#!/usr/bin/env python3
"""
Watoto translation pipeline.

Brings the fr / sw locale bundles up to full coverage against the English
catalog. It only ever translates keys that are still missing, in batches, so
it is cheap to resume and safe to re-run. Output is reviewed by a native
speaker before recording audio — this gets you a complete, consistent first
pass, not a substitute for that review.

This is the honest path from 10% to 100% for translation.

    export ANTHROPIC_API_KEY=sk-ant-...
    python extract_strings.py                  # refresh i18n/en.json first
    python translate_content.py --plan         # offline: how many strings per locale
    python translate_content.py fr             # translate all missing French
    python translate_content.py sw --limit 100 # translate 100 missing Swahili
    python translate_content.py                # both locales, everything missing

Set WATOTO_MODEL to your preferred current model (default below).
"""
import os, sys, json, re, time, urllib.request, urllib.error

I18N = "i18n"
LOCALES = {"fr": "French", "sw": "Swahili (Kiswahili)"}
BATCH = 40
MODEL = os.environ.get("WATOTO_MODEL", "claude-sonnet-4-6")
API_KEY = os.environ.get("ANTHROPIC_API_KEY")

SYSTEM = """You are a professional translator localizing a children's educational app
(ages 0-10) into {lang}. Translate each value into natural, warm, simple {lang} a young
child or their parent would hear. Rules:
- Keep it child-friendly and read-aloud smooth; match the playful register.
- Preserve any emoji exactly and keep them in a natural position.
- Keep onomatopoeia natural in {lang} (e.g. an animal sound a {lang} speaker would use).
- Do not translate or alter placeholders in braces like {{0001}} if present.
- Return ONLY a JSON object mapping each input key to its translated string. Same keys.
- No prose, no code fences, no extra keys."""

def load(p):
    return json.load(open(p, encoding="utf-8"))

def save(p, obj):
    json.dump(dict(sorted(obj.items())), open(p, "w", encoding="utf-8", newline="\n"),
              indent=2, ensure_ascii=False)

def call_claude(system, user, max_tokens=4000):
    if not API_KEY:
        sys.exit("ANTHROPIC_API_KEY not set. Use --plan for an offline preview.")
    body = json.dumps({"model": MODEL, "max_tokens": max_tokens, "system": system,
                       "messages": [{"role": "user", "content": user}]}).encode()
    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages", data=body,
        headers={"x-api-key": API_KEY, "anthropic-version": "2023-06-01",
                 "content-type": "application/json"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                data = json.load(r)
            return "".join(b.get("text", "") for b in data.get("content", []))
        except urllib.error.HTTPError as e:
            if e.code in (429, 529) and attempt < 3:
                time.sleep(2 ** attempt * 2); continue
            raise

def parse_obj(text):
    text = re.sub(r"^```(?:json)?|```$", "", text.strip(), flags=re.MULTILINE).strip()
    s, e = text.find("{"), text.rfind("}")
    return json.loads(text[s:e + 1])

def translate_locale(code, en, limit):
    lang = LOCALES[code]
    path = f"{I18N}/{code}.json"
    bundle = load(path) if os.path.exists(path) else {}
    missing = [k for k in en if k not in bundle]
    if limit:
        missing = missing[:limit]
    if not missing:
        print(f"{code}: already complete ({len(bundle)}/{len(en)})")
        return
    print(f"{code}: translating {len(missing)} strings in {(_ceil(len(missing), BATCH))} batches")
    sysprompt = SYSTEM.format(lang=lang)
    done = 0
    for i in range(0, len(missing), BATCH):
        chunk = {k: en[k] for k in missing[i:i + BATCH]}
        try:
            out = parse_obj(call_claude(sysprompt, json.dumps(chunk, ensure_ascii=False)))
        except Exception as e:
            print(f"  ! batch {i//BATCH} failed ({e}); will retry on next run")
            continue
        for k in chunk:                       # only accept keys we asked for
            if k in out and isinstance(out[k], str):
                bundle[k] = out[k]
                done += 1
        save(path, bundle)                    # checkpoint after each batch
        print(f"  ...{done}/{len(missing)} done")
    pct = round(100 * len(bundle) / len(en))
    print(f"{code}: now {len(bundle)}/{len(en)} ({pct}%)")

def _ceil(a, b):
    return -(-a // b)

def main():
    en = load(f"{I18N}/en.json")
    targets = [a for a in sys.argv[1:] if a in LOCALES] or list(LOCALES)
    limit = int(sys.argv[sys.argv.index("--limit") + 1]) if "--limit" in sys.argv else None

    if "--plan" in sys.argv:
        print(f"English catalog: {len(en)} strings\n")
        calls = 0
        for code in targets:
            path = f"{I18N}/{code}.json"
            have = load(path) if os.path.exists(path) else {}
            miss = len([k for k in en if k not in have])
            b = _ceil(miss, BATCH)
            calls += b
            print(f"  {code}: {miss} missing -> {b} batches of {BATCH}")
        print(f"\nEstimated total API calls: {calls}")
        print("Run without --plan (with ANTHROPIC_API_KEY set) to fill them, "
              "then check_i18n.py to verify.")
        return

    for code in targets:
        translate_locale(code, en, limit)

if __name__ == "__main__":
    main()
