// Swift-facing parameters and ownership adapter for five-digit NACA geometry.
import Foundation

/// Immutable inputs retained with a rendered five-digit airfoil snapshot.
nonisolated struct NACA5Metadata: Equatable, Sendable {
    let designation: String
    let chordLength: Double
    let pointCount: Int
    let pointDistribution: PointDistribution
    let trailingEdge: TrailingEdgeConfiguration
}

/// Editable five-digit NACA inputs using UI-friendly Swift values.
nonisolated struct NACA5Parameters: Equatable, Sendable {
    var designation = "23012"
    var chordLength = 1.0
    var pointCount = 256
    var pointDistribution = PointDistribution.cosine
    var trailingEdge = TrailingEdgeConfiguration.closed
}

/// Swift/C adapter; the five-digit NACA formulation and validation live only in PhoenixCore.
nonisolated enum NACA5Airfoil {
    static func generate(_ parameters: NACA5Parameters = NACA5Parameters()) throws -> SurfaceGeometry2D {
        var handle: OpaquePointer?
        var errorBuffer = [CChar](repeating: 0, count: 512)
        let status = parameters.designation.withCString { designation in
            // The designation pointer is borrowed by C++ only for this call.
            var cParameters = phoenix_naca5_parameters(
                designation: designation,
                chord_length: parameters.chordLength,
                point_count: parameters.pointCount,
                point_distribution: parameters.pointDistribution == .uniform
                    ? PHOENIX_POINT_DISTRIBUTION_UNIFORM
                    : PHOENIX_POINT_DISTRIBUTION_COSINE,
                trailing_edge: parameters.trailingEdge == .open
                    ? PHOENIX_TRAILING_EDGE_OPEN
                    : PHOENIX_TRAILING_EDGE_CLOSED
            )
            return errorBuffer.withUnsafeMutableBufferPointer { buffer in
                phoenix_generate_naca5(&cParameters, &handle, buffer.baseAddress, buffer.count)
            }
        }
        guard status == PHOENIX_STATUS_OK, let handle else {
            throw phoenixError(status: status, buffer: errorBuffer)
        }
        // SurfaceGeometry2D assumes ownership and pairs this handle with the
        // PhoenixCore destructor when the Swift snapshot is released.
        let metadata = NACA5Metadata(
            designation: parameters.designation,
            chordLength: parameters.chordLength,
            pointCount: parameters.pointCount,
            pointDistribution: parameters.pointDistribution,
            trailingEdge: parameters.trailingEdge
        )
        return try SurfaceGeometry2D(ownedHandle: handle, metadata: .nacaFiveDigit(metadata))
    }
}
