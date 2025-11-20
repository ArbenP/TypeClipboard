import SwiftUI

@main
struct TypeClipboardApp: App {
    @StateObject private var viewModel = ClipboardViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 520, idealWidth: 560, minHeight: 420, idealHeight: 470)
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
