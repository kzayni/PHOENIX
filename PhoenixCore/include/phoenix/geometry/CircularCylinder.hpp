#pragma once

#include "phoenix/geometry/SurfaceGeometry2D.hpp"

#include <cstddef>

namespace phoenix::geometry {

/// @brief Inputs to a uniformly sampled circular surface.
struct CircularCylinderParameters {
    double radius{0.5};
    Point2D center{0.0, 0.0};
    std::size_t pointCount{256};
    double startingAngleDegrees{0.0};
};

/// @brief Generates unique, uniformly spaced points with periodic connectivity.
/// @param parameters Radius, center in physical coordinates, exact final point
///        count, and counter-clockwise starting angle in degrees.
/// @return Counter-clockwise seam-unique periodic cylinder geometry.
/// @throws std::invalid_argument for non-finite values, nonpositive radius, or
///         fewer than three points.
[[nodiscard]] SurfaceGeometry2D generateCircularCylinder(
    const CircularCylinderParameters& parameters = {}
);

} // namespace phoenix::geometry
