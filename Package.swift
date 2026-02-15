// swift-tools-version: 6.2
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
            name: "TypeClipboardApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "TypeClipboardAppTests",
            dependencies: ["TypeClipboardApp"]
        )
    ]
)
