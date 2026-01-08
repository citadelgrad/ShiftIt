/*
 ShiftIt: Window Organizer for macOS
 Modern Swift 6 Example
 
 This file demonstrates modern Swift 6 patterns for window management
 targeting macOS 13+ (Ventura, Sonoma, Sequoia)
 
 Copyright (c) 2025 ShiftIt Project
 Licensed under GPL v3
*/

import Foundation
import Cocoa
import Combine
import OSLog

// MARK: - Logger

extension Logger {
    static let windowManager = Logger(subsystem: "org.shiftitapp.ShiftIt", category: "WindowManager")
}

// MARK: - Window Manager with Swift 6 Concurrency

/// Main actor-isolated window manager for thread-safe UI operations
@MainActor
final class ModernWindowManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var hasAccessibilityPermissions = false
    @Published private(set) var isProcessing = false
    @Published private(set) var lastError: WindowError?
    @Published private(set) var isCheckingPermissions = false
    
    // MARK: - Private Properties
    
    private let driver: ModernWindowDriver
    private var permissionMonitor: Task<Void, Never>?
    private var appActivationObserver: NSObjectProtocol?
    private var accessibilityChangeObserver: NSObjectProtocol?
    
    // MARK: - Custom Errors
    
    enum WindowError: LocalizedError, Sendable {
        case noPermissions
        case noFocusedWindow
        case operationFailed(String)
        case unsupportedOperation
        
        var errorDescription: String? {
            switch self {
            case .noPermissions:
                return "Accessibility permissions not granted. Enable in System Settings → Privacy & Security → Accessibility"
            case .noFocusedWindow:
                return "No window is currently focused"
            case .operationFailed(let reason):
                return "Operation failed: \(reason)"
            case .unsupportedOperation:
                return "This window doesn't support the requested operation"
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        self.driver = ModernWindowDriver()
        
        // Initial permission check
        checkPermissions()
        
        // Start monitoring permissions
        startPermissionMonitoring()
        
        // Monitor app activation to recheck permissions when returning from Settings
        setupAppActivationObserver()
        
        Logger.windowManager.info("ModernWindowManager initialized")
    }
    
    deinit {
        permissionMonitor?.cancel()
        if let observer = appActivationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = accessibilityChangeObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
    
    // MARK: - Permission Management
    
    func checkPermissions() {
        // Use Task to perform async check without blocking
        Task { @MainActor in
            isCheckingPermissions = true
            
            // Use the async version to avoid blocking the main thread
            let isGranted = await ModernWindowDriver.checkAccessibilityPermissionsAsync()
            
            // Update state with proper change detection
            if hasAccessibilityPermissions != isGranted {
                hasAccessibilityPermissions = isGranted
                Logger.windowManager.info("Permissions status changed to: \(isGranted)")
            } else {
                hasAccessibilityPermissions = isGranted
                Logger.windowManager.debug("Permissions status rechecked: \(isGranted)")
            }
            
            isCheckingPermissions = false
        }
    }
    
    func requestPermissions() {
        Logger.windowManager.info("Requesting accessibility permissions")
        ModernWindowDriver.requestAccessibilityPermissions()
        
        // Check again after delays to capture permission changes
        Task { @MainActor in
            // First check after UI might have appeared
            try? await Task.sleep(for: .seconds(1))
            checkPermissions()
            
            // Second check after user might have granted permission
            try? await Task.sleep(for: .seconds(3))
            checkPermissions()
        }
    }
    
    private func startPermissionMonitoring() {
        permissionMonitor = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                await self?.checkPermissions()
            }
        }
    }
    
    private func setupAppActivationObserver() {
        // Recheck permissions when app becomes active
        // This catches the case where user granted permissions in System Settings
        appActivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Logger.windowManager.debug("App became active, rechecking permissions")
            self?.checkPermissions()
        }
        
        // Listen for system-wide accessibility preference changes
        // This is the most immediate way to detect permission changes
        accessibilityChangeObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Logger.windowManager.info("Accessibility settings changed, rechecking permissions")
            // Add small delay to ensure system has processed the change
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                self?.checkPermissions()
            }
        }
    }
    
    // MARK: - Window Operations
    
    /// Shift focused window to the left half of the screen
    func shiftLeft() async {
        await performOperation { window in
            try self.driver.positionWindowLeft(window)
            Logger.windowManager.info("Window shifted left")
        }
    }
    
    /// Shift focused window to the right half of the screen
    func shiftRight() async {
        await performOperation { window in
            try self.driver.positionWindowRight(window)
            Logger.windowManager.info("Window shifted right")
        }
    }
    
    /// Maximize the focused window to fill the screen
    func maximize() async {
        await performOperation { window in
            try self.driver.maximizeWindow(window)
            Logger.windowManager.info("Window maximized")
        }
    }
    
    /// Center the focused window on its screen
    func center() async {
        await performOperation { window in
            try self.driver.centerWindow(window)
            Logger.windowManager.info("Window centered")
        }
    }
    
    /// Toggle full screen mode for the focused window
    func toggleFullScreen() async {
        await performOperation { window in
            guard window.canEnterFullScreen() else {
                throw WindowError.unsupportedOperation
            }
            try window.toggleFullScreen()
            Logger.windowManager.info("Toggled full screen")
        }
    }
    
    /// Move window to a specific screen by index
    func moveToScreen(index: Int) async {
        await performOperation { window in
            guard index < NSScreen.screens.count else {
                throw WindowError.operationFailed("Screen index \(index) out of range")
            }
            
            let targetScreen = NSScreen.screens[index]
            let visibleFrame = targetScreen.visibleFrame
            
            // Get current size and position on new screen
            let currentGeometry = try window.getGeometry()
            let newFrame = NSRect(
                x: visibleFrame.origin.x,
                y: visibleFrame.origin.y,
                width: currentGeometry.width,
                height: currentGeometry.height
            )
            
            try window.setGeometry(newFrame)
            Logger.windowManager.info("Window moved to screen \(index)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func performOperation(_ operation: @escaping (ModernWindow) throws -> Void) async {
        isProcessing = true
        lastError = nil
        
        defer {
            isProcessing = false
        }
        
        do {
            // Check permissions
            guard hasAccessibilityPermissions else {
                throw WindowError.noPermissions
            }
            
            // Get focused window
            let window = try driver.getFocusedWindow()
            
            // Perform operation
            try operation(window)
            
        } catch let error as WindowError {
            lastError = error
            Logger.windowManager.error("Window operation failed: \(error.localizedDescription)")
        } catch {
            lastError = .operationFailed(error.localizedDescription)
            Logger.windowManager.error("Unexpected error: \(error.localizedDescription)")
        }
    }
}

// MARK: - SwiftUI Integration Example

#if canImport(SwiftUI)
import SwiftUI

@available(macOS 13.0, *)
struct WindowControlView: View {
    @StateObject private var windowManager = ModernWindowManager()
    
    var body: some View {
        VStack(spacing: 20) {
            // Permission Status
            statusSection
            
            // Window Operations
            if windowManager.hasAccessibilityPermissions {
                operationsSection
            }
            
            // Error Display
            if let error = windowManager.lastError {
                errorSection(error)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private var statusSection: some View {
        VStack(spacing: 10) {
            HStack {
                if windowManager.isCheckingPermissions {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: windowManager.hasAccessibilityPermissions ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(windowManager.hasAccessibilityPermissions ? .green : .red)
                }
                
                Text("Accessibility Permissions")
                    .font(.headline)
                
                Spacer()
                
                // Add a recheck button that always shows
                Button {
                    windowManager.checkPermissions()
                } label: {
                    Label("Recheck", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Check permission status again")
                .disabled(windowManager.isCheckingPermissions)
            }
            
            if !windowManager.hasAccessibilityPermissions {
                Button("Open System Settings") {
                    windowManager.requestPermissions()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var operationsSection: some View {
        VStack(spacing: 12) {
            Text("Window Operations")
                .font(.headline)
            
            HStack(spacing: 10) {
                operationButton("Left", systemImage: "arrow.left.square") {
                    await windowManager.shiftLeft()
                }
                
                operationButton("Right", systemImage: "arrow.right.square") {
                    await windowManager.shiftRight()
                }
            }
            
            HStack(spacing: 10) {
                operationButton("Maximize", systemImage: "arrow.up.left.and.arrow.down.right") {
                    await windowManager.maximize()
                }
                
                operationButton("Center", systemImage: "circle") {
                    await windowManager.center()
                }
            }
            
            operationButton("Full Screen", systemImage: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left") {
                await windowManager.toggleFullScreen()
            }
        }
        .disabled(windowManager.isProcessing)
    }
    
    private func operationButton(_ title: String, systemImage: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task {
                await action()
            }
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
    
    private func errorSection(_ error: WindowError) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

// Preview
@available(macOS 13.0, *)
#Preview {
    WindowControlView()
}
#endif

// MARK: - Command-Line Example

/// Example of using the window manager from command line or scripts
@MainActor
struct CommandLineExample {
    static func run() async {
        let manager = ModernWindowManager()
        
        print("ShiftIt Modern Window Manager")
        print("==============================")
        
        // Check permissions
        if !manager.hasAccessibilityPermissions {
            print("⚠️  Accessibility permissions not granted")
            print("Please enable in System Settings → Privacy & Security → Accessibility")
            manager.requestPermissions()
            return
        }
        
        print("✅ Permissions granted")
        
        // Example: Shift window left
        print("\nShifting window left...")
        await manager.shiftLeft()
        
        if let error = manager.lastError {
            print("❌ Error: \(error.localizedDescription)")
        } else {
            print("✅ Success!")
        }
        
        // Wait a moment
        try? await Task.sleep(for: .seconds(2))
        
        // Example: Maximize window
        print("\nMaximizing window...")
        await manager.maximize()
        
        if let error = manager.lastError {
            print("❌ Error: \(error.localizedDescription)")
        } else {
            print("✅ Success!")
        }
    }
}

// MARK: - Advanced: Custom Window Layouts

@MainActor
extension ModernWindowManager {
    
    /// Apply a custom layout to the focused window
    func applyCustomLayout(_ layout: WindowLayout) async {
        await performOperation { window in
            guard let screen = ModernWindowDriver.screen(for: window) else {
                throw WindowError.operationFailed("Could not determine window screen")
            }
            
            let visibleFrame = screen.visibleFrame
            let newFrame = layout.frame(in: visibleFrame)
            
            try window.setGeometry(newFrame)
            Logger.windowManager.info("Applied custom layout: \(layout.name)")
        }
    }
    
    /// Quarter layouts (top-left, top-right, bottom-left, bottom-right)
    func applyQuarterLayout(_ position: QuarterPosition) async {
        let layout = WindowLayout.quarter(position)
        await applyCustomLayout(layout)
    }
    
    /// Third layouts (left, center, right)
    func applyThirdLayout(_ position: ThirdPosition) async {
        let layout = WindowLayout.third(position)
        await applyCustomLayout(layout)
    }
}

// MARK: - Window Layout Types

enum QuarterPosition: Sendable {
    case topLeft, topRight, bottomLeft, bottomRight
}

enum ThirdPosition: Sendable {
    case left, center, right
}

struct WindowLayout: Sendable {
    let name: String
    let frame: (NSRect) -> NSRect
    
    static func quarter(_ position: QuarterPosition) -> WindowLayout {
        WindowLayout(name: "Quarter-\(position)") { visibleFrame in
            let halfWidth = visibleFrame.width / 2
            let halfHeight = visibleFrame.height / 2
            
            switch position {
            case .topLeft:
                return NSRect(x: visibleFrame.minX, y: visibleFrame.minY + halfHeight,
                            width: halfWidth, height: halfHeight)
            case .topRight:
                return NSRect(x: visibleFrame.minX + halfWidth, y: visibleFrame.minY + halfHeight,
                            width: halfWidth, height: halfHeight)
            case .bottomLeft:
                return NSRect(x: visibleFrame.minX, y: visibleFrame.minY,
                            width: halfWidth, height: halfHeight)
            case .bottomRight:
                return NSRect(x: visibleFrame.minX + halfWidth, y: visibleFrame.minY,
                            width: halfWidth, height: halfHeight)
            }
        }
    }
    
    static func third(_ position: ThirdPosition) -> WindowLayout {
        WindowLayout(name: "Third-\(position)") { visibleFrame in
            let thirdWidth = visibleFrame.width / 3
            
            switch position {
            case .left:
                return NSRect(x: visibleFrame.minX, y: visibleFrame.minY,
                            width: thirdWidth, height: visibleFrame.height)
            case .center:
                return NSRect(x: visibleFrame.minX + thirdWidth, y: visibleFrame.minY,
                            width: thirdWidth, height: visibleFrame.height)
            case .right:
                return NSRect(x: visibleFrame.minX + 2 * thirdWidth, y: visibleFrame.minY,
                            width: thirdWidth, height: visibleFrame.height)
            }
        }
    }
}

// MARK: - Usage Examples

/*
 
 // Example 1: Basic window operations from AppDelegate
 
 @MainActor
 func applicationDidFinishLaunching(_ notification: Notification) {
     let manager = ModernWindowManager()
     
     Task {
         await manager.shiftLeft()
     }
 }
 
 // Example 2: Custom hotkey handler
 
 @MainActor
 func handleShiftLeftHotkey() {
     Task {
         let manager = ModernWindowManager()
         await manager.shiftLeft()
     }
 }
 
 // Example 3: Advanced quarter layout
 
 @MainActor
 func arrangeWindowsInQuarters() async {
     let manager = ModernWindowManager()
     await manager.applyQuarterLayout(.topLeft)
 }
 
 // Example 4: Command-line tool
 
 @main
 struct ShiftItCLI {
     static func main() async {
         await CommandLineExample.run()
     }
 }
 
 */
