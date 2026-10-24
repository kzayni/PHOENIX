#pragma once

#include "phoenix/geometry/NACA4Airfoil.hpp"
#include "phoenix/geometry/SurfaceGeometry2D.hpp"

#include <cstddef>
#include <string>

namespace phoenix::geometry {

/// @brief Inputs to the classical NACA five-digit construction.
struct NACA5Parameters {
    std::string designation{"23012"};
    double chordLength{1.0};
    std::size_t pointCount{256};
    PointDistribution pointDistribution{PointDistribution::cosine};
    TrailingEdge trailingEdge{TrailingEdge::closed};
};

/**
 * @brief Generates a classical NACA five-digit surface contour.
 *
 * The first digit specifies design lift, the next two select a standard normal
 * (`10`, `20`, ..., `50`) or reflex (`21`, `31`, ..., `51`) mean line, and the
 * final two specify thickness as percent chord. Standard tabulated mean-line
 * constants are used, with design lift scaled from the tabulated NACA `2xxxx`
 * family. Thickness and surface offset follow the classical NACA polynomial.
 * Calculations use `double`.
 *
 * @param parameters Designation, chord length, exact final point count,
 *        chordwise distribution, and trailing-edge convention.
 * @return Counter-clockwise periodic geometry ordered from upper trailing
 *         edge through leading edge to lower trailing edge. The seam point is
 *         not repeated.
 * @throws std::invalid_argument for unsupported/malformed/degenerate
 *         designations, non-finite or nonpositive chord, or fewer than eight
 *         points.
 */
[[nodiscard]] SurfaceGeometry2D generateNACA5(const NACA5Parameters& parameters = {});

} // namespace phoenix::geometry
