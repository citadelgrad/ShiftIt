/*
 ShiftIt: Window Organizer for macOS
 ShortcutRecorder Stub - Replacement Functions
 
 This file provides stub implementations for ShortcutRecorder functions
 that have been removed from the project.
*/

#import "ShortcutRecorderStubs.h"
#import <Carbon/Carbon.h>

// Make sure these are visible to the linker
#ifdef __cplusplus
extern "C" {
#endif

// Stub implementation for SRStringForKeyCode
NSString* SRStringForKeyCode(NSInteger keyCode) {
    // Basic key code to string mapping
    // For full keyboard shortcut support, use KeyboardShortcutManager
    
    // Common key codes
    switch (keyCode) {
        case 0x7B: return @"←";  // Left arrow
        case 0x7C: return @"→";  // Right arrow  
        case 0x7D: return @"↓";  // Down arrow
        case 0x7E: return @"↑";  // Up arrow
        case 0x24: return @"↩";  // Return
        case 0x30: return @"⇥";  // Tab
        case 0x33: return @"⌫";  // Delete
        case 0x35: return @"⎋";  // Escape
        case 0x31: return @"␣";  // Space
        default:
            // Try to convert to character
            if (keyCode >= 0 && keyCode <= 127) {
                return [NSString stringWithFormat:@"%c", (char)keyCode];
            }
            return @"";
    }
}

// Stub implementation for SRCocoaToCarbonFlags
NSUInteger SRCocoaToCarbonFlags(NSEventModifierFlags cocoaFlags) {
    NSUInteger carbonFlags = 0;
    
    if (cocoaFlags & NSEventModifierFlagCommand) {
        carbonFlags |= cmdKey;
    }
    if (cocoaFlags & NSEventModifierFlagOption) {
        carbonFlags |= optionKey;
    }
    if (cocoaFlags & NSEventModifierFlagShift) {
        carbonFlags |= shiftKey;
    }
    if (cocoaFlags & NSEventModifierFlagControl) {
        carbonFlags |= controlKey;
    }
    
    return carbonFlags;
}
#ifdef __cplusplus
}
#endif


