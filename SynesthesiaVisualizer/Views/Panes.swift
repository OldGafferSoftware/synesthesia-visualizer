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
                            .opacity(model.audio.isPlaying ? 1 : 0.3)
                        Text(model.audio.isPlaying ? "Strongest note now: \(Preset.noteNames[pitchClass])" : "Play a piece to see which note is sounding")
                            .font(.title3)
                    }
                }
            } footer: {
                Text("Note detection is approximate, especially with many instruments at once.")
            }

            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: 4), spacing: 20) {
                    ForEach(0..<12, id: \.self) { index in
                        ColorPicker(selection: colorBinding(index)) {
                            Text(Preset.noteNames[index]).font(.title3.bold())
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("What colour is each note for you?")
            } footer: {
                Text("Effects set to “Colour of the notes” use these.")
            }

            Section("Start from") {
                Button("Rainbow") { model.preset.noteColors = Preset.rainbowColors }
                Button("Scriabin's colours (historical)") { model.preset.noteColors = Preset.scriabinColors }
            }
        }
        .navigationTitle("Note colours")
    }

    private func colorBinding(_ index: Int) -> Binding<Color> {
        Binding(
            get: { model.preset.noteColors[index].color },
            set: { model.preset.noteColors[index] = RGBA($0) }
        )
    }
}

// MARK: - Layers

struct LayersPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        List {
            Section {
                ForEach($model.preset.layers) { $layer in
                    NavigationLink {
                        LayerEditor(layer: $layer)
                    } label: {
                        HStack {
                            Image(systemName: layer.kind.systemImage)
                            Text(layer.name)
                            Spacer()
                            Toggle("Visible", isOn: $layer.isVisible).labelsHidden()
                        }
                    }
                }
                .onDelete { model.preset.layers.remove(atOffsets: $0) }
                .onMove { model.preset.layers.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("Turn on “Show in my room” and play the music, then adjust each effect until it matches what you see.")
            }
        }
        .navigationTitle("Effects")
        .toolbar {
            Menu {
                ForEach(EffectKind.allCases) { kind in
                    Button(kind.label, systemImage: kind.systemImage) { model.addLayer(kind) }
                }
            } label: {
                Label("Add effect", systemImage: "plus")
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

            Section("Reacts to") {
                Picker("Sound", selection: $layer.reaction) {
                    ForEach(Reaction.allCases) { Text($0.label).tag($0) }
                }
                slider("Sensitivity", value: $layer.sensitivity, in: 0...2)
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

    var body: some View {
        @Bindable var model = model

        List {
            Section("Current preset") {
                TextField("Preset name", text: $model.preset.name)
                LabeledContent("Music", value: model.preset.trackTitle ?? "None chosen")
                Button("Save", systemImage: "square.and.arrow.down.on.square") { model.savePreset() }
                Button("Start a new preset", systemImage: "plus") { model.newPreset() }
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
    }
}
