import SwiftUI

struct ContentView: View {
    @State private var engine = SolarSystemEngine()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Planetsound")
                    .font(.system(size: 26, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 20)

                SolarSystemView(angles: engine.angles)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 40) {
            Label("HRTF", systemImage: "ear")

            Button(action: { engine.toggle() }) {
                Image(systemName: engine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(engine.isPlaying ? Color.yellow : Color.white)
                    .symbolEffect(.bounce, value: engine.isPlaying)
            }
            .buttonStyle(.plain)

            Label("8 worlds", systemImage: "globe")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.bottom, 24)
    }
}

// MARK: - Solar System Canvas

struct SolarSystemView: View {
    let angles: [String: Double]

    var body: some View {
        GeometryReader { geo in
            let shortSide  = min(geo.size.width, geo.size.height)
            let maxRadius  = shortSide / 2 - 20           // Neptune's orbit fits here
            let centre     = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxAU      = Planet.all.last!.semiMajorAxisAU   // 30.07 AU (Neptune)

            /// Maps AU → screen points using the same logarithmic formula as the
            /// audio engine. Swap `log(1 + x)` for `sqrt(x)` or `x` to experiment.
            func vr(_ au: Double) -> CGFloat {
                CGFloat(log(1 + au) / log(1 + maxAU)) * maxRadius
            }

            Canvas { ctx, _ in
                // ── Sun (listener) ───────────────────────────────────────
                let sr: CGFloat = 7
                ctx.fill(Path(ellipseIn: CGRect(x: centre.x - sr * 3, y: centre.y - sr * 3,
                                               width: sr * 6, height: sr * 6)),
                         with: .color(.yellow.opacity(0.12)))
                ctx.fill(Path(ellipseIn: CGRect(x: centre.x - sr * 1.6, y: centre.y - sr * 1.6,
                                               width: sr * 3.2, height: sr * 3.2)),
                         with: .color(.yellow.opacity(0.3)))
                ctx.fill(Path(ellipseIn: CGRect(x: centre.x - sr, y: centre.y - sr,
                                               width: sr * 2, height: sr * 2)),
                         with: .color(.yellow.opacity(0.95)))

                // ── Orbits + planets ─────────────────────────────────────
                for planet in Planet.all {
                    let a = vr(planet.semiMajorAxisAU)
                    let b = a * CGFloat(sqrt(1 - planet.eccentricity * planet.eccentricity))
                    let c = a * CGFloat(planet.eccentricity)

                    // Sun is at the right focus → ellipse centre is c to the left.
                    let ex = centre.x - c

                    // Orbit ring
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: ex - a, y: centre.y - b,
                                              width: a * 2, height: b * 2)),
                        with: .color(.white.opacity(0.12)),
                        style: StrokeStyle(lineWidth: 0.5)
                    )

                    // Planet position on the ellipse (parametric angle θ)
                    let θ  = angles[planet.name] ?? 0
                    let px = ex + a * CGFloat(cos(θ))
                    let py = centre.y + b * CGFloat(sin(θ))
                    let r  = planet.displayRadius

                    // Glow
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - r * 2.5, y: py - r * 2.5,
                                              width: r * 5, height: r * 5)),
                        with: .color(planet.color.opacity(0.2))
                    )

                    // Sphere
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - r, y: py - r,
                                              width: r * 2, height: r * 2)),
                        with: .color(planet.color)
                    )

                    // Label — only drawn if there is room (outer planets are larger)
                    ctx.draw(
                        Text(planet.name)
                            .font(.system(size: 7))
                            .foregroundStyle(.white.opacity(0.6)),
                        at: CGPoint(x: px, y: py + r + 7),
                        anchor: .center
                    )
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
