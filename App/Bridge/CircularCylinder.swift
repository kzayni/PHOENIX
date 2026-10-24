import Foundation

nonisolated struct CircularCylinderMetadata: Equatable, Sendable {
    let radius: Double
    let center: Point2D
    let pointCount: Int
    let startingAngleDegrees: Double
}

nonisolated struct CircularCylinderParameters: Equatable, Sendable {
    var radius = 0.5
    var center = Point2D(x: 0.0, y: 0.0)
    var pointCount = 256
    var startingAngleDegrees = 0.0
}

/// Swift/C adapter; cylinder generation and validation live only in PhoenixCore.
nonisolated enum CircularCylinder {
    static func generate(
        _ parameters: CircularCylinderParameters = CircularCylinderParameters()
    ) throws -> SurfaceGeometry2D {
        var cParameters = phoenix_cylinder_parameters(
            radius: parameters.radius,
            center: phoenix_point2d(x: parameters.center.x, y: parameters.center.y),
            point_count: parameters.pointCount,
            starting_angle_degrees: parameters.startingAngleDegrees
        )
        var handle: OpaquePointer?
        var errorBuffer = [CChar](repeating: 0, count: 512)
        let status = errorBuffer.withUnsafeMutableBufferPointer { buffer in
            phoenix_generate_cylinder(&cParameters, &handle, buffer.baseAddress, buffer.count)
        }
        guard status == PHOENIX_STATUS_OK, let handle else {
            throw phoenixError(status: status, buffer: errorBuffer)
        }
        let metadata = CircularCylinderMetadata(
            radius: parameters.radius,
            center: parameters.center,
            pointCount: parameters.pointCount,
            startingAngleDegrees: parameters.startingAngleDegrees
        )
        return try SurfaceGeometry2D(ownedHandle: handle, metadata: .circularCylinder(metadata))
    }
}
