#import <XCTest/XCTest.h>
#import "DefaultShiftItActions.h"
#import "ShiftItApp.h"

// Standard test screen size (1920x1080)
static const NSSize kScreen = {1920, 1080};
// Smaller screen for variety
static const NSSize kSmallScreen = {1440, 900};

#pragma mark - Helper

static void assertRect(XCTestCase *tc, NSRect actual, CGFloat x, CGFloat y, CGFloat w, CGFloat h,
                        NSString *msg, const char *file, int line) {
    XCTAssertEqualWithAccuracy(actual.origin.x, x, 0.5, @"%@ origin.x", msg);
    XCTAssertEqualWithAccuracy(actual.origin.y, y, 0.5, @"%@ origin.y", msg);
    XCTAssertEqualWithAccuracy(actual.size.width, w, 0.5, @"%@ width", msg);
    XCTAssertEqualWithAccuracy(actual.size.height, h, 0.5, @"%@ height", msg);
}

#define AssertRect(actual, x, y, w, h, msg) \
    assertRect(self, actual, x, y, w, h, msg, __FILE__, __LINE__)

@interface CloseToTests : XCTestCase
@end

@implementation CloseToTests

- (void)testCloseToIdenticalValues {
    XCTAssertTrue(CloseTo(100.0, 100.0));
}

- (void)testCloseToWithinThreshold {
    XCTAssertTrue(CloseTo(100.0, 119.0));
    XCTAssertTrue(CloseTo(119.0, 100.0));
}

- (void)testCloseToAtBoundary {
    // CloseTo uses < 20, so exactly 20 apart should be false
    XCTAssertFalse(CloseTo(100.0, 120.0));
    XCTAssertFalse(CloseTo(120.0, 100.0));
}

- (void)testCloseToFarApart {
    XCTAssertFalse(CloseTo(0.0, 100.0));
    XCTAssertFalse(CloseTo(100.0, 0.0));
}

- (void)testCloseToNegativeValues {
    XCTAssertTrue(CloseTo(-10.0, 5.0));
    XCTAssertFalse(CloseTo(-10.0, 15.0));
}

- (void)testRectCloseToIdentical {
    NSRect a = NSMakeRect(100, 200, 500, 400);
    XCTAssertTrue(rectCloseTo(a, a));
}

- (void)testRectCloseToSlightlyOff {
    NSRect a = NSMakeRect(100, 200, 500, 400);
    NSRect b = NSMakeRect(105, 195, 510, 390);
    XCTAssertTrue(rectCloseTo(a, b));
}

- (void)testRectCloseToOneDimensionOff {
    NSRect a = NSMakeRect(100, 200, 500, 400);
    NSRect b = NSMakeRect(100, 200, 500, 450); // height differs by 50
    XCTAssertFalse(rectCloseTo(a, b));
}

@end

#pragma mark - Half-Screen Actions (no cycling)

@interface HalfScreenActionsTests : XCTestCase
@end

@implementation HalfScreenActionsTests

- (void)setUp {
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kMutipleActionsCycleWindowSizes];
}

- (void)testLeftHalf {
    NSRect window = NSMakeRect(100, 100, 400, 300);
    AnchoredRect result = shiftItLeft(window, kScreen);

    AssertRect(result.rect, 0, 0, 960, 1080, @"Left half");
    XCTAssertEqual(result.anchor & kLeftDirection, kLeftDirection);
}

- (void)testRightHalf {
    NSRect window = NSMakeRect(100, 100, 400, 300);
    AnchoredRect result = shiftItRight(window, kScreen);

    AssertRect(result.rect, 960, 0, 960, 1080, @"Right half");
    XCTAssertEqual(result.anchor & kRightDirection, kRightDirection);
}

