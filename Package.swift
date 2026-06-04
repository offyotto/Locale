// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocaleApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LocaleApp", targets: ["LocaleApp"])
    ],
    targets: [
        .executableTarget(
            name: "LocaleApp",
            path: "Sources/LocaleApp",
            swiftSettings: [
                .unsafeFlags(["-Osize"], .when(configuration: .release))
            ]
        )
    ]
)
