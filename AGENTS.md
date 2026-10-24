AGENTS.md — PHOENIX

1. Project Overview

PHOENIX is a computational fluid dynamics (CFD) application designed for numerical simulation, scientific computing, and interactive visualization.

The project is being developed incrementally, beginning with two-dimensional geometry generation and structured body-fitted meshes, followed by numerical solvers and eventually immersed-boundary methods (IBM).

The long-term objective is to develop a modern, modular, high-performance CFD framework capable of exploiting multicore CPUs and GPUs.

Scientific correctness, software quality, extensibility, and computational efficiency are fundamental priorities.

2. General Instructions

Before modifying the project:

1. Inspect the repository structure and existing implementation.
2. Identify the programming languages, frameworks, build system, and architectural conventions.
3. Read relevant documentation and existing tests.
4. Reuse existing components whenever appropriate.
5. Understand dependencies between modules before introducing changes.

Do not assume that a particular language, framework, or architecture is used unless confirmed by the repository.

Prefer simple, robust solutions over unnecessary abstractions.

Avoid introducing dependencies unless they provide a clear technical benefit.

Do not rewrite working components without a justified reason.

3. Development Philosophy

Follow these principles:

* Correctness first: Numerical and scientific correctness take priority over performance.
* Modularity: Separate geometry, mesh generation, numerical methods, solvers, visualization, and user-interface components.
* Performance awareness: Consider memory layout, cache efficiency, vectorization, and GPU execution.
* Extensibility: Design components so they can evolve from 2D to 3D where practical.
* Reproducibility: Numerical results should be deterministic whenever reasonably possible.
* Maintainability: Prefer readable, well-structured code with clear responsibilities.
* Minimal complexity: Avoid premature optimization and unnecessary generalization.

Implement functionality incrementally and validate each stage before proceeding.

4. Architecture

Maintain clear separation between the following conceptual components:

Geometry

Responsible for defining and manipulating geometric objects.

Examples:

* NACA airfoil generation.
* Parametric curves and surfaces.
* Geometry import and export.
* Surface normals, tangents, and curvature.

Geometry representations must remain independent of rendering and numerical solvers.

Mesh Generation

Responsible for generating computational meshes.

Planned capabilities include:

* Structured 2D body-fitted O-grids.
* Hyperbolic mesh generation.
* Mesh smoothing and quality optimization.
* Structured Cartesian meshes.
* Block-based mesh decomposition.
* Future 3D mesh generation.

Mesh generation must not depend on the rendering system.

Numerical Methods

Responsible for reusable numerical algorithms.

Examples:

* Spatial reconstruction.
* Numerical fluxes.
* Gradient evaluation.
* Time integration.
* Linear algebra.
* Boundary-condition treatments.

Avoid embedding numerical algorithms directly into user-interface code.

Solvers

Responsible for physical models and governing equations.

Planned developments include:

* Two-dimensional compressible flow.
* Finite-volume discretization.
* Euler equations.
* Navier–Stokes equations.
* Immersed-boundary methods.

Numerical solvers should operate on well-defined mesh and field abstractions.

Visualization

Responsible for displaying geometry, meshes, and numerical fields.

Visualization must consume data from computational modules without modifying the underlying numerical representation.

User Interface

Responsible for user interaction, parameter configuration, and workflow management.

The UI must not contain scientific algorithms.

5. Numerical Correctness

Numerical correctness is mandatory.

For every numerical algorithm:

* Document the mathematical formulation.
* Define coordinate systems and indexing conventions.
* Specify assumptions and limitations.
* Handle degenerate and invalid inputs.
* Avoid silent numerical failures.
* Check for NaN and infinite values where appropriate.
* Preserve physical and geometric invariants when applicable.

Pay particular attention to:

* Array bounds.
* Surface orientation.
* Normal-vector conventions.
* Cell connectivity.
* Jacobian signs.
* Periodic indexing.
* Floating-point precision.
* Boundary conditions.

Do not silently clamp invalid numerical states unless the mathematical or physical justification is documented.

When implementing a numerical method from a publication, preserve the intended formulation and identify any deviations.

6. Geometry and Mesh Conventions

Use explicit, consistent conventions for geometric representations.

For structured two-dimensional meshes, prefer the logical indexing convention:

* (i): circumferential or first computational direction.
* (j): radial or second computational direction.

For body-fitted O-grids:

* The inner boundary represents the body surface.
* The outer boundary represents the far field.
* Circumferential connectivity is periodic.
* The radial direction extends outward from the body.

Document the orientation of coordinate systems and the sign convention for cell Jacobians.

Do not assume that all future meshes will be structured or body-fitted.

Mesh Quality

Where relevant, implement diagnostics for:

* Signed cell area or volume.
* Jacobian positivity.
* Orthogonality.
* Skewness.
* Aspect ratio.
* Grid stretching.
* Degenerate or inverted cells.

