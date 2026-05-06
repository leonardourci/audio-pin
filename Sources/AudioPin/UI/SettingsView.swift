import SwiftUI

struct SettingsView: View {
    let appState: AppState
    @State private var viewModel: SettingsViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: SettingsViewModel(appState: appState))
    }

    var body: some View {
        TabView {
            DevicesTab(viewModel: viewModel)
                .tabItem { Label("Devices", systemImage: "speaker.wave.2") }

            ProfilesTab(viewModel: viewModel)
                .tabItem { Label("Profiles", systemImage: "person.2") }

            GeneralTab(viewModel: viewModel)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 480, height: 360)
    }
}

// MARK: - Devices tab (Phase 3 placeholder)

private struct DevicesTab: View {
    let viewModel: SettingsViewModel

    var body: some View {
        Text("Device priority lists — Phase 3")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Profiles tab (Phase 4 placeholder)

private struct ProfilesTab: View {
    let viewModel: SettingsViewModel

    var body: some View {
        Text("Profiles — Phase 4")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - General tab

private struct GeneralTab: View {
    let viewModel: SettingsViewModel
    @State private var exportError: String?
    @State private var importError: String?

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { viewModel.launchAtLogin },
                set: { enabled in Task { await viewModel.setLaunchAtLogin(enabled) } }
            ))

            Divider()

            HStack {
                Button("Export Settings…") { exportSettings() }
                Button("Import Settings…") { importSettings() }
            }

            if let error = exportError ?? importError {
                Text(error).foregroundStyle(.red).font(.caption)
            }
        }
        .padding()
    }

    private func exportSettings() {
        Task {
            do {
                let data = try await viewModel.exportSettings()
                let panel = NSSavePanel()
                panel.nameFieldStringValue = "audiopin-settings.json"
                panel.allowedContentTypes = [.json]
                guard panel.runModal() == .OK, let url = panel.url else { return }
                try data.write(to: url)
            } catch {
                exportError = error.localizedDescription
            }
        }
    }

    private func importSettings() {
        Task {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.json]
            panel.allowsMultipleSelection = false
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                try await viewModel.importSettings(data)
            } catch {
                importError = error.localizedDescription
            }
        }
    }
}
