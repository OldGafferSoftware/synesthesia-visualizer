import SwiftUI

/// Help topics and FAQ. All the wording lives in `HelpContent` so it's easy to edit.
struct HelpPane: View {
    @State private var expandedQuestion: String?

    var body: some View {
        List {
            Section {
                ForEach(HelpContent.gettingStarted.indices, id: \.self) { i in
                    let step = HelpContent.gettingStarted[i]
                    HStack(alignment: .top, spacing: 16) {
                        Text("\(i + 1)")
                            .font(.title3.bold())
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.tint.opacity(0.25)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.title).font(.headline)
                            Text(step.body).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Getting started")
            }

            ForEach(HelpContent.topics, id: \.title) { topic in
                Section(topic.title) {
                    ForEach(topic.items, id: \.title) { item in
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.headline)
                                Text(item.body).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: item.systemImage)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Frequently asked questions") {
                ForEach(HelpContent.faq, id: \.question) { entry in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedQuestion == entry.question },
                            set: { expandedQuestion = $0 ? entry.question : nil }
                        )
                    ) {
                        Text(entry.answer)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } label: {
                        Text(entry.question).font(.headline)
                    }
                }
            }

            Section("Still stuck?") {
                Link(destination: AppInfo.emailURL) {
                    Label("Email us at \(AppInfo.email)", systemImage: "envelope")
                }
            }
        }
        .navigationTitle("Help")
    }
}

enum HelpContent {
    struct Step { let title: String; let body: String }
    struct Item { let title: String; let systemImage: String; let body: String }
    struct Topic { let title: String; let items: [Item] }
    struct FAQ { let question: String; let answer: String }

    static let gettingStarted: [Step] = [
        Step(title: "Choose a piece of music",
             body: "Open Music and pick one of the built-in pieces, or import your own audio file."),
        Step(title: "Show the effects in your room",
             body: "Tap “Show in my room” at the bottom of the window. Your room stays visible, and the effects appear in it."),
        Step(title: "Set your note colours",
             body: "Open Note colours. Tap a note to hear it held, choose the colour you see for it, then tap again to stop."),
        Step(title: "Shape the effects",
             body: "Open Effects. Every effect starts switched off. Switch on the kinds of light you see, then tap Adjust on each one to change its colour, size, speed, placement and how it reacts to the music."),
        Step(title: "Save and record",
             body: "Open Save and record. Tap Save…, confirm or edit the name, then follow the steps there to record what you see with Record My View."),
    ]

    static let topics: [Topic] = [
        Topic(title: "The effects", items: [
            Item(title: "Floating orbs", systemImage: EffectKind.orbs.systemImage,
                 body: "Soft glowing spheres, one group for each of the 12 notes. Each grows and brightens when its note sounds."),
            Item(title: "Flowing ribbon", systemImage: EffectKind.ribbon.systemImage,
                 body: "Bands of light that braid and flow like water. Each band takes the colour of one of the strongest notes, and the ribbon rises with higher sounds."),
            Item(title: "Bursts on the beat", systemImage: EffectKind.bursts.systemImage,
                 body: "A flash and a spray of sparks on each beat, starting white-hot and cooling into the note’s colour."),
            Item(title: "Aurora", systemImage: EffectKind.aurora.systemImage,
                 body: "Soft curtains of light that ripple like the northern lights, with the strongest note’s colour at the bottom and the next strongest above."),
        ]),
        Topic(title: "Effect settings", items: [
            Item(title: "Colour", systemImage: "paintpalette",
                 body: "“Colour of the notes” uses your note colours, so the colour changes with the music. “One colour” keeps the effect a single colour you choose."),
            Item(title: "Where", systemImage: "move.3d",
                 body: "Place the effect in front of you, all around you, or above you."),
            Item(title: "Size, speed and opacity", systemImage: "slider.horizontal.3",
                 body: "Make the effect bigger or smaller, faster or slower, and more solid or more see-through."),
            Item(title: "Reacts to", systemImage: "waveform",
                 body: "Choose which part of the sound drives the effect: overall volume, low, middle or high sounds. Sensitivity sets how strongly it responds."),
            Item(title: "Speed follows the music’s tempo", systemImage: "metronome",
                 body: "When on, effects move faster with faster music and slower with slower music. The Speed slider still sets the overall pace."),
            Item(title: "Layers", systemImage: "square.3.layers.3d",
                 body: "Every effect is listed on the Effects screen, switched off to start. Use the switch beside each to show or hide it. Tap + to add a second copy of an effect, and swipe to delete one."),
        ]),
        Topic(title: "Sharing what you see", items: [
            Item(title: "Presets", systemImage: "square.and.arrow.down.on.square",
                 body: "A preset saves everything: your note colours, every effect and its settings, and the music. Tap Save… and confirm the name. New preset… lets you start from the current preset or a clean slate."),
            Item(title: "Sending a preset", systemImage: "square.and.arrow.up",
                 body: "Use the share button beside a saved preset to send it by AirDrop, Messages or email. Someone with the app can open it and see what you see."),
            Item(title: "Recording a video", systemImage: "record.circle",
                 body: "Vision Pro’s Record My View captures your room and the effects together. Open Control Center, tap Record My View, then play the music. The video is saved to Photos."),
        ]),
    ]

