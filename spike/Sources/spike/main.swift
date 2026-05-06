import CoreAudio
import Foundation

// Force unbuffered stdout
setbuf(stdout, nil)
setbuf(stderr, nil)

// MARK: - Helpers

func cfStringProp(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> String? {
    var addr = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
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

func u32Prop(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> UInt32? {
    var addr = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )
    var size = UInt32(MemoryLayout<UInt32>.size)
    var value: UInt32 = 0
    let status = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value)
    guard status == noErr else { return nil }
    return value
}

func setU32Prop(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: UInt32) -> OSStatus {
    var addr = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var v = value
    let size = UInt32(MemoryLayout<UInt32>.size)
    return AudioObjectSetPropertyData(id, &addr, 0, nil, size, &v)
}

func deviceHasStreams(_ id: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreams,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    let status = AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size)
    guard status == noErr else { return false }
    return size > 0
}

struct Device {
    let id: AudioObjectID
    let uid: String
    let name: String
    let hasInput: Bool
    let hasOutput: Bool
}

func listDevices() -> [Device] {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return [] }
    let count = Int(size) / MemoryLayout<AudioObjectID>.size
    var ids = [AudioObjectID](repeating: 0, count: count)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return [] }

    return ids.compactMap { id -> Device? in
        let uid = cfStringProp(id, kAudioDevicePropertyDeviceUID) ?? "?"
        let name = cfStringProp(id, kAudioObjectPropertyName) ?? "?"
        let hasIn = deviceHasStreams(id, scope: kAudioDevicePropertyScopeInput)
        let hasOut = deviceHasStreams(id, scope: kAudioDevicePropertyScopeOutput)
        return Device(id: id, uid: uid, name: name, hasInput: hasIn, hasOutput: hasOut)
    }
}

func nameForID(_ id: AudioObjectID) -> String {
    cfStringProp(id, kAudioObjectPropertyName) ?? "?"
}

func defaultInputID() -> AudioObjectID {
    AudioObjectID(u32Prop(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice) ?? 0)
}

func defaultOutputID() -> AudioObjectID {
    AudioObjectID(u32Prop(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice) ?? 0)
}

func setDefaultInput(_ id: AudioObjectID) -> OSStatus {
    setU32Prop(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice, id)
}

func setDefaultOutput(_ id: AudioObjectID) -> OSStatus {
    setU32Prop(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, id)
}

func inputVolume(_ id: AudioObjectID) -> Float32? {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
    )
    if !AudioObjectHasProperty(id, &addr) {
        addr.mElement = 1
        guard AudioObjectHasProperty(id, &addr) else { return nil }
    }
    var size = UInt32(MemoryLayout<Float32>.size)
    var v: Float32 = 0
    guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &v) == noErr else { return nil }
    return v
}

func setInputVolume(_ id: AudioObjectID, _ value: Float32) -> OSStatus {
    // Try Main first; if not present, write all per-channel elements.
    var mainAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
    )
    var v = value
    if AudioObjectHasProperty(id, &mainAddr) {
        return AudioObjectSetPropertyData(id, &mainAddr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
    }
    var lastStatus: OSStatus = -1
    for el: AudioObjectPropertyElement in [1, 2] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: el
        )
        if AudioObjectHasProperty(id, &addr) {
            v = value
            lastStatus = AudioObjectSetPropertyData(id, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
        }
    }
    return lastStatus
}

// MARK: - Listeners

let listenerQueue = DispatchQueue(label: "audiopin.spike.listener")

func addListener(
    _ object: AudioObjectID,
    _ selector: AudioObjectPropertySelector,
    _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    _ block: @escaping (AudioObjectPropertySelector) -> Void
) {
    var addr = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectAddPropertyListenerBlock(object, &addr, listenerQueue) { _, addrs in
        let buf = UnsafeBufferPointer(start: addrs, count: 1)
        for a in buf {
            block(a.mSelector)
        }
    }
    if status != noErr {
        print("listener add failed for selector \(fourCC(selector)): \(status)")
    }
}

func fourCC(_ value: UInt32) -> String {
    let chars = [
        Character(UnicodeScalar((value >> 24) & 0xff) ?? "?"),
        Character(UnicodeScalar((value >> 16) & 0xff) ?? "?"),
        Character(UnicodeScalar((value >> 8) & 0xff) ?? "?"),
        Character(UnicodeScalar(value & 0xff) ?? "?")
    ]
    return String(chars)
}