Invalid meshes must be detected and reported rather than silently accepted.

7. Block-Based Computation

PHOENIX is expected to support small structured computational blocks suitable for CPU and GPU execution.

Use the conceptual block size

$$
B = N^d
$$

where:

* (N) is the number of cells per block direction.
* (d) is the spatial dimension.
* The initial default is (N=4).

The block size must remain configurable.

Potential configurations include:

* (4\times4) and (8\times8) in 2D.
* (4\times4\times4) and (8\times8\times8) in 3D.

Important requirements:

* Separate logical mesh indexing from physical memory layout.
* Do not hard-code block dimensions into numerical algorithms.
* Support future compile-time specialization of performance-critical kernels.
* Consider halo requirements and stencil widths.
* Minimize unnecessary memory duplication.
* Avoid assumptions that GPU threadgroup dimensions must equal computational block dimensions.

Do not introduce block decomposition into components that do not require it.

In particular, geometry generation should remain independent of computational block sizes.

8. GPU and Parallel Computing

PHOENIX should be designed with GPU execution in mind, including Apple Silicon GPUs through Metal where supported by the existing architecture.

However, GPU acceleration should be introduced only when justified.

Guidelines:

* Maintain clear separation between numerical algorithms and execution backends.
* Prefer contiguous memory access and predictable indexing.
* Avoid unnecessary CPU–GPU transfers.
* Consider thread divergence and synchronization costs.
* Minimize temporary allocations in performance-critical code.
* Avoid excessive abstraction in frequently executed kernels.
* Keep CPU reference implementations for validating GPU results when practical.

Do not assume NVIDIA CUDA execution semantics apply directly to Apple GPUs.

When implementing GPU kernels:

1. Establish a correct reference implementation.
2. Validate numerical equivalence within appropriate tolerances.
3. Measure performance.
4. Optimize based on profiling rather than assumptions.

9. Rendering and Visualization

Use the application’s existing rendering infrastructure.

Rendering requirements:

* Preserve physical aspect ratios.
* Support interactive zooming and panning.
* Avoid unnecessary geometry reconstruction.
* Separate geometry data from GPU rendering buffers.
* Update rendering resources only when necessary.
* Support future visualization of meshes, scalar fields, vector fields, and solution contours.

Visualization should remain responsive even when numerical computations are running.

Avoid introducing new rendering frameworks without a compelling reason.

10. Testing and Verification

Every substantial feature must include appropriate tests.

Unit Tests

Test individual components independently.

Examples:

* NACA geometry calculations.
* Coordinate transformations.
* Surface normals.
* Mesh connectivity.
* Indexing functions.
* Numerical operators.

Numerical Verification

Where analytical solutions are available, compare against them.

Use convergence studies when appropriate.

Distinguish clearly between:

* Unit testing.
* Numerical verification.
* Physical validation.

Do not describe a numerical method as validated solely because it passes unit tests.

Regression Testing

When fixing bugs or modifying numerical algorithms, add regression tests whenever practical.

Avoid changing established numerical results without understanding and documenting the reason.

Testing Requirements

Before considering a task complete:

1. Run relevant tests.
2. Build the affected targets.
3. Check for warnings and errors.
4. Verify that existing functionality remains operational.
5. Report tests that could not be executed.

Never claim that tests passed unless they were actually executed.

11. Performance and Memory

Performance matters, but correctness comes first.

Prefer:

* Efficient memory layouts.
* Minimal unnecessary allocations.
* Reuse of temporary buffers.
* Cache-friendly data access.
* Appropriate numerical precision.
* Explicit ownership and lifetime management.

Avoid premature micro-optimizations.

For performance-sensitive changes, provide benchmarks when practical.

Do not sacrifice numerical accuracy for speed without explicit justification.

12. Code Quality

Write clean, maintainable, production-quality code.

Requirements:

* Use descriptive names.
* Keep functions focused.
* Avoid duplicated logic.
* Document non-obvious algorithms.
* Use consistent formatting.
* Follow the repository’s naming conventions.
* Handle errors explicitly.
* Avoid unexplained constants.
* Keep public interfaces small and coherent.

Use comments to explain why something is done, especially for mathematical and numerical algorithms.

Avoid comments that merely repeat what the code already expresses.

13. Dependencies

Before adding a dependency:

1. Determine whether existing project components can provide the functionality.
2. Evaluate maintenance and portability implications.
3. Consider compatibility with the current build system.
4. Explain why the dependency is necessary.

Prefer lightweight dependencies when possible.

Do not introduce large frameworks for simple functionality.

14. Scope Management

Implement only what is requested.

Do not introduce unrelated features, architectural rewrites, or speculative functionality.

When a task suggests future extensions, design reasonable interfaces for them without implementing the extensions prematurely.

For complex tasks:

