// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GridGrip",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "GridGrip", targets: ["GridGrip"]),
        .library(name: "WindowCore", targets: ["WindowCore"]),
    ],
    targets: [
        .target(name: "WindowCore"),
        .executableTarget(name: "GridGrip", dependencies: ["WindowCore"]),
        .testTarget(name: "WindowCoreTests", dependencies: ["WindowCore"]),
    ]
)
