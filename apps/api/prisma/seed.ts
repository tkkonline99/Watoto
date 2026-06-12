/* eslint-disable no-console */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const SAMPLE_LESSON_BODY = {
  schema: 'watoto.lesson/1.0',
  titleKey: 'lesson.counting-1-3.title',
  blocks: [
    { type: 'concept', text: 'Let us count the mangoes!', image: 'mangoes.webp' },
    { type: 'tap_to_count', items: 3 },
    {
      type: 'check',
      question: {
        qtype: 'multiple_choice',
        prompt: 'How many mangoes did we count?',
        options: [
          { text: '2', correct: false },
          { text: '3', correct: true },
          { text: '4', correct: false },
        ],
      },
    },
  ],
  completion: { rewards: { xp: 10, stars: 1 }, skills: ['counting.1-10'] },
};

async function main(): Promise<void> {
  const math = await prisma.subject.upsert({
    where: { slug: 'math' },
    update: {},
    create: { slug: 'math', iconKey: 'icon_math', sort: 1 },
  });
  await prisma.subject.upsert({
    where: { slug: 'english' },
    update: {},
    create: { slug: 'english', iconKey: 'icon_english', sort: 2 },
  });
  await prisma.subject.upsert({
    where: { slug: 'science' },
    update: {},
    create: { slug: 'science', iconKey: 'icon_science', sort: 3 },
  });

  const course = await prisma.course.upsert({
    where: { slug: 'math-3-5' },
    update: { status: 'published' },
    create: { subjectId: math.id, ageBand: 'b3_5', slug: 'math-3-5', sort: 1, status: 'published' },
  });

  const unit = await prisma.unit.upsert({
    where: { courseId_slug: { courseId: course.id, slug: 'counting' } },
    update: {},
    create: { courseId: course.id, slug: 'counting', sort: 1 },
  });

  await prisma.lesson.upsert({
    where: { unitId_slug: { unitId: unit.id, slug: 'counting-1-3' } },
    update: { status: 'published', body: SAMPLE_LESSON_BODY },
    create: {
      unitId: unit.id,
      slug: 'counting-1-3',
      lessonType: 'interactive',
      difficulty: 1,
      estMinutes: 4,
      skills: ['counting.1-10'],
      status: 'published',
      body: SAMPLE_LESSON_BODY,
      sort: 1,
    },
  });

  console.log('Seed complete: 3 subjects, 1 published course/unit/lesson.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
