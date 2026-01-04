# Keyboard Shortcut Recorder Integration Guide

This guide explains how to integrate the new modern `KeyboardShortcutRecorder` into your ShiftIt project.

## Overview

The old ShortcutRecorder library has been replaced with a modern, Swift-based implementation that:
- Uses Swift 5+ and modern AppKit APIs
- Provides a clean, native macOS look and feel
- Integrates seamlessly with Objective-C code
- Requires no external dependencies

## Files Added

1. **KeyboardShortcutRecorder.swift** - Main Swift implementation of the keyboard shortcut recorder view
2. **ShiftIt-Bridging-Header.h** - Bridging header to expose Objective-C to Swift
3. This README file

## Files Modified

1. **PreferencesWindowController.h** - Updated to use KeyboardShortcutRecorder
2. **PreferencesWindowController.m** - Implemented modern keyboard shortcut recording
3. **ShiftItAppDelegate.m** - Added hotkey change notifications and dynamic re-registration

## Xcode Project Configuration

### Step 1: Add Swift Files to Your Target

1. Open your Xcode project
2. Select your app target
3. Go to "Build Phases" → "Compile Sources"
4. Ensure `KeyboardShortcutRecorder.swift` is included

### Step 2: Configure Bridging Header

1. Select your app target
2. Go to "Build Settings"
3. Search for "Objective-C Bridging Header"
4. Set the value to: `$(PROJECT_DIR)/ShiftIt-Bridging-Header.h` (adjust path as needed)

### Step 3: Enable Swift-ObjC Interoperability

1. In "Build Settings", search for "Defines Module"
2. Set `Defines Module` to `YES`
3. Search for "Product Module Name"
4. Note the value (usually your target name, e.g., "ShiftIt" or "ShiftItApp")

### Step 4: Update Objective-C Files

In `PreferencesWindowController.m`, the import should match your module name:

```objective-c
#if __has_include("ShiftIt-Swift.h")
#import "ShiftIt-Swift.h"
#elif __has_include("ShiftItApp-Swift.h")
#import "ShiftItApp-Swift.h"
#endif
```

Replace `ShiftIt` or `ShiftItApp` with your actual module name if different.

## How It Works

### Recording Shortcuts

When a user clicks on a keyboard shortcut field:

1. The recorder enters "recording mode" with a highlighted border
2. User presses a key combination (at least one modifier required, except for F-keys)
3. The shortcut is captured and displayed with proper symbols (⌘⌥⇧⌃)
4. The shortcut is saved to UserDefaults
5. A notification is posted to update the hotkey system

### Clearing Shortcuts

- Click the (X) button that appears when a shortcut is set
- Or press Delete/Backspace while recording

### Special Keys

The recorder properly handles:
- Arrow keys (←→↑↓)
- Function keys (F1-F20)
- Special keys (Space, Return, Tab, Delete, Escape)
- All modifier combinations (⌘ Command, ⌥ Option, ⇧ Shift, ⌃ Control)

## Customization

### Appearance

The recorder uses system colors and automatically adapts to light/dark mode:

```swift
layer?.borderColor = NSColor.separatorColor.cgColor  // Normal state
layer?.borderColor = NSColor.controlAccentColor.cgColor  // Recording state
```

### Validation

Modify the `handleKeyDown(_:)` method to add custom validation:

```swift
// Example: Require Command key for all shortcuts
let hasCommand = event.modifierFlags.contains(.command)
if !hasCommand && !isFunctionKey {
    NSSound.beep()
    return nil
}
```

### Display Format

Customize the `formatShortcut()` method to change how shortcuts are displayed:

```swift
private func formatShortcut() -> String {
    // Custom formatting logic here
}
```

## Troubleshooting

### Recorder Not Appearing

**Issue**: The preferences window shows blank fields instead of recorders.

**Solution**: 
- Check that `KeyboardShortcutRecorder.swift` is compiled
- Verify the bridging header path is correct
- Clean build folder (⇧⌘K) and rebuild

### Swift Class Not Found

