import Foundation

/// Helper to access the resource bundle
public struct BundleHelper {
    /// Try to find the ClaudeCodeCore resource bundle
    public static func findClaudeCodeCoreBundle() -> Bundle? {
        // Look for a bundle that contains our resources
        // First check if we have a ClaudeCodeCore_ClaudeCodeCore bundle (SPM naming convention)
        if let bundle = Bundle(identifier: "ClaudeCodeCore_ClaudeCodeCore") {
            return bundle
        }

        // Check for ClaudeCodeCore bundle
        if let bundle = Bundle(identifier: "ClaudeCodeCore") {
            return bundle
        }

        // Look through all bundles for one containing our resources
        for bundle in Bundle.allBundles {
            // Check if this bundle has our resource
            if bundle.url(forResource: "ApprovalMCPServer", withExtension: nil, subdirectory: "Resources") != nil {
                return bundle
            }
            // Also check without subdirectory
            if bundle.url(forResource: "ApprovalMCPServer", withExtension: nil) != nil {
                return bundle
            }
        }

        // Check frameworks
        for bundle in Bundle.allFrameworks {
            if bundle.url(forResource: "ApprovalMCPServer", withExtension: nil, subdirectory: "Resources") != nil {
                return bundle
            }
            if bundle.url(forResource: "ApprovalMCPServer", withExtension: nil) != nil {
                return bundle
            }
        }

        return nil
    }

    /// Get debug info about available bundles
    public static func getBundleDebugInfo() -> String {
        var info: [String] = []
        info.append("=== Bundle Search Debug ===")

        info.append("\nAll Bundles:")
        for bundle in Bundle.allBundles {
            info.append("  - \(bundle.bundleURL.lastPathComponent): \(bundle.bundleIdentifier ?? "no identifier")")
        }

        info.append("\nAll Frameworks:")
        for bundle in Bundle.allFrameworks {
            info.append("  - \(bundle.bundleURL.lastPathComponent): \(bundle.bundleIdentifier ?? "no identifier")")
        }

        return info.joined(separator: "\n")
    }
}