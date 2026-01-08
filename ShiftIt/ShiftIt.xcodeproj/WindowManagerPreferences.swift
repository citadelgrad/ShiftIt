/*
 ShiftIt: Window Organizer for macOS  
 Window Manager Extensions for Preferences
 
 Adds preference loading and margin support to WindowManager
*/

import Foundation
import Cocoa

extension WindowManager {
    
    /// Load preferences from UserDefaults
    func loadPreferences(from defaults: UserDefaults) {
        // Margins
        let marginsEnabled = defaults.bool(forKey: UserDefaultsKeys.marginsEnabled)
        if marginsEnabled {
            let left = CGFloat(defaults.double(forKey: UserDefaultsKeys.leftMargin))
            let top = CGFloat(defaults.double(forKey: UserDefaultsKeys.topMargin))
            let right = CGFloat(defaults.double(forKey: UserDefaultsKeys.rightMargin))
            let bottom = CGFloat(defaults.double(forKey: UserDefaultsKeys.bottomMargin))
            
            setMargins(NSEdgeInsets(top: top, left: left, bottom: bottom, right: right))
        } else {
            setMargins(NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0))
        }
    }
    
    /// Apply margins to a window frame
    func applyMargins(to frame: NSRect) -> NSRect {
        guard let margins = getMargins(), 
              margins.top > 0 || margins.left > 0 || margins.bottom > 0 || margins.right > 0 else {
            return frame
        }
        
        return NSRect(
            x: frame.origin.x + margins.left,
            y: frame.origin.y + margins.bottom,
            width: frame.width - margins.left - margins.right,
            height: frame.height - margins.top - margins.bottom
        )
    }
    
    // These methods should be added to the main WindowManager class
    private var _margins: NSEdgeInsets?
    
    func setMargins(_ margins: NSEdgeInsets) {
        _margins = margins
    }
    
    func getMargins() -> NSEdgeInsets? {
        return _margins
    }
}

// Update window operations to use margins
extension WindowManager {
    
    /// Position window to left half with margins
    func shiftLeftWithMargins() async {
        await performWindowOperation { [self] window in
            guard let screen = ModernWindowDriver.screen(for: window) else {
                throw WindowOperationError.noScreen
            }
            
            let visibleFrame = screen.visibleFrame
            var targetFrame = NSRect(
                x: visibleFrame.origin.x,
                y: visibleFrame.origin.y,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            )
            
            targetFrame = applyMargins(to: targetFrame)
            try await window.setGeometry(targetFrame)
        }
    }
    
    /// Position window to right half with margins
    func shiftRightWithMargins() async {
        await performWindowOperation { [self] window in
            guard let screen = ModernWindowDriver.screen(for: window) else {
                throw WindowOperationError.noScreen
            }
            
            let visibleFrame = screen.visibleFrame
            var targetFrame = NSRect(
                x: visibleFrame.origin.x + visibleFrame.width / 2,
                y: visibleFrame.origin.y,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            )
            
            targetFrame = applyMargins(to: targetFrame)
            try await window.setGeometry(targetFrame)
        }
    }
    
    /// Maximize window with margins
    func maximizeWithMargins() async {
        await performWindowOperation { [self] window in
            guard let screen = ModernWindowDriver.screen(for: window) else {
                throw WindowOperationError.noScreen
            }
            
            let visibleFrame = screen.visibleFrame
            let targetFrame = applyMargins(to: visibleFrame)
            try await window.setGeometry(targetFrame)
        }
    }
}
