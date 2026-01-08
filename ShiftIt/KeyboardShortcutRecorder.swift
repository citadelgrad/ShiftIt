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
@objc(KeyboardShortcutRecorder)
@objcMembers
public class KeyboardShortcutRecorder: NSView {

    // MARK: - Properties

    /// The action identifier associated with this recorder
    @objc public var actionIdentifier: String?

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
    nonisolated(unsafe) private var keyEventMonitor: Any?
    nonisolated(unsafe) private var clickEventMonitor: Any?

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
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
        if let monitor = clickEventMonitor {
            NSEvent.removeMonitor(monitor)
            clickEventMonitor = nil
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        // Create a non-interactive text field to display the shortcut
        textField = NonInteractiveTextField(labelWithString: "Click to record")
        textField.frame = bounds.insetBy(dx: 8, dy: 4)
        textField.autoresizingMask = [.width, .height]
        textField.alignment = .center
        textField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        textField.textColor = .secondaryLabelColor
        addSubview(textField)

        // Clear button
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

    // Override mouseDown to handle clicks directly
    override public func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        // Check if click was on the clear button
        if !clearButton.isHidden {
            let buttonFrame = clearButton.frame.insetBy(dx: -4, dy: -4)
            if buttonFrame.contains(location) {
                clearShortcut()
                return
            }
        }

        // Toggle recording state
        if isRecording {
            stopRecording()
        } else {
            window?.makeKeyAndOrderFront(nil)
            _ = window?.makeFirstResponder(self)
            startRecording()
        }
    }

    // Ensure we receive mouse events
    override public func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)

        // Check if the point is within the clear button
        if !clearButton.isHidden {
            let buttonFrame = clearButton.frame.insetBy(dx: -4, dy: -4)
            if buttonFrame.contains(localPoint) {
                return clearButton
            }
        }

        // Return self to receive mouse events
        if bounds.contains(localPoint) {
            return self
        }

        return nil
    }

    // MARK: - Display Updates

    private func updateDisplay() {
        if isRecording {
            textField.stringValue = "Type shortcut..."
            textField.textColor = .systemBlue
            clearButton.isHidden = true
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.borderWidth = 2
        } else if keyCode > 0 {
            textField.stringValue = formatShortcut()
            textField.textColor = .labelColor
            clearButton.isHidden = false
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.borderWidth = 1
        } else {
            textField.stringValue = "Click to record"
            textField.textColor = .secondaryLabelColor
            clearButton.isHidden = true
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.borderWidth = 1
        }

        needsDisplay = true
    }

    private func formatShortcut() -> String {
        guard keyCode > 0 else { return "" }

        var parts: [String] = []

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

        let keyString = keyCodeToString(keyCode)
        parts.append(keyString)

        return parts.joined()
    }

    private func keyCodeToString(_ code: Int) -> String {
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
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        default:
            break
        }

        let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "?"
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

        return "?"
    }

    // MARK: - First Responder

    override public var acceptsFirstResponder: Bool {
        return true
    }

    override public func becomeFirstResponder() -> Bool {
        return true
    }

    override public func resignFirstResponder() -> Bool {
        if isRecording {
            stopRecording()
        }
        return true
    }

    // MARK: - Recording

    private func startRecording() {
        guard !isRecording else { return }

        isRecording = true
        updateDisplay()

        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self, self.isRecording else { return event }

            if event.type == .keyDown {
                return self.handleKeyDown(event)
            }

            return event
        }

        // Delay click monitor setup to avoid catching the initial click
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self, self.isRecording else { return }

            self.clickEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                guard let self = self, self.isRecording else { return event }

                let locationInView = self.convert(event.locationInWindow, from: nil)
                if !self.bounds.contains(locationInView) {
                    self.stopRecording()
                }
                return event
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard isRecording else { return event }

        let keyCode = Int(event.keyCode)

        // Escape cancels recording
        if keyCode == kVK_Escape {
            stopRecording()
            return nil
        }

        // Delete clears the shortcut
        if keyCode == kVK_Delete && event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
            clearShortcut()
            return nil
        }

        // Require modifiers (except for function keys)
        let hasModifiers = !event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
        let functionKeyCodes: Set<Int> = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
            kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20
        ]
        let isFunctionKey = functionKeyCodes.contains(keyCode)

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
        delegate?.shortcutRecorder?(self, didChangeKeyCode: keyCode, modifiers: modifierFlags)

        return nil
    }

    private func stopRecording() {
        isRecording = false
        updateDisplay()

        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
        if let monitor = clickEventMonitor {
            NSEvent.removeMonitor(monitor)
            clickEventMonitor = nil
        }
    }

    @objc private func clearShortcut() {
        let oldKeyCode = keyCode
        keyCode = -1
        modifierFlags = 0
        stopRecording()

        if oldKeyCode != -1 {
            delegate?.shortcutRecorder?(self, didChangeKeyCode: -1, modifiers: 0)
        }
    }

    // MARK: - User Defaults

    private func saveToUserDefaults() {
        guard let identifier = actionIdentifier else { return }

        let defaults = UserDefaults.standard
        defaults.set(keyCode, forKey: "\(identifier)\(kKeyCodePrefKeySuffix)")
        defaults.set(Int(modifierFlags), forKey: "\(identifier)\(kModifiersPrefKeySuffix)")
        defaults.synchronize()
    }

    @objc public func loadFromUserDefaults() {
        guard let identifier = actionIdentifier else { return }

        let defaults = UserDefaults.standard
        let savedKeyCode = defaults.integer(forKey: "\(identifier)\(kKeyCodePrefKeySuffix)")
        let savedModifiers = defaults.integer(forKey: "\(identifier)\(kModifiersPrefKeySuffix)")

        if savedKeyCode > 0 {
            keyCode = savedKeyCode
            modifierFlags = UInt(savedModifiers)
        }
    }
}

// MARK: - Delegate Protocol

@objc(KeyboardShortcutRecorderDelegate)
public protocol KeyboardShortcutRecorderDelegate: AnyObject {
    @objc optional func shortcutRecorder(_ recorder: KeyboardShortcutRecorder, didChangeKeyCode keyCode: Int, modifiers: UInt)
}

// MARK: - Constants

public let kKeyCodePrefKeySuffix = "KeyCode"
public let kModifiersPrefKeySuffix = "Modifiers"

// MARK: - Non-Interactive TextField

/// A text field that passes all mouse events to its superview
private class NonInteractiveTextField: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        superview?.mouseDown(with: event)
    }
}
