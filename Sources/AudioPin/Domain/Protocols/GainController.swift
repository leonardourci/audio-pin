protocol GainController: Sendable {
    func gain(forDevice id: DeviceID) -> Float?
    func setGain(_ value: Float, forDevice id: DeviceID) throws
}
