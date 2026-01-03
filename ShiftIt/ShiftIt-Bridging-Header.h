/*
 ShiftIt: Window Organizer for macOS
 Copyright (c) 2010-2025 Filip Krikava
 
 Swift-Objective-C Bridging Header
 
 This header exposes Objective-C types to Swift code.
*/

#ifndef ShiftIt_Bridging_Header_h
#define ShiftIt_Bridging_Header_h

// Core protocols and types
#import "SIWindowDriver.h"
#import "SIWindow.h"
#import "SIWindowInfo.h"
#import "SIScreen.h"

// Existing driver (for gradual migration)
#import "AXWindowDriver.h"

// Utilities
#import "SIDefines.h"

// Format/logging (if needed)
#ifdef FMT_AVAILABLE
#import "FMT.h"
#endif

// Sparkle (auto-update framework)
#import <Sparkle/Sparkle.h>

#endif /* ShiftIt_Bridging_Header_h */
