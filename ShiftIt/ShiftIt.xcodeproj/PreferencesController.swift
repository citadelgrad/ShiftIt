/*
 ShiftIt: Window Organizer for macOS
 Modern Preferences Controller using SwiftUI
 
 Replaces PreferencesWindowController with SwiftUI-based preferences
*/

import SwiftUI
import Cocoa

/// AppKit window controller for SwiftUI preferences
@MainActor
class PreferencesController: NSWindowController {
    
    private let windowManager: WindowManager
    private let shortcutManager: KeyboardShortcutManager?
    
    init(windowManager: WindowManager, shortcutManager: KeyboardShortcutManager?) {
        self.windowManager = windowManager
        self.shortcutManager = shortcutManager
        
        // Create SwiftUI view
        let contentView = PreferencesView(
            windowManager: windowManager,
            shortcutManager: shortcutManager
        )
        
        // Create hosting controller
        let hostingController = NSHostingController(rootView: contentView)
        
        // Create window
        let window = NSWindow(contentViewController: hostingController)
        window.title = "ShiftIt Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 600, height: 500))
        window.center()
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}

// MARK: - SwiftUI Preferences View

struct PreferencesView: View {
    
    let windowManager: WindowManager
    let shortcutManager: KeyboardShortcutManager?
    
    @State private var selectedTab = 0
    @AppStorage(UserDefaultsKeys.showMenuIcon) private var showMenuIcon = true
    @AppStorage(UserDefaultsKeys.marginsEnabled) private var marginsEnabled = false
    @AppStorage(UserDefaultsKeys.leftMargin) private var leftMargin = 0.0
    @AppStorage(UserDefaultsKeys.topMargin) private var topMargin = 0.0
    @AppStorage(UserDefaultsKeys.rightMargin) private var rightMargin = 0.0
    @AppStorage(UserDefaultsKeys.bottomMargin) private var bottomMargin = 0.0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralPreferencesView(
                showMenuIcon: $showMenuIcon,
                marginsEnabled: $marginsEnabled,
                leftMargin: $leftMargin,
                topMargin: $topMargin,
                rightMargin: $rightMargin,
                bottomMargin: $bottomMargin
            )
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            .tag(0)
            
            ShortcutsPreferencesView(shortcutManager: shortcutManager)
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag(1)
            
            AdvancedPreferencesView(windowManager: windowManager)
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
                .tag(2)
            
            AboutPreferencesView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(3)
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - General Preferences

struct GeneralPreferencesView: View {
    
    @Binding var showMenuIcon: Bool
    @Binding var marginsEnabled: Bool
    @Binding var leftMargin: Double
    @Binding var topMargin: Double
    @Binding var rightMargin: Double
    @Binding var bottomMargin: Double
    
    @AppStorage("shouldStartAtLogin") private var shouldStartAtLogin = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Show menu bar icon", isOn: $showMenuIcon)
                    .help("Display ShiftIt icon in the menu bar")
                
                Toggle("Start at login", isOn: $shouldStartAtLogin)
                    .help("Launch ShiftIt automatically when you log in")
                    .onChange(of: shouldStartAtLogin) { _, newValue in
                        setLoginItem(enabled: newValue)
                    }
            } header: {
                Text("Application")
                    .font(.headline)
            }
            
            Section {
                Toggle("Enable window margins", isOn: $marginsEnabled)
                    .help("Add spacing around windows")
                
                if marginsEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        SliderRow(title: "Left:", value: $leftMargin, range: 0...100)
                        SliderRow(title: "Top:", value: $topMargin, range: 0...100)
                        SliderRow(title: "Right:", value: $rightMargin, range: 0...100)
                        SliderRow(title: "Bottom:", value: $bottomMargin, range: 0...100)
                    }
                    .padding(.leading)
                }
            } header: {
                Text("Window Margins")
                    .font(.headline)
            }
            
            Section {
                HStack {
                    Spacer()
                    Button("Reset to Defaults") {
                        resetDefaults()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func resetDefaults() {
        showMenuIcon = true
        marginsEnabled = false
        leftMargin = 0
        topMargin = 0
        rightMargin = 0
        bottomMargin = 0
    }
    
    private func setLoginItem(enabled: Bool) {
        // Implementation would use SMAppService or similar
        // Simplified for this example
        print("Set login item: \(enabled)")
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        HStack {
            Text(title)
                .frame(width: 60, alignment: .leading)
            Slider(value: $value, in: range, step: 1)
            Text("\(Int(value)) px")
                .frame(width: 50, alignment: .trailing)
                .monospacedDigit()
        }
    }
}

// MARK: - Shortcuts Preferences

struct ShortcutsPreferencesView: View {
    
    let shortcutManager: KeyboardShortcutManager?
    @State private var shortcuts: [WindowAction: KeyboardShortcut] = [:]
    @State private var selectedAction: WindowAction?
    @State private var isRecording = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Instructions
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Click on a shortcut to change it. Press ESC to cancel.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            // Shortcuts list
            List(WindowAction.allCases, id: \.self, selection: $selectedAction) { action in
                HStack {
                    Text(action.displayName)
                        .frame(width: 150, alignment: .leading)
                    
                    Spacer()
                    
                    if let shortcut = shortcuts[action] {
                        ShortcutDisplay(shortcut: shortcut)
                    } else {
                        Text("Not Set")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        recordShortcut(for: action)
                    }) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: {
                        shortcuts[action] = nil
                    }) {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .opacity(shortcuts[action] == nil ? 0.3 : 1.0)
                    .disabled(shortcuts[action] == nil)
                }
                .padding(.vertical, 4)
            }
            
            // Actions
            HStack {
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                Spacer()
                Button("Clear All") {
                    shortcuts = [:]
                }
            }
            .padding()
        }
        .onAppear {
            loadShortcuts()
        }
    }
    
    private func loadShortcuts() {
        // Load from shortcut manager or defaults
        for action in WindowAction.allCases {
            shortcuts[action] = action.defaultShortcut
        }
    }
    
    private func recordShortcut(for action: WindowAction) {
        // Would integrate with system keyboard recording
        // Simplified for this example
        print("Recording shortcut for \(action.displayName)")
    }
    
    private func resetToDefaults() {
        for action in WindowAction.allCases {
            shortcuts[action] = action.defaultShortcut
        }
    }
}

