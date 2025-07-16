// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "AccessibilityFoundation",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "AccessibilityFoundation",
      targets: ["AccessibilityFoundation"]
    ),
  ],
  targets: [
    .target(
      name: "AccessibilityFoundation",
      path: "Sources"
    ),
    .testTarget(
      name: "AccessibilityFoundationTests",
      dependencies: ["AccessibilityFoundation"],
      path: "Tests"
    ),
  ]
)
