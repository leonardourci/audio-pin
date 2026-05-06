import Foundation
import Observation
import ServiceManagement

@Observable
@MainActor
final class SettingsViewModel {
    private let appState: AppState

    var inputPriorityList: [DeviceEntry] { appState.settings.inputPriorityList }
    var outputPriorityList: [DeviceEntry] { appState.settings.outputPriorityList }
    var profiles: [Profile] { appState.settings.profiles }
    var activeProfileID: UUID { appState.settings.activeProfileID }
    var launchAtLogin: Bool { appState.settings.launchAtLogin }
    var connectedDevices: [AudioDevice] { appState.connectedDevices }

    init(appState: AppState) {
        self.appState = appState
    }

    func moveInputPriorityItem(from: IndexSet, to: Int) async {
        await appState.updateSettings { $0.inputPriorityList.move(fromOffsets: from, toOffset: to) }
    }

    func moveOutputPriorityItem(from: IndexSet, to: Int) async {
        await appState.updateSettings { $0.outputPriorityList.move(fromOffsets: from, toOffset: to) }
    }

    func addToInputPriority(_ device: AudioDevice) async {
        let entry = DeviceEntry(uid: device.uid, lastKnownName: device.name)
        await appState.updateSettings {
            guard !$0.inputPriorityList.contains(where: { $0.uid == entry.uid }) else { return }
            $0.inputPriorityList.append(entry)
        }
    }

    func addToOutputPriority(_ device: AudioDevice) async {
        let entry = DeviceEntry(uid: device.uid, lastKnownName: device.name)
        await appState.updateSettings {
            guard !$0.outputPriorityList.contains(where: { $0.uid == entry.uid }) else { return }
            $0.outputPriorityList.append(entry)
        }
    }

    func removeFromInputPriority(at offsets: IndexSet) async {
        await appState.updateSettings { $0.inputPriorityList.remove(atOffsets: offsets) }
    }

    func removeFromOutputPriority(at offsets: IndexSet) async {
        await appState.updateSettings { $0.outputPriorityList.remove(atOffsets: offsets) }
    }

    func addProfile(name: String) async {
        var p = Profile.makeDefault()
        p.name = name
        let newProfile = p
        await appState.updateSettings { $0.profiles.append(newProfile) }
    }

    func removeProfile(at offsets: IndexSet) async {
        await appState.updateSettings { settings in
            settings.profiles.remove(atOffsets: offsets)
            if !settings.profiles.contains(where: { $0.id == settings.activeProfileID }) {
                settings.activeProfileID = settings.profiles.first?.id ?? UUID()
            }
        }
    }

    func updateProfile(_ profile: Profile) async {
        await appState.updateSettings { settings in
            guard let idx = settings.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
            settings.profiles[idx] = profile
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) async {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try await SMAppService.mainApp.unregister()
            }
            await appState.updateSettings { $0.launchAtLogin = enabled }
        } catch {
            // SMAppService can fail silently — state mismatch surfaced in Settings UI
        }
    }

    func exportSettings() async throws -> Data {
        try await appState.exportSettings()
    }

    func importSettings(_ data: Data) async throws {
        try await appState.importSettings(data)
    }
}
