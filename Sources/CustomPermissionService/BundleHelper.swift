import Foundation

/// Helper to access Bundle.module when built as a Swift Package
public struct BundleHelper {
    /// Returns the resource bundle for this module
    /// When built as a Swift Package, this returns Bundle.module
    /// When built in Xcode, this returns the main bundle
    public static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        // When not built as a package, resources might be in the main bundle
        return Bundle.main
        #endif
    }

    /// Try to find the ClaudeCodeCore resource bundle
    public static func findClaudeCodeCoreBundle() -> Bundle? {
        // First try the module bundle if available
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        // Look for a bundle that contains our resources
        for bundle in Bundle.allBundles {
            if bundle.url(forResource: "ApprovalMCPServer", withExtension: nil, subdirectory: "Resources") != nil {
                return bundle
            }
        }

        // Check frameworks
        for bundle in Bundle.allFrameworks {
            if bundle.url(forResource: "ApprovalMCPServer", withExtension: nil, subdirectory: "Resources") != nil {
                return bundle
            }
        }

        return nil
        #endif
    }
}