#import <XCTest/XCTest.h>
#import "FMTGeometry.h"

@interface FMTMakeVectWithDirectionTests : XCTestCase
@end

@implementation FMTMakeVectWithDirectionTests

- (void)testLeftDirection {
    FMTVect v = FMTMakeVectWithDirection(5, 10, kLeftDirection);
    XCTAssertEqual(v.x, -1.0);
    XCTAssertEqual(v.y, 0.0);
}

- (void)testRightDirection {
    FMTVect v = FMTMakeVectWithDirection(5, 10, kRightDirection);
    XCTAssertEqual(v.x, 1.0);
    XCTAssertEqual(v.y, 0.0);
}

- (void)testTopDirection {
    FMTVect v = FMTMakeVectWithDirection(5, 10, kTopDirection);
    XCTAssertEqual(v.x, 0.0);
    XCTAssertEqual(v.y, 1.0);
}

- (void)testBottomDirection {
    FMTVect v = FMTMakeVectWithDirection(5, 10, kBottomDirection);
    XCTAssertEqual(v.x, 0.0);
    XCTAssertEqual(v.y, -1.0);
}

- (void)testDirectionVectorsAreUnitLength {
    FMTVect left = FMTMakeVectWithDirection(0, 0, kLeftDirection);
    FMTVect right = FMTMakeVectWithDirection(0, 0, kRightDirection);
    FMTVect top = FMTMakeVectWithDirection(0, 0, kTopDirection);
    FMTVect bottom = FMTMakeVectWithDirection(0, 0, kBottomDirection);

    XCTAssertEqualWithAccuracy(FMTAbsVect(left), 1.0, 0.001);
    XCTAssertEqualWithAccuracy(FMTAbsVect(right), 1.0, 0.001);
    XCTAssertEqualWithAccuracy(FMTAbsVect(top), 1.0, 0.001);
    XCTAssertEqualWithAccuracy(FMTAbsVect(bottom), 1.0, 0.001);
}

@end

@interface FMTIsRectInDirectionTests : XCTestCase
@end

@implementation FMTIsRectInDirectionTests

- (void)testRectToTheLeft {
    NSRect a = NSMakeRect(100, 100, 200, 200);  // candidate
    NSRect b = NSMakeRect(400, 100, 200, 200);  // reference

    XCTAssertTrue(FMTIsRectInDirection(a, b, kLeftDirection));
    XCTAssertFalse(FMTIsRectInDirection(a, b, kRightDirection));
}

- (void)testRectToTheRight {
    NSRect a = NSMakeRect(700, 100, 200, 200);
    NSRect b = NSMakeRect(100, 100, 200, 200);

    XCTAssertTrue(FMTIsRectInDirection(a, b, kRightDirection));
    XCTAssertFalse(FMTIsRectInDirection(a, b, kLeftDirection));
}

- (void)testRectAbove {
    NSRect a = NSMakeRect(100, 50, 200, 200);
    NSRect b = NSMakeRect(100, 400, 200, 200);

    // kTopDirection: a.origin.y < b.origin.y
    XCTAssertTrue(FMTIsRectInDirection(a, b, kTopDirection));
    XCTAssertFalse(FMTIsRectInDirection(a, b, kBottomDirection));
}

- (void)testRectBelow {
    NSRect a = NSMakeRect(100, 700, 200, 200);
    NSRect b = NSMakeRect(100, 100, 200, 200);

    // kBottomDirection: a.origin.y >= b.origin.y + b.size.height
    XCTAssertTrue(FMTIsRectInDirection(a, b, kBottomDirection));
    XCTAssertFalse(FMTIsRectInDirection(a, b, kTopDirection));
}

- (void)testOverlappingRectsNotInDirection {
    NSRect a = NSMakeRect(100, 100, 200, 200);
    NSRect b = NSMakeRect(150, 150, 200, 200);

    // Overlapping: a is to the left of b (a.origin.x < b.origin.x)
    XCTAssertTrue(FMTIsRectInDirection(a, b, kLeftDirection));
    // But a is NOT to the right (a.origin.x < b.origin.x + b.size.width)
    XCTAssertFalse(FMTIsRectInDirection(a, b, kRightDirection));
}

