import Foundation

struct AppSettings: Codable, Sendable {
    var schemaVersion: Int = 1
    var inputPriorityList: [DeviceEntry]
    var outputPriorityList: [DeviceEntry]
    var profiles: [Profile]
    var activeProfileID: UUID
    var enforcementEnabled: Bool
    var launchAtLogin: Bool

    static func makeDefault() -> AppSettings {
        let defaultProfile = Profile.makeDefault()
        return AppSettings(
            inputPriorityList: [],
            outputPriorityList: [],
            profiles: [defaultProfile],
            activeProfileID: defaultProfile.id,
            enforcementEnabled: true,
            launchAtLogin: false
        )
    }
}
