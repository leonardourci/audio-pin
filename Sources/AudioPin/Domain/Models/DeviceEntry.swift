struct DeviceEntry: Codable, Sendable, Hashable {
    var uid: String
    var lastKnownName: String
}

extension DeviceEntry: Identifiable {
    var id: String { uid }
}
