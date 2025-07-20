// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CustomPermissionServiceInterface",
    platforms: [
        .macOS(.v14),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "CustomPermissionServiceInterface",
            targets: ["CustomPermissionServiceInterface"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jamesrochabrun/ClaudeCodeSDK", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "CustomPermissionServiceInterface",
            dependencies: [
                .product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK")
            ]),
        .testTarget(
            name: "CustomPermissionServiceInterfaceTests",
            dependencies: ["CustomPermissionServiceInterface"]),
    ]
)
