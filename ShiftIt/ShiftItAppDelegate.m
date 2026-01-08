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

#import "ShiftItAppDelegate.h"
#import "ShiftItApp.h"
#import "WindowGeometryShiftItAction.h"
#import "DefaultShiftItActions.h"
#import "PreferencesWindowController.h"
#import "AXWindowDriver.h"
#import "SIWindowManager.h"
#import "FMT/FMTNSFileManager+DirectoryLocations.h"
#import <ApplicationServices/ApplicationServices.h>

// Import Sparkle if it's being used
#if __has_include(<Sparkle/Sparkle.h>)
#import <Sparkle/SPUStandardUpdaterController.h>
#import <Sparkle/SPUUpdater.h>
#import <Sparkle/SPUStandardUserDriverDelegate.h>
#import <Sparkle/SPUUserUpdateState.h>
#import <Sparkle/SUAppcastItem.h>
#endif

// the name of the plist file containing the preference defaults
NSString *const kShiftItUserDefaults = @"ShiftIt-defaults";

// preferences
NSString *const kHasStartedBeforePrefKey = @"hasStartedBefore";
NSString *const kShowMenuPrefKey = @"shiftItshowMenu";
NSString *const kMarginsEnabledPrefKey = @"marginsEnabled";
NSString *const kLeftMarginPrefKey = @"leftMargin";
NSString *const kTopMarginPrefKey = @"topMargin";
NSString *const kBottomMarginPrefKey = @"bottomMargin";
NSString *const kRightMarginPrefKey = @"rightMargin";
NSString *const kSizeDeltaTypePrefKey = @"sizeDeltaType";
NSString *const kFixedSizeWidthDeltaPrefKey = @"fixedSizeWidthDelta";
NSString *const kFixedSizeHeightDeltaPrefKey = @"fixedSizeHeightDelta";
NSString *const kWindowSizeDeltaPrefKey = @"windowSizeDelta";
NSString *const kScreenSizeDeltaPrefKey = @"screenSizeDelta";
NSString *const kMutipleActionsCycleWindowSizes = @"multipleActionsCycleWindowSizes";

// AX Driver Options
// TODO: should be moved to AX driver
NSString *const kAXIncludeDrawersPrefKey = @"axdriver_includeDrawers";
NSString *const kAXDriverConvergePrefKey = @"axdriver_converge";
NSString *const kAXDriverDelayBetweenOperationsPrefKey = @"axdriver_delayBetweenOperations";

// notifications
NSString *const kShowPreferencesRequestNotification = @"org.shiftitapp.shiftit.notifiactions.showPreferences";

// icon
NSString *const kSIIconName = @"ShiftItMenuIcon";
NSString *const kSIReversedIconName = @"ShiftItMenuIconReversed";

NSString *const kUsageStatisticsFileName = @"usage-statistics.plist";

// the size that should be reserved for the menu item in the system menu in px
NSInteger const kSIMenuItemSize = 30;

NSInteger const kSIMenuUITagPrefix = 2000;

// even if the user settings is higher - this defines the absolute max of tries
NSInteger const kMaxNumberOfTries = 20;

// error related
NSString *const SIAErrorDomain = @"org.shiftitapp.app.error";

const CFAbsoluteTime kMinimumTimeBetweenActionInvocations = 0.25; // in seconds

// TODO: move to the class
NSDictionary *allShiftActions = nil;

@interface SIUsageStatistics : NSObject {
@private
    NSMutableDictionary *statistics_;

}

- (id)initFromFile:(NSString *)path;

- (void)increment:(NSString *)key;

- (void)saveToFile:(NSString *)path;

- (NSArray *)toSparkle;

@end

@implementation SIUsageStatistics

- (id)initFromFile:(NSString *)path {
    if (![super init]) {
        return nil;
    }

    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm fileExistsAtPath:path]) {
        FMTLogInfo(@"Usage statistics do not exists");
        statistics_ = [[NSMutableDictionary dictionary] retain];
    } else {
        NSData *data = nil;
        NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;

        data = [fm contentsAtPath:path];
        NSError *deserializationError = nil;
        NSDictionary *d = (NSDictionary *) [NSPropertyListSerialization
                propertyListWithData:data
                             options:NSPropertyListMutableContainersAndLeaves
                              format:&format
                               error:&deserializationError];

        if (d) {
            FMTLogInfo(@"Loaded usage statistics from: %@", path);
            statistics_ = [[NSMutableDictionary dictionaryWithDictionary:d] retain];
        } else {
            FMTLogError(@"Error reading usage statistics: %@ from: %@ format: %ld",
                        deserializationError ? [deserializationError localizedDescription] : @"Unknown error",
                        path, NSPropertyListBinaryFormat_v1_0);
            statistics_ = [[NSMutableDictionary dictionary] retain];
        }
    }

    return self;
}

