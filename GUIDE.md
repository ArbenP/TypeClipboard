# Building TypeClipboard.app with Xcode

These steps produce a local `.app` bundle directly from Xcode without requiring a Developer ID or Mac App Store signing.

## Prerequisites
- macOS 13+
- Xcode 15 or newer (includes the Swift toolchain)

## Steps
1. Open Xcode and choose **File ▸ Open…**, then select `Package.swift` from this repository. Trust the package if prompted.
2. In the toolbar, pick the `TypeClipboardApp` scheme and the `My Mac` destination.
3. (Optional) In **Signing & Capabilities**, set **Team** to *None* and **Signing Certificate** to *Sign to Run Locally*. Xcode will handle the ad-hoc signature needed to launch the app on your machine.
4. Choose **Product ▸ Scheme ▸ Edit Scheme…** and set *Build configuration* to `Release` for the *Run* action if you want an optimized build.
5. Build the app with **Product ▸ Build** (⌘B).
6. Reveal the output via **Product ▸ Show Build Folder in Finder**. The compiled bundle lives at `Build/Products/Release/TypeClipboardApp.app` (or `Debug` if you left the default configuration).
7. Run the app from that location, or compress the `.app` if you want to share it outside of Xcode. For wider distribution, you can also use `scripts/build-app-bundle.sh` to embed the Swift runtime and ad-hoc sign in one step.
