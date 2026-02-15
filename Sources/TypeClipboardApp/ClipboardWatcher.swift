import AppKit
import Foundation

@MainActor
final class ClipboardWatcher: NSObject {
    typealias Handler = (_ string: String, _ changeCount: Int) -> Void

    private let interval: TimeInterval
    private let handler: Handler
    private var timer: Timer?
    private var lastChangeCount: Int

    init(interval: TimeInterval = 0.5, handler: @escaping Handler) {
        self.interval = interval
        self.handler = handler
        let pasteboard = NSPasteboard.general
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        let scheduledTimer = Timer(
            timeInterval: interval,
            target: self,
            selector: #selector(handleTimerFired),
            userInfo: nil,
            repeats: true
        )
        timer = scheduledTimer
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func sync(changeCount: Int) {
        lastChangeCount = changeCount
    }

    @objc private func handleTimerFired() {
        checkPasteboard()
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let string = pasteboard.string(forType: .string) else { return }
        handler(string, lastChangeCount)
    }
}
