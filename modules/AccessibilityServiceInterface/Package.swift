// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "AccessibilityServiceInterface",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "AccessibilityServiceInterface",
      targets: ["AccessibilityServiceInterface"]
    ),
  ],
  targets: [
    .target(
      name: "AccessibilityServiceInterface",
      path: "Sources"
    ),
    .testTarget(
      name: "AccessibilityServiceInterfaceTests",
      dependencies: ["AccessibilityServiceInterface"],
      path: "Tests"
    ),
  ]
)