- (void)dealloc {
    [statistics_ release];

    [super dealloc];
}

- (void)increment:(NSString *)key {
    NSInteger value = 0;

    id stat = [statistics_ objectForKey:key];
    if (stat) {
        value = [(NSNumber *) stat integerValue];
    }

    stat = [NSNumber numberWithInteger:(value + 1)];
    [statistics_ setObject:stat forKey:key];
}

- (void)saveToFile:(NSString *)path {
    NSError *serializationError = nil;

    NSData *data = [NSPropertyListSerialization dataWithPropertyList:statistics_
                                                               format:NSPropertyListBinaryFormat_v1_0
                                                              options:0
                                                                error:&serializationError];

    if (data) {
        [data writeToFile:path atomically:YES];
        FMTLogInfo(@"Save usage statitics to: %@", path);
    } else {
        FMTLogError(@"Unable to serialize usage statistics to: %@ - %@", path,
                    serializationError ? [serializationError localizedDescription] : @"Unknown error");
    }
}


- (NSArray *)toSparkle {
    NSMutableArray *a = [NSMutableArray array];

    [statistics_ enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        [a addObject:FMTEncodeForSparkle(key, value, key, value)];
    }];

    return [NSArray arrayWithArray:a];
}
@end

@implementation ShiftItAction

@synthesize identifier = identifier_;
@synthesize label = label_;
@synthesize uiTag = uiTag_;
@synthesize delegate = delegate_;

- (id)initWithIdentifier:(NSString *)identifier label:(NSString *)label uiTag:(NSInteger)uiTag delegate:(id <SIActionDelegate>)delegate {
    FMTAssertNotNil(identifier);
    FMTAssertNotNil(label);
    FMTAssert(uiTag > 0, @"uiTag must be greater than 0");
    FMTAssertNotNil(delegate);

    if (![super init]) {
        return nil;
    }

    identifier_ = [identifier retain];
    label_ = [label retain];
    uiTag_ = uiTag;
    delegate_ = [delegate retain];

    return self;
}

- (void)dealloc {
    [identifier_ release];
    [label_ release];
    [delegate_ release];

    [super dealloc];
}

- (BOOL)execute:(id <SIWindowContext>)windowContext error:(NSError **)error {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:FMTStr(@"You must override %@ in a subclass", NSStringFromSelector(_cmd))
                                 userInfo:nil];
}

@end

@interface ShiftItAppDelegate ()
#if __has_include(<Sparkle/Sparkle.h>)
<SPUStandardUserDriverDelegate>
#endif

- (void)checkAuthorization;

- (void)firstLaunch_;

- (void)setupMenuBar_;

- (void)initializeActions_;

- (void)registerHotKeys_;

- (void)invokeShiftItAction:(NSString *)identifier;

- (IBAction)shiftItMenuAction:(id)sender;

@end

@implementation ShiftItAppDelegate {
@private
    PreferencesWindowController *preferencesController_;
    FMTHotKeyManager *hotKeyManager_;
    SIWindowManager *windowManager_;

    SIUsageStatistics *usageStatistics_;
    NSMutableDictionary *allHotKeys_;
    BOOL paused_;

    NSStatusItem *statusItem_;

    // to keep some pause between action invocations
    CFAbsoluteTime beforeNow_;
    
    // Track if we've shown the permission prompt
    BOOL hasShownPermissionPrompt_;
    NSTimer *permissionCheckTimer_;
    
#if __has_include(<Sparkle/Sparkle.h>)
    // Sparkle updater controller
    SPUStandardUpdaterController *updaterController_;
#endif
}

+ (void)initialize {
    // register defaults - we assume that the installation is correct
    NSString *path = FMTGetMainBundleResourcePath(kShiftItUserDefaults, @"plist");
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:d];
}

