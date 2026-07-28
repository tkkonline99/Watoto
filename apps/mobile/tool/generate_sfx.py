"""Regenerates the app's interaction sound effects (WAV, 16-bit mono 44.1kHz).

Synthesis: additive sine partials with a soft attack and exponential decay, so
each note reads as a gentle bell/marimba rather than a beep. Three tonal
styles are produced side by side for audition; the shipped set is whichever
style is copied into assets/audio/sfx (currently warm-marimba).

Usage (from apps/mobile):
    python tool/generate_sfx.py branding/sfx-variants
    # then to ship a style:
    #   Copy-Item branding\\sfx-variants\\<style>\\*.wav assets\\audio\\sfx\\ -Force

Recipes are declared per style in STYLES: harmonics (relative partial
amplitudes), then (frequency Hz, duration s, decay s) per note.
"""
import math
import os
import struct
import sys
import wave

SR = 44100


def note(freq, dur, harmonics, decay, attack_ms=6.0):
    n = int(SR * dur)
    attack = max(1, int(SR * attack_ms / 1000))
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t / decay)
        if i < attack:
            env *= i / attack
        s = 0.0
        for k, amp in enumerate(harmonics, start=1):
            if amp:
                s += amp * math.sin(2 * math.pi * freq * k * t)
        out.append(env * s)
    return out


def normalize(samples, peak=0.72):
    hi = max(1e-9, max(abs(s) for s in samples))
    return [s * peak / hi for s in samples]


def write_wav(path, samples):
    samples = normalize(samples)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767))
        w.writeframes(bytes(frames))
    print(f"wrote {path} ({len(samples)/SR*1000:.0f} ms)")


def seq(*chunks):
    out = []
    for c in chunks:
        out += c
    return out


STYLES = {
    # Glassy, rounded (C major, mid register).
    "bell": dict(
        harmonics=(1.0, 0.5, 0.25),
        tap_harmonics=(1.0, 0.35),  # softer partials for the little pop
        tap=(560, 0.14, 0.045),
        correct=[(1046.50, 0.16, 0.10), (1318.51, 0.34, 0.16)],
        celebrate=[(523.25, 0.13, 0.09), (659.25, 0.13, 0.09),
                   (783.99, 0.13, 0.09), (1046.50, 0.42, 0.22)],
    ),
    # Woodier and softer; the strong 4th partial is marimba-like (G major,
    # low register). This is the shipped set (assets/audio/sfx).
    "warm-marimba": dict(
        harmonics=(1.0, 0.25, 0.0, 0.18),
        tap=(392.00, 0.14, 0.035),
        correct=[(783.99, 0.16, 0.07), (987.77, 0.32, 0.11)],
        celebrate=[(392.00, 0.13, 0.06), (493.88, 0.13, 0.06),
                   (587.33, 0.13, 0.06), (783.99, 0.40, 0.15)],
        # A rising fifth-to-octave fanfare, longer and brighter than the
        # per-activity celebration so a level genuinely feels bigger.
        levelup=[(392.00, 0.12, 0.06), (587.33, 0.12, 0.06),
                 (783.99, 0.12, 0.07), (1174.66, 0.55, 0.22)],
        # Coins: two quick high taps, the "it landed" confirmation.
        coin=[(1174.66, 0.09, 0.045), (1567.98, 0.18, 0.07)],
        # Streak: a warm ascending triad, proud rather than urgent.
        streak=[(493.88, 0.14, 0.08), (587.33, 0.14, 0.08),
                (739.99, 0.36, 0.16)],
        # Not-quite: a gentle *downward* step. Deliberately soft and short —
        # a wrong answer from a five-year-old should sound like "try again",
        # never like a buzzer.
        retry=[(440.00, 0.12, 0.06), (392.00, 0.20, 0.09)],
    ),
    # Plucky and sparkly; sparse harmonics, longer ring (A major, high).
    "bright-kalimba": dict(
        harmonics=(1.0, 0.15, 0.08),
        tap=(880.00, 0.13, 0.055),
        correct=[(1760.00, 0.15, 0.12), (2217.46, 0.34, 0.18)],
        celebrate=[(880.00, 0.12, 0.10), (1108.73, 0.12, 0.10),
                   (1318.51, 0.12, 0.10), (1760.00, 0.42, 0.24)],
    ),
}


def main(outdir):
    for name, r in STYLES.items():
        d = os.path.join(outdir, name)
        os.makedirs(d, exist_ok=True)
        h = r["harmonics"]
        f, dur, dec = r["tap"]
        write_wav(os.path.join(d, "tap.wav"),
                  note(f, dur, r.get("tap_harmonics", h), dec, attack_ms=3))
        write_wav(os.path.join(d, "correct.wav"),
                  seq(*[note(f, dur, h, dec) for f, dur, dec in r["correct"]]))
        write_wav(os.path.join(d, "celebrate.wav"),
                  seq(*[note(f, dur, h, dec) for f, dur, dec in r["celebrate"]]))
        # Optional per-style extras: only the shipped style defines these, so
        # auditioning a new tonal style does not require redrawing all of them.
        for key in ("levelup", "coin", "streak", "retry"):
            if key not in r:
                continue
            write_wav(
                os.path.join(d, f"{key}.wav"),
                seq(*[note(f, dur, h, dec) for f, dur, dec in r[key]]),
            )


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "branding/sfx-variants")