- (void)testTopHalf {
    NSRect window = NSMakeRect(100, 100, 400, 300);
    AnchoredRect result = shiftItTop(window, kScreen);

    AssertRect(result.rect, 0, 0, 1920, 540, @"Top half");
    XCTAssertEqual(result.anchor & kTopDirection, kTopDirection);
}

- (void)testBottomHalf {
    NSRect window = NSMakeRect(100, 100, 400, 300);
    AnchoredRect result = shiftItBottom(window, kScreen);

    AssertRect(result.rect, 0, 540, 1920, 540, @"Bottom half");
    XCTAssertEqual(result.anchor & kBottomDirection, kBottomDirection);
}

- (void)testLeftHalfSmallScreen {
    NSRect window = NSMakeRect(50, 50, 200, 150);
    AnchoredRect result = shiftItLeft(window, kSmallScreen);

    AssertRect(result.rect, 0, 0, 720, 900, @"Left half small screen");
}

@end

#pragma mark - Cycling Actions (half → third → two-thirds)

@interface CyclingActionsTests : XCTestCase
@end

@implementation CyclingActionsTests

- (void)setUp {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kMutipleActionsCycleWindowSizes];
}

- (void)testLeftCycleFromArbitrary {
    // Arbitrary window → left half
    NSRect window = NSMakeRect(100, 100, 400, 300);
    AnchoredRect result = shiftItLeft(window, kScreen);

    AssertRect(result.rect, 0, 0, 960, 1080, @"Left half from arbitrary");
}

- (void)testLeftCycleFromHalfToThird {
    // Already at left half → left third
    NSRect leftHalf = NSMakeRect(0, 0, 960, 1080);
    AnchoredRect result = shiftItLeft(leftHalf, kScreen);

    AssertRect(result.rect, 0, 0, 640, 1080, @"Left third");
}

- (void)testLeftCycleFromThirdToTwoThirds {
    // Already at left third → left two-thirds
    NSRect leftThird = NSMakeRect(0, 0, 640, 1080);
    AnchoredRect result = shiftItLeft(leftThird, kScreen);

    AssertRect(result.rect, 0, 0, 1280, 1080, @"Left two-thirds");
}

- (void)testLeftCycleFromTwoThirdsBackToHalf {
    // At two-thirds (doesn't match half or third) → left half
    NSRect twoThirds = NSMakeRect(0, 0, 1280, 1080);
    AnchoredRect result = shiftItLeft(twoThirds, kScreen);

    AssertRect(result.rect, 0, 0, 960, 1080, @"Back to left half");
}

- (void)testRightCycleFromHalfToThird {
    NSRect rightHalf = NSMakeRect(960, 0, 960, 1080);
    AnchoredRect result = shiftItRight(rightHalf, kScreen);

    // Right third: origin at 1920 - 640 = 1280
    AssertRect(result.rect, 1280, 0, 640, 1080, @"Right third");
}

- (void)testRightCycleFromThirdToTwoThirds {
    NSRect rightThird = NSMakeRect(1280, 0, 640, 1080);
    AnchoredRect result = shiftItRight(rightThird, kScreen);

    // Right two-thirds: origin at 1920 - 1280 = 640
    AssertRect(result.rect, 640, 0, 1280, 1080, @"Right two-thirds");
}

- (void)testTopCycleFromHalfToThird {
    NSRect topHalf = NSMakeRect(0, 0, 1920, 540);
    AnchoredRect result = shiftItTop(topHalf, kScreen);

    AssertRect(result.rect, 0, 0, 1920, 360, @"Top third");
}

- (void)testTopCycleFromThirdToTwoThirds {
    NSRect topThird = NSMakeRect(0, 0, 1920, 360);
    AnchoredRect result = shiftItTop(topThird, kScreen);

    AssertRect(result.rect, 0, 0, 1920, 720, @"Top two-thirds");
}

