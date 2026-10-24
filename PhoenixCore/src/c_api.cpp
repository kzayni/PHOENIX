/** @file c_api.cpp
 *  @brief Exception-safe ownership and data conversion at the public C ABI.
 */
#include "phoenix/c_api.h"

#include "phoenix/geometry/CircularCylinder.hpp"
#include "phoenix/geometry/NACA4Airfoil.hpp"
#include "phoenix/geometry/NACA5Airfoil.hpp"
#include "phoenix/geometry/SurfaceGeometry2D.hpp"

#include <algorithm>
#include <cstring>
#include <exception>
#include <memory>
#include <new>
#include <stdexcept>
#include <utility>

using phoenix::geometry::Connectivity;
using phoenix::geometry::Orientation;
using phoenix::geometry::PointDistribution;
using phoenix::geometry::SurfaceGeometry2D;
using phoenix::geometry::TrailingEdge;

struct phoenix_geometry {
    explicit phoenix_geometry(SurfaceGeometry2D generated)
        : surface(std::move(generated)) {}

    SurfaceGeometry2D surface;
};

namespace {

void clearError(char* message, const std::size_t capacity) noexcept {
    if (message != nullptr && capacity > 0) {
        message[0] = '\0';
    }
}

void writeError(char* destination, const std::size_t capacity, const char* message) noexcept {
    if (destination == nullptr || capacity == 0) {
        return;
    }
    const std::size_t messageLength = std::strlen(message);
    const std::size_t copiedLength = std::min(messageLength, capacity - 1);
    std::memcpy(destination, message, copiedLength);
    destination[copiedLength] = '\0';
}

template<typename Generator>
phoenix_status generate(
    phoenix_geometry** outGeometry,
    char* errorMessage,
    const std::size_t errorMessageCapacity,
    Generator&& generator
) noexcept {
    clearError(errorMessage, errorMessageCapacity);
    if (outGeometry == nullptr) {
        writeError(errorMessage, errorMessageCapacity, "The output geometry pointer is required.");
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    }
    *outGeometry = nullptr;

    // Construct under RAII and release only after the output object is fully
    // valid. Every exception is translated before crossing the C boundary.
    try {
        auto result = std::make_unique<phoenix_geometry>(generator());
        *outGeometry = result.release();
        return PHOENIX_STATUS_OK;
    } catch (const std::invalid_argument& error) {
        writeError(errorMessage, errorMessageCapacity, error.what());
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    } catch (const std::bad_alloc&) {
        writeError(errorMessage, errorMessageCapacity, "PhoenixCore could not allocate geometry memory.");
        return PHOENIX_STATUS_ALLOCATION_FAILURE;
    } catch (const std::exception& error) {
        writeError(errorMessage, errorMessageCapacity, error.what());
        return PHOENIX_STATUS_INTERNAL_ERROR;
    } catch (...) {
        writeError(errorMessage, errorMessageCapacity, "PhoenixCore encountered an unknown error.");
        return PHOENIX_STATUS_INTERNAL_ERROR;
    }
}

} // namespace

extern "C" phoenix_status phoenix_generate_naca4(
    const phoenix_naca4_parameters* parameters,
    phoenix_geometry** out_geometry,
    char* error_message,
    const size_t error_message_capacity
) {
    if (parameters == nullptr || parameters->designation == nullptr) {
        clearError(error_message, error_message_capacity);
        writeError(error_message, error_message_capacity, "NACA parameters and designation are required.");
        if (out_geometry != nullptr) {
            *out_geometry = nullptr;
        }
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    }
    if (parameters->point_distribution != PHOENIX_POINT_DISTRIBUTION_UNIFORM
        && parameters->point_distribution != PHOENIX_POINT_DISTRIBUTION_COSINE) {
        clearError(error_message, error_message_capacity);
        writeError(error_message, error_message_capacity, "Point distribution is invalid.");
        if (out_geometry != nullptr) {
            *out_geometry = nullptr;
        }
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    }
    if (parameters->trailing_edge != PHOENIX_TRAILING_EDGE_OPEN
        && parameters->trailing_edge != PHOENIX_TRAILING_EDGE_CLOSED) {
        clearError(error_message, error_message_capacity);
        writeError(error_message, error_message_capacity, "Trailing-edge configuration is invalid.");
        if (out_geometry != nullptr) {
            *out_geometry = nullptr;
        }
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    }

    // Convert POD enums explicitly so invalid C values never leak into C++.
    return generate(out_geometry, error_message, error_message_capacity, [&] {
        const phoenix::geometry::NACA4Parameters converted{
            parameters->designation,
            parameters->chord_length,
            parameters->point_count,
            parameters->point_distribution == PHOENIX_POINT_DISTRIBUTION_UNIFORM
                ? PointDistribution::uniform
                : PointDistribution::cosine,
            parameters->trailing_edge == PHOENIX_TRAILING_EDGE_OPEN
                ? TrailingEdge::open
                : TrailingEdge::closed,
        };
        return phoenix::geometry::generateNACA4(converted);
    });
}

