# TypeClipboard

TypeClipboard is a modern SwiftUI macOS utility that replays the contents of your clipboard as keyboard input. It is ideal for remote sessions (VNC, RDP, virtual consoles, etc.) where traditional paste is disabled but you still need to enter long secrets accurately.

## Highlights
- Live clipboard capture with a dedicated buffer you can review or edit.
- Adjustable countdown so you can focus the remote window before typing begins.
- Configurable character cadence and optional trailing `Return` key press.
- Friendly status banners and quick actions for clearing or re-capturing the clipboard.
- Inline guidance for granting the macOS Accessibility permission required to synthesize keystrokes.

## Getting Started
```bash
swift build
swift run TypeClipboardApp
```

When the window appears, hit **Capture Clipboard** (⇧⌘V) or enable *Update buffer when the clipboard changes* to keep the buffer in sync. The **Type Now** button respects your countdown and per-character delay settings so you have time to activate the destination app.

> **Note:** The first time you attempt to type, macOS will require Accessibility access. Use the built-in **Open Settings** button, add TypeClipboard to the list, then return and click **Refresh Status**.

## Project Layout
- `Sources/TypeClipboardApp/TypeClipboardApp.swift` – SwiftUI `App` entry point and command menu.
- `Sources/TypeClipboardApp/ContentView.swift` – Main interface, settings, and status banners.
- `Sources/TypeClipboardApp/ClipboardViewModel.swift` – Clipboard state management, countdown flow, and typing orchestration.
- `Sources/TypeClipboardApp/TypingEngine.swift` – Low-level `CGEvent` keyboard synthesis.
- `Sources/TypeClipboardApp/ClipboardWatcher.swift` – Polls `NSPasteboard` for changes.
- `Sources/TypeClipboardApp/AccessibilityPermissionManager.swift` – Wraps the Accessibility permission prompts.
- `Sources/TypeClipboardApp/AppDelegate.swift` – Configures the dock presence, menus, and app icon.
- `Sources/TypeClipboardApp/Resources/AppIcon.icns` – Default app icon packaged into the release-ready bundle.
- `Packaging/Info.plist` – Plist template used when assembling the `.app` bundle.
- `scripts/build-app-bundle.sh` – Utility script that produces a signed `.app` bundle in `dist/`.

## Building a Release Binary
```bash
swift build -c release
```
The compiled binary is located at `.build/release/TypeClipboardApp`. You can launch it directly, or bundle it with a minimal `.app` wrapper using Xcode if you prefer dock integration.

## Troubleshooting
- **Nothing types when I press Type Now** – Ensure Accessibility permission is granted and the target window is active. Some secure fields (e.g., macOS login) block synthetic input.
- **Buffer keeps changing while I edit** – Disable the *Update buffer when the clipboard changes* toggle; auto-capture only overwrites the buffer when there are no manual edits pending.
- **Characters type too fast/slow** – Adjust the per-character delay slider (0–250 ms).

## Packaging a Standalone `.app`
1. Optionally set environment variables to control the version strings:
   ```bash
   export VERSION=1.0.0
   export BUILD=5
   ```
2. Run the bundling script:
   ```bash
   ./scripts/build-app-bundle.sh
   ```
   This script builds the release binary, assembles `dist/TypeClipboard.app`, embeds the Swift runtime, and applies an ad-hoc signature.
3. Replace `com.example.typeclipboard` inside `Packaging/Info.plist` if you need a bespoke bundle identifier before notarisation.
4. For public distribution, re-sign with your Developer ID certificate and notarise:
   ```bash
   codesign --force --deep --sign "Developer ID Application: YOUR NAME" dist/TypeClipboard.app
   xcrun notarytool submit dist/TypeClipboard.app --keychain-profile YOUR_PROFILE --wait
   ```
