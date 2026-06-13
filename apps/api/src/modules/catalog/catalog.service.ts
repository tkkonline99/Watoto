import { Injectable, NotFoundException } from '@nestjs/common';
import { AgeBand } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';

@Injectable()
export class CatalogService {
  constructor(private readonly prisma: PrismaService) {}

  async listSubjects(ageBand?: AgeBand) {
    return this.prisma.subject.findMany({
      orderBy: { sort: 'asc' },
      include: {
        courses: {
          where: { status: 'published', ...(ageBand ? { ageBand } : {}) },
          orderBy: { sort: 'asc' },
          select: { id: true, slug: true, ageBand: true },
        },
      },
    });
  }

  async getCourse(courseId: string) {
    const course = await this.prisma.course.findFirst({
      where: { id: courseId, status: 'published' },
      include: {
        subject: true,
        units: {
          orderBy: { sort: 'asc' },
          include: {
            lessons: {
              where: { status: 'published' },
              orderBy: { sort: 'asc' },
              select: {
                id: true,
                slug: true,
                lessonType: true,
                difficulty: true,
                estMinutes: true,
                isPremium: true,
                sort: true,
              },
            },
          },
        },
      },
    });
    if (!course) throw new NotFoundException('Course not found');
    return course;
  }

  async getLesson(lessonId: string) {
    const lesson = await this.prisma.lesson.findFirst({
      where: { id: lessonId, status: 'published' },
    });
    if (!lesson) throw new NotFoundException('Lesson not found');
    return lesson;
  }

  /** Quiz with questions — answer keys stripped; grading is server-side. */
  async getQuiz(quizId: string) {
    const quiz = await this.prisma.quiz.findFirst({
      where: { id: quizId, status: 'published' },
      include: { questions: { orderBy: { sort: 'asc' } } },
    });
    if (!quiz) throw new NotFoundException('Quiz not found');
    return {
      ...quiz,
      questions: quiz.questions.map((q) => ({ ...q, body: stripAnswerKey(q.body) })),
    };
  }
}

function stripAnswerKey(body: unknown): unknown {
  const b = body as { options?: Array<Record<string, unknown>> } | null;
  if (!b?.options) return body;
  return {
    ...b,
    options: b.options.map(({ correct: _correct, ...rest }) => rest),
  };
}
