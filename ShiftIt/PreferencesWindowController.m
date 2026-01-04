/*
 ShiftIt: Window Organizer for OSX
 Copyright (c) 2010-2011 Filip Krikava
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
 */

#import "PreferencesWindowController.h"
#import "ShiftItApp.h"

// Import Swift classes
// The generated header name is based on your target's Product Module Name
// Check Build Settings -> Packaging -> Product Module Name
// Common names: ShiftIt-Swift.h, ShiftItApp-Swift.h
#if __has_include("ShiftIt-Swift.h")
    #import "ShiftIt-Swift.h"
    #define SWIFT_IMPORTED 1
#elif __has_include("ShiftItApp-Swift.h")
    #import "ShiftItApp-Swift.h"
    #define SWIFT_IMPORTED 1
#else
    #warning "Could not find Swift generated header. Check your Product Module Name in Build Settings."
    #define SWIFT_IMPORTED 0
#endif

// Declare protocol conformance here after Swift header is imported
@interface PreferencesWindowController () <KeyboardShortcutRecorderDelegate>
@end

NSString *const kKeyCodePrefKeySuffix = @"KeyCode";
NSString *const kModifiersPrefKeySuffix = @"Modifiers";

NSString *const kDidFinishEditingHotKeysPrefNotification = @"kEnableActionsRequestNotification";
NSString *const kDidStartEditingHotKeysPrefNotification = @"kDisableActionsRequestNotification";
NSString *const kHotKeyChangedNotification = @"kHotKeyChangedNotification";
NSString *const kActionIdentifierKey = @"kActionIdentifierKey";
NSString *const kHotKeyKeyCodeKey = @"kHotKeyKeyCodeKey";
NSString *const kHotKeyModifiersKey = @"kHotKeyModifiersKey";

NSString *const kShiftItGithubIssueURL = @"https://github.com/fikovnik/ShiftIt/issues";

NSString *const kHotKeysTabViewItemIdentifier = @"hotKeys";

@interface PreferencesWindowController (Private)

- (void)windowMainStatusChanged_:(NSNotification *)notification;

@end


@implementation PreferencesWindowController

@dynamic shouldStartAtLogin;
@dynamic debugLogging;
@synthesize debugLoggingFile = debugLoggingFile_;

- (id)init {
    if (![super initWithWindowNibName:@"PreferencesWindow"]) {
        return nil;
    }

    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)awakeFromNib {
    [tabView_ selectTabViewItemAtIndex:0];

    NSString *versionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    [versionLabel_ setStringValue:versionString];

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(windowMainStatusChanged_:) name:NSWindowDidResignMainNotification object:[self window]];
    [notificationCenter addObserver:self selector:@selector(windowMainStatusChanged_:) name:NSWindowDidBecomeMainNotification object:[self window]];

    // no debug logging by default
    [self setDebugLoggingFile:@""];

    [self updateRecorderCombos];
}

- (IBAction)showPreferences:(id)sender {
    [[self window] center];
    [NSApp activateIgnoringOtherApps:YES];
    [[self window] makeKeyAndOrderFront:sender];
}

- (IBAction)revertDefaults:(id)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSString *path = FMTGetMainBundleResourcePath(kShiftItUserDefaults, @"plist");
    NSDictionary *initialDefaults = [NSDictionary dictionaryWithContentsOfFile:path];
    [defaults registerDefaults:initialDefaults];

    for (ShiftItAction *action in [allShiftActions allValues]) {
        NSString *identifier = [action identifier];

        NSNumber *n = nil;

        n = [initialDefaults objectForKey:KeyCodePrefKey(identifier)];
        [defaults setInteger:[n integerValue] forKey:KeyCodePrefKey(identifier)];

        n = [initialDefaults objectForKey:ModifiersPrefKey(identifier)];
        [defaults setInteger:[n integerValue] forKey:ModifiersPrefKey(identifier)];
    }

    [defaults synchronize];

    // normally this won't be necessary since there could be an observer
    // looking at changes in the user defaults values itself, but since there is
    // unfortunatelly 2 defaults for one key this won't work well
    [self updateRecorderCombos];
}

-(IBAction)reportIssue:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:NSLocalizedString(@"Before you report new issue", nil)];
    [alert setInformativeText:NSLocalizedString(@"Please make sure that you look at the other issues before you submit a new one.", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Take me to github.com", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kShiftItGithubIssueURL]];
    }
    
    [alert release];
}

