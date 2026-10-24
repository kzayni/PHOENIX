/** @file GeometryTests.cpp
 *  @brief Dependency-free regression checks for geometry math and the C ABI.
 */
#include "phoenix/c_api.h"
#include "phoenix/geometry/CircularCylinder.hpp"
#include "phoenix/geometry/NACA4Airfoil.hpp"
#include "phoenix/geometry/NACA5Airfoil.hpp"

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <numbers>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

constexpr double tolerance = 1.0e-12;

void require(const bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

void requireApproximately(
    const double actual,
    const double expected,
    const std::string& message
) {
    require(std::abs(actual - expected) <= tolerance, message);
}

void testNACA() {
    // Combine analytical thickness checks with contour symmetry/orientation so
    // regressions in either sampling or formula evaluation are visible.
    phoenix::geometry::NACA4Parameters parameters;
    parameters.designation = "0012";
    parameters.pointCount = 255;
    parameters.trailingEdge = phoenix::geometry::TrailingEdge::open;
    const auto geometry = phoenix::geometry::generateNACA4(parameters);
    require(geometry.points().size() == 255, "NACA point count changed");
    require(geometry.signedArea() > 0.0, "NACA contour is not counter-clockwise");

    for (const auto point : geometry.points()) {
        double nearestSquaredDistance = INFINITY;
        for (const auto candidate : geometry.points()) {
            const double dx = candidate.x - point.x;
            const double dy = candidate.y + point.y;
            nearestSquaredDistance = std::min(nearestSquaredDistance, dx * dx + dy * dy);
        }
        require(nearestSquaredDistance <= 1.0e-24, "NACA 0012 lost symmetry");
    }

    parameters.pointCount = 256;
    parameters.trailingEdge = phoenix::geometry::TrailingEdge::closed;
    parameters.pointDistribution = phoenix::geometry::PointDistribution::uniform;
    const auto closed = phoenix::geometry::generateNACA4(parameters);
    const double x = 0.5;
    const double expectedThickness = 5.0 * 0.12 * (
        0.2969 * std::sqrt(x) - 0.1260 * x - 0.3516 * x * x
        + 0.2843 * x * x * x - 0.1036 * x * x * x * x
    );
    requireApproximately(closed.points()[64].y, expectedThickness, "NACA thickness changed");
    requireApproximately(closed.points()[192].y, -expectedThickness, "NACA lower thickness changed");
}

void testNACA5() {
    // Paired upper/lower samples recover the mean line because thickness is
    // offset symmetrically along its local normal.
    phoenix::geometry::NACA5Parameters parameters;
    parameters.designation = "23012";
    parameters.pointCount = 256;
    parameters.pointDistribution = phoenix::geometry::PointDistribution::uniform;
    parameters.trailingEdge = phoenix::geometry::TrailingEdge::closed;
    const auto normal = phoenix::geometry::generateNACA5(parameters);
    require(normal.points().size() == 256, "NACA five-digit point count changed");
    require(normal.signedArea() > 0.0, "NACA five-digit contour is not counter-clockwise");

    const double m = 0.2025;
    const double expectedCamber = (15.957 * m * m * m / 6.0) * 0.5;
    requireApproximately(
        0.5 * (normal.points()[64].x + normal.points()[192].x),
        0.5,
        "NACA 23012 paired x coordinate changed"
    );
    requireApproximately(
        0.5 * (normal.points()[64].y + normal.points()[192].y),
        expectedCamber,
        "NACA 23012 mean line changed"
    );

    parameters.designation = "23112";
    const auto reflex = phoenix::geometry::generateNACA5(parameters);
    const double reflexM = 0.2170;
    const double k1 = 15.793;
    const double ratio = 0.00677;
    const double x = 0.5;
    const double expectedReflexCamber = (k1 / 6.0) * (
        ratio * std::pow(x - reflexM, 3.0)
        - ratio * std::pow(1.0 - reflexM, 3.0) * x
        - std::pow(reflexM, 3.0) * x
        + std::pow(reflexM, 3.0)
    );
    requireApproximately(
        0.5 * (reflex.points()[64].y + reflex.points()[192].y),
        expectedReflexCamber,
        "NACA 23112 reflex mean line changed"
    );
}

void testCylinder() {
    phoenix::geometry::CircularCylinderParameters parameters;
    parameters.radius = 3.0;
    parameters.center = {2.0, -1.0};
    parameters.pointCount = 64;
    const auto geometry = phoenix::geometry::generateCircularCylinder(parameters);
    require(geometry.points().size() == 64, "Cylinder point count changed");
    for (const auto point : geometry.points()) {
        requireApproximately(
            std::hypot(point.x - parameters.center.x, point.y - parameters.center.y),
            parameters.radius,
            "Cylinder point is off radius"
        );
    }
    requireApproximately(geometry.bounds().minimum.x, -1.0, "Cylinder minimum x changed");
    requireApproximately(geometry.bounds().maximum.y, 2.0, "Cylinder maximum y changed");
    const auto normal = geometry.outwardUnitNormal(0);
    requireApproximately(normal.x, 1.0, "Cylinder normal x changed");
    requireApproximately(normal.y, 0.0, "Cylinder normal y changed");
}

void testInvalidInputs() {
    bool rejected = false;
    try {
        phoenix::geometry::NACA4Parameters invalid;
        invalid.designation = "0000";
        static_cast<void>(phoenix::geometry::generateNACA4(invalid));
    } catch (const std::invalid_argument&) {
        rejected = true;
    }
    require(rejected, "Degenerate NACA profile was accepted");

    rejected = false;
    try {
        phoenix::geometry::NACA5Parameters invalid;
        invalid.designation = "20112";
        static_cast<void>(phoenix::geometry::generateNACA5(invalid));
    } catch (const std::invalid_argument&) {
        rejected = true;
    }
    require(rejected, "Unsupported NACA five-digit mean line was accepted");

    rejected = false;
    try {
        phoenix::geometry::CircularCylinderParameters invalid;
        invalid.radius = 0.0;
        static_cast<void>(phoenix::geometry::generateCircularCylinder(invalid));
    } catch (const std::invalid_argument&) {
        rejected = true;
    }
    require(rejected, "Zero-radius cylinder was accepted");
}

void testCAPIOwnershipAndErrors() {
    // This test intentionally uses only the public C surface, including the
    // required caller-buffer and destroy pairing used by Swift.
    char error[256]{};
    phoenix_geometry* geometry = nullptr;
    const phoenix_naca4_parameters parameters{
        "2412",
        2.0,
        128,
        PHOENIX_POINT_DISTRIBUTION_COSINE,
        PHOENIX_TRAILING_EDGE_CLOSED,
    };
    require(
        phoenix_generate_naca4(&parameters, &geometry, error, sizeof(error)) == PHOENIX_STATUS_OK,
        "C API generation failed"
    );
    require(geometry != nullptr, "C API did not return owned geometry");
    std::size_t count = 0;
    require(
        phoenix_geometry_get_point_count(geometry, &count) == PHOENIX_STATUS_OK,
        "C API point-count access failed"
    );
    require(count == 128, "C API point count is invalid");
    std::vector<phoenix_point2d> points(count);
    require(
        phoenix_geometry_copy_points(geometry, points.data(), points.size() - 1)
            == PHOENIX_STATUS_INVALID_ARGUMENT,
        "C API accepted an undersized point buffer"
    );
    require(
        phoenix_geometry_copy_points(geometry, points.data(), points.size()) == PHOENIX_STATUS_OK,
        "C API point copy failed"
    );
    phoenix_geometry_destroy(geometry);
    phoenix_geometry_destroy(nullptr);

    const phoenix_naca5_parameters fiveDigitParameters{
        "23012",
        1.0,
        128,
        PHOENIX_POINT_DISTRIBUTION_COSINE,
        PHOENIX_TRAILING_EDGE_CLOSED,
    };
    geometry = nullptr;
    require(
        phoenix_generate_naca5(
            &fiveDigitParameters, &geometry, error, sizeof(error)
        ) == PHOENIX_STATUS_OK,
        "C API five-digit generation failed"
    );
    require(geometry != nullptr, "C API five-digit generation returned no geometry");
    phoenix_geometry_destroy(geometry);

    const phoenix_cylinder_parameters invalid{0.0, {0.0, 0.0}, 64, 0.0};
    geometry = reinterpret_cast<phoenix_geometry*>(0x1);
    require(
        phoenix_generate_cylinder(&invalid, &geometry, error, sizeof(error))
            == PHOENIX_STATUS_INVALID_ARGUMENT,
        "C API invalid input did not return an error"
    );
    require(geometry == nullptr, "C API left an output handle after failure");
    require(error[0] != '\0', "C API did not return an error message");

    // Repeated construction/destruction exercises the documented allocator
    // pairing and catches stale-output ownership regressions under sanitizers.
    for (int iteration = 0; iteration < 256; ++iteration) {
        geometry = nullptr;
        require(
            phoenix_generate_naca4(&parameters, &geometry, error, sizeof(error))
                == PHOENIX_STATUS_OK,
            "Repeated C API generation failed"
        );
        phoenix_geometry_destroy(geometry);
    }
}

} // namespace

int main() {
    try {
        testNACA();
        testNACA5();
        testCylinder();
        testInvalidInputs();
        testCAPIOwnershipAndErrors();
        std::cout << "PhoenixCore geometry tests passed\n";
        return EXIT_SUCCESS;
    } catch (const std::exception& error) {
        std::cerr << "PhoenixCore geometry test failure: " << error.what() << '\n';
        return EXIT_FAILURE;
    }
}
