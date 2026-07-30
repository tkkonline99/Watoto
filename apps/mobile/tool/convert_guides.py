"""Converts the "Subjects" curriculum drop (docx/xlsx) into bundled guides.

Reads the grade packages, storybook guides, and early-years guides from a
drop folder and writes assets/guides/<id>.md (Markdown-lite: the subset the
in-app viewer renders — #/##/### headings, - bullets, | tables, **bold**)
plus guides_manifest.json (groups by age band, docs in teaching order).

Duplicates in the drop are skipped by content hash. The Master Curriculum
Overview spreadsheet is rendered as per-band sections with subject bullets.

Usage (from apps/mobile):
    python tool/convert_guides.py "<drop folder>" assets/guides
"""
import hashlib
import json
import os
import re
import sys
import zipfile
import xml.etree.ElementTree as ET

sys.stdout.reconfigure(encoding="utf-8")

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
S = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"


# ------------------------------------------------------------------ docx

def _runs_text(el):
    return "".join(t.text or "" for t in el.iter(f"{W}t")).strip()


def _is_all_bold(p):
    runs = [r for r in p.iter(f"{W}r") if _runs_text(r)]
    if not runs:
        return False
    for r in runs:
        rpr = r.find(f"{W}rPr")
        if rpr is None or rpr.find(f"{W}b") is None:
            return False
    return True


def docx_to_markdown(path):
    """Body of a .docx as Markdown-lite lines (tables preserved)."""
    with zipfile.ZipFile(path) as z:
        root = ET.fromstring(z.read("word/document.xml"))
    body = root.find(f"{W}body")
    out = []
    seen_heading = False
    title_lines = 0

    def cell_text(tc):
        return " ".join(filter(None, (_runs_text(p) for p in tc.iter(f"{W}p"))))

    for el in body:
        if el.tag == f"{W}tbl":
            rows = []
            for tr in el.iter(f"{W}tr"):
                cells = [cell_text(tc).replace("|", "/") for tc in tr.findall(f"{W}tc")]
                if any(cells):
                    rows.append("| " + " | ".join(cells) + " |")
            if rows:
                out.append(rows[0])
                out.append("|" + "---|" * (rows[0].count("|") - 1))
                out.extend(rows[1:])
                out.append("")
            continue
        if el.tag != f"{W}p":
            continue
        text = _runs_text(el)
        if not text:
            continue
        style = ""
        ppr = el.find(f"{W}pPr")
        if ppr is not None:
            ps = ppr.find(f"{W}pStyle")
            if ps is not None:
                style = ps.get(f"{W}val", "")
        if style == "Heading1":
            seen_heading = True
            out += ["", f"## {text}", ""]
        elif style == "Heading2":
            out += ["", f"### {text}", ""]
        elif style == "ListParagraph":
            out.append(f"- {text}")
        elif not seen_heading and title_lines == 0:
            title_lines += 1
            out += [f"# {text}", ""]
        elif _is_all_bold(el):
            out += ["", f"**{text}**"]
        else:
            out.append(text)
    return "\n".join(out).strip() + "\n"


# ------------------------------------------------------------------ xlsx

def xlsx_overview_to_markdown(path):
    """The scope & sequence sheet as per-band sections with subject bullets."""
    with zipfile.ZipFile(path) as z:
        sheet = z.read("xl/worksheets/sheet1.xml").decode("utf-8")
    root = ET.fromstring(sheet)
    rows = []
    for row in root.iter(f"{S}row"):
        cells = []
        for c in row.iter(f"{S}c"):
            t = c.find(f"{S}is")
            cells.append("".join(x.text or "" for x in t.iter(f"{S}t")) if t is not None else "")
        rows.append(cells)
    out = ["# Master Curriculum Overview", ""]
    if rows and rows[0]:
        out += [rows[0][0], ""]
    if len(rows) > 1 and rows[1]:
        out += [f"> {rows[1][0]}", ""]
    # Data rows: Subject | Age Range | Stage | Core Topics | Regional | Assessment.
    # The sheet is subject-major (all bands for one subject, then the next), so
    # collect per band first and emit each band section exactly once.
    bands = {}  # ages -> (stage label, [subject lines])
    for cells in rows[2:]:
        if len(cells) < 4 or not cells[0] or cells[0] == "Subject":
            continue
        subject, ages, stage, topics = cells[0], cells[1], cells[2], cells[3]
        assessment = cells[5] if len(cells) > 5 else ""
        line = f"- **{subject}** — {topics}"
        if assessment:
            line += f" *Assessment: {assessment}*"
        bands.setdefault(ages, (stage, []))[1].append(line)

    def sort_key(ages):
        m = re.match(r"(\d+)", ages)
        return int(m.group(1)) if m else 99

    for ages in sorted(bands, key=sort_key):
        stage, lines = bands[ages]
        label = f" · {stage}" if stage else ""
        out += ["", f"## Ages {ages}{label}", ""] + lines
    return "\n".join(out).strip() + "\n"