    static let faq: [FAQ] = [
        FAQ(question: "What is synesthesia?",
            answer: "Synesthesia is when one sense triggers another. In music-colour synesthesia (also called chromesthesia), hearing music brings experiences of colour, shape and movement. It isn’t an illness, and it is different for every person."),
        FAQ(question: "Is this app a medical or diagnostic tool?",
            answer: "No. It helps you show and explain what you experience. It doesn’t diagnose, measure or treat anything. Talk to a qualified health professional about any medical question."),
        FAQ(question: "My experience looks nothing like these effects. Can I still use the app?",
            answer: "Yes. Start with the effect that comes closest, then adjust its colour, size, speed and movement. Combining several effects often gets nearer. We’re adding more kinds of effects, and we’d love to hear what’s missing: use the email link below."),
        FAQ(question: "Why does the colour sometimes change when the note hasn’t?",
            answer: "The app listens for the strongest note, which is approximate when many instruments play together or with very low notes. For setting colours, use the play buttons on Note colours: they play one clear note at a time."),
        FAQ(question: "Can I use music from Apple Music or Spotify?",
            answer: "No. Streaming services don’t let apps read their audio, so the effects couldn’t follow it, and their music is usually muted in recordings. Use the built-in pieces or import audio files you have the right to use."),
        FAQ(question: "How do I import my own music?",
            answer: "On Music, tap “Import an audio file” and choose an MP3, M4A, WAV or AIFF file from Files. It’s copied into the app and appears in the list."),
        FAQ(question: "Does the recording include the music?",
            answer: "It should: Record My View captures what you see along with the sound. If a recording is silent, check that the music was playing from this app and that your Vision Pro volume was up."),
        FAQ(question: "Why can’t the app record by itself?",
            answer: "To protect your privacy, visionOS doesn’t let apps capture the view of your room. Record My View, which you control, is the way to do it."),
        FAQ(question: "Where are my presets kept? Is anything uploaded?",
            answer: "Everything stays on your Vision Pro. The app has no accounts and sends nothing anywhere. A preset only leaves your device if you share it yourself."),
        FAQ(question: "The effects flash. Is that safe for me?",
            answer: "If you have photosensitive epilepsy or are sensitive to flashing light, talk to your doctor first. You can make effects gentler: lower the Sensitivity and Speed, reduce Opacity, or hide the Bursts effect."),
        FAQ(question: "Can a doctor or support group use this?",
            answer: "Yes. Clinicians, researchers and support organisations can use presets and recordings to understand and explain individual experiences. The app itself makes no medical claims."),
        FAQ(question: "How do I get help or send feedback?",
            answer: "Email us at \(AppInfo.email). We read every message."),
    ]
}
