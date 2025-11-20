import AppKit
import Foundation

enum AppRelauncherError: LocalizedError {
    case executableUnavailable
    case relaunchFailed

    var errorDescription: String? {
        switch self {
        case .executableUnavailable:
            return "Could not determine the app executable to relaunch."
        case .relaunchFailed:
            return "Failed to restart TypeClipboard automatically. Quit and reopen it manually."
        }
    }
}

struct AppRelauncher {
    func restart() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())

        let bundleURL = Bundle.main.bundleURL
        if bundleURL.pathExtension == "app" {
            try launchUsingOpen(bundlePath: bundleURL.path)
        } else if let executableURL = Bundle.main.executableURL {
            try launchExecutable(at: executableURL, arguments: arguments)
        } else {
            throw AppRelauncherError.executableUnavailable
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.terminate(nil)
        }
    }

    private func launchUsingOpen(bundlePath: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [bundlePath]
        try process.run()
    }

    private func launchExecutable(at url: URL, arguments: [String]) throws {
        let process = Process()
        process.executableURL = url
        process.arguments = arguments
        do {
            try process.run()
        } catch {
            throw AppRelauncherError.relaunchFailed
        }
    }
}
