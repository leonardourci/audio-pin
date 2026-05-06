import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    private(set) var connectedDevices: [AudioDevice] = []
    private(set) var currentInputID: DeviceID = 0
    private(set) var currentOutputID: DeviceID = 0
    private(set) var settings: AppSettings = .makeDefault()
    private(set) var enforcementBlocked = false

    var activeProfile: Profile? {
        settings.profiles.first(where: { $0.id == settings.activeProfileID })
    }

    private let hardware: AudioHardwareService
    private let pinEngine: DevicePinEngine
    private let gainEngine: GainLockEngine
    private let store: ProfileStore
    private var started = false

    init() {
        let hw = AudioHardwareService()
        hardware = hw
        pinEngine = DevicePinEngine(listProvider: hw, setter: hw)
        gainEngine = GainLockEngine(gainController: hw)
        store = ProfileStore()
    }

    func start() async {
        guard !started else { return }
        started = true
        settings = await store.settings
        connectedDevices = hardware.listDevices()
        currentInputID = hardware.defaultInputDeviceID()
        currentOutputID = hardware.defaultOutputDeviceID()

        await pinEngine.setOnBlocked { [weak self] in
            Task { @MainActor in self?.enforcementBlocked = true }
        }
        await gainEngine.setOnBlocked { [weak self] in
            Task { @MainActor in self?.enforcementBlocked = true }
        }

        hardware.addDeviceListListener { [weak self] in
            Task { @MainActor in await self?.onDeviceListChanged() }
        }
        hardware.addDefaultInputListener { [weak self] in
            Task { @MainActor in self?.onDefaultInputChanged() }
        }
        hardware.addDefaultOutputListener { [weak self] in
            Task { @MainActor in self?.onDefaultOutputChanged() }
        }

        registerGainListeners(for: connectedDevices.map(\.id))
    }

    // MARK: - Settings mutations (called from UI)

    func updateSettings(_ mutation: @Sendable (inout AppSettings) -> Void) async {
        await store.update(mutation)
        settings = await store.settings
    }

    func activateProfile(id: UUID) async {
        await store.update { $0.activeProfileID = id }
        settings = await store.settings
        await enforceCurrentProfile()
    }

    func exportSettings() async throws -> Data {
        try await store.exportJSON()
    }

    func importSettings(_ data: Data) async throws {
        try await store.importJSON(data)
        settings = await store.settings
    }

    // MARK: - Event handlers

    private func onDeviceListChanged() async {
        let previousIDs = Set(connectedDevices.map(\.id))
        connectedDevices = hardware.listDevices()

        let newIDs = Set(connectedDevices.map(\.id))
        let addedIDs = newIDs.subtracting(previousIDs)
        if !addedIDs.isEmpty {
            registerGainListeners(for: Array(addedIDs))
        }

        let connectedUIDs = Set(connectedDevices.map(\.uid))
        await store.autoActivateProfile(for: connectedUIDs)
        settings = await store.settings
        await enforceCurrentProfile()
    }

    private func onDefaultInputChanged() {
        currentInputID = hardware.defaultInputDeviceID()
        Task { await enforceCurrentProfile() }
    }

    private func onDefaultOutputChanged() {
        currentOutputID = hardware.defaultOutputDeviceID()
        Task { await enforceCurrentProfile() }
    }

    private func onGainChanged(for deviceID: DeviceID) async {
        guard deviceID == currentInputID,
              let profile = activeProfile,
              profile.gainLockEnabled
        else { return }
        await gainEngine.enforce(deviceID: deviceID, target: profile.gainTarget, enabled: true)
    }

    // MARK: - Enforcement

    private func enforceCurrentProfile() async {
        guard let profile = activeProfile else { return }
        await pinEngine.enforce(
            inputPriority: settings.inputPriorityList,
            outputPriority: settings.outputPriorityList,
            preferredInputUID: profile.preferredInputUID,
            preferredOutputUID: profile.preferredOutputUID,
            connectedDevices: connectedDevices,
            currentInputID: currentInputID,
            currentOutputID: currentOutputID,
            isEnabled: settings.enforcementEnabled
        )
    }

    private func registerGainListeners(for deviceIDs: [DeviceID]) {
        for id in deviceIDs {
            hardware.addGainListener(forDevice: id) { [weak self] in
                Task { @MainActor in await self?.onGainChanged(for: id) }
            }
        }
    }
}
