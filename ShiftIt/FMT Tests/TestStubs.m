// Stub definitions for extern constants needed by the test target.
// These are normally defined in ShiftItAppDelegate.m and SIWindowManager.m,
// which have too many dependencies to compile into the test bundle.

#import <Foundation/Foundation.h>

// From ShiftItAppDelegate.m - preference keys
NSString *const kMutipleActionsCycleWindowSizes = @"multipleActionsCycleWindowSizes";
NSString *const kSizeDeltaTypePrefKey = @"sizeDeltaType";
NSString *const kFixedSizeWidthDeltaPrefKey = @"fixedSizeWidthDelta";
NSString *const kFixedSizeHeightDeltaPrefKey = @"fixedSizeHeightDelta";
NSString *const kWindowSizeDeltaPrefKey = @"windowSizeDelta";
NSString *const kScreenSizeDeltaPrefKey = @"screenSizeDelta";
NSString *const kMarginsEnabledPrefKey = @"marginsEnabled";
NSString *const kLeftMarginPrefKey = @"leftMargin";
NSString *const kTopMarginPrefKey = @"topMargin";
NSString *const kBottomMarginPrefKey = @"bottomMargin";
NSString *const kRightMarginPrefKey = @"rightMargin";

// From ShiftItAppDelegate.m - error domain
NSString *const SIAErrorDomain = @"org.shiftitapp.app.error";

// From SIWindowManager.m - error domain and codes
NSString *const SIErrorDomain = @"org.shiftitapp.shifit.error";
NSInteger const kShiftItManagerFailureErrorCode = 2014;
NSInteger const kWindowManagerFailureErrorCode = 20101;
NSInteger const kShiftItActionFailureErrorCode = 20103;
