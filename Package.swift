// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HallPass",
    platforms: [.macOS("15.5")],
    products: [.executable(name: "HallPass", targets: ["HallPass"])],
    targets: [
        .target(name: "HallPassCore"),
        .executableTarget(name: "HallPass", dependencies: ["HallPassCore"]),
        .testTarget(name: "HallPassCoreTests", dependencies: ["HallPassCore"])
    ]
)
