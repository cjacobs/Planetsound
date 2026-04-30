import SwiftUI

@main
struct PlanetsoundApp: App {
    @State private var engine = SolarSystemEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environment(engine)

        #if os(macOS)
        Settings {
            PreferencesView()
        }
        .environment(engine)
        #endif
    }
}
