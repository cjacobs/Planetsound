import AVFoundation
import Observation

// MARK: - Starting configuration

enum StartingConfiguration: String, CaseIterable {
    case realWorld = "Real World"
    case random    = "Random"
}

/// Manages one spatial audio source per planet, all orbiting the listener
/// (positioned at the origin — the center of the solar system).
@MainActor
@Observable
final class SolarSystemEngine {

    // MARK: - Observable state

    /// Current parametric angle (radians) for each planet, keyed by name.
    private(set) var angles: [String: Double] = Dictionary(
        uniqueKeysWithValues: Planet.all.map { ($0.name, 0.0) }
    )
    private(set) var isPlaying = false

    // MARK: - Starting configuration

    /// Controls what angle each planet starts at. Changing this immediately
    /// updates the visual and (if playing) resets the animation origin.
    var startingConfiguration: StartingConfiguration = .realWorld {
        didSet { applyConfiguration() }
    }

    // Per-planet phase offsets (radians) applied at t = 0.
    @ObservationIgnored private var angleOffsets: [String: Double] = [:]
    /// Per-planet mute state. `true` means the planet is audible.
    var planetEnabled: [String: Bool] = Dictionary(
        uniqueKeysWithValues: Planet.all.map { ($0.name, true) }
    )

    /// The active sound generation strategy.
    private(set) var generator: SoundGenerator = .sine

    // MARK: - Orbit parameters

    /// Seconds Mercury takes to complete one full orbit.
    /// All other planets scale proportionally by Kepler's third law.
    let mercuryRevolutionDuration: Double = 10

    /// Maps a semi-major axis in AU to a 3D audio radius in metres.
    ///
    /// Swap this closure to experiment with different perceptual scales.
    /// The default is a logarithmic mapping: Pluto → 4 m, Mercury → 0.4 m.
    var audioDistanceScale: (Double) -> Double = { au in
        let maxAU = 39.48   // Pluto
        let t = log(1 + au) / log(1 + maxAU)   // normalised 0…1
        return 0.4 + t * 3.6                    // 0.4 m … 4.0 m
    }

    // MARK: - Audio graph

    @ObservationIgnored private let engine      = AVAudioEngine()
    @ObservationIgnored private let environment = AVAudioEnvironmentNode()
    @ObservationIgnored private var playerNodes: [String: AVAudioPlayerNode] = [:]
    /// Actual hardware sample rate, resolved in buildGraph().
    @ObservationIgnored private var bufferSampleRate: Double = 44100

    // MARK: - Animation

    @ObservationIgnored private var orbitTimer: Timer?
    @ObservationIgnored private var startDate:  Date?

    // MARK: - Init

    init() {
        configureAudioSession()
        buildGraph()
        applyConfiguration()   // sets initial angles to real-world positions
    }

    // MARK: - Public API

    func play() {
        guard !isPlaying else { return }
        do {
            try engine.start()
        } catch {
            print("SolarSystemEngine: failed to start audio engine — \(error)")
            return
        }
        for planet in Planet.all {
            scheduleTone(for: planet)
            playerNodes[planet.name]?.play()
        }
        startOrbiting()
        isPlaying = true
    }

    func stop() {
        guard isPlaying else { return }
        for node in playerNodes.values { node.stop() }
        engine.stop()
        stopOrbiting()
        isPlaying = false
    }

    func toggle() { isPlaying ? stop() : play() }

    // MARK: - Private – configuration

    private func applyConfiguration() {
        switch startingConfiguration {
        case .realWorld:
            angleOffsets = realWorldOffsets()
        case .random:
            angleOffsets = Dictionary(uniqueKeysWithValues:
                Planet.all.map { ($0.name, Double.random(in: 0 ..< 2 * .pi)) }
            )
        }
        // Reflect in the visual immediately.
        for planet in Planet.all {
            angles[planet.name] = angleOffsets[planet.name] ?? 0
        }
        // If already animating, reset the clock so elapsed restarts from 0
        // with the new offsets as the starting positions.
        if isPlaying { startDate = Date() }
    }

    /// Computes each planet's mean anomaly at the current date using J2000
    /// orbital elements and the planet's mean daily motion.
    private func realWorldOffsets() -> [String: Double] {
        // J2000.0 = 2000-Jan-01 12:00 UTC (Unix timestamp 946728000)
        let j2000 = Date(timeIntervalSince1970: 946_728_000)
        let daysSinceJ2000 = Date().timeIntervalSince(j2000) / 86_400

        return Dictionary(uniqueKeysWithValues: Planet.all.map { planet in
            // Advance the mean longitude from J2000 to today.
            let currentLongDeg = planet.meanLongitudeJ2000Deg
                + planet.meanMotionDegPerDay * daysSinceJ2000
            // Mean anomaly = mean longitude − longitude of perihelion.
            let meanAnomalyDeg = currentLongDeg - planet.longitudeOfPerihelionDeg
            let rad = meanAnomalyDeg * .pi / 180
            return (planet.name, rad)
        })
    /// Mutes or unmutes a single planet by setting its player node volume.
    func setPlanetEnabled(_ name: String, enabled: Bool) {
        planetEnabled[name] = enabled
        playerNodes[name]?.volume = enabled ? 1.0 : 0.0
    }

    /// Switches the sound generator and re-schedules all currently playing buffers.
    func setGenerator(_ newGenerator: SoundGenerator) {
        guard newGenerator != generator else { return }
        generator = newGenerator
        guard isPlaying else { return }
        for planet in Planet.all {
            guard let node = playerNodes[planet.name] else { continue }
            node.stop()
            scheduleTone(for: planet)
            node.play()
        }
    }

    // MARK: - Private – audio setup

    private func configureAudioSession() {
#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("SolarSystemEngine: audio session configuration failed — \(error)")
        }
#endif
    }

