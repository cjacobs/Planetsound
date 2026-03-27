# Planet\*sound

A solar system sonification app for iOS and macOS. Nine worlds orbit the Sun, each emitting a unique tone spatialized in 3D using Apple's HRTF rendering. Best experienced with headphones.

## Features

- **9 orbiting audio sources** — Mercury through Pluto, each on its own elliptical orbit with real eccentricities and period ratios derived from Kepler's third law.
- **HRTF spatial rendering** — `AVAudioEnvironmentNode` with `.HRTF` places each planet's tone in 3D space around the listener (the Sun).
- **Harmonic frequency mapping** — orbital periods are log-mapped onto a 3-octave range (110 Hz for Pluto up to 880 Hz for Mercury), so planets with near-resonant periods produce near-harmonic intervals.
- **Logarithmic distance scaling** — both the visual canvas and the audio 3D positions use the same `log(1 + AU)` normalization so that inner and outer planets are perceptually well-spaced.
- **Live orbit visualization** — a top-down SwiftUI `Canvas` shows elliptical orbit paths, a glowing Sun at one focus, and each planet moving in real time.
- **Play / pause** — tap the button to start or stop the audio and animation.

## Requirements

- Xcode 15+
- iOS 16+ or macOS 13+
- Headphones strongly recommended for the full spatial effect

## Getting Started

1. Open `Planetsound.xcodeproj` in Xcode.
2. Select a target device or simulator.
3. Build and run (`⌘R`).
4. Plug in headphones and tap the play button.

## Project Structure

```
Planetsound/
  PlanetsoundApp.swift      — @main SwiftUI app entry point
  ContentView.swift         — main UI + SolarSystemView Canvas
  SpatialAudioEngine.swift  — AVAudioEngine graph, tone generation, orbit animation
  Planet.swift              — data model with real orbital parameters for 9 worlds
  ScaleMapping.swift        — centralized AU/period → screen/audio/frequency mappings
  Info.plist
  Assets.xcassets/
```

### `Planet`

A value type holding each world's orbital data (semi-major axis, eccentricity, period) and display properties (color, radius). The static `Planet.all` array defines all 9 bodies from Mercury to Pluto.

### `ScaleMapping`

A struct that centralizes the logarithmic scale mappings shared by the visual and audio layers:

- `normalizedAU(_:)` — shared `log(1 + AU) / log(1 + maxAU)` normalization to 0...1.
- `screenRadius(au:maxRadius:)` — AU to screen points for the canvas.
- `audioDistance(au:)` — AU to 3D audio distance in meters (0.4 m to 4.0 m).
- `audioFrequency(orbitalPeriodYears:)` — orbital period to Hz (110 to 880).

All bounds are derived from `Planet.all`, so adding or removing a body automatically adjusts the mapping.

### `SolarSystemEngine`

An `@MainActor @Observable` class that owns the audio graph:

```
AVAudioPlayerNode (×9) → AVAudioEnvironmentNode (.HRTF) → mainMixerNode
```

- Generates seamlessly looping sine-wave buffers (whole-cycle aligned, no fade envelope).
- A 60 Hz `Timer` updates each planet's 3D position on its elliptical orbit.
- Publishes per-planet angles so the UI stays in sync.

### `SolarSystemView`

A SwiftUI `Canvas` drawing a top-down view of the solar system:

| Element | Appearance |
|---|---|
| Orbit paths | Thin white ellipses (10% opacity) |
| Sun (listener) | Yellow circle with glow at one focus |
| Planets | Colored circles with glow, sized by `displayRadius` |
| Labels | Small planet names beneath each body |
