// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TallyCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "TallyCore", targets: ["TallyCore"]),
    ],
    targets: [
        .target(name: "TallyCore"),
        .testTarget(name: "TallyCoreTests", dependencies: ["TallyCore"]),
    ]
)
