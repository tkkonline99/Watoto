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
}
