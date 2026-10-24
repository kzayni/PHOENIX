# PHOENIX Roadmap

This roadmap records objectives, not authorization to implement later phases. Status reflects the repository on 2026-10-24.

## Phase 1 — Geometry (initial increment implemented)

- Implemented: NACA four-digit airfoil generator with editable designation, chord, point count, sampling, and trailing-edge convention.
- Implemented: NACA five-digit airfoil generator with standard normal/reflex mean lines and the same editable sampling and trailing-edge controls.
- Implemented: circular-cylinder generator with editable radius, center, point count, and starting angle.
- Implemented: interactive equal-scale rendering with pan, zoom, fit, and optional point display.
- Implemented: initial analytical and invariant verification plus UI workflow tests.
- Planned: additional geometry formats or operations only when specifically required.

## Phase 2 — Structured Mesh Generation (planned)

- 2D body-fitted O-grid generation.
- Hyperbolic outward marching.
- Wall-normal spacing control.
- Mesh-quality diagnostics.
- Interactive mesh visualization.

## Phase 3 — Mesh Infrastructure (planned)

- Configurable structured blocks.
- Periodic connectivity.
- Halo management.
- Cell and face metrics.
- CPU/GPU-compatible data structures.

## Phase 4 — Numerical Solver (planned)

- Finite-volume infrastructure.
- Compressible Euler equations.
- Numerical fluxes.
- Time integration.
- Boundary conditions.
- Numerical verification.

## Phase 5 — Advanced Capabilities (planned)

- Navier–Stokes equations.
- GPU acceleration justified by profiling.
- Cartesian background meshes.
- Immersed-boundary methods.
- Extension to 3D.
