import { BadRequestException, Body, Controller, ForbiddenException, Post, Req, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthedRequest, JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ProgressService } from './progress.service';

// Content ids are slugs from the content library (e.g. s08.math.lesson.01),
// not UUIDs — so they validate as non-empty strings. clientOpId stays a UUID.
const contentId = z.string().min(1).max(80);

const progressSchema = z.object({
  lessonId: contentId,
  status: z.enum(['not_started', 'in_progress', 'completed', 'mastered']),
  scorePct: z.number().int().min(0).max(100).optional(),
  timeSpentS: z.number().int().min(0).default(0),
  clientUpdatedAt: z.coerce.date(),
});

const quizAttemptSchema = z.object({
  quizId: contentId,
  durationS: z.number().int().min(0).default(0),
  clientOpId: z.string().uuid(),
  answers: z
    .array(
      z.object({
        questionId: contentId,
        selectedIndex: z.number().int().min(0),
      }),
    )
    .min(1)
    .max(50),
});

@Controller('progress')
@UseGuards(JwtAuthGuard)
export class ProgressController {
  constructor(private readonly progress: ProgressService) {}

  @Post('lessons')
  async upsertLesson(@Req() req: AuthedRequest, @Body() body: unknown) {
    const childId = req.principal.childId;
    if (req.principal.role !== 'child' || !childId) {
      throw new ForbiddenException('Only child sessions record progress');
    }
    const parsed = progressSchema.safeParse(body);
    if (!parsed.success) {
      throw new BadRequestException(parsed.error.flatten());
    }
    return this.progress.upsert({ childId, ...parsed.data });
  }

  /** Server grades from raw answers and returns {scorePct, passed, stars, xp}. */
  @Post('quizzes')
  async submitQuiz(@Req() req: AuthedRequest, @Body() body: unknown) {
    const childId = req.principal.childId;
    if (req.principal.role !== 'child' || !childId) {
      throw new ForbiddenException('Only child sessions submit quiz attempts');
    }
    const parsed = quizAttemptSchema.safeParse(body);
    if (!parsed.success) {
      throw new BadRequestException(parsed.error.flatten());
    }
    return this.progress.submitQuizAttempt({ childId, ...parsed.data });
  }
}
