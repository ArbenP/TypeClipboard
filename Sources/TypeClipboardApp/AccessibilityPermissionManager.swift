import ApplicationServices
import Foundation

@MainActor
enum EventPostingPermission {
    static func isGranted() -> Bool {
        // App Sandbox-compatible check for synthetic key event posting.
        if CGPreflightPostEventAccess() {
            return true
        }

        // Fallback for local/non-sandbox workflows that still rely on AX trust.
        return AXIsProcessTrusted()
    }

    static func prompt() {
        // Requests permission to post synthetic key events.
        if CGRequestPostEventAccess() {
            return
        }

        // Fallback prompt for environments where AX is the active gate.
        let promptKey = "AXTrustedCheckOptionPrompt"
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

@MainActor
final class AccessibilityPermissionManager {
    func isTrusted() -> Bool {
        EventPostingPermission.isGranted()
    }

    func promptForAccess() {
        EventPostingPermission.prompt()
    }
}
