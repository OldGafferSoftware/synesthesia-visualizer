"""Shared helpers: write an arrangement as MIDI and render it with sampled instruments.

Uses FluidSynth and the FluidR3 GM soundfont (MIT licence, Frank Wen). On Ubuntu/Debian:
    sudo apt-get install fluidsynth fluid-soundfont-gm && pip install mido
"""
import os, subprocess, tempfile
import mido

OUT = os.path.join(os.path.dirname(__file__), "..", "SynesthesiaVisualizer", "Resources", "Music")
SOUNDFONT = "/usr/share/sounds/sf2/FluidR3_GM.sf2"
TPB = 480  # ticks per quarter note

# General MIDI programs used here.
PIANO, VIBRAPHONE, VIOLIN, CELLO, CONTRABASS, PIZZICATO, HARP, TIMPANI = 0, 11, 40, 42, 43, 45, 46, 47
STRINGS, TRUMPET, TROMBONE, HORN, BRASS = 48, 56, 57, 60, 61
OBOE, BASSOON, CLARINET, PICCOLO, FLUTE = 68, 70, 71, 72, 73
DRUMS = 9  # the percussion channel
CRASH, BASS_DRUM, SNARE = 49, 36, 38


def ticks(beat):
    return int(round(beat * TPB))


class Part:
    """One instrument's notes, as (tick, message) events."""

    def __init__(self, name, program, channel, pan=64, volume=100, reverb=70):
        self.name, self.program, self.channel = name, program, channel
        self.pan, self.volume, self.reverb = pan, volume, reverb
        self.events = []

    def note(self, start, length, pitch, velocity=80, legato=0.95):
        velocity = max(1, min(127, int(velocity)))
        self.events.append((ticks(start), mido.Message("note_on", note=pitch, velocity=velocity, channel=self.channel)))
        self.events.append((ticks(start + length * legato),
                            mido.Message("note_off", note=pitch, velocity=0, channel=self.channel)))

    def track(self):
        t = mido.MidiTrack()
        t.append(mido.MetaMessage("track_name", name=self.name, time=0))
        if self.channel != DRUMS:
            t.append(mido.Message("program_change", program=self.program, channel=self.channel, time=0))
        for control, value in ((10, self.pan), (7, self.volume), (91, self.reverb)):
            t.append(mido.Message("control_change", control=control, value=value, channel=self.channel, time=0))
        now = 0
        # note_offs before note_ons at the same tick, so repeated notes retrigger cleanly
        for tick, msg in sorted(self.events, key=lambda x: (x[0], x[1].type == "note_on")):
            t.append(msg.copy(time=tick - now))
            now = tick
        return t


def song(parts, tempo_changes):
    """tempo_changes: list of (beat, bpm), starting at beat 0."""
    mid = mido.MidiFile(ticks_per_beat=TPB)
    tempo = mido.MidiTrack()
    now = 0
    for beat, bpm in sorted(tempo_changes):
        tick = ticks(beat)
        tempo.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(bpm), time=tick - now))
        now = tick
    mid.tracks.append(tempo)
    for part in parts:
        mid.tracks.append(part.track())
    return mid


def render(mid, name, reverb_level=0.6):
    with tempfile.TemporaryDirectory() as tmp:
        midi_path = os.path.join(tmp, name + ".mid")
        wav_path = os.path.join(tmp, name + ".wav")
        mid.save(midi_path)
        subprocess.run(["fluidsynth", "-ni", "-g", "0.6", "-r", "44100",
                        "-o", "synth.reverb.room-size=0.75", "-o", f"synth.reverb.level={reverb_level}",
                        "-F", wav_path, SOUNDFONT, midi_path], check=True, stdout=subprocess.DEVNULL)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
                        "-af", "silenceremove=stop_periods=1:stop_threshold=-60dB:stop_duration=1,loudnorm=I=-16:TP=-1.5",
                        "-ar", "44100", "-c:a", "aac", "-b:a", "192k", os.path.join(OUT, name + ".m4a")], check=True)
