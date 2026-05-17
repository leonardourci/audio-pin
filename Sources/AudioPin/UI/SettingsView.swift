import SwiftUI
import AppKit

struct SettingsView: View {
    let appState: AppState
    @State private var viewModel: SettingsViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: SettingsViewModel(appState: appState))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UI.spacingL) {
                CurrentDevicesSection(viewModel: viewModel)
                Divider()
                DevicesSection(viewModel: viewModel)
                Divider()
                ProfilesSection(viewModel: viewModel)
                Divider()
                GeneralSection(viewModel: viewModel)
            }
            .padding(UI.windowPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 480, idealWidth: 560, maxWidth: 800, minHeight: 400, idealHeight: 580, maxHeight: 900)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

// MARK: - Shared section chrome

private struct SectionHeader: View {
    let title: String
    let subtitle: String?
    let trailing: AnyView?

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> some View = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.weight(.semibold))
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing
        }
    }
}

private struct SubsectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(0.5)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Current Devices (top quick-pickers)

private struct CurrentDevicesSection: View {
    let viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: UI.spacingS) {
            SectionHeader(
                "Current Devices",
                subtitle: "Preferred input and output for the active profile."
            )

            VStack(alignment: .leading, spacing: UI.spacingS) {
                pickerRow(
                    title: "Output",
                    selection: Binding(
                        get: { viewModel.preferredOutputUID },
                        set: { uid in Task { await viewModel.setPreferredOutput(uid) } }
                    ),
                    devices: viewModel.connectedDevices.filter { $0.hasOutput }
                )

                pickerRow(
                    title: "Input",
                    selection: Binding(
                        get: { viewModel.preferredInputUID },
                        set: { uid in Task { await viewModel.setPreferredInput(uid) } }
                    ),
                    devices: viewModel.connectedDevices.filter { $0.hasInput }
                )

                if viewModel.activeProfile == nil {
                    Text("No active profile. Add one below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(UI.spacingS)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func pickerRow(
        title: String,
        selection: Binding<String?>,
        devices: [AudioDevice]
    ) -> some View {
        VStack(alignment: .leading, spacing: UI.spacingXS) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            DeviceMenu(
                selectedUID: selection.wrappedValue,
                devices: devices,
                onSelect: { uid in selection.wrappedValue = uid }
            )
            .disabled(viewModel.activeProfile == nil || devices.isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DeviceMenu: View {
    let selectedUID: String?
    let devices: [AudioDevice]
    let onSelect: (String) -> Void

    var body: some View {
        let effectiveUID = selectedUID ?? devices.first?.uid
        let selectedName = devices.first(where: { $0.uid == effectiveUID })?.name ?? "No device available"
        Menu {
            ForEach(devices, id: \.uid) { device in
                Button {
                    onSelect(device.uid)
                } label: {
                    if device.uid == effectiveUID {
                        Label(device.name, systemImage: "checkmark")
                    } else {
                        Text(device.name)
                    }
                }
            }
        } label: {
            HStack(spacing: UI.spacingXS) {
                Text(selectedName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
    }
}

// MARK: - Devices

private struct DevicesSection: View {
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
        VStack(alignment: .leading, spacing: UI.spacingS) {
            SectionHeader("Devices", subtitle: "Highest connected device wins. Use arrows to reorder.")

            priorityBlock(
                title: "Input Priority",
                entries: viewModel.inputPriorityList,
                available: availableInputDevices,
                onMove: { index, direction in await viewModel.moveInputPriorityItem(at: index, direction: direction) },
                onRemoveIndex: { index in await viewModel.removeFromInputPriority(at: IndexSet(integer: index)) },
                onAdd: { device in await viewModel.addToInputPriority(device) },
                onDropBefore: { uid, targetUID in await viewModel.moveInputPriority(uid: uid, beforeUID: targetUID) },
                onDropAtIndex: { uid, index in await viewModel.moveInputPriority(uid: uid, toIndex: index) }
            )

            priorityBlock(
                title: "Output Priority",
                entries: viewModel.outputPriorityList,
                available: availableOutputDevices,
                onMove: { index, direction in await viewModel.moveOutputPriorityItem(at: index, direction: direction) },
                onRemoveIndex: { index in await viewModel.removeFromOutputPriority(at: IndexSet(integer: index)) },
                onAdd: { device in await viewModel.addToOutputPriority(device) },
                onDropBefore: { uid, targetUID in await viewModel.moveOutputPriority(uid: uid, beforeUID: targetUID) },
                onDropAtIndex: { uid, index in await viewModel.moveOutputPriority(uid: uid, toIndex: index) }
            )
        }
    }

    @ViewBuilder
    private func priorityBlock(
        title: String,
        entries: [DeviceEntry],
        available: [AudioDevice],
        onMove: @escaping @Sendable (Int, MoveDirection) async -> Void,
        onRemoveIndex: @escaping @Sendable (Int) async -> Void,
        onAdd: @escaping @Sendable (AudioDevice) async -> Void,
        onDropBefore: @escaping @Sendable (String, String) async -> Void,
        onDropAtIndex: @escaping @Sendable (String, Int) async -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: UI.spacingXS) {
            HStack {
                SubsectionHeader(title: title)
                Spacer()
                if !available.isEmpty {
                    Menu {
                        ForEach(available, id: \.uid) { device in
                            Button(device.name) {
                                Task { await onAdd(device) }
                            }
                        }
                    } label: {
                        Label("Add Device", systemImage: "plus")
                    }
                    .menuStyle(.borderlessButton)
                    .controlSize(.small)
                    .fixedSize()
                }
            }

            PriorityList(
                entries: entries,
                onMove: onMove,
                onRemoveIndex: onRemoveIndex,
                onDropBefore: onDropBefore,
                onDropAtIndex: onDropAtIndex
            )
        }
    }
}

private struct PriorityList: View {
    let entries: [DeviceEntry]
    let onMove: @Sendable (Int, MoveDirection) async -> Void
    let onRemoveIndex: @Sendable (Int) async -> Void
    let onDropBefore: @Sendable (String, String) async -> Void
    let onDropAtIndex: @Sendable (String, Int) async -> Void

    var body: some View {
        if entries.isEmpty {
            Text("No devices added yet — drop a device here")
                .foregroundStyle(.secondary)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, UI.spacingS)
                .padding(.horizontal, UI.spacingS)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .dropDestination(for: String.self) { items, _ in
                    guard let droppedUID = items.first else { return false }
                    Task { await onDropAtIndex(droppedUID, 0) }
                    return true
                }
        } else {
            VStack(spacing: 0) {
                edgeDropZone(onDrop: { uid in Task { await onDropAtIndex(uid, 0) } })

                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    PriorityRow(
                        uid: entry.uid,
                        name: entry.lastKnownName,
                        isFirst: index == 0,
                        isLast: index == entries.count - 1,
                        onUp: { Task { await onMove(index, .up) } },
                        onDown: { Task { await onMove(index, .down) } },
                        onRemove: { Task { await onRemoveIndex(index) } },
                        onDropUID: { draggedUID in Task { await onDropBefore(draggedUID, entry.uid) } }
                    )

                    if index < entries.count - 1 {
                        Divider().padding(.leading, UI.spacingS)
                    }
                }

                edgeDropZone(onDrop: { uid in Task { await onDropAtIndex(uid, entries.count) } })
            }
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func edgeDropZone(onDrop: @escaping (String) -> Void) -> some View {
        EdgeDropZone(onDrop: onDrop)
    }
}

private struct EdgeDropZone: View {
    let onDrop: (String) -> Void
    @State private var targeted = false

    var body: some View {
        Rectangle()
            .fill(targeted ? Color.accentColor.opacity(0.2) : Color.clear)
            .frame(height: 8)
            .dropDestination(for: String.self) { items, _ in
                guard let droppedUID = items.first else { return false }
                onDrop(droppedUID)
                return true
            } isTargeted: { targeted = $0 }
    }
}

private struct PriorityRow: View {
    let uid: String
    let name: String
    let isFirst: Bool
    let isLast: Bool
    let onUp: () -> Void
    let onDown: () -> Void
    let onRemove: () -> Void
    let onDropUID: (String) -> Void

    @State private var isHovered = false
    @State private var isDropTarget = false

    var body: some View {
        HStack(spacing: UI.spacingS) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .frame(width: UI.iconWidth, alignment: .center)

            Text(name)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            HStack(spacing: 2) {
                Button(action: onUp) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(isFirst)
                .help("Move up")

                Button(action: onDown) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(isLast)
                .help("Move down")

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Remove from priority list")
            }
        }
        .padding(.horizontal, UI.spacingS)
        .frame(minHeight: UI.rowHeight)
        .contentShape(Rectangle())
        .background(rowBackground)
        .onHover { isHovered = $0 }
        .draggable(uid) {
            Text(name)
                .padding(6)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .dropDestination(for: String.self) { items, _ in
            guard let droppedUID = items.first, droppedUID != uid else { return false }
            onDropUID(droppedUID)
            return true
        } isTargeted: { targeted in
            isDropTarget = targeted
        }
    }

    private var rowBackground: Color {
        if isDropTarget { return Color.accentColor.opacity(0.2) }
        if isHovered { return Color.secondary.opacity(0.06) }
        return .clear
    }
}

// MARK: - Profiles

private struct ProfilesSection: View {
    let viewModel: SettingsViewModel
    @State private var showAddProfile = false
    @State private var newProfileName = ""
    @State private var editingProfile: Profile?

    var body: some View {
        VStack(alignment: .leading, spacing: UI.spacingS) {
            SectionHeader("Profiles", subtitle: "Click a profile to activate. Pencil to edit.") {
                Button {
                    newProfileName = ""
                    showAddProfile = true
                } label: {
                    Label("Add Profile", systemImage: "plus")
                }
                .controlSize(.small)
            }

            ProfileListContent(viewModel: viewModel, editingProfile: $editingProfile)

            if showAddProfile {
                addProfileForm
            }
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditView(viewModel: viewModel, profile: profile)
        }
    }

    private var addProfileForm: some View {
        VStack(alignment: .leading, spacing: UI.spacingXS) {
            TextField("Profile name", text: $newProfileName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { commit() }

            HStack(spacing: UI.spacingXS) {
                Button("Cancel") {
                    showAddProfile = false
                    newProfileName = ""
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Add") { commit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(UI.spacingS)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private func commit() {
        let name = newProfileName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        Task {
            await viewModel.addProfile(name: name)
            await MainActor.run {
                showAddProfile = false
                newProfileName = ""
            }
        }
    }
}

private struct ProfileListContent: View {
    let viewModel: SettingsViewModel
    @Binding var editingProfile: Profile?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.profiles.enumerated()), id: \.element.id) { index, profile in
                ProfileRow(
                    profile: profile,
                    isActive: profile.id == viewModel.activeProfileID,
                    canDelete: viewModel.profiles.count > 1,
                    outputName: viewModel.deviceName(for: profile.preferredOutputUID),
                    inputName: viewModel.deviceName(for: profile.preferredInputUID)
                ) {
                    Task { await viewModel.activateProfile(id: profile.id) }
                } onEdit: {
                    editingProfile = profile
                } onDelete: {
                    if let idx = viewModel.profiles.firstIndex(where: { $0.id == profile.id }) {
                        Task { await viewModel.removeProfile(at: IndexSet(integer: idx)) }
                    }
                }

                if index < viewModel.profiles.count - 1 {
                    Divider().padding(.leading, UI.spacingS)
                }
            }
        }
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ProfileRow: View {
    let profile: Profile
    let isActive: Bool
    let canDelete: Bool
    let outputName: String?
    let inputName: String?
    let onActivate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var hasDeviceHints: Bool { outputName != nil || inputName != nil }

    var body: some View {
        HStack(spacing: UI.spacingS) {
            Image(systemName: profile.displayIconSystemName)
                .frame(width: UI.iconWidth, height: 44, alignment: .center)
                .foregroundStyle(isActive ? Color.accentColor : .primary)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { onEdit() }
                .help("Double-click to edit profile")

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .foregroundStyle(.primary)
                if hasDeviceHints {
                    HStack(spacing: UI.spacingS) {
                        if let outputName {
                            deviceHint(icon: "speaker.wave.2", name: outputName)
                        }
                        if let inputName {
                            deviceHint(icon: "mic", name: inputName)
                        }
                    }
                }
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 12, weight: .semibold))
            }

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("Edit profile")

            if canDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .opacity(isHovered ? 1 : 0)
            }
        }
        .padding(.horizontal, UI.spacingS)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? UI.activeBackground : Color.clear)
        )
        .onHover { isHovered = $0 }
        .onTapGesture { onActivate() }
    }

    private func deviceHint(icon: String, name: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(name).lineLimit(1).truncationMode(.middle)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Profile edit form

private struct ProfileEditView: View {
    let viewModel: SettingsViewModel
    @State private var profile: Profile
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SettingsViewModel, profile: Profile) {
        self.viewModel = viewModel
        _profile = State(initialValue: profile)
    }

    private var isNameValid: Bool {
        !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $profile.name)
                }

                Section("Icon") {
                    iconPicker
                }

                Section("Audio") {
                    Picker("Preferred Input", selection: $profile.preferredInputUID) {
                        Text("Auto (use priority list)").tag(Optional<String>.none)
                        ForEach(viewModel.inputPriorityList) { entry in
                            Text(entry.lastKnownName).tag(Optional(entry.uid))
                        }
                    }

                    Picker("Preferred Output", selection: $profile.preferredOutputUID) {
                        Text("Auto (use priority list)").tag(Optional<String>.none)
                        ForEach(viewModel.outputPriorityList) { entry in
                            Text(entry.lastKnownName).tag(Optional(entry.uid))
                        }
                    }
                }

                Section("Gain") {
                    VStack(alignment: .leading, spacing: UI.spacingXS) {
                        Text("Mic Gain: \(Int(profile.gainTarget * 100))%")
                        Slider(value: $profile.gainTarget, in: 0...1)
                    }

                    Toggle("Lock gain (prevent apps from changing it)", isOn: $profile.gainLockEnabled)
                }

                Section("Trigger") {
                    Picker("Auto-trigger on device", selection: $profile.autoTriggerDeviceUID) {
                        Text("Manual only").tag(Optional<String>.none)
                        ForEach(viewModel.connectedDevices, id: \.uid) { device in
                            Text(device.name).tag(Optional(device.uid))
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    let snapshot = profile
                    Task {
                        await viewModel.updateProfile(snapshot)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isNameValid)
            }
            .padding(UI.spacingS)
        }
        .navigationTitle(profile.name)
    }

    private var iconPicker: some View {
        HStack(spacing: UI.spacingXS) {
            ForEach(Profile.iconChoices, id: \.self) { name in
                Button {
                    profile.iconSystemName = name
                } label: {
                    Image(systemName: name)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(profile.iconSystemName == name ? UI.activeBackground : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(profile.iconSystemName == name ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - General

private struct GeneralSection: View {
    let viewModel: SettingsViewModel
    @State private var exportError: String?
    @State private var importError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: UI.spacingS) {
            SectionHeader("General")

            VStack(alignment: .leading, spacing: UI.spacingS) {
                Toggle("Launch at login", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { enabled in Task { await viewModel.setLaunchAtLogin(enabled) } }
                ))

                HStack(spacing: UI.spacingXS) {
                    Button("Export Settings…") { exportSettings() }
                    Button("Import Settings…") { importSettings() }
                }

                if let error = exportError ?? importError {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }
            .padding(UI.spacingS)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
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
