# PHOENIX Architecture

Last synchronized with the repository on 2026-10-24.

## Implemented architecture

PHOENIX has a reusable C++20 computational engine and two frontends:

```text
SwiftUI macOS app -> C API -> PhoenixCore <- C++ API <- phoenix CLI
       |                       |
       +-- Canvas renderer     +-- geometry data and algorithms
```

The computational engine has no dependency on Swift, SwiftUI, AppKit, rendering, Metal, or CUDA. Its implemented code uses the C++ standard library and is intended to remain buildable on Linux. Only the geometry module exists because mesh generation, numerical methods, and solvers have no implementation yet.

### C++ computational engine

`PhoenixCore` is a C++20 static library.

| Area | Responsibility |
| --- | --- |
| `PhoenixCore/include/phoenix/geometry` | Public points, bounds, surface representation, conventions, parameters, and generator APIs. |
| `PhoenixCore/src/geometry` | Surface validation, NACA four- and five-digit generation, cylinder generation, and outward normals. |
| `PhoenixCore/include/phoenix/c_api.h` | C-compatible POD parameters, opaque geometry handle, accessors, status codes, and ownership contract. |
| `PhoenixCore/src/c_api.cpp` | Exception containment, input conversion, coordinate copying, and handle allocation/destruction. |
| `Tests/Cpp` | Engine-level analytical, invariant, invalid-input, C-ABI, and ownership regression tests. |

`SurfaceGeometry2D` owns a contiguous `std::vector<Point2D>`, connectivity, orientation, bounds, and signed area. Generated bodies are counterclockwise, periodic, and seam-unique. Their outward normal is the right-hand normal of the directed tangent. NACA ordering is upper trailing edge to leading edge to lower trailing edge; an open trailing edge has two distinct seam points joined by the periodic blunt face. Five-digit profiles use the standard tabulated normal or reflex mean-line constants and the same thickness, sampling, and trailing-edge conventions as four-digit profiles.

### C boundary and ownership

Swift sees only C enums, POD parameter/result types, functions, and the opaque `phoenix_geometry` handle. It never receives STL types, templates, C++ exceptions, or implementation types.

- A successful generator call returns one caller-owned handle.
- The caller releases it only with `phoenix_geometry_destroy`; destroying `NULL` is safe.
- The caller queries point count, allocates a contiguous buffer, and asks C++ to copy into it; PhoenixCore never retains or frees caller storage.
- Error text is copied into an optional caller-owned buffer; status codes remain available without a buffer.
- C entry points catch all exceptions. Independent immutable handles may be read concurrently; destruction requires exclusive lifetime ownership.

### SwiftUI application

| Area | Responsibility |
| --- | --- |
| `App/PHOENIXApp.swift` | Application entry point and window lifecycle. |
| `App/Launch` | Native, nonblocking staged launch/landing presentation, deterministic Canvas singularity, liquified title reveal, and workspace handoff. |
| `App/Views` | Geometry parameter controls, equal-axis SwiftUI `Canvas` visualization, and native macOS scroll-wheel observation for pointer-centered zoom. |
| `App/State/GeometryViewModel.swift` | Main-actor UI state, generator selection, and error presentation. |
| `App/Bridge/*.swift` | Thin C-API adapters and Swift rendering snapshots; no geometry formulas. |
| `App/Bridge/PHOENIX-Bridging-Header.h` | Imports the public C API into Swift. |

The Swift wrapper retains the C++ handle for its lifetime and copies its points once into a Swift array for rendering. Derived geometry and normals come from the retained C++ object. Parameter changes flow through the view model to the C adapter, `PhoenixCore`, the rendering snapshot, and finally the viewport. View transforms never mutate computational data.

The app opens on a SwiftUI-only launch sequence. A pausable animation timeline drives a deterministic, top-down 2D Canvas singularity, a sliced turbulence/blur title reveal, and landing controls before `New Project` transitions to the geometry workspace. The singularity uses circular planar orbits without perspective tilt; horizontal drag rotates the 2D field. The four-second title stage mirrors the reference's independent device scale/rise, piece scaling and offsets, 3.5-second exponential turbulence decay, and final blur/contrast resolution. Inactive scenes stop requesting frames, Reduce Motion skips the reveal, and no launch code crosses the C boundary or is linked into the CLI.

### Headless CLI

`CLI/main.cpp` builds the `phoenix` executable and links directly to `PhoenixCore`. It parses geometry options, selects the four- or five-digit generator from the NACA profile length, calls the same C++ generators as the app, and writes `x,y` CSV files. It initializes no Apple UI or rendering framework. Usage errors return exit code 2; file/runtime failures return 1.

### Build systems

The root `CMakeLists.txt` builds `PhoenixCore`, `phoenix`, and `PhoenixCoreTests`; CTest also exercises valid and invalid CLI runs. CMake 3.20+ and a C++20 compiler are sufficient.

`PHOENIX.xcodeproj` remains authoritative for the macOS application. Its native `PhoenixCore` static-library target compiles the same C++ sources and is an explicit app dependency, eliminating manual binary copying. The Swift and UI tests remain Xcode targets. No third-party dependencies are present.

## Planned architecture

Future C++ modules will be added only with implemented functionality:

- mesh generation and mesh data structures;
- reusable numerical methods;
- governing-equation solvers; and
- measured CPU, Metal, and CUDA execution paths.

Core data structures must remain backend-neutral. Metal and CUDA will be separate execution implementations behind concrete needs, not required dependencies of the CPU core. Computational block sizes will remain independent of GPU execution-group dimensions.

## Unresolved architecture decisions

- Mesh ownership, indexing, metric, halo, and error-reporting interfaces.
- Field storage and project-wide numerical precision beyond double-precision geometry.
- The first concrete execution-backend boundary once a measured workload exists.
- Persistence/import/export formats and longer-term CLI configuration format.
- Supported deployment policy beyond the currently verified macOS GUI and host CMake build.
