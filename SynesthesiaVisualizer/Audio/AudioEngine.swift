import AVFoundation
import Observation

/// Plays one audio file on a loop and feeds it through the analyzer.
@MainActor
@Observable
final class AudioEngine {
    let analyzer = SpectrumAnalyzer()

    private(set) var isPlaying = false
    private(set) var loadedURL: URL?
    /// The note (0 = C … 11 = B) being held for colour choosing, if any.
    private(set) var heldNote: Int?
    var errorMessage: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let player = AVAudioPlayerNode()
    @ObservationIgnored private var file: AVAudioFile?
    @ObservationIgnored private var needsSchedule = true
    @ObservationIgnored private var playbackToken = 0
    @ObservationIgnored private let synth = NoteSynth()

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        let synthNode = Self.makeSynthNode(synth: synth, sampleRate: engine.outputNode.outputFormat(forBus: 0).sampleRate)
        engine.attach(synthNode)
        engine.connect(synthNode, to: engine.mainMixerNode, format: synthNode.outputFormat(forBus: 0))
        Self.installAnalysisTap(on: engine.mainMixerNode, analyzer: analyzer)
        Self.activateAudioSession()
    }

    /// Kept nonisolated so the render block runs freely on the audio thread.
    nonisolated private static func makeSynthNode(synth: NoteSynth, sampleRate: Double) -> AVAudioSourceNode {
        let rate = sampleRate > 0 ? sampleRate : 48_000
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        return AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            synth.render(frames: Int(frameCount), into: UnsafeMutableAudioBufferListPointer(audioBufferList), sampleRate: Float(rate))
            return noErr
        }
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

    /// Sets up the audio session once, off the main thread, because activating it can block briefly.
    nonisolated private static func activateAudioSession() {
        Task.detached(priority: .userInitiated) {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default)
            try? session.setActive(true)
        }
    }

    private func startEngine() -> Bool {
        do {
            if !engine.isRunning { try engine.start() }
            return true
        } catch {
            errorMessage = "Audio couldn't start: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: Held notes, for choosing colours

    /// Holds one note (middle octave) until `stopNote()`. Pauses the music while it sounds.
    func startNote(_ pitchClass: Int) {
        if isPlaying { pause() }
        guard startEngine() else { return }
        synth.setNote(midi: 60 + pitchClass)
        heldNote = pitchClass
    }

    func stopNote() {
        synth.release()
        heldNote = nil
    }

    // MARK: Music

    func play() {
        guard let file else { return }
        if heldNote != nil { stopNote() }
        guard startEngine() else { return }
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
