import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, ProgressStatus } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';
import { GradeResult, SubmittedAnswer, gradeFromScore, gradeQuiz } from './grading';

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

  /**
   * Grades server-side from raw answers (client scores are advisory) and
   * stores the attempt. Idempotent on clientOpId: re-sends return the
   * stored attempt's grade instead of double-recording.
   */
  async submitQuizAttempt(input: {
    childId: string;
    quizId: string;
    answers: SubmittedAnswer[];
    durationS: number;
    clientOpId: string;
    attemptedAt?: Date;
  }): Promise<GradeResult> {
    const quiz = await this.prisma.quiz.findFirst({
      where: { id: input.quizId, status: 'published' },
      include: { questions: true },
    });
    if (!quiz) throw new NotFoundException('Quiz not found');

    const grade = gradeQuiz(
      quiz.questions.map((q) => ({
        id: q.id,
        body: q.body as { options?: Array<{ correct?: boolean }> },
      })),
      input.answers,
      quiz.passPct,
    );

    try {
      await this.prisma.quizAttempt.create({
        data: {
          childId: input.childId,
          quizId: input.quizId,
          scorePct: grade.scorePct,
          passed: grade.passed,
          answers: input.answers as unknown as Prisma.InputJsonValue,
          durationS: input.durationS,
          attemptedAt: input.attemptedAt ?? new Date(),
          clientOpId: input.clientOpId,
        },
      });
      return grade;
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        const existing = await this.prisma.quizAttempt.findUnique({
          where: { clientOpId: input.clientOpId },
        });
        if (existing) {
          return gradeFromScore(
            existing.scorePct,
            quiz.questions.length,
            Math.round((existing.scorePct / 100) * quiz.questions.length),
            quiz.passPct,
          );
        }
      }
      throw e;
    }
  }
}
