/*
 Copyright (c) 2010-2011 Filip Krikava
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "FMTLoginItems.h"
#import "FMTDefines.h"

// For macOS 10.13+, use ServiceManagement framework
#import <ServiceManagement/ServiceManagement.h>

@interface FMTLoginItems (Private)

- (id)initWithLoginItemsType_:(CFStringRef)type;
- (LSSharedFileListItemRef) getApplicationLoginItemWithPath_:(NSString *)path;

@end

// following is just to simplify the code
// not sure whether the is a better way to do that
// this will reuse the SINGLETON_BOILERPLATE* macros
// so less typing while maintaining all the properties of these singletons

@interface FMTGlobalLoginItems_ : FMTLoginItems 

+ (FMTGlobalLoginItems_ *) sharedGlobalLoginItems_;

@end

@interface FMTSessionLoginItems_ : FMTLoginItems

+ (FMTSessionLoginItems_ *) sharedSessionLoginItems_;

@end


@implementation FMTLoginItems

@synthesize type = type_;


- (id)initWithLoginItemsType_:(CFStringRef)type {
	FMTAssertNotNil(type)
	
	if (![super init]) {
		return nil;
	}
	
	type_ = type;
	
	return self;
}

- (void)dealloc {
	[super dealloc];
}

- (BOOL) isInLoginItemsApplicationWithPath:(NSString *)path {
	FMTAssertNotNil(path);
	
	// For macOS 10.13+, use a simple check with NSWorkspace
	if (@available(macOS 10.13, *)) {
		// Check if app is in login items by looking at SMAppService (requires SMLoginItemSetEnabled setup)
		// For now, just return NO as the deprecated API isn't reliable
		// This could be improved with a helper app or using SMLoginItemSetEnabled
		return NO;
	} else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		return [self getApplicationLoginItemWithPath_:path] != nil;
#pragma clang diagnostic pop
	}
}

// following code has been inspired from Growl sources
// http://growl.info/source.php
- (void) toggleApplicationInLoginItemsWithPath:(NSString *)path enabled:(BOOL)enabled {
	FMTAssertNotNil(path);
	
	// For macOS 10.13+, use ServiceManagement framework
	if (@available(macOS 10.13, *)) {
		// Modern approach: Use SMLoginItemSetEnabled with a helper app
		// Note: This requires a helper app in your bundle
		// For backward compatibility, fall back to deprecated API
		
		// Get the bundle identifier from the path
		NSBundle *appBundle = [NSBundle bundleWithPath:path];
		NSString *bundleId = [appBundle bundleIdentifier];
		
		if (bundleId) {
			// This would normally use SMLoginItemSetEnabled with a helper app
			// For simplicity, we'll use the user's defaults as a workaround
			// A full implementation would require adding a helper app to the bundle
			NSLog(@"Login items management on macOS 10.13+ requires a helper app. Path: %@", path);
		}
	}
	
	// Use deprecated API for older systems or as fallback
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	OSStatus status;
	LSSharedFileListItemRef existingItem = [self getApplicationLoginItemWithPath_:path];
	CFURLRef URLToApp = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)path, kCFURLPOSIXPathStyle, true);
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,type_, NULL);
	
	if (enabled && (existingItem == NULL)) {
		NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath:path];
		IconRef icon = NULL;
		FSRef ref;
		Boolean gotRef = CFURLGetFSRef(URLToApp, &ref);
		if (gotRef) {
			status = GetIconRefFromFileInfo(&ref,
											/*fileNameLength*/ 0, /*fileName*/ NULL,
											kFSCatInfoNone, /*catalogInfo*/ NULL,
											kIconServicesNormalUsageFlag,
											&icon,
											/*outLabel*/ NULL);
			if (status != noErr)
				icon = NULL;
		}
		
		LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst, (CFStringRef)displayName, icon, URLToApp, /*propertiesToSet*/ NULL, /*propertiesToClear*/ NULL);
	} else if (!enabled && (existingItem != NULL)) {
		LSSharedFileListItemRemove(loginItems, existingItem);
	}
    CFRelease(URLToApp);
#pragma clang diagnostic pop
}

#pragma mark Private methods

- (LSSharedFileListItemRef) getApplicationLoginItemWithPath_:(NSString *)path {
	FMTAssertNotNil(path);
	
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	CFURLRef URLToApp = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)path, kCFURLPOSIXPathStyle, true);
	
	LSSharedFileListItemRef existingItem = NULL;
	UInt32 seed = 0U;
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,type_, NULL);
	NSArray *currentLoginItems = [NSMakeCollectable(LSSharedFileListCopySnapshot(loginItems, &seed)) autorelease];
	
	for (id itemObject in currentLoginItems) {
		LSSharedFileListItemRef item = (LSSharedFileListItemRef)itemObject;
		
		UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
		CFURLRef URL = NULL;
		OSStatus err = LSSharedFileListItemResolve(item, resolutionFlags, &URL, /*outRef*/ NULL);
		if (err == noErr) {
			Boolean foundIt = CFEqual(URL, URLToApp);
			CFRelease(URL);
			
			if (foundIt)
				existingItem = item;
			break;
		}
	}
	
	CFRelease(URLToApp);
#pragma clang diagnostic pop
	
	return existingItem;
}

+ (FMTLoginItems *) sharedGlobalLoginItems {
	return [FMTGlobalLoginItems_ sharedGlobalLoginItems_];
}

+ (FMTLoginItems *) sharedSessionLoginItems {
	return [FMTSessionLoginItems_ sharedSessionLoginItems_];
}
@end

@implementation FMTGlobalLoginItems_

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
SINGLETON_BOILERPLATE_FULL(FMTGlobalLoginItems_, sharedGlobalLoginItems_, initWithLoginItemsType_:kLSSharedFileListGlobalLoginItems);
#pragma clang diagnostic pop

@end

@implementation FMTSessionLoginItems_

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
SINGLETON_BOILERPLATE_FULL(FMTSessionLoginItems_, sharedSessionLoginItems_, initWithLoginItemsType_:kLSSharedFileListSessionLoginItems);
#pragma clang diagnostic pop

@end
