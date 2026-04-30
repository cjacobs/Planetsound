import SwiftUI
import AVKit

struct ContentView: View {
    @State private var engine = SolarSystemEngine()
    @State private var usePlanetSymbols = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // Force dark appearance so system controls (pickers, etc.) render correctly
            // on the black background regardless of the system-wide color scheme.
            .preferredColorScheme(.dark)

            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("Planet")
                        .font(.system(size: 26, weight: .thin, design: .rounded))
                    Text("*")
                        .font(.system(size: 16, weight: .light, design: .rounded))
                        .baselineOffset(10)
                    Text("sound")
                        .font(.system(size: 26, weight: .thin, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.top, 20)

                SolarSystemView(angles: engine.angles)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
            }
            #if os(iOS)
            .overlay(alignment: .topTrailing) {
                AirPlayButton()
                    .frame(width: 44, height: 44)
                    .padding(.trailing, 16)
                    .padding(.top, 8)
            }
            #endif
        }
    }

    
    private var footer: some View {
        VStack(spacing: 12)
        {
            planetPositionPicker

            planetToggles

            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Image(systemName: "hifispeaker.2.fill")
                        .hidden()
                        .overlay {
                            Image(systemName: engine.isSurround ? "hifispeaker.2.fill" : "ear")
                        }
                    Text("Surround")
                        .hidden()
                        .overlay {
                            Text(engine.isSurround ? "Surround" : "HRTF")
                        }
                }

                Button(action: { engine.toggle() }) {
                    Image(systemName: engine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(engine.isPlaying ? Color.yellow : Color.white)
                        .symbolEffect(.bounce, value: engine.isPlaying)
                }
                .buttonStyle(.plain)

                generatorPicker

                Button { engine.setSurround(!engine.isSurround) } label: {
                    Image(systemName: "hifispeaker.2.fill")
                        .hidden()
                        .overlay {
                            Image(systemName: engine.isSurround ? "hifispeaker.2.fill" : "hifispeaker.fill")
                                .foregroundStyle(engine.isSurround ? .white : .secondary)
                        }
                }
                .buttonStyle(.plain)
                .help(engine.isSurround ? "Switch to binaural (HRTF)" : "Switch to surround (multi-channel)")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.bottom, 24)
    }
    
    private var planetPositionPicker: some View {
        Picker("Start", selection: Binding(
            get: { engine.startingConfiguration },
            set: { engine.startingConfiguration = $0 }
        )) {
            ForEach(StartingConfiguration.allCases, id: \.self) {
                Text($0.rawValue).tag($0)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 240)
    }

    private var planetToggles: some View {
        HStack(spacing: 6) {
            Button {
                usePlanetSymbols.toggle()
            } label: {
                Text("♃")
                    .font(.system(size: 14))
                    .foregroundStyle(usePlanetSymbols ? .white : .white.opacity(0.35))
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(usePlanetSymbols ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(usePlanetSymbols ? Color.white.opacity(0.35) : Color.white.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 16)
                .padding(.trailing, 2)

            ForEach(Planet.all) { planet in
                let enabled = engine.planetEnabled[planet.name] ?? true
                Button {
                    engine.setPlanetEnabled(planet.name, enabled: !enabled)
                } label: {
                    let planetLabel = planetAbbreviation(planet.name)
                    Text(planetLabel)
                        .font(.system(size: usePlanetSymbols ? 14 : 11, weight: .medium, design: .rounded))
                        .foregroundStyle(enabled ? .white : .white.opacity(0.35))
                        .frame(width: 28, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(enabled ? planet.color.opacity(0.7) : Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(enabled ? Color.clear : Color.white.opacity(0.25))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var generatorPicker: some View {
        Picker("Generator", selection: Binding(
            get: { engine.generator },
            set: { engine.setGenerator($0) }
        )) {
            ForEach(SoundGenerator.allCases) { gen in
                Text(gen.label).tag(gen)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 180)
    }

    private func planetAbbreviation(_ name: String) -> String {
        if usePlanetSymbols {
            switch name {
            case "Mercury": "☿"
            case "Venus":   "♀"
            case "Earth":   "♁"
            case "Mars":    "♂"
            case "Jupiter": "♃"
            case "Saturn":  "♄"
            case "Uranus":  "♅"
            case "Neptune": "♆"
            case "Pluto":   "♇"
            default:        String(name.prefix(1))
            }
        } else {
            switch name {
            case "Mercury": "Me"
            case "Venus":   "Ve"
            case "Earth":   "Ea"
            case "Mars":    "Ma"
            case "Jupiter": "Ju"
            case "Saturn":  "Sa"
            case "Uranus":  "Ur"
            case "Neptune": "Ne"
            case "Pluto":   "Pl"
            default:        String(name.prefix(2))
            }
        }
    }
}

// MARK: - Solar System Canvas

struct SolarSystemView: View {
    let angles: [String: Double]

    var body: some View {
        GeometryReader { geo in
            let shortSide  = min(geo.size.width, geo.size.height)
            let maxRadius  = shortSide / 2 - 20
            let center     = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let mapping    = ScaleMapping.default

            Canvas { ctx, _ in
                // ── Sun (listener) ───────────────────────────────────────
                let sr: CGFloat = 7
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - sr * 3, y: center.y - sr * 3,
                                               width: sr * 6, height: sr * 6)),
                         with: .color(.yellow.opacity(0.12)))
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - sr * 1.6, y: center.y - sr * 1.6,
                                               width: sr * 3.2, height: sr * 3.2)),
                         with: .color(.yellow.opacity(0.3)))
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - sr, y: center.y - sr,
                                               width: sr * 2, height: sr * 2)),
                         with: .color(.yellow.opacity(0.95)))

                // ── Orbits + planets ─────────────────────────────────────
                for planet in Planet.all {
                    let a = mapping.screenRadius(au: planet.semiMajorAxisAU, maxRadius: maxRadius)
                    let b = a * CGFloat(sqrt(1 - planet.eccentricity * planet.eccentricity))
                    let c = a * CGFloat(planet.eccentricity)

                    // Sun is at the right focus → ellipse center is c to the left.
                    let ex = center.x - c

                    // Orbit ring
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: ex - a, y: center.y - b,
                                              width: a * 2, height: b * 2)),
                        with: .color(.white.opacity(0.12)),
                        style: StrokeStyle(lineWidth: 0.5)
                    )

                    // Planet position on the ellipse (parametric angle θ)
                    let θ  = angles[planet.name] ?? 0
                    let px = ex + a * CGFloat(cos(θ))
                    let py = center.y + b * CGFloat(sin(θ))
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

#if os(iOS)
/// Wraps AVRoutePickerView to present the system AirPlay / audio output picker.
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = .white
        picker.backgroundColor = .clear
        picker.prioritizesVideoDevices = false
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
#endif

#Preview {
    ContentView()
}
