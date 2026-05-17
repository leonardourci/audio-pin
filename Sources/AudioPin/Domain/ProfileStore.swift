import Foundation

actor ProfileStore {
    private static let log = AppLog.logger("ProfileStore")
    private static let defaultsKey = "audiopin.settings"

    private(set) var settings: AppSettings

    init() {
        settings = Self.load()
    }

    var activeProfile: Profile? {
        settings.profiles.first(where: { $0.id == settings.activeProfileID })
    }

    func update(_ mutation: @Sendable (inout AppSettings) -> Void) {
        mutation(&settings)
        persist()
    }

    func autoActivateProfile(for connectedUIDs: Set<String>) {
        guard let match = settings.profiles.first(where: {
            guard let trigger = $0.autoTriggerDeviceUID else { return false }
            return connectedUIDs.contains(trigger)
        }) else { return }
        settings.activeProfileID = match.id
        persist()
    }

    func exportJSON() throws -> Data {
        try JSONEncoder().encode(settings)
    }

    func importJSON(_ data: Data) throws {
        let imported = try JSONDecoder().decode(AppSettings.self, from: data)
        settings = imported
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        } catch {
            Self.log.error("persist failed: \(String(describing: error), privacy: .public)")
        }
    }

    private static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return .makeDefault()
        }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            log.error("load failed, falling back to defaults: \(String(describing: error), privacy: .public)")
            return .makeDefault()
        }
    }
}
