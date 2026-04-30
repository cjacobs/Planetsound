import SwiftUI
import AVKit

/// Carries the computed maxRadius from SolarSystemView up to ContentView so that
/// SideView can use the same pixels-per-AU scale.
private struct OrbitScaleKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct ContentView: View {
    @Environment(SolarSystemEngine.self) private var engine
    @State private var usePlanetSymbols = true
    @State private var showingPreferences = false
    @State private var orbitScale: CGFloat = 0

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
                    .onPreferenceChange(OrbitScaleKey.self) { orbitScale = $0 }

                SideView(angles: engine.angles, inclinationMultiplier: engine.inclinationMultiplier,
                         orbitScale: orbitScale)
                    .frame(maxWidth: .infinity, maxHeight: 120)

                inclinationSlider

                footer
            }
            #if os(iOS)
            .overlay(alignment: .topTrailing) {
                AirPlayButton()
                    .frame(width: 44, height: 44)
                    .padding(.trailing, 16)
                    .padding(.top, 8)
            }
            .sheet(isPresented: $showingPreferences) {
                PreferencesView()
                    .environment(engine)
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

                #if os(iOS)
                Button { showingPreferences = true } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                #endif

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
    
    private var inclinationSlider: some View {
        @Bindable var engine = engine
        return HStack(spacing: 10) {
            Text("Inclination")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: $engine.inclinationMultiplier, in: 0...8)
            Text("×\(engine.inclinationMultiplier, specifier: "%.1f")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
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

                // Pre-compute each planet's screen position and orbit path.
                struct PlanetDraw {
                    let planet: Planet
                    let px, py: CGFloat
                    let r: CGFloat
                    let orbitPath: Path
                }
                let draws: [PlanetDraw] = Planet.all.map { planet in
                    let a = mapping.screenRadius(au: planet.semiMajorAxisAU, maxRadius: maxRadius)
                    let b = a * CGFloat(sqrt(1 - planet.eccentricity * planet.eccentricity))
                    let c = a * CGFloat(planet.eccentricity)

                    let argPeri = CGFloat(planet.argumentOfPerihelionDeg   * .pi / 180)
                    let ascNode = CGFloat(planet.longitudeOfAscendingNodeDeg * .pi / 180)
                    let incl    = CGFloat(planet.inclinationDeg              * .pi / 180)
                    let (cosΩ, sinΩ) = (cos(ascNode), sin(ascNode))
                    let (cosω, sinω) = (cos(argPeri),  sin(argPeri))
                    let cosi = cos(incl)

                    func eclXY(_ θ: Double) -> CGPoint {
                        let xPF = a * CGFloat(cos(θ)) - c
                        let yPF = b * CGFloat(sin(θ))
                        let xEcl = xPF * (cosΩ*cosω - sinΩ*sinω*cosi)
                                 + yPF * (-cosΩ*sinω - sinΩ*cosω*cosi)
                        let yEcl = xPF * (sinΩ*cosω + cosΩ*sinω*cosi)
                                 + yPF * (-sinΩ*sinω + cosΩ*cosω*cosi)
                        return CGPoint(x: center.x + xEcl, y: center.y + yEcl)
                    }

                    // Orbit ring (traced path, since rotation makes it non-axis-aligned)
                    let steps = 90
                    var path = Path()
                    for i in 0...steps {
                        let pt = eclXY(Double(i) / Double(steps) * 2 * .pi)
                        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    }
                    path.closeSubpath()

                    let θ = angles[planet.name] ?? 0
                    let pt = eclXY(θ)
                    let r  = planet.displayRadius
                    return PlanetDraw(planet: planet, px: pt.x, py: pt.y, r: r, orbitPath: path)
                }

                // ── Pass 1: orbit rings (all behind every sphere) ─────────
                for d in draws {
                    ctx.stroke(d.orbitPath, with: .color(.white.opacity(0.12)),
                               style: StrokeStyle(lineWidth: 0.5))
                }

                // ── Pass 2: spheres sorted back-to-front by screen y ──────
                for d in draws.sorted(by: { $0.py < $1.py }) {
                    // Glow
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: d.px - d.r * 2.5, y: d.py - d.r * 2.5,
                                              width: d.r * 5, height: d.r * 5)),
                        with: .color(d.planet.color.opacity(0.2))
                    )
                    // Sphere
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: d.px - d.r, y: d.py - d.r,
                                              width: d.r * 2, height: d.r * 2)),
                        with: .color(d.planet.color)
                    )
                    // Label
                    ctx.draw(
                        Text(d.planet.name)
                            .font(.system(size: 7))
                            .foregroundStyle(.white.opacity(0.6)),
                        at: CGPoint(x: d.px, y: d.py + d.r + 7),
                        anchor: .center
                    )
                }
            }
            .preference(key: OrbitScaleKey.self, value: maxRadius)
        }
    }
}

