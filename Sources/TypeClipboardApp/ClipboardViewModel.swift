import AppKit
import Foundation
import SwiftUI

@MainActor
protocol TypingEngineProtocol {
    func type(text: String, characterDelay: Double, appendReturn: Bool) async throws
}

extension TypingEngine: TypingEngineProtocol {}

@MainActor
protocol AccessibilityPermissionManaging {
    func isTrusted() -> Bool
    func promptForAccess()
}

extension AccessibilityPermissionManager: AccessibilityPermissionManaging {}

@MainActor
protocol AppRelaunching {
    func restart() throws
}

extension AppRelauncher: AppRelaunching {}

@MainActor
protocol ClipboardWatching: AnyObject {
    func start()
    func stop()
    func sync(changeCount: Int)
}

extension ClipboardWatcher: ClipboardWatching {}

protocol PasteboardProviding {
    var changeCount: Int { get }
    func string(forType dataType: NSPasteboard.PasteboardType) -> String?
}

struct SystemPasteboard: PasteboardProviding {
    private let pasteboard: NSPasteboard

    init(_ pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int {
        pasteboard.changeCount
    }

    func string(forType dataType: NSPasteboard.PasteboardType) -> String? {
        pasteboard.string(forType: dataType)
    }
}

@MainActor
final class ClipboardViewModel: ObservableObject {
    enum CaptureOrigin {
        case bootstrapped
        case manual
        case automatic
    }

    struct StatusMessage: Identifiable {
        enum Style {
            case info
            case success
            case warning
            case error
        }

        let id = UUID()
        let text: String
        let style: Style
    }

    @Published var bufferText: String = ""
    @Published private(set) var previewDescription: String = "Buffer empty"
    @Published private(set) var characterCount: Int = 0
    @Published private(set) var lineCount: Int = 0
    @Published var autoCapture: Bool = false {
        didSet { autoCapture ? startClipboardMonitoring() : stopClipboardMonitoring() }
    }
    @Published var appendReturn: Bool = true
    @Published var countdownSeconds: Int = 2 {
        didSet {
            if countdownSeconds < 0 { countdownSeconds = 0 }
            if countdownSeconds > 10 { countdownSeconds = 10 }
        }
    }
    @Published var perCharacterDelay: Double = 0.035 {
        didSet {
            if perCharacterDelay < 0 { perCharacterDelay = 0 }
            if perCharacterDelay > 0.25 { perCharacterDelay = 0.25 }
        }
    }
    @Published private(set) var isTyping: Bool = false
    @Published var statusMessage: StatusMessage?
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var isAccessibilityTrusted: Bool = false

    let characterDelayRange = 0.0...0.25
    let countdownRange = 0...10

    var typingButtonDisabled: Bool {
        bufferText.isEmpty || isTyping
    }

    var delayDescription: String {
        "\(Int(perCharacterDelay * 1_000)) ms"
    }

    var countdownDescription: String {
        countdownSeconds == 1 ? "1 second" : "\(countdownSeconds) seconds"
    }

    private let typingEngine: any TypingEngineProtocol
    private let accessibilityManager: any AccessibilityPermissionManaging
    private let relauncher: any AppRelaunching
    private let pasteboard: any PasteboardProviding
    private let countdownTickNanoseconds: UInt64
    private var clipboardWatcher: (any ClipboardWatching)?
    private var lastCapturedChangeCount: Int
    private var isProgrammaticBufferMutation = false
    private var userHasEditedBuffer = false
    private var typingTask: Task<Void, Never>?

    init(
        typingEngine: any TypingEngineProtocol = TypingEngine(),
        accessibilityManager: any AccessibilityPermissionManaging = AccessibilityPermissionManager(),
        relauncher: any AppRelaunching = AppRelauncher(),
        pasteboard: any PasteboardProviding = SystemPasteboard(),
        clipboardWatcher: (any ClipboardWatching)? = nil,
        countdownTickNanoseconds: UInt64 = 1_000_000_000
    ) {
        self.typingEngine = typingEngine
        self.accessibilityManager = accessibilityManager
        self.relauncher = relauncher
        self.pasteboard = pasteboard
        self.countdownTickNanoseconds = countdownTickNanoseconds
        lastCapturedChangeCount = pasteboard.changeCount
        self.clipboardWatcher = clipboardWatcher ?? ClipboardWatcher { [weak self] string, changeCount in
            Task { @MainActor in
                self?.handleClipboardUpdate(string, changeCount: changeCount)
            }
        }

        refreshAccessibilityStatus()
    }

    func captureClipboard() {
        captureClipboard(silent: false)
    }

    func clearBuffer() {
        applyBuffer("", origin: .manual)
        statusMessage = StatusMessage(text: "Cleared the buffer.", style: .info)
    }

    func userEditedBuffer() {
        guard !isProgrammaticBufferMutation else { return }
        userHasEditedBuffer = true
        lastUpdatedAt = Date()
        recalculateBufferMetrics()
    }

    func refreshAccessibilityStatus() {
        isAccessibilityTrusted = accessibilityManager.isTrusted()
    }

    func requestAccessibilityAccess() {
        accessibilityManager.promptForAccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            Task { @MainActor in
                self?.refreshAccessibilityStatus()
            }
        }
    }

