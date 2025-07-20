// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ApprovalMCPServer",
    platforms: [
        .macOS(.v14),
        .iOS(.v15)
    ],
    products: [
        .executable(
            name: "ApprovalMCPServer",
            targets: ["ApprovalMCPServer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.9.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ApprovalMCPServer",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
    ]
)