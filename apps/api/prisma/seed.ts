/* eslint-disable no-console */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Fixed IDs shared with dev tooling: the mobile sample pack references
// SAMPLE_LESSON_ID, and POST /auth/dev-token defaults to the demo family.
const DEMO_PARENT_ID = '00000000-0000-0000-0000-000000000001';
const DEMO_CHILD_ID = '00000000-0000-0000-0000-000000000002';
const SAMPLE_LESSON_ID = '5d3f1a2b-9c4e-4f6a-8b7d-1e2f3a4b5c6d';

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
  await prisma.user.upsert({
    where: { firebaseUid: 'dev-parent' },
    update: {},
    create: {
      id: DEMO_PARENT_ID,
      firebaseUid: 'dev-parent',
      email: 'demo@watoto.app',
      role: 'parent',
      displayName: 'Demo Parent',
    },
  });

  await prisma.childProfile.upsert({
    where: { id: DEMO_CHILD_ID },
    update: {},
    create: {
      id: DEMO_CHILD_ID,
      parentId: DEMO_PARENT_ID,
      nickname: 'Amani',
      birthMonth: new Date('2022-06-01'),
      ageBand: 'b3_5',
    },
  });

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
      id: SAMPLE_LESSON_ID,
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

  console.log('Seed complete: demo family + 3 subjects + published counting lesson.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
