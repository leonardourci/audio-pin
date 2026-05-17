import Foundation
import Observation

@Observable
@MainActor
final class MenuBarViewModel {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - State

    var isConfigured: Bool {
        !appState.settings.inputPriorityList.isEmpty || !appState.settings.outputPriorityList.isEmpty
    }

    var enforcementEnabled: Bool { appState.settings.enforcementEnabled }
    var enforcementBlocked: Bool { appState.enforcementBlocked }

    var profiles: [Profile] { appState.settings.profiles }
    var activeProfile: Profile? { appState.activeProfile }
    var activeProfileID: UUID { appState.settings.activeProfileID }

    var connectedDevices: [AudioDevice] { appState.connectedDevices }
    var preferredOutputUID: String? { activeProfile?.preferredOutputUID }
    var preferredInputUID: String? { activeProfile?.preferredInputUID }

    var outputVolumePercent: Int { appState.currentOutputPercent }
    var inputGainPercent: Int { appState.currentInputPercent }
    var gainLockEnabled: Bool { activeProfile?.gainLockEnabled ?? false }

    var hasProfileWithCurrentCombo: Bool {
        let inUID = currentInputUID
        let outUID = currentOutputUID
        return appState.settings.profiles.contains {
            $0.preferredInputUID == inUID && $0.preferredOutputUID == outUID
        }
    }

    func deviceName(for uid: String?) -> String? {
        guard let uid else { return nil }
        if let device = appState.connectedDevices.first(where: { $0.uid == uid }) { return device.name }
        if let entry = appState.settings.inputPriorityList.first(where: { $0.uid == uid }) { return entry.lastKnownName }
        if let entry = appState.settings.outputPriorityList.first(where: { $0.uid == uid }) { return entry.lastKnownName }
        return nil
    }

    // MARK: - Volume / gain

    func setOutputVolumePercent(_ percent: Int) async {
        await appState.setOutputVolumePercent(percent)
    }

    func setInputGainEditing(_ editing: Bool) {
        appState.setAdjustingInputGain(editing)
    }

    func setInputGainPercent(_ percent: Int) async {
        await appState.setInputGainPercent(percent)
        guard gainLockEnabled, let id = activeProfile?.id else { return }
        let target = Float(percent) / 100
        // Fire-and-forget: UserDefaults write is the slowest hop and would make
        // slider-release feel laggy when gain lock is on.
        Task {
            await appState.updateSettings { settings in
                guard let idx = settings.profiles.firstIndex(where: { $0.id == id }) else { return }
                settings.profiles[idx].gainTarget = target
            }
        }
    }

    func setGainLock(_ enabled: Bool) async {
        guard let id = activeProfile?.id else { return }
        let currentGain = Float(appState.currentInputPercent) / 100
        await appState.updateSettings { settings in
            guard let idx = settings.profiles.firstIndex(where: { $0.id == id }) else { return }
            settings.profiles[idx].gainLockEnabled = enabled
            if enabled {
                settings.profiles[idx].gainTarget = currentGain
            }
        }
    }

    // MARK: - Enforcement / profiles

    func toggleEnforcement() async {
        await appState.updateSettings { $0.enforcementEnabled.toggle() }
    }

    func activateProfile(id: UUID) async {
        await appState.activateProfile(id: id)
    }

    func setPreferredOutput(_ uid: String?) async {
        guard let id = activeProfile?.id else { return }
        await appState.updateSettings { settings in
            guard let idx = settings.profiles.firstIndex(where: { $0.id == id }) else { return }
            settings.profiles[idx].preferredOutputUID = uid
        }
    }

    func setPreferredInput(_ uid: String?) async {
        guard let id = activeProfile?.id else { return }
        await appState.updateSettings { settings in
            guard let idx = settings.profiles.firstIndex(where: { $0.id == id }) else { return }
            settings.profiles[idx].preferredInputUID = uid
        }
    }

    func createProfileFromCurrent(name: String, iconSystemName: String? = nil) async {
        guard !hasProfileWithCurrentCombo else { return }
        let inUID = currentInputUID
        let outUID = currentOutputUID
        var profile = Profile.makeDefault()
        profile.name = name
        profile.preferredInputUID = inUID
        profile.preferredOutputUID = outUID
        profile.iconSystemName = iconSystemName
        let newProfile = profile
        await appState.updateSettings { settings in
            settings.profiles.append(newProfile)
            settings.activeProfileID = newProfile.id
        }
    }

    // MARK: - Private

    private var currentOutputUID: String? {
        appState.connectedDevices.first(where: { $0.id == appState.currentOutputID })?.uid
    }

    private var currentInputUID: String? {
        appState.connectedDevices.first(where: { $0.id == appState.currentInputID })?.uid
    }
}