- (id)init {
    if (![super init]) {
        return nil;
    }

    allHotKeys_ = [[NSMutableDictionary alloc] init];
    NSString *usageStatisticsFile = [[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingPathComponent:kUsageStatisticsFileName];
    usageStatistics_ = [[SIUsageStatistics alloc] initFromFile:usageStatisticsFile];

    beforeNow_ = CFAbsoluteTimeGetCurrent();

    return self;
}

- (void)dealloc {
    [allShiftActions release];
    [windowManager_ release];
    [allHotKeys_ release];
    [preferencesController_ release];
    [usageStatistics_ release];
    [hotKeyManager_ release];
    
#if __has_include(<Sparkle/Sparkle.h>)
    [updaterController_ release];
#endif
    
    if (permissionCheckTimer_) {
        [permissionCheckTimer_ invalidate];
        permissionCheckTimer_ = nil;
    }
    
    if (statusItem_) {
        [NSStatusBar.systemStatusBar removeStatusItem:statusItem_];
        [statusItem_ release];
    }

    [super dealloc];
}

- (void)firstLaunch_ {
    FMTLogInfo(@"First run");
    
    FMTLoginItems *loginItems = [FMTLoginItems sharedSessionLoginItems];
    NSString *appPath = [[NSBundle mainBundle] bundlePath];

    if (![loginItems isInLoginItemsApplicationWithPath:appPath]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(@"Start ShiftIt automatically?", nil);
        alert.informativeText = NSLocalizedString(@"Would you like to have ShiftIt automatically started at a login time?", nil);
        [alert addButtonWithTitle:NSLocalizedString(@"Yes", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"No", nil)];
        
        NSModalResponse ret = [alert runModal];
        
        if (ret == NSAlertFirstButtonReturn) {
            [loginItems toggleApplicationInLoginItemsWithPath:appPath enabled:YES];
        }
    }
}

- (void)setupSparkleUpdater_ {
#if __has_include(<Sparkle/Sparkle.h>)
    FMTLogInfo(@"Setting up Sparkle updater with gentle reminders");

    // Create the updater controller programmatically
    // Pass self as userDriverDelegate to enable gentle reminders for background apps
    updaterController_ = [[SPUStandardUpdaterController alloc]
                          initWithStartingUpdater:YES
                          updaterDelegate:nil
                          userDriverDelegate:self];

    if (updaterController_) {
        SPUUpdater *updater = updaterController_.updater;

        FMTLogInfo(@"Sparkle updater configured - automatic checks: %d, can check: %d",
                  updater.automaticallyChecksForUpdates,
                  updater.canCheckForUpdates);
    } else {
        FMTLogError(@"Failed to create Sparkle updater controller");
    }
#else
    FMTLogInfo(@"Sparkle framework not available - skipping updater setup");
#endif
}

#if __has_include(<Sparkle/Sparkle.h>)
#pragma mark - SPUStandardUserDriverDelegate

// Enable gentle scheduled update reminders for background/menu bar apps
- (BOOL)supportsGentleScheduledUpdateReminders {
    return YES;
}

// Called when Sparkle is about to show an update
// For background apps, we bring the app to foreground so the user sees the update dialog
- (void)standardUserDriverWillHandleShowingUpdate:(BOOL)handleShowingUpdate
                                        forUpdate:(SUAppcastItem *)update
                                            state:(SPUUserUpdateState *)state {
    if (handleShowingUpdate) {
        FMTLogInfo(@"Sparkle will show update: %@", update.displayVersionString);

        // Bring app to foreground so user sees the update dialog
        // This is the key behavior for gentle reminders - ensuring visibility
        [NSApp activateIgnoringOtherApps:YES];
    }
}

// Called when the user responds to the update alert
- (void)standardUserDriverDidReceiveUserAttentionForUpdate:(SUAppcastItem *)update {
    FMTLogInfo(@"User acknowledged update: %@", update.displayVersionString);

    // Clear any visual indicators (badges, etc.)
    // For now, we don't have a badge to clear, but this is where you'd do it
}

// Called when the update session finishes
- (void)standardUserDriverWillFinishUpdateSession {
    FMTLogInfo(@"Update session finished");

    // Return to background mode (hide dock icon if needed)
    // For menu bar apps, no action needed - we're already in background mode
}

#endif

- (void)checkAuthorization {
    // Get app information for debugging
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *bundleID = bundle.bundleIdentifier;
    NSString *bundlePath = bundle.bundlePath;
    
    FMTLogInfo(@"Authorization check - App: %@", bundlePath);
    FMTLogInfo(@"Authorization check - Bundle ID: %@", bundleID);
    
    // First check without prompting to see current state
    BOOL isTrustedWithoutPrompt = AXIsProcessTrusted();
    FMTLogInfo(@"Authorization check - AXIsProcessTrusted (no prompt): %d", isTrustedWithoutPrompt);
    
    if (isTrustedWithoutPrompt) {
        FMTLogInfo(@"ShiftIt is already authorized");
        return;
    }
    
    // Not authorized - let the system show its native prompt ONLY
    FMTLogInfo(@"ShiftIt is not authorized - triggering system prompt");
    
    // This will show the system's native permission dialog
    // The user must enable permission and then RELAUNCH the app
    NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    
    hasShownPermissionPrompt_ = YES;
    
    // Start polling to detect when permission is granted
    // This allows us to offer an automatic relaunch
    FMTLogInfo(@"Starting permission check timer");
    permissionCheckTimer_ = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                             target:self
                                                           selector:@selector(checkPermissionGranted:)
                                                           userInfo:nil
                                                            repeats:YES];
    [permissionCheckTimer_ retain];
    
    FMTLogInfo(@"User must enable accessibility - will monitor for changes");
}