- (IBAction)revealLogFileInFinder:(id)sender {
    if (debugLoggingFile_) {
        NSURL *fileURL = [NSURL fileURLWithPath:debugLoggingFile_];
        // Use modern API or pass empty string instead of nil
        if (@available(macOS 10.15, *)) {
            [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[fileURL]];
        } else {
            [[NSWorkspace sharedWorkspace] selectFile:[fileURL path] inFileViewerRootedAtPath:@""];
        }
    }
}

- (IBAction)showMenuBarIconAction:(id)sender {
    if (![showMenuIcon state]) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Disabling menu icon"];
        [alert setInformativeText:@"You chose to disable the menu icon. This means that you won't be able to easily open the Preferences window in the future.\n"
                   "\n"
                   "To open the Preferences window, while the menu icon is hidden, just relaunch the application."];
        [alert addButtonWithTitle:@"OK"];
        
        [alert runModal];
        [alert release];
    }
}


#pragma mark debugLogging dynamic property methods

- (BOOL)debugLogging {
    return !([[GTMLogger sharedLogger] writer] == [NSFileHandle fileHandleWithStandardOutput]);
}

- (void)setDebugLogging:(BOOL)flag {
    id <GTMLogWriter> writer = nil;

    if (flag) {
        NSString *logFile = FMTStr(@"%@/ShiftIt-debug-log-%@.txt",
                NSTemporaryDirectory(),
                [[NSDate date] stringWithFormat:@"YYYYMMDD-HHmm"]);

        FMTLogInfo(@"Enabling debug logging into file: %@", logFile);
        writer = [NSFileHandle fileHandleForLoggingAtPath:logFile mode:0644];
        [self setDebugLoggingFile:logFile];
    } else {
        FMTLogInfo(@"Enabling debug logging into stdout");
        writer = [NSFileHandle fileHandleWithStandardOutput];
        [self setDebugLoggingFile:@""];
    }

    [[GTMLogger sharedLogger] setWriter:writer];
}

#pragma mark shouldStartAtLogin dynamic property methods

- (BOOL)shouldStartAtLogin {
    NSString *path = [[NSBundle mainBundle] bundlePath];
    return [[FMTLoginItems sharedSessionLoginItems] isInLoginItemsApplicationWithPath:path];
}

- (void)setShouldStartAtLogin:(BOOL)flag {
    FMTLogDebug(@"ShiftIt should start at login: %d", flag);

    NSString *path = [[NSBundle mainBundle] bundlePath];
    [[FMTLoginItems sharedSessionLoginItems] toggleApplicationInLoginItemsWithPath:path enabled:flag];
}

#pragma mark Shortcut Recorder methods

