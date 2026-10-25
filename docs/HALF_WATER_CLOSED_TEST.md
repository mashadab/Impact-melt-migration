# Minimal half-water, half-ice closed-box test

The new solver `model_and_dependencies/simple_test_1D_half_water_closed.m` is a copy of `simple_test_1D_noflow_base.m`, the existing closed-box version of `simple_test_1D.m`. Exactly three lines differ: the MATLAB function name, the initial melt fraction, and the isolated default output directory. Reversing these substitutions reproduces the parent text exactly. The line-by-line difference is `HALF_WATER_CLOSED_TEST.diff`; hashes and the identity check are in `HALF_WATER_CLOSED_TEST_PROVENANCE.json`.

The only physical change replaces

```matlab
phiGr = 0.5*ones(size(phiGr));
```

with

```matlab
phiGr = double(Y > (Grid.p.ymin+Grid.p.ymax)/2);
```

Temperature remains 273 K everywhere. The original 100 x 120 Cartesian grid covers x = 0 to 20 km, z = -2 to 10 km. Thus the geometric midpoint is z = 4 km, with phi = 0 below and phi = 1 above it. Both phases and heat have zero flux through all exterior boundaries. The helper named `build_stokes_grid_cyl` inherits the default Cartesian geometry flag in this file; its name does not imply a cylindrical grid.

The momentum/pressure forcing, rheology, permeability exponent 3, harmonic averaging, compaction regularization, enthalpy update, time stepping, and boundary conditions are identical to the existing closed-box parent. No S3 forcing-reference correction, perturbation, phase-fraction floor, clipping, or interface smoothing was added to this test. The earlier proposed smaller grid and true 1D reduction were not used. Legacy impact drainage bookkeeping and its original `phiOrig` definition remain inherited; depletion stopping is disabled, and those quantities should not be interpreted as this test's half-domain melt budget.

## Run and saved results

With `model_and_dependencies` on the MATLAB path:

```matlab
run_half_water_closed_test(10,1.85e-8)
```

The wrapper runs the copied solver and writes to a new timestamped directory. It adds checks, a summary JSON, history CSV, a solver-source copy, and plots outside the solver. To regenerate plots from existing results without rerunning the solver:

```matlab
run_half_water_closed_test('C:/Users/lenovo/Desktop/Research/Impact-melt-migration/Output/half_water_closed_20261024_172613')
```

The first run is saved in `Output/half_water_closed_20261024_172613/`. It completed 10 steps at kc = 1.85e-8 m², reaching 0.0006892317505 years (about 6.04 hours). The lower half's maximum final phi is 1.30943e-14, and the maximum temperature change is about 5.8e-12 K. All recorded exterior solid, Darcy, conductive, and advective boundary fluxes are zero. Relative global enthalpy error is 1.62e-14.

The last archived flow has a maximum interface relative Darcy flux of 8.24e-36 m/year and a maximum interface solid speed of 7.93e-8 m/year. The archived flow precedes the final thermodynamic update; the wrapper labels this timestamp distinction. Initial and final fields are visually indistinguishable at ordinary plotting scales. No simulation times or states were interpolated.

## An observed velocity limitation

The unchanged parent formulation produces large cancelling solid-velocity and relative-Darcy components inside the pure-water region. At a vertical face at x = 5.7 km, z = 7 km, the last archived flow gives:

| Quantity | Signed value [m/year] |
| --- | ---: |
| Solid-velocity variable | +725445.395728102 |
| Relative Darcy flux | -725445.395728060 |
| Their sum (mixture volume flux) | +4.21e-8 |

Positive vertical flux is upward. These large component values are not the actual water speed: q is a flux relative to the solid-velocity variable, and the solid phase is absent where phi = 1. Their sum is tiny in the pure-water region. The maximum absolute sum across its internal faces is 9.80e-8 m/year. Consequently, unchanged temperature/porosity profiles alone do not validate the phase-velocity or dilation diagnostics at this pure-phase endpoint. This behavior also shortens the inherited adaptive time steps. No change to the parent flow formulation was made to suppress it.

The numerical results establish a blocked interface over this short test, not validated physical pore creation, pressure accuracy, or long-term stability. See `kc_1.850e-08_summary.json` and `endpoint_flow_check.json` in the run directory for the saved values. The read-only endpoint check is reproducible with `tmp/analyze_half_water_endpoint.py`, using MATLAB's MAT-file library without a solver run.

## One-year extension

The requested extension ran at kc = 1.85e-8 m² with a target of **one simulated year**, in `Output/half_water_1yr_20261024_190211/`, and was subsequently stopped at the user's request before reaching that target. The ten-year suggestion was superseded by the one-year request. The launcher is `tmp/start_half_water_1yr.m`, which calls `run_half_water_closed_years(1,1.85e-8,output_dir)`.

The minimal three-line solver copy remains unchanged. The time-run wrapper generates an archived `source/half_water_time_driver.m` that adds a final-time cap, stopping/status controls, and checkpoints. It also resolves the same initial input file from its original location because the archived driver lives in a different directory. Flow equations, forcing, rheology, grid, phase initialization, and enthalpy update are unchanged. Only the final adaptive step is shortened to reach the requested final time. The 200,000-step ceiling is a safety limit, not the requested duration; hitting it reports `step_limit` instead of completion.

`progress.json` updates every 50 steps and records completed steps, simulated time, wall time, step length, temperature, lower-half maximum phi, global energy error, and maximum flow components. Full actual states are saved at steps 1 and 100, every 1000 steps, the first step crossing 0.01, 0.1, 0.25, 0.5, 0.75 years, and the final time. The states retain both endpoint thermodynamic time and start-of-step flow time. An initial-state MAT, run configuration, archived source, and process launch record are also saved. At completion, the driver writes the full history CSV and regenerates the initial/final figure from saved data.

The initial time step is about 6.8923e-5 years, implying roughly 14,509 iterations if it stays similar. Runtime estimates must use measured sustained wall time and may change as the solution evolves. The MATLAB process was started hidden in the background so it continues after the chat response.

## User-requested stop and advisor package

The verified simulation process was stopped at the user's request. The last live report was step 5,700 at 0.392862097793 years, but its full fields were not archived. The last complete full checkpoint is step 5,000 at 0.344615875257 years. Figures and video use that complete saved checkpoint, and label it as the last saved state. No later field is reconstructed or invented.

The `advisor/` subfolder contains a minimal initial-versus-last-saved figure (PNG and editable SVG), separate initial/final snapshots with liquid fraction and temperature, a video assembled solely from actual full checkpoints, a frame-source CSV, copies of both endpoint MAT files, a preservation report, and an explanatory README. The original simulation source, states, logs, and configuration remain preserved. `publish_stopped_half_water.m` reproduces the package without advancing the simulation. The new centered-water test has a separate solver and output directory; see `CENTERED_BLOB_CLOSED_TEST.md`.
