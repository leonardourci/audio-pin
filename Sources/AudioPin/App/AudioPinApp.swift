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

        Settings {
            SettingsView(appState: appState)
        }
    }
}
