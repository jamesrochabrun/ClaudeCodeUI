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
        
        // Keep ApprovalMCPServer as local package since it's a separate executable
        .package(path: "modules/ApprovalMCPServer"),
    ],
    targets: [
        // Foundation modules (no dependencies)
        .target(
            name: "AccessibilityFoundation",
            path: "Sources/AccessibilityFoundation"
        ),
        .target(
            name: "AccessibilityServiceInterface",
            path: "Sources/AccessibilityServiceInterface"
        ),
        .target(
            name: "CustomPermissionServiceInterface",
            path: "Sources/CustomPermissionServiceInterface"
        ),
        .target(
            name: "PermissionsServiceInterface",
            path: "Sources/PermissionsServiceInterface"
        ),
        .target(
            name: "TerminalServiceInterface",
            path: "Sources/TerminalServiceInterface"
        ),
        
        // Modules with single dependencies
        .target(
            name: "XcodeObserverServiceInterface",
            dependencies: ["AccessibilityFoundation"],
            path: "Sources/XcodeObserverServiceInterface"
        ),
        .target(
            name: "TerminalService",
            dependencies: ["TerminalServiceInterface"],
            path: "Sources/TerminalService"
        ),
        .target(
            name: "CustomPermissionService",
            dependencies: [
                "CustomPermissionServiceInterface",
                .product(name: "SwiftAnthropic", package: "SwiftAnthropic"),
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Sources/CustomPermissionService"
        ),
        
        // Modules with multiple dependencies
        .target(
            name: "AccessibilityService",
            dependencies: [
                "AccessibilityFoundation",
                "AccessibilityServiceInterface"
            ],
            path: "Sources/AccessibilityService"
        ),
        .target(
            name: "PermissionsService",
            dependencies: [
                "PermissionsServiceInterface",
                "TerminalServiceInterface"
            ],
            path: "Sources/PermissionsService"
        ),
        .target(
            name: "XcodeObserverService",
            dependencies: [
                "AccessibilityFoundation",
                "AccessibilityServiceInterface",
                "PermissionsServiceInterface",
                "XcodeObserverServiceInterface"
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
                
                // Internal module dependencies
                "AccessibilityFoundation",
                "AccessibilityService",
                "AccessibilityServiceInterface",
                "CustomPermissionService",
                "CustomPermissionServiceInterface",
                "PermissionsService",
                "PermissionsServiceInterface",
                "TerminalService",
                "TerminalServiceInterface",
                "XcodeObserverService",
                "XcodeObserverServiceInterface",
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
            name: "AccessibilityFoundationTests",
            dependencies: ["AccessibilityFoundation"],
            path: "Tests/AccessibilityFoundationTests"
        ),
        .testTarget(
            name: "AccessibilityServiceTests",
            dependencies: ["AccessibilityService"],
            path: "Tests/AccessibilityServiceTests"
        ),
        .testTarget(
            name: "AccessibilityServiceInterfaceTests",
            dependencies: ["AccessibilityServiceInterface"],
            path: "Tests/AccessibilityServiceInterfaceTests"
        ),
        .testTarget(
            name: "CustomPermissionServiceTests",
            dependencies: ["CustomPermissionService"],
            path: "Tests/CustomPermissionServiceTests"
        ),
        .testTarget(
            name: "CustomPermissionServiceInterfaceTests",
            dependencies: ["CustomPermissionServiceInterface"],
            path: "Tests/CustomPermissionServiceInterfaceTests"
        ),
        .testTarget(
            name: "PermissionsServiceTests",
            dependencies: ["PermissionsService"],
            path: "Tests/PermissionsServiceTests"
        ),
        .testTarget(
            name: "PermissionsServiceInterfaceTests",
            dependencies: ["PermissionsServiceInterface"],
            path: "Tests/PermissionsServiceInterfaceTests"
        ),
        .testTarget(
            name: "TerminalServiceTests",
            dependencies: ["TerminalService"],
            path: "Tests/TerminalServiceTests",
            resources: [
                .process("simple_output.sh")
            ]
        ),
        .testTarget(
            name: "TerminalServiceInterfaceTests",
            dependencies: ["TerminalServiceInterface"],
            path: "Tests/TerminalServiceInterfaceTests"
        ),
        .testTarget(
            name: "XcodeObserverServiceTests",
            dependencies: ["XcodeObserverService"],
            path: "Tests/XcodeObserverServiceTests"
        ),
    ]
)