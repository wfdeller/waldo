// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Waldo",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "waldo",
            targets: ["Waldo"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Waldo",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]),
        .testTarget(
            name: "WaldoTests",
            dependencies: ["Waldo"],
            path: "Tests/WaldoTests")
    ]
)