import SwiftUI

/// Data model for one planet: real orbital mechanics + audio/visual properties.
struct Planet: Identifiable {
    let name: String
    /// Semi-major axis of the orbit in AU (IAU values).
    let semiMajorAxisAU: Double
    /// Orbital eccentricity (0 = circle, <1 = ellipse).
    let eccentricity: Double
    /// Sidereal orbital period in Earth years.
    let orbitalPeriodYears: Double
    /// Mass relative to Earth (Earth = 1).
    let massEarthMasses: Double
    /// Display colour for the orbit view.
    let color: Color
    /// Radius of the planet sphere in the orbit canvas (points).
    let displayRadius: CGFloat

    var id: String { name }

    /// Semi-minor axis, preserving the real eccentricity.
    var semiMinorAxisAU: Double { semiMajorAxisAU * sqrt(1 - eccentricity * eccentricity) }

    // MARK: - Frequency mapping

    /// Audio frequency derived from planetary mass.
    ///
    /// Mass is log-mapped inversely onto a 3-octave range (110–880 Hz):
    /// heavier planets sound lower, lighter planets sound higher.
    /// As a pleasant coincidence, Earth (1 M⊕) lands at ≈ 440 Hz (A4).
    var audioFrequency: Double {
        // Fixed reference masses: Jupiter (heaviest) → 110 Hz, Mercury (lightest) → 880 Hz.
        let logHeaviest = log(317.8)   // Jupiter
        let logLightest = log(0.0553)  // Mercury
        let t = (log(massEarthMasses) - logHeaviest) / (logLightest - logHeaviest)  // 0…1
        return 110.0 * pow(8.0, t)
    }

    // MARK: - Orbital data (IAU mean values)

    static let all: [Planet] = [
        Planet(name: "Mercury",
               semiMajorAxisAU: 0.387, eccentricity: 0.206, orbitalPeriodYears: 0.241,
               massEarthMasses: 0.0553,
               color: .gray, displayRadius: 4),
        Planet(name: "Venus",
               semiMajorAxisAU: 0.723, eccentricity: 0.007, orbitalPeriodYears: 0.615,
               massEarthMasses: 0.815,
               color: Color(red: 0.90, green: 0.80, blue: 0.55), displayRadius: 6),
        Planet(name: "Earth",
               semiMajorAxisAU: 1.000, eccentricity: 0.017, orbitalPeriodYears: 1.000,
               massEarthMasses: 1.000,
               color: Color(red: 0.25, green: 0.55, blue: 1.00), displayRadius: 6),
        Planet(name: "Mars",
               semiMajorAxisAU: 1.524, eccentricity: 0.093, orbitalPeriodYears: 1.881,
               massEarthMasses: 0.1075,
               color: Color(red: 0.85, green: 0.40, blue: 0.20), displayRadius: 5),
        Planet(name: "Jupiter",
               semiMajorAxisAU: 5.203, eccentricity: 0.049, orbitalPeriodYears: 11.86,
               massEarthMasses: 317.8,
               color: Color(red: 0.85, green: 0.70, blue: 0.50), displayRadius: 11),
        Planet(name: "Saturn",
               semiMajorAxisAU: 9.537, eccentricity: 0.057, orbitalPeriodYears: 29.46,
               massEarthMasses: 95.16,
               color: Color(red: 0.90, green: 0.85, blue: 0.60), displayRadius: 9),
        Planet(name: "Uranus",
               semiMajorAxisAU: 19.19, eccentricity: 0.046, orbitalPeriodYears: 84.01,
               massEarthMasses: 14.54,
               color: Color(red: 0.50, green: 0.85, blue: 0.90), displayRadius: 7),
        Planet(name: "Neptune",
               semiMajorAxisAU: 30.07, eccentricity: 0.010, orbitalPeriodYears: 164.8,
               massEarthMasses: 17.15,
               color: Color(red: 0.20, green: 0.35, blue: 0.95), displayRadius: 7),
        Planet(name: "Pluto",
               semiMajorAxisAU: 39.48, eccentricity: 0.249, orbitalPeriodYears: 248.0,
               color: Color(red: 0.72, green: 0.62, blue: 0.55), displayRadius: 3),
    ]
}
