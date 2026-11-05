# Synesthesia Visualizer

A Vision Pro app that helps people with music-colour synesthesia (chromesthesia) recreate what they see when they hear music. Effects float in your real room, react to the music live, and can be saved as presets and recorded.

This is the **testing prototype**: enough to put in front of people with synesthesia and learn what to build next.

## What's in the prototype

- **Mixed reality stage.** "Show in my room" opens effects in your space, with your room still visible.
- **Music.** Two built-in test pieces (a note-by-note scale and a simple *Ode to Joy*), plus import of your own audio files.
- **Live audio analysis.** Volume, bass / middle / treble, the strongest note (C to B) and beats, measured as the music plays.
- **Three effects.** Floating orbs (each tied to a note), flowing light (glowing strands that braid like water, one colour per strong note, rising with higher sounds), and bursts on the beat.
- **Note colours.** Choose a colour for each of the 12 notes, with a live readout of which note is sounding.
- **Effect controls.** Type, placement (in front, all around, above), colour, opacity, size, speed, what it reacts to, sensitivity.
- **Presets.** Save, reopen and share (as a small JSON file) the full setup, including the music.
- **Recording.** In-app steps for Vision Pro's built-in Record My View.

## Building and running

Needs a Mac with **Xcode 16 or later** (with the visionOS SDK installed).

1. Clone this repo and open `SynesthesiaVisualizer.xcodeproj`.
2. In the target's *Signing & Capabilities*, check the team is your Apple Developer team (preset to `D3235769G5`).
3. Pick the **Apple Vision Pro** simulator, or your headset, and press Run.

The simulator is fine for the windows and effects. Passthrough of a real room and realistic audio need the headset.

To regenerate the test music: `python3 Tools/make_test_music.py` (needs numpy and ffmpeg).

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
