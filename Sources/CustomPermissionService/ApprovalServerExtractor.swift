import Foundation

/// Handles extraction of the ApprovalMCPServer binary from embedded base64 resource
struct ApprovalServerExtractor {

  /// Extract the ApprovalMCPServer binary from base64 resource to Application Support
  /// - Returns: Path to the extracted executable, or nil if extraction fails
  static func extractApprovalServer() -> String? {
    // Try to find the base64 resource in various bundles
    let base64URL = findBase64Resource()

    guard let base64URL = base64URL else {
      print("[ApprovalServerExtractor] Could not find ApprovalMCPServer.base64 resource")
      return nil
    }

    do {
      // Read the base64 data
      let base64String = try String(contentsOf: base64URL)

      // Decode from base64
      guard let binaryData = Data(base64Encoded: base64String.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        print("[ApprovalServerExtractor] Failed to decode base64 data")
        return nil
      }

      // Prepare destination path
      let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
      let appName = Bundle.main.bundleIdentifier ?? "ClaudeCodeUI"
      let destinationDir = appSupportURL.appendingPathComponent(appName)
      let destinationPath = destinationDir.appendingPathComponent("ApprovalMCPServer")

      // Create directory if needed
      try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)

      // Check if we already have a valid binary
      if FileManager.default.fileExists(atPath: destinationPath.path) {
        // Verify it's executable
        let attributes = try FileManager.default.attributesOfItem(atPath: destinationPath.path)
        if let permissions = attributes[.posixPermissions] as? Int,
           permissions & 0o111 != 0 {
          print("[ApprovalServerExtractor] Using existing binary at: \(destinationPath.path)")
          return destinationPath.path
        }
      }

      // Write the binary data
      try binaryData.write(to: destinationPath)

      // Make it executable
      try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationPath.path)

