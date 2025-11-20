import ApplicationServices
import Foundation

final class AccessibilityPermissionManager {
    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func promptForAccess() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
