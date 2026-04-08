import AppKit
import Foundation
import KTalkAXCore

@MainActor
final class KTalkAXMenuBarApplicationDelegate: NSObject, NSApplicationDelegate {
    private let service = KTalkAXService()
    private let preferences = AppPreferences()
    private let aiDraftWorkflow = AIDraftWorkflow()

    private var settingsWindowController: SettingsWindowController?
    private var popoverController: MainPopoverViewController?
    private var statusItemController: StatusItemController?
    private var silentRefreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settingsWindowController = SettingsWindowController(preferences: preferences, aiDraftWorkflow: aiDraftWorkflow)
        let popoverController = MainPopoverViewController(service: service, preferences: preferences, aiDraftWorkflow: aiDraftWorkflow)
        let statusItemController = StatusItemController(contentController: popoverController)

        popoverController.onOpenSettings = { [weak self] in
            self?.showSettings(nil)
        }
        popoverController.onStatusAppearanceChange = { [weak statusItemController, weak settingsWindowController] appearance, status in
            statusItemController?.apply(appearance: appearance)
            settingsWindowController?.update(status: status)
        }

        statusItemController.onRefreshRequested = { [weak popoverController] in
            popoverController?.refreshFromMenu()
        }
        statusItemController.onOpenSettings = { [weak self] in
            self?.showSettings(nil)
        }
        statusItemController.onQuitRequested = {
            NSApp.terminate(nil)
        }

        self.settingsWindowController = settingsWindowController
        self.popoverController = popoverController
        self.statusItemController = statusItemController

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak popoverController] in
            popoverController?.refreshStatusSilently()
        }

        silentRefreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak popoverController] _ in
            DispatchQueue.main.async {
                popoverController?.refreshStatusSilently()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(nil)
        return true
    }

    @objc func showSettings(_ sender: Any?) {
        settingsWindowController?.showWindowAndActivate()
    }

    func applicationWillTerminate(_ notification: Notification) {
        silentRefreshTimer?.invalidate()
        silentRefreshTimer = nil
    }
}
