import SwiftUI
import UniformTypeIdentifiers

// MARK: - Music

struct MusicPane: View {
    @Environment(AppModel.self) private var model
    @State private var importing = false

    var body: some View {
        List {
            Section {
                ForEach(model.tracks) { track in
                    Button {
                        model.select(track)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title).font(.headline)
                                Text(track.subtitle).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if track.id == model.selectedTrackID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } header: {
                Text("Choose a piece")
            } footer: {
                if model.tracks.isEmpty {
                    Text("No music yet. Import an audio file below.")
                }
            }

            Section {
                Button("Import an audio file…", systemImage: "square.and.arrow.down") { importing = true }
            } footer: {
                Text("Use recordings you have the right to use. Apple Music tracks can't be imported.")
            }

            if let track = model.selectedTrack {
                Section("About this recording") {
                    Text(track.licence).font(.footnote)
                }
            }

            if let error = model.audio.errorMessage {
                Text(error).foregroundStyle(.red)
            }
        }
        .navigationTitle("Music")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result { model.importAudio(from: url) }
        }
    }
}

// MARK: - Note colours

struct NoteColoursPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                    let features = model.audio.features
                    let pitchClass = features.dominantPitchClass
                    HStack(spacing: 16) {
                        Circle()
                            .fill(model.preset.noteColors[pitchClass].color)
                            .frame(width: 44, height: 44)
                            .opacity(model.audio.isPlaying || model.audio.heldNote != nil ? 1 : 0.3)
                        Text(model.audio.isPlaying || model.audio.heldNote != nil ? "Strongest note now: \(Preset.noteNames[pitchClass])" : "Play a piece to see which note is sounding")
                            .font(.title3)
                    }
                }
            } footer: {
                Text("Note detection is approximate, especially with many instruments at once.")
            }

            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: 3), spacing: 20) {
                    ForEach(0..<12, id: \.self) { index in
                        NoteSwatch(index: index)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("What colour is each note for you?")
            } footer: {
                Text("Tap a note to hear it held. While it plays, choose its colour, then tap again to stop. Turn on “Show in my room” to see the colour in your space as you choose.")
            }

            Section("Start from") {
                Button("Rainbow") { model.preset.noteColors = Preset.rainbowColors }
                Button("Scriabin's colours (historical)") { model.preset.noteColors = Preset.scriabinColors }
            }
        }
        .navigationTitle("Note colours")
        .onDisappear { model.audio.stopNote() }
    }
}

/// One note: a play/stop button that holds the note, and its colour well.
struct NoteSwatch: View {
    @Environment(AppModel.self) private var model
    let index: Int

    private var isHeld: Bool { model.audio.heldNote == index }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if isHeld { model.audio.stopNote() } else { model.audio.startNote(index) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isHeld ? "stop.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                    Text(Preset.noteNames[index])
                        .font(.title3.bold())
                        .frame(minWidth: 36, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(model.preset.noteColors[index].color.opacity(isHeld ? 0.55 : 0.18))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isHeld ? "Stop \(Preset.noteNames[index])" : "Play \(Preset.noteNames[index])")

            ColorPicker("Colour for \(Preset.noteNames[index])", selection: colorBinding)
                .labelsHidden()
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { model.preset.noteColors[index].color },
            set: { model.preset.noteColors[index] = RGBA($0) }
        )
    }
}

// MARK: - Layers

struct LayersPane: View {
    @Environment(AppModel.self) private var model
    /// The effect being adjusted. A plain button sets this, so rows show no navigation arrow.
    @State private var editingID: EffectLayer.ID?

