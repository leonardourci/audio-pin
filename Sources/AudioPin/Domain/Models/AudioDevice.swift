typealias DeviceID = UInt32

struct AudioDevice: Sendable, Hashable {
    let id: DeviceID
    let uid: String
    let name: String
    let hasInput: Bool
    let hasOutput: Bool
}
