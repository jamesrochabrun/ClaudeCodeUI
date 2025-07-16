// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "XcodeObserverServiceInterface",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "XcodeObserverServiceInterface",
      targets: ["XcodeObserverServiceInterface"]
    ),
  ],
  dependencies: [
    .package(path: "../AccessibilityFoundation"),
  ],
  targets: [
    .target(
      name: "XcodeObserverServiceInterface",
      dependencies: ["AccessibilityFoundation"],
      path: "Sources"
    ),
    .testTarget(
      name: "XcodeObserverInterfaceTests",
      dependencies: ["XcodeObserverServiceInterface"],
      path: "Tests"
    ),
  ]
)

/// Enable support for inline Regexes (https://stackoverflow.com/questions/75573646/does-the-swift-package-manager-support-regex-literals)
let swiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("BareSlashRegexLiterals"),
  .enableUpcomingFeature("StrictConcurrency"),
  .unsafeFlags(
    ["-enable-actor-data-race-checks"],
    .when(configuration: .debug)
  ),
]
for target in package.targets {
  target.swiftSettings = target.swiftSettings ?? []
  target.swiftSettings?.append(contentsOf: swiftSettings)
}
