import CoreAudio
import Foundation

final class AudioHardwareService: @unchecked Sendable {
    private let queue = DispatchQueue(label: "audiopin.hardware", qos: .userInteractive)

    // Retain listener blocks so CoreAudio doesn't deallocate them
    private var listenerBlocks: [Any] = []
    private let blocksLock = NSLock()
}

// MARK: - DeviceListProvider

extension AudioHardwareService: DeviceListProvider {
    func listDevices() -> [AudioDevice] {
        var addr = systemAddr(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &addr, 0, nil, &size) == noErr else { return [] }

        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &ids) == noErr else { return [] }

        return ids.compactMap { deviceFrom(id: $0) }
    }

    func defaultInputDeviceID() -> DeviceID {
        u32(systemObject, kAudioHardwarePropertyDefaultInputDevice) ?? 0
    }

    func defaultOutputDeviceID() -> DeviceID {
        u32(systemObject, kAudioHardwarePropertyDefaultOutputDevice) ?? 0
    }
}

// MARK: - DefaultDeviceSetter

extension AudioHardwareService: DefaultDeviceSetter {
    func setDefaultInput(_ id: DeviceID) throws {
        try setU32(systemObject, kAudioHardwarePropertyDefaultInputDevice, id)
    }

    func setDefaultOutput(_ id: DeviceID) throws {
        try setU32(systemObject, kAudioHardwarePropertyDefaultOutputDevice, id)
    }
}

// MARK: - GainController

extension AudioHardwareService: GainController {
    func gain(forDevice id: DeviceID) -> Float? {
        // Try Main element first; fall back to per-channel elements (USB mics)
        for element: AudioObjectPropertyElement in [kAudioObjectPropertyElementMain, 1, 2] {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: element
            )
            guard AudioObjectHasProperty(id, &addr) else { continue }
            var size = UInt32(MemoryLayout<Float32>.size)
            var value: Float32 = 0
            guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { continue }
            return value
        }
        return nil
    }

    func setGain(_ value: Float, forDevice id: DeviceID) throws {
        var wroteAny = false
        for element: AudioObjectPropertyElement in [kAudioObjectPropertyElementMain, 1, 2] {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: element
            )
            guard AudioObjectHasProperty(id, &addr) else { continue }
            var v = value
            let status = AudioObjectSetPropertyData(id, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
            if status == noErr { wroteAny = true }
        }
        if !wroteAny { throw AudioError.propertyNotFound }
    }
}

// MARK: - PropertyListenerRegistrar

extension AudioHardwareService: PropertyListenerRegistrar {
    func addDeviceListListener(_ handler: @escaping @Sendable () -> Void) {
        addListener(on: systemObject, selector: kAudioHardwarePropertyDevices) { handler() }
    }

    func addDefaultInputListener(_ handler: @escaping @Sendable () -> Void) {
        addListener(on: systemObject, selector: kAudioHardwarePropertyDefaultInputDevice) { handler() }
    }

    func addDefaultOutputListener(_ handler: @escaping @Sendable () -> Void) {
        addListener(on: systemObject, selector: kAudioHardwarePropertyDefaultOutputDevice) { handler() }
    }

    func addGainListener(forDevice id: DeviceID, _ handler: @escaping @Sendable () -> Void) {
        for element: AudioObjectPropertyElement in [kAudioObjectPropertyElementMain, 1, 2] {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: element
            )
            guard AudioObjectHasProperty(id, &addr) else { continue }
            let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
            let status = AudioObjectAddPropertyListenerBlock(id, &addr, queue, block)
            if status == noErr {
                blocksLock.withLock { listenerBlocks.append(block) }
            }
        }
    }
}

// MARK: - Private helpers

private extension AudioHardwareService {
    var systemObject: AudioObjectID { AudioObjectID(kAudioObjectSystemObject) }

    func systemAddr(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    func u32(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<UInt32>.size)
        var value: UInt32 = 0
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    func setU32(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: UInt32) throws {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var v = value
        let status = AudioObjectSetPropertyData(id, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &v)
        if status != noErr { throw AudioError.coreAudio(status) }
    }

    func cfString(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<CFString?>.size)
        var value: CFString?
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0)
        }
        guard status == noErr, let v = value else { return nil }
        return v as String
    }

    func hasStreams(_ id: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr else { return false }
        return size > 0
    }

    func deviceFrom(id: AudioObjectID) -> AudioDevice? {
        guard let uid = cfString(id, kAudioDevicePropertyDeviceUID) else { return nil }
        let name = cfString(id, kAudioObjectPropertyName) ?? uid
        return AudioDevice(
            id: id,
            uid: uid,
            name: name,
            hasInput: hasStreams(id, scope: kAudioDevicePropertyScopeInput),
            hasOutput: hasStreams(id, scope: kAudioDevicePropertyScopeOutput)
        )
    }

    func addListener(
        on object: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        handler: @escaping @Sendable () -> Void
    ) {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        let status = AudioObjectAddPropertyListenerBlock(object, &addr, queue, block)
        if status == noErr {
            blocksLock.withLock { listenerBlocks.append(block) }
        }
    }
}