- (void)checkPermissionGranted:(NSTimer *)timer {
    if (AXIsProcessTrusted()) {
        // Permission was granted!
        FMTLogInfo(@"Permission granted! Offering to relaunch.");
        
        [permissionCheckTimer_ invalidate];
        permissionCheckTimer_ = nil;
        
        // Show relaunch dialog
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSApp activateIgnoringOtherApps:YES];
            
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = NSLocalizedString(@"Permission Granted!", nil);
            alert.informativeText = NSLocalizedString(@"ShiftIt now has Accessibility permission. Please relaunch the app for the changes to take effect.", nil);
            [alert addButtonWithTitle:NSLocalizedString(@"Relaunch Now", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Later", nil)];
            
            NSModalResponse response = [alert runModal];
            [alert release];
            
            if (response == NSAlertFirstButtonReturn) {
                FMTLogInfo(@"User chose to relaunch");
                [self relaunchApplication];
            } else {
                FMTLogInfo(@"User chose to relaunch later");
            }
        });
    }
}

- (void)relaunchApplication {
    // Get the app path
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    
    FMTLogInfo(@"Relaunching app from: %@", appPath);
    
    // Create a script that waits for this process to quit, then launches the app
    // Use the process ID to wait for this specific instance to quit
    int pid = [[NSProcessInfo processInfo] processIdentifier];
    NSString *script = [NSString stringWithFormat:
        @"(while /bin/ps -p %d > /dev/null; do /bin/sleep 0.1; done; /usr/bin/open -n '%@') &",
        pid, appPath];
    
    // Launch the script using /bin/sh
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:@[@"-c", script]];
    
    // Important: Don't wait for the task, let it run in background
    @try {
        [task launch];
        FMTLogInfo(@"Relaunch script started successfully");
    } @catch (NSException *exception) {
        FMTLogError(@"Failed to launch relaunch script: %@", exception);
    }
    [task release];
    
    // Give the script a moment to start, then quit
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), 
                   dispatch_get_main_queue(), ^{
        FMTLogInfo(@"Terminating current instance");
        [NSApp terminate:nil];
    });
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Initialize Sparkle updater with gentle reminders enabled
    [self setupSparkleUpdater_];
    
    // Initialize actions first
    [self initializeActions_];
    
    // Register hotkeys for all actions
    [self registerHotKeys_];
    
    // Setup menu bar icon
    [self setupMenuBar_];
    
    // Listen for hotkey changes from preferences
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(hotkeyChanged:)
                                                 name:kHotKeyChangedNotification
                                               object:nil];
    
    // Initial authorization check - will prompt if needed
    [self checkAuthorization];
    
    // Show first launch dialog if authorized
    if (AXIsProcessTrusted()) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        BOOL hasStartedBefore = [defaults boolForKey:kHasStartedBeforePrefKey];
        
        if (!hasStartedBefore) {
            [self firstLaunch_];
            [defaults setBool:YES forKey:kHasStartedBeforePrefKey];
            [defaults synchronize];
        }
    }
}

