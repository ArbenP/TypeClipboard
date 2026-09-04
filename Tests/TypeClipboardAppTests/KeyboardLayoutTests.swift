import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import TypeClipboardApp

final class KeyboardLayoutTests: XCTestCase {
    func testControlCharactersResolveWithoutLayoutData() {
        let layout = KeyboardLayout(table: [:])

        XCTAssertEqual(layout.keyStroke(for: "\n"), KeyStroke(keyCode: CGKeyCode(kVK_Return), modifiers: []))
        XCTAssertEqual(layout.keyStroke(for: "\r"), KeyStroke(keyCode: CGKeyCode(kVK_Return), modifiers: []))
        XCTAssertEqual(layout.keyStroke(for: "\t"), KeyStroke(keyCode: CGKeyCode(kVK_Tab), modifiers: []))
    }

    func testUnreachableCharacterHasNoKeyStroke() {
        let layout = KeyboardLayout(table: ["a": KeyStroke(keyCode: CGKeyCode(kVK_ANSI_A), modifiers: [])])

        XCTAssertNil(layout.keyStroke(for: "😀"))
    }

    func testKeyStrokeReturnsTheMappedStroke() {
        let stroke = KeyStroke(keyCode: CGKeyCode(kVK_ANSI_1), modifiers: .maskShift)
        let layout = KeyboardLayout(table: ["!": stroke])

        XCTAssertEqual(layout.keyStroke(for: "!"), stroke)
    }

    /// The bug this guards: every character used to be posted on virtual key 0, so remote desktop
    /// clients received the same character for the whole buffer because they read the key code and
    /// ignore the Unicode payload.
    func testCurrentLayoutMapsDistinctCharactersToDistinctKeyStrokes() throws {
        let layout = try currentLayout()
        let sample = "abcdefghijklmnopqrstuvwxyz0123456789"

        var strokes: Set<[UInt64]> = []
        for character in sample {
            guard let stroke = layout.keyStroke(for: character) else {
                throw XCTSkip("Character \(character) is not reachable on the active keyboard layout.")
            }
            strokes.insert([UInt64(stroke.keyCode), stroke.modifiers.rawValue])
        }

        XCTAssertEqual(strokes.count, sample.count, "Characters collided onto the same keystroke.")
    }

    func testUppercaseSharesTheKeyCodeOfLowercaseAndAddsShift() throws {
        let layout = try currentLayout()

        guard let lowercase = layout.keyStroke(for: "a"), let uppercase = layout.keyStroke(for: "A") else {
            throw XCTSkip("The active keyboard layout does not carry the Latin letter A.")
        }

        XCTAssertEqual(uppercase.keyCode, lowercase.keyCode)
        XCTAssertFalse(lowercase.modifiers.contains(.maskShift))
        XCTAssertTrue(uppercase.modifiers.contains(.maskShift))
    }

    private func currentLayout() throws -> KeyboardLayout {
        let layout = KeyboardLayout.current()
        if layout.isEmpty {
            throw XCTSkip("No Unicode keyboard layout data available in this environment.")
        }
        return layout
    }
}
