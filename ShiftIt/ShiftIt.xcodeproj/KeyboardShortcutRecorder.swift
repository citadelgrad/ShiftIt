//
//  KeyboardShortcutRecorder.swift
//  ShiftIt
//
//  Modern keyboard shortcut recorder for macOS
//  Replaces deprecated ShortcutRecorder library
//

import Cocoa
import Carbon.HIToolbox

/// A modern keyboard shortcut recorder view that captures and displays keyboard shortcuts
@objc public class KeyboardShortcutRecorder: NSView {
    
    // MARK: - Properties
    
    /// The action identifier associated with this recorder
    @objc public var identifier: String?
    
    /// The current key code
    @objc public var keyCode: Int = -1 {
        didSet {
            updateDisplay()
            saveToUserDefaults()
        }
    }
    
    /// The current modifier flags
    @objc public var modifierFlags: UInt = 0 {
        didSet {
            updateDisplay()
            saveToUserDefaults()
        }
    }
    
    /// Delegate for shortcut changes
    @objc public weak var delegate: KeyboardShortcutRecorderDelegate?
    
    // MARK: - Private Properties
    
    private var isRecording = false
    private var textField: NSTextField!
    private var clearButton: NSButton!
    private var eventMonitor: Any?
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    deinit {
        stopRecording()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        
        // Text field to display the shortcut
        textField = NSTextField(frame: bounds.insetBy(dx: 8, dy: 4))
        textField.autoresizingMask = [.width, .height]
        textField.isEditable = false
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.alignment = .center
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        textField.stringValue = "Click to record shortcut"
        addSubview(textField)
        
        // Clear button (hidden initially)
        clearButton = NSButton(frame: NSRect(x: bounds.width - 24, y: (bounds.height - 16) / 2, width: 16, height: 16))
        clearButton.autoresizingMask = [.minXMargin, .minYMargin, .maxYMargin]
        clearButton.setButtonType(.momentaryPushIn)
        clearButton.isBordered = false
        clearButton.title = ""
        clearButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Clear")
        clearButton.target = self
        clearButton.action = #selector(clearShortcut)
        clearButton.isHidden = true
        addSubview(clearButton)
        
        updateDisplay()
    }
    
    // MARK: - Display Updates
    
    private func updateDisplay() {
        if keyCode > 0 {
            textField.stringValue = formatShortcut()
            textField.textColor = .labelColor
            clearButton.isHidden = false
        } else {
            textField.stringValue = isRecording ? "Type shortcut..." : "Click to record shortcut"
            textField.textColor = .secondaryLabelColor
            clearButton.isHidden = true
        }
        
        // Update border color based on recording state
        if isRecording {
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.borderWidth = 2
        } else {
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.borderWidth = 1
        }
    }
    
    private func formatShortcut() -> String {
        guard keyCode > 0 else { return "" }
        
        var parts: [String] = []
        
        // Add modifier symbols
        if modifierFlags & UInt(NSEvent.ModifierFlags.control.rawValue) != 0 {
            parts.append("⌃")
        }
        if modifierFlags & UInt(NSEvent.ModifierFlags.option.rawValue) != 0 {
            parts.append("⌥")
        }
        if modifierFlags & UInt(NSEvent.ModifierFlags.shift.rawValue) != 0 {
            parts.append("⇧")
        }
        if modifierFlags & UInt(NSEvent.ModifierFlags.command.rawValue) != 0 {
            parts.append("⌘")
        }
        
        // Add key character
        let keyString = keyCodeToString(keyCode)
        parts.append(keyString)
        
        return parts.joined()
    }
    
    private func keyCodeToString(_ code: Int) -> String {
        // Special keys
        switch code {
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_End: return "↘"
        case kVK_Home: return "↖"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        case kVK_F1...kVK_F20:
            return "F\(code - kVK_F1 + 1)"
        default:
            break
        }
        
        // Try to get the character for this key code
        let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return ""
        }
        
