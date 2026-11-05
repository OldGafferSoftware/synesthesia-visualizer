"""Generates the app's ensemble test pieces: public-domain compositions, performed by a
small synthesized orchestra made for this app (so the recordings are ours to use).

    python3 Tools/make_ensemble_music.py

Requires numpy and ffmpeg. Writes .m4a files into SynesthesiaVisualizer/Resources/Music.
"""
import os, subprocess, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "SynesthesiaVisualizer", "Resources", "Music")
rng = np.random.default_rng(7)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def envelope(n, attack, release, decay=None):
    t = np.arange(n) / SR
    env = np.minimum(1, t / max(attack, 1e-3))
    if decay:
        env *= np.exp(-t * decay)
    rel = int(release * SR)
    if 0 < rel < n:
        env[-rel:] *= np.linspace(1, 0, rel)
    return env


def additive(m, dur, amps, vibrato=0.0, detune_cents=0.0, harmonic_decay=None):
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = hz(m) * 2 ** (detune_cents / 1200)
    vib = 1 + vibrato * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.4)
    phase = 2 * np.pi * np.cumsum(np.full(n, f) * vib) / SR
    out = np.zeros(n)
    for k, a in enumerate(amps, start=1):
        if f * k > SR / 2 - 500:
            break
        partial = a * np.sin(k * phase)
        if harmonic_decay:
            partial *= np.exp(-t * harmonic_decay * k)
        out += partial
    return out


# --- Instruments -----------------------------------------------------------

def strings(m, dur, amp=0.2):
    amps = [1 / k for k in range(1, 13)]
    sig = sum(additive(m, dur, amps, vibrato=0.004, detune_cents=c) for c in (-5, 0, 5)) / 3
    return amp * sig * envelope(len(sig), 0.18, min(0.4, dur / 2))


def reed(m, dur, amp=0.25):
    amps = [1 / k if k % 2 else 0.08 / k for k in range(1, 10)]
    sig = additive(m, dur, amps, vibrato=0.002)
    return amp * sig * envelope(len(sig), 0.03, min(0.08, dur / 3))


def brass(m, dur, amp=0.22):
    amps = [1 / k ** 0.7 for k in range(1, 11)]
    sig = additive(m, dur, amps, vibrato=0.003)
    return amp * sig * envelope(len(sig), 0.05, min(0.1, dur / 3))


def flute(m, dur, amp=0.22):
    sig = additive(m, dur, [1, 0.25, 0.08], vibrato=0.006)
    breath = rng.normal(0, 0.03, len(sig)) * envelope(len(sig), 0.02, 0.05, decay=6)
    return amp * (sig + breath) * envelope(len(sig), 0.08, min(0.2, dur / 3))


def pizzicato(m, dur, amp=0.35):
    sig = additive(m, max(dur, 0.6), [1, 0.5, 0.3, 0.15, 0.08], harmonic_decay=2.5)
    return amp * sig * envelope(len(sig), 0.004, 0.05, decay=5)


def harp(m, amp=0.25):
    sig = additive(m, 2.0, [1, 0.6, 0.35, 0.2, 0.1, 0.05], harmonic_decay=1.2)
    return amp * sig * envelope(len(sig), 0.003, 0.1, decay=1.8)


def timpani(m, amp=0.6):
    n = int(SR * 1.4)
    t = np.arange(n) / SR
    f = hz(m) * (1 + 0.15 * np.exp(-t * 25))
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR)
    hit = rng.normal(0, 1, n) * np.exp(-t * 40) * 0.3
    return amp * (tone + hit) * np.exp(-t * 3)


def cymbal(amp=0.18):
    n = int(SR * 2.0)
    t = np.arange(n) / SR
    noise = np.diff(rng.normal(0, 1, n + 1))
    return amp * noise * np.exp(-t * 2.2) * np.minimum(1, t / 0.003)


# --- Mixing ----------------------------------------------------------------

def place(track, sig, start):
    i = int(start * SR)
    if i >= len(track):
        return
    j = min(len(track), i + len(sig))
    track[i:j] += sig[: j - i]


def reverb(x, seconds=1.8, wet=0.22):
    n = int(SR * seconds)
    t = np.arange(n) / SR
    ir = rng.normal(0, 1, n) * np.exp(-t * 3.5)
    ir[0] = 0
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    tail = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)]
    tail *= np.max(np.abs(x)) / max(1e-9, np.max(np.abs(tail)))
    return x * (1 - wet) + tail * wet


def save(name, track):
    track = reverb(track)
    track = track / max(1e-9, np.max(np.abs(track))) * 0.85
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((track * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "aac", "-b:a", "160k",
                    os.path.join(OUT, name + ".m4a")], check=True)
    os.remove(wav)


