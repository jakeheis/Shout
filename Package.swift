// swift-tools-version:5.0
// Managed by ice

import PackageDescription

let package = Package(
    name: "Shout",
    platforms: [
        .macOS(.v10_10)
    ],
    products: [
        .library(name: "Shout", targets: ["Shout"]),
    ],
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/BlueSocket", from: "1.0.46"),
    ],
    targets: [
        .systemLibrary(name: "CSSH", pkgConfig: "libssh2", providers: [.brew(["libssh2","openssl"])]),
        .target(name: "Shout", dependencies: ["CSSH", "Socket"]),
        .testTarget(name: "ShoutTests", dependencies: ["Shout"]),
    ]
)