func ts() -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f.string(from: Date())
}

// MARK: - Main

print("=== AudioPin CoreAudio spike ===\n")

let devices = listDevices()
print("Devices (\(devices.count)):")
for d in devices {
    let io = "\(d.hasInput ? "I" : "-")\(d.hasOutput ? "O" : "-")"
    print("  [\(io)] id=\(d.id)  uid=\(d.uid)  name=\(d.name)")
}

print("\nDefault input:  \(defaultInputID()) (\(nameForID(defaultInputID())))")
print("Default output: \(defaultOutputID()) (\(nameForID(defaultOutputID())))")

let inID = defaultInputID()
if let vol = inputVolume(inID) {
    print("Default input gain: \(vol)")
} else {
    print("Default input gain: <not readable>")
}

print("\nRegistering listeners. Plug/unplug devices, change defaults in System Settings, change mic gain. Ctrl-C to exit.\n")

let sysObj = AudioObjectID(kAudioObjectSystemObject)

addListener(sysObj, kAudioHardwarePropertyDevices) { _ in
    print("[\(ts())] device list changed")
    let now = listDevices()
    for d in now {
        let io = "\(d.hasInput ? "I" : "-")\(d.hasOutput ? "O" : "-")"
        print("    [\(io)] \(d.name) (\(d.uid))")
    }
}

addListener(sysObj, kAudioHardwarePropertyDefaultInputDevice) { _ in
    let id = defaultInputID()
    print("[\(ts())] default INPUT changed -> \(id) \(nameForID(id))")
}

addListener(sysObj, kAudioHardwarePropertyDefaultOutputDevice) { _ in
    let id = defaultOutputID()
    print("[\(ts())] default OUTPUT changed -> \(id) \(nameForID(id))")
}

addListener(sysObj, kAudioHardwarePropertyDefaultSystemOutputDevice) { _ in
    let id = AudioObjectID(u32Prop(sysObj, kAudioHardwarePropertyDefaultSystemOutputDevice) ?? 0)
    print("[\(ts())] default SYSTEM OUTPUT changed -> \(id) \(nameForID(id))")
}

// Probe which elements have the volume property
print("Probing volume property on input device \(inID):")
for el: AudioObjectPropertyElement in [kAudioObjectPropertyElementMain, 1, 2] {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: el
    )
    let has = AudioObjectHasProperty(inID, &addr)
    print("  element \(el): hasProperty=\(has)")
}

// Attach listener to Main, 1, and 2 — see which fires.
for el: AudioObjectPropertyElement in [kAudioObjectPropertyElementMain, 1, 2] {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: el
    )
    if AudioObjectHasProperty(inID, &addr) {
        let status = AudioObjectAddPropertyListenerBlock(inID, &addr, listenerQueue) { _, _ in
            print("[\(ts())] gain listener fired (element \(el))")
        }
        print("  attached listener on element \(el): \(status)")
    }
}

// CLI: simple stdin commands
print("Commands: 'l' list, 'i <id>' set default input, 'o <id>' set default output, 'g <0-1>' set input gain, 'q' quit")

DispatchQueue.global().async {
    while let line = readLine() {
        let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
        guard let cmd = parts.first else { continue }
        switch cmd {
        case "l":
            for d in listDevices() {
                let io = "\(d.hasInput ? "I" : "-")\(d.hasOutput ? "O" : "-")"
                print("  [\(io)] id=\(d.id)  \(d.name)")
            }
        case "i":
            if parts.count > 1, let id = UInt32(parts[1]) {
                let s = setDefaultInput(AudioObjectID(id))
                print("setDefaultInput -> \(s)")
            }
        case "o":
            if parts.count > 1, let id = UInt32(parts[1]) {
                let s = setDefaultOutput(AudioObjectID(id))
                print("setDefaultOutput -> \(s)")
            }
        case "g":
            if parts.count > 1, let v = Float32(parts[1]) {
                let s = setInputVolume(defaultInputID(), v)
                print("setInputVolume -> \(s)")
            }
        case "q":
            exit(0)
        default:
            print("?")
        }
    }
}

RunLoop.main.run()
