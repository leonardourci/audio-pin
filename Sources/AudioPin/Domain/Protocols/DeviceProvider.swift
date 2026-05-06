protocol DeviceListProvider: Sendable {
    func listDevices() -> [AudioDevice]
    func defaultInputDeviceID() -> DeviceID
    func defaultOutputDeviceID() -> DeviceID
}

protocol DefaultDeviceSetter: Sendable {
    func setDefaultInput(_ id: DeviceID) throws
    func setDefaultOutput(_ id: DeviceID) throws
}
