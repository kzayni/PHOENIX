// Swift regression coverage for launch timing, adapters, geometry invariants,
// and the C ownership boundary used by the macOS application.
import Foundation
import Testing
@testable import PHOENIX

private let tightTolerance = 1.0e-12

// MARK: - Launch timing

struct LaunchSequenceTests {
    @Test func stagesFollowTheDocumentedTimeline() {
        #expect(LaunchSequence.stage(at: 0) == .singularity)
        #expect(LaunchSequence.stage(at: 1.999) == .singularity)
        #expect(LaunchSequence.stage(at: 2) == .titleReveal)
        #expect(LaunchSequence.stage(at: 4) == .titleReveal)
        #expect(LaunchSequence.stage(at: 6) == .controlsReveal)
        #expect(LaunchSequence.stage(at: 7) == .landing)
    }

    @Test func revealProgressIsBoundedAndMonotonic() {
        let samples = stride(from: 0.0, through: 8.0, by: 0.1)
        let title = samples.map(LaunchSequence.titleProgress)
        let controls = samples.map(LaunchSequence.controlsProgress)

        #expect(title.first == 0)
        #expect(title.last == 1)
        #expect(controls.first == 0)
        #expect(controls.last == 1)
        #expect(zip(title, title.dropFirst()).allSatisfy(<=))
        #expect(zip(controls, controls.dropFirst()).allSatisfy(<=))
    }
}

private func expectApproximately(
    _ actual: Double,
    _ expected: Double,
    tolerance: Double = tightTolerance
) {
    #expect(abs(actual - expected) <= tolerance)
}

private func expectNoDegenerateSegments(_ geometry: SurfaceGeometry2D) {
    for index in 0..<geometry.segmentCount {
        let nextIndex = (index + 1) % geometry.points.count
        #expect(geometry.points[index].distanceSquared(to: geometry.points[nextIndex]) > 0)
    }
}

// MARK: - Four-digit NACA geometry

struct NACA4AirfoilTests {
    @Test func defaultNACA0012IsSymmetricAndPeriodic() throws {
        let geometry = try NACA4Airfoil.generate(
            NACA4Parameters(
                designation: "0012",
                chordLength: 1.0,
                pointCount: 255,
                pointDistribution: .cosine,
                trailingEdge: .open
            )
        )

        #expect(geometry.points.count == 255)
        #expect(geometry.connectivity == .periodic)
        #expect(geometry.orientation == .counterClockwise)

        for point in geometry.points {
            let reflected = Point2D(x: point.x, y: -point.y)
            let nearestDistance = geometry.points
                .map { $0.distanceSquared(to: reflected) }
                .min()!
            #expect(nearestDistance <= 1.0e-24)
        }
    }

    @Test func NACA2412UsesPiecewiseCamberLine() throws {
        let geometry = try NACA4Airfoil.generate(
            NACA4Parameters(
                designation: "2412",
                chordLength: 1.0,
                pointCount: 256,
                pointDistribution: .uniform,
                trailingEdge: .closed
            )
        )

        // With 129 stations per side, station 64 is x/c = 0.5. Averaging
        // paired upper/lower coordinates recovers the analytical camber line.
        let upper = geometry.points[64]
        let lower = geometry.points[192]
        let expectedCamber = (0.02 / (0.6 * 0.6)) * (1.0 - 0.8 + 0.4 - 0.25)
        expectApproximately(0.5 * (upper.x + lower.x), 0.5)
        expectApproximately(0.5 * (upper.y + lower.y), expectedCamber)
        #expect(geometry.bounds.maximum.y > abs(geometry.bounds.minimum.y))
    }

    @Test func analyticalThicknessMatchesStandardPolynomial() throws {
        let geometry = try NACA4Airfoil.generate(
            NACA4Parameters(
                designation: "0012",
                chordLength: 1.0,
                pointCount: 256,
                pointDistribution: .uniform,
                trailingEdge: .closed
            )
        )

        let x = 0.5
        let expectedThickness = 5.0 * 0.12 * (
            0.2969 * sqrt(x)
                - 0.1260 * x
                - 0.3516 * x * x
                + 0.2843 * x * x * x
                - 0.1036 * x * x * x * x
        )
        expectApproximately(geometry.points[64].y, expectedThickness)
        expectApproximately(geometry.points[192].y, -expectedThickness)
    }