- (void)setupMenuBar_ {
    // Create the status item in the menu bar
    statusItem_ = [[NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength] retain];
    
    // Set the icon
    NSImage *icon = [NSImage imageNamed:kSIIconName];
    if (icon) {
        icon.template = YES; // Adapts to light/dark mode
        statusItem_.button.image = icon;
    }
    
    // Set the menu
    if (self.statusMenu_) {
        statusItem_.menu = self.statusMenu_;
        
        // Add menu items for all actions
        [self updateStatusMenuWithActions_];
    } else {
        FMTLogError(@"Status menu outlet is not connected in Interface Builder!");
    }
    
    FMTLogInfo(@"Menu bar icon set up");
}

- (void)updateStatusMenuWithActions_ {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    
    // Iterate through all menu items and connect actions
    for (NSMenuItem *item in self.statusMenu_.itemArray) {
        if (item.tag >= kSIMenuUITagPrefix) {
            // This is an action menu item - find the corresponding action
            NSString *identifier = nil;
            for (NSString *key in allShiftActions) {
                ShiftItAction *action = allShiftActions[key];
                if (action.uiTag == item.tag) {
                    identifier = key;
                    break;
                }
            }
            
            if (identifier) {
                // Set the action
                item.target = self;
                item.action = @selector(shiftItMenuAction:);
                item.representedObject = identifier;
                
                // Set the keyboard equivalent if available
                NSString *keyCodeKey = KeyCodePrefKey(identifier);
                NSString *modifiersKey = ModifiersPrefKey(identifier);
                
                NSInteger keyCode = [defaults integerForKey:keyCodeKey];
                NSUInteger modifiers = [defaults integerForKey:modifiersKey];
                
                if (keyCode > 0) {
                    item.keyEquivalentModifierMask = modifiers;
                    // Note: Proper key equivalent string would require keycode->character mapping
                }
            }
        }
    }
    
    FMTLogInfo(@"Updated status menu with action connections");
}

- (IBAction)shiftItMenuAction:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSString *identifier = [menuItem representedObject];
    
    if (identifier) {
        FMTLogInfo(@"Menu action triggered for: %@", identifier);
        [self invokeShiftItAction:identifier];
    } else {
        FMTLogError(@"Menu item has no identifier: %@", menuItem);
    }
}

