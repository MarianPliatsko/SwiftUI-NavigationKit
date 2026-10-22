// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IOSNavigationKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "IOSNavigationKit", targets: ["IOSNavigationKit"])],
    targets: [
        .target(name: "IOSNavigationKit"),
        .target(name: "IOSNavigationKitExamples", dependencies: ["IOSNavigationKit"], path: "Examples"),
        .testTarget(name: "IOSNavigationKitTests", dependencies: ["IOSNavigationKit"])
    ],
    swiftLanguageModes: [.v6]
)