    @Test func chordLengthScalesEveryCoordinate() throws {
        let unit = try NACA4Airfoil.generate(
            NACA4Parameters(designation: "2412", chordLength: 1.0, pointCount: 128)
        )
        let scaled = try NACA4Airfoil.generate(
            NACA4Parameters(designation: "2412", chordLength: 2.5, pointCount: 128)
        )

        #expect(unit.points.count == scaled.points.count)
        for (unitPoint, scaledPoint) in zip(unit.points, scaled.points) {
            expectApproximately(scaledPoint.x, 2.5 * unitPoint.x)
            expectApproximately(scaledPoint.y, 2.5 * unitPoint.y)
        }
    }

    @Test func cosineSpacingClustersPointsNearLeadingEdge() throws {
        let uniform = try NACA4Airfoil.generate(
            NACA4Parameters(pointCount: 256, pointDistribution: .uniform)
        )
        let cosine = try NACA4Airfoil.generate(
            NACA4Parameters(pointCount: 256, pointDistribution: .cosine)
        )

        let uniformLeadingEdgeSpacing = uniform.points[uniform.points.count / 2 - 1].x
        let cosineLeadingEdgeSpacing = cosine.points[cosine.points.count / 2 - 1].x
        #expect(cosineLeadingEdgeSpacing < uniformLeadingEdgeSpacing)
        expectApproximately(uniformLeadingEdgeSpacing, 1.0 / 128.0)
    }

    @Test func openAndClosedTrailingEdgesHaveSpecifiedBehavior() throws {
        let open = try NACA4Airfoil.generate(
            NACA4Parameters(pointCount: 255, trailingEdge: .open)
        )
        let closed = try NACA4Airfoil.generate(
            NACA4Parameters(pointCount: 256, trailingEdge: .closed)
        )

        let openUpperTrailingEdge = open.points[0]
        let openLowerTrailingEdge = open.points[open.points.count - 1]
        expectApproximately(openUpperTrailingEdge.x, 1.0)
        expectApproximately(openLowerTrailingEdge.x, 1.0)
        expectApproximately(
            openUpperTrailingEdge.y - openLowerTrailingEdge.y,
            2.0 * 5.0 * 0.12 * (0.2969 - 0.1260 - 0.3516 + 0.2843 - 0.1015)
        )

        expectApproximately(closed.points[0].x, 1.0)
        expectApproximately(closed.points[0].y, 0.0)
        #expect(closed.points[0] != closed.points[closed.points.count - 1])
        #expect(open.points.count == 255)
        #expect(closed.points.count == 256)
    }

    @Test func airfoilCoordinatesAndPeriodicIndexingAreValid() throws {
        let geometry = try NACA4Airfoil.generate()

        let allCoordinatesAreFinite = geometry.points.allSatisfy { $0.isFinite }
        #expect(allCoordinatesAreFinite)
        #expect(geometry.signedArea > 0)
        #expect(geometry.nextIndex(after: geometry.points.count - 1) == 0)
        #expect(try geometry.point(atPeriodicIndex: -1) == geometry.points.last)
        expectNoDegenerateSegments(geometry)

        for index in stride(from: 0, to: geometry.points.count, by: 17) {
            let normal = try geometry.outwardUnitNormal(at: index)
            expectApproximately(hypot(normal.x, normal.y), 1.0)
        }
    }

    @Test func invalidNACADesignationsAndParametersAreRejected() {
        #expect(throws: GeometryError.self) {
            try NACA4Airfoil.generate(NACA4Parameters(designation: "12"))
        }
        #expect(throws: GeometryError.self) {
            try NACA4Airfoil.generate(NACA4Parameters(designation: "0312"))
        }
        #expect(throws: GeometryError.self) {
            try NACA4Airfoil.generate(NACA4Parameters(designation: "0000"))
        }
        #expect(throws: GeometryError.self) {
            try NACA4Airfoil.generate(NACA4Parameters(chordLength: 0))
        }
        #expect(throws: GeometryError.self) {
            try NACA4Airfoil.generate(NACA4Parameters(pointCount: 7))
        }
    }
}

