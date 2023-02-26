// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FileOpener",
    platforms: [.iOS(.v14), .macOS(.v11)],
    products: [
        .library(
            name: "FileOpener",
            targets: ["FileOpener"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FileOpener",
            dependencies: []),
        .testTarget(
            name: "FileOpenerTests",
            dependencies: ["FileOpener"]),
    ]
)
