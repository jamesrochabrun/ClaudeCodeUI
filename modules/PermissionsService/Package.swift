// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "PermissionsService",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "PermissionsService",
      targets: ["PermissionsService"]
    ),
  ],
  dependencies: [
    .package(path: "../PermissionsServiceInterface"),
    .package(path: "../TerminalServiceInterface"),
  ],
  targets: [
    .target(
      name: "PermissionsService",
      dependencies: [
        "PermissionsServiceInterface",
        "TerminalServiceInterface",
      ],
      path: "Sources"
    ),
    .testTarget(
      name: "PermissionsServiceTests",
      dependencies: [
        "PermissionsService",
        "PermissionsServiceInterface",
      ],
      path: "Tests"
    ),
  ]
)