- (void)testBottomCycleFromHalfToThird {
    NSRect bottomHalf = NSMakeRect(0, 540, 1920, 540);
    AnchoredRect result = shiftItBottom(bottomHalf, kScreen);

    CGFloat thirdHeight = floor(1080.0 / 3.0);
    AssertRect(result.rect, 0, 1080 - thirdHeight, 1920, thirdHeight, @"Bottom third");
}

- (void)testBottomCycleFromThirdToTwoThirds {
    CGFloat thirdHeight = floor(1080.0 / 3.0);
    NSRect bottomThird = NSMakeRect(0, 1080 - thirdHeight, 1920, thirdHeight);
    AnchoredRect result = shiftItBottom(bottomThird, kScreen);

    CGFloat twoThirdsHeight = floor(1080.0 * 2.0 / 3.0);
    AssertRect(result.rect, 0, 1080 - twoThirdsHeight, 1920, twoThirdsHeight, @"Bottom two-thirds");
}

@end

#pragma mark - Quarter-Screen Actions

@interface QuarterScreenActionsTests : XCTestCase
@end

@implementation QuarterScreenActionsTests

- (void)testTopLeft {
    NSRect window = NSMakeRect(100, 100, 400, 300);
    AnchoredRect result = shiftItTopLeft(window, kScreen);

    AssertRect(result.rect, 0, 0, 960, 540, @"Top-left quarter");
    XCTAssertTrue(result.anchor & kTopDirection);
    XCTAssertTrue(result.anchor & kLeftDirection);
}

- (void)testTopRight {
    NSRect window = NSMakeRect(100, 100, 400, 300);
    AnchoredRect result = shiftItTopRight(window, kScreen);

    AssertRect(result.rect, 960, 0, 960, 540, @"Top-right quarter");
    XCTAssertTrue(result.anchor & kTopDirection);
    XCTAssertTrue(result.anchor & kRightDirection);
}

- (void)testBottomLeft {
    NSRect window = NSMakeRect(100, 100, 400, 300);
    AnchoredRect result = shiftItBottomLeft(window, kScreen);

    AssertRect(result.rect, 0, 540, 960, 540, @"Bottom-left quarter");
    XCTAssertTrue(result.anchor & kBottomDirection);
    XCTAssertTrue(result.anchor & kLeftDirection);
}

- (void)testBottomRight {
    NSRect window = NSMakeRect(100, 100, 400, 300);
    AnchoredRect result = shiftItBottomRight(window, kScreen);

    AssertRect(result.rect, 960, 540, 960, 540, @"Bottom-right quarter");
    XCTAssertTrue(result.anchor & kBottomDirection);
    XCTAssertTrue(result.anchor & kRightDirection);
}

- (void)testQuartersCoverFullScreen {
    NSRect w = NSMakeRect(0, 0, 100, 100);
    NSRect tl = shiftItTopLeft(w, kScreen).rect;
    NSRect tr = shiftItTopRight(w, kScreen).rect;
    NSRect bl = shiftItBottomLeft(w, kScreen).rect;
    NSRect br = shiftItBottomRight(w, kScreen).rect;

    // All four quarters should tile the screen with no gaps
    XCTAssertEqual(tl.size.width + tr.size.width, kScreen.width);
    XCTAssertEqual(tl.size.height + bl.size.height, kScreen.height);
    XCTAssertEqual(NSMaxX(tl), tr.origin.x);
    XCTAssertEqual(NSMaxY(tl), bl.origin.y);
}

@end

#pragma mark - Full Screen and Center

@interface FullScreenCenterTests : XCTestCase
@end

@implementation FullScreenCenterTests

- (void)testFullScreen {
    NSRect window = NSMakeRect(100, 100, 400, 300);
    AnchoredRect result = shiftItFullScreen(window, kScreen);

    AssertRect(result.rect, 0, 0, 1920, 1080, @"Full screen");
    XCTAssertEqual(result.anchor, 0);
}

