import AppKit
import Foundation

@MainActor
public enum KTalkAXMenuBarLauncher {
    public static func run() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)

        let delegate = KTalkAXMenuBarApplicationDelegate()
        AppDelegateRetainer.shared.delegate = delegate
        application.delegate = delegate
        application.run()
    }
}

@MainActor
private final class AppDelegateRetainer {
    static let shared = AppDelegateRetainer()

    var delegate: NSApplicationDelegate?
}
