import Foundation
@testable import AudioPin

final class MockGainController: GainController, @unchecked Sendable {
    struct InputWrite: Equatable {
        let value: Float
        let id: DeviceID
    }

    var inputGainValues: [DeviceID: Float] = [:]
    var outputVolumeValues: [DeviceID: Float] = [:]
    var errorToThrow: Error?

    private(set) var setInputGainCalls: [InputWrite] = []
    private(set) var setOutputVolumeCalls: [InputWrite] = []

    func inputGain(forDevice id: DeviceID) -> Float? { inputGainValues[id] }

    func setInputGain(_ value: Float, forDevice id: DeviceID) throws {
        if let e = errorToThrow { throw e }
        setInputGainCalls.append(InputWrite(value: value, id: id))
        inputGainValues[id] = value
    }

    func outputVolume(forDevice id: DeviceID) -> Float? { outputVolumeValues[id] }

    func setOutputVolume(_ value: Float, forDevice id: DeviceID) throws {
        if let e = errorToThrow { throw e }
        setOutputVolumeCalls.append(InputWrite(value: value, id: id))
        outputVolumeValues[id] = value
    }
}
