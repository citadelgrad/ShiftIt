/*
 ShiftIt: Window Organizer for macOS
 Menu Bar Controller
 
 Manages the menu bar item and actions
*/

import Cocoa
import os.log

@MainActor
class MenuBarController {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "org.shiftitapp.ShiftIt", category: "MenuBar")
    private let windowManager: WindowManager
    private let statistics: UsageStatistics
    
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    
    // MARK: - Initialization
    
    init(windowManager: WindowManager, statistics: UsageStatistics) {
        self.windowManager = windowManager
        self.statistics = statistics
        setupMenuBar()
    }
    
    deinit {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
    
    // MARK: - Setup
    
    private func setupMenuBar() {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusItem = statusItem else {
            logger.error("Failed to create status item")
            return
        }
        
        // Set icon
        if let button = statusItem.button {
            if let image = NSImage(named: "ShiftItMenuIcon") {
                image.isTemplate = true
                button.image = image
            } else {
                // Fallback text if image not found
                button.title = "⌘⌥"
            }
            button.toolTip = "ShiftIt - Window Organizer"
        }
        
        // Create menu
        menu = NSMenu()
        setupMenu()
        statusItem.menu = menu
        
        logger.info("Menu bar setup complete")
    }
    
    private func setupMenu() {
        guard let menu = menu else { return }
        
        menu.removeAllItems()
        
        // Window Actions Section
        menu.addItem(withTitle: "Window Actions", action: nil, keyEquivalent: "")
            .isEnabled = false
        menu.addItem(NSMenuItem.separator())
        
        // Left/Right/Up/Down
        addAction(.shiftLeft, to: menu)
        addAction(.shiftRight, to: menu)
        addAction(.shiftUp, to: menu)
        addAction(.shiftDown, to: menu)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quarters
        addAction(.topLeft, to: menu)
        addAction(.topRight, to: menu)
        addAction(.bottomLeft, to: menu)
        addAction(.bottomRight, to: menu)
        
        menu.addItem(NSMenuItem.separator())
        
        // Size
        addAction(.maximize, to: menu)
        addAction(.center, to: menu)
        addAction(.fullScreen, to: menu)
        
        menu.addItem(NSMenuItem.separator())
        
        // Resize
        addAction(.increase, to: menu)
        addAction(.reduce, to: menu)
        
        menu.addItem(NSMenuItem.separator())
        
        // Multi-monitor
        addAction(.nextScreen, to: menu)
        addAction(.previousScreen, to: menu)
        
        menu.addItem(NSMenuItem.separator())
        
        // App Actions
        let prefsItem = menu.addItem(
            withTitle: "Preferences...",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        prefsItem.target = self
        
        let aboutItem = menu.addItem(
            withTitle: "About ShiftIt",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = menu.addItem(
            withTitle: "Quit ShiftIt",
            action: #selector(NSApp.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
    }
    
    private func addAction(_ action: WindowAction, to menu: NSMenu) {
        let item = menu.addItem(
            withTitle: action.displayName,
            action: #selector(performAction(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = action
        
        // Show keyboard shortcut if available
        if let shortcut = action.defaultShortcut {
            item.keyEquivalent = String(UnicodeScalar(shortcut.keyCode) ?? " ")
            item.keyEquivalentModifierMask = shortcut.modifiers
        }
    }
    
    // MARK: - Actions
    
    @objc private func performAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? WindowAction else {
            logger.error("No action found for menu item")
            return
        }
        
        logger.debug("Performing action: \(action.rawValue)")
        statistics.increment(action.rawValue)
        
        Task {
            await executeAction(action)
        }
    }
    
    private func executeAction(_ action: WindowAction) async {
        do {
            switch action {
            case .shiftLeft:
                await windowManager.shiftLeft()
            case .shiftRight:
                await windowManager.shiftRight()
            case .shiftUp:
                await windowManager.shiftUp()
            case .shiftDown:
                await windowManager.shiftDown()
            case .maximize:
                await windowManager.maximize()
            case .center:
                await windowManager.center()
            case .fullScreen:
                await windowManager.toggleFullScreen()
            case .topLeft:
                await windowManager.moveToQuadrant(.topLeft)
            case .topRight:
                await windowManager.moveToQuadrant(.topRight)
            case .bottomLeft:
                await windowManager.moveToQuadrant(.bottomLeft)
            case .bottomRight:
                await windowManager.moveToQuadrant(.bottomRight)
            case .increase:
                await windowManager.increaseSize()
            case .reduce:
                await windowManager.reduceSize()
            case .nextScreen:
                await windowManager.moveToNextScreen()
            case .previousScreen:
                await windowManager.moveToPreviousScreen()
            }
            
            logger.debug("Action \(action.rawValue) completed successfully")
            
        } catch {
            logger.error("Action \(action.rawValue) failed: \(error.localizedDescription)")
            
            await MainActor.run {
                showError("Window operation failed: \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func showPreferences() {
        NotificationCenter.default.post(name: .showPreferencesRequest, object: nil)
    }
    
    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - Public Methods
    
    func updateMenu() {
        setupMenu()
    }
}

// MARK: - Window Manager Extensions

extension WindowManager {
    
    /// Move window up (top half of screen)
    func shiftUp() async {
        await performWindowOperation { [self] window in
            guard let screen = ModernWindowDriver.screen(for: window) else {
                throw WindowOperationError.noScreen
            }
            
            let visibleFrame = screen.visibleFrame
            let newFrame = NSRect(
                x: visibleFrame.origin.x,
                y: visibleFrame.origin.y + visibleFrame.height / 2,
                width: visibleFrame.width,
                height: visibleFrame.height / 2
            )
            
            try await window.setGeometry(newFrame)
        }
    }
    
    /// Move window down (bottom half of screen)
    func shiftDown() async {
        await performWindowOperation { [self] window in
            guard let screen = ModernWindowDriver.screen(for: window) else {
                throw WindowOperationError.noScreen
            }
            
            let visibleFrame = screen.visibleFrame
            let newFrame = NSRect(
                x: visibleFrame.origin.x,
                y: visibleFrame.origin.y,
                width: visibleFrame.width,
                height: visibleFrame.height / 2
            )
            
            try await window.setGeometry(newFrame)
        }
    }
    
    /// Increase window size
    func increaseSize() async {
        await performWindowOperation { window in
            let currentGeometry = try await window.getGeometry()
            let newGeometry = NSRect(
                x: currentGeometry.origin.x - 20,
                y: currentGeometry.origin.y - 20,
                width: currentGeometry.width + 40,
                height: currentGeometry.height + 40
            )
            try await window.setGeometry(newGeometry)
        }
    }
    
    /// Reduce window size
    func reduceSize() async {
        await performWindowOperation { window in
            let currentGeometry = try await window.getGeometry()
            let newGeometry = NSRect(
                x: currentGeometry.origin.x + 20,
                y: currentGeometry.origin.y + 20,
                width: max(200, currentGeometry.width - 40),
                height: max(200, currentGeometry.height - 40)
            )
            try await window.setGeometry(newGeometry)
        }
    }
    
    /// Move window to next screen
    func moveToNextScreen() async {
        await performWindowOperation { window in
            let currentGeometry = try await window.getGeometry()
            let screens = NSScreen.screens
            
            guard let currentScreen = screens.first(where: { $0.frame.intersects(currentGeometry) }),
                  let currentIndex = screens.firstIndex(of: currentScreen) else {
                throw WindowOperationError.noScreen
            }
            
            let nextIndex = (currentIndex + 1) % screens.count
            let nextScreen = screens[nextIndex]
            
            let visibleFrame = nextScreen.visibleFrame
            let newGeometry = NSRect(
                x: visibleFrame.origin.x + (visibleFrame.width - currentGeometry.width) / 2,
                y: visibleFrame.origin.y + (visibleFrame.height - currentGeometry.height) / 2,
                width: min(currentGeometry.width, visibleFrame.width),
                height: min(currentGeometry.height, visibleFrame.height)
            )
            
            try await window.setGeometry(newGeometry)
        }
    }
    
    /// Move window to previous screen
    func moveToPreviousScreen() async {
        await performWindowOperation { window in
            let currentGeometry = try await window.getGeometry()
            let screens = NSScreen.screens
            
            guard let currentScreen = screens.first(where: { $0.frame.intersects(currentGeometry) }),
                  let currentIndex = screens.firstIndex(of: currentScreen) else {
                throw WindowOperationError.noScreen
            }
            
            let previousIndex = (currentIndex - 1 + screens.count) % screens.count
            let previousScreen = screens[previousIndex]
            
            let visibleFrame = previousScreen.visibleFrame
            let newGeometry = NSRect(
                x: visibleFrame.origin.x + (visibleFrame.width - currentGeometry.width) / 2,
                y: visibleFrame.origin.y + (visibleFrame.height - currentGeometry.height) / 2,
                width: min(currentGeometry.width, visibleFrame.width),
                height: min(currentGeometry.height, visibleFrame.height)
            )
            
            try await window.setGeometry(newGeometry)
        }
    }
}
