import { Injectable } from '@nestjs/common';
import { Prisma, ProgressStatus } from '@prisma/client';
import { z } from 'zod';
import { PrismaService } from '../../common/prisma/prisma.service';
import { ProgressService } from '../learning/progress.service';

export const syncOpSchema = z.object({
  clientOpId: z.string().uuid(),
  opType: z.enum(['lesson_progress', 'quiz_attempt', 'story_read']), // reward_event, reading_attempt… follow with their modules
  payload: z.record(z.unknown()),
  clientUpdatedAt: z.coerce.date(),
});

export type SyncOpInput = z.infer<typeof syncOpSchema>;
export type SyncOpResult = 'applied' | 'duplicate' | 'conflict_server_won' | 'rejected';

const progressPayloadSchema = z.object({
  lessonId: z.string().uuid(),
  status: z.enum(['not_started', 'in_progress', 'completed', 'mastered']),
  scorePct: z.number().int().min(0).max(100).optional(),
  timeSpentS: z.number().int().min(0).default(0),
});

const quizPayloadSchema = z.object({
  quizId: z.string().uuid(),
  durationS: z.number().int().min(0).default(0),
  answers: z
    .array(
      z.object({
        questionId: z.string().uuid(),
        selectedIndex: z.number().int().min(0),
      }),
    )
    .min(1)
    .max(50),
  // scorePct/passed from the client are advisory only — server re-grades.
});

const storyPayloadSchema = z.object({
  storyId: z.string().uuid(),
});

@Injectable()
export class SyncService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly progress: ProgressService,
  ) {}

  async applyBatch(
    childId: string,
    deviceId: string,
    ops: SyncOpInput[],
  ): Promise<Array<{ clientOpId: string; result: SyncOpResult }>> {
    const results: Array<{ clientOpId: string; result: SyncOpResult }> = [];
    for (const op of ops) {
      results.push({ clientOpId: op.clientOpId, result: await this.applyOne(childId, deviceId, op) });
    }
    return results;
  }

  private async applyOne(childId: string, deviceId: string, op: SyncOpInput): Promise<SyncOpResult> {
    try {
      // Idempotency gate: the unique PK on client_op_id makes duplicates explicit.
      await this.prisma.syncOp.create({
        data: {
          clientOpId: op.clientOpId,
          childId,
          opType: op.opType,
          payload: op.payload as Prisma.InputJsonValue,
          deviceId,
        },
      });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        return 'duplicate';
      }
      throw e;
    }

    switch (op.opType) {
      case 'lesson_progress':
        return this.applyLessonProgress(childId, op);
      case 'quiz_attempt':
        return this.applyQuizAttempt(childId, op);
      case 'story_read':
        return this.applyStoryRead(childId, op);
    }
  }

  private async applyLessonProgress(childId: string, op: SyncOpInput): Promise<SyncOpResult> {
    const parsed = progressPayloadSchema.safeParse(op.payload);
    if (!parsed.success) return 'rejected';

    const { result } = await this.progress.upsert({
      childId,
      lessonId: parsed.data.lessonId,
      status: parsed.data.status as ProgressStatus,
      scorePct: parsed.data.scorePct,
      timeSpentS: parsed.data.timeSpentS,
      clientUpdatedAt: op.clientUpdatedAt,
    });
    return result === 'applied' ? 'applied' : 'conflict_server_won';
  }

  private async applyQuizAttempt(childId: string, op: SyncOpInput): Promise<SyncOpResult> {
    const parsed = quizPayloadSchema.safeParse(op.payload);
    if (!parsed.success) return 'rejected';

    try {
      await this.progress.submitQuizAttempt({
        childId,
        quizId: parsed.data.quizId,
        answers: parsed.data.answers,
        durationS: parsed.data.durationS,
        clientOpId: op.clientOpId,
        attemptedAt: op.clientUpdatedAt,
      });
      return 'applied';
    } catch {
      return 'rejected'; // e.g. quiz unpublished since the attempt
    }
  }

  private async applyStoryRead(childId: string, op: SyncOpInput): Promise<SyncOpResult> {
    const parsed = storyPayloadSchema.safeParse(op.payload);
    if (!parsed.success) return 'rejected';

    await this.progress.recordStoryRead({
      childId,
      storyId: parsed.data.storyId,
      clientOpId: op.clientOpId,
      readAt: op.clientUpdatedAt,
    });
    return 'applied';
  }
}
