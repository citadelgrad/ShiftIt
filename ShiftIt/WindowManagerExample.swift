/*
 ShiftIt: Window Organizer for macOS
 Modern Swift Example Implementation
 
 This file demonstrates how to use the ModernWindowDriver
 with modern Swift patterns and best practices.
*/

import Foundation
import Cocoa
import Combine

/// Manager class that coordinates window management operations
@MainActor
class WindowManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var hasAccessibilityPermissions = false
    @Published var lastError: Error?
    @Published var isProcessing = false
    
    // MARK: - Private Properties
    
    private let driver: ModernWindowDriver
    private var permissionCheckTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        self.driver = ModernWindowDriver()
        checkPermissions()
        startPermissionMonitoring()
    }
    
    deinit {
        // Timer cleanup handled by weak self in closure
        // No direct access needed here
    }
    
    // MARK: - Permission Management
    
    func checkPermissions() {
        hasAccessibilityPermissions = ModernWindowDriver.checkAccessibilityPermissions()
    }
    
    func requestPermissions() {
        ModernWindowDriver.requestAccessibilityPermissions()
        
        // Check again after a delay
        Task {
            try? await Task.sleep(for: .seconds(1))
            checkPermissions()
        }
    }
    
    private func startPermissionMonitoring() {
        // Check permissions every 5 seconds
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermissions()
            }
        }
    }
    
    // MARK: - Window Operations
    
    /// Position the focused window to the left half of the screen
    func shiftLeft() async {
        await performWindowOperation { [driver] window in
            try driver.positionWindowLeft(window)
        }
    }
    
    /// Position the focused window to the right half of the screen
    func shiftRight() async {
        await performWindowOperation { [driver] window in
            try driver.positionWindowRight(window)
        }
    }
    
    /// Maximize the focused window
    func maximize() async {
        await performWindowOperation { [driver] window in
            try driver.maximizeWindow(window)
        }
    }
    
    /// Center the focused window on its screen
    func center() async {
        await performWindowOperation { [driver] window in
            try driver.centerWindow(window)
        }
    }
    
    /// Toggle full screen mode
    func toggleFullScreen() async {
        await performWindowOperation { window in
            guard window.canEnterFullScreen() else {
                throw WindowOperationError.operationNotSupported("Full screen not supported")
            }
            try window.toggleFullScreen()
        }
    }
    
    /// Toggle zoom (maximize/restore)
    func toggleZoom() async {
        await performWindowOperation { window in
            guard window.canZoom() else {
                throw WindowOperationError.operationNotSupported("Zoom not supported")
            }
            try window.toggleZoom()
        }
    }
    
    // MARK: - Advanced Operations
    
    /// Move window to a specific screen
    func moveToScreen(_ screen: NSScreen) async {
        // Capture screen properties to avoid Sendable issues
        let screenFrame = screen.visibleFrame
        
        await performWindowOperation { window in
            let currentGeometry = try window.getGeometry()
            
            // Calculate new position maintaining relative position on new screen
            let newGeometry = NSRect(
                x: screenFrame.origin.x + (screenFrame.width - currentGeometry.width) / 2,
                y: screenFrame.origin.y + (screenFrame.height - currentGeometry.height) / 2,
                width: currentGeometry.width,
                height: currentGeometry.height
            )
            
            try window.setGeometry(newGeometry)
        }
    }
    
    /// Resize window to specific percentage of screen
    func resizeToPercentage(width: CGFloat, height: CGFloat) async {
        await performWindowOperation { window in
            let currentGeometry = try window.getGeometry()
            guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(currentGeometry) }) else {
                throw WindowOperationError.noScreen
            }
            
            let visibleFrame = screen.visibleFrame
            let newSize = NSSize(
                width: visibleFrame.width * width,
                height: visibleFrame.height * height
            )
            
            // Center on screen with new size
            let newOrigin = NSPoint(
                x: visibleFrame.origin.x + (visibleFrame.width - newSize.width) / 2,
                y: visibleFrame.origin.y + (visibleFrame.height - newSize.height) / 2
            )
            
            let newGeometry = NSRect(origin: newOrigin, size: newSize)
            try window.setGeometry(newGeometry)
        }
    }
    
    /// Move window to specific quadrant of screen
    func moveToQuadrant(_ quadrant: ScreenQuadrant) async {
        await performWindowOperation { window in
            guard let screen = ModernWindowDriver.screen(for: window) else {
                throw WindowOperationError.noScreen
            }
            
            let visibleFrame = screen.visibleFrame
            let halfWidth = visibleFrame.width / 2
            let halfHeight = visibleFrame.height / 2
            
            let newFrame: NSRect
            switch quadrant {
            case .topLeft:
                newFrame = NSRect(
                    x: visibleFrame.origin.x,
                    y: visibleFrame.origin.y + halfHeight,
                    width: halfWidth,
                    height: halfHeight
                )
            case .topRight:
                newFrame = NSRect(
                    x: visibleFrame.origin.x + halfWidth,
                    y: visibleFrame.origin.y + halfHeight,
                    width: halfWidth,
                    height: halfHeight
                )
            case .bottomLeft:
                newFrame = NSRect(
                    x: visibleFrame.origin.x,
                    y: visibleFrame.origin.y,
                    width: halfWidth,
                    height: halfHeight
                )
            case .bottomRight:
                newFrame = NSRect(
                    x: visibleFrame.origin.x + halfWidth,
                    y: visibleFrame.origin.y,
                    width: halfWidth,
                    height: halfHeight
                )
            }
            
            try window.setGeometry(newFrame)
        }
    }
    
    // MARK: - Helper Methods
    
    private func performWindowOperation(_ operation: @escaping @Sendable (ModernWindow) async throws -> Void) async {
        guard hasAccessibilityPermissions else {
            lastError = WindowOperationError.noPermissions
            return
        }
        
        isProcessing = true
        lastError = nil
        
        do {
            let window = try driver.getFocusedWindow()
            try await operation(window)
        } catch {
            lastError = error
            print("Window operation failed: \(error.localizedDescription)")
        }
        
        isProcessing = false
    }
    
    // MARK: - Window Information
    
    /// Get information about the currently focused window
    func getFocusedWindowInfo() async -> WindowInfo? {
        guard hasAccessibilityPermissions else { return nil }
        
        do {
            let window = try driver.getFocusedWindow()
            let geometry = try window.getGeometry()
            
            return WindowInfo(
                geometry: geometry,
                canMove: window.canMove(),
                canResize: window.canResize(),
                canZoom: window.canZoom(),
                canEnterFullScreen: window.canEnterFullScreen()
            )
        } catch {
            lastError = error
            return nil
        }
    }
}

