# Xcode Build Settings Reference

## Required Build Settings for Swift-ObjC Interop

Copy and paste these exact values into your Xcode Build Settings.

---

## How to Access Build Settings

1. Open your Xcode project
2. Click on the **project** in the Navigator (blue icon)
3. Select your **app target** (usually "ShiftIt")
4. Click the **Build Settings** tab
5. Make sure **"All"** and **"Combined"** are selected (not "Basic")
6. Use the search box to find each setting

---

## Swift Compiler Settings

### Objective-C Bridging Header
```
SWIFT_OBJC_BRIDGING_HEADER = ShiftIt/ShiftIt-Bridging-Header.h
```
**Or (if the above doesn't work):**
```
SWIFT_OBJC_BRIDGING_HEADER = $(PROJECT_DIR)/ShiftIt/ShiftIt-Bridging-Header.h
```

**Location in UI**: 
- **Swift Compiler - General** → **Objective-C Bridging Header**

---

### Swift Language Version
```
SWIFT_VERSION = 5.0
```

**Location in UI**: 
- **Swift Compiler - Language** → **Swift Language Version**

**Options**: Choose **Swift 5** (or the latest available)

---

### Defines Module
```
DEFINES_MODULE = YES
```

**Location in UI**: 
- **Packaging** → **Defines Module**

**Critical**: This **must** be YES for Swift→ObjC bridging to work!

---

### Install Objective-C Compatibility Header
```
SWIFT_INSTALL_OBJC_HEADER = YES
```

**Location in UI**: 
- **Swift Compiler - General** → **Install Objective-C Compatibility Header**

**Note**: This may not appear in all Xcode versions. If you don't see it, skip it.

---

### Product Module Name
```
PRODUCT_MODULE_NAME = ShiftIt
```

**Location in UI**: 
- **Packaging** → **Product Module Name**

**Important**: 
- This determines the name of the generated Swift header
- If it's "ShiftIt", the header will be `ShiftIt-Swift.h`
- If it's "ShiftItApp", the header will be `ShiftItApp-Swift.h`
- Don't change this unless you know what you're doing

---

## Other Important Settings

### Enable Modules (C and Objective-C)
```
CLANG_ENABLE_MODULES = YES
```

**Location in UI**: 
- **Apple Clang - Language - Modules** → **Enable Modules (C and Objective-C)**

---

### Module Name
```
PRODUCT_NAME = ShiftIt
```

**Location in UI**: 
- **Packaging** → **Product Name**

---

### Allow Non-modular Includes
```
CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES = YES
```

**Location in UI**: 
- **Apple Clang - Language - Modules** → **Allow Non-modular Includes**

**Note**: Only set this if you have build issues with old code

---

## Deployment Settings

### macOS Deployment Target

Make sure this is set appropriately for your needs:

```
MACOSX_DEPLOYMENT_TARGET = 10.13
```

**Location in UI**: 
- **Deployment** → **macOS Deployment Target**

**Recommendation**: 
- 10.13+ for modern Swift features
- 10.15+ for best SwiftUI support (not needed for this project)

---

## Quick Copy-Paste for Terminal

You can set these via command line (close Xcode first):

```bash
cd /Users/scott/projects/ShiftIt

# Set bridging header
/usr/libexec/PlistBuddy -c "Set :objects:YOUR_TARGET_ID:buildSettings:SWIFT_OBJC_BRIDGING_HEADER 'ShiftIt/ShiftIt-Bridging-Header.h'" ShiftIt.xcodeproj/project.pbxproj

# Enable modules
/usr/libexec/PlistBuddy -c "Set :objects:YOUR_TARGET_ID:buildSettings:DEFINES_MODULE YES" ShiftIt.xcodeproj/project.pbxproj
```

**Note**: Replace `YOUR_TARGET_ID` with your actual target ID (hard to find, easier to use Xcode UI)

---

## Verify Your Settings

After setting everything, verify by building with verbose output:

```bash
cd /Users/scott/projects/ShiftIt
xcodebuild -project ShiftIt.xcodeproj \
  -target ShiftIt \
  -configuration Debug \
  -showBuildSettings | grep -E "SWIFT_|DEFINES_MODULE|PRODUCT_MODULE_NAME"
```

**Expected output should include:**
```
DEFINES_MODULE = YES
PRODUCT_MODULE_NAME = ShiftIt
SWIFT_OBJC_BRIDGING_HEADER = ShiftIt/ShiftIt-Bridging-Header.h
SWIFT_VERSION = 5.0
```

---

## Common Mistakes

### ❌ Bridging Header Path is Wrong

**Problem**: Path doesn't point to actual file location

**Fix**: The path should be relative to the `.xcodeproj` file. If your structure is:
```
ShiftIt/
  ├── ShiftIt.xcodeproj
  └── ShiftIt/
      ├── ShiftIt-Bridging-Header.h  ← file is here
      └── KeyboardShortcutRecorder.swift
```

Then the setting should be: `ShiftIt/ShiftIt-Bridging-Header.h`

---

### ❌ Module Name Contains Spaces or Special Characters

**Problem**: `PRODUCT_MODULE_NAME = "Shift It"` (with space)

**Fix**: No spaces allowed! Use: `PRODUCT_MODULE_NAME = ShiftIt`

---

### ❌ Settings Applied to Wrong Target

**Problem**: You edited the **Project** settings instead of the **Target** settings

**Fix**: 
- Make sure you select the **target** (not project) before editing
- The target has a different icon (looks like an app icon, not a folder)

---

### ❌ Using User-Defined Settings

**Problem**: Created custom user-defined settings instead of using built-in ones

**Fix**: 
- Scroll down to the actual build setting, don't create new ones
- If you see your setting under "User-Defined", delete it
- Search again and set the official one

---

## Project Structure Verification

Your project should look like this in Finder:

```
/Users/scott/projects/ShiftIt/
├── ShiftIt.xcodeproj/
│   └── project.pbxproj               ← Contains all settings
├── ShiftIt/
│   ├── ShiftIt-Bridging-Header.h     ← Must exist!
│   ├── KeyboardShortcutRecorder.swift ← Must exist!
│   ├── PreferencesWindowController.h
│   ├── PreferencesWindowController.m
│   ├── ShiftItAppDelegate.h
│   ├── ShiftItAppDelegate.m
│   └── ... (other files)
└── build/                            ← Generated by Xcode (can delete)
```

Run this to verify:
```bash
cd /Users/scott/projects/ShiftIt
ls -la ShiftIt/ShiftIt-Bridging-Header.h
ls -la ShiftIt/KeyboardShortcutRecorder.swift
```

Both should exist and not be empty.

---

## Build Settings Template

Save this as a reference. After you get it working, you can export these settings:

1. In Xcode: **Editor** → **Add Build Setting** → **Add User-Defined Setting**
2. Or better: Copy `project.pbxproj` and save it as a backup
3. Commit it to Git so you can revert if needed

---

## Testing Swift Configuration

Create this test file to verify Swift is working:

**File**: `SwiftTest.swift`
```swift
import Foundation

@objc(SwiftTestClass)
@objcMembers
public class SwiftTestClass: NSObject {
    public var testString: String = "Swift is working!"
    
    public func testMethod() -> String {
        return "Hello from Swift"
    }
}
```

Then in any `.m` file:
```objective-c
#import "ShiftIt-Swift.h" // or whatever your module name is

- (void)testSwift {
    SwiftTestClass *test = [[SwiftTestClass alloc] init];
    NSLog(@"%@", test.testString);
    NSLog(@"%@", [test testMethod]);
}
```

If this builds and runs, your Swift configuration is correct!

---

## Xcode Version Compatibility

These settings work with:
- ✅ Xcode 12.x+
- ✅ Xcode 13.x+
- ✅ Xcode 14.x+
- ✅ Xcode 15.x+

If you're on an older Xcode:
- Some settings may have different names
- Swift 5 may not be available (use Swift 4.2)
- Consider updating Xcode

---

## Final Checklist

Before building, verify:

- [ ] `DEFINES_MODULE = YES`
- [ ] `SWIFT_OBJC_BRIDGING_HEADER` points to correct file
- [ ] `SWIFT_VERSION = 5.0` (or later)
- [ ] Bridging header file exists at specified path
- [ ] `KeyboardShortcutRecorder.swift` is in "Compile Sources"
- [ ] `KeyboardShortcutRecorder.swift` target membership is checked
- [ ] No "Yes" or other weird files in Build Phases
- [ ] Cleaned build folder (⇧⌘K)
- [ ] Closed and reopened Xcode

Then build with ⌘B!

---

## Success Indicators

When everything is configured correctly:

1. Build succeeds with 0 errors
2. You see compile messages like:
   ```
   Compiling Swift sources...
   Generating ShiftIt-Swift.h...
   ```
3. The generated header exists (check DerivedData)
4. No warnings about "forward class"
5. App runs and shows working shortcut recorders

Good luck! 🚀
