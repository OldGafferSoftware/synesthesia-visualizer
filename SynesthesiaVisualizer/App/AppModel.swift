import SwiftUI
import Observation

@MainActor
@Observable
final class AppModel {
    static let stageID = "Stage"

    let audio = AudioEngine()
    let presetStore = PresetStore()

    var tracks: [Track] = []
    var selectedTrackID: String?
    var preset: Preset = .starter
    var savedPresets: [Preset] = []
    var isStageOpen = false
    var message: String?

    init() {
        tracks = TrackLibrary.allTracks()
        savedPresets = presetStore.loadAll()
        if let first = tracks.first { select(first) }
    }

    var selectedTrack: Track? { tracks.first { $0.id == selectedTrackID } }

    // MARK: Music

    func select(_ track: Track) {
        let wasPlaying = audio.isPlaying
        selectedTrackID = track.id
        preset.trackID = track.id
        preset.trackTitle = track.title
        audio.load(url: track.url)
        if wasPlaying { audio.play() }
    }

    func togglePlayback() {
        guard let track = selectedTrack else { return }
        if audio.loadedURL != track.url { audio.load(url: track.url) }
        if audio.isPlaying { audio.pause() } else { audio.play() }
    }

    func restart() {
        guard selectedTrack != nil else { return }
        audio.restart()
    }

    func importAudio(from url: URL) {
        do {
            let copied = try TrackLibrary.importFile(from: url)
            tracks = TrackLibrary.allTracks()
            if let track = tracks.first(where: { $0.url.standardizedFileURL == copied.standardizedFileURL }) {
                select(track)
            }
        } catch {
            message = "Couldn't import that file: \(error.localizedDescription)"
        }
    }

    // MARK: Layers

    /// Adds a new copy of an effect, placed right after `sourceID` if given, otherwise after the last
    /// effect of the same kind, so copies of one effect stay grouped together.
    func addLayer(_ kind: EffectKind, after sourceID: EffectLayer.ID? = nil) {
        let names = Set(preset.layers.map(\.name))
        var name = kind.label
        var number = 2
        while names.contains(name) {
            name = "\(kind.label) \(number)"
            number += 1
        }
        let layer = EffectLayer(name: name, kind: kind)

        let anchor = sourceID.flatMap { id in preset.layers.firstIndex { $0.id == id } }
            ?? preset.layers.lastIndex { $0.kind == kind }
        if let anchor {
            preset.layers.insert(layer, at: anchor + 1)
        } else {
            preset.layers.append(layer)
        }
    }

    func removeLayer(_ id: EffectLayer.ID) {
        preset.layers.removeAll { $0.id == id }
    }

    // MARK: Presets

    func savePreset(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        preset.name = trimmed.isEmpty ? "Untitled preset" : trimmed
        do {
            try presetStore.save(preset)
            savedPresets = presetStore.loadAll()
            message = "Saved “\(preset.name)”."
        } catch {
            message = "Couldn't save: \(error.localizedDescription)"
        }
    }

    /// Starts a new, unsaved preset: either a copy of the current one or a clean slate.
    func newPreset(fromCurrent: Bool) {
        var fresh: Preset
        if fromCurrent {
            fresh = preset
            fresh.id = UUID()
            fresh.createdAt = Date()
            fresh.name = "Copy of \(preset.name)"
            for i in fresh.layers.indices { fresh.layers[i].id = UUID() }
        } else {
            fresh = Preset.starter
        }
        fresh.trackID = selectedTrack?.id
        fresh.trackTitle = selectedTrack?.title
        preset = fresh
    }

    /// Whether the current preset has been saved under its current id.
    var isCurrentPresetSaved: Bool { savedPresets.contains { $0.id == preset.id } }

    func open(_ saved: Preset) {
        preset = saved
        if let id = saved.trackID, let track = tracks.first(where: { $0.id == id }) {
            select(track)
        } else if saved.trackID != nil {
            message = "This preset's music (\(saved.trackTitle ?? "unknown")) isn't on this device."
        }
    }

    func deletePresets(at offsets: IndexSet) {
        for index in offsets { presetStore.delete(savedPresets[index]) }
        savedPresets = presetStore.loadAll()
    }
}
