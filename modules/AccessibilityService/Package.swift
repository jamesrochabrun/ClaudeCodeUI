// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "AccessibilityService",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "AccessibilityService",
      targets: ["AccessibilityService"]
    ),
  ],
  dependencies: [
    .package(path: "../AccessibilityFoundation"),
    .package(path: "../AccessibilityServiceInterface"),
  ],
  targets: [
    .target(
      name: "AccessibilityService",
      dependencies: [
        "AccessibilityFoundation",
        "AccessibilityServiceInterface",
      ],
      path: "Sources"
    ),
    .testTarget(
      name: "AccessibilityServiceTests",
      dependencies: ["AccessibilityService"],
      path: "Tests"
    ),
  ]
)
