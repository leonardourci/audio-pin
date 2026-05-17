import Foundation
import Testing
@testable import AudioPin

@Suite(.serialized) struct ProfileStoreTests {
    private static let defaultsKey = "audiopin.settings"

    init() {
        UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
    }

    @Test func defaultSettings_haveOneProfile_withStableID() async {
        let store = ProfileStore()
        let settings = await store.settings
        #expect(settings.profiles.count == 1)
        #expect(settings.profiles.first?.id == settings.activeProfileID)
        #expect(settings.profiles.first?.name == "Default")
    }

    @Test func exportImport_roundtripPreservesSettings() async throws {
        let store = ProfileStore()
        let triggerUID = "uid.trigger.headset"
        let newProfileID = UUID()

        await store.update { settings in
            settings.inputPriorityList = [DeviceEntry(uid: "uid.mic.A", lastKnownName: "Mic A")]
            settings.outputPriorityList = [DeviceEntry(uid: "uid.spk.X", lastKnownName: "Speakers X")]
            settings.enforcementEnabled = false
            settings.profiles.append(Profile(
                id: newProfileID,
                name: "Work",
                preferredInputUID: "uid.mic.A",
                preferredOutputUID: "uid.spk.X",
                gainTarget: 0.6,
                gainLockEnabled: true,
                autoTriggerDeviceUID: triggerUID,
                iconSystemName: "headphones"
            ))
        }

        let data = try await store.exportJSON()

        UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
        let other = ProfileStore()
        try await other.importJSON(data)

        let imported = await other.settings
        #expect(imported.inputPriorityList.first?.uid == "uid.mic.A")
        #expect(imported.outputPriorityList.first?.lastKnownName == "Speakers X")
        #expect(!imported.enforcementEnabled)
        #expect(imported.profiles.count == 2)
        let work = imported.profiles.first(where: { $0.id == newProfileID })
        #expect(work != nil)
        #expect(work?.name == "Work")
        #expect(abs((work?.gainTarget ?? 0) - 0.6) < 0.0001)
        #expect(work?.gainLockEnabled == true)
        #expect(work?.autoTriggerDeviceUID == triggerUID)
        #expect(work?.iconSystemName == "headphones")
    }

    @Test func autoActivateProfile_switchesActiveByConnectedUID() async {
        let store = ProfileStore()
        let workID = UUID()
        let gamingID = UUID()
        let workTriggerUID = "uid.headset.work"
        let gamingTriggerUID = "uid.headset.gaming"

        await store.update { settings in
            settings.profiles.append(Profile(
                id: workID,
                name: "Work",
                preferredInputUID: nil, preferredOutputUID: nil,
                gainTarget: 0.7, gainLockEnabled: false,
                autoTriggerDeviceUID: workTriggerUID,
                iconSystemName: nil
            ))
            settings.profiles.append(Profile(
                id: gamingID,
                name: "Gaming",
                preferredInputUID: nil, preferredOutputUID: nil,
                gainTarget: 0.7, gainLockEnabled: false,
                autoTriggerDeviceUID: gamingTriggerUID,
                iconSystemName: nil
            ))
        }

        await store.autoActivateProfile(for: [gamingTriggerUID])
        var settings = await store.settings
        #expect(settings.activeProfileID == gamingID)

        await store.autoActivateProfile(for: [workTriggerUID])
        settings = await store.settings
        #expect(settings.activeProfileID == workID)

        // Non-matching uid: active remains unchanged.
        await store.autoActivateProfile(for: ["uid.random.noise"])
        settings = await store.settings
        #expect(settings.activeProfileID == workID)
    }
}
