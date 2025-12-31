/*
 ShiftIt: Window Organizer for macOS
 Simple Test Suite
 
 Minimal tests that don't require external dependencies.
 Add this file to your TEST TARGET, not the main app target.
*/

import XCTest

/// Simple geometry tests that don't require window management
class SimpleGeometryTests: XCTestCase {
    
    func testLeftHalfCalculation() {
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
        XCTAssertEqual(leftHalf.origin.y, 0)
    }
    
    func testRightHalfCalculation() {
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
    
    func testQuadrantCalculations() {
        let screenFrame = NSRect(x: 0, y: 0, width: 2000, height: 1000)
        let halfWidth = screenFrame.width / 2
        let halfHeight = screenFrame.height / 2
        
        // Top left
        let topLeft = NSRect(x: 0, y: halfHeight, width: halfWidth, height: halfHeight)
        XCTAssertEqual(topLeft.width, 1000)
        XCTAssertEqual(topLeft.height, 500)
        XCTAssertEqual(topLeft.origin.y, 500)
        
        // Bottom right
        let bottomRight = NSRect(x: halfWidth, y: 0, width: halfWidth, height: halfHeight)
        XCTAssertEqual(bottomRight.origin.x, 1000)
        XCTAssertEqual(bottomRight.width, 1000)
    }
}

/// Performance tests for geometry calculations
class SimplePerformanceTests: XCTestCase {
    
    func testGeometryPerformance() {
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
