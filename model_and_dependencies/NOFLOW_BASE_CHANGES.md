# Changes in the separate closed-lid solver

## Numerical and boundary changes

1. **Permeability matrix:** `comp_mean` already returns a sparse diagonal matrix. Assign it directly to `Kdprime`; do not pass that matrix through `spdiags` again.
2. **Pressure-head consistency:** retain the solved head as `p_head` before converting `p` for display. Calculate `qr = -Pi_1 * Kdprime * (Gp * p_head)` consistently in the flow and effective-velocity enthalpy calculations.
3. **Closed top, base and sides:** remove ALL enthalpy Dirichlet constraints, prescribe zero conductive flux on the outer faces, and explicitly zero Darcy mobility at those same faces in the flow operator. The existing free-slip, zero normal solid-velocity conditions remain. Enthalpy and melt fraction evolve in every cell. There is no imposed surface temperature in this insulated test.

## Run and reporting changes

- Separate callable solver with run options; the original solver and wrapper remain unchanged.
- Requested step limit (1000 by default); optional melt-loss stopping is disabled for this test.
- Stable source-relative input paths and separate output directory `Output/closed_lid_1000_steps`.
- Optional passive-tracer updates and legacy graphics/video, disabled by default; tracer boundary metadata supplied.
- Sparse zero blocks and a local sparse Stokes-operator helper, preserving the operator coefficients.
- Snapshots at steps 0, 100, 250, 500 and 1000 by default, with temperature in kelvin, melt fraction and enthalpy at x = 10 km. Full final states are saved too.
- Every-step top/base/all-boundary solid, Darcy, advective-heat and conductive-heat flux checks; total-domain enthalpy conservation and finite-state checks. The wrapper checks all boundaries and verifies there are no enthalpy Dirichlet cells.
- Entirely new wrapper and plotter with temperature/melt profiles, boundary/energy plots, MAT and CSV exports. Caller warning settings are restored after the solver returns.

The change markers themselves contain comments only. Removing them exactly recovers the updated unannotated source. Every original-to-copy diff hunk is enclosed by a marker; the complete diff also records removed code. No new temperature clamp or change to the upwind donor rule was introduced.

## Marker index

| Marker | Current solver line | Original source | Change |
|---|---:|---|---|
| NF-01 | 1 | original lines 1-1 | Separate callable solver, options argument and documented closed-domain behavior. |
| NF-02 | 30 | original lines 21-21 | Read run options and restore the caller warning state on return. |
| NF-03 | 63 | original lines 46-46 | Resolve initial-condition files relative to this solver. |
| NF-04 | 222 | original lines 202-204 | Use sparse zero storage and equivalent sparse Stokes operators. |
| NF-05 | 239 | original lines 216-255 | Remove top/base enthalpy constraints; close and insulate every outer face. |
| NF-06 | 280 | original lines 281-281 | Supply optional passive-tracer boundary metadata. |
| NF-07 | 298 | original lines 295-297 | Initialize diagnostics/snapshots and bound the requested step count. |
| NF-08 | 383 | original lines 361-361 | Keep the matrix returned by comp_mean and seal its boundary faces. |
| NF-09 | 423 | original lines 396-396 | Preserve solved pressure head and use it for the Darcy flux. |
| NF-10 | 466 | original lines 434-434 | Use the same permeability and pressure head in enthalpy advection. |
| NF-11 | 501 | original lines 466-466 | Make passive-tracer updates optional; disabled for these column tests. |
| NF-12 | 529 | original lines 490-490 | Make passive-tracer updates optional; disabled for these column tests. |
| NF-13 | 566 | original lines 523-526 | Add flux/energy checks and checkpoints; make early stopping optional. |
| NF-14 | 609 | original lines 533-533 | Make the original 2D graphics optional. |
| NF-15 | 866 | original lines 787-787 | Keep optional legacy files inside the separate run output directory. |
| NF-16 | 875 | original lines 793-797 | Keep optional legacy files inside the separate run output directory. |
| NF-17 | 888 | original lines 803-807 | Keep optional legacy files inside the separate run output directory. |
| NF-18 | 904 | original lines 816-825 | Keep optional legacy files inside the separate run output directory. |
| NF-19 | 932 | original lines 841-841 | Make video generation optional and isolate the video path. |
| NF-20 | 940 | original lines 845-853 | Keep optional legacy files inside the separate run output directory. |
| NF-21 | 965 | original lines 867-870 | Finalize results; add options, middle-column and sparse-operator helpers. |

## Original-file verification

- `simple_test_1D.m` SHA-256 before and after: `db2344aed93fa928f06a3b90ad174a6ebfac10dd7d557067453d82d4aa434451`
- `Simple_test_wrapper.m` SHA-256 before and after: `901099ed38065d6d6ce31a97dc3388c23df1abefa92ff01ef509def8ce48eed0`

The completed-run verification is recorded in `Output/closed_lid_1000_steps/closed_lid_summary.csv` and the diagnostic plots.

## Completed 1000-step verification

All three cases completed on the full 100 x 120 grid. Temperature remained 273 K. Solid, Darcy, advective-heat and conductive-heat fluxes were exactly zero on every outer boundary. No enthalpy Dirichlet cells were present; the initial melt fraction was 0.5 in every cell, including the lid.

| kc (m^2) | Elapsed time (years) | Final lid melt fraction (min-max) | Maximum relative enthalpy error |
|---|---:|---|---:|
| 0 | 465.405382 | 0.5-0.5 | 0 |
| 1.85e-12 | 51.3787321 | 0.104366025-0.104371951 | 5.59e-14 |
| 1.85e-8 | 0.0743481553 | 0.065346462-0.065346462 | 1.03e-13 |

These are equal step-count comparisons; each case uses its own adaptive timestep. The temperature and melt-fraction profiles are in `closed_lid_profiles.png`, and top/base evolution, boundary fluxes and energy residuals are in `closed_lid_checks.png`. These checks verify the stated boundary conditions and enthalpy conservation for these runs.