- (void)testFullScreenSmallScreen {
    NSRect window = NSMakeRect(50, 50, 200, 150);
    AnchoredRect result = shiftItFullScreen(window, kSmallScreen);

    AssertRect(result.rect, 0, 0, 1440, 900, @"Full screen small");
}

- (void)testCenterPreservesSize {
    NSRect window = NSMakeRect(100, 100, 400, 300);
    AnchoredRect result = shiftItCenter(window, kScreen);

    // Centered: x = (1920/2 - 400/2) = 760, y = (1080/2 - 300/2) = 390
    AssertRect(result.rect, 760, 390, 400, 300, @"Center");
    XCTAssertEqual(result.anchor, 0);
}

- (void)testCenterSmallWindow {
    NSRect window = NSMakeRect(0, 0, 100, 50);
    AnchoredRect result = shiftItCenter(window, kScreen);

    AssertRect(result.rect, 910, 515, 100, 50, @"Center small");
}

- (void)testCenterLargeWindow {
    // Window larger than screen - should still center (may go negative)
    NSRect window = NSMakeRect(0, 0, 2000, 1200);
    AnchoredRect result = shiftItCenter(window, kScreen);

    XCTAssertEqualWithAccuracy(result.rect.origin.x, -40, 0.5);
    XCTAssertEqualWithAccuracy(result.rect.origin.y, -60, 0.5);
    XCTAssertEqual(result.rect.size.width, 2000.0);
    XCTAssertEqual(result.rect.size.height, 1200.0);
}

@end

#pragma mark - Third-Screen Grid (3x2)

@interface ThirdScreenGridTests : XCTestCase
@end

@implementation ThirdScreenGridTests

- (void)testThirdTopLeft {
    NSRect window = NSMakeRect(0, 0, 100, 100);
    AnchoredRect result = shiftItThirdTopLeft(window, kScreen);

    AssertRect(result.rect, 0, 0, 640, 540, @"Third top-left");
    XCTAssertTrue(result.anchor & kTopDirection);
    XCTAssertTrue(result.anchor & kLeftDirection);
}

- (void)testThirdTopCenter {
    NSRect window = NSMakeRect(0, 0, 100, 100);
    AnchoredRect result = shiftItThirdTopCenter(window, kScreen);

    // x = 1920 - (640 * 2) = 640
    AssertRect(result.rect, 640, 0, 640, 540, @"Third top-center");
    XCTAssertTrue(result.anchor & kTopDirection);
}

- (void)testThirdTopRight {
    NSRect window = NSMakeRect(0, 0, 100, 100);
    AnchoredRect result = shiftItThirdTopRight(window, kScreen);

    // x = 1920 - 640 = 1280
    AssertRect(result.rect, 1280, 0, 640, 540, @"Third top-right");
}

- (void)testThirdBottomLeft {
    NSRect window = NSMakeRect(0, 0, 100, 100);
    AnchoredRect result = shiftItThirdBottomLeft(window, kScreen);

    AssertRect(result.rect, 0, 540, 640, 540, @"Third bottom-left");
    XCTAssertTrue(result.anchor & kBottomDirection);
    XCTAssertTrue(result.anchor & kLeftDirection);
}

- (void)testThirdBottomCenter {
    NSRect window = NSMakeRect(0, 0, 100, 100);
    AnchoredRect result = shiftItThirdBottomCenter(window, kScreen);

    AssertRect(result.rect, 640, 540, 640, 540, @"Third bottom-center");
}

- (void)testThirdBottomRight {
    NSRect window = NSMakeRect(0, 0, 100, 100);
    AnchoredRect result = shiftItThirdBottomRight(window, kScreen);

    AssertRect(result.rect, 1280, 540, 640, 540, @"Third bottom-right");
}

