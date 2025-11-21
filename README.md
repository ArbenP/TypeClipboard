# TypeClipboard

![TypeClipboard screenshot](./Screenshot.png)

TypeClipboard is a SwiftUI macOS utility that replays whatever is in your clipboard as live keyboard input. It is built for remote sessions (VNC, RDP, virtual consoles, kiosks) where paste is blocked but you still need to enter long secrets accurately.

## Features
- Capture clipboard contents into an editable buffer
- Adjustable countdown so you can focus the target window before typing begins
- Per-character delay plus optional trailing Return key press
- Inline guidance for macOS Accessibility permission (required to synthesize keystrokes)
- Status banners, manual capture, and cancel-in-progress typing (Esc)
- Optional auto-capture of clipboard changes (off by default to avoid surprises)

## Download
- Get the latest prebuilt `.app` from the [Releases page](https://github.com/ArbenP/TypeClipboard/releases).


## First Run / Permissions
TypeClipboard needs macOS Accessibility permission to generate keystrokes:
1. Launch the app and click **Open Settings** in the banner.  
2. In *Privacy & Security ▸ Accessibility*, enable TypeClipboard.  
3. Click **Restart App** to reload with the permission applied.  
If permission is missing, typing will be blocked and you’ll see an error banner.

## Usage
- **Capture**: Click *Capture Clipboard* (⇧⌘V) to pull the current clipboard into the buffer.  
- **Edit**: Review or edit text in the buffer; metrics update live.  
- **Type**: Click *Type Now* to send the buffer as keystrokes. Use countdown and delay controls to match the target app’s latency.  
- **Cancel**: Press Esc or hit *Cancel Typing* while the countdown/typing is in progress.  
- **Automation**: Turn on *Update buffer when the clipboard changes* only if you want automatic capture; it’s off by default to avoid overwriting edits.  
- **Return key**: Toggle *Press Return after typing* if your workflow expects a trailing Enter.

## Requirements
- macOS 13 or newer
- Accessibility permission enabled for TypeClipboard

## Build From Source
Requires Swift 5.9+.

CLI build/run:
```bash
swift build
swift run TypeClipboardApp
```

Optimized binary:
```bash
swift build -c release
```
Binary is at `.build/release/TypeClipboardApp`.

## Build a `.app`
- Quick script (ad-hoc signed, embeds Swift runtime):
```bash
./scripts/build-app-bundle.sh
```
Output: `dist/TypeClipboard.app`.

- Xcode path: see `GUIDE.md` for step-by-step instructions to build the `.app` from Xcode (no Developer ID required for local use).

## Tests
```bash
swift test
```

## Troubleshooting
- **Nothing types**: Accessibility permission not granted or the target field rejects synthetic input (some secure fields do).  
- **Buffer changed while editing**: Leave auto-capture off, or recapture manually.  
- **Too fast/slow**: Adjust the per-character delay slider (0–250 ms) and/or countdown.  
- **Blocked at launch**: Right-click the app → Open to bypass Gatekeeper for ad-hoc builds.
