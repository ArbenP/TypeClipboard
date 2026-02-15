import AppKit
import Foundation
import XCTest
@testable import TypeClipboardApp

@MainActor
final class ClipboardViewModelTests: XCTestCase {
    func testUserEditedBufferRecalculatesMetrics() {
        let viewModel = makeViewModel()

        viewModel.bufferText = "line1\nline2"
        viewModel.userEditedBuffer()

        XCTAssertEqual(viewModel.characterCount, 11)
        XCTAssertEqual(viewModel.lineCount, 2)
        XCTAssertEqual(viewModel.previewDescription, "line1⏎line2 (11 characters)")
        XCTAssertNotNil(viewModel.lastUpdatedAt)
    }

    func testAutoCaptureToggleStartsAndStopsWatcher() {
        let watcher = ClipboardWatcherMock()
        let viewModel = makeViewModel(watcher: watcher)

        viewModel.autoCapture = true
        viewModel.autoCapture = false

        XCTAssertEqual(watcher.startCallCount, 1)
        XCTAssertEqual(watcher.stopCallCount, 1)
    }

    func testAutoCaptureUpdatesBufferWhenEnabled() {
        let viewModel = makeViewModel()
        viewModel.autoCapture = true

        viewModel.handleClipboardUpdate("captured", changeCount: 42)

        XCTAssertEqual(viewModel.bufferText, "captured")
        XCTAssertEqual(viewModel.characterCount, 8)
        XCTAssertEqual(viewModel.statusMessage?.text, "Clipboard captured automatically (8 characters).")
    }

    func testAutoCaptureSkipsWhenBufferHasUserEdits() {
        let viewModel = makeViewModel()
        viewModel.autoCapture = true
        viewModel.bufferText = "local draft"
        viewModel.userEditedBuffer()

        viewModel.handleClipboardUpdate("incoming", changeCount: 7)

        XCTAssertEqual(viewModel.bufferText, "local draft")
        XCTAssertEqual(viewModel.statusMessage?.text, "Ignored clipboard change to avoid overwriting your edits. Capture manually when ready.")
    }

    func testTypeBufferUsesAppendReturnAndDelay() async {
        let typingEngine = TypingEngineMock()
        let viewModel = makeViewModel(typingEngine: typingEngine, trusted: true)
        viewModel.bufferText = "abc"
        viewModel.userEditedBuffer()
        viewModel.countdownSeconds = 0
        viewModel.perCharacterDelay = 0.08
        viewModel.appendReturn = true

        viewModel.typeBuffer()
        let finishedTyping = await waitUntil { !viewModel.isTyping }
        XCTAssertTrue(finishedTyping)

        XCTAssertEqual(typingEngine.invocations.count, 1)
        XCTAssertEqual(typingEngine.invocations[0].text, "abc")
        XCTAssertEqual(typingEngine.invocations[0].appendReturn, true)
        XCTAssertEqual(typingEngine.invocations[0].characterDelay, 0.08, accuracy: 0.000_001)
        XCTAssertEqual(viewModel.statusMessage?.text, "Typed 4 characters successfully.")
    }

    func testCancelTypingDuringCountdownStopsBeforeEngineRuns() async {
        let typingEngine = TypingEngineMock()
        let viewModel = makeViewModel(
            typingEngine: typingEngine,
            trusted: true,
            countdownTickNanoseconds: 500_000_000
        )
        viewModel.bufferText = "abc"
        viewModel.userEditedBuffer()
        viewModel.countdownSeconds = 3

        viewModel.typeBuffer()
        try? await Task.sleep(nanoseconds: 20_000_000)
        viewModel.cancelTyping()
        let cancelled = await waitUntil { !viewModel.isTyping }
        XCTAssertTrue(cancelled)

        XCTAssertEqual(typingEngine.invocations.count, 0)
        XCTAssertEqual(viewModel.statusMessage?.text, "Typing cancelled.")
    }

    private func makeViewModel(
        typingEngine: TypingEngineMock = TypingEngineMock(),
        trusted: Bool = true,
        watcher: ClipboardWatcherMock = ClipboardWatcherMock(),
        countdownTickNanoseconds: UInt64 = 1_000_000
    ) -> ClipboardViewModel {
        ClipboardViewModel(
            typingEngine: typingEngine,
            accessibilityManager: AccessibilityManagerMock(trusted: trusted),
            relauncher: RelauncherMock(),
            pasteboard: PasteboardMock(),
            clipboardWatcher: watcher,
            countdownTickNanoseconds: countdownTickNanoseconds
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        pollNanoseconds: UInt64 = 10_000_000,
        condition: @escaping () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        return condition()
    }
}

@MainActor
private final class TypingEngineMock: TypingEngineProtocol {
    struct Invocation {
        let text: String
        let characterDelay: Double
        let appendReturn: Bool
    }

    private(set) var invocations: [Invocation] = []

    func type(text: String, characterDelay: Double, appendReturn: Bool) async throws {
        invocations.append(Invocation(text: text, characterDelay: characterDelay, appendReturn: appendReturn))
    }
}

@MainActor
private final class AccessibilityManagerMock: AccessibilityPermissionManaging {
    private let trusted: Bool

    init(trusted: Bool) {
        self.trusted = trusted
    }

    func isTrusted() -> Bool {
        trusted
    }

    func promptForAccess() {}
}

@MainActor
private struct RelauncherMock: AppRelaunching {
    func restart() throws {}
}

private struct PasteboardMock: PasteboardProviding {
    let changeCount: Int = 0

    func string(forType dataType: NSPasteboard.PasteboardType) -> String? {
        nil
    }
}

@MainActor
private final class ClipboardWatcherMock: ClipboardWatching {
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    func start() {
        startCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }

    func sync(changeCount: Int) {}
}
