import CoreGraphics
import Foundation

/// The path the pointer traces when Unidle moves it.
///
/// The movement is a full circle that starts and ends on the pointer's current
/// position, so the cursor never drifts. It is drawn as a series of small steps
/// rather than one jump: someone using the cursor as a visual anchor has to be
/// able to follow it, and a jump cannot be followed.
///
/// An amplitude of zero produces a single event that does not move the cursor at
/// all, for people who want the pointer left exactly where it is.
struct PointerMovement: Equatable {
    /// Radius of the circle, in points.
    var amplitude: CGFloat
    /// Number of steps around the circle. More steps means smoother tracking.
    var steps: Int = 24

    /// Offered in Settings. Zero is the invisible option.
    static let amplitudeOptions: [CGFloat] = [0, 24, 64, 120]

    static func label(for amplitude: CGFloat) -> String {
        switch amplitude {
        case 0: return "None — cursor stays put"
        case 24: return "Small"
        case 64: return "Medium"
        default: return "Large"
        }
    }

    func path(from origin: CGPoint) -> [CGPoint] {
        guard amplitude > 0, steps > 1 else { return [origin] }

        // Centre the circle one radius to the right, so angle zero lands on the
        // pointer's actual position and the loop closes exactly where it began.
        let centre = CGPoint(x: origin.x + amplitude, y: origin.y)
        return (0...steps).map { step in
            let angle = (Double(step) / Double(steps)) * 2 * .pi
            return CGPoint(
                x: centre.x - amplitude * CGFloat(cos(angle)),
                y: centre.y + amplitude * CGFloat(sin(angle))
            )
        }
    }
}
