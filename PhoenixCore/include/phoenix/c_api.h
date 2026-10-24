#ifndef PHOENIX_C_API_H
#define PHOENIX_C_API_H

/**
 * @file c_api.h
 * @brief Stable C boundary used by Swift and other non-C++ clients.
 *
 * Functions have no shared mutable state and independent geometry handles may
 * be read concurrently. A handle must not be destroyed while another thread is
 * reading it. No C++ exception crosses this boundary; failures are returned as
 * `phoenix_status` values with optional caller-owned error buffers.
 */

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum phoenix_status {
    PHOENIX_STATUS_OK = 0,
    PHOENIX_STATUS_INVALID_ARGUMENT = 1,
    PHOENIX_STATUS_ALLOCATION_FAILURE = 2,
    PHOENIX_STATUS_INTERNAL_ERROR = 3
} phoenix_status;

/// Chordwise station distribution used by both NACA generators.
typedef enum phoenix_point_distribution {
    PHOENIX_POINT_DISTRIBUTION_UNIFORM = 0,
    PHOENIX_POINT_DISTRIBUTION_COSINE = 1
} phoenix_point_distribution;

/// Thickness-polynomial convention at the NACA trailing edge.
typedef enum phoenix_trailing_edge {
    PHOENIX_TRAILING_EDGE_OPEN = 0,
    PHOENIX_TRAILING_EDGE_CLOSED = 1
} phoenix_trailing_edge;

typedef enum phoenix_connectivity {
    PHOENIX_CONNECTIVITY_PERIODIC = 0,
    PHOENIX_CONNECTIVITY_OPEN = 1
} phoenix_connectivity;

typedef enum phoenix_orientation {
    PHOENIX_ORIENTATION_COUNTER_CLOCKWISE = 0,
    PHOENIX_ORIENTATION_CLOCKWISE = 1
} phoenix_orientation;

typedef struct phoenix_point2d {
    double x;
    double y;
} phoenix_point2d;

typedef struct phoenix_bounds2d {
    phoenix_point2d minimum;
    phoenix_point2d maximum;
} phoenix_bounds2d;

typedef struct phoenix_naca4_parameters {
    const char* designation;
    double chord_length;
    size_t point_count;
    phoenix_point_distribution point_distribution;
    phoenix_trailing_edge trailing_edge;
} phoenix_naca4_parameters;

typedef struct phoenix_naca5_parameters {
    const char* designation;
    double chord_length;
    size_t point_count;
    phoenix_point_distribution point_distribution;
    phoenix_trailing_edge trailing_edge;
} phoenix_naca5_parameters;

typedef struct phoenix_cylinder_parameters {
    double radius;
    phoenix_point2d center;
    size_t point_count;
    double starting_angle_degrees;
} phoenix_cylinder_parameters;

typedef struct phoenix_geometry phoenix_geometry;

/// @brief Generates a four-digit NACA contour.
/// Creates geometry owned by the caller. On success `*out_geometry` must be
/// released with `phoenix_geometry_destroy`. Input strings are borrowed only
/// for the duration of the call. Error text is written to the caller-owned
/// buffer when one is supplied.
phoenix_status phoenix_generate_naca4(
    const phoenix_naca4_parameters* parameters,
    phoenix_geometry** out_geometry,
    char* error_message,
    size_t error_message_capacity
);

/// @brief Generates a five-digit NACA contour with the same ownership contract
/// as `phoenix_generate_naca4`.
phoenix_status phoenix_generate_naca5(
    const phoenix_naca5_parameters* parameters,
    phoenix_geometry** out_geometry,
    char* error_message,
    size_t error_message_capacity
);

/// @brief Generates a circular-cylinder contour with caller-owned output.
phoenix_status phoenix_generate_cylinder(
    const phoenix_cylinder_parameters* parameters,
    phoenix_geometry** out_geometry,
    char* error_message,
    size_t error_message_capacity
);

/// @brief Releases a geometry handle created by PhoenixCore; `NULL` is safe.
void phoenix_geometry_destroy(phoenix_geometry* geometry);

/// @brief Returns the exact number of points required by a coordinate buffer.
phoenix_status phoenix_geometry_get_point_count(
    const phoenix_geometry* geometry,
    size_t* out_count
);

/// @brief Copies points into caller-owned contiguous storage.
/// @param geometry Geometry to read.
/// @param out_points Writable buffer containing at least `point_capacity`
///        elements. PhoenixCore never retains or frees this pointer.
/// @param point_capacity Number of elements available in `out_points`; it must
///        be at least the count returned by `phoenix_geometry_get_point_count`.
phoenix_status phoenix_geometry_copy_points(
    const phoenix_geometry* geometry,
    phoenix_point2d* out_points,
    size_t point_capacity
);

phoenix_status phoenix_geometry_get_bounds(
    const phoenix_geometry* geometry,
    phoenix_bounds2d* out_bounds
);

/// @brief Returns whether the final point connects back to the first.
phoenix_status phoenix_geometry_get_connectivity(
    const phoenix_geometry* geometry,
    phoenix_connectivity* out_connectivity
);

/// @brief Returns orientation derived from signed enclosed area.
phoenix_status phoenix_geometry_get_orientation(
    const phoenix_geometry* geometry,
    phoenix_orientation* out_orientation
);

/// @brief Returns signed shoelace area in physical coordinate units squared.
phoenix_status phoenix_geometry_get_signed_area(
    const phoenix_geometry* geometry,
    double* out_signed_area
);

/// @brief Computes the orientation-aware outward unit normal at a surface point.
phoenix_status phoenix_geometry_get_outward_unit_normal(
    const phoenix_geometry* geometry,
    size_t point_index,
    phoenix_point2d* out_normal,
    char* error_message,
    size_t error_message_capacity
);

/// @brief Returns static human-readable text for a status code.
const char* phoenix_status_description(phoenix_status status);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // PHOENIX_C_API_H
