// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HealthMonitorCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "HealthMonitorCore", targets: ["HealthMonitorCore"])
    ],
    targets: [
        .target(name: "HealthMonitorCore"),
        .testTarget(name: "HealthMonitorCoreTests", dependencies: ["HealthMonitorCore"])
    ]
)
