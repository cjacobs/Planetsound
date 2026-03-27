import AVFoundation
import Observation

/// Manages a 440 Hz sine-wave tone that orbits the listener using AVAudioEnvironmentNode.
@MainActor
@Observable
final class SpatialAudioEngine {

    // MARK: - Observable state

    /// Current angle of the sound source, in radians (0 = right, counter-clockwise).
    private(set) var angle: Double = 0
    /// Whether the engine is currently playing.
    private(set) var isPlaying = false

    // MARK: - Audio graph

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let player = AVAudioPlayerNode()
    @ObservationIgnored private let environment = AVAudioEnvironmentNode()

    // MARK: - Orbit parameters

    /// Semi-major axis of the elliptical orbit in metres.
    let semiMajorAxis: Float = 2.0
    /// Semi-minor axis of the elliptical orbit in metres.
    let semiMinorAxis: Float = 1.6
    /// Distance from ellipse centre to each focus (listener sits at one focus).
    var focalDistance: Float { sqrt(semiMajorAxis * semiMajorAxis - semiMinorAxis * semiMinorAxis) }
    /// Time in seconds for one full revolution.
    let revolutionDuration: Double = 8

    // MARK: - Animation

    @ObservationIgnored private var orbitTimer: Timer?
    @ObservationIgnored private var startDate: Date?

    // MARK: - Init

    init() {
        configureAudioSession()
        buildGraph()
    }

    // MARK: - Public API

    func play() {
        guard !isPlaying else { return }
        try? engine.start()
        scheduleSineBuffer()
        player.play()
        startOrbiting()
        isPlaying = true
    }

    func stop() {
        guard isPlaying else { return }
        player.stop()
        engine.stop()
        stopOrbiting()
        isPlaying = false
    }

    func toggle() {
        isPlaying ? stop() : play()
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
        engine.attach(player)
        engine.attach(environment)

        // Mono player → environment → mainMixerNode
        let monoFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(player, to: environment, format: monoFormat)
        engine.connect(environment, to: engine.mainMixerNode, format: nil)

        // Listener stays at the origin (default); enable HRTF rendering.
        environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.renderingAlgorithm = .HRTF
        environment.reverbParameters.enable = true
        environment.reverbParameters.level = -10

        // Place player node at periapsis (θ=0) of the ellipse.
        player.position = AVAudio3DPoint(x: semiMajorAxis - focalDistance, y: 0, z: 0)
    }

    // MARK: - Private – tone generation

    private func makeSineBuffer(frequency: Double = 440,
                                sampleRate: Double = 44100,
                                durationSeconds: Double = 2) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        let twoPi = 2.0 * Double.pi
        for i in 0..<Int(frameCount) {
            // Soft fade-in / fade-out over 512 samples to avoid clicks on loop.
            let fade: Float
            let fadeSamples = 512
            if i < fadeSamples {
                fade = Float(i) / Float(fadeSamples)
            } else if i >= Int(frameCount) - fadeSamples {
                fade = Float(Int(frameCount) - i) / Float(fadeSamples)
            } else {
                fade = 1
            }
            data[i] = Float(sin(twoPi * frequency * Double(i) / sampleRate)) * 0.5 * fade
        }
        return buffer
    }

    private func scheduleSineBuffer() {
        let buffer = makeSineBuffer()
        player.scheduleBuffer(buffer, at: nil, options: .loops)
    }

    // MARK: - Private – orbit animation

    private func startOrbiting() {
        startDate = Date()
        // ~60 fps timer; works on both iOS and macOS.
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateOrbit()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        orbitTimer = timer
    }

    private func stopOrbiting() {
        orbitTimer?.invalidate()
        orbitTimer = nil
        startDate = nil
    }

    private func updateOrbit() {
        guard let start = startDate else { return }
        let elapsed = Date().timeIntervalSince(start)
        let fraction = elapsed.truncatingRemainder(dividingBy: revolutionDuration) / revolutionDuration
        let theta = fraction * 2 * .pi
        angle = theta

        // Ellipse with listener at focus: x = a·cos(θ) − c,  z = b·sin(θ)
        let x = Float(cos(theta)) * semiMajorAxis - focalDistance
        let z = Float(sin(theta)) * semiMinorAxis   // z = depth axis; y = height
        player.position = AVAudio3DPoint(x: x, y: 0, z: z)
    }
}
