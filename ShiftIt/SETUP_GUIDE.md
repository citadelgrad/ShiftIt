# Quick Setup Guide for Keyboard Shortcut Recorder

## Current Build Errors

You're seeing errors because the Swift class `KeyboardShortcutRecorder` isn't being properly bridged to Objective-C. Here's how to fix it:

## Required Xcode Configuration

### 1. Add Swift Files to Your Target

1. In Xcode's Project Navigator, find `KeyboardShortcutRecorder.swift`
2. If it's red (missing), re-add it to the project:
   - Right-click on your project folder
   - Choose "Add Files to ShiftIt..."
   - Select `KeyboardShortcutRecorder.swift`
   - **IMPORTANT**: Check "Add to targets: ShiftIt" (or your app target name)

### 2. Configure Bridging Header

1. Select your project in the navigator
2. Select your **app target** (not the project)
3. Go to **Build Settings** tab
4. Search for "bridging"
5. Under **Swift Compiler - General**, find **Objective-C Bridging Header**
6. Set the value to: `ShiftIt/ShiftIt-Bridging-Header.h` (adjust path if needed)
   - Or use: `$(SRCROOT)/ShiftIt/ShiftIt-Bridging-Header.h`

### 3. Enable Swift Support

In **Build Settings**, make sure these are set:

| Setting | Value |
|---------|-------|
| **Defines Module** | YES |
| **Install Objective-C Compatibility Header** | YES (if available) |
| **Swift Language Version** | Swift 5 (or latest) |

### 4. Verify Product Module Name

1. Still in **Build Settings**, search for "product module"
2. Find **Product Module Name** under **Packaging**
3. Note the value (e.g., "ShiftIt" or "ShiftItApp")
4. The generated header will be named: `<ProductModuleName>-Swift.h`

### 5. Fix the "Build input file cannot be found: Yes" Error

This strange error suggests there might be a build phase or script with incorrect paths. 

**To fix it:**

1. Select your target
2. Go to **Build Phases**
3. Check each phase for any references to a file called "Yes"
4. Expand "Compile Sources" - look for any broken/red files
5. Remove any invalid entries

Common places to check:
- Compile Sources
- Copy Bundle Resources
- Run Script phases
- Link Binary With Libraries

### 6. Clean Build

After making these changes:

1. Press **⇧⌘K** (Shift-Command-K) to clean
2. Close Xcode
3. Delete derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/ShiftIt-*
   ```
4. Reopen Xcode
5. Build again (**⌘B**)

## Verification

After building successfully, you should see:

1. No compiler errors
2. The Preferences window shows interactive shortcut recorders
3. Clicking a recorder field lets you capture keyboard shortcuts
4. Shortcuts display with proper symbols (⌘⌥⇧⌃)

## If You Still See Errors

### Error: "Use of undeclared type 'KeyboardShortcutRecorder'"

**Problem**: Swift file not compiled or bridging not working

**Solution**:
1. Verify `KeyboardShortcutRecorder.swift` is in "Compile Sources" (Build Phases)
2. Check that "Defines Module" is YES
3. Clean and rebuild

### Error: "Could not build Objective-C module 'ShiftIt'"

**Problem**: Bridging header has issues

**Solution**:
1. Open `ShiftIt-Bridging-Header.h`
2. Make sure all `#import` statements are valid
3. Remove any imports to files that don't exist
4. Build again

### Error: "Receiver is a forward class"

**Problem**: The Swift-generated header isn't being imported

**Solution**:
1. Check that `SWIFT_IMPORTED` is defined (build log will show a warning if not)
2. Verify the generated header exists in DerivedData:
   ```
   ~/Library/Developer/Xcode/DerivedData/ShiftIt-*/Build/Intermediates.noindex/ShiftIt.build/Debug/ShiftIt.build/DerivedSources/
   ```
3. Look for files like `ShiftIt-Swift.h` or `ShiftItApp-Swift.h`

## File Locations

Make sure these files exist in your project:

```
ShiftIt/
├── KeyboardShortcutRecorder.swift          ← Swift implementation
├── ShiftIt-Bridging-Header.h               ← Bridging header  
├── PreferencesWindowController.h
├── PreferencesWindowController.m
└── ...
```

## Testing the Integration

Once built successfully:

1. Run the app
2. Open Preferences (⌘,)
3. Go to "Hotkeys" tab
4. Click on any shortcut field
5. Press a key combination (e.g., ⌘⌥←)
6. You should see it display as "⌥⌘←"

## Manual Verification Commands

Run these in Terminal to check your setup:

```bash
# Check if Swift file exists
ls -la ShiftIt/KeyboardShortcutRecorder.swift

# Check if bridging header exists  
ls -la ShiftIt/ShiftIt-Bridging-Header.h

# Check product module name
defaults read ~/Library/Developer/Xcode/DerivedData/*/Build/Intermediates.noindex/ShiftIt.build/Debug/ShiftIt.build/Objects-normal/*/ShiftIt.SwiftFileList 2>/dev/null | head -5
```

## Alternative: Manual Xcode Project File Edit

If Xcode isn't picking up the Swift file, you may need to manually add it to your `.xcodeproj`:

1. Close Xcode
2. Right-click `ShiftIt.xcodeproj` → Show Package Contents
3. Open `project.pbxproj` in a text editor
4. Search for `KeyboardShortcutRecorder.swift`
5. If not found, use Xcode to add it properly (don't edit manually unless you know what you're doing)

## Still Stuck?

The code has been written with fallback support. If Swift integration continues to fail:

1. The app will show a message: "Setup required: Check KEYBOARD_SHORTCUT_INTEGRATION.md"
2. Review the full integration guide: `KEYBOARD_SHORTCUT_INTEGRATION.md`
3. Consider using the older ShortcutRecorder library temporarily
4. Check GitHub Issues for similar problems

## Quick Diagnostic

Run this build and check the output:

```bash
xcodebuild -project ShiftIt.xcodeproj -target ShiftIt -configuration Debug clean build 2>&1 | grep -i "swift\|bridg\|KeyboardShortcut"
```

This will show you Swift-related build steps and help identify what's missing.
