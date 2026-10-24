#pragma once

#include <cstddef>
#include <span>
#include <vector>

namespace phoenix::geometry {

/// @brief Cartesian point in the two-dimensional physical domain.
struct Point2D {
    double x;
    double y;
};

/// @brief Cartesian vector in the two-dimensional physical domain.
struct Vector2D {
    double x;
    double y;
};

/// @brief Axis-aligned physical-coordinate bounds.
struct Bounds2D {
    Point2D minimum;
    Point2D maximum;
};

/// @brief Connectivity at the contour seam.
enum class Connectivity {
    periodic,
    open,
};

/// @brief Orientation determined from the signed shoelace area.
enum class Orientation {
    counterClockwise,
    clockwise,
};

/// An ordered two-dimensional contour.
///
/// Generated bodies are counter-clockwise and do not repeat their first point
/// at the periodic seam. For a counter-clockwise contour the outward normal is
/// the right-hand normal `(tangent.y, -tangent.x)`.
class SurfaceGeometry2D final {
public:
    /// @brief Validates and takes ownership of an ordered contour.
    /// @param points Finite physical-coordinate points. Periodic contours must
    ///        contain at least three points and omit a repeated seam endpoint.
    /// @param connectivity Whether the final point connects back to the first.
    /// @throws std::invalid_argument if the contour is too short, non-finite,
    ///         contains a zero-length segment, or encloses negligible area.
    SurfaceGeometry2D(std::vector<Point2D> points, Connectivity connectivity);

    [[nodiscard]] std::span<const Point2D> points() const noexcept { return points_; }
    [[nodiscard]] Connectivity connectivity() const noexcept { return connectivity_; }
    [[nodiscard]] Orientation orientation() const noexcept { return orientation_; }
    [[nodiscard]] const Bounds2D& bounds() const noexcept { return bounds_; }
    [[nodiscard]] double signedArea() const noexcept { return signedArea_; }
    [[nodiscard]] std::size_t segmentCount() const noexcept;
    /// @brief Computes a centered-tangent outward unit normal.
    /// @param index Surface-point index. Open endpoints use one-sided tangents.
    /// @return Unit normal consistent with the contour orientation.
    /// @throws std::out_of_range if `index` is invalid.
    [[nodiscard]] Vector2D outwardUnitNormal(std::size_t index) const;

private:
    std::vector<Point2D> points_;
    Connectivity connectivity_;
    Orientation orientation_;
    Bounds2D bounds_;
    double signedArea_;
};

} // namespace phoenix::geometry
