"""Renders Pachelbel's Canon in D (public domain) with sampled instruments.

Writes an arrangement as MIDI, then plays it through FluidSynth with the FluidR3 GM
soundfont (MIT licence, Frank Wen). On Ubuntu/Debian:

    sudo apt-get install fluidsynth fluid-soundfont-gm && pip install mido
    python3 Tools/make_canon.py
"""
import os, subprocess, tempfile
import mido

OUT = os.path.join(os.path.dirname(__file__), "..", "SynesthesiaVisualizer", "Resources", "Music")
SOUNDFONT = "/usr/share/sounds/sf2/FluidR3_GM.sf2"
TPB = 480            # ticks per quarter note
BPM = 56

# The ground bass and its chords, one per beat, repeating every two bars.
BASS = [50, 45, 47, 42, 43, 38, 43, 45]                      # D A B F# G D G A
CHORDS = [[62, 66, 69], [61, 64, 69], [62, 66, 71], [61, 66, 69],
          [62, 67, 71], [62, 66, 69], [62, 67, 71], [61, 64, 69]]

# Two-bar melodic variations: lists of (midi note, length in beats).
def q(*notes):  return [(n, 1.0) for n in notes]
def e(*notes):  return [(n, 0.5) for n in notes]
def s(*notes):  return [(n, 0.25) for n in notes]

VARIATIONS = [
    q(78, 76, 74, 73, 71, 69, 71, 73),
    q(74, 73, 71, 69, 67, 66, 67, 64),
    e(62, 66, 69, 67, 66, 62, 66, 64, 62, 59, 62, 69, 67, 71, 69, 67),
    e(69, 74, 73, 76, 74, 78, 73, 69, 71, 74, 69, 66, 67, 71, 69, 73),
    s(78, 76, 74, 73, 76, 74, 73, 71, 74, 73, 71, 69, 69, 73, 76, 73,
      71, 69, 67, 66, 69, 67, 66, 64, 62, 67, 71, 74, 73, 76, 81, 79),
    q(86, 85, 83, 81, 79, 78, 79, 76),
    q(78, 76, 74, 73, 71, 69, 71, 73),
]
BARS_PER_VARIATION = 2
VOICE_OFFSET_BARS = 2          # each violin enters two bars after the one before


def beats(b):
    return int(round(b * TPB))


def add_note(events, start_beat, length_beats, note, velocity, channel, legato=0.95):
    events.append((beats(start_beat), mido.Message("note_on", note=note, velocity=velocity, channel=channel)))
    events.append((beats(start_beat + length_beats * legato), mido.Message("note_off", note=note, velocity=0, channel=channel)))


def track_from(events, name, program, channel, pan, volume=100, reverb=70):
    track = mido.MidiTrack()
    track.append(mido.MetaMessage("track_name", name=name, time=0))
    track.append(mido.Message("program_change", program=program, channel=channel, time=0))
    track.append(mido.Message("control_change", control=10, value=pan, channel=channel, time=0))
    track.append(mido.Message("control_change", control=7, value=volume, channel=channel, time=0))
    track.append(mido.Message("control_change", control=91, value=reverb, channel=channel, time=0))
    now = 0
    for tick, msg in sorted(events, key=lambda x: (x[0], x[1].type == "note_on")):
        track.append(msg.copy(time=tick - now))
        now = tick
    return track


def build():
    voices = 3
    melody_bars = len(VARIATIONS) * BARS_PER_VARIATION
    total_bars = melody_bars + VOICE_OFFSET_BARS * (voices - 1) + 2   # a two-bar opening for the bass
    end_beat = total_bars * 4

    mid = mido.MidiFile(ticks_per_beat=TPB)
    tempo = mido.MidiTrack()
    tempo.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(BPM), time=0))
    # A gentle slowing into the final chord.
    tempo.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(BPM * 0.85), time=beats(end_beat - 2)))
    mid.tracks.append(tempo)

    cello, pad, harp = [], [], []
    for beat in range(end_beat):
        i = beat % 8
        add_note(cello, beat, 1, BASS[i] - 12, 78, channel=0)
        add_note(cello, beat, 1, BASS[i], 52, channel=0)
        if beat % 2 == 0:
            for n in CHORDS[i]:
                add_note(pad, beat, 2, n - 12, 38, channel=1, legato=1.0)
        if beat >= 16:
            for k, n in enumerate(CHORDS[i] + [CHORDS[i][0] + 12]):
                add_note(harp, beat + k * 0.25, 1.2, n, 46 + 6 * (k == 0), channel=2, legato=1.0)
    # Final D major chord.
    for n in (38, 50, 62, 66, 69, 74):
        add_note(cello if n < 55 else pad, end_beat, 4, n, 70, channel=0 if n < 55 else 1, legato=1.0)

    mid.tracks.append(track_from(cello, "Cello", 42, 0, pan=48, volume=105))
    mid.tracks.append(track_from(pad, "Strings", 48, 1, pan=64, volume=80))
    mid.tracks.append(track_from(harp, "Harp", 46, 2, pan=80, volume=75))

    pans = [40, 88, 64]
    for v in range(voices):
        events = []
        t = (2 + v * VOICE_OFFSET_BARS) * 4
        for variation in VARIATIONS:
            for note, length in variation:
                velocity = 84 if length >= 1 else 74
                add_note(events, t, length, note, velocity, channel=3 + v)
                t += length
        events_end = t
        add_note(events, events_end, 4, [74, 78, 81][v], 70, channel=3 + v, legato=1.0)
        mid.tracks.append(track_from(events, f"Violin {v + 1}", 40, 3 + v, pan=pans[v], volume=100))
    return mid


def render(mid, name):
    with tempfile.TemporaryDirectory() as tmp:
        midi_path = os.path.join(tmp, name + ".mid")
        wav_path = os.path.join(tmp, name + ".wav")
        mid.save(midi_path)
        subprocess.run(["fluidsynth", "-ni", "-g", "0.6", "-r", "44100", "-o", "synth.reverb.room-size=0.75",
                        "-o", "synth.reverb.level=0.6", "-F", wav_path, SOUNDFONT, midi_path], check=True,
                       stdout=subprocess.DEVNULL)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
                        "-af", "silenceremove=stop_periods=1:stop_threshold=-60dB:stop_duration=1,loudnorm=I=-16:TP=-1.5",
                        "-ar", "44100", "-c:a", "aac", "-b:a", "192k", os.path.join(OUT, name + ".m4a")], check=True)


if __name__ == "__main__":
    render(build(), "pachelbel-canon")
    print("done")
