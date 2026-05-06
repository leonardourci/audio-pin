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

// MARK: - Devices tab (Phase 3)

private struct DevicesTab: View {
    let viewModel: SettingsViewModel

    var availableInputDevices: [AudioDevice] {
        let existingUIDs = Set(viewModel.inputPriorityList.map(\.uid))
        return viewModel.connectedDevices.filter { $0.hasInput && !existingUIDs.contains($0.uid) }
    }

    var availableOutputDevices: [AudioDevice] {
        let existingUIDs = Set(viewModel.outputPriorityList.map(\.uid))
        return viewModel.connectedDevices.filter { $0.hasOutput && !existingUIDs.contains($0.uid) }
    }

    var body: some View {
        Form {
            Section("Input Priority") {
                ForEach(viewModel.inputPriorityList) { entry in
                    Text(entry.lastKnownName)
                }
                .onMove { from, to in
                    Task { await viewModel.moveInputPriorityItem(from: from, to: to) }
                }
                .onDelete { offsets in
                    Task { await viewModel.removeFromInputPriority(at: offsets) }
                }

                if !availableInputDevices.isEmpty {
                    Menu("Add Input Device…") {
                        ForEach(availableInputDevices, id: \.uid) { device in
                            Button(device.name) {
                                Task { await viewModel.addToInputPriority(device) }
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            Section("Output Priority") {
                ForEach(viewModel.outputPriorityList) { entry in
                    Text(entry.lastKnownName)
                }
                .onMove { from, to in
                    Task { await viewModel.moveOutputPriorityItem(from: from, to: to) }
                }
                .onDelete { offsets in
                    Task { await viewModel.removeFromOutputPriority(at: offsets) }
                }

                if !availableOutputDevices.isEmpty {
                    Menu("Add Output Device…") {
                        ForEach(availableOutputDevices, id: \.uid) { device in
                            Button(device.name) {
                                Task { await viewModel.addToOutputPriority(device) }
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Profiles tab (Phase 4)

private struct ProfilesTab: View {
    let viewModel: SettingsViewModel
    @State private var showAddProfile = false
    @State private var newProfileName = ""
    @State private var editingProfile: Profile?

    var body: some View {
        ProfileListContent(viewModel: viewModel, editingProfile: $editingProfile)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newProfileName = ""
                        showAddProfile = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editingProfile) { profile in
                ProfileEditView(viewModel: viewModel, profile: profile)
            }
            .alert("New Profile", isPresented: $showAddProfile) {
                TextField("Name", text: $newProfileName)
                Button("Add") {
                    let name = newProfileName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    Task { await viewModel.addProfile(name: name) }
                }
                Button("Cancel", role: .cancel) {}
            }
    }
}

private struct ProfileListContent: View {
    let viewModel: SettingsViewModel
    @Binding var editingProfile: Profile?

    var body: some View {
        List {
            ForEach(viewModel.profiles) { profile in
                ProfileRow(
                    profile: profile,
                    isActive: profile.id == viewModel.activeProfileID,
                    canDelete: viewModel.profiles.count > 1
                ) {
                    editingProfile = profile
                } onDelete: {
                    if let idx = viewModel.profiles.firstIndex(where: { $0.id == profile.id }) {
                        Task { await viewModel.removeProfile(at: IndexSet(integer: idx)) }
                    }
                }
            }
        }
    }
}

private struct ProfileRow: View {
    let profile: Profile
    let isActive: Bool
    let canDelete: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(profile.name)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if canDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Profile edit form

private struct ProfileEditView: View {
    let viewModel: SettingsViewModel
    @State private var profile: Profile

    init(viewModel: SettingsViewModel, profile: Profile) {
        self.viewModel = viewModel
        _profile = State(initialValue: profile)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $profile.name)
                    .onChange(of: profile.name) { _, _ in save() }
            }

            Section("Audio") {
                Picker("Preferred Input", selection: $profile.preferredInputUID) {
                    Text("Auto (use priority list)").tag(Optional<String>.none)
                    ForEach(viewModel.inputPriorityList) { entry in
                        Text(entry.lastKnownName).tag(Optional(entry.uid))
                    }
                }
                .onChange(of: profile.preferredInputUID) { _, _ in save() }

                Picker("Preferred Output", selection: $profile.preferredOutputUID) {
                    Text("Auto (use priority list)").tag(Optional<String>.none)
                    ForEach(viewModel.outputPriorityList) { entry in
                        Text(entry.lastKnownName).tag(Optional(entry.uid))
                    }
                }
                .onChange(of: profile.preferredOutputUID) { _, _ in save() }
            }

            Section("Gain") {
                VStack(alignment: .leading) {
                    Text("Mic Gain: \(Int(profile.gainTarget * 100))%")
                    Slider(value: $profile.gainTarget, in: 0...1)
                        .onChange(of: profile.gainTarget) { _, _ in save() }
                }

                Toggle("Lock gain (prevent apps from changing it)", isOn: $profile.gainLockEnabled)
                    .onChange(of: profile.gainLockEnabled) { _, _ in save() }
            }

            Section("Trigger") {
                Picker("Auto-trigger on device", selection: $profile.autoTriggerDeviceUID) {
                    Text("Manual only").tag(Optional<String>.none)
                    ForEach(viewModel.connectedDevices, id: \.uid) { device in
                        Text(device.name).tag(Optional(device.uid))
                    }
                }
                .onChange(of: profile.autoTriggerDeviceUID) { _, _ in save() }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(profile.name)
    }

    private func save() {
        let snapshot = profile
        Task { await viewModel.updateProfile(snapshot) }
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
