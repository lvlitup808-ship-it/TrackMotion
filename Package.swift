// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TrackMotion",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "TrackMotion", targets: ["TrackMotion"])
    ],
    dependencies: [
        // Swift Numerics for biomechanical calculations
        .package(
            url: "https://github.com/apple/swift-numerics",
            from: "1.0.2"
        ),
        // Swift Algorithms for data processing
        .package(
            url: "https://github.com/apple/swift-algorithms",
            from: "1.2.0"
        )
    ],
    targets: [
        .target(
            name: "TrackMotion",
            dependencies: [
                .product(name: "RealModule", package: "swift-numerics"),
                .product(name: "Algorithms", package: "swift-algorithms")
            ],
            path: "TrackMotion"
        )
    ]
)
