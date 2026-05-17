import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    private(set) var connectedDevices: [AudioDevice] = []
    private(set) var currentInputID: DeviceID = 0
    private(set) var currentOutputID: DeviceID = 0
    // Integer percent (0...100) is the canonical UI representation. Float only
    // appears at the CoreAudio boundary so hardware quantization cannot cause
    // a 1% visual jump on slider release.
    private(set) var currentOutputPercent: Int = 0
    private(set) var currentInputPercent: Int = 0
    private(set) var settings: AppSettings = .makeDefault()
    private(set) var enforcementBlocked = false

    // True while the user is actively dragging the input gain slider; gain-lock
    // enforcement is paused so it doesn't fight the live slider value.
    private(set) var isAdjustingInputGain = false

    // User-write filter window. After the user commits a slider value, hardware
    // may quantize to a value that round-trips through the listener to a
    // different integer percent (e.g. write 50% -> hardware stores 0.5078 ->
    // listener reports 51%). Within this window, ignore listener readbacks for
    // the same device so the UI keeps the user's chosen percent. Separate from
    // the gain-lock path: this is user intent vs. hardware quantization, not
    // an echo filter. See PRD §4a.
    private var lastUserInputGainWriteTime: ContinuousClock.Instant?
    private var lastUserOutputVolumeWriteTime: ContinuousClock.Instant?
    private static let userWriteFilterWindow: Duration = .milliseconds(500)

    func setAdjustingInputGain(_ adjusting: Bool) {
        isAdjustingInputGain = adjusting
    }

    private static let log = AppLog.logger("AppState")

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

        registerInputGainListeners(for: connectedDevices.map(\.id))

        snapshotInputGain()
        snapshotOutputVolume()
        registerInputGainListener(for: currentInputID)
        registerOutputVolumeListener(for: currentOutputID)
    }

    // MARK: - Volume/gain mutations (called from UI)

    func setOutputVolumePercent(_ percent: Int) async {
        let clamped = max(0, min(100, percent))
        let id = currentOutputID
        do {
            try hardware.setOutputVolume(Float(clamped) / 100, forDevice: id)
            currentOutputPercent = clamped
            lastUserOutputVolumeWriteTime = .now
        } catch {
            Self.log.error("setOutputVolume failed: id=\(id, privacy: .public) error=\(String(describing: error), privacy: .public)")
        }
    }

    func setInputGainPercent(_ percent: Int) async {
        let clamped = max(0, min(100, percent))
        let id = currentInputID
        do {
            try hardware.setInputGain(Float(clamped) / 100, forDevice: id)
            currentInputPercent = clamped
            lastUserInputGainWriteTime = .now
        } catch {
            Self.log.error("setInputGain failed: id=\(id, privacy: .public) error=\(String(describing: error), privacy: .public)")
        }
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
            registerInputGainListeners(for: Array(addedIDs))
        }

        let connectedUIDs = Set(connectedDevices.map(\.uid))
        await store.autoActivateProfile(for: connectedUIDs)
        settings = await store.settings
        await enforceCurrentProfile()
    }

    private func onDefaultInputChanged() {
        currentInputID = hardware.defaultInputDeviceID()
        // Previous device's listener block stays attached (no CoreAudio deregistration
        // API in use). CoreAudio tolerates multiple listener blocks per property.
        snapshotInputGain()
        registerInputGainListener(for: currentInputID)
        Task { await enforceCurrentProfile() }
    }

    private func onDefaultOutputChanged() {
        currentOutputID = hardware.defaultOutputDeviceID()
        snapshotOutputVolume()
        registerOutputVolumeListener(for: currentOutputID)
        Task { await enforceCurrentProfile() }
    }

    private func onInputGainChanged(for deviceID: DeviceID) async {
        if deviceID == currentInputID,
           !isWithinUserWriteWindow(lastUserInputGainWriteTime),
           let v = hardware.inputGain(forDevice: deviceID) {
            currentInputPercent = Self.percent(from: v)
        }
        guard deviceID == currentInputID,
              !isAdjustingInputGain,
              let profile = activeProfile,
              profile.gainLockEnabled
        else { return }
        await gainEngine.enforce(deviceID: deviceID, target: profile.gainTarget, enabled: true)
    }

    private func onOutputVolumeChanged(for deviceID: DeviceID) {
        guard deviceID == currentOutputID,
              !isWithinUserWriteWindow(lastUserOutputVolumeWriteTime),
              let v = hardware.outputVolume(forDevice: deviceID)
        else { return }
        currentOutputPercent = Self.percent(from: v)
    }

    private func isWithinUserWriteWindow(_ last: ContinuousClock.Instant?) -> Bool {
        guard let last else { return false }
        return ContinuousClock.now - last < Self.userWriteFilterWindow
    }

    // Float -> Int percent. Single rounding point; nothing downstream rounds again.
    private static func percent(from v: Float) -> Int {
        let clamped = max(0, min(1, v))
        return Int((clamped * 100).rounded())
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

    private func registerInputGainListeners(for deviceIDs: [DeviceID]) {
        for id in deviceIDs {
            hardware.addInputGainListener(forDevice: id) { [weak self] in
                Task { @MainActor in await self?.onInputGainChanged(for: id) }
            }
        }
    }

    private func snapshotInputGain() {
        currentInputPercent = Self.percent(from: hardware.inputGain(forDevice: currentInputID) ?? 0)
    }

    private func snapshotOutputVolume() {
        currentOutputPercent = Self.percent(from: hardware.outputVolume(forDevice: currentOutputID) ?? 0)
    }

    private func registerInputGainListener(for id: DeviceID) {
        guard id != 0 else { return }
        // Same device may already have a listener from registerInputGainListeners;
        // CoreAudio tolerates multiple listener blocks per property.
        hardware.addInputGainListener(forDevice: id) { [weak self] in
            Task { @MainActor in await self?.onInputGainChanged(for: id) }
        }
    }

    private func registerOutputVolumeListener(for id: DeviceID) {
        guard id != 0 else { return }
        hardware.addOutputVolumeListener(forDevice: id) { [weak self] in
            Task { @MainActor in self?.onOutputVolumeChanged(for: id) }
        }
    }
}
