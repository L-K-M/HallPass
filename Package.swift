// swift-tools-version: 6.0
import PackageDescription

var products: [Product] = []
var targets: [Target] = [
    .target(name: "HallPassCore"),
    .testTarget(name: "HallPassCoreTests", dependencies: ["HallPassCore"])
]

// Keep format and editing tests runnable without the Mac UI frameworks.
#if os(macOS)
products.append(.executable(name: "HallPass", targets: ["HallPass"]))
targets.append(.executableTarget(name: "HallPass", dependencies: ["HallPassCore"]))
targets.append(.testTarget(name: "HallPassTests", dependencies: ["HallPass"]))
#endif

let package = Package(
    name: "HallPass",
    platforms: [.macOS("26.0")],
    products: products,
    targets: targets
)
