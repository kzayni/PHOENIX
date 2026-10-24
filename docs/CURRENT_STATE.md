# PHOENIX Current State

Last synchronized with the repository on 2026-10-24.

For a new session, read `AGENTS.md`, this file, `ARCHITECTURE.md`, and `DESIGN_DECISIONS.md` in that order, then verify relevant statements against source and tests.

## Implemented

- A reusable C++20 static library, `PhoenixCore`, independent of the GUI and rendering stack.
- C++ surface geometry with contiguous points, open/periodic connectivity, bounds, signed-area orientation, validation, and outward normals.
- C++ implementations of classical NACA four-digit, NACA five-digit, and circular-cylinder generators. Five-digit support includes the standard normal and reflex mean-line families, design-lift scaling, exact point counts, uniform/cosine sampling, and sharp/blunt trailing edges.
- A documented C ABI using POD inputs, status/error reporting, opaque caller-owned handles, explicit-capacity copies into caller-owned contiguous point buffers, and paired C++ destruction.
- Thin Swift adapters under `App/Bridge` that call the C API; no NACA or cylinder formulas or ambiguous Swift `Core/` directory remain.
- SwiftUI controls for selecting NACA four-digit, NACA five-digit, or cylinder geometry and editing every exposed generator input, plus an interactive equal-scale renderer with drag panning, trackpad magnification, pointer-centered mouse-wheel zoom, fit-to-view reset, and optional PhoenixCore-derived surface-normal arrows.
- A native SwiftUI launch and landing sequence: top-down 2D singularity with deterministic circular accretion particles and drag rotation, liquified `PHOENIX` reveal, persistent title, and delayed landing controls.
- Nonblocking launch timing with inactive-scene pausing, Reduce Motion support, and a `Skip Intro` path; `New Project` enters the existing geometry workspace.
- The NACA controls expose trailing-edge selection as a sharp/blunt toggle; it maps to the existing verified zero-thickness closed and finite-thickness open formulations respectively.
- A headless C++ `phoenix` CLI supporting four- or five-digit NACA and cylinder CSV generation plus all currently exposed generator parameters.
- CMake targets for `PhoenixCore`, `phoenix`, and `PhoenixCoreTests`, with CTest coverage of core and CLI behavior.
- A native Xcode `PhoenixCore` target linked as an explicit application dependency; no manual binary copy step is required.
- CMake output directories and common generated root artifacts excluded by `.gitignore`.
- Persistent code-documentation standards in `AGENTS.md`, with Doxygen C++ APIs and explicit interoperability ownership documentation.

## Verification performed

Environment: Xcode 26.6, Apple Swift 6.3.3, Apple Clang 21.0.0, CMake 4.1.2, arm64 macOS.

- Independent CMake configure and build: succeeded.
- All 4 CTest entries passed: C++ geometry/C-ABI regression plus valid NACA, valid cylinder, and invalid-input CLI cases.
- The same 4 CTest entries passed under AddressSanitizer, including 256 repeated C-handle allocation/destruction cycles.
- CLI NACA 0012 and radius-0.5 cylinder commands: succeeded and produced 256 coordinate rows each.
- CLI degenerate NACA input: rejected with a clear message and nonzero exit status.
- Xcode macOS Debug app build with native `PhoenixCore` dependency: succeeded.
- All 14 Swift analytical/invariant/C-ABI tests: passed against the C++ implementations.
- Full Xcode scheme: passed with all 14 Swift analytical/invariant/C-ABI tests and all 4 UI-test executions. After the final caller-owned point-buffer refinement, all 14 Swift tests and the complete NACA/cylinder UI workflow passed again.
- Launch work: macOS Debug app build succeeded; all 16 Swift tests (including launch timing) and all 5 UI-test executions passed in the full scheme, including launch/landing and the existing geometry workflow.
- After matching the supplied four-second GSAP title timeline, all 16 Swift tests and the focused launch/landing UI test passed; the full scheme was not rerun for this presentation-only refinement.
- NACA five-digit increment: all 5 CTest entries passed in normal and AddressSanitizer builds, including core normal/reflex numerical checks and the five-digit CLI; all 19 Swift unit tests passed. The focused UI workflow was attempted twice, but XCTest timed out before launching the test while enabling macOS automation mode.

## Not implemented

- Structured or unstructured mesh generation.
- Numerical-method and CFD solver modules.
- CPU parallel execution infrastructure.
- Metal or CUDA compute backends or kernels.
- Mesh, scalar-field, or vector-field visualization.
- Geometry import/export beyond CLI CSV output or project persistence.
- Project persistence and the `Open Project` workflow; the landing control is visible but disabled with an explanatory help message.

## Known limitations and unresolved issues

- Airfoil support is limited to classical NACA four- and five-digit profiles. Five-digit mean-line codes are restricted to the standard normal `10`–`50` and reflex `21`–`51` tabulations; zero design lift or thickness is rejected.
- Swift takes a point-array snapshot for rendering while retaining the owning C++ handle. This is intentional frontend isolation but duplicates the point buffer once per generated surface.
- UI-triggered generation is synchronous on the main actor; current geometry sizes are responsive.
- The launch singularity is a native 2D Canvas interpretation of the WebGL reference, not a direct Three.js port. The text reveal uses native sliced displacement because the optional Xcode Metal compiler component is not installed.
- The exact proprietary Formula 1 display font is not bundled; the launch title uses the native Avenir Next Condensed Heavy Italic face as the available motorsport-style substitute.
- Linux compatibility is an architectural constraint and the core uses portable standard C++, but this task verified only Apple Clang on macOS.
- The app's declared iOS and visionOS destinations were not verified with the new native library target.
- Builds emit `search path '/lib' not found` because the invoking environment currently defines `LIBRARY_PATH=/lib:...`; repository Xcode build settings do not add `/lib`.

## Current objective

The long-term frontend/engine boundary is established: numerical work belongs in the independently buildable C++20 `PhoenixCore`; SwiftUI owns macOS interaction and visualization; the CLI provides headless access to the same algorithms.

## Immediate next steps

1. Remove the invalid repeated `/lib` entries from the developer environment's `LIBRARY_PATH` and `CPATH` configuration.
2. Verify the portable CMake build on a Linux compiler/toolchain.
3. Define the smallest C++ structured O-grid data model and explicit `(i, j)`, orientation, and periodic-seam conventions.
4. Add topology and metric tests before implementing hyperbolic outward marching.

Do not add Metal/CUDA abstractions, mesh generators, or solvers until their corresponding verified increment begins.
