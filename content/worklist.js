// Regenerates docs/CONTENT_WORKLIST.md — the per-subject content gap map.
//
// Measures the shipped library against its own `_buildPlan` (6 lessons /
// 4 quizzes / 2 stories per subject) and against the per-tier step depth in
// apps/mobile/test/lesson_depth_test.dart, then writes a worklist ordered by
// `_buildPlan.priorityOrder` (stages 1-3, then 4-6, then 7-10).
//
//   node content/worklist.js        # from the repo root
//
// Node rather than Python only because the repo already needs Node in CI and
// this reads the same JSON the app does. The Python tools in this folder stay
// the content pipeline; this is a reporting script.
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const LIB = path.join(ROOT, 'apps/mobile/assets/content/watoto_content_library.json');
const IMGDIR = path.join(ROOT, 'apps/mobile/assets/images/img');

const j = JSON.parse(fs.readFileSync(LIB, 'utf8'));
const arr = j.content;
const TARGET = j._buildPlan.targetPerSubject;

// Keep in sync with minStepsForTier in apps/mobile/test/lesson_depth_test.dart.
// A 0-1 year old cannot sit through a stage-7 teaching arc, so depth is a
// function of the design tier, not one number for the whole library.
const MIN_STEPS_BY_TIER = {
  'parent-led': 4,
  'encourage-effort': 6,
  'gamify-gently': 8,
  'grant-autonomy': 8,
};
const minStepsFor = (item) => MIN_STEPS_BY_TIER[item.designTier] ?? 8;

// ---- subject list from the curriculum, in stage order ----
const subs = [];
for (const st of j.curriculum.stages) {
  for (const s of st.subjects) {
    subs.push({
      stage: st.stage ?? st.id,
      ages: st.ages || '',
      subject: typeof s === 'string' ? s : s.name,
    });
  }
}

const bySub = {};
for (const it of arr) {
  const k = it.stage + '||' + it.subject;
  (bySub[k] = bySub[k] || []).push(it);
}

// ids look like sNN.<slug>.<type>.NN — recover the slug from existing items so
// generated ids stay in the family already used by the subject.
function slugOf(items) {
  for (const it of items) {
    const m = /^s\d{2}\.([^.]+)\./.exec(it.id);
    if (m) return m[1];
  }
  return null;
}

