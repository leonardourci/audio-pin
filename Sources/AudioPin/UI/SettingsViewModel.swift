import Foundation
import Observation
import ServiceManagement

enum MoveDirection {
    case up
    case down
}

@Observable
@MainActor
final class SettingsViewModel {
    private static let log = AppLog.logger("SettingsViewModel")
    private let appState: AppState

    var inputPriorityList: [DeviceEntry] { appState.settings.inputPriorityList }
    var outputPriorityList: [DeviceEntry] { appState.settings.outputPriorityList }
    var profiles: [Profile] { appState.settings.profiles }
    var activeProfileID: UUID { appState.settings.activeProfileID }
    var launchAtLogin: Bool { appState.settings.launchAtLogin }
    var connectedDevices: [AudioDevice] { appState.connectedDevices }
    var activeProfile: Profile? { appState.activeProfile }

    var preferredInputUID: String? { activeProfile?.preferredInputUID }
    var preferredOutputUID: String? { activeProfile?.preferredOutputUID }

    func deviceName(for uid: String?) -> String? {
        guard let uid else { return nil }
        if let device = appState.connectedDevices.first(where: { $0.uid == uid }) { return device.name }
        if let entry = appState.settings.inputPriorityList.first(where: { $0.uid == uid }) { return entry.lastKnownName }
        if let entry = appState.settings.outputPriorityList.first(where: { $0.uid == uid }) { return entry.lastKnownName }
        return nil
    }

    init(appState: AppState) {
        self.appState = appState
    }

    func activateProfile(id: UUID) async {
        await appState.activateProfile(id: id)
    }

    func setPreferredInput(_ uid: String?) async {
        guard let id = activeProfile?.id else { return }
        await appState.updateSettings { settings in
            guard let idx = settings.profiles.firstIndex(where: { $0.id == id }) else { return }
            settings.profiles[idx].preferredInputUID = uid
        }
    }

    func setPreferredOutput(_ uid: String?) async {
        guard let id = activeProfile?.id else { return }
        await appState.updateSettings { settings in
            guard let idx = settings.profiles.firstIndex(where: { $0.id == id }) else { return }
            settings.profiles[idx].preferredOutputUID = uid
        }
    }

    func moveInputPriorityItem(at index: Int, direction: MoveDirection) async {
        await appState.updateSettings { settings in
            Self.move(&settings.inputPriorityList, at: index, direction: direction)
        }
    }

    func moveOutputPriorityItem(at index: Int, direction: MoveDirection) async {
        await appState.updateSettings { settings in
            Self.move(&settings.outputPriorityList, at: index, direction: direction)
        }
    }

    func moveInputPriority(uid: String, beforeUID targetUID: String) async {
        await appState.updateSettings { settings in
            Self.moveByUID(&settings.inputPriorityList, uid: uid, beforeUID: targetUID)
        }
    }

    func moveOutputPriority(uid: String, beforeUID targetUID: String) async {
        await appState.updateSettings { settings in
            Self.moveByUID(&settings.outputPriorityList, uid: uid, beforeUID: targetUID)
        }
    }

    nonisolated static func moveByUID(_ list: inout [DeviceEntry], uid: String, beforeUID targetUID: String) {
        guard uid != targetUID,
              let fromIndex = list.firstIndex(where: { $0.uid == uid }),
              let originalTargetIndex = list.firstIndex(where: { $0.uid == targetUID }) else { return }
        // Dragging downward: drop AFTER target so the item lands past it.
        // Dragging upward: drop BEFORE target.
        let movingDown = fromIndex < originalTargetIndex
        let item = list.remove(at: fromIndex)
        let newTargetIndex = list.firstIndex(where: { $0.uid == targetUID }) ?? list.count
        let insertIndex = movingDown ? newTargetIndex + 1 : newTargetIndex
        list.insert(item, at: min(insertIndex, list.count))
    }

    func moveInputPriority(uid: String, toIndex: Int) async {
        await appState.updateSettings { settings in
            Self.moveByUIDToIndex(&settings.inputPriorityList, uid: uid, toIndex: toIndex)
        }
    }

    func moveOutputPriority(uid: String, toIndex: Int) async {
        await appState.updateSettings { settings in
            Self.moveByUIDToIndex(&settings.outputPriorityList, uid: uid, toIndex: toIndex)
        }
    }

    nonisolated private static func moveByUIDToIndex(_ list: inout [DeviceEntry], uid: String, toIndex: Int) {
        guard let from = list.firstIndex(where: { $0.uid == uid }) else { return }
        let item = list.remove(at: from)
        let clamped = max(0, min(toIndex, list.count))
        list.insert(item, at: clamped)
    }

    nonisolated private static func move(_ list: inout [DeviceEntry], at index: Int, direction: MoveDirection) {
        guard list.indices.contains(index) else { return }
        switch direction {
        case .up:
            guard index > 0 else { return }
            list.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
        case .down:
            guard index < list.count - 1 else { return }
            // `move(fromOffsets:toOffset:)` uses an "insert-before" offset, so to move
            // one slot down we target index + 2.
            list.move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
        }
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
            Self.log.error("setLaunchAtLogin(\(enabled, privacy: .public)) failed: \(String(describing: error), privacy: .public)")
        }
    }

    func exportSettings() async throws -> Data {
        try await appState.exportSettings()
    }

    func importSettings(_ data: Data) async throws {
        try await appState.importSettings(data)
    }
}
