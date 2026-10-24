# PHOENIX

PHOENIX is an early-stage computational fluid dynamics application for geometry generation, structured mesh generation, numerical simulation, and interactive visualization. A reusable C++20 computational engine serves both a native SwiftUI macOS application and a headless command-line interface.

## Current status

`PhoenixCore` currently implements verified two-dimensional NACA four- and five-digit airfoils plus circular-cylinder geometry. The macOS app provides editable controls, validation feedback, and an interactive equal-scale viewport. The `phoenix` CLI generates the same geometry without loading a GUI. Mesh generation, flow solvers, Metal compute, and CUDA compute are not implemented.

## Build the C++ core and CLI

Requirements are a C++20 compiler and CMake 3.20 or newer. No Apple framework, Metal, or CUDA dependency is required.

```sh
cmake -S . -B build-cmake -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=ON
cmake --build build-cmake --parallel
ctest --test-dir build-cmake --output-on-failure
```

Equivalent convenience targets are `make core`, `make cli`, and `make cpp-test`. Example headless runs:

```sh
build-cmake/phoenix geometry naca --profile 0012 --points 256 --output naca0012.csv
build-cmake/phoenix geometry naca --profile 23012 --points 256 --output naca23012.csv
build-cmake/phoenix geometry cylinder --radius 0.5 --points 256 --output cylinder.csv
```

CSV output contains an `x,y` header followed by one row per seam-unique surface point.

## Build the macOS application

The GUI requires Xcode and Apple platform SDKs. Xcode builds `PhoenixCore` as a target dependency, so no CMake build or manual library copy is required first. The following macOS Debug build was verified on 2026-10-24 with Xcode 26.6:

```sh
make app
```

The built application is placed at `build/Build/Products/Debug/PHOENIX.app`. To build and open it:

```sh
make run
```

`make clean` removes Xcode build products through the configured build system. CMake build output belongs in the ignored `build-cmake/` directory. The app project still declares iOS and visionOS destinations, but the integrated native core and UI have only been verified on macOS.

## Documentation

- [Current state](docs/CURRENT_STATE.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Design decisions](docs/DESIGN_DECISIONS.md)
- [Roadmap](docs/ROADMAP.md)
- [Contributor and agent instructions](AGENTS.md)

## Roadmap summary

The initial geometry increment is implemented. Planned work progresses through structured mesh generation, mesh infrastructure, compressible-flow solvers, and advanced CPU/GPU capabilities. See the [roadmap](docs/ROADMAP.md) for the implemented/planned distinction.
