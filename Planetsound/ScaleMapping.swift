import Foundation
import CoreGraphics

/// Centralizes the logarithmic scale mappings used to translate orbital
/// mechanics (AU, orbital periods) into screen coordinates and audio
/// parameters.
struct ScaleMapping {

    // MARK: - Precomputed invariants

    /// Largest semi-major axis in the system (AU).
    let maxAU: Double

    private let logMaxAU: Double
    private let logFastestFreq: Double
    private let logSlowestFreq: Double

    // MARK: - Tuning constants

    let audioDistanceMin: Double
    let audioDistanceMax: Double
    let frequencyMin: Double
    let frequencyMax: Double

    // MARK: - Init

    init(
        planets: [Planet] = Planet.all,
        audioDistanceRange: ClosedRange<Double> = 0.4...4.0,
        frequencyRange: ClosedRange<Double> = 110.0...880.0
    ) {
        let axes    = planets.map(\.semiMajorAxisAU)
        let periods = planets.map(\.orbitalPeriodYears)

        self.maxAU    = axes.max()!
        self.logMaxAU = log(1 + maxAU)

        self.logFastestFreq = log(1.0 / periods.min()!)
        self.logSlowestFreq = log(1.0 / periods.max()!)

        self.audioDistanceMin = audioDistanceRange.lowerBound
        self.audioDistanceMax = audioDistanceRange.upperBound
        self.frequencyMin     = frequencyRange.lowerBound
        self.frequencyMax     = frequencyRange.upperBound
    }

    // MARK: - Core normalisation

    /// Normalizes an AU distance to 0…1 using log(1 + au) / log(1 + maxAU).
    func normalizedAU(_ au: Double) -> Double {
        log(1 + au) / logMaxAU
    }

    // MARK: - Derived mappings

    /// Maps AU to screen-space radius (points).
    func screenRadius(au: Double, maxRadius: CGFloat) -> CGFloat {
        CGFloat(normalizedAU(au)) * maxRadius
    }

    /// Maps AU to 3D audio distance in metres.
    func audioDistance(au: Double) -> Double {
        let t = normalizedAU(au)
        return audioDistanceMin + t * (audioDistanceMax - audioDistanceMin)
    }

    /// Maps an orbital period (years) to an audio frequency (Hz).
    func audioFrequency(orbitalPeriodYears: Double) -> Double {
        let logThis = log(1.0 / orbitalPeriodYears)
        let t = (logThis - logSlowestFreq) / (logFastestFreq - logSlowestFreq)
        return frequencyMin * pow(frequencyMax / frequencyMin, t)
    }

    // MARK: - Shared instance

    static let `default` = ScaleMapping()
}
