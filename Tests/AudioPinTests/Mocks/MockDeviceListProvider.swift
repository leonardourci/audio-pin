import Foundation
@testable import AudioPin

final class MockDeviceListProvider: DeviceListProvider, @unchecked Sendable {
    var devices: [AudioDevice] = []
    var defaultInput: DeviceID = 0
    var defaultOutput: DeviceID = 0

    private(set) var listDevicesCallCount = 0

    func listDevices() -> [AudioDevice] {
        listDevicesCallCount += 1
        return devices
    }

    func defaultInputDeviceID() -> DeviceID { defaultInput }
    func defaultOutputDeviceID() -> DeviceID { defaultOutput }
}
