import Testing
@testable import AudioPin

@Suite struct GainLockEngineTests {

    private let deviceID: DeviceID = 42

    @Test func enforce_writesTarget_whenEnabled() async {
        let gain = MockGainController()
        gain.inputGainValues[deviceID] = 0.30
        let engine = GainLockEngine(gainController: gain)

        await engine.enforce(deviceID: deviceID, target: 0.75, enabled: true)

        #expect(gain.setInputGainCalls.count == 1)
        #expect(gain.setInputGainCalls.first?.id == deviceID)
        #expect(abs((gain.setInputGainCalls.first?.value ?? 0) - 0.75) < 0.0001)
    }

    @Test func enforce_skipsWhenDisabled() async {
        let gain = MockGainController()
        gain.inputGainValues[deviceID] = 0.30
        let engine = GainLockEngine(gainController: gain)

        await engine.enforce(deviceID: deviceID, target: 0.75, enabled: false)

        #expect(gain.setInputGainCalls.isEmpty)
    }

    @Test func runawayGuard_firesOnBlockedAfter11CallsWithin1s() async {
        let gain = MockGainController()
        let engine = GainLockEngine(gainController: gain)

        let blocked = AtomicFlag()
        await engine.setOnBlocked {
            blocked.set()
        }

        for _ in 0..<11 {
            await engine.enforce(deviceID: deviceID, target: 0.5, enabled: true)
        }

        #expect(blocked.isSet)
    }
}
