import Foundation
@testable import AudioPin

final class MockPropertyListenerRegistrar: PropertyListenerRegistrar, @unchecked Sendable {
    private let lock = NSLock()
    private var _deviceListHandlers: [@Sendable () -> Void] = []
    private var _defaultInputHandlers: [@Sendable () -> Void] = []
    private var _defaultOutputHandlers: [@Sendable () -> Void] = []
    private var _inputGainHandlers: [DeviceID: [@Sendable () -> Void]] = [:]
    private var _outputVolumeHandlers: [DeviceID: [@Sendable () -> Void]] = [:]

    func addDeviceListListener(_ handler: @escaping @Sendable () -> Void) {
        lock.lock(); defer { lock.unlock() }
        _deviceListHandlers.append(handler)
    }

    func addDefaultInputListener(_ handler: @escaping @Sendable () -> Void) {
        lock.lock(); defer { lock.unlock() }
        _defaultInputHandlers.append(handler)
    }

    func addDefaultOutputListener(_ handler: @escaping @Sendable () -> Void) {
        lock.lock(); defer { lock.unlock() }
        _defaultOutputHandlers.append(handler)
    }

    func addInputGainListener(forDevice id: DeviceID, _ handler: @escaping @Sendable () -> Void) {
        lock.lock(); defer { lock.unlock() }
        _inputGainHandlers[id, default: []].append(handler)
    }

    func addOutputVolumeListener(forDevice id: DeviceID, _ handler: @escaping @Sendable () -> Void) {
        lock.lock(); defer { lock.unlock() }
        _outputVolumeHandlers[id, default: []].append(handler)
    }

    func fireDeviceListChanged() {
        lock.lock(); let h = _deviceListHandlers; lock.unlock()
        h.forEach { $0() }
    }

    func fireDefaultInputChanged() {
        lock.lock(); let h = _defaultInputHandlers; lock.unlock()
        h.forEach { $0() }
    }

    func fireDefaultOutputChanged() {
        lock.lock(); let h = _defaultOutputHandlers; lock.unlock()
        h.forEach { $0() }
    }

    func fireInputGainChanged(forDevice id: DeviceID) {
        lock.lock(); let h = _inputGainHandlers[id] ?? []; lock.unlock()
        h.forEach { $0() }
    }

    func fireOutputVolumeChanged(forDevice id: DeviceID) {
        lock.lock(); let h = _outputVolumeHandlers[id] ?? []; lock.unlock()
        h.forEach { $0() }
    }

    var inputGainListenerCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _inputGainHandlers.values.reduce(0) { $0 + $1.count }
    }
}
