// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TallyUI",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "TallyUI", targets: ["TallyUI"]),
    ],
    dependencies: [
        .package(path: "../TallyCore"),
    ],
    targets: [
        .target(
            name: "TallyUI",
            dependencies: ["TallyCore"],
            // Xcode compiles the Metal source into the module's default.metallib.
            resources: [.process("Shaders")]
        ),
    ]
)
