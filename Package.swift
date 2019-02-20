// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "Shout",
    products: [
        .library(name: "Shout", targets: ["Shout"]),
    ],
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/BlueSocket", from: "0.12.68"),
    ],
    targets: [
        .systemLibrary(name: "CSSH", pkgConfig: "libssh2"),
        .target(name: "Bindings", dependencies: ["Socket", "CSSH"]),
        .target(name: "Shout", dependencies: ["Bindings", "Socket"]),
        .testTarget(name: "ShoutTests", dependencies: ["Shout"]),
    ]
)
