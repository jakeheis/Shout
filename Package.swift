// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "Shout",
    products: [
        .library(name: "Shout", targets: ["Shout"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jakeheis/CSSH", from: "1.0.3"),
        .package(url: "https://github.com/IBM-Swift/BlueSocket", from: "0.12.68")
    ],
    targets: [
        .target(name: "Shout", dependencies: ["Socket"])
    ]
)
