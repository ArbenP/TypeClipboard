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
}
