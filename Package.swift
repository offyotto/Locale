// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocaleApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LocaleApp", targets: ["LocaleApp"]),
        .executable(name: "LocaleHelper", targets: ["LocaleHelper"])
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
                .linkedFramework("ServiceManagement")
            ]
        ),
        .executableTarget(
            name: "LocaleHelper",
            dependencies: ["LocaleShared"],
            path: "Sources/LocaleHelper",
            swiftSettings: [
                .unsafeFlags(["-Osize"], .when(configuration: .release))
            ]
        )
    ]
)
