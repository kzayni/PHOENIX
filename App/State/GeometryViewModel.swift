// Main-actor state that translates editable controls into PhoenixCore calls.
import Combine
import Foundation

/// Geometry families currently exposed by the native application.
enum GeometrySelection: String, CaseIterable, Identifiable {
    case nacaFourDigit = "NACA Four-Digit"
    case nacaFiveDigit = "NACA Five-Digit"
    case circularCylinder = "Circular Cylinder"

    var id: Self { self }
}

@MainActor
/// Owns editable application state and delegates all geometry computation to the
/// PhoenixCore-backed Swift adapters. Regeneration is currently synchronous and
/// main-actor isolated because supported geometry sizes are interactive.
final class GeometryViewModel: ObservableObject {
    @Published var selection = GeometrySelection.nacaFourDigit { didSet { regenerate() } }

    @Published var nacaDesignation = "0012" { didSet { regenerate() } }
    @Published var nacaChordLength = 1.0 { didSet { regenerate() } }
    @Published var nacaPointCount = 256 { didSet { regenerate() } }
    @Published var nacaPointDistribution = PointDistribution.cosine { didSet { regenerate() } }
    @Published var nacaTrailingEdge = TrailingEdgeConfiguration.closed { didSet { regenerate() } }

    @Published var naca5Designation = "23012" { didSet { regenerate() } }
    @Published var naca5ChordLength = 1.0 { didSet { regenerate() } }
    @Published var naca5PointCount = 256 { didSet { regenerate() } }
    @Published var naca5PointDistribution = PointDistribution.cosine { didSet { regenerate() } }
    @Published var naca5TrailingEdge = TrailingEdgeConfiguration.closed { didSet { regenerate() } }

    @Published var cylinderRadius = 0.5 { didSet { regenerate() } }
    @Published var cylinderCenterX = 0.0 { didSet { regenerate() } }
    @Published var cylinderCenterY = 0.0 { didSet { regenerate() } }
    @Published var cylinderPointCount = 256 { didSet { regenerate() } }
    @Published var cylinderStartingAngleDegrees = 0.0 { didSet { regenerate() } }

    @Published var showsSurfacePoints = false
    @Published var showsSurfaceNormals = false
    @Published private(set) var geometry: SurfaceGeometry2D?
    @Published private(set) var errorMessage: String?
    @Published private(set) var viewportResetToken = 0

    init() {
        regenerate()
    }

    func regenerate() {
        // Keep this switch as orchestration only. Mathematical generation and
        // validation belong to the C++ adapters selected by each branch.
        do {
            switch selection {
            case .nacaFourDigit:
                geometry = try NACA4Airfoil.generate(
                    NACA4Parameters(
                        designation: nacaDesignation,
                        chordLength: nacaChordLength,
                        pointCount: nacaPointCount,
                        pointDistribution: nacaPointDistribution,
                        trailingEdge: nacaTrailingEdge
                    )
                )
            case .nacaFiveDigit:
                geometry = try NACA5Airfoil.generate(
                    NACA5Parameters(
                        designation: naca5Designation,
                        chordLength: naca5ChordLength,
                        pointCount: naca5PointCount,
                        pointDistribution: naca5PointDistribution,
                        trailingEdge: naca5TrailingEdge
                    )
                )
            case .circularCylinder:
                geometry = try CircularCylinder.generate(
                    CircularCylinderParameters(
                        radius: cylinderRadius,
                        center: Point2D(x: cylinderCenterX, y: cylinderCenterY),
                        pointCount: cylinderPointCount,
                        startingAngleDegrees: cylinderStartingAngleDegrees
                    )
                )
            }
            errorMessage = nil
        } catch {
            // Invalid edits clear stale geometry so the viewport never implies
            // that rejected parameters produced the last valid contour.
            geometry = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        viewportResetToken &+= 1
    }

    func resetViewport() {
        viewportResetToken &+= 1
    }
}
