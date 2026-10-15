// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TallyIntelligence",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "TallyIntelligence", targets: ["TallyIntelligence"]),
    ],
    dependencies: [
        .package(path: "../TallyCore"),
    ],
    targets: [
        .target(name: "TallyIntelligence", dependencies: ["TallyCore"]),
        .testTarget(name: "TallyIntelligenceTests", dependencies: ["TallyIntelligence"]),
    ]
)
