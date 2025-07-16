// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "XcodeObserverService",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "XcodeObserverService",
      targets: ["XcodeObserverService"]
    ),
  ],
  dependencies: [
    .package(path: "../AccessibilityFoundation"),
    .package(path: "../AccessibilityServiceInterface"),
    .package(path: "../PermissionsServiceInterface"),
    .package(path: "../XcodeObserverServiceInterface"),
  ],
  targets: [
    .target(
      name: "XcodeObserverService",
      dependencies: [
        "AccessibilityFoundation",
        "AccessibilityServiceInterface",
        "PermissionsServiceInterface",
        "XcodeObserverServiceInterface",
      ],
      path: "Sources"
    ),
    .testTarget(
      name: "XcodeObserverServiceTests",
      dependencies: ["XcodeObserverServiceInterface", "XcodeObserverService"],
      path: "Tests"
    ),
  ]
)
