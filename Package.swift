// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "speak-low", platforms: [.macOS(.v14)],
    products: [.executable(name: "speak-low", targets: ["SpeakLow"])],
    dependencies: [.package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", exact: "1.1.1")],
    targets: [
        .executableTarget(name: "SpeakLow", dependencies: [.product(name: "WhisperKit", package: "argmax-oss-swift")])
    ]
)
