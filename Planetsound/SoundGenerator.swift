import AVFoundation

/// Determines how each planet's audio buffer is synthesized.
enum SoundGenerator: String, CaseIterable, Identifiable, Hashable {
    case sine
    case blip
    case noise

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sine:  "Sine"
        case .blip:  "Blip"
        case .noise: "Noise"
        }
    }

    /// Creates a seamlessly-looping PCM buffer for the given frequency.
    ///
    /// - Parameters:
    ///   - frequency: The fundamental frequency in Hz.
    ///   - sampleRate: Audio sample rate (default 44100).
    ///   - duration: Approximate buffer duration in seconds.
    ///   - blipRate: Blips per second; only used by `.blip`.
    func makeBuffer(
        frequency: Double,
        sampleRate: Double = 44100,
        duration: Double = 2,
        blipRate: Double = 1
    ) -> AVAudioPCMBuffer {
        switch self {
        case .sine:
            return makeSineBuffer(frequency: frequency, sampleRate: sampleRate, duration: duration)
        case .blip:
            return makeBlipBuffer(frequency: frequency, sampleRate: sampleRate, duration: duration, blipRate: blipRate)
        case .noise:
            return makeNoiseBuffer(frequency: frequency, sampleRate: sampleRate, duration: duration)
        }
    }

    // MARK: - Sine

    private func makeSineBuffer(frequency: Double, sampleRate: Double, duration: Double) -> AVAudioPCMBuffer {
        let wholeCycles = max(1, Int(frequency * duration))
        let frameCount  = AVAudioFrameCount(Double(wholeCycles) / frequency * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        let twoPi = 2.0 * Double.pi
        for i in 0..<Int(frameCount) {
            data[i] = Float(sin(twoPi * frequency * Double(i) / sampleRate)) * 0.12
        }
        return buffer
    }

    // MARK: - Blip

    private func makeBlipBuffer(frequency: Double, sampleRate: Double, duration: Double, blipRate: Double) -> AVAudioPCMBuffer {
        // Ensure buffer contains whole blip cycles for seamless looping.
        let effectiveRate = max(0.25, blipRate)
        let blipPeriod = 1.0 / effectiveRate
        let wholeBlipCycles = max(1, Int(duration * effectiveRate))
        let totalDuration = Double(wholeBlipCycles) * blipPeriod
        let frameCount = AVAudioFrameCount(totalDuration * sampleRate)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        // Zero fill (silence).
        for i in 0..<Int(frameCount) { data[i] = 0 }

        // Blip parameters.
        let blipDuration = min(0.06, blipPeriod * 0.5)
        let blipSamples = Int(blipDuration * sampleRate)
        let rampSamples = min(Int(0.005 * sampleRate), blipSamples / 4)

        let twoPi = 2.0 * Double.pi
        for blipIndex in 0..<wholeBlipCycles {
            let onset = Int(Double(blipIndex) * blipPeriod * sampleRate)
            for j in 0..<blipSamples {
                let sampleIndex = onset + j
                guard sampleIndex < Int(frameCount) else { break }

                // Raised-cosine envelope: attack, sustain, release.
                var envelope: Float = 1.0
                if j < rampSamples {
                    envelope = Float(0.5 * (1.0 - cos(Double.pi * Double(j) / Double(rampSamples))))
                } else if j >= blipSamples - rampSamples {
                    let tail = j - (blipSamples - rampSamples)
                    envelope = Float(0.5 * (1.0 + cos(Double.pi * Double(tail) / Double(rampSamples))))
                }

                let sample = Float(sin(twoPi * frequency * Double(sampleIndex) / sampleRate))
                data[sampleIndex] = sample * envelope * 0.12
            }
        }
        return buffer
    }

    // MARK: - Band-limited noise

    private func makeNoiseBuffer(frequency: Double, sampleRate: Double, duration: Double) -> AVAudioPCMBuffer {
        // Whole-cycle align to the fundamental for seamless looping.
        let wholeCycles = max(1, Int(frequency * duration))
        let frameCount  = AVAudioFrameCount(Double(wholeCycles) / frequency * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        // Sum ~20 sine waves at random phases within +/- one semitone of center frequency.
        let twoPi = 2.0 * Double.pi
        let partialCount = 20
        let semitoneRatio = pow(2.0, 1.0 / 12.0)
        let fLow  = frequency / semitoneRatio
        let fHigh = frequency * semitoneRatio

        var partials: [(freq: Double, phase: Double)] = []
        for k in 0..<partialCount {
            let t = Double(k) / Double(partialCount - 1)
            let f = fLow + t * (fHigh - fLow)
            let phi = Double.random(in: 0..<twoPi)
            partials.append((f, phi))
        }

        // Zero fill, then accumulate.
        for i in 0..<Int(frameCount) { data[i] = 0 }
        let amplitude: Float = 0.12 / Float(partialCount)
        for (f, phi) in partials {
            for i in 0..<Int(frameCount) {
                data[i] += Float(sin(twoPi * f * Double(i) / sampleRate + phi)) * amplitude
            }
        }
        return buffer
    }
}
