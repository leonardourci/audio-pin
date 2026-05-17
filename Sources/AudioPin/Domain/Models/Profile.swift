import Foundation

struct Profile: Codable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var preferredInputUID: String?
    var preferredOutputUID: String?
    var gainTarget: Float
    var gainLockEnabled: Bool
    var autoTriggerDeviceUID: String?
    var iconSystemName: String?

    static let iconChoices: [String] = [
        "person.2.fill",
        "headphones",
        "music.note",
        "gamecontroller.fill",
        "mic.fill",
        "speaker.wave.2.fill",
        "house.fill",
        "briefcase.fill"
    ]

    var displayIconSystemName: String { iconSystemName ?? "person.2.fill" }

    static func defaultIcon(forIndex index: Int) -> String {
        guard !iconChoices.isEmpty else { return "person.2.fill" }
        let safe = ((index % iconChoices.count) + iconChoices.count) % iconChoices.count
        return iconChoices[safe]
    }

    static func makeDefault() -> Profile {
        Profile(
            id: UUID(),
            name: "Default",
            preferredInputUID: nil,
            preferredOutputUID: nil,
            gainTarget: 0.75,
            gainLockEnabled: false,
            autoTriggerDeviceUID: nil,
            iconSystemName: nil
        )
    }
}
