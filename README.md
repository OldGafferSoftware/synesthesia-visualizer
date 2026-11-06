# Synesthesia Visualizer

A Vision Pro app that helps people with music-colour synesthesia (chromesthesia) recreate what they see when they hear music. Effects float in your real room, react to the music live, and can be saved as presets and recorded.

This is the **testing prototype**: enough to put in front of people with synesthesia and learn what to build next.

## What's in the prototype

- **Mixed reality stage.** "Show in my room" opens effects in your space, with your room still visible.
- **Music.** Four built-in pieces played with sampled orchestral instruments: Grieg's *In the Hall of the Mountain King* (speeds up from slow to very fast), Pachelbel's *Canon in D*, Beethoven's *Ode to Joy*, and a note-by-note scale on flute for checking colours. You can also import your own audio files.
- **Live audio analysis.** Volume, bass / middle / treble, the strongest note (C to B), beats and tempo, measured as the music plays.
- **Four effects.** Floating orbs (each tied to a note), flowing light (glowing strands that braid like water, one colour per strong note, rising with higher sounds), light-explosion bursts on the beat, and an aurora (shimmering curtains of northern lights).
- **Note colours.** Choose a colour for each of the 12 notes, with a live readout of which note is sounding.
- **Effect controls.** Type, placement (in front, all around, above), colour, opacity, size, speed, whether speed follows the music's tempo, what it reacts to, sensitivity.
- **Help.** A Help screen with a getting-started guide, explanations of each effect and setting, and an FAQ (wording in `Views/HelpPane.swift`).
- **Splash and Info.** A launch page with copyright, a not-medical-advice notice and a flashing-lights warning; the Info button shows it again with a contact email.
- **Presets.** Save, reopen and share (as a small JSON file) the full setup, including the music.
- **Recording.** In-app steps for Vision Pro's built-in Record My View.

## Building and running

Needs a Mac with **Xcode 16 or later** (with the visionOS SDK installed).

1. Clone this repo and open `SynesthesiaVisualizer.xcodeproj`.
2. In the target's *Signing & Capabilities*, check the team is your Apple Developer team (preset to `D3235769G5`).
3. Pick the **Apple Vision Pro** simulator, or your headset, and press Run.

The simulator is fine for the windows and effects. Passthrough of a real room and realistic audio need the headset.

To regenerate the built-in music: `python3 Tools/make_sampled_music.py` and `python3 Tools/make_canon.py` (need FluidSynth, the `fluid-soundfont-gm` soundfont, `mido` and ffmpeg; see `Tools/midi_render.py`).

The app icon (three layers) and logo are in `SynesthesiaVisualizer/Assets.xcassets`; their SVG sources and a renderer are in `Design/`.

## Getting it to testers (TestFlight)

1. In Xcode: *Product → Archive*, then *Distribute App → TestFlight & App Store*.
2. In [App Store Connect](https://appstoreconnect.apple.com), add testers by email under TestFlight.
3. Testers install the TestFlight app on their Vision Pro and accept the invite.

## Project layout

| Folder | What's there |
| --- | --- |
| `SynesthesiaVisualizer/App` | App entry point and the shared app state |
| `SynesthesiaVisualizer/Audio` | Playback and the music analysis |
| `SynesthesiaVisualizer/Effects` | The immersive stage and the three effects (RealityKit) |
| `SynesthesiaVisualizer/Model` | Presets, layers, colours, music library and saving |
| `SynesthesiaVisualizer/Views` | The control window |
| `SynesthesiaVisualizer/Resources/Music` | Built-in music and its licence notes (`catalog.json`) |

New files added under `SynesthesiaVisualizer/` are picked up by Xcode automatically.

## Music and licensing

Only bundle recordings that are free to use: our own synthesized performances, or recordings released into the public domain by the performers. A public-domain composition (for example Beethoven) can still have a copyrighted recording. Every bundled file needs an entry in `catalog.json` with its licence and source. Apple Music can't be used: its audio can't be analysed and is usually muted in recordings.

## Known limits

- Apps can't record the passthrough view themselves, so recording uses the system's Record My View. Whether app audio is captured with it still needs checking on a headset.
- Note detection is approximate, especially for low notes and full orchestras.
- Not a diagnostic tool. It illustrates experiences; it doesn't assess them.
