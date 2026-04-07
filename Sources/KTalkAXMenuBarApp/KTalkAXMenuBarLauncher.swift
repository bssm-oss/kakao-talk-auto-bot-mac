import AppKit
import ApplicationServices
import Foundation

@MainActor
public enum KTalkAXMenuBarLauncher {
    public static func run() {
        if CommandLine.arguments.contains("--print-accessibility-status") {
            let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": false] as CFDictionary)
            let payload = "{\"trusted\":\(trusted ? "true" : "false")}" + "\n"
            FileHandle.standardOutput.write(Data(payload.utf8))
            return
        }

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
