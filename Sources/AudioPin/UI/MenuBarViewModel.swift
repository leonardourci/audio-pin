import Foundation
import Observation

@Observable
@MainActor
final class MenuBarViewModel {
    private let appState: AppState

    var currentInputName: String {
        appState.connectedDevices.first(where: { $0.id == appState.currentInputID })?.name ?? "Unknown"
    }

    var currentOutputName: String {
        appState.connectedDevices.first(where: { $0.id == appState.currentOutputID })?.name ?? "Unknown"
    }

    var activeProfileName: String {
        appState.activeProfile?.name ?? "None"
    }

    var enforcementEnabled: Bool {
        get { appState.settings.enforcementEnabled }
    }

    var profiles: [Profile] {
        appState.settings.profiles
    }

    var activeProfileID: UUID {
        appState.settings.activeProfileID
    }

    var enforcementBlocked: Bool {
        appState.enforcementBlocked
    }

    var isConfigured: Bool {
        !appState.settings.inputPriorityList.isEmpty || !appState.settings.outputPriorityList.isEmpty
    }

    init(appState: AppState) {
        self.appState = appState
    }

    func toggleEnforcement() async {
        await appState.updateSettings { $0.enforcementEnabled.toggle() }
    }

    func activateProfile(id: UUID) async {
        await appState.activateProfile(id: id)
    }
}
