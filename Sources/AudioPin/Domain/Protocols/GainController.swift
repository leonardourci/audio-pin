protocol GainController: Sendable {
    func inputGain(forDevice id: DeviceID) -> Float?
    func setInputGain(_ value: Float, forDevice id: DeviceID) throws
    func outputVolume(forDevice id: DeviceID) -> Float?
    func setOutputVolume(_ value: Float, forDevice id: DeviceID) throws
}