      print("[ApprovalServerExtractor] Successfully extracted ApprovalMCPServer to: \(destinationPath.path)")
      return destinationPath.path

    } catch {
      print("[ApprovalServerExtractor] Error extracting approval server: \(error)")
      return nil
    }
  }

  /// Find the base64 resource in various bundle locations
  private static func findBase64Resource() -> URL? {
    // For Swift Package consumers, try to find it as an embedded string literal first
    // This is a fallback if the base64 file isn't bundled properly
    if let embeddedBase64 = getEmbeddedBase64() {
      // Create a temporary file with the embedded content
      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ApprovalMCPServer.base64")
      do {
        try embeddedBase64.write(to: tempURL, atomically: true, encoding: .utf8)
        print("[ApprovalServerExtractor] Using embedded base64 resource")
        return tempURL
      } catch {
        print("[ApprovalServerExtractor] Failed to write embedded base64 to temp file: \(error)")
      }
    }

    // First, try direct path to SPM resource bundle
    let mainBundle = Bundle.main
    let spmBundlePath = mainBundle.bundleURL.appendingPathComponent("Contents/Resources/ClaudeCodeUI_ClaudeCodeCore.bundle")
    if let spmBundle = Bundle(url: spmBundlePath) {
      print("[ApprovalServerExtractor] Found SPM bundle at direct path: \(spmBundlePath.path)")
      if let url = spmBundle.url(forResource: "ApprovalMCPServer", withExtension: "base64") {
        print("[ApprovalServerExtractor] Found base64 resource in SPM bundle!")
        return url
      }
    }

    // List of bundles to check
    var bundles: [Bundle] = [
      Bundle.main,
      Bundle(for: MCPApprovalTool.self)
    ]

    // Try to find ClaudeCodeCore bundle
    if let coreBundle = BundleHelper.findClaudeCodeCoreBundle() {
      bundles.append(coreBundle)
    }

    // Also check all bundles containing ClaudeCode
    for bundle in Bundle.allBundles {
      if bundle.bundleURL.path.contains("ClaudeCode") {
        bundles.append(bundle)
      }
      // Also check SPM-generated bundle names
      if bundle.bundleURL.lastPathComponent == "ClaudeCodeUI_ClaudeCodeCore.bundle" {
        bundles.append(bundle)
        print("[ApprovalServerExtractor] Found SPM bundle: \(bundle.bundleURL.path)")
      }
    }

    // Also check frameworks
    for bundle in Bundle.allFrameworks {
      if bundle.bundleURL.path.contains("ClaudeCode") {
        bundles.append(bundle)
      }
    }

    // Try to find the base64 resource
    for bundle in bundles {
      // Try with Resources subdirectory
      if let url = bundle.url(forResource: "ApprovalMCPServer", withExtension: "base64", subdirectory: "Resources") {
        print("[ApprovalServerExtractor] Found base64 resource in \(bundle.bundleURL.lastPathComponent)/Resources")
        return url
      }

      // Try without subdirectory
      if let url = bundle.url(forResource: "ApprovalMCPServer", withExtension: "base64") {
        print("[ApprovalServerExtractor] Found base64 resource in \(bundle.bundleURL.lastPathComponent)")
        return url
      }
    }

    return nil
  }

  /// Get the embedded base64 string (will be generated at build time)
  /// Returns nil for now - this will be replaced with actual base64 data
  private static func getEmbeddedBase64() -> String? {
    // This will be replaced by a build script with the actual base64 content
    // For now, return nil to fall back to file-based lookup
    return nil
  }

  /// Get debug info about the base64 resource search
  static func getDebugInfo() -> String {
    var info: [String] = []
    info.append("=== ApprovalServerExtractor Debug Info ===")

    // Check direct SPM bundle path first
    let mainBundle = Bundle.main
    let spmBundlePath = mainBundle.bundleURL.appendingPathComponent("Contents/Resources/ClaudeCodeUI_ClaudeCodeCore.bundle")
    info.append("\nChecking direct SPM path: \(spmBundlePath.path)")
    if FileManager.default.fileExists(atPath: spmBundlePath.path) {
      info.append("✅ SPM bundle exists at path")
      if let spmBundle = Bundle(url: spmBundlePath) {
        if let url = spmBundle.url(forResource: "ApprovalMCPServer", withExtension: "base64") {
          info.append("✅ Found base64 resource in SPM bundle!")
        } else {
          info.append("❌ base64 resource not found in SPM bundle")
          // List contents of bundle
          let resourcesPath = spmBundle.bundleURL.appendingPathComponent("Contents/Resources")
          if let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcesPath.path) {
            info.append("   Bundle contents: \(contents.joined(separator: ", "))")
          }
        }
      }
    } else {
      info.append("❌ SPM bundle does not exist at expected path")
    }

    // Check if base64 resource exists
    if let base64URL = findBase64Resource() {
      info.append("\n✅ Found base64 resource at: \(base64URL.path)")

      // Try to get file size
      if let attributes = try? FileManager.default.attributesOfItem(atPath: base64URL.path),
         let fileSize = attributes[.size] as? Int64 {
        info.append("   Size: \(fileSize) bytes")
      }
    } else {
      info.append("\n❌ Base64 resource not found")

      // List bundles checked
      info.append("\nBundles checked:")
      var bundles: Set<String> = []
      bundles.insert(Bundle.main.bundleURL.lastPathComponent)
      bundles.insert(Bundle(for: MCPApprovalTool.self).bundleURL.lastPathComponent)

      for bundle in Bundle.allBundles {
        if bundle.bundleURL.path.contains("ClaudeCode") {
          bundles.insert(bundle.bundleURL.lastPathComponent)
        }
      }

      for bundle in Bundle.allFrameworks {
        if bundle.bundleURL.path.contains("ClaudeCode") {
          bundles.insert(bundle.bundleURL.lastPathComponent)
        }
      }

      for bundleName in bundles.sorted() {
        info.append("  - \(bundleName)")
      }
    }

    // Check extraction destination
    let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let appName = Bundle.main.bundleIdentifier ?? "ClaudeCodeUI"
    let destinationPath = appSupportURL.appendingPathComponent(appName).appendingPathComponent("ApprovalMCPServer")

    info.append("\nExtraction destination: \(destinationPath.path)")
    if FileManager.default.fileExists(atPath: destinationPath.path) {
      info.append("✅ Binary exists at destination")

      // Check if executable
      if let attributes = try? FileManager.default.attributesOfItem(atPath: destinationPath.path),
         let permissions = attributes[.posixPermissions] as? Int {
        let isExecutable = permissions & 0o111 != 0
        info.append("   Executable: \(isExecutable ? "Yes" : "No")")
        info.append("   Permissions: \(String(format: "%o", permissions))")
      }
    } else {
      info.append("❌ Binary not yet extracted")
    }

    return info.joined(separator: "\n")
  }
}