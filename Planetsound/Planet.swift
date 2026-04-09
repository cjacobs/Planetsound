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
    /// Mean ecliptic longitude at the J2000.0 epoch (degrees).
    let meanLongitudeJ2000Deg: Double
    /// Longitude of perihelion at J2000.0, ω̄ = Ω + ω (degrees).
    let longitudeOfPerihelionDeg: Double
    /// Inclination of the orbital plane relative to the ecliptic (degrees).
    let inclinationDeg: Double
    /// Longitude of the ascending node Ω at J2000.0 (degrees).
    let longitudeOfAscendingNodeDeg: Double
    /// Display colour for the orbit view.
    let color: Color
    /// Radius of the planet sphere in the orbit canvas (points).
    let displayRadius: CGFloat

    var id: String { name }

    // MARK: - Derived orbital quantities

    /// Semi-minor axis, preserving the real eccentricity.
    var semiMinorAxisAU: Double { semiMajorAxisAU * sqrt(1 - eccentricity * eccentricity) }

    /// Mean motion in degrees per day, derived from the orbital period.
    var meanMotionDegPerDay: Double { 360.0 / (orbitalPeriodYears * 365.25) }

    /// Argument of perihelion ω = ω̄ − Ω (degrees).
    var argumentOfPerihelionDeg: Double { longitudeOfPerihelionDeg - longitudeOfAscendingNodeDeg }

    // MARK: - Frequency mapping

    /// Audio frequency derived from planetary mass.
    ///
    /// Mass is log-mapped inversely onto a 3-octave range (110–880 Hz):
    /// heavier planets sound lower, lighter ones sound higher.
    var audioFrequency: Double {
        // Jupiter (317.8 M⊕) → 110 Hz; Pluto (0.00218 M⊕) → 880 Hz.
        let logHeaviest = log(317.8)
        let logLightest = log(0.00218)
        let t = (log(massEarthMasses) - logHeaviest) / (logLightest - logHeaviest)
        return 110.0 * pow(8.0, max(0, min(1, t)))
    }

    // MARK: - Orbital data (IAU mean values, J2000.0 elements from Standish 1992 / JPL)

    static let all: [Planet] = [
        Planet(name: "Mercury",
               semiMajorAxisAU: 0.387,  eccentricity: 0.206,  orbitalPeriodYears: 0.241,
               massEarthMasses: 0.0553,
               meanLongitudeJ2000Deg: 252.251, longitudeOfPerihelionDeg:  77.456,
               inclinationDeg: 7.005,   longitudeOfAscendingNodeDeg:  48.331,
               color: .gray,                                             displayRadius: 4),
        Planet(name: "Venus",
               semiMajorAxisAU: 0.723,  eccentricity: 0.007,  orbitalPeriodYears: 0.615,
               massEarthMasses: 0.815,
               meanLongitudeJ2000Deg: 181.980, longitudeOfPerihelionDeg: 131.564,
               inclinationDeg: 3.395,   longitudeOfAscendingNodeDeg:  76.680,
               color: Color(red: 0.90, green: 0.80, blue: 0.55),        displayRadius: 6),
        Planet(name: "Earth",
               semiMajorAxisAU: 1.000,  eccentricity: 0.017,  orbitalPeriodYears: 1.000,
               massEarthMasses: 1.000,
               meanLongitudeJ2000Deg: 100.464, longitudeOfPerihelionDeg: 102.937,
               inclinationDeg: 0.000,   longitudeOfAscendingNodeDeg:   0.000,
               color: Color(red: 0.25, green: 0.55, blue: 1.00),        displayRadius: 6),
        Planet(name: "Mars",
               semiMajorAxisAU: 1.524,  eccentricity: 0.093,  orbitalPeriodYears: 1.881,
               massEarthMasses: 0.1075,
               meanLongitudeJ2000Deg: 355.433, longitudeOfPerihelionDeg: 336.060,
               inclinationDeg: 1.850,   longitudeOfAscendingNodeDeg:  49.558,
               color: Color(red: 0.85, green: 0.40, blue: 0.20),        displayRadius: 5),
        Planet(name: "Jupiter",
               semiMajorAxisAU: 5.203,  eccentricity: 0.049,  orbitalPeriodYears: 11.86,
               massEarthMasses: 317.8,
               meanLongitudeJ2000Deg:  34.352, longitudeOfPerihelionDeg:  14.331,
               inclinationDeg: 1.303,   longitudeOfAscendingNodeDeg: 100.464,
               color: Color(red: 0.85, green: 0.70, blue: 0.50),        displayRadius: 11),
        Planet(name: "Saturn",
               semiMajorAxisAU: 9.537,  eccentricity: 0.057,  orbitalPeriodYears: 29.46,
               massEarthMasses: 95.16,
               meanLongitudeJ2000Deg:  50.077, longitudeOfPerihelionDeg:  93.057,
               inclinationDeg: 2.486,   longitudeOfAscendingNodeDeg: 113.666,
               color: Color(red: 0.90, green: 0.85, blue: 0.60),        displayRadius: 9),
        Planet(name: "Uranus",
               semiMajorAxisAU: 19.19,  eccentricity: 0.046,  orbitalPeriodYears: 84.01,
               massEarthMasses: 14.54,
               meanLongitudeJ2000Deg: 314.055, longitudeOfPerihelionDeg: 173.005,
               inclinationDeg: 0.773,   longitudeOfAscendingNodeDeg:  74.006,
               color: Color(red: 0.50, green: 0.85, blue: 0.90),        displayRadius: 7),
        Planet(name: "Neptune",
               semiMajorAxisAU: 30.07,  eccentricity: 0.010,  orbitalPeriodYears: 164.8,
               massEarthMasses: 17.15,
               meanLongitudeJ2000Deg: 304.349, longitudeOfPerihelionDeg:  48.124,
               inclinationDeg: 1.770,   longitudeOfAscendingNodeDeg: 131.784,
               color: Color(red: 0.20, green: 0.35, blue: 0.95),        displayRadius: 7),
        Planet(name: "Pluto",
               semiMajorAxisAU: 39.48,  eccentricity: 0.249,  orbitalPeriodYears: 247.9,
               massEarthMasses: 0.00218,
               meanLongitudeJ2000Deg: 238.929, longitudeOfPerihelionDeg: 224.068,
               inclinationDeg: 17.14,   longitudeOfAscendingNodeDeg: 110.299,
               color: Color(red: 0.76, green: 0.65, blue: 0.53),        displayRadius: 3),
    ]
}
