import Foundation
import Testing
@testable import AudioPin

@Suite struct ProfileTests {

    @Test func defaultIcon_rotatesThroughIconChoices() {
        let choices = Profile.iconChoices
        #expect(!choices.isEmpty)
        for i in 0..<choices.count {
            #expect(Profile.defaultIcon(forIndex: i) == choices[i])
        }
        // Past the end wraps.
        #expect(Profile.defaultIcon(forIndex: choices.count) == choices[0])
        #expect(Profile.defaultIcon(forIndex: choices.count + 3) == choices[3])
        // Negative indices wrap defensively too.
        #expect(Profile.defaultIcon(forIndex: -1) == choices[choices.count - 1])
    }

    @Test func displayIconSystemName_fallsBackWhenNil() {
        var p = Profile.makeDefault()
        p.iconSystemName = nil
        #expect(p.displayIconSystemName == "person.2.fill")

        p.iconSystemName = "music.note"
        #expect(p.displayIconSystemName == "music.note")
    }

    @Test func codableBackwardCompat_missingIconSystemNameDecodesAsNil() throws {
        let id = UUID()
        let json = """
        {
            "id": "\(id.uuidString)",
            "name": "Legacy",
            "preferredInputUID": null,
            "preferredOutputUID": null,
            "gainTarget": 0.75,
            "gainLockEnabled": false,
            "autoTriggerDeviceUID": null
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(Profile.self, from: json)
        #expect(decoded.id == id)
        #expect(decoded.name == "Legacy")
        #expect(decoded.iconSystemName == nil)
        #expect(decoded.displayIconSystemName == "person.2.fill")
    }
}
