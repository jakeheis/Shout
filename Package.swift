// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "Slush",
    dependencies: [
        .Package(url: "https://github.com/jakeheis/CSSH", majorVersion: 1)
    ]
)
