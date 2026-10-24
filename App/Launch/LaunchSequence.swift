import Foundation

/// Timing and eased progress values for the nonblocking launch presentation.
enum LaunchSequence {
    enum Stage: Equatable {
        case singularity
        case titleReveal
        case controlsReveal
        case landing
    }

    static let titleStart = 2.0
    static let titleEnd = 6.0
    static let controlsEnd = 7.0

    static func stage(at elapsed: TimeInterval) -> Stage {
        switch elapsed {
        case ..<titleStart:
            return .singularity
        case ..<titleEnd:
            return .titleReveal
        case ..<controlsEnd:
            return .controlsReveal
        default:
            return .landing
        }
    }

    static func titleProgress(at elapsed: TimeInterval) -> Double {
        easedProgress(elapsed, from: titleStart, to: titleEnd)
    }

    static func controlsProgress(at elapsed: TimeInterval) -> Double {
        easedProgress(elapsed, from: titleEnd, to: controlsEnd)
    }

    private static func easedProgress(
        _ elapsed: TimeInterval,
        from start: TimeInterval,
        to end: TimeInterval
    ) -> Double {
        let linear = min(max((elapsed - start) / (end - start), 0), 1)
        // Quintic smoothstep has zero velocity and acceleration at both ends.
        return linear * linear * linear * (linear * (linear * 6 - 15) + 10)
    }
}