    func restartApplicationForAccessibility() {
        statusMessage = StatusMessage(
            text: "Restarting TypeClipboard to apply new accessibility permissions…",
            style: .info
        )
        do {
            try relauncher.restart()
        } catch let error as AppRelauncherError {
            statusMessage = StatusMessage(text: error.localizedDescription, style: .error)
        } catch {
            statusMessage = StatusMessage(text: error.localizedDescription, style: .error)
        }
    }

    func typeBuffer() {
        refreshAccessibilityStatus()

        guard !bufferText.isEmpty else {
            statusMessage = StatusMessage(text: "The buffer is empty. Capture the clipboard or type something first.", style: .warning)
            return
        }

        guard isAccessibilityTrusted else {
            statusMessage = StatusMessage(text: "Accessibility is disabled. Enable it to let TypeClipboard simulate keystrokes.", style: .error)
            return
        }

        guard !isTyping else { return }

        let text = bufferText
        let delay = perCharacterDelay
        let appendReturn = self.appendReturn
        let countdown = countdownSeconds

        isTyping = true
        if countdown > 0 {
            statusMessage = StatusMessage(text: "Switch to the target window. Typing in \(countdownDescription)…", style: .info)
        } else {
            statusMessage = StatusMessage(text: "Typing now…", style: .info)
        }

        typingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isTyping = false
                self.typingTask = nil
            }

            do {
                if countdown > 0 {
                    for remaining in stride(from: countdown, to: 0, by: -1) {
                        try Task.checkCancellation()
                        self.statusMessage = StatusMessage(text: "Typing in \(remaining == 1 ? "1 second" : "\(remaining) seconds")…", style: .info)
                        try await Task.sleep(nanoseconds: self.countdownTickNanoseconds)
                    }
                }

                try Task.checkCancellation()
                try await self.typingEngine.type(text: text, characterDelay: delay, appendReturn: appendReturn)
                let appended = appendReturn ? 1 : 0
                self.statusMessage = StatusMessage(
                    text: "Typed \(text.count + appended) characters successfully.",
                    style: .success
                )
            } catch is CancellationError {
                self.statusMessage = StatusMessage(text: "Typing cancelled.", style: .info)
            } catch let error as TypingEngineError {
                self.statusMessage = StatusMessage(text: error.localizedDescription, style: .error)
            } catch {
                self.statusMessage = StatusMessage(text: error.localizedDescription, style: .error)
            }
        }
    }

    func cancelTyping() {
        guard isTyping else { return }
        typingTask?.cancel()
    }

    private func captureClipboard(silent: Bool) {
        guard let string = pasteboard.string(forType: .string), !string.isEmpty else {
            if !silent {
                statusMessage = StatusMessage(text: "The clipboard does not contain plain text.", style: .warning)
            }
            return
        }

        lastCapturedChangeCount = pasteboard.changeCount
        clipboardWatcher?.sync(changeCount: lastCapturedChangeCount)
        applyBuffer(string, origin: silent ? .bootstrapped : .manual)

        if !silent {
            statusMessage = StatusMessage(text: "Captured \(string.count) characters from the clipboard.", style: .success)
        }
    }

    func handleClipboardUpdate(_ string: String, changeCount: Int) {
        lastCapturedChangeCount = changeCount
        clipboardWatcher?.sync(changeCount: changeCount)

        guard autoCapture else {
            statusMessage = StatusMessage(
                text: "Clipboard changed (\(string.count) characters). Auto-capture is off.",
                style: .info
            )
            return
        }

        if userHasEditedBuffer {
            statusMessage = StatusMessage(
                text: "Ignored clipboard change to avoid overwriting your edits. Capture manually when ready.",
                style: .warning
            )
            return
        }

        applyBuffer(string, origin: .automatic)
        statusMessage = StatusMessage(
            text: "Clipboard captured automatically (\(string.count) characters).",
            style: .info
        )
    }

    private func applyBuffer(_ text: String, origin: CaptureOrigin) {
        isProgrammaticBufferMutation = true
        bufferText = text
        isProgrammaticBufferMutation = false
        userHasEditedBuffer = false
        lastUpdatedAt = Date()
        recalculateBufferMetrics()
    }

    private func recalculateBufferMetrics() {
        characterCount = bufferText.count
        lineCount = bufferText.isEmpty ? 0 : bufferText.components(separatedBy: .newlines).count
        previewDescription = makePreview(from: bufferText)
    }

    private func startClipboardMonitoring() {
        clipboardWatcher?.start()
    }

    private func stopClipboardMonitoring() {
        clipboardWatcher?.stop()
    }

    private func makePreview(from text: String) -> String {
        guard !text.isEmpty else { return "Buffer empty" }

        let sanitized = text
            .replacingOccurrences(of: "\n", with: "⏎")
            .replacingOccurrences(of: "\t", with: "⇥")

        let snippet: String
        if sanitized.count <= 32 {
            snippet = sanitized
        } else {
            let start = sanitized.prefix(14)
            let end = sanitized.suffix(14)
            snippet = "\(start)…\(end)"
        }

        let suffix = characterCount == 1 ? "character" : "characters"
        return "\(snippet) (\(characterCount) \(suffix))"
    }
}
