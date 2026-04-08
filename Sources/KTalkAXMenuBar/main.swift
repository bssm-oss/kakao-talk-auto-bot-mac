import Foundation
import ApplicationServices

if CommandLine.arguments.contains("--print-accessibility-status") {
    let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": false] as CFDictionary)
    let payload = "{\"trusted\":\(trusted ? "true" : "false")}" + "\n"
    FileHandle.standardOutput.write(Data(payload.utf8))
    exit(0)
}

if CommandLine.arguments.contains("--prompt-accessibility-status") {
    let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    let payload = "{\"trusted\":\(trusted ? "true" : "false")}" + "\n"
    FileHandle.standardOutput.write(Data(payload.utf8))
    exit(0)
}

import KTalkAXMenuBarApp
KTalkAXMenuBarLauncher.run()
