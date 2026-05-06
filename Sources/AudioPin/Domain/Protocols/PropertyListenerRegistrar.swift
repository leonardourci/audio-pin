protocol PropertyListenerRegistrar: Sendable {
    func addDeviceListListener(_ handler: @escaping @Sendable () -> Void)
    func addDefaultInputListener(_ handler: @escaping @Sendable () -> Void)
    func addDefaultOutputListener(_ handler: @escaping @Sendable () -> Void)
    func addGainListener(forDevice id: DeviceID, _ handler: @escaping @Sendable () -> Void)
}
