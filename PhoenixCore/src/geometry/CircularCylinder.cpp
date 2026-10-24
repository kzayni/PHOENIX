/** @file CircularCylinder.cpp
 *  @brief Validated, uniformly sampled circular-cylinder construction.
 */
#include "phoenix/geometry/CircularCylinder.hpp"

#include <cmath>
#include <numbers>
#include <stdexcept>
#include <vector>

namespace phoenix::geometry {

SurfaceGeometry2D generateCircularCylinder(const CircularCylinderParameters& parameters) {
    if (!std::isfinite(parameters.radius)) {
        throw std::invalid_argument("Radius must be a finite number.");
    }
    if (!(parameters.radius > 0.0)) {
        throw std::invalid_argument("Radius must be greater than zero.");
    }
    if (!std::isfinite(parameters.center.x) || !std::isfinite(parameters.center.y)) {
        throw std::invalid_argument("Center coordinates must be finite numbers.");
    }
    if (!std::isfinite(parameters.startingAngleDegrees)) {
        throw std::invalid_argument("Starting angle must be a finite number.");
    }
    if (parameters.pointCount < 3) {
        throw std::invalid_argument("Surface-point count must be at least 3.");
    }

    // Samples advance counter-clockwise in physical Cartesian coordinates and
    // omit the repeated 2π endpoint so the periodic seam remains unique.
    const double startingAngle = parameters.startingAngleDegrees * std::numbers::pi / 180.0;
    std::vector<Point2D> points;
    points.reserve(parameters.pointCount);
    for (std::size_t index = 0; index < parameters.pointCount; ++index) {
        const double angle = startingAngle
            + 2.0 * std::numbers::pi * static_cast<double>(index)
                / static_cast<double>(parameters.pointCount);
        points.push_back({
            parameters.center.x + parameters.radius * std::cos(angle),
            parameters.center.y + parameters.radius * std::sin(angle),
        });
    }
    return SurfaceGeometry2D(std::move(points), Connectivity::periodic);
}

} // namespace phoenix::geometry
