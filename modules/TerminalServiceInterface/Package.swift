// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "TerminalServiceInterface",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "TerminalServiceInterface",
      targets: ["TerminalServiceInterface"]
    ),
  ],
  targets: [
    .target(
      name: "TerminalServiceInterface",
      path: "Sources"
    ),
    .testTarget(
      name: "TerminalServiceInterfaceTests",
      dependencies: ["TerminalServiceInterface"],
      path: "Tests"
    ),
  ]
)
