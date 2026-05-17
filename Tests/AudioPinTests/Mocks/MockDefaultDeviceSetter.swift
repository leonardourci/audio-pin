import Foundation
@testable import AudioPin

final class MockDefaultDeviceSetter: DefaultDeviceSetter, @unchecked Sendable {
    struct Call: Equatable {
        let scope: Scope
        let id: DeviceID
    }
    enum Scope { case input, output }

    private(set) var calls: [Call] = []
    var errorToThrow: Error?

    func setDefaultInput(_ id: DeviceID) throws {
        if let e = errorToThrow { throw e }
        calls.append(Call(scope: .input, id: id))
    }

    func setDefaultOutput(_ id: DeviceID) throws {
        if let e = errorToThrow { throw e }
        calls.append(Call(scope: .output, id: id))
    }

    var inputCalls: [DeviceID] { calls.filter { $0.scope == .input }.map(\.id) }
    var outputCalls: [DeviceID] { calls.filter { $0.scope == .output }.map(\.id) }
}
