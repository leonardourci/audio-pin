import SwiftUI
import AppKit

struct MenuBarView: View {
    let appState: AppState
    @State private var viewModel: MenuBarViewModel
    @State private var isAddingProfile = false
    @State private var newProfileName = ""
    @State private var newProfileIcon: String = Profile.iconChoices.first ?? "person.2.fill"
    @State private var showGainLockHelp = false
    @State private var showEnforcementHelp = false
    @Environment(\.openWindow) private var openWindow

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: MenuBarViewModel(appState: appState))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: UI.spacingS) {
            header

            if viewModel.isConfigured {
                Divider()
                outputSection

                Divider()
                inputSection

                Divider()
                profilesSection

                Divider()
                enforcementSection
            } else {
                Divider()
                emptyState
            }

            Divider()
            footer
        }
        .padding(UI.spacingS)
        .frame(width: UI.popoverWidth)
    }

    private var header: some View {
        HStack(spacing: UI.spacingXS) {
            Image(systemName: "headphones")
            Text("AudioPin").font(.headline)
            Spacer()
        }
    }

    // MARK: - Output / Input

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: UI.spacingXS) {
            sectionLabel("Output")
            let outputs = viewModel.connectedDevices.filter { $0.hasOutput }
            deviceMenu(
                icon: "speaker.wave.2",
                selectedUID: viewModel.preferredOutputUID,
                devices: outputs,
                onSelect: { uid in Task { await viewModel.setPreferredOutput(uid) } }
            )
            percentSlider(value: viewModel.outputVolumePercent) { p in
                Task { await viewModel.setOutputVolumePercent(p) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: UI.spacingXS) {
            sectionLabel("Input")
            let inputs = viewModel.connectedDevices.filter { $0.hasInput }
            deviceMenu(
                icon: "mic",
                selectedUID: viewModel.preferredInputUID,
                devices: inputs,
                onSelect: { uid in Task { await viewModel.setPreferredInput(uid) } }
            )
            percentSlider(
                value: viewModel.inputGainPercent,
                onCommit: { p in Task { await viewModel.setInputGainPercent(p) } },
                onEditingChanged: { editing in viewModel.setInputGainEditing(editing) }
            )
            HStack(spacing: UI.spacingXS) {
                Toggle("Lock mic gain", isOn: Binding(
                    get: { viewModel.gainLockEnabled },
                    set: { enabled in Task { await viewModel.setGainLock(enabled) } }
                ))
                .controlSize(.regular)
                helpButton(
                    isPresented: $showGainLockHelp,
                    tooltip: "Holds your microphone input level at a fixed value. Apps like Zoom or Chrome can't adjust it via AGC."
                )
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deviceMenu(
        icon: String,
        selectedUID: String?,
        devices: [AudioDevice],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        let effectiveUID = selectedUID ?? devices.first?.uid
        let selectedName = devices.first(where: { $0.uid == effectiveUID })?.name ?? "No device available"
        return Menu {
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
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
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
        .disabled(devices.isEmpty)
    }

    private func percentSlider(
        value: Int,
        onCommit: @escaping (Int) -> Void,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) -> some View {
        DebouncedPercentSlider(
            externalValue: value,
            onCommit: onCommit,
            onEditingChanged: onEditingChanged
        )
    }

    // MARK: - Profiles

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: UI.spacingXS) {
            HStack {
                sectionLabel("Profiles")
                Spacer()
                Button {
                    newProfileName = ""
                    newProfileIcon = Profile.defaultIcon(forIndex: viewModel.profiles.count)
                    isAddingProfile = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .disabled(isAddingProfile)
                .help("Save current devices as a new profile")
            }

            if isAddingProfile {
                addProfileForm
            }

            VStack(spacing: 2) {
                ForEach(viewModel.profiles) { profile in
                    profileRow(profile)
                }
            }
        }
    }

    private func profileRow(_ profile: Profile) -> some View {
        let isActive = profile.id == viewModel.activeProfileID
        let outputName = viewModel.deviceName(for: profile.preferredOutputUID)
        let inputName = viewModel.deviceName(for: profile.preferredInputUID)
        let hasDeviceHints = outputName != nil || inputName != nil
        return HStack(spacing: UI.spacingS) {
            Image(systemName: profile.displayIconSystemName)
                .frame(width: UI.iconWidth, height: UI.rowMinHeight, alignment: .center)
                .foregroundStyle(isActive ? Color.accentColor : .primary)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { openSettings() }
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
        }
        .padding(.horizontal, UI.spacingS)
        .padding(.vertical, UI.spacingXS)
        .frame(maxWidth: .infinity, minHeight: UI.rowMinHeight, alignment: .leading)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? UI.activeBackground : Color.clear)
        )
        .onTapGesture {
            Task { await viewModel.activateProfile(id: profile.id) }
        }
    }

    private func deviceHint(icon: String, name: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(name).lineLimit(1).truncationMode(.middle)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    var addProfileForm: some View {
        VStack(alignment: .leading, spacing: UI.spacingXS) {
            TextField("Profile name", text: $newProfileName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { commitNewProfile() }

            iconChoiceRow

            if viewModel.hasProfileWithCurrentCombo {
                Label("A profile already exists for the current devices.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack(spacing: UI.spacingXS) {
                Button("Cancel") {
                    isAddingProfile = false
                    newProfileName = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .frame(maxWidth: .infinity)

                Button("Create") { commitNewProfile() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity)
                    .disabled(
                        newProfileName.trimmingCharacters(in: .whitespaces).isEmpty
                            || viewModel.hasProfileWithCurrentCombo
                    )
            }
        }
    }

    private var iconChoiceRow: some View {
        HStack(spacing: UI.spacingXS) {
            ForEach(Profile.iconChoices, id: \.self) { name in
                Button {
                    newProfileIcon = name
                } label: {
                    Image(systemName: name)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(newProfileIcon == name ? UI.activeBackground : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(newProfileIcon == name ? Color.accentColor : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func commitNewProfile() {
        let name = newProfileName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let icon = newProfileIcon
        Task {
            await viewModel.createProfileFromCurrent(name: name, iconSystemName: icon)
            await MainActor.run {
                isAddingProfile = false
                newProfileName = ""
            }
        }
    }

    // MARK: - Enforcement

    private var enforcementSection: some View {
        VStack(alignment: .leading, spacing: UI.spacingXS) {
            HStack(spacing: UI.spacingXS) {
                Toggle("Enforce pinning", isOn: Binding(
                    get: { viewModel.enforcementEnabled },
                    set: { _ in Task { await viewModel.toggleEnforcement() } }
                ))
                .controlSize(.regular)
                helpButton(
                    isPresented: $showEnforcementHelp,
                    tooltip: "When on, AudioPin keeps your preferred input/output devices selected — even when macOS or another app tries to switch."
                )
                Spacer()
            }

            if viewModel.enforcementBlocked {
                Label("Fighting another app", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func helpButton(isPresented: Binding<Bool>, tooltip: String) -> some View {
        Button {
            isPresented.wrappedValue.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .popover(isPresented: isPresented, arrowEdge: .bottom) {
            Text(tooltip)
                .font(.callout)
                .frame(maxWidth: 260, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(UI.spacingS)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: UI.spacingS) {
            Text("No devices configured yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                openSettings()
            } label: {
                Label("Set up AudioPin…", systemImage: "gearshape")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var footer: some View {
        HStack {
            Button("Settings…") { openSettings() }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .controlSize(.small)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "settings")
    }
}

// Custom slider so clicking on the track jumps to that point (SwiftUI Slider
// only drags from the knob). Buffered locally to avoid CoreAudio writes
// mid-drag; commit fires once on release. Operates on Int percent (0...100)
// so no Float math can introduce drift between display and committed value.
private struct DebouncedPercentSlider: View {
    let externalValue: Int
    let onCommit: (Int) -> Void
    let onEditingChanged: ((Bool) -> Void)?

    init(
        externalValue: Int,
        onCommit: @escaping (Int) -> Void,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.externalValue = externalValue
        self.onCommit = onCommit
        self.onEditingChanged = onEditingChanged
    }

    @State private var percent: Int = 0
    @State private var editing = false

    private static let knob: CGFloat = 14
    private static let trackHeight: CGFloat = 4

    var body: some View {
        HStack(spacing: UI.spacingS) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: Self.trackHeight)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: filledWidth(in: geo.size.width), height: Self.trackHeight)
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
                        .frame(width: Self.knob, height: Self.knob)
                        .offset(x: knobOffset(in: geo.size.width))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            if !editing {
                                editing = true
                                onEditingChanged?(true)
                            }
                            percent = percentValue(at: drag.location.x, width: geo.size.width)
                        }
                        .onEnded { _ in
                            editing = false
                            onEditingChanged?(false)
                            onCommit(percent)
                        }
                )
            }
            .frame(height: 20)
            .frame(maxWidth: .infinity)

            Text("\(percent)%")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: UI.percentLabelWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { percent = clampPercent(externalValue) }
        .onChange(of: externalValue) { _, newValue in
            if !editing { percent = clampPercent(newValue) }
        }
    }

    private func clampPercent(_ p: Int) -> Int {
        max(0, min(100, p))
    }

    private func percentValue(at x: CGFloat, width: CGFloat) -> Int {
        guard width > 0 else { return 0 }
        let clamped = max(0, min(width, x))
        let raw = (clamped / width) * 100
        return clampPercent(Int(raw.rounded()))
    }

    private func filledWidth(in width: CGFloat) -> CGFloat {
        max(0, (CGFloat(percent) / 100) * width)
    }

    private func knobOffset(in width: CGFloat) -> CGFloat {
        let position = (CGFloat(percent) / 100) * width
        return max(0, min(width - Self.knob, position - Self.knob / 2))
    }
}