# ------------------------------------------------------------- inventory

BANDS = {  # key -> (group title, sort)
    "early": ("Early Years — Ages 0–5", 1),
    "k": ("Kindergarten — Ages 5–6", 2),
    "g1": ("Grade 1 — Ages 6–7", 3),
    "g2": ("Grade 2 — Ages 7–8", 4),
    "g3": ("Grade 3 — Ages 8–9", 5),
    "g4": ("Grade 4 — Ages 9–10", 6),
}
GRADE_KEY = {"Kindergarten": "k", "Grade1": "g1", "Grade2": "g2",
             "Grade3": "g3", "Grade4": "g4"}
SUBJECTS = {  # filename token -> (display, emoji, sort within band)
    "Reading_Writing": ("Reading & Writing", "📖", 1),
    "Math": ("Math", "🔢", 2),
    "Science": ("Science", "🔬", 3),
    "Social_Studies": ("Social Studies", "🌍", 4),
    "Technology_Logic": ("Technology & Logic", "🤖", 5),
    "Storybooks": ("Storybooks — Reading Guide", "📚", 6),
}


def classify(filename):
    """(band key, doc id, title, emoji, sort) for a drop file, or None."""
    m = re.match(r"Ages_(\d+)-(\d+)_(.+)\.docx", filename)
    if m:
        a, b = m.group(1), m.group(2)
        kind = "Development & Play Guide" if "Development" in m.group(3) else \
            m.group(3).replace("_", " ")
        return "early", f"ages-{a}-{b}", f"Ages {a}–{b} — {kind}", "🌱", int(a)
    if filename.startswith("Early_Years_Milestones"):
        return "early", "milestones", "Milestones & Activities (Ages 0–5)", "🧸", 9
    m = re.match(r"(\w+?)_(Kindergarten|Grade\d)_(Complete_Package|Reading_Guide)\.docx",
                 filename)
    if m:
        subj, grade = m.group(1), m.group(2)
        if subj not in SUBJECTS:
            return None
        title, emoji, sort = SUBJECTS[subj]
        return GRADE_KEY[grade], f"{GRADE_KEY[grade]}-{subj.lower().replace('_','-')}", \
            title, emoji, sort
    return None


def main(drop, outdir):
    os.makedirs(outdir, exist_ok=True)
    seen = set()
    docs = []  # (band, sort, {id,title,emoji,asset})
    newest_xlsx = None

    for root, _, files in os.walk(drop):
        for f in sorted(files):
            path = os.path.join(root, f)
            h = hashlib.md5(open(path, "rb").read()).hexdigest()
            if h in seen:
                continue
            seen.add(h)
            if f == "Master_Curriculum_Overview.xlsx":
                if newest_xlsx is None or os.path.getmtime(path) > os.path.getmtime(newest_xlsx):
                    newest_xlsx = path
                continue
            info = classify(f)
            if info is None:
                print(f"SKIP (unrecognized): {f}")
                continue
            band, doc_id, title, emoji, sort = info
            md = docx_to_markdown(path)
            with open(os.path.join(outdir, f"{doc_id}.md"), "w", encoding="utf-8") as fh:
                fh.write(md)
            docs.append((band, sort, {
                "id": doc_id, "title": title, "emoji": emoji,
                "asset": f"assets/guides/{doc_id}.md",
            }))
            print(f"{doc_id}.md  <-  {f}  ({len(md)//1024}KB)")

    if newest_xlsx:
        md = xlsx_overview_to_markdown(newest_xlsx)
        with open(os.path.join(outdir, "overview.md"), "w", encoding="utf-8") as fh:
            fh.write(md)
        print(f"overview.md  <-  {os.path.basename(newest_xlsx)}  ({len(md)//1024}KB)")

    groups = []
    if newest_xlsx:
        groups.append({"band": "overview", "title": "Overview — Ages 0–10", "docs": [
            {"id": "overview", "title": "Master Curriculum Overview",
             "emoji": "🗺️", "asset": "assets/guides/overview.md"}]})
    for key, (title, _) in sorted(BANDS.items(), key=lambda kv: kv[1][1]):
        band_docs = sorted((d for d in docs if d[0] == key), key=lambda d: d[1])
        if band_docs:
            groups.append({"band": key, "title": title,
                           "docs": [d[2] for d in band_docs]})

    manifest = {"version": 1, "groups": groups}
    with open(os.path.join(outdir, "guides_manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=2)
    total = sum(len(g["docs"]) for g in groups)
    print(f"\nmanifest: {len(groups)} groups, {total} docs")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "assets/guides")
