"""Renders the built-in pieces (all public-domain compositions) with sampled instruments.

    python3 Tools/make_sampled_music.py

See midi_render.py for what to install. Canon in D is in make_canon.py.
"""
import numpy as np
from midi_render import *


# --- Grieg: In the Hall of the Mountain King (1875) ------------------------
# Starts slow and quiet on bassoon and pizzicato, then speeds up and grows, bar by bar,
# to full orchestra: a good test for effects that follow the music's tempo.

def mountain_king():
    phrase = [
        ([59, 61, 62, 64, 66, 62, 66], [1, 1, 1, 1, 1, 1, 2]),
        ([65, 61, 65, 64, 60, 64], [1, 1, 2, 1, 1, 2]),
        ([59, 61, 62, 64, 66, 62, 66, 71], [1, 1, 1, 1, 1, 1, 1, 1]),
        ([69, 66, 62, 66, 69], [1, 1, 1, 1, 4]),
    ]  # in eighth notes; four bars of 4/4
    repeats = 10
    bars = repeats * 4
    tempos = [(bar * 4, float(bpm)) for bar, bpm in enumerate(np.linspace(84, 200, bars))]

    bassoon = Part("Bassoon", BASSOON, 0, pan=56, volume=110)
    pizz = Part("Pizzicato", PIZZICATO, 1, pan=72, volume=105)
    strings = Part("Strings", STRINGS, 2, pan=64, volume=95)
    brass = Part("Brass", BRASS, 3, pan=80, volume=95)
    piccolo = Part("Piccolo", PICCOLO, 4, pan=44, volume=80)
    timpani = Part("Timpani", TIMPANI, 5, pan=64, volume=110)
    drums = Part("Cymbals", 0, DRUMS, pan=64, volume=90)

    for r in range(repeats):
        start = r * 16
        loud = 0.45 + 0.55 * r / (repeats - 1)
        octave = 12 if r % 2 else 0
        beat = start
        for notes, lengths in phrase:
            for m, l in zip(notes, lengths):
                d = l / 2
                staccato = 0.6 if l == 1 else 0.85
                bassoon.note(beat, d, m - 12 + octave, 90 * loud, staccato)
                if r >= 2:
                    strings.note(beat, d, m + octave, 85 * loud, staccato)
                if r >= 5:
                    brass.note(beat, d, m + 12, 95 * loud, staccato)
                if r >= 7:
                    piccolo.note(beat, d, m + 24, 80 * loud, staccato)
                beat += d
        for b in range(16):
            root = 47 if (b // 2) % 2 == 0 else 42
            pizz.note(start + b, 1, root - 12 + (12 if r >= 4 else 0), 95 * loud, 0.5)
            if r >= 4:
                timpani.note(start + b, 1, root - 12, 100 * loud, 0.6)
        if r >= 6:
            drums.note(start, 1, CRASH, 100 * loud)

    # The final crash.
    end = repeats * 16
    for m in (47, 54, 59, 62, 66, 71):
        brass.note(end, 3, m, 120, 1.0)
        strings.note(end, 3, m + 12, 115, 1.0)
    timpani.note(end, 3, 35, 127, 1.0)
    drums.note(end, 3, CRASH, 127)
    drums.note(end, 1, BASS_DRUM, 127)
    tempos.append((end, 120))

    render(song([bassoon, pizz, strings, brass, piccolo, timpani, drums], tempos), "grieg-mountain-king")


# --- Beethoven: Ode to Joy (Symphony No. 9, 1824) ---------------------------
# First verse softly on clarinet with strings; second verse full orchestra.

def ode_to_joy():
    melody = [64, 64, 65, 67, 67, 65, 64, 62, 60, 60, 62, 64, 64, 62, 62,
              64, 64, 65, 67, 67, 65, 64, 62, 60, 60, 62, 64, 62, 60, 60]
    lengths = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5, 0.5, 2,
               1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5, 0.5, 2]
    harmony = ["C", "G", "C", "G", "C", "G", "C", "GC"]          # one per bar
    chords = {"C": [48, 52, 55], "G": [43, 50, 55]}
    bass_root = {"C": 36, "G": 31}

    clarinet = Part("Clarinet", CLARINET, 0, pan=50, volume=105)
    violins = Part("Violins", VIOLIN, 1, pan=40, volume=105)
    trumpet = Part("Trumpet", TRUMPET, 2, pan=78, volume=90)
    horns = Part("Horns", HORN, 3, pan=70, volume=90)
    strings = Part("Strings", STRINGS, 4, pan=64, volume=85)
    cello = Part("Cello", CELLO, 5, pan=58, volume=100)
    timpani = Part("Timpani", TIMPANI, 6, pan=64, volume=100)
    flute = Part("Flute", FLUTE, 7, pan=30, volume=80)

    for verse in range(2):
        start = verse * 32
        beat = start
        for m, l in zip(melody, lengths):
            if verse == 0:
                clarinet.note(beat, l, m, 88, 0.92)
            else:
                violins.note(beat, l, m + 12, 100, 0.92)
                trumpet.note(beat, l, m, 92, 0.9)
            beat += l
        for bar, h in enumerate(harmony):
            b0 = start + bar * 4
            parts = [h] if len(h) == 1 else [h[0], h[1]]
            for k, name in enumerate(parts):
                span = 4 / len(parts)
                t0 = b0 + k * span
                for n in chords[name]:
                    strings.note(t0, span, n + 12, 55 if verse == 0 else 70, 1.0)
                    if verse == 1:
                        horns.note(t0, span, n + 12, 75, 1.0)
                for q in range(int(span)):
                    cello.note(t0 + q, 1, bass_root[name] + (12 if q % 2 else 0), 70 if verse == 0 else 90, 0.8)
                if verse == 1:
                    timpani.note(t0, 1, bass_root[name] + 12 if name == "C" else bass_root[name] + 12, 95, 0.7)
                    flute.note(t0, span, chords[name][2] + 24, 60, 1.0)
    end = 64
    for n in (36, 48, 52, 55, 60, 64, 72):
        strings.note(end, 4, n, 100, 1.0)
        horns.note(end, 4, n, 90, 1.0)
    violins.note(end, 4, 84, 100, 1.0)
    trumpet.note(end, 4, 72, 95, 1.0)
    timpani.note(end, 2, 36, 120, 1.0)

    render(song([clarinet, violins, trumpet, horns, strings, cello, timpani, flute],
                [(0, 104), (32, 112), (62, 96)]), "ode-to-joy")


# --- The twelve notes, for checking colours ---------------------------------
# Each note held for a second on a clear, steady instrument (flute), C to B, then the octave above.

def twelve_notes():
    flute = Part("Flute", FLUTE, 0, pan=64, volume=110, reverb=30)
    for i, m in enumerate(list(range(60, 72)) + list(range(72, 84))):
        flute.note(i, 1, m, 95, 0.9)
    render(song([flute], [(0, 60)]), "test-twelve-notes", reverb_level=0.3)


if __name__ == "__main__":
    mountain_king()
    ode_to_joy()
    twelve_notes()
    print("done")
