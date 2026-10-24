#pragma once

#include "phoenix/geometry/SurfaceGeometry2D.hpp"

#include <cstddef>
#include <string>

namespace phoenix::geometry {

/// @brief Chordwise station distribution on each airfoil surface.
enum class PointDistribution {
    uniform,
    cosine,
};

/// @brief Fourth-order thickness coefficient convention.
enum class TrailingEdge {
    open,
    closed,
};

/// @brief Inputs to the classical NACA four-digit construction.
struct NACA4Parameters {
    std::string designation{"0012"};
    double chordLength{1.0};
    std::size_t pointCount{256};
    PointDistribution pointDistribution{PointDistribution::cosine};
    TrailingEdge trailingEdge{TrailingEdge::closed};
};

/**
 * @brief Generates a classical NACA four-digit surface contour.
 *
 * The thickness distribution is
 * `y_t/c = 5t(0.2969 sqrt(x) - 0.1260x - 0.3516x^2 +
 * 0.2843x^3 - a_4x^4)`, with `a_4 = 0.1015` for an open and
 * `a_4 = 0.1036` for a closed trailing edge. The standard piecewise parabolic
 * camber line is offset along its local normal. Calculations use `double`.
 *
 * @param parameters Designation, chord length, exact final point count,
 *        chordwise distribution, and trailing-edge convention.
 * @return Counter-clockwise periodic geometry ordered from upper trailing
 *         edge through leading edge to lower trailing edge. The seam point is
 *         not repeated.
 * @throws std::invalid_argument for malformed/degenerate designations,
 *         non-finite or nonpositive chord, or fewer than eight points.
 */
[[nodiscard]] SurfaceGeometry2D generateNACA4(const NACA4Parameters& parameters = {});

} // namespace phoenix::geometry
