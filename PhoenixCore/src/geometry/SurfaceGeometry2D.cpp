/** @file SurfaceGeometry2D.cpp
 *  @brief Contour invariant checks and orientation-aware surface operations.
 */
#include "phoenix/geometry/SurfaceGeometry2D.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <stdexcept>
#include <utility>

namespace phoenix::geometry {

namespace {

[[nodiscard]] bool isFinite(const Point2D point) noexcept {
    return std::isfinite(point.x) && std::isfinite(point.y);
}

[[nodiscard]] double distanceSquared(const Point2D first, const Point2D second) noexcept {
    const double dx = second.x - first.x;
    const double dy = second.y - first.y;
    return dx * dx + dy * dy;
}

} // namespace

SurfaceGeometry2D::SurfaceGeometry2D(
    std::vector<Point2D> points,
    const Connectivity connectivity
) : points_(std::move(points)), connectivity_(connectivity) {
    const std::size_t minimumCount = connectivity == Connectivity::periodic ? 3 : 2;
    if (points_.size() < minimumCount) {
        throw std::invalid_argument("The contour does not contain enough points for its connectivity.");
    }
    if (!std::ranges::all_of(points_, isFinite)) {
        throw std::invalid_argument("Surface coordinates must be finite numbers.");
    }

    // Validate the seam segment only for periodic contours; open contours have
    // no implicit last-to-first edge.
    const std::size_t checkedSegmentCount =
        connectivity == Connectivity::periodic ? points_.size() : points_.size() - 1;
    for (std::size_t index = 0; index < checkedSegmentCount; ++index) {
        const std::size_t nextIndex = (index + 1) % points_.size();
        if (!(distanceSquared(points_[index], points_[nextIndex]) > 0.0)) {
            throw std::invalid_argument(
                "The contour contains a zero-length segment between consecutive points."
            );
        }
    }

    const auto [minimumX, maximumX] = std::ranges::minmax_element(
        points_, {}, &Point2D::x
    );
    const auto [minimumY, maximumY] = std::ranges::minmax_element(
        points_, {}, &Point2D::y
    );
    bounds_ = {
        {minimumX->x, minimumY->y},
        {maximumX->x, maximumY->y},
    };

    // The signed shoelace area determines both degeneracy and orientation.
    double twiceArea = 0.0;
    for (std::size_t index = 0; index < points_.size(); ++index) {
        const Point2D next = points_[(index + 1) % points_.size()];
        twiceArea += points_[index].x * next.y - next.x * points_[index].y;
    }
    signedArea_ = 0.5 * twiceArea;
    // Scale the degeneracy threshold by geometry size so the check remains
    // meaningful when users change chord or radius.
    const double scale = std::max(
        bounds_.maximum.x - bounds_.minimum.x,
        bounds_.maximum.y - bounds_.minimum.y
    );
    if (!(std::abs(signedArea_) > 1.0e-14 * scale * scale)) {
        throw std::invalid_argument("The contour has zero or numerically negligible enclosed area.");
    }
    orientation_ = signedArea_ > 0.0
        ? Orientation::counterClockwise
        : Orientation::clockwise;
}

std::size_t SurfaceGeometry2D::segmentCount() const noexcept {
    return connectivity_ == Connectivity::periodic ? points_.size() : points_.size() - 1;
}

Vector2D SurfaceGeometry2D::outwardUnitNormal(const std::size_t index) const {
    if (index >= points_.size()) {
        throw std::out_of_range("Surface-point index is out of bounds.");
    }

    std::size_t previousIndex;
    std::size_t nextIndex;
    if (connectivity_ == Connectivity::periodic) {
        // Centered tangents wrap naturally across a seam-unique contour.
        previousIndex = (index + points_.size() - 1) % points_.size();
        nextIndex = (index + 1) % points_.size();
    } else if (index == 0) {
        previousIndex = index;
        nextIndex = index + 1;
    } else if (index + 1 == points_.size()) {
        previousIndex = index - 1;
        nextIndex = index;
    } else {
        previousIndex = index - 1;
        nextIndex = index + 1;
    }

    const double tangentX = points_[nextIndex].x - points_[previousIndex].x;
    const double tangentY = points_[nextIndex].y - points_[previousIndex].y;
    const double magnitude = std::hypot(tangentX, tangentY);
    if (!(magnitude > 0.0)) {
        throw std::invalid_argument(
            "The contour contains a zero-length tangent at the requested point."
        );
    }

    // The exterior lies to the right of a counter-clockwise directed contour
    // and to the left of a clockwise contour.
    if (orientation_ == Orientation::counterClockwise) {
        return {tangentY / magnitude, -tangentX / magnitude};
    }
    return {-tangentY / magnitude, tangentX / magnitude};
}

} // namespace phoenix::geometry