- (void)initializeActions_ {
    FMTLogInfo(@"Initializing ShiftIt actions");
    
    NSMutableDictionary *actions = [NSMutableDictionary dictionary];
    id<SIActionDelegate> delegate;
    
    // Basic directional actions (left, right, top, bottom)
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItLeft] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"left" label:@"Left" uiTag:kSIMenuUITagPrefix+1 delegate:delegate] autorelease] forKey:@"left"];
    
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItRight] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"right" label:@"Right" uiTag:kSIMenuUITagPrefix+2 delegate:delegate] autorelease] forKey:@"right"];
    
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItTop] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"top" label:@"Top" uiTag:kSIMenuUITagPrefix+3 delegate:delegate] autorelease] forKey:@"top"];
    
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItBottom] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"bottom" label:@"Bottom" uiTag:kSIMenuUITagPrefix+4 delegate:delegate] autorelease] forKey:@"bottom"];
    
    // Corner actions (tl, tr, bl, br)
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItTopLeft] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"tl" label:@"Top Left" uiTag:kSIMenuUITagPrefix+5 delegate:delegate] autorelease] forKey:@"tl"];
    
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItTopRight] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"tr" label:@"Top Right" uiTag:kSIMenuUITagPrefix+6 delegate:delegate] autorelease] forKey:@"tr"];
    
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItBottomLeft] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"bl" label:@"Bottom Left" uiTag:kSIMenuUITagPrefix+7 delegate:delegate] autorelease] forKey:@"bl"];
    
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItBottomRight] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"br" label:@"Bottom Right" uiTag:kSIMenuUITagPrefix+8 delegate:delegate] autorelease] forKey:@"br"];
    
    // Third position actions (ltt, ltb, ctt, ctb, rtt, rtb, lt, ct, rt)
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItThirdTopLeft] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"ltt" label:@"Third Top Left" uiTag:kSIMenuUITagPrefix+9 delegate:delegate] autorelease] forKey:@"ltt"];
    
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItThirdBottomLeft] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"ltb" label:@"Third Bottom Left" uiTag:kSIMenuUITagPrefix+10 delegate:delegate] autorelease] forKey:@"ltb"];
    
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItThirdTopCenter] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"ctt" label:@"Third Top Center" uiTag:kSIMenuUITagPrefix+11 delegate:delegate] autorelease] forKey:@"ctt"];
    
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItThirdBottomCenter] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"ctb" label:@"Third Bottom Center" uiTag:kSIMenuUITagPrefix+12 delegate:delegate] autorelease] forKey:@"ctb"];
    
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItThirdTopRight] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"rtt" label:@"Third Top Right" uiTag:kSIMenuUITagPrefix+13 delegate:delegate] autorelease] forKey:@"rtt"];
    
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItThirdBottomRight] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"rtb" label:@"Third Bottom Right" uiTag:kSIMenuUITagPrefix+14 delegate:delegate] autorelease] forKey:@"rtb"];
    
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItThirdLeft] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"lt" label:@"Third Left" uiTag:kSIMenuUITagPrefix+15 delegate:delegate] autorelease] forKey:@"lt"];
    
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItThirdCenter] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"ct" label:@"Third Center" uiTag:kSIMenuUITagPrefix+16 delegate:delegate] autorelease] forKey:@"ct"];
    
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItThirdRight] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"rt" label:@"Third Right" uiTag:kSIMenuUITagPrefix+17 delegate:delegate] autorelease] forKey:@"rt"];
    
    // Center, zoom, maximize, fullScreen
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItCenter] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"center" label:@"Center" uiTag:kSIMenuUITagPrefix+18 delegate:delegate] autorelease] forKey:@"center"];
    
    delegate = [[[ToggleZoomShiftItAction alloc] init] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"zoom" label:@"Zoom" uiTag:kSIMenuUITagPrefix+19 delegate:delegate] autorelease] forKey:@"zoom"];
    
    delegate = [[[WindowGeometryShiftItAction alloc] initWithBlock:shiftItFullScreen] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"maximize" label:@"Maximize" uiTag:kSIMenuUITagPrefix+20 delegate:delegate] autorelease] forKey:@"maximize"];
    
    delegate = [[[ToggleFullScreenShiftItAction alloc] init] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"fullScreen" label:@"Full Screen" uiTag:kSIMenuUITagPrefix+21 delegate:delegate] autorelease] forKey:@"fullScreen"];
    
    // Size adjustment actions (increase, reduce)
    delegate = [[[IncreaseReduceShiftItAction alloc] initWithMode:YES] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"increase" label:@"Increase" uiTag:kSIMenuUITagPrefix+22 delegate:delegate] autorelease] forKey:@"increase"];
    
    delegate = [[[IncreaseReduceShiftItAction alloc] initWithMode:NO] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"reduce" label:@"Reduce" uiTag:kSIMenuUITagPrefix+23 delegate:delegate] autorelease] forKey:@"reduce"];
    
    // Screen switching actions (nextscreen, previousscreen)
    delegate = [[[ScreenChangeShiftItAction alloc] initWithMode:YES] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"nextscreen" label:@"Next Screen" uiTag:kSIMenuUITagPrefix+24 delegate:delegate] autorelease] forKey:@"nextscreen"];
    
    delegate = [[[ScreenChangeShiftItAction alloc] initWithMode:NO] autorelease];
    [actions setObject:[[[ShiftItAction alloc] initWithIdentifier:@"previousscreen" label:@"Previous Screen" uiTag:kSIMenuUITagPrefix+25 delegate:delegate] autorelease] forKey:@"previousscreen"];
    
    // Assign to the global variable (retain it since it's a global)
    allShiftActions = [[NSDictionary dictionaryWithDictionary:actions] retain];
    
    FMTLogInfo(@"Initialized %lu ShiftIt actions", (unsigned long)[allShiftActions count]);
}

