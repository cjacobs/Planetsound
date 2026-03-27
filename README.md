# Planetsound

An iOS/macOS app for experimenting with Spatial Audio. A 440 Hz tone orbits your head in 3D space using Apple's HRTF rendering — best experienced with headphones.

## Features

- **Orbiting audio source** — a 440 Hz sine wave circles the listener at a 1.5 m radius, completing one revolution every 8 seconds.
- **HRTF spatial rendering** — `AVAudioEnvironmentNode` with `.HRTF` algorithm places sound in full 3D space around the listener.
- **Orbit visualisation** — a top-down SwiftUI canvas shows the orbit ring, your position ("You") at the centre, and the cyan sound-source sphere moving in real time.
- **Play / pause** — tap the button to start or stop playback.

## Requirements

- Xcode 15+
- iOS 16+ (iPhone or iPad) — or macOS 13+ via Mac Catalyst
- Headphones strongly recommended for the full spatial effect

## Getting Started

1. Open `Planetsound.xcodeproj` in Xcode.
2. Select a target device or simulator.
3. Build and run (`⌘R`).
4. Plug in headphones and tap the play button.

## Project Structure

```
Planetsound/
  PlanetsoundApp.swift        — @main SwiftUI app entry point
  SpatialAudioEngine.swift    — AVAudioEngine graph, sine-wave generation,
                                CADisplayLink orbit animation
  ContentView.swift           — main view + OrbitView Canvas
  Info.plist
  Assets.xcassets/
```

### `SpatialAudioEngine`

An `@MainActor ObservableObject` that owns the audio graph:

```
AVAudioPlayerNode → AVAudioEnvironmentNode → mainMixerNode
```

- Generates a 440 Hz sine-wave buffer with 512-sample fade-in/out to avoid clicks, scheduled as a looping buffer.
- A `CADisplayLink` fires every display frame and updates `player.position`:
  - `x = cos(θ) × 1.5 m`
  - `z = sin(θ) × 1.5 m`  *(z = depth axis; listener at origin)*
- Publishes `angle` (radians) so the UI stays in sync.

### `OrbitView`

A SwiftUI `Canvas` drawing a schematic top-down view:

| Element | Appearance |
|---|---|
| Orbit path | White dashed ring |
| Listener | White filled circle labelled "You" |
| Sound source | Cyan filled circle with glow, labelled "440 Hz" |
| Connecting line | Cyan, 25 % opacity |