struct ShortcutDisplay: View {
    let shortcut: KeyboardShortcut
    
    var body: some View {
        HStack(spacing: 4) {
            if shortcut.modifiers.contains(.command) {
                ShortcutKey(symbol: "⌘")
            }
            if shortcut.modifiers.contains(.option) {
                ShortcutKey(symbol: "⌥")
            }
            if shortcut.modifiers.contains(.control) {
                ShortcutKey(symbol: "⌃")
            }
            if shortcut.modifiers.contains(.shift) {
                ShortcutKey(symbol: "⇧")
            }
            ShortcutKey(symbol: keyCodeToString(shortcut.keyCode))
        }
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "\(keyCode)"
        }
    }
}

struct ShortcutKey: View {
    let symbol: String
    
    var body: some View {
        Text(symbol)
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Advanced Preferences

struct AdvancedPreferencesView: View {
    
    let windowManager: WindowManager
    
    @AppStorage(UserDefaultsKeys.includeDrawers) private var includeDrawers = true
    @AppStorage(UserDefaultsKeys.converge) private var converge = true
    @AppStorage(UserDefaultsKeys.delayBetweenOperations) private var delayBetweenOperations = 0.0
    @AppStorage("debugLogging") private var debugLogging = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Include drawers in window geometry", isOn: $includeDrawers)
                    .help("Consider drawer windows when calculating window size")
                
                Toggle("Converge window operations", isOn: $converge)
                    .help("Retry operations until window reaches target position")
                
                HStack {
                    Text("Delay between operations:")
                    Spacer()
                    TextField("", value: $delayBetweenOperations, format: .number)
                        .frame(width: 60)
                    Text("ms")
                }
                .help("Time to wait between window operations")
            } header: {
                Text("Window Driver")
                    .font(.headline)
            }
            
            Section {
                Toggle("Enable debug logging", isOn: $debugLogging)
                    .help("Write detailed logs for troubleshooting")
                
                if debugLogging {
                    HStack {
                        Button("Open Log File") {
                            openLogFile()
                        }
                        Button("Clear Logs") {
                            clearLogs()
                        }
                    }
                }
            } header: {
                Text("Debugging")
                    .font(.headline)
            }
            
            Section {
                Button("Reset Accessibility Permissions") {
                    resetAccessibilityPermissions()
                }
                .help("Reset and re-request accessibility permissions")
            } header: {
                Text("Permissions")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func openLogFile() {
        // Open log file in Finder
        print("Open log file")
    }
    
    private func clearLogs() {
        // Clear log files
        print("Clear logs")
    }
    
    private func resetAccessibilityPermissions() {
        let alert = NSAlert()
        alert.messageText = "Reset Accessibility Permissions"
        alert.informativeText = "You will need to manually remove ShiftIt from System Settings → Privacy & Security → Accessibility, then restart the app."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - About Preferences

struct AboutPreferencesView: View {
    
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // App icon
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 128, height: 128)
            }
            
            // App name and version
            VStack(spacing: 4) {
                Text("ShiftIt")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Window Organizer for macOS")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .padding(.horizontal, 40)
            
            // Credits
            VStack(spacing: 8) {
                Text("Copyright © 2010-2025")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Link("Visit Website", destination: URL(string: "https://github.com/fikovnik/ShiftIt")!)
                
                Link("Report an Issue", destination: URL(string: "https://github.com/fikovnik/ShiftIt/issues")!)
            }
            
            Spacer()
            
            // License
            VStack(spacing: 4) {
                Text("Licensed under GPL v3")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("View License") {
                    showLicense()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .padding(40)
    }
    
    private func showLicense() {
        if let url = URL(string: "https://www.gnu.org/licenses/gpl-3.0.html") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView(
            windowManager: WindowManager(),
            shortcutManager: nil
        )
        .frame(width: 600, height: 500)
    }
}
#endif
