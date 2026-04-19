// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SceneCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SceneCore", targets: ["SceneCore"]),
    ],
    targets: [
        .target(
            name: "SceneCore",
            path: "Sources/SceneCore"
        ),
        .testTarget(
            name: "SceneCoreTests",
            dependencies: ["SceneCore"],
            path: "Tests/SceneCoreTests"
        ),
    ]
)
