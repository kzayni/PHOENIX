# PHOENIX Design Decisions

Last synchronized with the repository on 2026-10-24.

These records separate accepted direction from future implementation. A decision does not imply that its planned capability exists.

## DD-001 — Correctness before performance

**Decision:** Scientific and numerical correctness takes priority over speed.

**Rationale:** A fast CFD result is not useful unless its geometry, mesh, and governing-equation implementation are demonstrably correct.

**Implications:** Establish CPU references and analytical tests first; document formulas and conventions; detect invalid states; optimize only after measurement. Implemented geometry follows this policy. Solver verification remains planned.

## DD-002 — Separate scientific and presentation responsibilities

**Decision:** Geometry, mesh generation, numerical methods, solvers, rendering, and UI remain logically separated.

**Rationale:** Independent computational components can be tested without a window or graphics backend and reused by future execution paths.

**Implications:** UI code coordinates inputs; it does not contain formulas. Rendering consumes immutable geometry. Mesh and solver code must not depend on SwiftUI. `PhoenixCore` is the computational boundary; Swift adapters and visualization live under `App`.

## DD-003 — Begin with NACA four-digit geometry

**Decision:** Initial airfoil support uses the classical NACA four-digit formulation.

**Rationale:** It has compact parameters and analytical properties suitable for verification.

**Implications:** The four-digit generator supports symmetric and cambered sections, configurable chord, sampling, point count, and open/closed trailing-edge coefficients. Classical five-digit support was added as a separate verified generator under DD-016; imported and other airfoil families remain out of scope.

## DD-004 — Use a 2D body-fitted O-grid first

**Decision:** The initial structured mesh topology will be a two-dimensional body-fitted O-grid.

**Rationale:** It matches closed airfoil/cylinder boundaries and provides explicit periodic circumferential connectivity.

**Implications:** Future indexing should use circumferential `i` and outward radial `j`, with body and far-field boundaries explicit. No mesh generator is implemented yet.

## DD-005 — Prefer hyperbolic outward marching initially

**Decision:** Hyperbolic outward marching is the preferred first O-grid generation approach, subject to numerical verification.

**Rationale:** It provides direct wall-normal growth control and an incremental path from a verified surface.

**Implications:** The method must be tested for orientation, Jacobian positivity, spacing, degeneracy, and robustness. A different method remains possible if verification exposes unacceptable behavior. This is planned, not implemented.

## DD-006 — Keep structured block size configurable

**Decision:** Structured computational blocks will eventually contain `N^d` cells, initially defaulting to `N = 4`.

**Rationale:** Small regular blocks support locality and future specialization without fixing one hardware layout.

**Implications:** Algorithms must not hard-code block dimensions. Geometry remains independent of blocks. Block infrastructure is not implemented.

## DD-007 — Decouple blocks from GPU execution groups

**Decision:** Computational block dimensions and GPU threadgroup dimensions are independent choices.

**Rationale:** They represent different concerns and optimal values may differ across kernels and hardware.

**Implications:** Future execution backends must map work explicitly rather than infer one layout from the other.

## DD-008 — Target Metal and CUDA without losing CPU references

**Decision:** Apple Silicon/Metal and NVIDIA/CUDA are future GPU targets, while practical CPU reference implementations remain authoritative for comparison.

**Rationale:** Metal matches the initial macOS platform, CUDA supports future NVIDIA systems, and CPU references enable debugging and numerical equivalence checks.

**Implications:** Core data types must embed neither Metal nor CUDA types or execution assumptions. GPU kernels are not implemented and neither toolkit is a CPU-core build requirement.

## DD-009 — Add GPU acceleration only after measurement

**Decision:** Introduce GPU compute paths only when profiling demonstrates a useful target.

**Rationale:** Premature GPU work adds synchronization, transfer, and verification complexity.

**Implications:** Build the smallest correct CPU implementation, benchmark it, then accelerate measured bottlenecks while retaining equivalence tests.

## DD-010 — Use explicit surface orientation and seam conventions

**Decision:** Generated closed bodies use counterclockwise, seam-unique points with periodic connectivity. Outward normals are the right-hand normal of directed edges.

**Rationale:** Mesh construction and boundary conditions need deterministic orientation, indexing, and normals.

**Implications:** A closed NACA trailing edge has one seam location; an open trailing edge has distinct upper/lower seam points joined by the periodic blunt face. Consumers must use connectivity instead of assuming a repeated endpoint.

## DD-011 — Use C++20 for the independent computational engine

**Decision:** Numerical algorithms and computational data structures live in the independently buildable C++20 `PhoenixCore` library.

**Rationale:** The engine must support headless workflows, non-Apple platforms, and future CPU/GPU implementations without depending on the graphical application.

**Implications:** `PhoenixCore` uses portable standard C++ where practical and has no Swift, SwiftUI, AppKit, rendering, Metal, or CUDA dependency. Only implemented modules are created.

## DD-012 — Use SwiftUI Canvas for initial 2D visualization

**Decision:** Use the existing SwiftUI stack and `Canvas` for the initial geometry viewport.

**Rationale:** It supports responsive line rendering and interaction without a new rendering dependency or custom GPU resource layer.

**Implications:** View transforms preserve equal axes and do not alter geometry. A different renderer should be considered only when mesh/field scale and measured performance require it.

## DD-013 — Cross the Swift/C++ boundary through a C ABI

**Decision:** Swift calls `PhoenixCore` through a small C-compatible API with POD values and opaque handles.

**Rationale:** C provides a stable language boundary without exposing C++ ABI details, templates, containers, or exceptions to Swift.

**Implications:** Allocation and destruction remain paired in C++; coordinates are copied into caller-owned buffers with explicit capacity; errors use status codes and caller-owned text buffers; every C entry point catches exceptions.

## DD-014 — Support native Xcode and independent CMake builds

**Decision:** CMake builds the reusable engine, CLI, and C++ tests, while Xcode compiles the same sources as a native static-library dependency of the SwiftUI app.

**Rationale:** Headless and future Linux workflows need CMake, while native target integration avoids manually copying binaries during macOS app development.

**Implications:** Source lists and language settings in both build definitions must remain synchronized. The CLI and GUI must never acquire separate geometry implementations.

## DD-015 — Keep interoperability inside the application boundary

**Decision:** Swift-facing DTOs, resource owners, C adapters, and the bridging header live under `App/Bridge`; `PhoenixCore/` contains only C++ engine code.

**Rationale:** A Swift directory named `Core` obscures which layer owns computation and invites algorithm duplication.

**Implications:** Lightweight point snapshots may exist for rendering, but scientific generation and derived computational operations remain in C++.

## DD-016 — Use tabulated classical NACA five-digit mean lines

**Decision:** Five-digit airfoils use the classical tabulated normal (`10`–`50`) and reflex (`21`–`51`) mean-line constants, scaled by the designation's design-lift digit.

**Rationale:** The five-digit family is not fully defined by a single inferred camber-position formula; using the published standard constants preserves the intended piecewise mean lines.

**Implications:** Unsupported middle-digit combinations are rejected explicitly. The generator shares the four-digit thickness, surface-normal offset, point distribution, contour ordering, and sharp/blunt trailing-edge conventions, while Swift remains a parameter adapter only.

## Open decisions

- Exact structured-mesh and field interfaces, storage layouts, and metric conventions.
- Project-wide precision policy beyond the present `Double` geometry calculations.
- Persistence/import/export and longer-term CLI configuration scope.
- Parallel scheduling plus Metal/CUDA backend design after representative workloads exist.
- Numerical details and acceptance tolerances for hyperbolic marching and later solvers.
