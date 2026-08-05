import XCTest
@testable import TypeClipboardApp

final class TypingEngineTests: XCTestCase {
    func testTypingEmptyBufferThrows() async {
        let engine = TypingEngine()

        do {
            try await engine.type(text: "", characterDelay: 0, appendReturn: false)
            XCTFail("Expected TypingEngineError.emptyBuffer")
        } catch TypingEngineError.emptyBuffer {
            // Expected path
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOperationsWithoutShiftReturnKeepsNewlinesAsCharacters() {
        let ops = TypingOperation.operations(for: "a\nb", appendReturn: true, shiftReturnForNewlines: false)

        XCTAssertEqual(ops, [
            .character("a"),
            .character("\n"),
            .character("b"),
            .returnKey(shift: false)
        ])
    }

    func testOperationsWithShiftReturnConvertsNewlinesToShiftReturn() {
        let ops = TypingOperation.operations(for: "a\nb", appendReturn: true, shiftReturnForNewlines: true)

        XCTAssertEqual(ops, [
            .character("a"),
            .returnKey(shift: true),
            .character("b"),
            .returnKey(shift: false)
        ])
    }

    func testOperationsAppendReturnStaysPlainReturnEvenWithShiftReturnEnabled() {
        let ops = TypingOperation.operations(for: "a\nb", appendReturn: true, shiftReturnForNewlines: true)

        // The trailing Return from appendReturn must be a plain (non-shift) Return.
        if case .returnKey(let shift) = ops.last {
            XCTAssertFalse(shift, "appendReturn should produce a plain Return, not Shift+Return")
        } else {
            XCTFail("Expected last operation to be a returnKey")
        }
    }

    func testOperationsNoAppendReturnOmitsTrailingReturn() {
        let ops = TypingOperation.operations(for: "a\nb", appendReturn: false, shiftReturnForNewlines: true)

        XCTAssertEqual(ops, [
            .character("a"),
            .returnKey(shift: true),
            .character("b")
        ])
    }

    func testOperationsHandlesCarriageReturnAndCRLF() {
        // Swift treats "\r\n" as a single Character (a single Unicode line break),
        // so it produces one Shift+Return. A lone "\r" also counts as a newline.
        let crlfOps = TypingOperation.operations(for: "a\r\nb", appendReturn: false, shiftReturnForNewlines: true)
        XCTAssertEqual(crlfOps, [
            .character("a"),
            .returnKey(shift: true),
            .character("b")
        ])

        let crOps = TypingOperation.operations(for: "a\rb", appendReturn: false, shiftReturnForNewlines: true)
        XCTAssertEqual(crOps, [
            .character("a"),
            .returnKey(shift: true),
            .character("b")
        ])
    }
}
