// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MicophoneCore",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [.library(name: "MicophoneCore", targets: ["MicophoneCore"])],
    targets: [
        .target(name: "MicophoneCore", path: "Micophone-iOS/Core"),
        .testTarget(name: "MicophoneCoreTests", dependencies: ["MicophoneCore"],
                    path: "Tests/Core", resources: [.copy("Fixtures")])
    ]
)
