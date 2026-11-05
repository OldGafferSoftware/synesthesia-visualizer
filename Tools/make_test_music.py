"""Generates the app's two built-in test pieces (our own synthesized performances,
so there are no copyright questions). Run: python3 Tools/make_test_music.py
Requires numpy and ffmpeg. Writes .m4a files into SynesthesiaVisualizer/Resources/Music."""
import os, subprocess, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "SynesthesiaVisualizer", "Resources", "Music")

def midi_hz(m): return 440.0 * 2 ** ((m - 69) / 12)

def tone(m, dur, amp=0.3, bright=1.0):
    t = np.arange(int(SR * dur)) / SR
    f = midi_hz(m)
    sig = sum((bright ** (k - 1)) / k * np.sin(2 * np.pi * f * k * t) for k in range(1, 6))
    env = np.minimum(1, t / 0.01) * np.exp(-2.5 * t / max(dur, 0.1))
    return amp * sig * env

def kick(dur=0.3):
    t = np.arange(int(SR * dur)) / SR
    f = 120 * np.exp(-t * 20) + 45
    return 0.6 * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 12)

def place(track, sig, start):
    i = int(start * SR)
    j = min(len(track), i + len(sig))
    track[i:j] += sig[: j - i]

def save(name, track):
    track = track / max(1e-9, np.max(np.abs(track))) * 0.8
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((track * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "aac", "-b:a", "128k",
                    os.path.join(OUT, name + ".m4a")], check=True)
    os.remove(wav)

# 1. Note-by-note scale: every one of the 12 notes, low to high, then one octave higher.
notes = list(range(60, 72)) + list(range(72, 84))
scale = np.zeros(int(SR * (len(notes) * 1.0 + 1)))
for i, m in enumerate(notes):
    place(scale, tone(m, 0.95), i * 1.0)
save("test-twelve-notes", scale)

# 2. "Ode to Joy" (Beethoven, public domain) with bass, chords and a steady beat.
melody = [64,64,65,67,67,65,64,62,60,60,62,64,64,62,62, 64,64,65,67,67,65,64,62,60,60,62,64,62,60,60]
lengths = [1,1,1,1,1,1,1,1,1,1,1,1,1.5,0.5,2, 1,1,1,1,1,1,1,1,1,1,1,1,1.5,0.5,2]
beat = 0.5
total = sum(lengths) * beat
ode = np.zeros(int(SR * (total * 2 + 2)))
for rep in range(2):
    t0 = rep * total
    t = t0
    for m, l in zip(melody, lengths):
        place(ode, tone(m + 12 * rep, l * beat, 0.35, 0.6 + 0.3 * rep), t)
        t += l * beat
    for b in range(int(sum(lengths))):
        place(ode, kick(), t0 + b * beat)
        chord_root = [48, 43, 48, 43][(b // 4) % 4]
        if b % 2 == 0:
            for m in (chord_root, chord_root + 4 if chord_root == 48 else chord_root + 4, chord_root + 7):
                place(ode, tone(m, beat * 2, 0.12, 0.4), t0 + b * beat)
save("ode-to-joy-synth", ode)
print("done")