// ---- PNGs on disk that no item references ----
const referenced = new Set();
for (const it of arr) {
  for (const a of it.assets || []) if (a.type === 'image') referenced.add(a.ref.replace(/^img\//, ''));
  for (const q of it.questions || []) for (const o of q.options || []) if (o.asset) referenced.add(o.asset.replace(/^img\//, ''));
  for (const p of it.pages || []) if (p.illustration) referenced.add(p.illustration.replace(/^img\//, ''));
}
const orphans = [];
for (const d of fs.readdirSync(IMGDIR)) {
  const p = path.join(IMGDIR, d);
  if (!fs.statSync(p).isDirectory()) continue;
  for (const f of fs.readdirSync(p)) {
    const rel = d + '/' + f;
    if (!referenced.has(rel)) orphans.push({ stage: parseInt(d.replace('s', ''), 10), file: f, rel });
  }
}

const STOP = new Set(['the', 'a', 'an', 'and', 'of', 'to', 'in', 'is', 'it', 'png', 'img']);
const tok = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, ' ').split(' ').filter((w) => w.length > 2 && !STOP.has(w));
function scoreMatch(orphan, item) {
  if (orphan.stage !== item.stage) return 0;
  const ot = new Set(tok(orphan.file.replace(/\.png$/i, '')));
  const it = new Set([...tok(item.title), ...tok(item.subject), ...tok(item.objective || '')]);
  let hits = 0;
  for (const t of ot) if (it.has(t)) hits++;
  return hits;
}

// ---- declared audio with no file behind it ----
const audioRefs = new Set();
for (const it of arr) for (const a of it.assets || []) if (a.type === 'audio') audioRefs.add(a.ref);
const missingAudio = [...audioRefs].filter((r) => !fs.existsSync(path.join(ROOT, 'apps/mobile/assets/audio', r)));

const isBare = (s) => !(s.mechanic || '').trim() && s.answer == null;

const rows = [];
const totals = { quiz: 0, story: 0, shallow: 0, norecap: 0, noart: 0, bare: 0 };

for (const { stage, ages, subject } of subs) {
  const items = bySub[stage + '||' + subject] || [];
  const slug = slugOf(items) || subject.toLowerCase().replace(/[^a-z]+/g, '');
  const pad = (n) => String(n).padStart(2, '0');
  const sid = 's' + pad(stage);

  const byType = { lesson: [], quiz: [], story: [] };
  for (const it of items) byType[it.type].push(it);

  const nextIds = (type, need) => {
    const used = new Set(byType[type].map((it) => parseInt(it.id.split('.').pop(), 10)));
    const out = [];
    let n = 1;
    while (out.length < need) {
      if (!used.has(n)) out.push(`${sid}.${slug}.${type}.${pad(n)}`);
      n++;
    }
    return out;
  };

  const missQuiz = Math.max(0, TARGET.quiz - byType.quiz.length);
  const missStory = Math.max(0, TARGET.story - byType.story.length);
  const shallow = byType.lesson.filter((l) => (l.steps || []).length < minStepsFor(l));
  const noRecap = byType.lesson.filter((l) => !l.recap);
  // "Has art" means art the player actually draws. `assets[]` is pipeline
  // metadata that LibraryItem never even parses, so counting only that once
  // reported 227 art-less items when the real figure — items with no image
  // anywhere, including quiz options and story pages — was less than half of it.
  const noArt = items.filter((it) => {
    const q = (it.questions || []).some((x) => (x.options || []).some((o) => o.asset));
    const p = (it.pages || []).some((x) => x.illustration);
    return !(it.assets || []).some((a) => a.type === 'image') && !q && !p;
  });
  const bare = byType.lesson.reduce((n, l) => n + (l.steps || []).filter(isBare).length, 0);

  totals.quiz += missQuiz;
  totals.story += missStory;
  totals.shallow += shallow.length;
  totals.norecap += noRecap.length;
  totals.noart += noArt.length;
  totals.bare += bare;

  const cands = [];
  for (const o of orphans) {
    let best = 0;
    for (const it of items) best = Math.max(best, scoreMatch(o, it));
    if (best > 0) cands.push({ rel: o.rel, score: best });
  }
  cands.sort((a, b) => b.score - a.score);

  rows.push({
    stage, ages, subject,
    authorQuiz: nextIds('quiz', missQuiz),
    authorStory: nextIds('story', missStory),
    shallow: shallow.map((l) => ({ id: l.id, steps: (l.steps || []).length, min: minStepsFor(l) })),
    noRecap: noRecap.map((l) => l.id),
    noArt: noArt.map((it) => it.id),
    bare,
    art: cands.slice(0, 6).map((c) => c.rel),
  });
}

const band = (s) =>
  s <= 3 ? 'P1 — foundation (stages 1-3)' : s <= 6 ? 'P2 — pre-literacy → kindergarten (stages 4-6)' : 'P3 — grades 1-4 (stages 7-10)';

let md = '';
md += '# Content worklist\n\n';
md += '_Generated by `node content/worklist.js` from `apps/mobile/assets/content/watoto_content_library.json`,\n';
md += 'measured against its own `_buildPlan` and the per-tier depth in `apps/mobile/test/lesson_depth_test.dart`._\n\n';
md += `_Library version ${j._meta.version}, generated ${j._meta.generated}._\n\n`;
md += '## Totals\n\n';
md += '| Gap | Count |\n|---|---|\n';
md += `| Quizzes to author | ${totals.quiz} |\n`;
md += `| Stories to author | ${totals.story} |\n`;
md += `| Lessons below their tier's step depth | ${totals.shallow} |\n`;
md += `| Lessons with no recap | ${totals.norecap} |\n`;
md += `| Items with no illustration | ${totals.noart} |\n`;
md += `| Unreferenced PNGs on disk | ${orphans.length} |\n`;
md += `| Steps with no declared mechanic | ${totals.bare} |\n`;
md += `| Declared audio files that do not exist | ${missingAudio.length} |\n\n`;
md += 'Depth minimums are per design tier — `parent-led` 4, `encourage-effort` 6, `gamify-gently` and\n';
md += '`grant-autonomy` 8. A stage-7 teaching arc is the wrong shape for a one-year-old.\n\n';
md += 'Priority follows `_buildPlan.priorityOrder`: finish stages 1-3 first, then 4-6, then 7-10.\n\n';

let lastBand = null;
for (const r of rows) {
  const b = band(r.stage);
  if (b !== lastBand) {
    md += `\n## ${b}\n`;
    lastBand = b;
  }
  const gaps = r.authorQuiz.length + r.authorStory.length + r.shallow.length + r.noRecap.length + r.noArt.length + r.bare;
  md += `\n### Stage ${r.stage} — ${r.subject}${r.ages ? ` (ages ${r.ages})` : ''}\n\n`;
  if (!gaps) {
    md += '- ✅ complete\n';
    continue;
  }
  if (r.authorQuiz.length) md += `- **Author ${r.authorQuiz.length} quiz:** ${r.authorQuiz.map((x) => '`' + x + '`').join(', ')}\n`;
  if (r.authorStory.length) md += `- **Author ${r.authorStory.length} story:** ${r.authorStory.map((x) => '`' + x + '`').join(', ')}\n`;
  if (r.shallow.length)
    md += `- **Deepen ${r.shallow.length} lessons:** ${r.shallow.map((s) => '`' + s.id + '` (' + s.steps + '→' + s.min + ')').join(', ')}\n`;
  if (r.noRecap.length) md += `- **Add ${r.noRecap.length} recaps:** ${r.noRecap.map((x) => '`' + x + '`').join(', ')}\n`;
  if (r.noArt.length) md += `- **${r.noArt.length} items have no illustration** (emoji fallback): ${r.noArt.map((x) => '`' + x + '`').join(', ')}\n`;
  if (r.art.length) md += `- Unused art that may fit: ${r.art.map((x) => '`img/' + x + '`').join(', ')}\n`;
  if (r.bare) md += `- ${r.bare} steps declare no \`mechanic\`\n`;
}

md += '\n## Declared audio that does not exist\n\n';
if (!missingAudio.length) {
  md += 'None — every declared audio ref resolves to a file.\n';
} else {
  md += `${missingAudio.length} refs. The app bundles only the generic SFX in \`assets/audio/sfx/\`, so every cue\n`;
  md += 'below is silent at runtime. `content/validate_content.py --assets` fails on these.\n\n';
  md += '```\n' + missingAudio.sort().join('\n') + '\n```\n';
}

fs.writeFileSync(path.join(ROOT, 'docs/CONTENT_WORKLIST.md'), md);
console.log('wrote docs/CONTENT_WORKLIST.md');
console.log('totals:', JSON.stringify(totals), '| orphan PNGs:', orphans.length, '| missing audio:', missingAudio.length);
