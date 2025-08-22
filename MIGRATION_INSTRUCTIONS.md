# Xcode Project Migration Instructions

## Current Status
✅ Package.swift created with ClaudeCodeCore library
✅ All source code copied to Sources/ClaudeCodeCore/
✅ Minimal executable created in Sources/ClaudeCodeUI/
⚠️ Xcode project still using original files (needs manual configuration)

## Steps to Complete the Migration

### 1. Add Local Package Dependency
1. Open `ClaudeCodeUI.xcodeproj` in Xcode
2. Select the project in the navigator (top blue icon)
3. In the project editor, select the `ClaudeCodeUI` project (not target)
4. Click the "Package Dependencies" tab
5. Click the "+" button
6. Click "Add Local..."
7. Navigate to your ClaudeCodeUI folder and select it (the root folder containing Package.swift)
8. Click "Add Package"
9. In the dialog that appears:
   - Choose "ClaudeCodeCore" library for the ClaudeCodeUI target
   - Click "Add Package"

### 2. Update App Target
1. Select the `ClaudeCodeUI` target
2. Go to "General" tab
3. In "Frameworks, Libraries, and Embedded Content" section:
   - You should see "ClaudeCodeCore" added
   - If not, click "+" and add it

### 3. Remove Original Source Files
1. In the project navigator, select the `ClaudeCodeUI` folder (the one under the project)
2. Delete all folders EXCEPT:
   - `Assets.xcassets` (keep this)
   - `ClaudeCodeUI.entitlements` (keep this)
3. When prompted, choose "Remove Reference" (not "Move to Trash")

### 4. Create New App Entry Point
1. Right-click the ClaudeCodeUI folder in project navigator
2. Select "New File..."
3. Choose "Swift File"
4. Name it "App.swift"
5. Add this content:

```swift
//
//  App.swift
//  ClaudeCodeUI
//
//  App entry point using ClaudeCodeCore package
//

import SwiftUI
import ClaudeCodeCore

@main
struct ClaudeCodeUIAppWrapper: App {
    var body: some Scene {
        // Use the complete app implementation from the package
        ClaudeCodeUIApp().body
    }
}
```

### 5. Clean and Build
1. Clean build folder: Product → Clean Build Folder (⇧⌘K)
2. Build: Product → Build (⌘B)

### 6. (Optional) Remove Duplicate Files
Once everything is working, you can delete the original source files:
```bash
rm -rf ClaudeCodeUI/Data
rm -rf ClaudeCodeUI/DependencyInjection
rm -rf ClaudeCodeUI/Design
rm -rf ClaudeCodeUI/Diff
rm -rf ClaudeCodeUI/Extensions
rm -rf ClaudeCodeUI/FileSearch
rm -rf ClaudeCodeUI/Models
rm -rf ClaudeCodeUI/Protocols
rm -rf ClaudeCodeUI/Services
rm -rf ClaudeCodeUI/Storage
rm -rf ClaudeCodeUI/ToolFormatting
rm -rf ClaudeCodeUI/UI
rm -rf ClaudeCodeUI/Utils
rm -rf ClaudeCodeUI/ViewModels
rm ClaudeCodeUI/RootView.swift
rm ClaudeCodeUI/ClaudeCodeUIApp.swift
```

## Verification
After completing these steps:
- ✅ Xcode project should build successfully
- ✅ The app should run exactly as before
- ✅ Swift Package Manager should also work: `swift build`
- ✅ Other developers can use your package in their apps

## Benefits of This Setup
1. **Single source of truth** - No duplicate files
2. **Package reusability** - Others can import ClaudeCodeCore
3. **Maintainability** - Changes in one place affect both SPM and Xcode builds
4. **Distribution flexibility** - Can distribute as app or package