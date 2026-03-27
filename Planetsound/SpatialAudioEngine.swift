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

    private func makeSineBuffer(frequency: Double,
                                sampleRate: Double = 44100,
                                duration: Double = 2) -> AVAudioPCMBuffer {
        // Use an exact integer number of wave cycles so the buffer loops
        // seamlessly without any phase discontinuity.
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

    private func scheduleTone(for planet: Planet) {
        let buffer = makeSineBuffer(frequency: mapping.audioFrequency(orbitalPeriodYears: planet.orbitalPeriodYears))
        playerNodes[planet.name]?.scheduleBuffer(buffer, at: nil, options: .loops)
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

        // Mercury's angular velocity in rad/s.
        let ωMercury = 2.0 * Double.pi / mercuryRevolutionDuration

        for planet in Planet.all {
            // Each planet's ω scales by the ratio of Mercury's period to its own
            // (shorter period = faster angular velocity).
            let ω = ωMercury * (0.241 / planet.orbitalPeriodYears)
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
