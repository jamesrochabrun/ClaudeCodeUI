// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "PermissionsServiceInterface",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "PermissionsServiceInterface",
      targets: ["PermissionsServiceInterface"]
    ),
  ],
  targets: [
    .target(
      name: "PermissionsServiceInterface",
      path: "Sources"
    ),
    .testTarget(
      name: "PermissionsServiceInterfaceTests",
      dependencies: ["PermissionsServiceInterface"],
      path: "Tests"
    ),
  ]
)
