import AppKit
import Foundation
import SwiftUI

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
    @Published var autoCapture: Bool = true {
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

    private let typingEngine = TypingEngine()
    private let accessibilityManager = AccessibilityPermissionManager()
    private let relauncher = AppRelauncher()
    private var clipboardWatcher: ClipboardWatcher?
    private var lastCapturedChangeCount: Int
    private var isProgrammaticBufferMutation = false

    init() {
        lastCapturedChangeCount = NSPasteboard.general.changeCount
        clipboardWatcher = ClipboardWatcher { [weak self] string, changeCount in
            Task { @MainActor in
                self?.handleClipboardUpdate(string, changeCount: changeCount)
            }
        }

        refreshAccessibilityStatus()
        captureClipboard(silent: true)
        if autoCapture {
            startClipboardMonitoring()
        }
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

        Task { [weak self] in
            guard let self else { return }

            if countdown > 0 {
                for remaining in stride(from: countdown, to: 0, by: -1) {
                    self.statusMessage = StatusMessage(text: "Typing in \(remaining == 1 ? "1 second" : "\(remaining) seconds")…", style: .info)
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }

            do {
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

            self.isTyping = false
        }
    }

    private func captureClipboard(silent: Bool) {
        let pasteboard = NSPasteboard.general

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

    private func handleClipboardUpdate(_ string: String, changeCount: Int) {
        lastCapturedChangeCount = changeCount
        clipboardWatcher?.sync(changeCount: changeCount)

        guard autoCapture else {
            statusMessage = StatusMessage(
                text: "Clipboard changed (\(string.count) characters). Auto-capture is off.",
                style: .info
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
