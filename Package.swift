// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "SSH",
    dependencies: [
        .Package(url: "https://github.com/jakeheis/CSSH", majorVersion: 1),
        .Package(url: "https://github.com/IBM-Swift/BlueSocket", majorVersion: 0)
    ]
)