// MARK: - Five-digit NACA geometry

struct NACA5AirfoilTests {
    @Test func normalMeanLineMatchesTabulatedNACA23012Definition() throws {
        let geometry = try NACA5Airfoil.generate(
            NACA5Parameters(
                designation: "23012",
                chordLength: 1.0,
                pointCount: 256,
                pointDistribution: .uniform,
                trailingEdge: .closed
            )
        )

        let m = 0.2025
        let expectedCamber = (15.957 * m * m * m / 6.0) * 0.5
        expectApproximately(0.5 * (geometry.points[64].x + geometry.points[192].x), 0.5)
        expectApproximately(
            0.5 * (geometry.points[64].y + geometry.points[192].y),
            expectedCamber
        )
        #expect(geometry.points.count == 256)
        #expect(geometry.orientation == .counterClockwise)
        #expect(geometry.connectivity == .periodic)
        expectNoDegenerateSegments(geometry)
    }

    @Test func reflexMeanLineMatchesTabulatedNACA23112Definition() throws {
        let geometry = try NACA5Airfoil.generate(
            NACA5Parameters(
                designation: "23112",
                chordLength: 1.0,
                pointCount: 256,
                pointDistribution: .uniform,
                trailingEdge: .closed
            )
        )

        let x = 0.5
        let m = 0.2170
        let ratio = 0.00677
        let expectedCamber = (15.793 / 6.0) * (
            ratio * pow(x - m, 3)
                - ratio * pow(1.0 - m, 3) * x
                - pow(m, 3) * x
                + pow(m, 3)
        )
        expectApproximately(
            0.5 * (geometry.points[64].y + geometry.points[192].y),
            expectedCamber
        )
    }

    @Test func configurableInputsAndInvalidCodesAreHandled() throws {
        let open = try NACA5Airfoil.generate(
            NACA5Parameters(
                designation: "24015",
                chordLength: 2.0,
                pointCount: 255,
                pointDistribution: .cosine,
                trailingEdge: .open
            )
        )
        #expect(open.points.count == 255)
        #expect(open.points.first != open.points.last)
        #expect(open.bounds.maximum.x > 1.9)

        #expect(throws: GeometryError.self) {
            try NACA5Airfoil.generate(NACA5Parameters(designation: "2301"))
        }
        #expect(throws: GeometryError.self) {
            try NACA5Airfoil.generate(NACA5Parameters(designation: "20112"))
        }
        #expect(throws: GeometryError.self) {
            try NACA5Airfoil.generate(NACA5Parameters(designation: "23000"))
        }
    }
}

// MARK: - Circular geometry

struct CircularCylinderTests {
    @Test func radiusCenterCountAndBoundsAreCorrect() throws {
        let center = Point2D(x: 2.0, y: -1.0)
        let geometry = try CircularCylinder.generate(
            CircularCylinderParameters(
                radius: 3.0,
                center: center,
                pointCount: 64,
                startingAngleDegrees: 0.0
            )
        )

        #expect(geometry.points.count == 64)
        for point in geometry.points {
            expectApproximately(hypot(point.x - center.x, point.y - center.y), 3.0)
        }
        expectApproximately(geometry.bounds.minimum.x, -1.0)
        expectApproximately(geometry.bounds.maximum.x, 5.0)
        expectApproximately(geometry.bounds.minimum.y, -4.0)
        expectApproximately(geometry.bounds.maximum.y, 2.0)
    }

