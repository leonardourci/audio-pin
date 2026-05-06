import Foundation

struct Profile: Codable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var preferredInputUID: String?
    var preferredOutputUID: String?
    var gainTarget: Float
    var gainLockEnabled: Bool
    var autoTriggerDeviceUID: String?

    static func makeDefault() -> Profile {
        Profile(
            id: UUID(),
            name: "Default",
            preferredInputUID: nil,
            preferredOutputUID: nil,
            gainTarget: 0.75,
            gainLockEnabled: false,
            autoTriggerDeviceUID: nil
        )
    }
}
