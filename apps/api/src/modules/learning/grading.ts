/**
 * Pure quiz grading — the server-authoritative twin of the client's
 * QuizBody.grade(). Star thresholds per docs/12-gamification.md:
 * ≥70% = 1★, ≥90% = 2★, 100% = 3★.
 */

export interface QuestionForGrading {
  id: string;
  body: { options?: Array<{ correct?: boolean }> };
}

export interface SubmittedAnswer {
  questionId: string;
  selectedIndex: number;
}

export interface GradeResult {
  total: number;
  correct: number;
  scorePct: number;
  passed: boolean;
  stars: number;
  xp: number;
}

const XP_BY_STARS = [0, 10, 15, 20];

export function gradeFromScore(scorePct: number, total: number, correct: number, passPct: number): GradeResult {
  const passed = scorePct >= passPct;
  const stars = scorePct >= 100 ? 3 : scorePct >= 90 ? 2 : passed ? 1 : 0;
  return { total, correct, scorePct, passed, stars, xp: XP_BY_STARS[stars] };
}

export function gradeQuiz(
  questions: QuestionForGrading[],
  answers: SubmittedAnswer[],
  passPct: number,
): GradeResult {
  const byId = new Map(questions.map((q) => [q.id, q]));
  let correct = 0;
  for (const answer of answers) {
    const question = byId.get(answer.questionId);
    const options = question?.body.options;
    if (options && options[answer.selectedIndex]?.correct === true) {
      correct++;
    }
  }
  const total = questions.length;
  const scorePct = total === 0 ? 0 : Math.round((correct / total) * 100);
  return gradeFromScore(scorePct, total, correct, passPct);
}
