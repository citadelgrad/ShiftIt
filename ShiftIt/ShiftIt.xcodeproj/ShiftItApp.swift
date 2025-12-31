/*
 ShiftIt: Window Organizer for macOS
 Modern Swift App Delegate
 
 This replaces ShiftItAppDelegate.m with a clean, modern Swift implementation.
 Uses Swift Concurrency, structured architecture, and modern APIs.
*/

import Cocoa
import ApplicationServices
import os.log

/// Modern app delegate using Swift and current best practices
@main
@MainActor
class ShiftItApp: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "org.shiftitapp.ShiftIt", category: "App")
    
    /// Main window manager
    private let windowManager = WindowManager()
    
    /// Menu bar controller
    private var menuBarController: MenuBarController?
    
    /// Preferences window controller
    private var preferencesController: PreferencesController?
    
    /// Keyboard shortcut manager
    private var shortcutManager: KeyboardShortcutManager?
    
    /// Usage statistics
    private var statistics = UsageStatistics()
    
    /// User defaults
    private let defaults = UserDefaults.standard
    
    // MARK: - App Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Starting ShiftIt...")
        
        // Check for first launch
        checkFirstLaunch()
        
        // Check accessibility permissions
        Task {
            await checkAccessibilityPermissions()
        }
        
        // Setup menu bar
        setupMenuBar()
        
        // Setup keyboard shortcuts
        setupKeyboardShortcuts()
        
        // Setup preferences
        setupPreferences()
        
        // Setup notifications
        setupNotifications()
        
        logger.info("ShiftIt started successfully")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        logger.info("ShiftIt terminating...")
        
        // Save usage statistics
        statistics.save()
        
        // Cleanup shortcuts
        shortcutManager?.stopMonitoring()
        
        logger.info("ShiftIt terminated")
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showPreferences(nil)
        }
        return true
    }
    
    // MARK: - Setup Methods
    
    private func checkFirstLaunch() {
        let hasStartedBefore = defaults.bool(forKey: UserDefaultsKeys.hasStartedBefore)
        
        if !hasStartedBefore {
            logger.info("First launch detected")
            defaults.set(true, forKey: UserDefaultsKeys.hasStartedBefore)
            defaults.synchronize()
            
            // Show welcome or tutorial
            showWelcome()
        }
    }
    
    private func checkAccessibilityPermissions() async {
        if !ModernWindowDriver.checkAccessibilityPermissions() {
            logger.warning("Accessibility permissions not granted")
            
            await MainActor.run {
                showAccessibilityAlert()
            }
        } else {
            logger.info("Accessibility permissions granted")
        }
    }
    
    private func setupMenuBar() {
        let showMenuIcon = defaults.bool(forKey: UserDefaultsKeys.showMenuIcon)
        
        if showMenuIcon {
            menuBarController = MenuBarController(
                windowManager: windowManager,
                statistics: statistics
            )
        }
    }
    
    private func setupKeyboardShortcuts() {
        shortcutManager = KeyboardShortcutManager(windowManager: windowManager)
        
        // Load saved shortcuts from preferences
        if let savedShortcuts = loadShortcuts() {
            shortcutManager?.applyShortcuts(savedShortcuts)
        } else {
            // Use default shortcuts
            shortcutManager?.applyDefaultShortcuts()
        }
        
        shortcutManager?.startMonitoring()
    }
    
    private func setupPreferences() {
        // Configure window manager from preferences
        windowManager.loadPreferences(from: defaults)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showPreferences(_:)),
            name: .showPreferencesRequest,
            object: nil
        )
    }
    
    // MARK: - Accessibility Permission Handling
    
    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        ShiftIt needs accessibility permissions to manage windows.
        
        Click "Open System Settings" to grant permission, then restart ShiftIt.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            openAccessibilitySettings()
            NSApp.terminate(nil)
        case .alertSecondButtonReturn:
            NSApp.terminate(nil)
        default:
            break
        }
    }
    
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Window Actions
    
    @objc func showPreferences(_ sender: Any?) {
        if preferencesController == nil {
            preferencesController = PreferencesController(
                windowManager: windowManager,
                shortcutManager: shortcutManager
            )
        }
        
        preferencesController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func showWelcome() {
        // Could show a welcome window or tutorial
        showPreferences(nil)
    }
    
    // MARK: - Shortcut Management
    
    private func loadShortcuts() -> [WindowAction: KeyboardShortcut]? {
        // Load from UserDefaults
        guard let data = defaults.data(forKey: UserDefaultsKeys.keyboardShortcuts),
              let shortcuts = try? JSONDecoder().decode([WindowAction: KeyboardShortcut].self, from: data) else {
            return nil
        }
        return shortcuts
    }
    
    func saveShortcuts(_ shortcuts: [WindowAction: KeyboardShortcut]) {
        if let data = try? JSONEncoder().encode(shortcuts) {
            defaults.set(data, forKey: UserDefaultsKeys.keyboardShortcuts)
            defaults.synchronize()
        }
    }
}

