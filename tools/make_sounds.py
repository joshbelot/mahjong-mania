#!/usr/bin/env python3
"""Writes the Practice sound effects (SPEC §18.7) as short 16-bit mono WAV files.

Pure Python (standard library only): every sound is a few synthesised tones with a decay, so they are
original and tiny. Run from the repository root:

    python3 tools/make_sounds.py

The files go to App/Resources/Sounds/ and are committed; the app plays them with AVAudioPlayer on an
ambient audio session (muted by the silent switch, other audio keeps playing). Every sound is under 0.6 s.
"""
import math
import os
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "App", "Resources", "Sounds")


def tone(freq, length, volume=0.5, decay=6.0, partials=((1, 1.0), (2, 0.35), (3, 0.12)), glide=1.0, attack=0.004):
    """One note: a few harmonics with an exponential decay and a short attack; `glide` bends the pitch."""
    n = int(RATE * length)
    out = []
    phase = [0.0] * len(partials)
    for i in range(n):
        t = i / RATE
        f = freq * (1 + (glide - 1) * (i / n))
        env = min(1.0, t / attack) * math.exp(-decay * t / length)
        sample = 0.0
        for k, (mult, amp) in enumerate(partials):
            phase[k] += 2 * math.pi * f * mult / RATE
            sample += amp * math.sin(phase[k])
        out.append(sample * env * volume)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


def delay(samples, seconds):
    return [0.0] * int(RATE * seconds) + samples


def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = min(1.0, 0.9 / peak)
    # A 5 ms fade-out so no sound ends on a click.
    fade = int(RATE * 0.005)
    for i in range(fade):
        samples[-1 - i] *= i / fade
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))
    print(f"{name}.wav  {len(samples) / RATE:.2f}s")


C6, E6, G6, C7 = 1046.5, 1318.5, 1568.0, 2093.0
C5, E5, G5 = 523.25, 659.25, 783.99

os.makedirs(OUT, exist_ok=True)

# Right answer: a bright two-note "ding".
write("right", mix(tone(880, 0.30, 0.45, decay=7), delay(tone(1318.5, 0.34, 0.45, decay=7), 0.07)))

# Wrong answer: a soft low "bonk", never harsh.
write("wrong", mix(tone(190, 0.26, 0.6, decay=9, partials=((1, 1.0), (2, 0.2)), glide=0.62), tone(95, 0.2, 0.35, decay=10, partials=((1, 1.0),))))

# Combo: a quick rising arpeggio.
write("combo", mix(*[delay(tone(f, 0.18, 0.35, decay=6), i * 0.07) for i, f in enumerate([C6, E6, G6, C7])]))

# Stars: one chime each, rising.
for i, f in enumerate([C6, E6, G6], start=1):
    write(f"star{i}", mix(tone(f, 0.4, 0.5, decay=6), tone(f * 2, 0.4, 0.15, decay=8, partials=((1, 1.0),))))

# Level up, milestone, badge: a short fanfare.
write(
    "fanfare",
    mix(
        tone(C5, 0.2, 0.4, decay=4),
        delay(tone(E5, 0.2, 0.4, decay=4), 0.11),
        delay(tone(G5, 0.2, 0.4, decay=4), 0.22),
        delay(tone(C6, 0.25, 0.5, decay=4), 0.33),
        delay(tone(E6, 0.25, 0.3, decay=4), 0.33),
    ),
)

# A node unlocking: a quick pop.
write("unlock", tone(520, 0.16, 0.5, decay=8, partials=((1, 1.0), (2, 0.3)), glide=1.8))
