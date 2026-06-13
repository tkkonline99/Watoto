import { gradeQuiz, QuestionForGrading } from './grading';

const q = (id: string, correctIndex: number): QuestionForGrading => ({
  id,
  body: { options: [0, 1, 2].map((i) => ({ correct: i === correctIndex })) },
});

const QUESTIONS = [q('q1', 0), q('q2', 1), q('q3', 2)];

describe('gradeQuiz (server-authoritative, mirrors client QuizBody.grade)', () => {
  it('perfect score: 100%, passed, 3 stars, 20 xp', () => {
    const grade = gradeQuiz(
      QUESTIONS,
      [
        { questionId: 'q1', selectedIndex: 0 },
        { questionId: 'q2', selectedIndex: 1 },
        { questionId: 'q3', selectedIndex: 2 },
      ],
      70,
    );
    expect(grade).toEqual({ total: 3, correct: 3, scorePct: 100, passed: true, stars: 3, xp: 20 });
  });

  it('2 of 3 = 67% fails a 70% gate with no xp', () => {
    const grade = gradeQuiz(
      QUESTIONS,
      [
        { questionId: 'q1', selectedIndex: 0 },
        { questionId: 'q2', selectedIndex: 1 },
        { questionId: 'q3', selectedIndex: 0 },
      ],
      70,
    );
    expect(grade.scorePct).toBe(67);
    expect(grade.passed).toBe(false);
    expect(grade.stars).toBe(0);
    expect(grade.xp).toBe(0);
  });

  it('90% earns 2 stars and 15 xp', () => {
    const ten = Array.from({ length: 10 }, (_, i) => q(`q${i}`, 0));
    const answers = ten.map((question, i) => ({
      questionId: question.id,
      selectedIndex: i === 9 ? 1 : 0, // one wrong
    }));
    const grade = gradeQuiz(ten, answers, 70);
    expect(grade).toMatchObject({ scorePct: 90, passed: true, stars: 2, xp: 15 });
  });

  it('answers for unknown questions and out-of-range picks never count', () => {
    const grade = gradeQuiz(
      QUESTIONS,
      [
        { questionId: 'ghost', selectedIndex: 0 },
        { questionId: 'q1', selectedIndex: 99 },
      ],
      70,
    );
    expect(grade.correct).toBe(0);
  });

  it('empty quiz grades to 0 without dividing by zero', () => {
    expect(gradeQuiz([], [], 70).scorePct).toBe(0);
  });
});