**Issue**: Error: "Use of undeclared type 'KeyboardShortcutRecorder'"

**Solution**:
- Ensure "Defines Module" is set to YES
- Check that the import statement matches your module name
- The generated header is `<ModuleName>-Swift.h`

### Shortcuts Not Working

**Issue**: Shortcuts are recorded but don't trigger actions.

**Solution**:
- Check that `kHotKeyChangedNotification` is being observed in ShiftItAppDelegate
- Verify the `hotkeyChanged:` method is being called
- Check Console.app for log messages starting with "ShiftIt"

### Recording Mode Stuck

**Issue**: The recorder stays in recording mode and won't exit.

**Solution**:
- Press Escape to cancel recording
- Click outside the recorder field
- This should be rare - check for event monitor issues

## Migration from Old ShortcutRecorder

The old ShortcutRecorder library used Carbon-based APIs and had this structure:

```objective-c
// OLD (removed):
SRRecorderControl *recorder = [[SRRecorderControl alloc] initWithFrame:frame];
recorder.delegate = self;
[recorder setKeyCombo:combo];
```

The new implementation is cleaner:

```objective-c
// NEW:
KeyboardShortcutRecorder *recorder = [[KeyboardShortcutRecorder alloc] initWithFrame:frame];
recorder.delegate = self;
recorder.identifier = @"action_id";
[recorder loadFromUserDefaults];
```

### Key Differences

| Old ShortcutRecorder | New KeyboardShortcutRecorder |
|---------------------|------------------------------|
| Carbon-based APIs | Modern Swift/AppKit |
| External dependency | Built-in, no dependencies |
| Complex setup | Simple, self-contained |
| Limited customization | Fully customizable |
| Objective-C only | Swift + ObjC bridge |

## Testing

### Manual Testing

1. Open Preferences (⌘,)
2. Go to the "Hotkeys" tab
3. Click on any shortcut field
4. Press a key combination (e.g., ⌘⌥←)
5. Verify the shortcut displays correctly
6. Try triggering the action using the shortcut
7. Relaunch the app and verify shortcuts persist

### Edge Cases to Test

- ✓ Shortcuts with all modifier combinations
- ✓ Function keys (F1-F20) without modifiers
- ✓ Clearing shortcuts
- ✓ Duplicate shortcuts (should allow but may cause conflicts)
- ✓ Escape to cancel recording
- ✓ Delete to clear while recording
- ✓ Persistence across app launches

## API Reference

### KeyboardShortcutRecorder Class

```swift
@objc public class KeyboardShortcutRecorder: NSView {
    @objc public var identifier: String?
    @objc public var keyCode: Int
    @objc public var modifierFlags: UInt
    @objc public weak var delegate: KeyboardShortcutRecorderDelegate?
    
    @objc public func loadFromUserDefaults()
}
```

### KeyboardShortcutRecorderDelegate Protocol

```swift
@objc public protocol KeyboardShortcutRecorderDelegate: AnyObject {
    @objc optional func shortcutRecorder(
        _ recorder: KeyboardShortcutRecorder, 
        didChangeKeyCode keyCode: Int, 
        modifiers: UInt
    )
}
```

## Future Enhancements

Possible improvements for the future:

1. **Conflict Detection**: Show warnings when two actions use the same shortcut
2. **Global Shortcut Display**: Show all registered shortcuts in a separate tab
3. **Import/Export**: Allow users to share shortcut configurations
4. **Themes**: Support custom color schemes
5. **Animation**: Add smooth transitions when changing shortcuts
6. **Accessibility**: Enhanced VoiceOver support

## Support

If you encounter issues:

1. Check Console.app for log messages (filter by "ShiftIt")
2. Verify Accessibility permissions are granted
3. Try resetting to default shortcuts
4. Check the GitHub issues page

## License

This implementation maintains compatibility with ShiftIt's GPL v3 license.

---

**Note**: This is a complete drop-in replacement for ShortcutRecorder. No changes to your existing preference defaults or user settings are required.
