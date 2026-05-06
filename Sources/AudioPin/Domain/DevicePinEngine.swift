import Foundation

actor DevicePinEngine {
    private let listProvider: any DeviceListProvider
    private let setter: any DefaultDeviceSetter

    // Prevents feedback loop: CoreAudio echoes own writes on default-device path
    private var lastWriteTime: ContinuousClock.Instant?
    private static let selfWriteWindow: Duration = .milliseconds(50)

    // Runaway guard: bail if enforcement fires >10x/s for >1s
    private var eventTimestamps: [ContinuousClock.Instant] = []
    private static let runawayThreshold = 10
    private static let runawayWindow: Duration = .seconds(1)

    var onBlocked: (@Sendable () -> Void)?

    init(listProvider: any DeviceListProvider, setter: any DefaultDeviceSetter) {
        self.listProvider = listProvider
        self.setter = setter
    }

    func setOnBlocked(_ handler: @escaping @Sendable () -> Void) {
        onBlocked = handler
    }

    func enforce(
        inputPriority: [DeviceEntry],
        outputPriority: [DeviceEntry],
        preferredInputUID: String?,
        preferredOutputUID: String?,
        connectedDevices: [AudioDevice],
        currentInputID: DeviceID,
        currentOutputID: DeviceID,
        isEnabled: Bool
    ) {
        guard isEnabled, !isRunaway() else { return }

        if !isSelfWrite() {
            let targetInput = resolve(
                preferred: preferredInputUID,
                priority: inputPriority,
                from: connectedDevices,
                scope: .input
            )
            if let target = targetInput, target.id != currentInputID {
                lastWriteTime = .now
                try? setter.setDefaultInput(target.id)
            }

            let targetOutput = resolve(
                preferred: preferredOutputUID,
                priority: outputPriority,
                from: connectedDevices,
                scope: .output
            )
            if let target = targetOutput, target.id != currentOutputID {
                lastWriteTime = .now
                try? setter.setDefaultOutput(target.id)
            }
        }
    }

    private func isSelfWrite() -> Bool {
        guard let last = lastWriteTime else { return false }
        return ContinuousClock.now - last < Self.selfWriteWindow
    }

    private func isRunaway() -> Bool {
        let now = ContinuousClock.now
        eventTimestamps.append(now)
        eventTimestamps = eventTimestamps.filter { now - $0 < Self.runawayWindow }
        guard eventTimestamps.count > Self.runawayThreshold else { return false }
        onBlocked?()
        return true
    }

    private enum Scope { case input, output }

    private func resolve(
        preferred: String?,
        priority: [DeviceEntry],
        from connected: [AudioDevice],
        scope: Scope
    ) -> AudioDevice? {
        let candidates = connected.filter { isCompatible($0, scope: scope) }

        // Profile's preferred device takes top priority if connected
        if let uid = preferred, let match = candidates.first(where: { $0.uid == uid }) {
            return match
        }

        // Fall through priority list: UID match first, name fallback
        for entry in priority {
            if let match = candidates.first(where: { $0.uid == entry.uid }) { return match }
            if let match = candidates.first(where: { $0.name == entry.lastKnownName }) { return match }
        }

        return nil
    }

    private func isCompatible(_ device: AudioDevice, scope: Scope) -> Bool {
        switch scope {
        case .input: device.hasInput
        case .output: device.hasOutput
        }
    }
}