// MARK: - Supporting Types

enum ScreenQuadrant {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

enum WindowOperationError: LocalizedError {
    case noPermissions
    case noScreen
    case operationNotSupported(String)
    
    var errorDescription: String? {
        switch self {
        case .noPermissions:
            return "Accessibility permissions not granted. Please enable in System Settings."
        case .noScreen:
            return "Could not determine window's screen"
        case .operationNotSupported(let reason):
            return "Operation not supported: \(reason)"
        }
    }
}

struct WindowInfo {
    let geometry: NSRect
    let canMove: Bool
    let canResize: Bool
    let canZoom: Bool
    let canEnterFullScreen: Bool
}

// MARK: - Global Keyboard Shortcuts Integration

/// Example of how to integrate with macOS keyboard shortcuts
@MainActor
class KeyboardShortcutManager {
    
    private let windowManager: WindowManager
    private var eventMonitor: Any?
    
    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }
    
    func startMonitoring() {
        // Register global keyboard shortcuts
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            
            // Check for modifier keys + arrow keys
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // Example: Cmd+Opt+Arrow keys
            if modifiers.contains([.command, .option]) {
                Task {
                    switch event.keyCode {
                    case 123: // Left arrow
                        await self.windowManager.shiftLeft()
                    case 124: // Right arrow
                        await self.windowManager.shiftRight()
                    case 125: // Down arrow
                        await self.windowManager.maximize()
                    case 126: // Up arrow
                        await self.windowManager.center()
                    default:
                        break
                    }
                }
            }
        }
    }
    
    nonisolated func stopMonitoring() {
        Task { @MainActor in
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - Usage Example in App Delegate

/*
 Example integration in your AppDelegate:
 
 @NSApplicationMain
 class AppDelegate: NSObject, NSApplicationDelegate {
     
     private let windowManager = WindowManager()
     private var shortcutManager: KeyboardShortcutManager?
     
     func applicationDidFinishLaunching(_ notification: Notification) {
         // Check and request permissions
         if !windowManager.hasAccessibilityPermissions {
             windowManager.requestPermissions()
         }
         
         // Set up keyboard shortcuts
         shortcutManager = KeyboardShortcutManager(windowManager: windowManager)
         shortcutManager?.startMonitoring()
     }
     
     func applicationWillTerminate(_ notification: Notification) {
         shortcutManager?.stopMonitoring()
     }
     
     // Menu actions
     @IBAction func shiftLeft(_ sender: Any) {
         Task {
             await windowManager.shiftLeft()
         }
     }
     
     @IBAction func shiftRight(_ sender: Any) {
         Task {
             await windowManager.shiftRight()
         }
     }
     
     @IBAction func maximize(_ sender: Any) {
         Task {
             await windowManager.maximize()
         }
     }
 }
*/
