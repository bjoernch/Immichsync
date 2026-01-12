// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ImmichSync",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "ImmichSync",
            targets: ["ImmichSync"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ImmichSync",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
