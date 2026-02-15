import ApplicationServices
import Foundation

@MainActor
final class AccessibilityPermissionManager {
    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func promptForAccess() {
        let promptKey = "AXTrustedCheckOptionPrompt"
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