- (void)testThirdGridCoversScreen {
    NSRect w = NSMakeRect(0, 0, 100, 100);
    NSRect tl = shiftItThirdTopLeft(w, kScreen).rect;
    NSRect tc = shiftItThirdTopCenter(w, kScreen).rect;
    NSRect tr = shiftItThirdTopRight(w, kScreen).rect;
    NSRect bl = shiftItThirdBottomLeft(w, kScreen).rect;

    // Three columns should span the width
    XCTAssertEqualWithAccuracy(tl.size.width + tc.size.width + tr.size.width, kScreen.width, 1.0);
    // Two rows should span the height
    XCTAssertEqualWithAccuracy(tl.size.height + bl.size.height, kScreen.height, 1.0);
}

@end

#pragma mark - Vertical Thirds (full height)

@interface VerticalThirdsTests : XCTestCase
@end

@implementation VerticalThirdsTests

- (void)testThirdLeft {
    NSRect window = NSMakeRect(0, 0, 100, 100);
    AnchoredRect result = shiftItThirdLeft(window, kScreen);

    AssertRect(result.rect, 0, 0, 640, 1080, @"Third left");
    XCTAssertTrue(result.anchor & kLeftDirection);
}

- (void)testThirdCenter {
    NSRect window = NSMakeRect(0, 0, 100, 100);
    AnchoredRect result = shiftItThirdCenter(window, kScreen);

    AssertRect(result.rect, 640, 0, 640, 1080, @"Third center");
}

- (void)testThirdRight {
    NSRect window = NSMakeRect(0, 0, 100, 100);
    AnchoredRect result = shiftItThirdRight(window, kScreen);

    AssertRect(result.rect, 1280, 0, 640, 1080, @"Third right");
}

- (void)testVerticalThirdsCoverWidth {
    NSRect w = NSMakeRect(0, 0, 100, 100);
    NSRect l = shiftItThirdLeft(w, kScreen).rect;
    NSRect c = shiftItThirdCenter(w, kScreen).rect;
    NSRect r = shiftItThirdRight(w, kScreen).rect;

    XCTAssertEqualWithAccuracy(l.size.width + c.size.width + r.size.width, kScreen.width, 1.0);
    XCTAssertEqual(l.size.height, kScreen.height);
    XCTAssertEqual(c.size.height, kScreen.height);
    XCTAssertEqual(r.size.height, kScreen.height);
}

@end

#pragma mark - IncreaseReduceShiftItAction

// Simple mock for SIWindowContext that provides margins
@interface MockWindowContext : NSObject <SIWindowContext>
@property (nonatomic) Margins margins;
@end

@implementation MockWindowContext

- (BOOL)getFocusedWindow:(id<SIWindow> *)window error:(NSError **)error {
    return NO; // Not used in shiftWindowRect tests
}

- (BOOL)anchorWindow:(id<SIWindow>)window to:(int)anchor error:(NSError **)error {
    return YES;
}

- (void)getAnchorMargins:(Margins *)margins {
    *margins = self.margins;
}

@end

@interface IncreaseReduceTests : XCTestCase
@end

@implementation IncreaseReduceTests

- (void)setUp {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:kFixedSizeDeltaType forKey:kSizeDeltaTypePrefKey];
    [defaults setInteger:100 forKey:kFixedSizeWidthDeltaPrefKey];
    [defaults setInteger:100 forKey:kFixedSizeHeightDeltaPrefKey];
}

- (MockWindowContext *)contextWithMargins:(int)left top:(int)top bottom:(int)bottom right:(int)right {
    MockWindowContext *ctx = [[MockWindowContext alloc] init];
    ctx.margins = (Margins){left, top, bottom, right};
    return ctx;
}

