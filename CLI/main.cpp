/** @file main.cpp
 *  @brief Headless argument parsing and CSV output for PhoenixCore geometry.
 */
#include "phoenix/geometry/CircularCylinder.hpp"
#include "phoenix/geometry/NACA4Airfoil.hpp"
#include "phoenix/geometry/NACA5Airfoil.hpp"

#include <charconv>
#include <cstddef>
#include <exception>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>
#include <string_view>

namespace {

using phoenix::geometry::CircularCylinderParameters;
using phoenix::geometry::NACA4Parameters;
using phoenix::geometry::NACA5Parameters;
using phoenix::geometry::PointDistribution;
using phoenix::geometry::SurfaceGeometry2D;
using phoenix::geometry::TrailingEdge;

[[noreturn]] void usageError(const std::string& message) {
    throw std::invalid_argument(message + "\nRun 'phoenix help' for usage.");
}

[[nodiscard]] std::string_view requireValue(int& index, const int count, char** values) {
    if (++index >= count) {
        usageError(std::string("Missing value after ") + values[index - 1] + ".");
    }
    return values[index];
}

[[nodiscard]] double parseDouble(const std::string_view text, const std::string_view option) {
    double value = 0.0;
    const auto result = std::from_chars(text.data(), text.data() + text.size(), value);
    if (result.ec != std::errc{} || result.ptr != text.data() + text.size()) {
        usageError("Invalid numeric value for " + std::string(option) + ": " + std::string(text));
    }
    return value;
}

[[nodiscard]] std::size_t parsePointCount(
    const std::string_view text,
    const std::string_view option
) {
    std::size_t value = 0;
    const auto result = std::from_chars(text.data(), text.data() + text.size(), value);
    if (result.ec != std::errc{} || result.ptr != text.data() + text.size()) {
        usageError("Invalid integer value for " + std::string(option) + ": " + std::string(text));
    }
    return value;
}

void writeCSV(const SurfaceGeometry2D& geometry, const std::string& path) {
    std::ofstream output(path);
    if (!output) {
        throw std::runtime_error("Could not open output file: " + path);
    }
    output << "x,y\n" << std::setprecision(17);
    for (const auto point : geometry.points()) {
        output << point.x << ',' << point.y << '\n';
    }
    if (!output) {
        throw std::runtime_error("Failed while writing output file: " + path);
    }
}

void printUsage() {
    std::cout
        << "PHOENIX headless computational interface\n\n"
        << "Usage:\n"
        << "  phoenix geometry naca --profile 0012|23012 --points 256 --output FILE\n"
        << "      [--chord 1.0] [--distribution cosine|uniform]\n"
        << "      [--trailing-edge closed|open]\n"
        << "  phoenix geometry cylinder --radius 0.5 --points 256 --output FILE\n"
        << "      [--center-x 0] [--center-y 0] [--start-angle 0]\n";
}

int runNACA(const int count, char** values) {
    NACA4Parameters parameters;
    std::string outputPath;
    for (int index = 3; index < count; ++index) {
        const std::string_view option = values[index];
        if (option == "--profile") {
            parameters.designation = requireValue(index, count, values);
        } else if (option == "--points") {
            parameters.pointCount = parsePointCount(requireValue(index, count, values), option);
        } else if (option == "--output") {
            outputPath = requireValue(index, count, values);
        } else if (option == "--chord") {
            parameters.chordLength = parseDouble(requireValue(index, count, values), option);
        } else if (option == "--distribution") {
            const auto value = requireValue(index, count, values);
            if (value == "uniform") {
                parameters.pointDistribution = PointDistribution::uniform;
            } else if (value == "cosine") {
                parameters.pointDistribution = PointDistribution::cosine;
            } else {
                usageError("Distribution must be 'uniform' or 'cosine'.");
            }
        } else if (option == "--trailing-edge") {
            const auto value = requireValue(index, count, values);
            if (value == "open") {
                parameters.trailingEdge = TrailingEdge::open;
            } else if (value == "closed") {
                parameters.trailingEdge = TrailingEdge::closed;
            } else {
                usageError("Trailing edge must be 'open' or 'closed'.");
            }
        } else {
            usageError("Unknown NACA option: " + std::string(option));
        }
    }
    if (outputPath.empty()) {
        usageError("The --output option is required.");
    }
    if (parameters.designation.size() == 4) {
        writeCSV(phoenix::geometry::generateNACA4(parameters), outputPath);
    } else if (parameters.designation.size() == 5) {
        writeCSV(
            phoenix::geometry::generateNACA5(NACA5Parameters{
                parameters.designation,
                parameters.chordLength,
                parameters.pointCount,
                parameters.pointDistribution,
                parameters.trailingEdge,
            }),
            outputPath
        );
    } else {
        usageError("NACA profile must contain four or five digits.");
    }
    return 0;
}

int runCylinder(const int count, char** values) {
    CircularCylinderParameters parameters;
    std::string outputPath;
    for (int index = 3; index < count; ++index) {
        const std::string_view option = values[index];
        if (option == "--radius") {
            parameters.radius = parseDouble(requireValue(index, count, values), option);
        } else if (option == "--points") {
            parameters.pointCount = parsePointCount(requireValue(index, count, values), option);
        } else if (option == "--output") {
            outputPath = requireValue(index, count, values);
        } else if (option == "--center-x") {
            parameters.center.x = parseDouble(requireValue(index, count, values), option);
        } else if (option == "--center-y") {
            parameters.center.y = parseDouble(requireValue(index, count, values), option);
        } else if (option == "--start-angle") {
            parameters.startingAngleDegrees = parseDouble(requireValue(index, count, values), option);
        } else {
            usageError("Unknown cylinder option: " + std::string(option));
        }
    }
    if (outputPath.empty()) {
        usageError("The --output option is required.");
    }
    writeCSV(phoenix::geometry::generateCircularCylinder(parameters), outputPath);
    return 0;
}

} // namespace

int main(const int count, char** values) {
    try {
        if (count == 2 && std::string_view(values[1]) == "help") {
            printUsage();
            return 0;
        }
        if (count < 3 || std::string_view(values[1]) != "geometry") {
            usageError("Expected a geometry command.");
        }
        const std::string_view generator = values[2];
        if (generator == "naca") {
            return runNACA(count, values);
        }
        if (generator == "cylinder") {
            return runCylinder(count, values);
        }
        usageError("Unknown geometry generator: " + std::string(generator));
    } catch (const std::invalid_argument& error) {
        std::cerr << "phoenix: " << error.what() << '\n';
        return 2;
    } catch (const std::exception& error) {
        std::cerr << "phoenix: " << error.what() << '\n';
        return 1;
    }
}
