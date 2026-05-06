import SwiftUI

struct MenuBarView: View {
    let appState: AppState
    @State private var viewModel: MenuBarViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: MenuBarViewModel(appState: appState))
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Output: \(viewModel.currentOutputName)").font(.callout)
            Text("Input: \(viewModel.currentInputName)").font(.callout)
            Text("Profile: \(viewModel.activeProfileName)").font(.callout)

            Divider()

            Toggle("Enforce pinning", isOn: Binding(
                get: { viewModel.enforcementEnabled },
                set: { _ in Task { await viewModel.toggleEnforcement() } }
            ))

            if viewModel.enforcementBlocked {
                Text("⚠ Fighting another app").foregroundStyle(.orange).font(.caption)
            }

            Divider()

            Menu("Profiles") {
                ForEach(viewModel.profiles) { profile in
                    Button(profile.name) {
                        Task { await viewModel.activateProfile(id: profile.id) }
                    }
                }
            }

            Divider()

            SettingsLink { Text("Settings…") }
            Button("Quit AudioPin") { NSApp.terminate(nil) }
        }
        .padding(8)
    }
}