// MARK: - Side View (edge-on / inclination view)

/// Shows the solar system edge-on: horizontal axis is ecliptic X, vertical axis
/// is ecliptic Z (north of the ecliptic plane). Earth appears as a flat line;
/// other planets are tilted by their orbital inclinations, scaled by `inclinationMultiplier`.
struct SideView: View {
    let angles: [String: Double]
    let inclinationMultiplier: Double
    /// Shared pixels-per-AU scale from SolarSystemView. Zero means not yet known.
    var orbitScale: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w  = geo.size.width
            let h  = geo.size.height
            let cx = w / 2
            let cy = h / 2
            let maxR  = orbitScale > 0 ? orbitScale : (w / 2 - 16)
            let mapping = ScaleMapping.default

            // Fix the z-scale so Pluto's orbit just fills the view at multiplier = 1.
            let aPluto = mapping.screenRadius(au: mapping.maxAU, maxRadius: maxR)
            let maxZRef = aPluto * CGFloat(sin(Planet.all.last(where: { $0.name == "Pluto" })?.inclinationDeg ?? 17.1) * .pi / 180)
            let zScale: CGFloat = maxZRef > 0 ? h * 0.42 / maxZRef : 1

            Canvas { ctx, _ in
                // Ecliptic reference line
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: 0, y: cy))
                    p.addLine(to: CGPoint(x: w, y: cy))
                }, with: .color(.white.opacity(0.18)), lineWidth: 0.5)

                // Sun
                let sr: CGFloat = 7
                ctx.fill(Path(ellipseIn: CGRect(x: cx - sr * 1.5, y: cy - sr * 1.5,
                                               width: sr * 3, height: sr * 3)),
                         with: .color(.yellow.opacity(0.12)))
                ctx.fill(Path(ellipseIn: CGRect(x: cx - sr, y: cy - sr,
                                               width: sr * 2, height: sr * 2)),
                         with: .color(.yellow.opacity(0.9)))

                for planet in Planet.all {
                    let a = mapping.screenRadius(au: planet.semiMajorAxisAU, maxRadius: maxR)
                    let b = a * CGFloat(sqrt(1 - planet.eccentricity * planet.eccentricity))
                    let c = a * CGFloat(planet.eccentricity)

                    let argPeri = CGFloat(planet.argumentOfPerihelionDeg  * .pi / 180)
                    let ascNode = CGFloat(planet.longitudeOfAscendingNodeDeg * .pi / 180)
                    let incl    = CGFloat(planet.inclinationDeg             * .pi / 180)
                    let cosΩ = cos(ascNode), sinΩ = sin(ascNode)
                    let cosω = cos(argPeri),  sinω = sin(argPeri)
                    let cosi = cos(incl),     sini = sin(incl)

                    // Helper: ecliptic (x, z) for parametric angle θ
                    func eclXZ(_ θ: Double) -> CGPoint {
                        let xPF = a * CGFloat(cos(θ)) - c
                        let yPF = b * CGFloat(sin(θ))
                        let xEcl = xPF * (cosΩ*cosω - sinΩ*sinω*cosi) + yPF * (-cosΩ*sinω - sinΩ*cosω*cosi)
                        let zEcl = xPF * (sinω*sini)                   + yPF * (cosω*sini)
                        return CGPoint(x: cx + xEcl,
                                       y: cy - zEcl * CGFloat(inclinationMultiplier) * zScale)
                    }

                    // Orbit trace
                    let steps = 90
                    var path = Path()
                    for i in 0...steps {
                        let pt = eclXZ(Double(i) / Double(steps) * 2 * .pi)
                        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    }
                    path.closeSubpath()
                    ctx.stroke(path, with: .color(.white.opacity(0.12)),
                               style: StrokeStyle(lineWidth: 0.5))

                    // Current planet position
                    let θ  = angles[planet.name] ?? 0
                    let pt = eclXZ(θ)
                    let r  = planet.displayRadius
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r * 2, y: pt.y - r * 2,
                                                    width: r * 4, height: r * 4)),
                             with: .color(planet.color.opacity(0.2)))
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r,
                                                    width: r * 2, height: r * 2)),
                             with: .color(planet.color))
                }
            }
        }
    }
}

/// Wraps AVRoutePickerView to present the system AirPlay / audio output picker.
#if os(iOS)
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
