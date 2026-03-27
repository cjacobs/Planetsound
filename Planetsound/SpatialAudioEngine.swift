import AVFoundation
import Observation

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

    let mapping = ScaleMapping.default

    // MARK: - Audio graph

    @ObservationIgnored private let engine      = AVAudioEngine()
    @ObservationIgnored private let environment = AVAudioEnvironmentNode()
    @ObservationIgnored private var playerNodes: [String: AVAudioPlayerNode] = [:]

    // MARK: - Animation

    @ObservationIgnored private var orbitTimer: Timer?
    @ObservationIgnored private var startDate:  Date?

    // MARK: - Init

    init() {
        configureAudioSession()
        buildGraph()
    }

    // MARK: - Public API

    func play() {
        guard !isPlaying else { return }
        try? engine.start()
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
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
#endif
    }

    private func buildGraph() {
        engine.attach(environment)
        environment.listenerPosition    = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.renderingAlgorithm  = .HRTF
        environment.reverbParameters.enable = true
        environment.reverbParameters.level  = -20

        let monoFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        for planet in Planet.all {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: environment, format: monoFormat)
            playerNodes[planet.name] = node
            // Start at periapsis (θ = 0).
            let a = Float(mapping.audioDistance(au: planet.semiMajorAxisAU))
            let c = a * Float(planet.eccentricity)
            node.position = AVAudio3DPoint(x: a - c, y: 0, z: 0)
        }
        engine.connect(environment, to: engine.mainMixerNode, format: nil)
    }

    // MARK: - Private – tone generation

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
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateOrbits() }
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
            let ω = angularVelocity(for: planet)
            let θ = ω * elapsed
            angles[planet.name] = θ

            // 3D position: listener (sun) at origin, planet on ellipse.
            // x = a·cos(θ) − c   z = b·sin(θ)
            let a = Float(mapping.audioDistance(au: planet.semiMajorAxisAU))
            let b = a * Float(sqrt(1.0 - planet.eccentricity * planet.eccentricity))
            let c = a * Float(planet.eccentricity)
            playerNodes[planet.name]?.position = AVAudio3DPoint(
                x: a * Float(cos(θ)) - c,
                y: 0,
                z: b * Float(sin(θ))
            )
        }
    }
}
