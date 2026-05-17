import Foundation

actor GainLockEngine {
    private static let log = AppLog.logger("GainLockEngine")
    private let gainController: any GainController

    private var eventTimestamps: [ContinuousClock.Instant] = []
    private static let runawayThreshold = 10
    private static let runawayWindow: Duration = .seconds(1)

    var onBlocked: (@Sendable () -> Void)?

    init(gainController: any GainController) {
        self.gainController = gainController
    }

    func setOnBlocked(_ handler: @escaping @Sendable () -> Void) {
        onBlocked = handler
    }

    func enforce(deviceID: DeviceID, target: Float, enabled: Bool) {
        guard enabled, !isRunaway() else { return }
        do {
            try gainController.setInputGain(target, forDevice: deviceID)
        } catch {
            Self.log.error("enforce: setInputGain failed: id=\(deviceID, privacy: .public) error=\(String(describing: error), privacy: .public)")
        }
    }

    private func isRunaway() -> Bool {
        let now = ContinuousClock.now
        eventTimestamps.append(now)
        eventTimestamps = eventTimestamps.filter { now - $0 < Self.runawayWindow }
        guard eventTimestamps.count > Self.runawayThreshold else { return false }
        onBlocked?()
        return true
    }
}
