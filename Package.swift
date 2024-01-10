// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "Shout",
    products: [
        .library(name: "Shout", targets: ["Shout"]),
    ],
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/BlueSocket", from: "2.0.0"),
        .package(url: "https://github.com/DimaRU/Libssh2Prebuild.git", exact: "1.11.0-OpenSSL-1-1-1w")
    ],
    targets: [
        .target(name: "Shout", dependencies: [
            .product(name: "Socket", package: "BlueSocket"),
            .product(name: "CSSH", package: "Libssh2Prebuild")
        ]),
        .testTarget(name: "ShoutTests", dependencies: ["Shout"]),
    ]
)
