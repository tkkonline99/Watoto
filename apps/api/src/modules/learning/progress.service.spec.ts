import { ProgressService } from './progress.service';
import { PrismaService } from '../../common/prisma/prisma.service';

describe('ProgressService merge rules (docs/15-offline-sync.md §15.4)', () => {
  const findUnique = jest.fn();
  const create = jest.fn();
  const update = jest.fn();
  const prisma = { lessonProgress: { findUnique, create, update } } as unknown as PrismaService;
  const service = new ProgressService(prisma);

  const base = {
    childId: '11111111-1111-1111-1111-111111111111',
    lessonId: '22222222-2222-2222-2222-222222222222',
    timeSpentS: 60,
  };

  beforeEach(() => jest.clearAllMocks());

  it('creates a row on first write', async () => {
    findUnique.mockResolvedValue(null);
    const res = await service.upsert({
      ...base,
      status: 'in_progress',
      clientUpdatedAt: new Date('2026-06-12T10:00:00Z'),
    });
    expect(res.result).toBe('applied');
    expect(create).toHaveBeenCalledTimes(1);
  });

  it('never regresses status: late in_progress cannot undo completed', async () => {
    findUnique.mockResolvedValue({
      status: 'completed',
      scorePct: 80,
      timeSpentS: 100,
      clientUpdatedAt: new Date('2026-06-12T09:00:00Z'),
      completedAt: new Date('2026-06-12T09:00:00Z'),
    });
    await service.upsert({
      ...base,
      status: 'in_progress',
      clientUpdatedAt: new Date('2026-06-12T10:00:00Z'), // newer, but lower status
    });
    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ status: 'completed' }) }),
    );
  });

  it('keeps the max score across devices', async () => {
    findUnique.mockResolvedValue({
      status: 'completed',
      scorePct: 90,
      timeSpentS: 100,
      clientUpdatedAt: new Date('2026-06-12T09:00:00Z'),
      completedAt: new Date(),
    });
    await service.upsert({
      ...base,
      status: 'completed',
      scorePct: 70,
      clientUpdatedAt: new Date('2026-06-12T11:00:00Z'),
    });
    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ scorePct: 90 }) }),
    );
  });

  it('older write is merged, not applied (LWW)', async () => {
    findUnique.mockResolvedValue({
      status: 'in_progress',
      scorePct: null,
      timeSpentS: 10,
      clientUpdatedAt: new Date('2026-06-12T12:00:00Z'),
      completedAt: null,
    });
    const res = await service.upsert({
      ...base,
      status: 'in_progress',
      clientUpdatedAt: new Date('2026-06-12T08:00:00Z'), // stale
    });
    expect(res.result).toBe('merged');
  });
});
