// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "TerminalService",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "TerminalService",
      targets: ["TerminalService"]
    ),
  ],
  dependencies: [
    .package(path: "../TerminalServiceInterface"),
  ],
  targets: [
    .target(
      name: "TerminalService",
      dependencies: [
        "TerminalServiceInterface",
      ],
      path: "Sources"
    ),
    .testTarget(
      name: "TerminalServiceTests",
      dependencies: ["TerminalService"],
      path: "Tests",
      exclude: ["SwiftPrintTest.swift"]
    ),
  ]
)
