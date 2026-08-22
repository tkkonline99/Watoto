"""Prepare a supplied photograph for use as a lexicon picture.

The app draws a lexicon word as a glyph on a tinted disc. A word listed in
`option_photos.dart` draws a photograph instead, in the same disc — which means
the photo is **circle-masked**, and at the answer size that circle is 58dp.
Two things follow, and both are why this script exists rather than the files
being dropped in by hand:

  - a square photo loses its corners to the mask, so the part of the animal
    that identifies it has to sit near the centre. A hen whose comb falls in a
    corner arrives as a brown blob;
  - the source photos are 250-350 KB at 500-700px, against an art pack that
    averages 28 KB at 512x512. Shipping them unprocessed would cost more than
    every stage-1 illustration put together.

Run it again whenever a source photo changes; it is idempotent.

    python content/prep_photos.py <source-dir> [--check]

Source files are matched by the `PLAN` table below and written out under the
*lexicon word* they illustrate, which is the name option_photos.dart looks up.
Preview the result with `--preview`, which renders the crops exactly as the app
masks them, at the real disc size — the only honest way to judge whether an
animal survives the circle.
"""
import argparse
import io
import os
import sys

from PIL import Image, ImageDraw

# Where the bundled pictures live. Not stage-specific: a lexicon word is used
# wherever the word appears, so these sit outside the per-stage folders.
OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "apps", "mobile", "assets", "images", "img", "photo",
)

SIZE = 512

# source file -> (lexicon word, focus box or None)
#
# A focus box (left, top, right, bottom) in the *source's own* pixels, picked
# by eye for a photo shot against a background that cannot be detected — bokeh
# and grass are not flat colours. None means the subject is a cut-out against a
# flat background and can be found automatically.
#
# The boxes crop tight on the animal's head and shoulders rather than framing
# the whole creature. At 58dp a full-body shot is a smudge; what a child
# recognises is a face. That is why the flying owl is cropped to its face and
# not to its wingspan, and why only the sharp hen from a field of six is kept.
PLAN = {
    "dog.jpg": ("dog", (1000, 900, 3300, 3200)),
    "owl.jpg": ("owl", (924, 1802, 1524, 2402)),
    "hen.jpg": ("chicken", (1880, 1160, 3520, 2800)),
}

# Where each source came from, so the provenance of anything that ships is
# auditable. All three are Unsplash, whose licence grants free commercial use
# with no attribution required — which is the reason they can be here at all.
SOURCES = {
    "dog.jpg": "https://unsplash.com/photos/rFao8fcvTdY",
    "owl.jpg": "https://unsplash.com/photos/xWQcud4Xtr4",
    "hen.jpg": "https://unsplash.com/photos/4W8FgDVyUME",
}


def subject_box(im):
    """Bounding box of everything that is not the flat background."""
    alpha = im.getchannel("A")
    if alpha.getextrema()[0] < 250:  # a real cut-out: trust its alpha
        return im.getbbox()
    grey = im.convert("L")
    return grey.point(lambda v: 0 if v > 244 else 255).getbbox()


def squarify(box, w, h):
    """The largest square inside w*h that stays centred on box."""
    l, t, r, b = box
    side = min(max(r - l, b - t), w, h)
    cx, cy = (l + r) / 2, (t + b) / 2
    l = int(round(min(max(cx - side / 2, 0), w - side)))
    t = int(round(min(max(cy - side / 2, 0), h - side)))
    return (l, t, l + int(side), t + int(side))