extern "C" phoenix_status phoenix_generate_naca5(
    const phoenix_naca5_parameters* parameters,
    phoenix_geometry** out_geometry,
    char* error_message,
    const size_t error_message_capacity
) {
    if (parameters == nullptr || parameters->designation == nullptr) {
        clearError(error_message, error_message_capacity);
        writeError(error_message, error_message_capacity, "NACA parameters and designation are required.");
        if (out_geometry != nullptr) {
            *out_geometry = nullptr;
        }
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    }
    if (parameters->point_distribution != PHOENIX_POINT_DISTRIBUTION_UNIFORM
        && parameters->point_distribution != PHOENIX_POINT_DISTRIBUTION_COSINE) {
        clearError(error_message, error_message_capacity);
        writeError(error_message, error_message_capacity, "Point distribution is invalid.");
        if (out_geometry != nullptr) {
            *out_geometry = nullptr;
        }
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    }
    if (parameters->trailing_edge != PHOENIX_TRAILING_EDGE_OPEN
        && parameters->trailing_edge != PHOENIX_TRAILING_EDGE_CLOSED) {
        clearError(error_message, error_message_capacity);
        writeError(error_message, error_message_capacity, "Trailing-edge configuration is invalid.");
        if (out_geometry != nullptr) {
            *out_geometry = nullptr;
        }
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    }

    // The C and C++ parameter layouts are intentionally independent.
    return generate(out_geometry, error_message, error_message_capacity, [&] {
        const phoenix::geometry::NACA5Parameters converted{
            parameters->designation,
            parameters->chord_length,
            parameters->point_count,
            parameters->point_distribution == PHOENIX_POINT_DISTRIBUTION_UNIFORM
                ? PointDistribution::uniform
                : PointDistribution::cosine,
            parameters->trailing_edge == PHOENIX_TRAILING_EDGE_OPEN
                ? TrailingEdge::open
                : TrailingEdge::closed,
        };
        return phoenix::geometry::generateNACA5(converted);
    });
}

extern "C" phoenix_status phoenix_generate_cylinder(
    const phoenix_cylinder_parameters* parameters,
    phoenix_geometry** out_geometry,
    char* error_message,
    const size_t error_message_capacity
) {
    if (parameters == nullptr) {
        clearError(error_message, error_message_capacity);
        writeError(error_message, error_message_capacity, "Cylinder parameters are required.");
        if (out_geometry != nullptr) {
            *out_geometry = nullptr;
        }
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    }

    const phoenix::geometry::CircularCylinderParameters converted{
        parameters->radius,
        {parameters->center.x, parameters->center.y},
        parameters->point_count,
        parameters->starting_angle_degrees,
    };
    return generate(out_geometry, error_message, error_message_capacity, [&] {
        return phoenix::geometry::generateCircularCylinder(converted);
    });
}

extern "C" void phoenix_geometry_destroy(phoenix_geometry* geometry) {
    delete geometry;
}

