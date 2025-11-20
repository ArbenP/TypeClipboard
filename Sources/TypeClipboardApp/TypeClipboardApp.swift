import SwiftUI
import AppKit

@main
struct TypeClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = ClipboardViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .pasteboard) {
                Button("Capture Clipboard", action: viewModel.captureClipboard)
                    .keyboardShortcut("v", modifiers: [.command, .shift])
            }
        }
    }
}