    private func buildGraph() {
        // Query the hardware sample rate before building the graph so buffers
        // are generated at the correct rate and no sample-rate conversion occurs.
        let hwRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        bufferSampleRate = hwRate > 0 ? hwRate : 44100

        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: bufferSampleRate,
                                             channels: 1) else {
            print("SolarSystemEngine: failed to create AVAudioFormat")
            return
        }

        engine.attach(environment)
        environment.listenerPosition    = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.renderingAlgorithm  = .HRTF
        environment.reverbParameters.enable = true
        environment.reverbParameters.level  = -20

        for planet in Planet.all {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: environment, format: monoFormat)
            playerNodes[planet.name] = node
            // Start at periapsis (θ = 0); updateOrbits() refines this on first tick.
            let a = Float(audioDistanceScale(planet.semiMajorAxisAU))
            let c = a * Float(planet.eccentricity)
            node.position = AVAudio3DPoint(x: a - c, y: 0, z: 0)
        }
        engine.connect(environment, to: engine.mainMixerNode, format: nil)
    }

    // MARK: - Private – tone generation

    private func makeSineBuffer(frequency: Double, duration: Double = 2) -> AVAudioPCMBuffer {
        let sampleRate = bufferSampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        // These initialisers cannot fail for valid sample rates and frame counts.
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        let twoPi = 2.0 * Double.pi
        let fadeSamples = 512
        for i in 0..<Int(frameCount) {
            let fade: Float
            if i < fadeSamples {
                fade = Float(i) / Float(fadeSamples)
            } else if i >= Int(frameCount) - fadeSamples {
                fade = Float(Int(frameCount) - i) / Float(fadeSamples)
            } else {
                fade = 1
            }
            data[i] = Float(sin(twoPi * frequency * Double(i) / sampleRate)) * 0.12 * fade
        }
        return buffer
    }

    private func scheduleTone(for planet: Planet) {
        let freq = mapping.audioFrequency(orbitalPeriodYears: planet.orbitalPeriodYears)
        let buffer = generator.makeBuffer(
            frequency: freq,
            blipRate: angularVelocity(for: planet)
        )
        playerNodes[planet.name]?.scheduleBuffer(buffer, at: nil, options: .loops)
    }

    /// Angular velocity in rad/s for the given planet.
    private func angularVelocity(for planet: Planet) -> Double {
        let omegaMercury = 2.0 * Double.pi / mercuryRevolutionDuration
        return omegaMercury * (0.241 / planet.orbitalPeriodYears)
    }

    // MARK: - Private – orbit animation

    private func startOrbiting() {
        startDate = Date()
        // The timer is added to the main run loop, so the callback executes on
        // the main thread. MainActor.assumeIsolated lets us call @MainActor
        // methods directly without spinning up a new Task.
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateOrbits() }
        }
        RunLoop.main.add(timer, forMode: .common)
        orbitTimer = timer
    }

    private func stopOrbiting() {
        orbitTimer?.invalidate()
        orbitTimer = nil
        startDate = nil
    }

    private func updateOrbits() {
        guard let start = startDate else { return }
        let elapsed = Date().timeIntervalSince(start)

        for planet in Planet.all {
            // Each planet's angular velocity scales inversely with its period.
            let angularVelocity = ωMercury * (0.241 / planet.orbitalPeriodYears)
            let θ = angularVelocity * elapsed + (angleOffsets[planet.name] ?? 0)
            angles[planet.name] = θ

            // ── 3D position via perifocal → ecliptic rotation ────────────
            // In the orbital (perifocal) plane:
            let a = Float(audioDistanceScale(planet.semiMajorAxisAU))
            let b = a * Float(sqrt(1.0 - planet.eccentricity * planet.eccentricity))
            let c = a * Float(planet.eccentricity)
            let xPF = a * Float(cos(θ)) - c   // along major axis (toward perihelion)
            let yPF = b * Float(sin(θ))        // perpendicular in orbital plane

            // Orbital angles (radians) — distinct names to avoid shadowing θ/ω above.
            let argPeri = Float(planet.argumentOfPerihelionDeg   * .pi / 180)  // ω
            let ascNode = Float(planet.longitudeOfAscendingNodeDeg * .pi / 180) // Ω
            let incl    = Float(planet.inclinationDeg              * .pi / 180) // i
            let (cosΩ, sinΩ) = (cos(ascNode), sin(ascNode))
            let (cosω, sinω) = (cos(argPeri),  sin(argPeri))
            let (cosi, sini) = (cos(incl),     sin(incl))

            // Rotate to ecliptic frame (standard perifocal transformation):
            let xEcl = xPF * (cosΩ*cosω - sinΩ*sinω*cosi)
                     + yPF * (-cosΩ*sinω - sinΩ*cosω*cosi)
            let yEcl = xPF * (sinΩ*cosω + cosΩ*sinω*cosi)
                     + yPF * (-sinΩ*sinω + cosΩ*cosω*cosi)
            let zEcl = xPF * (sinω*sini)
                     + yPF * (cosω*sini)

            // Map ecliptic → AVAudio3DPoint: ecliptic X→audio X,
            // ecliptic Y→audio Z, ecliptic north (Z)→audio Y (up).
            playerNodes[planet.name]?.position = AVAudio3DPoint(
                x: xEcl, y: zEcl, z: yEcl
            )
        }
    }
}