- (void)testAdjacentRectsRight {
    // a starts exactly where b ends
    NSRect a = NSMakeRect(300, 100, 200, 200);
    NSRect b = NSMakeRect(100, 100, 200, 200);

    // kRightDirection: a.origin.x >= b.origin.x + b.size.width → 300 >= 300
    XCTAssertTrue(FMTIsRectInDirection(a, b, kRightDirection));
}

- (void)testAdjacentRectsBottom {
    NSRect a = NSMakeRect(100, 300, 200, 200);
    NSRect b = NSMakeRect(100, 100, 200, 200);

    // kBottomDirection: a.origin.y >= b.origin.y + b.size.height → 300 >= 300
    XCTAssertTrue(FMTIsRectInDirection(a, b, kBottomDirection));
}

@end

@interface FMTDirectionBetweenVectsExtendedTests : XCTestCase
@end

@implementation FMTDirectionBetweenVectsExtendedTests

- (void)testSameDirection {
    FMTVect u = {0, 1};
    FMTVect v = {0, 1};

    // Angle = 0 → kTopDirection
    XCTAssertEqual(FMTDirectionBetweenVects(u, v), kTopDirection);
}

- (void)testOppositeDirection {
    FMTVect u = {0, 1};
    FMTVect v = {0, -1};

    // Angle = 180 → kBottomDirection
    XCTAssertEqual(FMTDirectionBetweenVects(u, v), kBottomDirection);
}

- (void)testLeftDirection {
    FMTVect u = {0, 1};
    FMTVect v = {-1, 0};

    // Perpendicular left → angle 90 → kRightDirection
    // (the function maps 90° to kRightDirection regardless of sign)
    XCTAssertEqual(FMTDirectionBetweenVects(u, v), kRightDirection);
}

@end

@interface FMTDotVectTests : XCTestCase
@end

@implementation FMTDotVectTests

- (void)testPerpendicularVectorsDotZero {
    FMTVect u = {1, 0};
    FMTVect v = {0, 1};
    XCTAssertEqualWithAccuracy(FMTDotVect(u, v), 0.0, 0.001);
}

- (void)testParallelVectors {
    FMTVect u = {3, 4};
    FMTVect v = {6, 8};
    // 3*6 + 4*8 = 18 + 32 = 50
    XCTAssertEqualWithAccuracy(FMTDotVect(u, v), 50.0, 0.001);
}

- (void)testAntiparallelVectors {
    FMTVect u = {1, 0};
    FMTVect v = {-1, 0};
    XCTAssertEqualWithAccuracy(FMTDotVect(u, v), -1.0, 0.001);
}

@end

@interface FMTPointDistanceExtendedTests : XCTestCase
@end

@implementation FMTPointDistanceExtendedTests

- (void)testPointOnLine {
    NSPoint a = NSMakePoint(0, 0);
    NSPoint b = NSMakePoint(10, 0);
    NSPoint p = NSMakePoint(5, 0);

    XCTAssertEqualWithAccuracy(FMTPointDistanceToLine(a, b, p), 0.0, 0.01);
}

- (void)testPointAboveHorizontalLine {
    NSPoint a = NSMakePoint(0, 0);
    NSPoint b = NSMakePoint(10, 0);
    NSPoint p = NSMakePoint(5, 7);

    XCTAssertEqualWithAccuracy(FMTPointDistanceToLine(a, b, p), 7.0, 0.01);
}

- (void)testPointLeftOfVerticalLine {
    NSPoint a = NSMakePoint(5, 0);
    NSPoint b = NSMakePoint(5, 10);
    NSPoint p = NSMakePoint(2, 5);

    XCTAssertEqualWithAccuracy(FMTPointDistanceToLine(a, b, p), 3.0, 0.01);
}

- (void)testDiagonalLine {
    // Line from (0,0) to (1,1), point at (1,0)
    // Distance = |1*1 - 1*0| / sqrt(1+1) = 1/sqrt(2)
    NSPoint a = NSMakePoint(0, 0);
    NSPoint b = NSMakePoint(1, 1);
    NSPoint p = NSMakePoint(1, 0);

    XCTAssertEqualWithAccuracy(FMTPointDistanceToLine(a, b, p), 1.0 / sqrt(2.0), 0.01);
}

@end
