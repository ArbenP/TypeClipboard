import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

enum TypingEngineError: LocalizedError {
    case emptyBuffer
    case accessibilityDenied
    case eventCreationFailed

    var errorDescription: String? {
        switch self {
        case .emptyBuffer:
            return "There is nothing to type. Capture the clipboard or paste text into the buffer."
        case .accessibilityDenied:
            return "TypeClipboard needs accessibility access to simulate keystrokes. Enable it in System Settings ▸ Privacy & Security ▸ Accessibility."
        case .eventCreationFailed:
            return "macOS refused to create keyboard events. Try again or restart the app."
        }
    }
}

@MainActor
final class TypingEngine {
    private let keyPressDuration: UInt64 = 15_000_000 // 15 ms between key down and key up

    func type(text: String, characterDelay: Double, appendReturn: Bool) async throws {
        guard !text.isEmpty else { throw TypingEngineError.emptyBuffer }
        guard EventPostingPermission.isGranted() else { throw TypingEngineError.accessibilityDenied }

        let sanitizedDelay = max(characterDelay, 0)
        let eventSource = CGEventSource(stateID: .hidSystemState)

        for character in text {
            try await send(character: character, using: eventSource, interCharacterDelay: sanitizedDelay)
        }

        if appendReturn {
            try await sendReturn(using: eventSource, interCharacterDelay: sanitizedDelay)
        }
    }

    private func send(character: Character, using source: CGEventSource?, interCharacterDelay delay: Double) async throws {
        var utf16Units = Array(String(character).utf16)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            throw TypingEngineError.eventCreationFailed
        }

        keyDown.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: &utf16Units)
        keyUp.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: &utf16Units)

        keyDown.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: keyPressDuration)
        keyUp.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: nanoseconds(for: delay))
    }

    private func sendReturn(using source: CGEventSource?, interCharacterDelay delay: Double) async throws {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Return), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Return), keyDown: false) else {
            throw TypingEngineError.eventCreationFailed
        }

        down.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: keyPressDuration)
        up.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: nanoseconds(for: delay))
    }

    private func nanoseconds(for delay: Double) -> UInt64 {
        guard delay > 0 else { return 0 }
        return UInt64(delay * 1_000_000_000)
    }
}
