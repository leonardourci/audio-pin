import SwiftUI

struct MenuBarView: View {
    let appState: AppState
    @State private var viewModel: MenuBarViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: MenuBarViewModel(appState: appState))
    }

    var body: some View {
        Text("AudioPin")
            .disabled(true)

        Divider()

        if viewModel.isConfigured {
            Text("Output: \(viewModel.currentOutputName)")
                .disabled(true)
            Text("Input: \(viewModel.currentInputName)")
                .disabled(true)
            Text("Profile: \(viewModel.activeProfileName)")
                .disabled(true)
        } else {
            SettingsLink {
                Text("Set up AudioPin…")
            }
        }

        Divider()

        Toggle("Enforce pinning", isOn: Binding(
            get: { viewModel.enforcementEnabled },
            set: { _ in Task { await viewModel.toggleEnforcement() } }
        ))

        if viewModel.enforcementBlocked {
            Text("⚠ Fighting another app")
                .foregroundStyle(.orange)
                .disabled(true)
        }

        Menu("Profiles") {
            ForEach(viewModel.profiles) { profile in
                Button {
                    Task { await viewModel.activateProfile(id: profile.id) }
                } label: {
                    if profile.id == viewModel.activeProfileID {
                        Label(profile.name, systemImage: "checkmark")
                    } else {
                        Text(profile.name)
                    }
                }
            }
        }

        Divider()

        SettingsLink {
            Text("Settings…")
        }

        Button("Quit AudioPin") {
            NSApp.terminate(nil)
        }
    }
}
