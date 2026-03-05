import SwiftUI

struct ContentView: View {
    @StateObject private var audio = SpatialAudioEngine()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Text("Planetsound")
                    .font(.system(size: 28, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)

                OrbitView(angle: audio.angle,
                          orbitRadius: Double(audio.orbitRadius))
                    .frame(width: 280, height: 280)

                infoRow

                playButton
            }
            .padding()
        }
    }

    // MARK: - Sub-views

    private var infoRow: some View {
        HStack(spacing: 24) {
            Label("440 Hz", systemImage: "waveform")
            Label("HRTF", systemImage: "ear")
            Label(String(format: "%.0f°", audio.angle * 180 / .pi),
                  systemImage: "arrow.triangle.2.circlepath")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var playButton: some View {
        Button(action: { audio.toggle() }) {
            Image(systemName: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(audio.isPlaying ? Color.cyan : Color.white)
                .symbolEffect(.bounce, value: audio.isPlaying)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Orbit visualisation

struct OrbitView: View {
    let angle: Double       // radians
    let orbitRadius: Double // conceptual; mapped to view coords

    private let listenerRadius: CGFloat = 14
    private let sourceRadius: CGFloat   = 10

    var body: some View {
        GeometryReader { geo in
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let viewRadius = min(geo.size.width, geo.size.height) / 2 - sourceRadius - 4

            Canvas { ctx, _ in
                // ── Orbit ring ──────────────────────────────────────────
                let ringRect = CGRect(x: centre.x - viewRadius,
                                     y: centre.y - viewRadius,
                                     width: viewRadius * 2,
                                     height: viewRadius * 2)
                var ring = Path(ellipseIn: ringRect)
                ctx.stroke(ring, with: .color(.white.opacity(0.15)),
                           style: StrokeStyle(lineWidth: 1, dash: [4, 6]))

                // ── Listener (user) ──────────────────────────────────────
                let listenerRect = CGRect(x: centre.x - listenerRadius,
                                         y: centre.y - listenerRadius,
                                         width: listenerRadius * 2,
                                         height: listenerRadius * 2)
                ctx.fill(Path(ellipseIn: listenerRect),
                         with: .color(.white.opacity(0.9)))

                // "You" label
                var text = Text("You").font(.system(size: 9, weight: .semibold))
                ctx.draw(text, at: CGPoint(x: centre.x, y: centre.y + listenerRadius + 8))

                // ── Sound source ─────────────────────────────────────────
                // angle=0 → right side; sin → downward (matches CoreAudio z-axis mapped to y)
                let sx = centre.x + viewRadius * CGFloat(cos(angle))
                let sy = centre.y + viewRadius * CGFloat(sin(angle))

                // Glow
                let glowRect = CGRect(x: sx - sourceRadius * 2,
                                      y: sy - sourceRadius * 2,
                                      width: sourceRadius * 4,
                                      height: sourceRadius * 4)
                ctx.fill(Path(ellipseIn: glowRect),
                         with: .color(.cyan.opacity(0.2)))

                // Sphere
                let sourceRect = CGRect(x: sx - sourceRadius,
                                        y: sy - sourceRadius,
                                        width: sourceRadius * 2,
                                        height: sourceRadius * 2)
                ctx.fill(Path(ellipseIn: sourceRect), with: .color(.cyan))

                // Hz label
                var hzText = Text("440 Hz").font(.system(size: 8))
                ctx.draw(hzText, at: CGPoint(x: sx, y: sy - sourceRadius - 7),
                         anchor: .center)

                // Line from listener to source
                var line = Path()
                line.move(to: centre)
                line.addLine(to: CGPoint(x: sx, y: sy))
                ctx.stroke(line, with: .color(.cyan.opacity(0.25)),
                           style: StrokeStyle(lineWidth: 1))
            }
        }
    }
}

#Preview {
    ContentView()
}
