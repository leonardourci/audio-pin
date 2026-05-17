import Foundation

actor DevicePinEngine {
    private static let log = AppLog.logger("DevicePinEngine")
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
        Self.log.debug("""
            enforce: enabled=\(isEnabled, privacy: .public) \
            currentIn=\(currentInputID, privacy: .public) currentOut=\(currentOutputID, privacy: .public) \
            preferredInUID=\(preferredInputUID ?? "nil", privacy: .public) \
            preferredOutUID=\(preferredOutputUID ?? "nil", privacy: .public) \
            inPriority=\(inputPriority.count, privacy: .public) outPriority=\(outputPriority.count, privacy: .public) \
            connected=\(connectedDevices.count, privacy: .public)
            """)

        guard isEnabled else {
            Self.log.debug("enforce: skipped (disabled)")
            return
        }
        guard !isRunaway() else {
            Self.log.error("enforce: skipped (runaway guard tripped)")
            return
        }
        if isSelfWrite() {
            Self.log.debug("enforce: skipped (self-write window)")
            return
        }

        let targetInput = resolve(
            preferred: preferredInputUID,
            priority: inputPriority,
            from: connectedDevices,
            scope: .input
        )
        if let target = targetInput {
            if target.id != currentInputID {
                Self.log.info("enforce: setting input -> id=\(target.id, privacy: .public) uid=\(target.uid, privacy: .public) name=\(target.name, privacy: .public)")
                lastWriteTime = .now
                do {
                    try setter.setDefaultInput(target.id)
                } catch {
                    Self.log.error("enforce: setDefaultInput failed: \(String(describing: error), privacy: .public)")
                }
            } else {
                Self.log.debug("enforce: input already on target id=\(target.id, privacy: .public)")
            }
        } else {
            Self.log.info("enforce: no input target resolved (preferred=\(preferredInputUID ?? "nil", privacy: .public), priorityCount=\(inputPriority.count, privacy: .public))")
        }

        let targetOutput = resolve(
            preferred: preferredOutputUID,
            priority: outputPriority,
            from: connectedDevices,
            scope: .output
        )
        if let target = targetOutput {
            if target.id != currentOutputID {
                Self.log.info("enforce: setting output -> id=\(target.id, privacy: .public) uid=\(target.uid, privacy: .public) name=\(target.name, privacy: .public)")
                lastWriteTime = .now
                do {
                    try setter.setDefaultOutput(target.id)
                } catch {
                    Self.log.error("enforce: setDefaultOutput failed: \(String(describing: error), privacy: .public)")
                }
            } else {
                Self.log.debug("enforce: output already on target id=\(target.id, privacy: .public)")
            }
        } else {
            Self.log.info("enforce: no output target resolved (preferred=\(preferredOutputUID ?? "nil", privacy: .public), priorityCount=\(outputPriority.count, privacy: .public))")
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
        Self.log.debug("resolve(\(String(describing: scope), privacy: .public)): candidates=\(candidates.map { "\($0.name)#\($0.id)" }.joined(separator: ","), privacy: .public)")

        if let uid = preferred {
            if let match = candidates.first(where: { $0.uid == uid }) {
                Self.log.debug("resolve: preferred uid=\(uid, privacy: .public) matched id=\(match.id, privacy: .public)")
                return match
            } else {
                Self.log.debug("resolve: preferred uid=\(uid, privacy: .public) NOT in compatible candidates")
            }
        }

        for entry in priority {
            if let match = candidates.first(where: { $0.uid == entry.uid }) {
                Self.log.debug("resolve: priority uid=\(entry.uid, privacy: .public) matched id=\(match.id, privacy: .public)")
                return match
            }
            if let match = candidates.first(where: { $0.name == entry.lastKnownName }) {
                Self.log.debug("resolve: priority name=\(entry.lastKnownName, privacy: .public) matched id=\(match.id, privacy: .public)")
                return match
            }
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
