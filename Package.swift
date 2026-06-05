// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocaleApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LocaleApp", targets: ["LocaleApp"]),
        .executable(name: "LocaleDNSProxy", targets: ["LocaleDNSProxy"])
    ],
    targets: [
        .target(
            name: "LocaleShared",
            path: "Sources/LocaleShared"
        ),
        .executableTarget(
            name: "LocaleApp",
            dependencies: ["LocaleShared"],
            path: "Sources/LocaleApp",
            swiftSettings: [
                .unsafeFlags(["-Osize"], .when(configuration: .release))
            ],
            linkerSettings: [
                .linkedFramework("NetworkExtension"),
                .linkedFramework("SystemExtensions")
            ]
        ),
        .executableTarget(
            name: "LocaleDNSProxy",
            dependencies: ["LocaleShared"],
            path: "Sources/LocaleDNSProxy",
            swiftSettings: [
                .unsafeFlags(["-Osize"], .when(configuration: .release))
            ],
            linkerSettings: [
                .linkedFramework("NetworkExtension")
            ]
        ),
        .testTarget(
            name: "LocaleSharedTests",
            dependencies: ["LocaleShared"],
            path: "Tests/LocaleSharedTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
