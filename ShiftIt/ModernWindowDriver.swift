/*
 ShiftIt: Window Organizer for macOS
 Copyright (c) 2010-2025 Filip Krikava
 
 Modernized implementation using Swift and current macOS APIs
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

import Foundation
import Cocoa
import ApplicationServices
import ScreenCaptureKit

/// Modern window management driver using Accessibility API with Swift concurrency
@objc class ModernWindowDriver: NSObject, @unchecked Sendable {
    
    private let systemElement: AXUIElement
    
    /// Errors that can occur during window management
    enum WindowDriverError: LocalizedError {
        case accessibilityNotEnabled
        case noFocusedWindow
        case failedToGetGeometry
        case failedToSetGeometry
        case axError(AXError)
        case invalidWindow
        
        var errorDescription: String? {
            switch self {
            case .accessibilityNotEnabled:
                return "Accessibility permissions not granted"
            case .noFocusedWindow:
                return "No focused window found"
            case .failedToGetGeometry:
                return "Failed to get window geometry"
            case .failedToSetGeometry:
                return "Failed to set window geometry"
            case .axError(let error):
                return "Accessibility API error: \(error.rawValue)"
            case .invalidWindow:
                return "Invalid window reference"
            }
        }
    }
    
    @objc override init() {
        self.systemElement = AXUIElementCreateSystemWide()
        super.init()
    }
    
    /// Check if accessibility permissions are granted
    /// This is the most reliable method as of macOS 14+
    @objc static func checkAccessibilityPermissions() -> Bool {
        // Primary check using AXIsProcessTrusted()
        // This is the canonical way to check accessibility permissions
        let isTrusted = AXIsProcessTrusted()
        
        // Secondary verification: Actually test if we can use the API
        // This catches edge cases where the system reports trusted but API doesn't work
        // (e.g., during permission transitions, system bugs, or security policy conflicts)
        if isTrusted {
            let systemElement = AXUIElementCreateSystemWide()
            var roleRef: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(
                systemElement,
                kAXRoleAttribute as CFString,
                &roleRef
            )
            
            // Double-check: even if we got a role, verify it's not empty
            if error == .success, let role = roleRef as? String, !role.isEmpty {
                return true
            }
            
            // If verification failed, permissions might be in transition state
            // Return false to be safe
            return false
        }
        
        return false
    }
    
    /// Asynchronous permission check (recommended for UI updates)
    /// Performs the check off the main thread to avoid blocking
    @MainActor
    static func checkAccessibilityPermissionsAsync() async -> Bool {
        await Task.detached(priority: .userInitiated) {
            checkAccessibilityPermissions()
        }.value
    }
    
    /// Request accessibility permissions
    /// Opens System Settings to the appropriate pane
    @objc static func requestAccessibilityPermissions() {
        // Modern approach: Use URL to open System Settings directly to Privacy & Security
        if #available(macOS 13.0, *) {
            // macOS 13+ uses x-apple.systempreferences URL scheme with new settings IDs
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        } else {
            // Fallback for macOS 12 and earlier
            // Use string literal directly to avoid concurrency warnings with kAXTrustedCheckOptionPrompt
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }
    
    /// Get the focused window from the frontmost application
    @objc func getFocusedWindow() throws -> ModernWindow {
        // Get the frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            throw WindowDriverError.noFocusedWindow
        }
        
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
        // Get the focused window
        var focusedWindowRef: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowRef
        )
        
        guard error == .success, let windowElement = focusedWindowRef else {
            throw WindowDriverError.axError(error)
        }
        
        return ModernWindow(element: windowElement as! AXUIElement, driver: self)
    }
}

/// Represents a window that can be manipulated
@objc class ModernWindow: NSObject, @unchecked Sendable {
    
    private let element: AXUIElement
    private weak var driver: ModernWindowDriver?
    
    init(element: AXUIElement, driver: ModernWindowDriver) {
        self.element = element
        self.driver = driver
        super.init()
    }
    
    // MARK: - Geometry
    
    /// Get the window's current position and size (returns via output parameter for Objective-C compatibility)
    @objc func getGeometry(_ rect: UnsafeMutablePointer<NSRect>) throws {
        var position = CGPoint.zero
        var size = CGSize.zero
        
        // Get position
        var positionRef: CFTypeRef?
        var error = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef)
        guard error == .success, let positionValue = positionRef else {
            throw ModernWindowDriver.WindowDriverError.axError(error)
        }
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        
        // Get size
        var sizeRef: CFTypeRef?
        error = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
        guard error == .success, let sizeValue = sizeRef else {
            throw ModernWindowDriver.WindowDriverError.axError(error)
        }
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        
        rect.pointee = NSRect(origin: position, size: size)
    }
    
    /// Swift-only convenience method that returns NSRect directly
    func getGeometry() throws -> NSRect {
        var position = CGPoint.zero
        var size = CGSize.zero
        
        // Get position
        var positionRef: CFTypeRef?
        var error = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef)
        guard error == .success, let positionValue = positionRef else {
            throw ModernWindowDriver.WindowDriverError.axError(error)
        }
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        
        // Get size
        var sizeRef: CFTypeRef?
        error = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
        guard error == .success, let sizeValue = sizeRef else {
            throw ModernWindowDriver.WindowDriverError.axError(error)
        }
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        
        return NSRect(origin: position, size: size)
    }
    
    /// Set the window's position and size
    @objc func setGeometry(_ rect: NSRect) throws {
        // Set position
        var position = rect.origin
        let positionValue = AXValueCreate(.cgPoint, &position)!
        var error = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue)
        guard error == .success else {
            throw ModernWindowDriver.WindowDriverError.axError(error)
        }
        
        // Set size
        var size = rect.size
        let sizeValue = AXValueCreate(.cgSize, &size)!
        error = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        guard error == .success else {
            throw ModernWindowDriver.WindowDriverError.axError(error)
        }
    }
    
    // MARK: - Capabilities
    
    /// Check if the window can be moved
    @objc func canMove() -> Bool {
        return isAttributeSettable(kAXPositionAttribute as CFString)
    }
    
    /// Check if the window can be resized
    @objc func canResize() -> Bool {
        return isAttributeSettable(kAXSizeAttribute as CFString)
    }
    
    /// Check if the window has a zoom button
    @objc func canZoom() -> Bool {
        return attributeExists(kAXZoomButtonAttribute as CFString)
    }
    
    /// Check if the window supports full screen
    @objc func canEnterFullScreen() -> Bool {
        return isAttributeSettable("AXFullScreen" as CFString)
    }
    
    // MARK: - Actions
    
    /// Toggle the window's zoom state
    @objc func toggleZoom() throws {
        var button: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXZoomButtonAttribute as CFString, &button)
        guard error == .success, let zoomButton = button else {
            throw ModernWindowDriver.WindowDriverError.axError(error)
        }
        
        let pressError = AXUIElementPerformAction(zoomButton as! AXUIElement, kAXPressAction as CFString)
        guard pressError == .success else {
            throw ModernWindowDriver.WindowDriverError.axError(pressError)
        }
    }
    
    /// Toggle full screen mode
    @objc func toggleFullScreen() throws {
        var fullScreenRef: CFTypeRef?
        var error = AXUIElementCopyAttributeValue(element, "AXFullScreen" as CFString, &fullScreenRef)
        guard error == .success, let fullScreenValue = fullScreenRef else {
            throw ModernWindowDriver.WindowDriverError.axError(error)
        }
        
        let currentFullScreen = fullScreenValue as! CFBoolean
        let newFullScreen: CFBoolean = (currentFullScreen == kCFBooleanTrue) ? kCFBooleanFalse : kCFBooleanTrue
        
        error = AXUIElementSetAttributeValue(element, "AXFullScreen" as CFString, newFullScreen)
        guard error == .success else {
            throw ModernWindowDriver.WindowDriverError.axError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func isAttributeSettable(_ attribute: CFString) -> Bool {
        var settable: DarwinBoolean = false
        let error = AXUIElementIsAttributeSettable(element, attribute, &settable)
        return error == .success && settable.boolValue
    }
    
    private func attributeExists(_ attribute: CFString) -> Bool {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)
        return error == .success
    }
}

// MARK: - Objective-C Bridging Helpers

extension ModernWindowDriver {
    
    /// Objective-C compatible method to get focused window
    @objc func findFocusedWindow() throws -> ModernWindow {
        return try getFocusedWindow()
    }
    
    /// Objective-C compatible method to check if window can be moved
    @objc func canMove(_ window: ModernWindow) -> Bool {
        return window.canMove()
    }
    
    /// Objective-C compatible method to check if window can be resized
    @objc func canResize(_ window: ModernWindow) -> Bool {
        return window.canResize()
    }
}

// MARK: - Screen Management Helpers

extension ModernWindowDriver {
    
    /// Get the screen containing the window
    @objc static func screen(for window: ModernWindow) -> NSScreen? {
        guard let geometry = try? window.getGeometry() else {
            return nil
        }
        
        return NSScreen.screens.first { screen in
            screen.frame.intersects(geometry)
        } ?? NSScreen.main
    }
    
    /// Position a window to fill half the screen (left side)
    @objc func positionWindowLeft(_ window: ModernWindow) throws {
        guard let screen = Self.screen(for: window) else {
            throw WindowDriverError.invalidWindow
        }
        
        let visibleFrame = screen.visibleFrame
        let newFrame = NSRect(
            x: visibleFrame.origin.x,
            y: visibleFrame.origin.y,
            width: visibleFrame.width / 2,
            height: visibleFrame.height
        )
        
        try window.setGeometry(newFrame)
    }
    
    /// Position a window to fill half the screen (right side)
    @objc func positionWindowRight(_ window: ModernWindow) throws {
        guard let screen = Self.screen(for: window) else {
            throw WindowDriverError.invalidWindow
        }
        
        let visibleFrame = screen.visibleFrame
        let newFrame = NSRect(
            x: visibleFrame.origin.x + visibleFrame.width / 2,
            y: visibleFrame.origin.y,
            width: visibleFrame.width / 2,
            height: visibleFrame.height
        )
        
        try window.setGeometry(newFrame)
    }
    
    /// Position a window to fill the entire screen
    @objc func maximizeWindow(_ window: ModernWindow) throws {
        guard let screen = Self.screen(for: window) else {
            throw WindowDriverError.invalidWindow
        }
        
        let visibleFrame = screen.visibleFrame
        try window.setGeometry(visibleFrame)
    }
    
    /// Center a window on its current screen
    @objc func centerWindow(_ window: ModernWindow) throws {
        guard let screen = Self.screen(for: window) else {
            throw WindowDriverError.invalidWindow
        }
        
        let currentGeometry = try window.getGeometry()
        let visibleFrame = screen.visibleFrame
        
        let newOrigin = NSPoint(
            x: visibleFrame.origin.x + (visibleFrame.width - currentGeometry.width) / 2,
            y: visibleFrame.origin.y + (visibleFrame.height - currentGeometry.height) / 2
        )
        
        let newFrame = NSRect(origin: newOrigin, size: currentGeometry.size)
        try window.setGeometry(newFrame)
    }
}
