protocol PropertyListenerRegistrar: Sendable {
    func addDeviceListListener(_ handler: @escaping @Sendable () -> Void)
    func addDefaultInputListener(_ handler: @escaping @Sendable () -> Void)
    func addDefaultOutputListener(_ handler: @escaping @Sendable () -> Void)
    func addInputGainListener(forDevice id: DeviceID, _ handler: @escaping @Sendable () -> Void)
    func addOutputVolumeListener(forDevice id: DeviceID, _ handler: @escaping @Sendable () -> Void)
}
