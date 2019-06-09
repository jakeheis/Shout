// swift-tools-version:4.0
// Managed by ice

import PackageDescription

let package = Package(
    name: "Shout",
    products: [
        .library(name: "Shout", targets: ["Shout"]),
    ],
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/BlueSocket", from: "1.0.0"),
        .package(url: "https://github.com/jakeheis/CSSH", from: "1.0.3"),
    ],
    targets: [
        .target(name: "Shout", dependencies: ["Socket"]),
        .testTarget(name: "ShoutTests", dependencies: ["Shout"]),
    ]
)
