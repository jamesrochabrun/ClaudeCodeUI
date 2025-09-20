import Foundation

/// Protocol for providing the path to the ApprovalMCPServer executable
/// This allows package consumers to specify their own build location
/// while maintaining backward compatibility with bundled executables
public protocol ApprovalServerProvider {
  /// Returns the absolute path to the ApprovalMCPServer executable
  /// - Returns: Path to executable, or nil if not available
  func approvalServerPath() -> String?
}

/// Default implementation that looks for the server in the app bundle
public struct BundleApprovalServerProvider: ApprovalServerProvider {
  public init() {}

  public func approvalServerPath() -> String? {
    // Check if it's in the app bundle (for DMG distribution)
    if let bundlePath = Bundle.main.path(forResource: "ApprovalMCPServer", ofType: nil) {
      if FileManager.default.fileExists(atPath: bundlePath) {
        return bundlePath
      }
    }
    return nil
  }
}

/// Custom implementation for package consumers who build their own server
public struct CustomApprovalServerProvider: ApprovalServerProvider {
  private let path: String

  public init(path: String) {
    self.path = path
  }

  public func approvalServerPath() -> String? {
    return FileManager.default.fileExists(atPath: path) ? path : nil
  }
}