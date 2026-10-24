// Rendering-facing geometry values and lifetime management for C++ handles.
import Foundation

// MARK: - Lightweight value types

/// Cartesian point copied from PhoenixCore for SwiftUI rendering.
nonisolated struct Point2D: Equatable, Sendable {
    let x: Double
    let y: Double
    var isFinite: Bool { x.isFinite && y.isFinite }

    func distanceSquared(to other: Point2D) -> Double {
        let dx = other.x - x
        let dy = other.y - y
        return dx * dx + dy * dy
    }
}

/// Cartesian vector returned by PhoenixCore-derived operations.
nonisolated struct Vector2D: Equatable, Sendable {
    let x: Double
    let y: Double
}

/// Axis-aligned physical bounds computed and validated by PhoenixCore.
nonisolated struct GeometryBounds: Equatable, Sendable {
    let minimum: Point2D
    let maximum: Point2D
    var width: Double { maximum.x - minimum.x }
    var height: Double { maximum.y - minimum.y }
    var center: Point2D {
        Point2D(x: 0.5 * (minimum.x + maximum.x), y: 0.5 * (minimum.y + maximum.y))
    }
}

nonisolated enum ContourConnectivity: String, CaseIterable, Identifiable, Sendable {
    case periodic
    case open
    var id: Self { self }
}

nonisolated enum SurfaceOrientation: String, Sendable {
    case counterClockwise
    case clockwise
}

nonisolated enum PointDistribution: String, CaseIterable, Identifiable, Sendable {
    case uniform
    case cosine
    var id: Self { self }
    var displayName: String { rawValue.capitalized }
}

nonisolated enum TrailingEdgeConfiguration: String, CaseIterable, Identifiable, Sendable {
    case open
    case closed
    var id: Self { self }
    var displayName: String { rawValue.capitalized }
}

nonisolated enum GeometryMetadata: Equatable, Sendable {
    case nacaFourDigit(NACA4Metadata)
    case nacaFiveDigit(NACA5Metadata)
    case circularCylinder(CircularCylinderMetadata)
}

nonisolated enum GeometryError: Error, Equatable, LocalizedError {
    case core(String)
    case indexOutOfBounds(Int)

    var errorDescription: String? {
        switch self {
        case .core(let message): message
        case .indexOutOfBounds(let index): "Surface-point index \(index) is out of bounds."
        }
    }
}

// MARK: - Owned geometry snapshot

/// A rendering-facing Swift view of a contour owned and validated by PhoenixCore.
///
/// The opaque C++ allocation remains alive for this object's lifetime. `points`
/// is a Swift snapshot for rendering; derived computational values and normals
/// come from the same C++ object through the C API.
nonisolated final class SurfaceGeometry2D: @unchecked Sendable {
    let points: [Point2D]
    let connectivity: ContourConnectivity
    let orientation: SurfaceOrientation
    let bounds: GeometryBounds
    let metadata: GeometryMetadata
    let signedArea: Double

    private let handle: OpaquePointer

    var segmentCount: Int {
        connectivity == .periodic ? points.count : max(points.count - 1, 0)
    }

    init(ownedHandle handle: OpaquePointer, metadata: GeometryMetadata) throws {
        var pointCount = 0
        var cBounds = phoenix_bounds2d()
        var cConnectivity = PHOENIX_CONNECTIVITY_PERIODIC
        var cOrientation = PHOENIX_ORIENTATION_COUNTER_CLOCKWISE
        var area = 0.0

        // Read all scalar invariants before accepting ownership into a usable
        // Swift object; any partial failure destroys the supplied handle.
        guard phoenix_geometry_get_point_count(handle, &pointCount) == PHOENIX_STATUS_OK,
              phoenix_geometry_get_bounds(handle, &cBounds) == PHOENIX_STATUS_OK,
              phoenix_geometry_get_connectivity(handle, &cConnectivity) == PHOENIX_STATUS_OK,
              phoenix_geometry_get_orientation(handle, &cOrientation) == PHOENIX_STATUS_OK,
              phoenix_geometry_get_signed_area(handle, &area) == PHOENIX_STATUS_OK else {
            phoenix_geometry_destroy(handle)
            throw GeometryError.core("PhoenixCore returned incomplete geometry data.")
        }

        // SwiftUI consumes an immutable local snapshot. The retained handle is
        // still used for computational queries such as outward normals.
        var copiedPoints = [phoenix_point2d](repeating: phoenix_point2d(), count: pointCount)
        let copyStatus = copiedPoints.withUnsafeMutableBufferPointer { buffer in
            phoenix_geometry_copy_points(handle, buffer.baseAddress, buffer.count)
        }
        guard copyStatus == PHOENIX_STATUS_OK else {
            phoenix_geometry_destroy(handle)
            throw GeometryError.core("PhoenixCore could not copy the geometry coordinates.")
        }

        self.handle = handle
        self.points = copiedPoints.map {
            Point2D(x: $0.x, y: $0.y)
        }
        self.connectivity = cConnectivity == PHOENIX_CONNECTIVITY_PERIODIC ? .periodic : .open
        self.orientation = cOrientation == PHOENIX_ORIENTATION_COUNTER_CLOCKWISE
            ? .counterClockwise
            : .clockwise
        self.bounds = GeometryBounds(
            minimum: Point2D(x: cBounds.minimum.x, y: cBounds.minimum.y),
            maximum: Point2D(x: cBounds.maximum.x, y: cBounds.maximum.y)
        )
        self.metadata = metadata
        self.signedArea = area
    }

    deinit {
        phoenix_geometry_destroy(handle)
    }

    func nextIndex(after index: Int) -> Int? {
        guard points.indices.contains(index) else { return nil }
        if index + 1 < points.count { return index + 1 }
        return connectivity == .periodic ? 0 : nil
    }

    func point(atPeriodicIndex index: Int) throws -> Point2D {
        guard connectivity == .periodic else {
            guard points.indices.contains(index) else { throw GeometryError.indexOutOfBounds(index) }
            return points[index]
        }
        // Swift's remainder may be negative, so normalize twice for periodic
        // indexing in both directions.
        let wrappedIndex = ((index % points.count) + points.count) % points.count
        return points[wrappedIndex]
    }

    func outwardUnitNormal(at index: Int) throws -> Vector2D {
        guard index >= 0 else { throw GeometryError.indexOutOfBounds(index) }
        var normal = phoenix_point2d()
        var errorBuffer = [CChar](repeating: 0, count: 256)
        let status = errorBuffer.withUnsafeMutableBufferPointer { buffer in
            phoenix_geometry_get_outward_unit_normal(
                handle, index, &normal, buffer.baseAddress, buffer.count
            )
        }
        guard status == PHOENIX_STATUS_OK else {
            if index >= points.count { throw GeometryError.indexOutOfBounds(index) }
            throw phoenixError(status: status, buffer: errorBuffer)
        }
        return Vector2D(x: normal.x, y: normal.y)
    }
}

/// Converts a C status/error buffer into the single Swift error surface used by the UI.
nonisolated func phoenixError(status: phoenix_status, buffer: [CChar]) -> GeometryError {
    let message = buffer.withUnsafeBufferPointer { pointer in
        guard let address = pointer.baseAddress, address.pointee != 0 else {
            return String(cString: phoenix_status_description(status))
        }
        return String(cString: address)
    }
    return .core(message)
}