    @Test func angularSpacingStartAngleAndConnectivityAreCorrect() throws {
        let geometry = try CircularCylinder.generate(
            CircularCylinderParameters(
                radius: 0.5,
                center: Point2D(x: 0, y: 0),
                pointCount: 16,
                startingAngleDegrees: 30.0
            )
        )

        let expectedStep = 2.0 * Double.pi / 16.0
        expectApproximately(atan2(geometry.points[0].y, geometry.points[0].x), .pi / 6.0)
        for index in 0..<geometry.points.count {
            let next = geometry.points[(index + 1) % geometry.points.count]
            let currentAngle = atan2(geometry.points[index].y, geometry.points[index].x)
            let nextAngle = atan2(next.y, next.x)
            let wrappedDifference = (nextAngle - currentAngle + 2.0 * .pi)
                .truncatingRemainder(dividingBy: 2.0 * .pi)
            expectApproximately(wrappedDifference, expectedStep)
        }

        #expect(geometry.connectivity == .periodic)
        #expect(geometry.nextIndex(after: 15) == 0)
        #expect(geometry.points.first != geometry.points.last)
        #expect(geometry.orientation == .counterClockwise)
        expectNoDegenerateSegments(geometry)
    }

    @Test func cylinderOutwardNormalIsRadial() throws {
        let geometry = try CircularCylinder.generate(
            CircularCylinderParameters(radius: 2.0, pointCount: 32)
        )
        let normal = try geometry.outwardUnitNormal(at: 0)
        expectApproximately(normal.x, 1.0)
        expectApproximately(normal.y, 0.0)
    }

    @Test func invalidCylinderParametersAreRejected() {
        #expect(throws: GeometryError.self) {
            try CircularCylinder.generate(CircularCylinderParameters(radius: 0))
        }
        #expect(throws: GeometryError.self) {
            try CircularCylinder.generate(CircularCylinderParameters(pointCount: 2))
        }
        #expect(throws: GeometryError.self) {
            try CircularCylinder.generate(
                CircularCylinderParameters(center: Point2D(x: .infinity, y: 0))
            )
        }
    }
}

// MARK: - C interoperability and ownership

struct SurfaceGeometry2DTests {
    @Test func cAPIReturnsContiguousOwnedGeometry() throws {
        var parameters = phoenix_cylinder_parameters(
            radius: 1.0,
            center: phoenix_point2d(x: 2.0, y: -3.0),
            point_count: 32,
            starting_angle_degrees: 0.0
        )
        var handle: OpaquePointer?
        var error = [CChar](repeating: 0, count: 256)
        let status = error.withUnsafeMutableBufferPointer { buffer in
            phoenix_generate_cylinder(&parameters, &handle, buffer.baseAddress, buffer.count)
        }
        #expect(status == PHOENIX_STATUS_OK)
        let ownedHandle = try #require(handle)
        defer { phoenix_geometry_destroy(ownedHandle) }

        var pointCount = 0
        #expect(phoenix_geometry_get_point_count(ownedHandle, &pointCount) == PHOENIX_STATUS_OK)
        var points = [phoenix_point2d](repeating: phoenix_point2d(), count: pointCount)
        let copyStatus = points.withUnsafeMutableBufferPointer { buffer in
            phoenix_geometry_copy_points(ownedHandle, buffer.baseAddress, buffer.count)
        }
        #expect(copyStatus == PHOENIX_STATUS_OK)
        #expect(points.count == 32)
        expectApproximately(points[0].x, 3.0)
        expectApproximately(points[0].y, -3.0)
    }

    @Test func cAPIInvalidInputReturnsErrorWithoutOwnership() {
        var parameters = phoenix_naca4_parameters(
            designation: nil,
            chord_length: 1.0,
            point_count: 256,
            point_distribution: PHOENIX_POINT_DISTRIBUTION_COSINE,
            trailing_edge: PHOENIX_TRAILING_EDGE_CLOSED
        )
        var handle: OpaquePointer?
        var error = [CChar](repeating: 0, count: 256)
        let status = error.withUnsafeMutableBufferPointer { buffer in
            phoenix_generate_naca4(&parameters, &handle, buffer.baseAddress, buffer.count)
        }
        #expect(status == PHOENIX_STATUS_INVALID_ARGUMENT)
        #expect(handle == nil)
        #expect(error[0] != 0)
    }
}
