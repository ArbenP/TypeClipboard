import AppKit
import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    let minimumSize: CGSize
    let preferredSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configureIfPossible(context: context, hostingView: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureIfPossible(context: context, hostingView: nsView)
        }
    }

    private func configureIfPossible(context: Context, hostingView: NSView) {
        guard let window = hostingView.window else { return }

        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: minimumSize.width, height: minimumSize.height)

        if !context.coordinator.appliedPreferredSize {
            let currentSize = window.contentLayoutRect.size
            let targetWidth = max(currentSize.width, preferredSize.width)
            let targetHeight = max(currentSize.height, preferredSize.height)
            let targetSize = NSSize(width: targetWidth, height: targetHeight)
            window.setContentSize(targetSize)
            context.coordinator.appliedPreferredSize = true
        }
    }

    final class Coordinator {
        var appliedPreferredSize = false
    }
}