    var body: some View {
        @Bindable var model = model

        List {
            Section {
                ForEach($model.preset.layers) { $layer in
                    // Switch, icon and name on the left; the ••• (adjust), + and − buttons sit together at the right edge
                    // so they line up from row to row whatever the name's length.
                    HStack(spacing: 20) {
                        Toggle("Show \(layer.name)", isOn: $layer.isVisible)
                            .labelsHidden()
                        Image(systemName: layer.kind.systemImage)
                            .font(.title3)
                            .frame(width: 32)
                            .foregroundStyle(layer.isVisible ? Color.primary : Color.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(layer.name).font(.headline)
                            Text(layer.isVisible ? "On" : "Off")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 32)
                        Button {
                            editingID = layer.id
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel("Adjust \(layer.name)")
                        HStack(spacing: 4) {
                            Button {
                                model.addLayer(layer.kind, after: layer.id)
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Add another \(layer.kind.label)")
                            Button {
                                model.removeLayer(layer.id)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Remove \(layer.name)")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 6)
                }
                .onDelete { model.preset.layers.remove(atOffsets: $0) }
                .onMove { model.preset.layers.move(fromOffsets: $0, toOffset: $1) }
            } header: {
                Text("Switch on the effects you see")
            } footer: {
                Text("Turn on “Show in my room” and play the music. Use the switch to turn an effect on, and the ••• button to change it until it matches what you see. Use + on a row to add another copy just below it, and − to remove that row. The + at the top right adds back an effect you've removed.")
            }
        }
        .navigationTitle("Effects")
        .navigationDestination(item: $editingID) { id in
            if let index = model.preset.layers.firstIndex(where: { $0.id == id }) {
                LayerEditor(layer: $model.preset.layers[index])
            }
        }
        .toolbar {
            Menu {
                ForEach(EffectKind.allCases) { kind in
                    Button(kind.label, systemImage: kind.systemImage) { model.addLayer(kind) }
                }
            } label: {
                Label("Add another effect", systemImage: "plus")
            }
        }
    }
}

/// Shows the tempo the app is currently hearing.
struct TempoReadout: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            LabeledContent("Tempo now") {
                Text(model.audio.isPlaying ? "about \(Int(model.audio.features.tempo.rounded())) beats a minute" : "play some music")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LayerEditor: View {
    @Binding var layer: EffectLayer

    var body: some View {
        Form {
            Section("Effect") {
                TextField("Name", text: $layer.name)
                Picker("Type", selection: $layer.kind) {
                    ForEach(EffectKind.allCases) { Text($0.label).tag($0) }
                }
                Picker("Where", selection: $layer.placement) {
                    ForEach(Placement.allCases) { Text($0.label).tag($0) }
                }
            }

            Section("Colour") {
                Picker("Colour", selection: $layer.colorSource) {
                    ForEach(ColorSource.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                if layer.colorSource == .single {
                    ColorPicker("Colour", selection: Binding(
                        get: { layer.singleColor.color },
                        set: { layer.singleColor = RGBA($0) }
                    ))
                }
                slider("Opacity", value: $layer.opacity, in: 0.1...1)
            }

            Section("Size and movement") {
                slider("Size", value: $layer.size, in: 0.2...3)
                slider("Speed", value: $layer.speed, in: 0...3)
            }

            Section {
                Picker("Sound", selection: $layer.reaction) {
                    ForEach(Reaction.allCases) { Text($0.label).tag($0) }
                }
                slider("Sensitivity", value: $layer.sensitivity, in: 0...2)
                Toggle("Speed follows the music's tempo", isOn: $layer.followsTempo)
                if layer.followsTempo {
                    TempoReadout()
                }
            } header: {
                Text("Reacts to")
            } footer: {
                Text(layer.followsTempo
                     ? "Movement speeds up with faster music and slows with slower music. The Speed slider sets how fast it is overall."
                     : "Movement stays at the Speed slider's setting, whatever the music's tempo.")
            }
        }
        .navigationTitle(layer.name)
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>) -> some View {
        LabeledContent(title) {
            Slider(value: value, in: range).frame(maxWidth: 360)
        }
    }
}

// MARK: - Presets and recording

struct PresetsPane: View {
    @Environment(AppModel.self) private var model
    @State private var showSaveAlert = false
    @State private var pendingName = ""
    @State private var showNewPresetChoice = false

    var body: some View {
        @Bindable var model = model

        List {
            Section {
                TextField("Preset name", text: $model.preset.name)
                    .font(.title3)
                LabeledContent("Music", value: model.preset.trackTitle ?? "None chosen")
                LabeledContent("Effects on", value: "\(model.preset.layers.filter(\.isVisible).count) of \(model.preset.layers.count)")
                Button("Save…", systemImage: "square.and.arrow.down.on.square") {
                    pendingName = model.preset.name
                    showSaveAlert = true
                }
                Button("New preset…", systemImage: "plus") { showNewPresetChoice = true }
            } header: {
                Text("Current preset")
            } footer: {
                Text(model.isCurrentPresetSaved ? "Saving again updates this preset." : "Not saved yet.")
            }

            Section {
                ForEach(model.savedPresets) { saved in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(saved.name).font(.headline)
                            Text(saved.trackTitle ?? "No music").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open") { model.open(saved) }
                        ShareLink(item: model.presetStore.fileURL(for: saved)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .buttonStyle(.borderless)
                }
                .onDelete { model.deletePresets(at: $0) }
            } header: {
                Text("Saved presets")
            } footer: {
                if model.savedPresets.isEmpty { Text("Nothing saved yet.") }
            }

            Section("Record what you see") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Open “Show in my room” and get the effects how you want them.")
                    Text("2. Move this window to the side, out of the way.")
                    Text("3. Open Control Center and tap Record My View.")
                    Text("4. Press “Play from the start”. Stop recording in Control Center when done.")
                    Text("The video, with your room and the effects, is saved to Photos.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Save and record")
        .alert("Save preset", isPresented: $showSaveAlert) {
            TextField("Preset name", text: $pendingName)
            Button("Save") { model.savePreset(named: pendingName) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Confirm the name for this preset, or change it.")
        }
        .confirmationDialog("Start a new preset", isPresented: $showNewPresetChoice, titleVisibility: .visible) {
            Button("Start from “\(model.preset.name)”") { model.newPreset(fromCurrent: true) }
            Button("Start with a clean slate") { model.newPreset(fromCurrent: false) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(model.isCurrentPresetSaved
                 ? "Your saved presets stay as they are."
                 : "The current preset hasn't been saved. Save it first if you want to keep it.")
        }
    }
}
