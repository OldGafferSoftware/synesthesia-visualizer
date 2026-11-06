import AVFoundation

/// A soft, sustained organ-like tone used to preview a single note.
/// Settings are written on the main thread and read on the audio thread; a stale
/// read only delays a change by one buffer, so no lock is needed.
final class NoteSynth: @unchecked Sendable {
    private var frequency: Float = 261.63
    private var targetGain: Float = 0
    private var gain: Float = 0
    private var phase: Float = 0
    private var vibratoPhase: Float = 0

    func setNote(midi: Int) {
        frequency = 440 * pow(2, Float(midi - 69) / 12)
        targetGain = 1
    }

    func release() {
        targetGain = 0
    }

    func render(frames: Int, into buffers: UnsafeMutableAudioBufferListPointer, sampleRate: Float) {
        let twoPi = 2 * Float.pi
        let target = targetGain
        let freq = frequency
        for frame in 0..<frames {
            // Smooth gain changes so starting and stopping never click.
            gain += (target - gain) * 0.0008
            vibratoPhase += twoPi * 5 / sampleRate
            if vibratoPhase > twoPi { vibratoPhase -= twoPi }
            let wobble = 1 + 0.003 * sin(vibratoPhase)
            phase += twoPi * freq * wobble / sampleRate
            if phase > twoPi { phase -= twoPi }
            let tone = 0.6 * sin(phase) + 0.25 * sin(2 * phase) + 0.1 * sin(3 * phase) + 0.05 * sin(4 * phase)
            let sample = tone * gain * 0.35
            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                data[frame] = sample
            }
        }
    }
}
