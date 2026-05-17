import Foundation
import Testing
@testable import AudioPin

@Suite struct DevicePinEngineTests {

    // MARK: - Fixtures

    private func makeEngine() -> (DevicePinEngine, MockDeviceListProvider, MockDefaultDeviceSetter) {
        let lister = MockDeviceListProvider()
        let setter = MockDefaultDeviceSetter()
        let engine = DevicePinEngine(listProvider: lister, setter: setter)
        return (engine, lister, setter)
    }

    private let micA = AudioDevice(id: 10, uid: "uid.mic.A", name: "Mic A", hasInput: true, hasOutput: false)
    private let micB = AudioDevice(id: 11, uid: "uid.mic.B", name: "Mic B", hasInput: true, hasOutput: false)
    private let micC = AudioDevice(id: 12, uid: "uid.mic.C", name: "Mic C (renamed)", hasInput: true, hasOutput: false)
    private let spkX = AudioDevice(id: 20, uid: "uid.spk.X", name: "Speakers X", hasInput: false, hasOutput: true)

    // MARK: - Self-write filter

    @Test func selfWriteFilter_secondCallWithinWindowSkipsWrite() async {
        let (engine, _, setter) = makeEngine()
        let connected = [micA, spkX]

        // First enforce: micA in priority list, current is 0, should write.
        await engine.enforce(
            inputPriority: [DeviceEntry(uid: micA.uid, lastKnownName: micA.name)],
            outputPriority: [],
            preferredInputUID: nil,
            preferredOutputUID: nil,
            connectedDevices: connected,
            currentInputID: 0,
            currentOutputID: 0,
            isEnabled: true
        )
        #expect(setter.inputCalls == [micA.id])

        // Second immediate enforce: target still differs from current. Only the
        // self-write filter (50 ms window) prevents the second write.
        await engine.enforce(
            inputPriority: [DeviceEntry(uid: micA.uid, lastKnownName: micA.name)],
            outputPriority: [],
            preferredInputUID: nil,
            preferredOutputUID: nil,
            connectedDevices: connected,
            currentInputID: 0,
            currentOutputID: 0,
            isEnabled: true
        )
        #expect(setter.inputCalls == [micA.id])
    }

    // MARK: - Runaway guard

    @Test func runawayGuard_firesOnBlockedAfter11CallsWithin1s() async {
        let (engine, _, _) = makeEngine()

        let blocked = AtomicFlag()
        await engine.setOnBlocked {
            blocked.set()
        }

        // 11 rapid calls; threshold is >10 within 1s.
        for _ in 0..<11 {
            await engine.enforce(
                inputPriority: [],
                outputPriority: [],
                preferredInputUID: nil,
                preferredOutputUID: nil,
                connectedDevices: [],
                currentInputID: 0,
                currentOutputID: 0,
                isEnabled: true
            )
        }

        #expect(blocked.isSet)
    }

    // MARK: - resolve()

    @Test func resolve_preferredUID_winsOverPriorityList() async {
        let (engine, _, setter) = makeEngine()
        await engine.enforce(
            inputPriority: [
                DeviceEntry(uid: micA.uid, lastKnownName: micA.name),
                DeviceEntry(uid: micB.uid, lastKnownName: micB.name),
            ],
            outputPriority: [],
            preferredInputUID: micB.uid,
            preferredOutputUID: nil,
            connectedDevices: [micA, micB],
            currentInputID: 0,
            currentOutputID: 0,
            isEnabled: true
        )
        #expect(setter.inputCalls == [micB.id])
    }

    @Test func resolve_fallsThroughPriorityListWhenPreferredMissing() async {
        let (engine, _, setter) = makeEngine()
        await engine.enforce(
            inputPriority: [
                DeviceEntry(uid: micA.uid, lastKnownName: micA.name),
                DeviceEntry(uid: micB.uid, lastKnownName: micB.name),
            ],
            outputPriority: [],
            preferredInputUID: "uid.does.not.exist",
            preferredOutputUID: nil,
            connectedDevices: [micB],
            currentInputID: 0,
            currentOutputID: 0,
            isEnabled: true
        )
        #expect(setter.inputCalls == [micB.id])
    }

    @Test func resolve_fallsBackToLastKnownName_whenUIDMismatch() async {
        let (engine, _, setter) = makeEngine()
        // Entry uid is gone (firmware reset) but lastKnownName matches the
        // currently-connected micC.
        await engine.enforce(
            inputPriority: [
                DeviceEntry(uid: "uid.mic.C.old", lastKnownName: micC.name),
            ],
            outputPriority: [],
            preferredInputUID: nil,
            preferredOutputUID: nil,
            connectedDevices: [micC],
            currentInputID: 0,
            currentOutputID: 0,
            isEnabled: true
        )
        #expect(setter.inputCalls == [micC.id])
    }

    // MARK: - No-op cases

    @Test func noWrite_whenTargetEqualsCurrent() async {
        let (engine, _, setter) = makeEngine()
        await engine.enforce(
            inputPriority: [DeviceEntry(uid: micA.uid, lastKnownName: micA.name)],
            outputPriority: [],
            preferredInputUID: nil,
            preferredOutputUID: nil,
            connectedDevices: [micA],
            currentInputID: micA.id,
            currentOutputID: 0,
            isEnabled: true
        )
        #expect(setter.inputCalls == [])
        #expect(setter.outputCalls == [])
    }

    @Test func noWrite_whenDisabled() async {
        let (engine, _, setter) = makeEngine()
        await engine.enforce(
            inputPriority: [DeviceEntry(uid: micA.uid, lastKnownName: micA.name)],
            outputPriority: [DeviceEntry(uid: spkX.uid, lastKnownName: spkX.name)],
            preferredInputUID: nil,
            preferredOutputUID: nil,
            connectedDevices: [micA, spkX],
            currentInputID: 0,
            currentOutputID: 0,
            isEnabled: false
        )
        #expect(setter.calls == [])
    }
}

/// Sendable boolean flag used to capture callback invocation in tests.
final class AtomicFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() { lock.lock(); value = true; lock.unlock() }
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
}
