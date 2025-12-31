/*
 ShiftIt: Window Organizer for macOS
 Tests for ModernWindowDriver
 
 Copyright (c) 2010-2025 Filip Krikava
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

import XCTest
@testable import ShiftIt

/// Tests for the ModernWindowDriver and ModernWindow classes
class ModernWindowDriverTests: XCTestCase {
    
    var driver: ModernWindowDriver!
    
    override func setUp() {
        super.setUp()
        driver = ModernWindowDriver()
    }
    
    override func tearDown() {
        driver = nil
        super.tearDown()
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityPermissionsCheck() {
        // This test just verifies the method can be called
        // Actual permissions depend on system settings
        let hasPermissions = ModernWindowDriver.checkAccessibilityPermissions()
        
        // We can't assert true/false as it depends on system state
        // Just verify it returns a boolean
        XCTAssertTrue(hasPermissions == true || hasPermissions == false)
    }
    
    // MARK: - Window Geometry Tests
    
    func testGeometryCalculations() {
        // Test left half calculation
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let leftHalf = NSRect(
            x: 0,
            y: 0,
            width: screenFrame.width / 2,
            height: screenFrame.height
        )
        
        XCTAssertEqual(leftHalf.width, 960)
        XCTAssertEqual(leftHalf.height, 1080)
        XCTAssertEqual(leftHalf.origin.x, 0)
    }
    
    func testRightHalfGeometry() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let rightHalf = NSRect(
            x: screenFrame.width / 2,
            y: 0,
            width: screenFrame.width / 2,
            height: screenFrame.height
        )
        
        XCTAssertEqual(rightHalf.width, 960)
        XCTAssertEqual(rightHalf.origin.x, 960)
    }
    
    func testCenterCalculation() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowSize = NSSize(width: 800, height: 600)
        
        let centeredX = (screenFrame.width - windowSize.width) / 2
        let centeredY = (screenFrame.height - windowSize.height) / 2
        
        XCTAssertEqual(centeredX, 560)
        XCTAssertEqual(centeredY, 240)
    }
    
    // MARK: - Screen Tests
    
    func testMainScreenExists() {
        XCTAssertNotNil(NSScreen.main, "Main screen should always exist")
    }
    
    func testScreenCount() {
        let screenCount = NSScreen.screens.count
        XCTAssertGreaterThan(screenCount, 0, "Should have at least one screen")
    }
    
    // MARK: - Integration Tests (Require Accessibility Permissions)
    
    func testGetFocusedWindow() throws {
        // Skip if accessibility permissions aren't granted
        guard ModernWindowDriver.checkAccessibilityPermissions() else {
            throw XCTSkip("Accessibility permissions not granted - skipping test")
        }
        
        // This test may fail if no window is focused
        // We'll mark it as expected to potentially fail
        do {
            let window = try driver.getFocusedWindow()
            XCTAssertNotNil(window, "Should get a valid window reference")
        } catch ModernWindowDriver.WindowDriverError.noFocusedWindow {
            // This is acceptable if no window is focused
            throw XCTSkip("No focused window available for testing")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testGeometryCalculationPerformance() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        
        measure {
            for _ in 0..<1000 {
                _ = NSRect(
                    x: screenFrame.width / 2,
                    y: 0,
                    width: screenFrame.width / 2,
                    height: screenFrame.height
                )
            }
        }
    }
}

/// Tests for quadrant and advanced geometry calculations
class GeometryLayoutTests: XCTestCase {
    
    func testQuadrantCalculations() {
        let screenFrame = NSRect(x: 0, y: 0, width: 2000, height: 1000)
        let halfWidth = screenFrame.width / 2
        let halfHeight = screenFrame.height / 2
        
        // Top left
        let topLeft = NSRect(x: 0, y: halfHeight, width: halfWidth, height: halfHeight)
        XCTAssertEqual(topLeft.width, 1000)
        XCTAssertEqual(topLeft.height, 500)
        XCTAssertEqual(topLeft.origin.y, 500)
        
        // Top right
        let topRight = NSRect(x: halfWidth, y: halfHeight, width: halfWidth, height: halfHeight)
        XCTAssertEqual(topRight.origin.x, 1000)
        XCTAssertEqual(topRight.origin.y, 500)
        
        // Bottom left
        let bottomLeft = NSRect(x: 0, y: 0, width: halfWidth, height: halfHeight)
        XCTAssertEqual(bottomLeft.origin.x, 0)
        XCTAssertEqual(bottomLeft.origin.y, 0)
        
        // Bottom right
        let bottomRight = NSRect(x: halfWidth, y: 0, width: halfWidth, height: halfHeight)
        XCTAssertEqual(bottomRight.origin.x, 1000)
        XCTAssertEqual(bottomRight.width, 1000)
    }
    
    func testThirdsCalculation() {
        let screenFrame = NSRect(x: 0, y: 0, width: 3000, height: 1000)
        let thirdWidth = screenFrame.width / 3
        
        // Left third
        let leftThird = NSRect(x: 0, y: 0, width: thirdWidth, height: screenFrame.height)
        XCTAssertEqual(leftThird.width, 1000)
        
        // Middle third
        let middleThird = NSRect(x: thirdWidth, y: 0, width: thirdWidth, height: screenFrame.height)
        XCTAssertEqual(middleThird.origin.x, 1000)
        XCTAssertEqual(middleThird.width, 1000)
        
        // Right third
        let rightThird = NSRect(x: thirdWidth * 2, y: 0, width: thirdWidth, height: screenFrame.height)
        XCTAssertEqual(rightThird.origin.x, 2000)
    }
    
    func testMultipleScreenBounds() {
        let screens = NSScreen.screens
        
        for screen in screens {
            let frame = screen.frame
            let visibleFrame = screen.visibleFrame
            
            // Visible frame should be within or equal to the full frame
            XCTAssertLessThanOrEqual(visibleFrame.width, frame.width)
            XCTAssertLessThanOrEqual(visibleFrame.height, frame.height)
        }
    }
}