extern "C" phoenix_status phoenix_geometry_get_point_count(
    const phoenix_geometry* geometry,
    size_t* out_count
) {
    if (geometry == nullptr || out_count == nullptr) {
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    }
    *out_count = geometry->surface.points().size();
    return PHOENIX_STATUS_OK;
}

extern "C" phoenix_status phoenix_geometry_copy_points(
    const phoenix_geometry* geometry,
    phoenix_point2d* out_points,
    const size_t point_capacity
) {
    if (geometry == nullptr || out_points == nullptr
        || point_capacity < geometry->surface.points().size()) {
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    }
    // Copy rather than expose vector storage so callers cannot retain a pointer
    // whose validity depends on a C++ object lifetime.
    const auto points = geometry->surface.points();
    for (std::size_t index = 0; index < points.size(); ++index) {
        out_points[index] = {points[index].x, points[index].y};
    }
    return PHOENIX_STATUS_OK;
}

extern "C" phoenix_status phoenix_geometry_get_bounds(
    const phoenix_geometry* geometry,
    phoenix_bounds2d* out_bounds
) {
    if (geometry == nullptr || out_bounds == nullptr) {
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    }
    const auto bounds = geometry->surface.bounds();
    *out_bounds = {{bounds.minimum.x, bounds.minimum.y}, {bounds.maximum.x, bounds.maximum.y}};
    return PHOENIX_STATUS_OK;
}

extern "C" phoenix_status phoenix_geometry_get_connectivity(
    const phoenix_geometry* geometry,
    phoenix_connectivity* out_connectivity
) {
    if (geometry == nullptr || out_connectivity == nullptr) {
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    }
    *out_connectivity = geometry->surface.connectivity() == Connectivity::periodic
        ? PHOENIX_CONNECTIVITY_PERIODIC
        : PHOENIX_CONNECTIVITY_OPEN;
    return PHOENIX_STATUS_OK;
}

extern "C" phoenix_status phoenix_geometry_get_orientation(
    const phoenix_geometry* geometry,
    phoenix_orientation* out_orientation
) {
    if (geometry == nullptr || out_orientation == nullptr) {
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    }
    *out_orientation = geometry->surface.orientation() == Orientation::counterClockwise
        ? PHOENIX_ORIENTATION_COUNTER_CLOCKWISE
        : PHOENIX_ORIENTATION_CLOCKWISE;
    return PHOENIX_STATUS_OK;
}

extern "C" phoenix_status phoenix_geometry_get_signed_area(
    const phoenix_geometry* geometry,
    double* out_signed_area
) {
    if (geometry == nullptr || out_signed_area == nullptr) {
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    }
    *out_signed_area = geometry->surface.signedArea();
    return PHOENIX_STATUS_OK;
}

extern "C" phoenix_status phoenix_geometry_get_outward_unit_normal(
    const phoenix_geometry* geometry,
    const size_t point_index,
    phoenix_point2d* out_normal,
    char* error_message,
    const size_t error_message_capacity
) {
    clearError(error_message, error_message_capacity);
    if (geometry == nullptr || out_normal == nullptr) {
        writeError(error_message, error_message_capacity, "Geometry and output normal are required.");
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    }
    try {
        const auto normal = geometry->surface.outwardUnitNormal(point_index);
        *out_normal = {normal.x, normal.y};
        return PHOENIX_STATUS_OK;
    } catch (const std::exception& error) {
        writeError(error_message, error_message_capacity, error.what());
        return PHOENIX_STATUS_INVALID_ARGUMENT;
    } catch (...) {
        writeError(error_message, error_message_capacity, "PhoenixCore encountered an unknown error.");
        return PHOENIX_STATUS_INTERNAL_ERROR;
    }
}

extern "C" const char* phoenix_status_description(const phoenix_status status) {
    switch (status) {
    case PHOENIX_STATUS_OK:
        return "success";
    case PHOENIX_STATUS_INVALID_ARGUMENT:
        return "invalid argument";
    case PHOENIX_STATUS_ALLOCATION_FAILURE:
        return "allocation failure";
    case PHOENIX_STATUS_INTERNAL_ERROR:
        return "internal error";
    }
    return "unknown status";
}