- (void)testIncreaseFromCenter {
    IncreaseReduceShiftItAction *action = [[IncreaseReduceShiftItAction alloc] initWithMode:YES];
    MockWindowContext *ctx = [self contextWithMargins:0 top:0 bottom:0 right:0];

    // Window in the center of the screen, not touching any edge
    NSRect window = NSMakeRect(500, 300, 600, 400);
    AnchoredRect result = [action shiftWindowRect:window screenSize:kScreen withContext:ctx];

    // Should expand in all 4 directions (50px each way for width, 50px each for height)
    XCTAssertTrue(result.rect.size.width > window.size.width);
    XCTAssertTrue(result.rect.size.height > window.size.height);
    XCTAssertEqualWithAccuracy(result.rect.size.width, 700, 1.0);
    XCTAssertEqualWithAccuracy(result.rect.size.height, 500, 1.0);
}

- (void)testReduceFromCenter {
    IncreaseReduceShiftItAction *action = [[IncreaseReduceShiftItAction alloc] initWithMode:NO];
    MockWindowContext *ctx = [self contextWithMargins:0 top:0 bottom:0 right:0];

    NSRect window = NSMakeRect(500, 300, 600, 400);
    AnchoredRect result = [action shiftWindowRect:window screenSize:kScreen withContext:ctx];

    XCTAssertTrue(result.rect.size.width < window.size.width);
    XCTAssertTrue(result.rect.size.height < window.size.height);
}

- (void)testIncreaseAnchoredLeft {
    IncreaseReduceShiftItAction *action = [[IncreaseReduceShiftItAction alloc] initWithMode:YES];
    MockWindowContext *ctx = [self contextWithMargins:0 top:0 bottom:0 right:0];

    // Window at left edge - should not expand left
    NSRect window = NSMakeRect(0, 300, 600, 400);
    AnchoredRect result = [action shiftWindowRect:window screenSize:kScreen withContext:ctx];

    XCTAssertEqualWithAccuracy(result.rect.origin.x, 0, 0.5, @"Should stay at left edge");
    XCTAssertTrue(result.rect.size.width > window.size.width);
}

- (void)testIncreaseConstrainedByScreen {
    IncreaseReduceShiftItAction *action = [[IncreaseReduceShiftItAction alloc] initWithMode:YES];
    MockWindowContext *ctx = [self contextWithMargins:0 top:0 bottom:0 right:0];

    // Window nearly full screen
    NSRect window = NSMakeRect(10, 10, 1900, 1060);
    AnchoredRect result = [action shiftWindowRect:window screenSize:kScreen withContext:ctx];

    // Should be constrained to screen bounds
    XCTAssertTrue(result.rect.origin.x >= 0);
    XCTAssertTrue(result.rect.origin.y >= 0);
    XCTAssertTrue(result.rect.size.width <= kScreen.width);
    XCTAssertTrue(result.rect.size.height <= kScreen.height);
}

- (void)testReduceFromFullScreenResetDirections {
    IncreaseReduceShiftItAction *action = [[IncreaseReduceShiftItAction alloc] initWithMode:NO];
    MockWindowContext *ctx = [self contextWithMargins:0 top:0 bottom:0 right:0];

    // Full screen window - all edges at margins, so directions=0
    // Special case: reducing from maximized should allow all directions
    NSRect window = NSMakeRect(0, 0, 1920, 1080);
    AnchoredRect result = [action shiftWindowRect:window screenSize:kScreen withContext:ctx];

    XCTAssertTrue(result.rect.size.width < window.size.width);
    XCTAssertTrue(result.rect.size.height < window.size.height);
}

- (void)testMinimumSizeEnforced {
    IncreaseReduceShiftItAction *action = [[IncreaseReduceShiftItAction alloc] initWithMode:NO];
    MockWindowContext *ctx = [self contextWithMargins:0 top:0 bottom:0 right:0];

    // Very small window - reduce should not go below delta size
    NSRect window = NSMakeRect(500, 300, 110, 110);
    AnchoredRect result = [action shiftWindowRect:window screenSize:kScreen withContext:ctx];

    // Minimum size is the delta (100x100)
    XCTAssertTrue(result.rect.size.width >= 100);
    XCTAssertTrue(result.rect.size.height >= 100);
}

@end