static NSString *hotkeyIdentifiers[] = {
    @"left",
    @"right",
    @"top",
    @"bottom",
    NULL,
    @"tl",
    @"tr",
    @"bl",
    @"br",
    NULL,
    @"ltt",
    @"ltb",
    @"ctt",
    @"ctb",
    @"rtt",
    @"rtb",
    NULL,
    @"lt",
    @"ct",
    @"rt",
    NULL,
    @"center",
    @"zoom",
    @"maximize",
    @"fullScreen",
    NULL,
    @"increase",
    @"reduce",
    NULL,
    @"nextscreen",
    @"previousscreen"
};

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return sizeof(hotkeyIdentifiers) / sizeof(hotkeyIdentifiers[0]);
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex {
    return NO;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    FMTAssert(row >= 0 && row < sizeof(hotkeyIdentifiers) / sizeof(hotkeyIdentifiers[0]), @"Row out of range");
    NSString* identifier = hotkeyIdentifiers[row];
    if (identifier == NULL)
        return 1;
    return 23;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    FMTAssert(row >= 0 && row < sizeof(hotkeyIdentifiers) / sizeof(hotkeyIdentifiers[0]), @"Row out of range");
    NSString* identifier = hotkeyIdentifiers[row];
    if (identifier == NULL)
        return NULL;
    ShiftItAction *action = [allShiftActions objectForKey:identifier];
    FMTAssertNotNil(action);
    if (tableColumn == hotkeyLabelColumn_) {
        NSTextField* text = [[NSTextField alloc] initWithFrame:tableView.frame];
        text.alignment = NSTextAlignmentRight;
        text.drawsBackground = NO;
        text.stringValue = action.label;
        [text setBordered:NO];
        [text setEditable:NO];
        return text;
    }
    if (tableColumn == hotkeyColumn_) {
#if SWIFT_IMPORTED
        // Use modern KeyboardShortcutRecorder
        NSRect frame = NSMakeRect(0, 0, tableView.frame.size.width - 10, 22);
        KeyboardShortcutRecorder *recorder = [[KeyboardShortcutRecorder alloc] initWithFrame:frame];
        recorder.actionIdentifier = identifier;
        recorder.delegate = self;
        
        // Load current shortcut from user defaults
        [recorder loadFromUserDefaults];
        
        return recorder;
#else
        // Fallback: Show message that Swift integration is needed
        NSTextField *placeholderText = [[NSTextField alloc] initWithFrame:tableView.frame];
        [placeholderText setStringValue:@"Setup required: Check KEYBOARD_SHORTCUT_INTEGRATION.md"];
        [placeholderText setEditable:NO];
        [placeholderText setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
        [placeholderText setTextColor:[NSColor systemRedColor]];
        return placeholderText;
#endif
    }
    FMTFail(@"Unknown tableView or tableColumn");
    return NULL;
}

#if SWIFT_IMPORTED
// Modern KeyboardShortcutRecorder delegate method
- (void)shortcutRecorder:(KeyboardShortcutRecorder *)recorder
      didChangeKeyCode:(NSInteger)keyCode
             modifiers:(NSUInteger)modifiers {
    NSString *identifier = recorder.actionIdentifier;
    FMTAssertNotNil(identifier);
    
    ShiftItAction *action = [allShiftActions objectForKey:identifier];
    FMTAssertNotNil(action);
    
    FMTLogInfo(@"ShiftIt action %@ hotkey changed: keyCode=%ld modifiers=%lu", 
               [action identifier], (long)keyCode, (unsigned long)modifiers);
    
    // Post notification for hotkey change
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:3];
    [userInfo setObject:[action identifier] forKey:kActionIdentifierKey];
    [userInfo setObject:[NSNumber numberWithInteger:keyCode] forKey:kHotKeyKeyCodeKey];
    [userInfo setObject:[NSNumber numberWithUnsignedInteger:modifiers] forKey:kHotKeyModifiersKey];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kHotKeyChangedNotification 
                                                        object:self 
                                                      userInfo:userInfo];
}
#endif

- (void)updateRecorderCombos {
#if SWIFT_IMPORTED
    FMTLogInfo(@"Updating keyboard shortcut recorders");
    
    // Reload all recorder views in the table
    for (int row = 0; row < sizeof(hotkeyIdentifiers) / sizeof(hotkeyIdentifiers[0]); ++row) {
        NSString* identifier = hotkeyIdentifiers[row];
        if (identifier == NULL)
            continue;
            
        KeyboardShortcutRecorder *recorder = (KeyboardShortcutRecorder *)[hotkeysView_ viewAtColumn:1 row:row makeIfNecessary:NO];
        if (recorder && [recorder isKindOfClass:[KeyboardShortcutRecorder class]]) {
            [recorder loadFromUserDefaults];
        }
    }
#else
    FMTLogInfo(@"Swift integration not available - cannot update recorders");
#endif
}

- (void)updateRecorderCombo:(id)recorder forIdentifier:(NSString *)identifier {
    // ShortcutRecorder removed - this method is deprecated
    // Keyboard shortcuts are handled by KeyboardShortcutManager
    FMTLogInfo(@"updateRecorderCombo called but ShortcutRecorder has been replaced");
    
    // Old implementation commented out:
    /*
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    KeyCombo combo;
    combo.code = [defaults integerForKey:KeyCodePrefKey(identifier)];
    combo.flags = [defaults integerForKey:ModifiersPrefKey(identifier)];
    [recorder setKeyCombo:combo];
    */
}

#pragma mark TabView delegate methods

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    // TODO: why not to use the tabViewItem
    if ([selectedTabIdentifier_ isEqualTo:kHotKeysTabViewItemIdentifier]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kDidStartEditingHotKeysPrefNotification object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:kDidFinishEditingHotKeysPrefNotification object:nil];
    }
}

#pragma mark Notification handling methods

- (void)windowMainStatusChanged_:(NSNotification *)notification {
    NSString *name = [notification name];

    if ([name isEqualToString:NSWindowDidBecomeMainNotification] && [selectedTabIdentifier_ isEqualToString:kHotKeysTabViewItemIdentifier]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kDidStartEditingHotKeysPrefNotification object:nil];
    } else if ([name isEqualToString:NSWindowDidResignMainNotification]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kDidFinishEditingHotKeysPrefNotification object:nil];
    }
}

@end
