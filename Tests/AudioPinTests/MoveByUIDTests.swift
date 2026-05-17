import Testing
@testable import AudioPin

@Suite struct MoveByUIDTests {

    private func entries(_ uids: [String]) -> [DeviceEntry] {
        uids.map { DeviceEntry(uid: $0, lastKnownName: "name-\($0)") }
    }

    private func uids(_ list: [DeviceEntry]) -> [String] {
        list.map(\.uid)
    }

    @Test func moveByUID_downward_landsAfterTarget() {
        var list = entries(["a", "b", "c"])
        // Drag first row onto second (downward).
        SettingsViewModel.moveByUID(&list, uid: "a", beforeUID: "b")
        #expect(uids(list) == ["b", "a", "c"])
    }

    @Test func moveByUID_downward_toLast_landsAtEnd() {
        var list = entries(["a", "b", "c"])
        SettingsViewModel.moveByUID(&list, uid: "a", beforeUID: "c")
        #expect(uids(list) == ["b", "c", "a"])
    }

    @Test func moveByUID_upward_landsBeforeTarget() {
        var list = entries(["a", "b", "c"])
        SettingsViewModel.moveByUID(&list, uid: "c", beforeUID: "a")
        #expect(uids(list) == ["c", "a", "b"])
    }

    @Test func moveByUID_ontoSelf_isNoOp() {
        var list = entries(["a", "b", "c"])
        SettingsViewModel.moveByUID(&list, uid: "b", beforeUID: "b")
        #expect(uids(list) == ["a", "b", "c"])
    }
}
