import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// A single keystroke: the virtual key code plus the modifiers needed to produce a character
/// on a given keyboard layout.
struct KeyStroke: Equatable {
    let keyCode: CGKeyCode
    let modifiers: CGEventFlags
}

/// Maps characters to the real virtual key codes of the active keyboard layout.
///
/// Remote desktop clients (RDP, VNC) translate the *virtual key code* of a synthetic event into a
/// scancode for the remote host and ignore any Unicode payload attached to the event. Posting every
/// event with a placeholder key code therefore delivers the same character over and over on the
/// remote side, even though native macOS apps look correct because they read the Unicode payload.
///
/// Resolving the real key code keeps remote sessions working. The Unicode payload is still attached,
/// so local typing is unchanged.
struct KeyboardLayout {
    private let table: [Character: KeyStroke]

    init(table: [Character: KeyStroke]) {
        self.table = table
    }

    var isEmpty: Bool { table.isEmpty }

    /// The keystroke that produces `character`, or `nil` if the layout cannot reach it (emoji,
    /// characters from another script, anything needing more than one keypress).
    func keyStroke(for character: Character) -> KeyStroke? {
        if let stroke = Self.controlKeyStroke(for: character) { return stroke }
        return table[character]
    }

    /// Builds a map for the keyboard layout the user is currently typing on. Returns an empty
    /// layout if macOS will not hand over layout data, in which case callers fall back to posting
    /// the Unicode payload alone.
    static func current() -> KeyboardLayout {
        guard let layoutData = currentLayoutData() else { return KeyboardLayout(table: [:]) }
        return KeyboardLayout(table: buildTable(from: layoutData))
    }

    // Control characters never come back cleanly from the layout tables, so they are pinned to the
    // keys that produce them on every layout.
    private static func controlKeyStroke(for character: Character) -> KeyStroke? {
        switch character {
        case "\n", "\r":
            return KeyStroke(keyCode: CGKeyCode(kVK_Return), modifiers: [])
        case "\t":
            return KeyStroke(keyCode: CGKeyCode(kVK_Tab), modifiers: [])
        default:
            return nil
        }
    }

    private static func currentLayoutData() -> Data? {
        // Copies the underlying layout even when an input method (Pinyin, Kotoeri, ...) is active.
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        return Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
    }

    private static func buildTable(from layoutData: Data) -> [Character: KeyStroke] {
        // Ordered cheapest-first: a character reachable without modifiers is never registered as a
        // shifted or alted keystroke, and low key codes win over the numeric keypad.
        let combinations: [(flags: CGEventFlags, carbonModifiers: UInt32)] = [
            ([], 0),
            (.maskShift, UInt32(shiftKey >> 8)),
            (.maskAlternate, UInt32(optionKey >> 8)),
            ([.maskShift, .maskAlternate], UInt32((shiftKey | optionKey) >> 8))
        ]

        let keyboardType = UInt32(LMGetKbdType())
        var table: [Character: KeyStroke] = [:]

        for combination in combinations {
            for keyCode in CGKeyCode(0)..<CGKeyCode(128) {
                guard let character = translate(keyCode: keyCode,
                                                carbonModifiers: combination.carbonModifiers,
                                                keyboardType: keyboardType,
                                                layoutData: layoutData),
                      let scalar = character.unicodeScalars.first,
                      scalar.value >= 32, scalar.value != 127,
                      table[character] == nil else {
                    continue
                }

                table[character] = KeyStroke(keyCode: keyCode, modifiers: combination.flags)
            }
        }

        return table
    }

    private static func translate(keyCode: CGKeyCode,
                                  carbonModifiers: UInt32,
                                  keyboardType: UInt32,
                                  layoutData: Data) -> Character? {
        var deadKeyState: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 4)
        var length = 0

        let status: OSStatus = layoutData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> OSStatus in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return OSStatus(-1)
            }

            return UCKeyTranslate(layout,
                                  keyCode,
                                  UInt16(kUCKeyActionDown),
                                  carbonModifiers,
                                  keyboardType,
                                  OptionBits(kUCKeyTranslateNoDeadKeysMask),
                                  &deadKeyState,
                                  characters.count,
                                  &length,
                                  &characters)
        }

        // Only single-unit results are usable: anything longer needs more than one keypress.
        guard status == noErr, length == 1, let scalar = Unicode.Scalar(characters[0]) else { return nil }
        return Character(scalar)
    }
}
