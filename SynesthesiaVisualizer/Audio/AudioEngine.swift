import AVFoundation
import Observation

/// Plays one audio file on a loop and feeds it through the analyzer.
@MainActor
@Observable
final class AudioEngine {
    let analyzer = SpectrumAnalyzer()

    private(set) var isPlaying = false
    private(set) var loadedURL: URL?
    var errorMessage: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let player = AVAudioPlayerNode()
    @ObservationIgnored private var file: AVAudioFile?
    @ObservationIgnored private var needsSchedule = true
    @ObservationIgnored private var playbackToken = 0

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        Self.installAnalysisTap(on: engine.mainMixerNode, analyzer: analyzer)
    }

    /// Kept nonisolated so the tap closure runs freely on the audio thread.
    nonisolated private static func installAnalysisTap(on mixer: AVAudioMixerNode, analyzer: SpectrumAnalyzer) {
        mixer.installTap(onBus: 0, bufferSize: 4096, format: mixer.outputFormat(forBus: 0)) { buffer, _ in
            analyzer.process(buffer)
        }
    }

    /// Latest measurements of the music; safe to call every frame.
    nonisolated var features: AudioFeatures { analyzer.snapshot() }

    func load(url: URL) {
        stop()
        do {
            let newFile = try AVAudioFile(forReading: url)
            engine.disconnectNodeOutput(player)
            engine.connect(player, to: engine.mainMixerNode, format: newFile.processingFormat)
            file = newFile
            loadedURL = url
            errorMessage = nil
        } catch {
            file = nil
            loadedURL = nil
            errorMessage = "Couldn't open that audio file."
        }
    }

    func play() {
        guard let file else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            if !engine.isRunning { try engine.start() }
        } catch {
            errorMessage = "Audio couldn't start: \(error.localizedDescription)"
            return
        }
        if needsSchedule { schedule(file) }
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func stop() {
        playbackToken += 1
        player.stop()
        isPlaying = false
        needsSchedule = true
        analyzer.reset()
    }

    func restart() {
        stop()
        play()
    }

    private func schedule(_ file: AVAudioFile) {
        playbackToken += 1
        let token = playbackToken
        needsSchedule = false
        player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.finished(token: token) }
        }
    }

    /// Loops the piece so there's time to fine-tune effects.
    private func finished(token: Int) {
        guard token == playbackToken, let file else { return }
        schedule(file)
        player.play()
    }
}
