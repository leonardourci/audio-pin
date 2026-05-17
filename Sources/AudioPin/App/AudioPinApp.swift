import SwiftUI

@main
struct AudioPinApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
                .task { await appState.start() }
        } label: {
            Image(systemName: "headphones")
        }
        .menuBarExtraStyle(.window)

        Window("AudioPin Settings", id: "settings") {
            SettingsView(appState: appState)
        }
        .windowResizability(.contentSize)
    }
}
