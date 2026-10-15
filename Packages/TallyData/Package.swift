// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TallyData",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "TallyData", targets: ["TallyData"]),
    ],
    dependencies: [
        .package(path: "../TallyCore"),
    ],
    targets: [
        .target(name: "TallyData", dependencies: ["TallyCore"]),
        .testTarget(name: "TallyDataTests", dependencies: ["TallyData"]),
    ]
)