1. Inspect the existing implementation.
2. Establish a concise implementation plan.
3. Implement the smallest complete functional increment.
4. Test the implementation.
5. Summarize the results.

Avoid creating unnecessary abstractions for features that do not yet exist.

15. Current Development Priorities

The initial PHOENIX development sequence is:

Phase 1 — Geometry

* NACA four-digit airfoil generator.
* Parametric geometry controls.
* Interactive 2D rendering.
* Geometry verification.

Phase 2 — Structured Meshes

* Body-fitted 2D O-grid generation.
* Hyperbolic outward marching.
* Wall-normal spacing control.
* Mesh-quality diagnostics.
* Interactive mesh visualization.

Phase 3 — Mesh Infrastructure

* Configurable structured blocks.
* Periodic connectivity.
* Halo management.
* Cell and face metrics.
* CPU/GPU-compatible data layouts.

Phase 4 — Numerical Solver

* Finite-volume infrastructure.
* Compressible Euler equations.
* Numerical fluxes.
* Time integration.
* Boundary conditions.
* Verification benchmarks.

Phase 5 — Advanced Capabilities

* Navier–Stokes equations.
* GPU acceleration.
* Cartesian background meshes.
* Immersed-boundary methods.
* Extension to three dimensions.

These phases describe the intended direction, not authorization to implement future features during unrelated tasks.

16. Communication and Completion Reports

After implementing a task, provide a concise summary containing:

* What was implemented.
* Files created or modified.
* Important architectural decisions.
* Tests and builds executed.
* Known limitations.
* Recommended next steps, when relevant.

Clearly distinguish completed functionality from planned functionality.

If a requested implementation cannot be completed, explain the specific blocker.

Do not claim success for incomplete or untested work.

17. Guiding Principle

PHOENIX is a scientific computing project.

Every implementation should contribute to a framework that is:

Numerically reliable, computationally efficient, modular, maintainable, and suitable for future high-performance CPU/GPU execution.

Favor technically justified decisions over unnecessary complexity, and preserve the ability to verify numerical algorithms independently.

Context Management and Continuity

PHOENIX is a long-term scientific software development project.

Do not rely exclusively on conversational context to understand the project.

At the Beginning of Each Task

1. Read AGENTS.md.
2. Read docs/CURRENT_STATE.md, if available.
3. Consult docs/ARCHITECTURE.md for architectural questions.
4. Consult docs/DESIGN_DECISIONS.md before making significant design changes.
5. Inspect the relevant source files and tests.
6. Verify that documented information matches the actual implementation.

Repository source code and tests are authoritative for implemented behavior. Documentation records design intent and should be corrected when outdated.

At the End of Each Substantial Task

Update docs/CURRENT_STATE.md with:

* Functionality implemented.
* Relevant files modified.
* Tests executed and their results.
* Known limitations or unresolved issues.
* The next recommended development step.

Update docs/ARCHITECTURE.md when module boundaries, interfaces, or data structures change.

Update docs/DESIGN_DECISIONS.md when significant architectural or numerical decisions are made.

Do not rewrite unrelated documentation unnecessarily.

Context Preservation

Before completing a long task or when conversational context becomes limited:

1. Summarize completed work.
2. Record unresolved problems.
3. Record important implementation decisions.
4. Identify the exact next action.
5. Save this information in the appropriate repository documentation.

Keep documentation concise, factual, and synchronized with the code.

Never mark planned functionality as implemented.

Starting a New Session

Use repository documentation to recover the current project state before proposing or implementing changes.

Do not repeat completed work or redesign existing components without a technical justification.

18. Code Documentation and Commenting Standards

Documentation is part of implementation work and must remain synchronized with code.

* Write technically accurate English comments that explain purpose, reasoning, assumptions, limitations, numerical conventions, and important edge cases.
* Document public interfaces, important data structures, nontrivial algorithms, and architectural components without restating obvious code.
* Use Doxygen-compatible `///` or `/** ... */` comments for public C++ APIs. Use `@brief`, `@param`, `@return`, `@throws`, `@note`, and `@warning` where they add information.
* Use Swift `///` documentation for important types and methods, especially UI responsibilities, C++ data flow, cross-language ownership, rendering transforms, and concurrency assumptions.
* For numerical methods, document the mathematical formulation, discretization, indexing/orientation, implementation choices, assumptions, limitations, and stability or convergence considerations where applicable. Never invent references or unverified claims.
* For C/Swift interoperability, explicitly state allocation and deallocation responsibilities, buffer layout and size, pointer lifetime, error reporting, and thread-safety requirements.
* For future Metal or CUDA kernels, document thread-to-cell mapping, memory layout, halos/stencils, synchronization, precision, and correctness constraints behind optimizations.
* Add concise file-level documentation to substantial numerical or architectural files when it helps explain their role. Do not add repetitive boilerplate to trivial files.
* Review and update affected comments whenever behavior changes; remove obsolete explanations.
