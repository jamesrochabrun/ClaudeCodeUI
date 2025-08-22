// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClaudeCodeUI",
    platforms: [
        .macOS("15.2")
    ],
    products: [
        // Library for developers to use in their own apps
        .library(
            name: "ClaudeCodeCore",
            targets: ["ClaudeCodeCore"]
        ),
        // Executable for running the macOS app via SPM
        .executable(
            name: "ClaudeCodeUI",
            targets: ["ClaudeCodeUI"]
        )
    ],
    dependencies: [
        // External dependencies
        .package(url: "https://github.com/jamesrochabrun/ClaudeCodeSDK", branch: "main"),
        .package(url: "https://github.com/jamesrochabrun/SwiftAnthropic", from: "2.1.7"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.3.0"),
        .package(url: "https://github.com/gsabran/Down", revision: "14309dd8781c7613063344727454ffbbebc8e8bd"),
        .package(url: "https://github.com/appstefan/highlightswift", from: "1.1.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.9.0"),
        
        // Local module dependencies
        .package(path: "modules/AccessibilityFoundation"),
        .package(path: "modules/AccessibilityService"),
        .package(path: "modules/AccessibilityServiceInterface"),
        .package(path: "modules/ApprovalMCPServer"),
        .package(path: "modules/CustomPermissionService"),
        .package(path: "modules/CustomPermissionServiceInterface"),
        .package(path: "modules/PermissionsService"),
        .package(path: "modules/PermissionsServiceInterface"),
        .package(path: "modules/TerminalService"),
        .package(path: "modules/TerminalServiceInterface"),
        .package(path: "modules/XcodeObserverService"),
        .package(path: "modules/XcodeObserverServiceInterface"),
    ],
    targets: [
        // Core library containing all reusable components
        .target(
            name: "ClaudeCodeCore",
            dependencies: [
                .product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK"),
                .product(name: "SwiftAnthropic", package: "SwiftAnthropic"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Down", package: "Down"),
                .product(name: "HighlightSwift", package: "highlightswift"),
                .product(name: "MCP", package: "swift-sdk"),
                
                // Local modules
                .product(name: "AccessibilityFoundation", package: "AccessibilityFoundation"),
                .product(name: "AccessibilityService", package: "AccessibilityService"),
                .product(name: "AccessibilityServiceInterface", package: "AccessibilityServiceInterface"),
                .product(name: "CustomPermissionService", package: "CustomPermissionService"),
                .product(name: "CustomPermissionServiceInterface", package: "CustomPermissionServiceInterface"),
                .product(name: "PermissionsService", package: "PermissionsService"),
                .product(name: "PermissionsServiceInterface", package: "PermissionsServiceInterface"),
                .product(name: "TerminalService", package: "TerminalService"),
                .product(name: "TerminalServiceInterface", package: "TerminalServiceInterface"),
                .product(name: "XcodeObserverService", package: "XcodeObserverService"),
                .product(name: "XcodeObserverServiceInterface", package: "XcodeObserverServiceInterface"),
            ],
            path: "Sources/ClaudeCodeCore",
            resources: [
                .process("Assets.xcassets")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        
        // Minimal executable target that uses the core library
        .executableTarget(
            name: "ClaudeCodeUI",
            dependencies: [
                .target(name: "ClaudeCodeCore")
            ],
            path: "Sources/ClaudeCodeUI"
        ),
        
        // Test targets
        .testTarget(
            name: "ClaudeCodeCoreTests",
            dependencies: ["ClaudeCodeCore"],
            path: "Tests/ClaudeCodeCoreTests"
        )
    ]
)