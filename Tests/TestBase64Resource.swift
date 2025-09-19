import Foundation

// Simple test to see if we can access the base64 resource when using as Swift Package
func testBase64ResourceAccess() {
  print("=== Testing Base64 Resource Access ===")

  // Test 1: Check Bundle.main
  print("\n1. Bundle.main:")
  print("   Path: \(Bundle.main.bundlePath)")
  if let resource = Bundle.main.url(forResource: "ApprovalMCPServer", withExtension: "base64") {
    print("   ✅ Found in Bundle.main: \(resource)")
  } else {
    print("   ❌ Not found in Bundle.main")
  }

  // Test 2: Check all bundles
  print("\n2. All bundles:")
  for bundle in Bundle.allBundles {
    if bundle.bundleURL.path.contains("ClaudeCode") {
      print("   Checking: \(bundle.bundleURL.lastPathComponent)")
      if let resource = bundle.url(forResource: "ApprovalMCPServer", withExtension: "base64") {
        print("      ✅ Found: \(resource)")
      }
      if let resource = bundle.url(forResource: "ApprovalMCPServer", withExtension: "base64", subdirectory: "Resources") {
        print("      ✅ Found in Resources: \(resource)")
      }
    }
  }

  // Test 3: Check frameworks
  print("\n3. All frameworks:")
  for bundle in Bundle.allFrameworks {
    if bundle.bundleURL.path.contains("ClaudeCode") {
      print("   Checking: \(bundle.bundleURL.lastPathComponent)")
      if let resource = bundle.url(forResource: "ApprovalMCPServer", withExtension: "base64") {
        print("      ✅ Found: \(resource)")
      }
    }
  }

  print("\n=== End Test ===")
}

// Run the test
testBase64ResourceAccess()