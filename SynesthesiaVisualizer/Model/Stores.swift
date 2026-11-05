import Foundation

struct Track: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let licence: String
    let url: URL
}

/// Finds the bundled public-domain music and any audio files the user imported.
enum TrackLibrary {
    private struct CatalogEntry: Codable {
        let file: String
        let title: String
        let composer: String
        let performer: String
        let licence: String
        let source: String
    }

    static var importedDirectory: URL {
        let dir = URL.documentsDirectory.appending(path: "Imported", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func allTracks() -> [Track] { bundledTracks() + importedTracks() }

    static func bundledTracks() -> [Track] {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([CatalogEntry].self, from: data)
        else { return [] }

        return entries.compactMap { entry in
            let name = (entry.file as NSString).deletingPathExtension
            let ext = (entry.file as NSString).pathExtension
            guard let fileURL = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
            return Track(
                id: "bundle:\(entry.file)",
                title: entry.title,
                subtitle: "\(entry.composer) · \(entry.performer)",
                licence: "\(entry.licence). Source: \(entry.source)",
                url: fileURL
            )
        }
    }

    static func importedTracks() -> [Track] {
        let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac"]
        let files = (try? FileManager.default.contentsOfDirectory(at: importedDirectory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { audioExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { url in
                Track(
                    id: "import:\(url.lastPathComponent)",
                    title: url.deletingPathExtension().lastPathComponent,
                    subtitle: "Imported",
                    licence: "Your own file",
                    url: url
                )
            }
    }

    /// Copies a file picked in the Files app into the app, so it stays available.
    static func importFile(from source: URL) throws -> URL {
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        let destination = importedDirectory.appending(path: source.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path()) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }
}

/// Saves presets as JSON files in the app's Documents folder.
struct PresetStore {
    var directory: URL {
        let dir = URL.documentsDirectory.appending(path: "Presets", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func fileURL(for preset: Preset) -> URL {
        directory.appending(path: "\(preset.id.uuidString).json")
    }

    func loadAll() -> [Preset] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(Preset.self, from: Data(contentsOf: $0)) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ preset: Preset) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(preset).write(to: fileURL(for: preset), options: .atomic)
    }

    func delete(_ preset: Preset) {
        try? FileManager.default.removeItem(at: fileURL(for: preset))
    }
}
