/** @file NACA4Airfoil.cpp
 *  @brief Classical NACA four-digit coordinate construction and sampling.
 */
#include "phoenix/geometry/NACA4Airfoil.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <numbers>
#include <stdexcept>
#include <string>
#include <vector>

namespace phoenix::geometry {

namespace {

struct Digits {
    double maximumCamber;
    double camberPosition;
    double thicknessRatio;
};

struct SurfacePair {
    Point2D upper;
    Point2D lower;
};

[[nodiscard]] Digits parse(const std::string& designation) {
    const bool allDigits = std::ranges::all_of(
        designation,
        [](const char value) { return value >= '0' && value <= '9'; }
    );
    if (designation.size() != 4 || !allDigits) {
        throw std::invalid_argument(
            "The NACA designation must contain exactly four decimal digits."
        );
    }

    const int maximumCamberDigit = designation[0] - '0';
    const int camberPositionDigit = designation[1] - '0';
    const int thicknessDigits = 10 * (designation[2] - '0') + (designation[3] - '0');
    const bool validCamber =
        (maximumCamberDigit == 0 && camberPositionDigit == 0)
        || (maximumCamberDigit > 0 && camberPositionDigit > 0);
    if (thicknessDigits == 0 || !validCamber) {
        throw std::invalid_argument(
            "The NACA designation requires nonzero thickness and a consistent camber position."
        );
    }

    return {
        static_cast<double>(maximumCamberDigit) / 100.0,
        static_cast<double>(camberPositionDigit) / 10.0,
        static_cast<double>(thicknessDigits) / 100.0,
    };
}

[[nodiscard]] std::vector<double> chordStations(
    const std::size_t count,
    const PointDistribution distribution
) {
    std::vector<double> stations;
    stations.reserve(count);
    for (std::size_t index = 0; index < count; ++index) {
        const double fraction = static_cast<double>(index) / static_cast<double>(count - 1);
        stations.push_back(distribution == PointDistribution::uniform
            ? fraction
            : 0.5 * (1.0 - std::cos(std::numbers::pi * fraction)));
    }
    return stations;
}

[[nodiscard]] SurfacePair surfaceCoordinates(
    const double normalizedX,
    const Digits digits,
    const double chord,
    const TrailingEdge trailingEdge
) {
    const double x = normalizedX;
    const double fourthOrderCoefficient = trailingEdge == TrailingEdge::open ? 0.1015 : 0.1036;
    double thickness = 5.0 * digits.thicknessRatio * chord * (
        0.2969 * std::sqrt(x)
        - 0.1260 * x
        - 0.3516 * x * x
        + 0.2843 * x * x * x
        - fourthOrderCoefficient * x * x * x * x
    );
    if (trailingEdge == TrailingEdge::closed && x == 1.0) {
        thickness = 0.0;
    }

    double camber = 0.0;
    double camberSlope = 0.0;
    if (digits.maximumCamber > 0.0 && x < digits.camberPosition) {
        const double scale = digits.maximumCamber / (digits.camberPosition * digits.camberPosition);
        camber = scale * (2.0 * digits.camberPosition * x - x * x);
        camberSlope = 2.0 * scale * (digits.camberPosition - x);
    } else if (digits.maximumCamber > 0.0) {
        const double aftLength = 1.0 - digits.camberPosition;
        const double scale = digits.maximumCamber / (aftLength * aftLength);
        camber = scale * (
            1.0 - 2.0 * digits.camberPosition
            + 2.0 * digits.camberPosition * x
            - x * x
        );
        camberSlope = 2.0 * scale * (digits.camberPosition - x);
    }

    const double angle = std::atan(camberSlope);
    const double chordwiseX = chord * x;
    const double camberY = chord * camber;
    return {
        {chordwiseX - thickness * std::sin(angle), camberY + thickness * std::cos(angle)},
        {chordwiseX + thickness * std::sin(angle), camberY - thickness * std::cos(angle)},
    };
}

} // namespace

SurfaceGeometry2D generateNACA4(const NACA4Parameters& parameters) {
    const Digits digits = parse(parameters.designation);
    if (!std::isfinite(parameters.chordLength)) {
        throw std::invalid_argument("Chord length must be a finite number.");
    }
    if (!(parameters.chordLength > 0.0)) {
        throw std::invalid_argument("Chord length must be greater than zero.");
    }
    if (parameters.pointCount < 8) {
        throw std::invalid_argument("Surface-point count must be at least 8.");
    }

    const std::size_t upperStationCount = parameters.pointCount / 2 + 1;
    const std::size_t lowerStationCount = parameters.trailingEdge == TrailingEdge::closed
        ? parameters.pointCount - upperStationCount + 2
        : parameters.pointCount - upperStationCount + 1;
    const auto upperStations = chordStations(upperStationCount, parameters.pointDistribution);
    const auto lowerStations = chordStations(lowerStationCount, parameters.pointDistribution);

    std::vector<Point2D> points;
    points.reserve(parameters.pointCount);
    for (auto station = upperStations.rbegin(); station != upperStations.rend(); ++station) {
        points.push_back(surfaceCoordinates(
            *station, digits, parameters.chordLength, parameters.trailingEdge
        ).upper);
    }
    const std::size_t lowerEndOffset = parameters.trailingEdge == TrailingEdge::closed ? 1 : 0;
    for (std::size_t index = 1; index < lowerStations.size() - lowerEndOffset; ++index) {
        points.push_back(surfaceCoordinates(
            lowerStations[index], digits, parameters.chordLength, parameters.trailingEdge
        ).lower);
    }

    return SurfaceGeometry2D(std::move(points), Connectivity::periodic);
}

} // namespace phoenix::geometry