def prepare(path, focus):
    im = Image.open(path).convert("RGBA")
    if focus:
        return im.crop(squarify(focus, im.width, im.height)).resize(
            (SIZE, SIZE), Image.LANCZOS)
    # A cut-out that fills its own frame cannot be padded by cropping wider —
    # there is nothing wider. Re-mount it on a larger square of its own
    # background, which is seamless because that background is flat. 1.4 puts
    # the subject at ~71% of the frame, which is what clears the circle.
    l, t, r, b = subject_box(im)
    subject = im.crop((l, t, r, b))
    side = int(max(r - l, b - t) * 1.4)
    canvas = Image.new("RGBA", (side, side), im.getpixel((0, 0)))
    canvas.alpha_composite(
        subject, ((side - subject.width) // 2, (side - subject.height) // 2))
    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def encode(img):
    """JPEG, not PNG. The art pack is PNG because flat vector art compresses
    losslessly to ~3 KB a file; a photograph does not, and the same three
    pictures came to 844 KB as PNG against 66 KB as JPEG — more than every
    stage-1 illustration combined, for three answers. None of the sources has
    real transparency, so there is nothing to lose by flattening."""
    buf = io.BytesIO()
    img.convert("RGB").save(buf, "JPEG", quality=86, optimize=True,
                            progressive=True)
    return buf.getvalue()


def write_preview(images, path):
    """The crops as the app masks them: circular, at the 58dp answer disc on a
    3x screen, over the disc's pale gold."""
    d, ss = 174, 4
    sheet = Image.new("RGBA", (d * len(images) + 20 * (len(images) + 1), d + 40),
                      (253, 246, 236, 255))
    mask = Image.new("L", (d * ss, d * ss), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, d * ss - 1, d * ss - 1), fill=255)
    for i, img in enumerate(images):
        disc = Image.new("RGBA", (d * ss, d * ss), (255, 240, 205, 255))
        disc.alpha_composite(img.resize((d * ss, d * ss), Image.LANCZOS))
        disc.putalpha(mask)
        sheet.alpha_composite(disc.resize((d, d), Image.LANCZOS),
                              (20 + i * (d + 20), 20))
    sheet.save(path)
    print(f"preview -> {path}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source", help="directory holding the source photographs")
    ap.add_argument("--check", action="store_true",
                    help="report whether the bundled files are up to date")
    ap.add_argument("--preview", metavar="PATH",
                    help="also render a disc-masked preview sheet here")
    args = ap.parse_args()

    os.makedirs(OUT_DIR, exist_ok=True)
    stale, images = [], []
    for src_name, (word, focus) in sorted(PLAN.items()):
        src = os.path.join(args.source, src_name)
        if not os.path.exists(src):
            sys.exit(f"missing source photograph: {src}")
        img = prepare(src, focus)
        images.append(img)
        data = encode(img)
        dst = os.path.join(OUT_DIR, f"{word}.jpg")
        current = open(dst, "rb").read() if os.path.exists(dst) else None
        if current == data:
            print(f"{word}.jpg up to date ({len(data) // 1024} KB)")
            continue
        stale.append(word)
        if args.check:
            print(f"{word}.jpg STALE")
            continue
        with open(dst, "wb") as f:
            f.write(data)
        print(f"{src_name} -> {word}.jpg  {len(data) // 1024} KB")

    # Provenance sits beside the files rather than in a doc somewhere, because
    # the question it answers ("may we ship this?") gets asked about the files.
    credits = [
        "Photographs bundled with Watoto",
        "",
        "Source: Unsplash (https://unsplash.com). The Unsplash Licence grants",
        "free use, including commercially, with no attribution required and no",
        "permission needed. Retained here so the provenance of anything that",
        "ships is auditable at release time.",
        "",
        "Cropped and re-encoded by content/prep_photos.py; the originals are",
        "unmodified at the URLs below.",
        "",
    ]
    for src_name, (word, _) in sorted(PLAN.items()):
        credits.append(f"{word}.jpg  <-  {SOURCES.get(src_name, 'UNKNOWN')}")
    credits.append("")
    credits.append("Photographer names are not recorded: the licence does not")
    credits.append("require them and the photo pages are behind a bot check.")
    credits.append("Add them here if you would rather credit by name.")
    sources_path = os.path.join(OUT_DIR, "SOURCES.txt")
    with open(sources_path, "w", encoding="utf-8") as f:
        f.write("\n".join(credits) + "\n")

    if args.preview:
        write_preview(images, args.preview)
    if args.check and stale:
        sys.exit(f"stale: {', '.join(stale)} — rerun without --check")


if __name__ == "__main__":
    main()
