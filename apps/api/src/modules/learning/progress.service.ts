import { Injectable } from '@nestjs/common';
import { ProgressStatus } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';

export interface ProgressUpsert {
  childId: string;
  lessonId: string;
  status: ProgressStatus;
  scorePct?: number;
  timeSpentS: number;
  clientUpdatedAt: Date;
}

/** Rank used to enforce "status never regresses" during merges. */
const STATUS_RANK: Record<ProgressStatus, number> = {
  not_started: 0,
  in_progress: 1,
  completed: 2,
  mastered: 3,
};

@Injectable()
export class ProgressService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Last-write-wins on clientUpdatedAt with monotonic guards:
   * status only moves forward and scorePct keeps the maximum
   * (see docs/15-offline-sync.md §15.4).
   */
  async upsert(op: ProgressUpsert): Promise<{ result: 'applied' | 'merged' }> {
    const existing = await this.prisma.lessonProgress.findUnique({
      where: { childId_lessonId: { childId: op.childId, lessonId: op.lessonId } },
    });

    if (!existing) {
      await this.prisma.lessonProgress.create({
        data: {
          childId: op.childId,
          lessonId: op.lessonId,
          status: op.status,
          scorePct: op.scorePct ?? null,
          timeSpentS: op.timeSpentS,
          clientUpdatedAt: op.clientUpdatedAt,
          completedAt: STATUS_RANK[op.status] >= STATUS_RANK.completed ? new Date() : null,
        },
      });
      return { result: 'applied' };
    }

    const incomingNewer = op.clientUpdatedAt > existing.clientUpdatedAt;
    const mergedStatus =
      STATUS_RANK[op.status] >= STATUS_RANK[existing.status] ? op.status : existing.status;
    const mergedScore = Math.max(op.scorePct ?? 0, existing.scorePct ?? 0) || null;

    await this.prisma.lessonProgress.update({
      where: { childId_lessonId: { childId: op.childId, lessonId: op.lessonId } },
      data: {
        status: mergedStatus,
        scorePct: mergedScore,
        timeSpentS: existing.timeSpentS + op.timeSpentS,
        clientUpdatedAt: incomingNewer ? op.clientUpdatedAt : existing.clientUpdatedAt,
        completedAt:
          existing.completedAt ??
          (STATUS_RANK[mergedStatus] >= STATUS_RANK.completed ? new Date() : null),
      },
    });
    return { result: incomingNewer ? 'applied' : 'merged' };
  }
}