// MARK: - User Defaults Keys

enum UserDefaultsKeys {
    static let hasStartedBefore = "hasStartedBefore"
    static let showMenuIcon = "shiftItshowMenu"
    static let keyboardShortcuts = "keyboardShortcuts"
    static let marginsEnabled = "marginsEnabled"
    static let leftMargin = "leftMargin"
    static let topMargin = "topMargin"
    static let bottomMargin = "bottomMargin"
    static let rightMargin = "rightMargin"
    static let windowSizeDelta = "windowSizeDelta"
    static let screenSizeDelta = "screenSizeDelta"
    static let includeDrawers = "axdriver_includeDrawers"
    static let converge = "axdriver_converge"
    static let delayBetweenOperations = "axdriver_delayBetweenOperations"
}

// MARK: - Notifications

extension Notification.Name {
    static let showPreferencesRequest = Notification.Name("org.shiftitapp.shiftit.notifications.showPreferences")
}

// MARK: - Usage Statistics

class UsageStatistics {
    
    private var statistics: [String: Int] = [:]
    private let logger = Logger(subsystem: "org.shiftitapp.ShiftIt", category: "Statistics")
    
    private var statisticsURL: URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        
        let shiftItDir = appSupport.appendingPathComponent("ShiftIt", isDirectory: true)
        try? FileManager.default.createDirectory(at: shiftItDir, withIntermediateDirectories: true)
        return shiftItDir.appendingPathComponent("usage-statistics.plist")
    }
    
    init() {
        load()
    }
    
    func increment(_ key: String) {
        statistics[key, default: 0] += 1
        logger.debug("Incremented \(key) to \(self.statistics[key] ?? 0)")
    }
    
    func load() {
        guard let url = statisticsURL,
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Int] else {
            logger.info("No existing statistics found")
            return
        }
        
        statistics = plist
        logger.info("Loaded statistics from \(url.path)")
    }
    
    func save() {
        guard let url = statisticsURL else { return }
        
        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: statistics,
                format: .binary,
                options: 0
            )
            try data.write(to: url)
            logger.info("Saved statistics to \(url.path)")
        } catch {
            logger.error("Failed to save statistics: \(error.localizedDescription)")
        }
    }
    
    func getStatistics() -> [String: Int] {
        return statistics
    }
}

// MARK: - Window Actions Enum

enum WindowAction: String, Codable, CaseIterable {
    case shiftLeft = "left"
    case shiftRight = "right"
    case shiftUp = "top"
    case shiftDown = "bottom"
    case maximize = "maximize"
    case center = "center"
    case fullScreen = "fullscreen"
    case topLeft = "topLeft"
    case topRight = "topRight"
    case bottomLeft = "bottomLeft"
    case bottomRight = "bottomRight"
    case increase = "increase"
    case reduce = "reduce"
    case nextScreen = "nextScreen"
    case previousScreen = "previousScreen"
    
    var displayName: String {
        switch self {
        case .shiftLeft: return "Shift Left"
        case .shiftRight: return "Shift Right"
        case .shiftUp: return "Shift Up"
        case .shiftDown: return "Shift Down"
        case .maximize: return "Maximize"
        case .center: return "Center"
        case .fullScreen: return "Full Screen"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .increase: return "Increase Size"
        case .reduce: return "Reduce Size"
        case .nextScreen: return "Next Screen"
        case .previousScreen: return "Previous Screen"
        }
    }
    
    var defaultShortcut: KeyboardShortcut? {
        switch self {
        case .shiftLeft:
            return KeyboardShortcut(keyCode: 123, modifiers: [.command, .option]) // Left arrow
        case .shiftRight:
            return KeyboardShortcut(keyCode: 124, modifiers: [.command, .option]) // Right arrow
        case .shiftUp:
            return KeyboardShortcut(keyCode: 126, modifiers: [.command, .option]) // Up arrow
        case .shiftDown:
            return KeyboardShortcut(keyCode: 125, modifiers: [.command, .option]) // Down arrow
        case .maximize:
            return KeyboardShortcut(keyCode: 3, modifiers: [.command, .option, .control]) // F
        case .center:
            return KeyboardShortcut(keyCode: 8, modifiers: [.command, .option, .control]) // C
        default:
            return nil
        }
    }
}

// MARK: - Keyboard Shortcut

struct KeyboardShortcut: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
    
    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    
    // Custom Codable implementation because NSEvent.ModifierFlags isn't Codable
    enum CodingKeys: String, CodingKey {
        case keyCode
        case modifiers
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        let modifierRawValue = try container.decode(UInt.self, forKey: .modifiers)
        modifiers = NSEvent.ModifierFlags(rawValue: modifierRawValue)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers.rawValue, forKey: .modifiers)
    }
}
