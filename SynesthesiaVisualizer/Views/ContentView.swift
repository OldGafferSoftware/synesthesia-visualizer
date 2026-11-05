import SwiftUI

enum Pane: String, CaseIterable, Identifiable {
    case music, colours, layers, presets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .music: "Music"
        case .colours: "Note colours"
        case .layers: "Effects"
        case .presets: "Save and record"
        }
    }

    var systemImage: String {
        switch self {
        case .music: "music.note"
        case .colours: "paintpalette"
        case .layers: "square.3.layers.3d"
        case .presets: "square.and.arrow.down"
        }
    }
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var pane: Pane? = .music
    @State private var showSplash = true
    @State private var showInfo = false

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $pane) { pane in
                Label(pane.title, systemImage: pane.systemImage).tag(pane)
            }
            .navigationTitle("Synesthesia")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("About this app", systemImage: "info.circle") { showInfo = true }
                }
            }
            .sheet(isPresented: $showInfo) {
                AboutView(mode: .info) { showInfo = false }
                    .frame(minWidth: 760, minHeight: 640)
            }
        } detail: {
            NavigationStack {
                switch pane ?? .music {
                case .music: MusicPane()
                case .colours: NoteColoursPane()
                case .layers: LayersPane()
                case .presets: PresetsPane()
                }
            }
        }
        .sheet(isPresented: $showSplash) {
            AboutView(mode: .splash) { showSplash = false }
                .frame(minWidth: 760, minHeight: 640)
                .interactiveDismissDisabled()
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomOrnament) {
                Button {
                    model.togglePlayback()
                } label: {
                    Label(model.audio.isPlaying ? "Pause" : "Play",
                          systemImage: model.audio.isPlaying ? "pause.fill" : "play.fill")
                }
                .disabled(model.selectedTrack == nil)

                Button {
                    model.restart()
                } label: {
                    Label("Play from the start", systemImage: "backward.end.fill")
                }
                .disabled(model.selectedTrack == nil)

                Toggle(isOn: stageBinding) {
                    Label("Show in my room", systemImage: "visionpro")
                }
                .toggleStyle(.button)
            }
        }
        .alert("Synesthesia Visualizer", isPresented: Binding(
            get: { model.message != nil },
            set: { if !$0 { model.message = nil } }
        )) {
            Button("OK") { model.message = nil }
        } message: {
            Text(model.message ?? "")
        }
    }

    private var stageBinding: Binding<Bool> {
        Binding(
            get: { model.isStageOpen },
            set: { show in
                Task { @MainActor in
                    if show {
                        switch await openImmersiveSpace(id: AppModel.stageID) {
                        case .opened: model.isStageOpen = true
                        default: model.isStageOpen = false
                        }
                    } else {
                        await dismissImmersiveSpace()
                        model.isStageOpen = false
                    }
                }
            }
        )
    }
}
