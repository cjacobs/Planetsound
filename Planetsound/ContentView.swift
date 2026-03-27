import SwiftUI

struct ContentView: View {
    @State private var audio = SpatialAudioEngine()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Text("Planetsound")
                    .font(.system(size: 28, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)

                OrbitView(angle: audio.angle,
                          semiMajorAxis: Double(audio.semiMajorAxis),
                          semiMinorAxis: Double(audio.semiMinorAxis))
                    .frame(width: 300, height: 220)

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
    let angle: Double        // radians; parametric angle on the ellipse
    let semiMajorAxis: Double
    let semiMinorAxis: Double

    private let listenerRadius: CGFloat = 14
    private let sourceRadius: CGFloat   = 10

    var body: some View {
        GeometryReader { geo in
            // Scale so the full ellipse fits with padding.
            let padding = sourceRadius + 4
            let a = geo.size.width  / 2 - padding   // semi-major in screen pts
            let b = a * (semiMinorAxis / semiMajorAxis) // semi-minor, preserving ratio
            let c = sqrt(a * a - b * b)               // focal distance in screen pts

            // Ellipse is centred on the canvas; listener sits at the right focus.
            let ellipseCentre = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let listenerPt    = CGPoint(x: ellipseCentre.x + c, y: ellipseCentre.y)

            // Source parametric position (ellipse centred at ellipseCentre).
            let sx = ellipseCentre.x + a * CGFloat(cos(angle))
            let sy = ellipseCentre.y + b * CGFloat(sin(angle))
            let sourcePt = CGPoint(x: sx, y: sy)

            Canvas { ctx, _ in
                // ── Orbit ellipse ────────────────────────────────────────
                let ringRect = CGRect(x: ellipseCentre.x - a,
                                     y: ellipseCentre.y - b,
                                     width: a * 2, height: b * 2)
                ctx.stroke(Path(ellipseIn: ringRect),
                           with: .color(.white.opacity(0.15)),
                           style: StrokeStyle(lineWidth: 1, dash: [4, 6]))

                // ── Listener (user) at focus ──────────────────────────────
                let listenerRect = CGRect(x: listenerPt.x - listenerRadius,
                                         y: listenerPt.y - listenerRadius,
                                         width: listenerRadius * 2,
                                         height: listenerRadius * 2)
                ctx.fill(Path(ellipseIn: listenerRect),
                         with: .color(.white.opacity(0.9)))

                let youLabel = Text("You").font(.system(size: 9, weight: .semibold))
                ctx.draw(youLabel,
                         at: CGPoint(x: listenerPt.x, y: listenerPt.y + listenerRadius + 8))

                // ── Sound source ─────────────────────────────────────────
                let glowRect = CGRect(x: sourcePt.x - sourceRadius * 2,
                                     y: sourcePt.y - sourceRadius * 2,
                                     width: sourceRadius * 4,
                                     height: sourceRadius * 4)
                ctx.fill(Path(ellipseIn: glowRect),
                         with: .color(.cyan.opacity(0.2)))

                let sourceRect = CGRect(x: sourcePt.x - sourceRadius,
                                        y: sourcePt.y - sourceRadius,
                                        width: sourceRadius * 2,
                                        height: sourceRadius * 2)
                ctx.fill(Path(ellipseIn: sourceRect), with: .color(.cyan))

                let hzText = Text("440 Hz").font(.system(size: 8))
                ctx.draw(hzText,
                         at: CGPoint(x: sourcePt.x, y: sourcePt.y - sourceRadius - 7),
                         anchor: .center)

                // ── Line from focus (listener) to source ─────────────────
                var line = Path()
                line.move(to: listenerPt)
                line.addLine(to: sourcePt)
                ctx.stroke(line, with: .color(.cyan.opacity(0.25)),
                           style: StrokeStyle(lineWidth: 1))
            }
        }
    }
}

#Preview {
    ContentView()
}
