import XCTest
@testable import Unidle

final class PointerMovementTests: XCTestCase {

    private let origin = CGPoint(x: 500, y: 400)

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }

    /// Zero amplitude is the "leave my pointer alone" option: one event, no move.
    func testZeroAmplitudeProducesASinglePointAtTheOrigin() {
        let path = PointerMovement(amplitude: 0).path(from: origin)
        XCTAssertEqual(path, [origin])
    }

    func testPathStartsAtTheOrigin() {
        let path = PointerMovement(amplitude: 64).path(from: origin)
        XCTAssertEqual(path.first!.x, origin.x, accuracy: 0.001)
        XCTAssertEqual(path.first!.y, origin.y, accuracy: 0.001)
    }

    /// The pointer must end exactly where it started, or it drifts a little
    /// further across the screen on every single tick.
    func testPathReturnsToTheOrigin() {
        let path = PointerMovement(amplitude: 120).path(from: origin)
        XCTAssertEqual(distance(path.last!, origin), 0, accuracy: 0.001)
    }

    func testEveryPointStaysWithinTwiceTheAmplitude() {
        let amplitude: CGFloat = 64
        for point in PointerMovement(amplitude: amplitude).path(from: origin) {
            XCTAssertLessThanOrEqual(distance(point, origin), amplitude * 2 + 0.001)
        }
    }

    /// A jump can't be tracked by eye; the movement has to be drawn in steps.
    func testPathIsDrawnInManySmallSteps() {
        let path = PointerMovement(amplitude: 64, steps: 24).path(from: origin)
        XCTAssertEqual(path.count, 25)
        for (a, b) in zip(path, path.dropFirst()) {
            XCTAssertLessThan(distance(a, b), 32, "steps should be small enough to follow")
        }
    }

    func testFewerStepsStillClosesTheLoop() {
        let path = PointerMovement(amplitude: 40, steps: 4).path(from: origin)
        XCTAssertEqual(path.count, 5)
        XCTAssertEqual(distance(path.last!, origin), 0, accuracy: 0.001)
    }

    func testDegenerateStepCountFallsBackToNoMovement() {
        XCTAssertEqual(PointerMovement(amplitude: 64, steps: 1).path(from: origin), [origin])
    }

    func testAmplitudeIsActuallyReached() {
        let amplitude: CGFloat = 100
        let path = PointerMovement(amplitude: amplitude).path(from: origin)
        let furthest = path.map { distance($0, origin) }.max() ?? 0
        XCTAssertEqual(furthest, amplitude * 2, accuracy: 1.0, "the circle's far side sits two radii out")
    }

    func testEveryOfferedAmplitudeHasALabel() {
        for amplitude in PointerMovement.amplitudeOptions {
            XCTAssertFalse(PointerMovement.label(for: amplitude).isEmpty)
        }
    }
}
