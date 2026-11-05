import AVFoundation
import Accelerate

/// What the effects react to, measured from the music many times a second.
/// Every value is 0...1 unless noted.
struct AudioFeatures: Sendable {
    var level: Float = 0
    var bass: Float = 0
    var mid: Float = 0
    var treble: Float = 0
    /// How "bright" or high the sound is overall (spectral centroid, 200 Hz → 0, 5 kHz → 1).
    var brightness: Float = 0.5
    /// Strength of each of the 12 notes (C, C♯ … B), regardless of octave.
    var chroma = [Float](repeating: 0, count: 12)
    var dominantPitchClass = 0
    /// Goes up by one on every detected beat or strong onset.
    var beatCount = 0

    func value(for reaction: Reaction) -> Float {
        switch reaction {
        case .volume: level
        case .bass: bass
        case .mid: mid
        case .treble: treble
        case .none: 0.5
        }
    }
}

/// Turns raw audio buffers into `AudioFeatures`. Called on the audio thread; read from the main thread.
final class SpectrumAnalyzer: @unchecked Sendable {
    private let fftSize: Int
    private let fft: vDSP.FFT<DSPSplitComplex>
    private let window: [Float]
    private let lock = NSLock()

    private var previousMagnitudes: [Float]
    private var fluxAverage: Float = 0
    private var framesSinceBeat = 0
    /// Slowly-decaying peaks, so loud and quiet pieces both use the full 0...1 range.
    private var peaks: [Float] = [1e-3, 1e-3, 1e-3, 1e-3]
    private var current = AudioFeatures()

    init(fftSize: Int = 4096) {
        self.fftSize = fftSize
        let log2n = vDSP_Length(log2(Double(fftSize)))
        fft = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self)!
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: fftSize, isHalfWindow: false)
        previousMagnitudes = [Float](repeating: 0, count: fftSize / 2)
    }

    func snapshot() -> AudioFeatures {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        let beats = current.beatCount
        current = AudioFeatures()
        current.beatCount = beats
    }

    func process(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let available = Int(buffer.frameLength)
        guard available > 0 else { return }

        let count = min(available, fftSize)
        let start = available - count
        var samples = [Float](repeating: 0, count: fftSize)
        for i in 0..<count { samples[i] = channel[start + i] }

        var sumOfSquares: Float = 0
        for i in 0..<count { sumOfSquares += samples[i] * samples[i] }
        let rms = sqrt(sumOfSquares / Float(count))

        samples = vDSP.multiply(samples, window)

        let half = fftSize / 2
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var magnitudes = [Float](repeating: 0, count: half)
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                samples.withUnsafeBufferPointer { samplePtr in
                    samplePtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(half))
                    }
                }
                let input = split
                fft.forward(input: input, output: &split)
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(half))
            }
        }
        magnitudes[0] = 0

        let sampleRate = Float(buffer.format.sampleRate)
        let binHz = sampleRate / Float(fftSize)

        func bandEnergy(_ low: Float, _ high: Float) -> Float {
            let a = max(1, Int(low / binHz))
            let b = min(half - 1, Int(high / binHz))
            guard b > a else { return 0 }
            var sum: Float = 0
            for i in a...b { sum += magnitudes[i] }
            return sum / Float(b - a + 1)
        }
        let bass = bandEnergy(20, 250)
        let mid = bandEnergy(250, 2000)
        let treble = bandEnergy(2000, 8000)

        // Note strengths (chroma) and overall brightness (spectral centroid).
        var chroma = [Float](repeating: 0, count: 12)
        var weighted: Float = 0
        var total: Float = 0
        let lowBin = max(1, Int(60 / binHz))
        let highBin = min(half - 1, Int(5000 / binHz))
        if highBin > lowBin {
            for i in lowBin...highBin {
                let frequency = Float(i) * binHz
                let m = magnitudes[i]
                weighted += frequency * m
                total += m
                if frequency < 2000 {
                    let midi = 69 + 12 * log2(frequency / 440)
                    var pitchClass = Int(midi.rounded()) % 12
                    if pitchClass < 0 { pitchClass += 12 }
                    chroma[pitchClass] += m * m
                }
            }
        }
        let centroid = total > 0 ? weighted / total : 0
        let brightness = centroid > 0 ? min(1, max(0, log2(centroid / 200) / log2(25))) : 0

        // Onsets: a sudden rise in energy across the spectrum.
        var flux: Float = 0
        for i in 0..<half {
            let rise = magnitudes[i] - previousMagnitudes[i]
            if rise > 0 { flux += rise }
        }
        previousMagnitudes = magnitudes

        lock.lock(); defer { lock.unlock() }

        func normalize(_ value: Float, _ index: Int) -> Float {
            peaks[index] = max(value, peaks[index] * 0.997)
            return min(1, value / max(peaks[index], 1e-4))
        }
        func smooth(_ old: Float, _ new: Float) -> Float {
            old + (new - old) * (new > old ? 0.6 : 0.15)
        }

        current.level = smooth(current.level, normalize(rms, 0))
        current.bass = smooth(current.bass, normalize(bass, 1))
        current.mid = smooth(current.mid, normalize(mid, 2))
        current.treble = smooth(current.treble, normalize(treble, 3))
        current.brightness = current.brightness * 0.8 + brightness * 0.2

        let strongest = chroma.max() ?? 0
        if strongest > 0 {
            for i in 0..<12 {
                current.chroma[i] = current.chroma[i] * 0.6 + (chroma[i] / strongest) * 0.4
            }
        } else {
            for i in 0..<12 { current.chroma[i] *= 0.9 }
        }
        if let best = current.chroma.indices.max(by: { current.chroma[$0] < current.chroma[$1] }) {
            current.dominantPitchClass = best
        }

        framesSinceBeat += available
        let minimumGap = Int(0.25 * sampleRate)
        if framesSinceBeat > minimumGap, flux > fluxAverage * 1.6, rms > 0.01 {
            current.beatCount += 1
            framesSinceBeat = 0
        }
        fluxAverage = fluxAverage * 0.92 + flux * 0.08
    }
}
