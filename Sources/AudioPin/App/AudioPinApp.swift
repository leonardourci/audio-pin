import SwiftUI

@main
struct AudioPinApp: App {
    @State private var appState = AppState()
    @State private var updateChecker = UpdateChecker()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState, updateChecker: updateChecker)
                .task {
                    await appState.start()
                    updateChecker.startPeriodicChecks()
                }
        } label: {
            Image(systemName: updateChecker.updateAvailable
                  ? "headphones.circle.fill"
                  : "headphones")
        }
        .menuBarExtraStyle(.window)

        Window("AudioPin Settings", id: "settings") {
            SettingsView(appState: appState)
        }
        .windowResizability(.contentSize)
    }
}
