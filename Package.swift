// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClaudeCodeUI",
    platforms: [
        .macOS("14.0")
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
        .package(url: "https://github.com/jamesrochabrun/ClaudeCodeSDK", from: "1.1.2"),
        .package(url: "https://github.com/jamesrochabrun/SwiftAnthropic", from: "2.1.7"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.3.0"),
        .package(url: "https://github.com/jamesrochabrun/Down", branch: "fix/external-cmark-dependency"),
        .package(url: "https://github.com/appstefan/highlightswift", from: "1.1.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.9.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.3"),

        // Keep ApprovalMCPServer as local package since it's a separate executable
        .package(path: "modules/ApprovalMCPServer"),
    ],
    targets: [
        // Foundation modules (no dependencies)
        .target(
            name: "CCAccessibilityFoundation",
            path: "Sources/AccessibilityFoundation"
        ),
        .target(
            name: "CCAccessibilityServiceInterface",
            path: "Sources/AccessibilityServiceInterface"
        ),
        .target(
            name: "CCCustomPermissionServiceInterface",
            dependencies: [
                .product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK")
            ],
            path: "Sources/CustomPermissionServiceInterface"
        ),
        .target(
            name: "CCPermissionsServiceInterface",
            path: "Sources/PermissionsServiceInterface"
        ),
        .target(
            name: "CCTerminalServiceInterface",
            path: "Sources/TerminalServiceInterface"
        ),
        
        // Modules with single dependencies
        .target(
            name: "CCXcodeObserverServiceInterface",
            dependencies: ["CCAccessibilityFoundation"],
            path: "Sources/XcodeObserverServiceInterface"
        ),
        .target(
            name: "CCTerminalService",
            dependencies: ["CCTerminalServiceInterface"],
            path: "Sources/TerminalService"
        ),
        .target(
            name: "CCCustomPermissionService",
            dependencies: [
                "CCCustomPermissionServiceInterface",
                .product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK"),
                .product(name: "SwiftAnthropic", package: "SwiftAnthropic"),
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Sources/CustomPermissionService"
        ),
        
        // Modules with multiple dependencies
        .target(
            name: "CCAccessibilityService",
            dependencies: [
                "CCAccessibilityFoundation",
                "CCAccessibilityServiceInterface"
            ],
            path: "Sources/AccessibilityService"
        ),
        .target(
            name: "CCPermissionsService",
            dependencies: [
                "CCPermissionsServiceInterface",
                "CCTerminalServiceInterface"
            ],
            path: "Sources/PermissionsService"
        ),
        .target(
            name: "CCXcodeObserverService",
            dependencies: [
                "CCAccessibilityFoundation",
                "CCAccessibilityServiceInterface",
                "CCPermissionsServiceInterface",
                "CCXcodeObserverServiceInterface"
            ],
            path: "Sources/XcodeObserverService",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        
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
                .product(name: "SQLite", package: "SQLite.swift"),

                // Internal module dependencies
                "CCAccessibilityFoundation",
                "CCAccessibilityService",
                "CCAccessibilityServiceInterface",
                "CCCustomPermissionService",
                "CCCustomPermissionServiceInterface",
                "CCPermissionsService",
                "CCPermissionsServiceInterface",
                "CCTerminalService",
                "CCTerminalServiceInterface",
                "CCXcodeObserverService",
                "CCXcodeObserverServiceInterface",
            ],
            path: "Sources/ClaudeCodeCore",
            exclude: [
                "FileSearch/FileSearch_README.md",
                "ClaudeCodeUI.entitlements"
            ],
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
        ),
        .testTarget(
            name: "CCAccessibilityFoundationTests",
            dependencies: ["CCAccessibilityFoundation"],
            path: "Tests/AccessibilityFoundationTests"
        ),
        .testTarget(
            name: "CCAccessibilityServiceTests",
            dependencies: ["CCAccessibilityService"],
            path: "Tests/AccessibilityServiceTests"
        ),
        .testTarget(
            name: "CCAccessibilityServiceInterfaceTests",
            dependencies: ["CCAccessibilityServiceInterface"],
            path: "Tests/AccessibilityServiceInterfaceTests"
        ),
        .testTarget(
            name: "CCCustomPermissionServiceTests",
            dependencies: ["CCCustomPermissionService"],
            path: "Tests/CustomPermissionServiceTests"
        ),
        .testTarget(
            name: "CCCustomPermissionServiceInterfaceTests",
            dependencies: ["CCCustomPermissionServiceInterface"],
            path: "Tests/CustomPermissionServiceInterfaceTests"
        ),
        .testTarget(
            name: "CCPermissionsServiceTests",
            dependencies: ["CCPermissionsService"],
            path: "Tests/PermissionsServiceTests"
        ),
        .testTarget(
            name: "CCPermissionsServiceInterfaceTests",
            dependencies: ["CCPermissionsServiceInterface"],
            path: "Tests/PermissionsServiceInterfaceTests"
        ),
        .testTarget(
            name: "CCTerminalServiceTests",
            dependencies: ["CCTerminalService"],
            path: "Tests/TerminalServiceTests",
            resources: [
                .process("simple_output.sh")
            ]
        ),
        .testTarget(
            name: "CCTerminalServiceInterfaceTests",
            dependencies: ["CCTerminalServiceInterface"],
            path: "Tests/TerminalServiceInterfaceTests"
        ),
        .testTarget(
            name: "CCXcodeObserverServiceTests",
            dependencies: ["CCXcodeObserverService"],
            path: "Tests/XcodeObserverServiceTests"
        ),
    ]
)