        let layout = unsafeBitCast(layoutData, to: CFData.self)
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(layout), to: UnsafePointer<UCKeyboardLayout>.self)
        
        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        
        let error = UCKeyTranslate(
            keyboardLayout,
            UInt16(code),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysMask),
            &deadKeyState,
            4,
            &length,
            &chars
        )
        
        if error == noErr && length > 0 {
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
        
        return ""
    }
    
    // MARK: - Recording
    
    override public func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        if !isRecording {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        updateDisplay()
        
        // Start monitoring for key events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self else { return event }
            
            if event.type == .keyDown {
                return self.handleKeyDown(event)
            } else if event.type == .flagsChanged {
                // Allow user to see modifier keys
                self.updateDisplay()
            }
            
            return event
        }
        
        // Also monitor clicks outside to stop recording
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self else { return event }
            
            if event.window === self.window {
                let locationInView = self.convert(event.locationInWindow, from: nil)
                if !self.bounds.contains(locationInView) {
                    self.stopRecording()
                }
            }
            
            return event
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard isRecording else { return event }
        
        let keyCode = Int(event.keyCode)
        
        // Check if escape was pressed (cancel)
        if keyCode == kVK_Escape {
            stopRecording()
            return nil
        }
        
        // Check if delete was pressed (clear)
        if keyCode == kVK_Delete && event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
            clearShortcut()
            return nil
        }
        
        // Require at least one modifier key (except for function keys)
        let hasModifiers = !event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
        let isFunctionKey = (kVK_F1...kVK_F20).contains(keyCode)
        
        if !hasModifiers && !isFunctionKey {
            NSSound.beep()
            return nil
        }
        
        // Capture the shortcut
        self.keyCode = keyCode
        self.modifierFlags = UInt(event.modifierFlags.rawValue) & (
            UInt(NSEvent.ModifierFlags.command.rawValue) |
            UInt(NSEvent.ModifierFlags.option.rawValue) |
            UInt(NSEvent.ModifierFlags.shift.rawValue) |
            UInt(NSEvent.ModifierFlags.control.rawValue)
        )
        
        stopRecording()
        
        // Notify delegate
        delegate?.shortcutRecorder?(self, didChangeKeyCode: keyCode, modifiers: modifierFlags)
        
        return nil
    }
    
    private func stopRecording() {
        isRecording = false
        updateDisplay()
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    @objc private func clearShortcut() {
        keyCode = -1
        modifierFlags = 0
        stopRecording()
        
        // Notify delegate
        delegate?.shortcutRecorder?(self, didChangeKeyCode: -1, modifiers: 0)
    }
    
    // MARK: - User Defaults
    
    private func saveToUserDefaults() {
        guard let identifier = identifier else { return }
        
        let defaults = UserDefaults.standard
        defaults.set(keyCode, forKey: "\(identifier)_\(kKeyCodePrefKeySuffix)")
        defaults.set(Int(modifierFlags), forKey: "\(identifier)_\(kModifiersPrefKeySuffix)")
        defaults.synchronize()
    }
    
    @objc public func loadFromUserDefaults() {
        guard let identifier = identifier else { return }
        
        let defaults = UserDefaults.standard
        let savedKeyCode = defaults.integer(forKey: "\(identifier)_\(kKeyCodePrefKeySuffix)")
        let savedModifiers = defaults.integer(forKey: "\(identifier)_\(kModifiersPrefKeySuffix)")
        
        if savedKeyCode > 0 {
            keyCode = savedKeyCode
            modifierFlags = UInt(savedModifiers)
        }
    }
}

// MARK: - Delegate Protocol

@objc public protocol KeyboardShortcutRecorderDelegate: AnyObject {
    @objc optional func shortcutRecorder(_ recorder: KeyboardShortcutRecorder, didChangeKeyCode keyCode: Int, modifiers: UInt)
}

// MARK: - Constants (exposed to Objective-C)

@objc public let kKeyCodePrefKeySuffix = "KeyCode"
@objc public let kModifiersPrefKeySuffix = "Modifiers"
