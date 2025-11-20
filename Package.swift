// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TypeClipboardApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "TypeClipboardApp",
            targets: ["TypeClipboardApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "TypeClipboardApp"
        )
    ]
)
