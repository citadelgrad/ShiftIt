//
//  ShiftIt-Bridging-Header.h
//  ShiftIt
//
//  Bridging header to expose Objective-C to Swift
//

#ifndef ShiftIt_Bridging_Header_h
#define ShiftIt_Bridging_Header_h

// Import Foundation and AppKit
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

// Import ShiftIt app headers
#import "ShiftItApp.h"
#import "PreferencesWindowController.h"

// Constants for user defaults keys
extern NSString *const kKeyCodePrefKeySuffix;
extern NSString *const kModifiersPrefKeySuffix;

// Notification names
extern NSString *const kHotKeyChangedNotification;
extern NSString *const kActionIdentifierKey;
extern NSString *const kHotKeyKeyCodeKey;
extern NSString *const kHotKeyModifiersKey;

// Global actions dictionary
extern NSDictionary *allShiftActions;

#endif /* ShiftIt_Bridging_Header_h */
