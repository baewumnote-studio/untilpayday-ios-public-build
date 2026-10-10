// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UntilPaydayCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "UntilPaydayCore", targets: ["UntilPaydayCore"])
    ],
    targets: [
        .target(name: "UntilPaydayCore"),
        .testTarget(name: "UntilPaydayCoreTests", dependencies: ["UntilPaydayCore"])
    ]
)