- (void)registerHotKeys_ {
    FMTLogInfo(@"Registering hotkeys");
    
    if (!hotKeyManager_) {
        hotKeyManager_ = [[FMTHotKeyManager alloc] init];
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Register hotkeys for each action
    [allShiftActions enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, ShiftItAction *action, BOOL *stop) {
        NSString *keyCodeKey = KeyCodePrefKey(identifier);
        NSString *modifiersKey = ModifiersPrefKey(identifier);
        
        NSInteger keyCode = [defaults integerForKey:keyCodeKey];
        NSUInteger modifiers = [defaults integerForKey:modifiersKey];
        
        // Only register if there's a valid keycode
        if (keyCode > 0) {
            FMTHotKey *hotKey = [[FMTHotKey alloc] initWithKeyCode:keyCode modifiers:modifiers];
            
            // Register with the hotkey manager using selector-based API
            [hotKeyManager_ registerHotKey:hotKey 
                                   handler:@selector(invokeShiftItAction:) 
                                  provider:self 
                                  userData:identifier];
            
            [allHotKeys_ setObject:hotKey forKey:identifier];
            FMTLogDebug(@"Registered hotkey for action '%@': keyCode=%ld modifiers=%lu", 
                       identifier, (long)keyCode, (unsigned long)modifiers);
            
            [hotKey release];
        }
    }];
    
    FMTLogInfo(@"Registered %lu hotkeys", (unsigned long)[allHotKeys_ count]);
}

- (void)invokeShiftItAction:(NSString *)identifier {
    FMTLogInfo(@"Invoking action: %@", identifier);
    
    // Check authorization before attempting action
    if (!AXIsProcessTrusted()) {
        FMTLogError(@"Action invoked but app is not trusted (AXIsProcessTrusted = NO)");
        NSBeep();
        
        // Don't show prompt again if they already saw it - just fail silently
        // They can grant permission in System Settings when ready
        return;
    }
    
    // Throttle action invocations
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if ((now - beforeNow_) < kMinimumTimeBetweenActionInvocations) {
        FMTLogDebug(@"Action invocation throttled");
        return;
    }
    beforeNow_ = now;
    
    // Get the action
    ShiftItAction *action = [allShiftActions objectForKey:identifier];
    if (!action) {
        FMTLogError(@"Action not found: %@", identifier);
        return;
    }
    
    // Get or create the window manager with drivers
    if (!windowManager_) {
        FMTLogInfo(@"Creating window manager and AX driver");
        
        // Create the AX window driver
        NSError *driverError = nil;
        AXWindowDriver *driver = [[AXWindowDriver alloc] initWithError:&driverError];
        
        if (!driver) {
            FMTLogError(@"Failed to create AXWindowDriver: %@", driverError ? [driverError localizedDescription] : @"Unknown error");
            NSBeep();
            return;
        }
        
        // Configure driver settings from preferences
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        driver.shouldUseDrawers = [defaults boolForKey:kAXIncludeDrawersPrefKey];
        driver.converge = [defaults boolForKey:kAXDriverConvergePrefKey];
        driver.delayBetweenOperations = [defaults doubleForKey:kAXDriverDelayBetweenOperationsPrefKey];
        
        FMTLogInfo(@"AX driver configured: useDrawers=%d converge=%d delay=%f", 
                  driver.shouldUseDrawers, driver.converge, driver.delayBetweenOperations);
        
        // Create window manager with the driver
        NSArray *drivers = @[driver];
        windowManager_ = [[SIWindowManager alloc] initWithDrivers:drivers];
        [driver release];
        
        if (!windowManager_) {
            FMTLogError(@"Failed to create SIWindowManager");
            NSBeep();
            return;
        }
        
        FMTLogInfo(@"Window manager created successfully");
    }
    
    // Execute the action using the window manager
    NSError *error = nil;
    FMTLogDebug(@"Executing action delegate for '%@'", identifier);
    
    if (![windowManager_ executeAction:action.delegate error:&error]) {
        FMTLogError(@"Action execution failed: %@", error ? [error localizedDescription] : @"Unknown error");
        if (error) {
            FMTLogError(@"Error details: %@", [error fullDescription]);
        }
        NSBeep();
    } else {
        FMTLogInfo(@"Action '%@' executed successfully", identifier);
        [usageStatistics_ increment:identifier];
    }
}

