// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Strata",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "StrataLib",
            dependencies: ["SwiftTerm"],
            path: "Sources/StrataLib"
        ),
        .executableTarget(
            name: "Strata",
            dependencies: ["StrataLib"],
            path: "Sources/Strata"
        ),
        .testTarget(
            name: "StrataTests",
            dependencies: ["StrataLib"],
            path: "Tests/StrataTests"
        )
    ]
)
