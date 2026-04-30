import SwiftUI

struct PreferencesView: View {
    @Environment(SolarSystemEngine.self) private var engine

    var body: some View {
        @Bindable var engine = engine
        Form {
            Section("Audio") {
                Picker("Sound", selection: Binding(
                    get: { engine.generator },
                    set: { engine.setGenerator($0) }
                )) {
                    ForEach(SoundGenerator.allCases) { gen in
                        Text(gen.label).tag(gen)
                    }
                }

                LabeledContent("Speed") {
                    Slider(value: Binding(
                        get: { -engine.mercuryRevolutionDuration },
                        set: { engine.mercuryRevolutionDuration = -$0 }
                    ), in: -60 ... -3) {
                        EmptyView()
                    } minimumValueLabel: {
                        Text("Slow").foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("Fast").foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Reverb") {
                    Slider(value: $engine.reverbLevel, in: -40...0) {
                        EmptyView()
                    } minimumValueLabel: {
                        Text("Dry").foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("Wet").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(width: 400, height: 220)
        #endif
    }
}

#Preview {
    PreferencesView()
        .environment(SolarSystemEngine())
}
