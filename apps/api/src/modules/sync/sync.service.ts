import { Injectable } from '@nestjs/common';
import { Prisma, ProgressStatus } from '@prisma/client';
import { z } from 'zod';
import { PrismaService } from '../../common/prisma/prisma.service';
import { ProgressService } from '../learning/progress.service';

export const syncOpSchema = z.object({
  clientOpId: z.string().uuid(),
  opType: z.enum(['lesson_progress']), // quiz_attempt, reward_event, ... follow with their modules
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
}