- (IBAction)showPreferences:(id)sender {
    FMTLogInfo(@"Show preferences requested from sender: %@", sender);
    
    if (!preferencesController_) {
        FMTLogInfo(@"Creating new PreferencesWindowController");
        preferencesController_ = [[PreferencesWindowController alloc] init];
        
        if (!preferencesController_) {
            FMTLogError(@"Failed to create PreferencesWindowController!");
            return;
        }
        
        FMTLogInfo(@"PreferencesWindowController created successfully");
    }
    
    // Show the window
    FMTLogInfo(@"Showing preferences window");
    [preferencesController_ showWindow:self];
    
    NSWindow *prefWindow = preferencesController_.window;
    if (prefWindow) {
        FMTLogInfo(@"Preferences window exists, making key and order front");
        [prefWindow makeKeyAndOrderFront:self];
        prefWindow.level = NSNormalWindowLevel;
        [prefWindow center];
        FMTLogInfo(@"Preferences window frame: %@", NSStringFromRect(prefWindow.frame));
    } else {
        FMTLogError(@"Preferences window is nil!");
    }
    
    [NSApp activateIgnoringOtherApps:YES];
    
    // Warn if not authorized
    if (!AXIsFullyFunctional()) {
        FMTLogInfo(@"Showing preferences but app is not authorized yet");
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Remove observer
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // Save usage statistics
    if (usageStatistics_) {
        NSString *usageStatisticsFile = [[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingPathComponent:kUsageStatisticsFileName];
        [usageStatistics_ saveToFile:usageStatisticsFile];
    }
}

- (void)hotkeyChanged:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSString *identifier = [userInfo objectForKey:kActionIdentifierKey];
    NSInteger keyCode = [[userInfo objectForKey:kHotKeyKeyCodeKey] integerValue];
    NSUInteger modifiers = [[userInfo objectForKey:kHotKeyModifiersKey] unsignedIntegerValue];
    
    FMTLogInfo(@"Hotkey changed for action '%@': keyCode=%ld modifiers=%lu", 
               identifier, (long)keyCode, (unsigned long)modifiers);
    
    // Unregister old hotkey if it exists
    FMTHotKey *oldHotKey = [allHotKeys_ objectForKey:identifier];
    if (oldHotKey) {
        [hotKeyManager_ unregisterHotKey:oldHotKey];
        [allHotKeys_ removeObjectForKey:identifier];
        FMTLogDebug(@"Unregistered old hotkey for action '%@'", identifier);
    }
    
    // Register new hotkey if valid
    if (keyCode > 0) {
        FMTHotKey *newHotKey = [[FMTHotKey alloc] initWithKeyCode:keyCode modifiers:modifiers];
        
        [hotKeyManager_ registerHotKey:newHotKey 
                               handler:@selector(invokeShiftItAction:) 
                              provider:self 
                              userData:identifier];
        
        [allHotKeys_ setObject:newHotKey forKey:identifier];
        FMTLogInfo(@"Registered new hotkey for action '%@'", identifier);
        
        [newHotKey release];
    }
    
    // Update menu
    [self updateStatusMenuWithActions_];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    // When the dock icon is clicked, show preferences
    if (!flag) {
        [self showPreferences:nil];
    }
    return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    // Allow the app to terminate
    return NSTerminateNow;
}

// Small helper to verify Accessibility API is actually usable (not just the flag).
static BOOL AXIsFullyFunctional(void) {
    // The basic trust check is sufficient - if this returns YES, we have permission
    // Additional checks can fail for various legitimate reasons (e.g., no focused app)
    BOOL trusted = AXIsProcessTrusted();
    
    if (!trusted) {
        return NO;
    }
    
    // Do a lightweight verification that the API is actually working
    // by trying to create a system-wide element (this should always succeed if we're trusted)
    AXUIElementRef sys = AXUIElementCreateSystemWide();
    if (!sys) {
        return NO;
    }
    
    // Try to get any attribute to verify we have actual API access
    // We use a simple attribute that should always be available
    CFTypeRef value = NULL;
    AXError err = AXUIElementCopyAttributeValue(sys, kAXFocusedApplicationAttribute, &value);
    CFRelease(sys);
    
    // If we got a value or the error indicates we have access but there's just no value,
    // we're good. Common success codes:
    // - kAXErrorSuccess: Got the value
    // - kAXErrorNoValue: We have access, but the attribute has no value (OK)
    // - kAXErrorAttributeUnsupported: We have access, but attribute doesn't exist (OK for our test)
    BOOL hasAccess = (err == kAXErrorSuccess || 
                      err == kAXErrorNoValue || 
                      err == kAXErrorAttributeUnsupported);
    
    if (value) {
        CFRelease(value);
    }
    
    return hasAccess;
}

@end
