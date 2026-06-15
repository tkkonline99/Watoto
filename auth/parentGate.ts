/**
 * Parent gate (COPPA / GDPR-K).
 *
 * A child must not be able to create an account, enter personal info, or make
 * a purchase on their own. Per FTC guidance, a "parental gate" should require
 * an action a young child is unlikely to complete. We use a multi-step number
 * entry (not a simple yes/no). Show this gate immediately BEFORE:
 *   - the parent sign-up / sign-in screen
 *   - any settings that collect data
 *   - the premium / purchase screen
 *
 * This is a gate, not authentication — it does not prove who the adult is, it
 * just keeps young children out of adult flows. Real identity = Firebase Auth.
 */

export type ParentGateChallenge = {
  prompt: string; // e.g. "Type the number: four — two — nine"
  answer: string; // e.g. "429"
};

const WORDS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"];

/** Generate a fresh 3-digit spelled-out challenge. */
export function makeParentGate(): ParentGateChallenge {
  const digits = Array.from({ length: 3 }, () => Math.floor(Math.random() * 10));
  return {
    prompt: digits.map((d) => WORDS[d]).join(" — "),
    answer: digits.join(""),
  };
}

/** Verify the adult's input against the active challenge. */
export function checkParentGate(input: string, challenge: ParentGateChallenge): boolean {
  return input.replace(/\D/g, "") === challenge.answer;
}
