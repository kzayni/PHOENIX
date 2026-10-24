/** @file NACA5Airfoil.cpp
 *  @brief Classical NACA five-digit coordinate construction and sampling.
 */
#include "phoenix/geometry/NACA5Airfoil.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <numbers>
#include <stdexcept>
#include <string>
#include <vector>

namespace phoenix::geometry {

namespace {

struct MeanLine {
    double m;
    double k1;
    double k2OverK1;
    bool reflex;
};

struct Digits {
    double designLiftScale;
    double thicknessRatio;
    MeanLine meanLine;
};

struct Camber {
    double ordinate;
    double slope;
};

struct SurfacePair {
    Point2D upper;
    Point2D lower;
};

[[nodiscard]] MeanLine normalMeanLine(const int code) {
    // The classical five-digit family is defined by tabulated m and k1 values;
    // deriving m directly from the designation would change the mean line.
    switch (code) {
    case 10: return {0.0580, 361.4, 0.0, false};
    case 20: return {0.1260, 51.64, 0.0, false};
    case 30: return {0.2025, 15.957, 0.0, false};
    case 40: return {0.2900, 6.643, 0.0, false};
    case 50: return {0.3910, 3.230, 0.0, false};
    default:
        throw std::invalid_argument(
            "A normal NACA five-digit mean-line code must be 10, 20, 30, 40, or 50."
        );
    }
}

[[nodiscard]] MeanLine reflexMeanLine(const int code) {
    // Reflex profiles add the tabulated k2/k1 ratio to enforce the intended
    // aft-camber behavior and pitching-moment characteristics.
    switch (code) {
    case 21: return {0.1300, 51.990, 0.000764, true};
    case 31: return {0.2170, 15.793, 0.00677, true};
    case 41: return {0.3180, 6.520, 0.0303, true};
    case 51: return {0.4410, 3.191, 0.1355, true};
    default:
        throw std::invalid_argument(
            "A reflex NACA five-digit mean-line code must be 21, 31, 41, or 51."
        );
    }
}

[[nodiscard]] Digits parse(const std::string& designation) {
    const bool allDigits = std::ranges::all_of(
        designation,
        [](const char value) { return value >= '0' && value <= '9'; }
    );
    if (designation.size() != 5 || !allDigits) {
        throw std::invalid_argument(
            "The NACA designation must contain exactly five decimal digits."
        );
    }

    const int liftDigit = designation[0] - '0';
    const int meanLineCode = 10 * (designation[1] - '0') + (designation[2] - '0');
    const int thicknessDigits = 10 * (designation[3] - '0') + (designation[4] - '0');
    if (liftDigit == 0 || thicknessDigits == 0) {
        throw std::invalid_argument(
            "The NACA five-digit designation requires nonzero design lift and thickness."
        );
    }

    const bool reflex = meanLineCode % 10 == 1;
    // Tables are normalized for the NACA 2xxxx design lift; scale k1 linearly
    // for the designation's first digit.
    return {
        static_cast<double>(liftDigit) / 2.0,
        static_cast<double>(thicknessDigits) / 100.0,
        reflex ? reflexMeanLine(meanLineCode) : normalMeanLine(meanLineCode),
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
        // Cosine spacing clusters stations at both leading and trailing edges.
        stations.push_back(distribution == PointDistribution::uniform
            ? fraction
            : 0.5 * (1.0 - std::cos(std::numbers::pi * fraction)));
    }
    return stations;
}

[[nodiscard]] Camber camberAt(const double x, const Digits& digits) {
    const auto [m, tabulatedK1, k2OverK1, reflex] = digits.meanLine;
    const double k1 = digits.designLiftScale * tabulatedK1;
    if (!reflex) {
        // Normal mean lines use a cubic forward branch and linear aft branch,
        // joined continuously at the tabulated m station.
        if (x < m) {
            return {
                (k1 / 6.0) * (x * x * x - 3.0 * m * x * x + m * m * (3.0 - m) * x),
                (k1 / 6.0) * (3.0 * x * x - 6.0 * m * x + m * m * (3.0 - m)),
            };
        }
        return {
            (k1 * m * m * m / 6.0) * (1.0 - x),
            -(k1 * m * m * m / 6.0),
        };
    }

    // Reflex branches share constant terms that preserve endpoint and join
    // conditions while changing the cubic coefficient aft of m.
    const double mCubed = m * m * m;
    const double aftCubed = (1.0 - m) * (1.0 - m) * (1.0 - m);
    if (x < m) {
        const double offset = x - m;
        return {
            (k1 / 6.0) * (
                offset * offset * offset - k2OverK1 * aftCubed * x - mCubed * x + mCubed
            ),
            (k1 / 6.0) * (
                3.0 * offset * offset - k2OverK1 * aftCubed - mCubed
            ),
        };
    }
    const double offset = x - m;
    return {
        (k1 / 6.0) * (
            k2OverK1 * offset * offset * offset
            - k2OverK1 * aftCubed * x - mCubed * x + mCubed
        ),
        (k1 / 6.0) * (
            3.0 * k2OverK1 * offset * offset - k2OverK1 * aftCubed - mCubed
        ),
    };
}

[[nodiscard]] SurfacePair surfaceCoordinates(
    const double normalizedX,
    const Digits& digits,
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

    const Camber camber = camberAt(x, digits);
    // As in the four-digit construction, thickness is offset along the local
    // mean-line normal rather than along the global y direction.
    const double angle = std::atan(camber.slope);
    const double chordwiseX = chord * x;
    const double camberY = chord * camber.ordinate;
    return {
        {chordwiseX - thickness * std::sin(angle), camberY + thickness * std::cos(angle)},
        {chordwiseX + thickness * std::sin(angle), camberY - thickness * std::cos(angle)},
    };
}

} // namespace

SurfaceGeometry2D generateNACA5(const NACA5Parameters& parameters) {
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

    // Preserve an exact final count while representing a sharp edge once and a
    // blunt edge with distinct upper/lower seam points.
    const std::size_t upperStationCount = parameters.pointCount / 2 + 1;
    const std::size_t lowerStationCount = parameters.trailingEdge == TrailingEdge::closed
        ? parameters.pointCount - upperStationCount + 2
        : parameters.pointCount - upperStationCount + 1;
    const auto upperStations = chordStations(upperStationCount, parameters.pointDistribution);
    const auto lowerStations = chordStations(lowerStationCount, parameters.pointDistribution);

    std::vector<Point2D> points;
    points.reserve(parameters.pointCount);
    // This traversal produces the project-wide counter-clockwise body order.
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