# --- Grieg: In the Hall of the Mountain King (1875) ------------------------
# Speeds up from slow and quiet to fast and loud, adding instruments as it goes:
# a good test for effects that follow the music's tempo.

def mountain_king():
    bars = [
        ([59, 61, 62, 64, 66, 62, 66], [1, 1, 1, 1, 1, 1, 2]),
        ([65, 61, 65, 64, 60, 64], [1, 1, 2, 1, 1, 2]),
        ([59, 61, 62, 64, 66, 62, 66, 71], [1, 1, 1, 1, 1, 1, 1, 1]),
        ([69, 66, 62, 66, 69], [1, 1, 1, 1, 4]),
    ]
    repeats = 10
    tempos = np.linspace(84, 200, repeats)      # beats per minute, per phrase
    starts = []
    t = 0.0
    for bpm in tempos:
        starts.append(t)
        t += 16 * 60 / bpm                       # 4 bars of 4 beats
    track = np.zeros(int(SR * (t + 3)))

    for r, (bpm, t0) in enumerate(zip(tempos, starts)):
        eighth = 30 / bpm
        loud = 0.35 + 0.65 * r / (repeats - 1)
        octave = 12 if r % 2 else 0
        when = t0
        for notes, lengths in bars:
            for m, l in zip(notes, lengths):
                d = l * eighth * 0.9
                place(track, reed(m - 12 + octave, d, 0.22 * loud), when)          # bassoon-like
                if r >= 2:
                    place(track, strings(m + octave, d, 0.14 * loud), when)
                if r >= 5:
                    place(track, brass(m + 12, d, 0.12 * loud), when)
                if r >= 7:
                    place(track, flute(m + 24, d, 0.08 * loud), when)
                when += l * eighth
        # Low pizzicato and, later, timpani on every beat.
        for b in range(16):
            root = 47 if (b // 2) % 2 == 0 else 42
            place(track, pizzicato(root - 12 + (12 if r >= 4 else 0), 2 * eighth, 0.3 * loud), t0 + b * 2 * eighth)
            if r >= 4:
                place(track, timpani(root - 12, 0.35 * loud), t0 + b * 2 * eighth)
        if r >= 6:
            place(track, cymbal(0.12 * loud), t0)
    # The final crash.
    end = starts[-1] + 16 * 60 / tempos[-1]
    for m in (47, 54, 59, 62, 66, 71):
        place(track, brass(m, 1.6, 0.18), end)
        place(track, strings(m + 12, 1.6, 0.15), end)
    place(track, timpani(35, 0.8), end)
    place(track, cymbal(0.3), end)
    save("grieg-mountain-king", track)


# --- Pachelbel: Canon in D (c. 1680-1706) ----------------------------------
# Slow and lush: string chords, cello bass, a violin melody, harp and flute.

def canon():
    beat = 60 / 64
    chord_len = 2 * beat
    bass = [50, 45, 47, 42, 43, 38, 43, 45]
    chords = [[62, 66, 69], [61, 64, 69], [62, 66, 71], [61, 66, 69],
              [62, 67, 71], [62, 66, 69], [62, 67, 71], [61, 64, 69]]
    melody_1 = [78, 76, 74, 73, 71, 69, 71, 73]
    melody_2 = [74, 73, 71, 69, 67, 66, 67, 64]
    cycles = 5
    track = np.zeros(int(SR * (cycles * 8 * chord_len + 4)))
    for c in range(cycles):
        for i in range(8):
            t0 = (c * 8 + i) * chord_len
            place(track, strings(bass[i] - 12, chord_len, 0.22), t0)               # cello
            for m in chords[i]:
                place(track, strings(m - 12, chord_len, 0.07), t0)                 # string chords
            if c >= 1:
                place(track, strings(melody_1[i], chord_len, 0.13), t0)            # violin 1
            if c >= 2:
                place(track, strings(melody_2[i], chord_len, 0.1), t0 + beat)      # violin 2, a beat later
            if c >= 3:
                arp = [chords[i][0], chords[i][1], chords[i][2], chords[i][1] + 12]
                for k, m in enumerate(arp):                                        # harp
                    place(track, harp(m, 0.18), t0 + k * beat / 2)
            if c >= 4:
                run = [melody_1[i] + 2, melody_1[i], melody_1[i] - 1, melody_1[i] - 3]
                for k, m in enumerate(run):                                        # flute
                    place(track, flute(m, beat / 2 * 0.95, 0.1), t0 + k * beat / 2)
    save("pachelbel-canon", track)


if __name__ == "__main__":
    mountain_king()
    canon()
    print("done")
