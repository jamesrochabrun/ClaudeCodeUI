// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CustomPermissionService",
    platforms: [
        .macOS(.v14),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "CustomPermissionService",
            targets: ["CustomPermissionService"]),
    ],
    dependencies: [
        .package(path: "../CustomPermissionServiceInterface"),
        .package(url: "https://github.com/jamesrochabrun/ClaudeCodeSDK", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "CustomPermissionService",
            dependencies: [
                "CustomPermissionServiceInterface",
                .product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK")
            ]),
        .testTarget(
            name: "CustomPermissionServiceTests",
            dependencies: ["CustomPermissionService", "CustomPermissionServiceInterface"]),
    ]
)
