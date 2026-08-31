// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Vellbar",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure model and layout logic — no AppKit, no window-list calls — so
        // the ordering and hiding rules are testable without a menu bar.
        .target(name: "VellbarCore"),
        .executableTarget(name: "Vellbar", dependencies: ["VellbarCore"]),
        .testTarget(name: "VellbarCoreTests", dependencies: ["VellbarCore"]),
    ]
)
