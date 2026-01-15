// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Voxa",
    platforms: [
        .macOS(.v14)  // WhisperKit requires macOS 14.0+
    ],
    products: [
        .executable(name: "Voxa", targets: ["Voxa"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
        .package(url: "https://github.com/mattt/llama.swift.git", .upToNextMajor(from: "2.7721.0"))
    ],
    targets: [
        .executableTarget(
            name: "Voxa",
            dependencies: [
                "WhisperKit",
                .product(name: "LlamaSwift", package: "llama.swift")
            ],
            path: "Sources/Voxa"
        )
        // Note: Tests require full Xcode installation (not just Command Line Tools)
        // Tests can be added when building with Xcode IDE
    ]
)
