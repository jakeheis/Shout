// swift-tools-version:3.1

import PackageDescription

// Compile with: swift build -Xlinker -lssh2 -Xlinker -L/usr/local/lib/

let package = Package(
    name: "Slush",
    dependencies: [
        .Package(url: "https://github.com/jakeheis/CSSH", majorVersion: 1),
        .Package(url: "https://github.com/IBM-Swift/BlueSocket", majorVersion: 0)
    ]
)
