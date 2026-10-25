# Centered-water continuation and mechanism audit

**Superseded calculation:** this inherited-reference run was stopped and saved
at step 4979, 0.2717792053389223 years, when the user requested the corrected
working S3 baseline. Later references below to the "ongoing" run describe its
status during the original audit. The replacement starts fresh in the same
shared solver as the wave and Europa cases; see
[CENTERED_WATER_S3_SETUP.md](CENTERED_WATER_S3_SETUP.md).

The user requested a long continuation to understand the movement. The original 100-step centered-water test is preserved. The continuation restarts from its actual full step-100 state and targets one simulated year at kc = 1.85e-8 m². Output is `Output/centered_blob_continuation_20261024_210127/`.

## Source and restart verification

The parent is `simple_test_1D_centered_blob_closed.m`, SHA-256 `7ec36cce2836aa6f7a28856a43c5fadf9ab5bf40b1db7a871811cc3e268e4e45`. The archived driver adds restart state loading, diagnostic calculations, checkpoint/progress writing, a final-time cap, and a graceful stop-file check. The input path is resolved to the same initial-condition file because the archived driver resides in a separate directory. No forcing, rheology, permeability, flow operator, phase recovery, or enthalpy equation is changed.

An uninterrupted 101-step replay reproduced the original saved step-100 H, phi, and temperature with exactly zero difference. A 100+1 restart reproduced uninterrupted step 101 with exactly zero difference in H, phi, temperature, solid velocity, Darcy flux, pressure head, and time. See `restart_verification.json`. This verifies implementation/restart identity; it does not establish physical validity.

The actual archived driver and helper sources are under `source/`, with a line-by-line driver difference and configuration. The original flat-layer, centered-trial, and Europa sources remain unchanged.

## Saving and stopping

`diagnostics.csv` records each actual update, including downward carried-liquid and Darcy rates across z = 4 km, change in lower-half liquid volume, the two transport contributions, effective phase residual, wet-region dilation, energy error, and enthalpy reconstruction error. Volumes are **per metre of out-of-plane depth**, rather than cylindrical annular volumes.

Full checkpoints include start- and end-of-step phase/enthalpy, physical solid and Darcy fluxes, carried liquid flux, dilation, permeability, pressure head, and the separated enthalpy increments. They are written every 250 steps, at selected early steps and physical-time milestones, at the final time, and on a stop request. The flow timestamp precedes the endpoint thermodynamic timestamp, and both are retained.

To stop cleanly, create the file `STOP_REQUESTED` in the continuation output directory. The driver checks it after every update, saves the current full step, and exits with `stopped_by_user`. No process termination is needed for this continuation. Progress is updated every 50 steps. The first long target is one simulated year; a 200,000-step ceiling reports `step_limit` if reached early.

## Exact first-step evidence

The first-step diagnostic replay identifies an initially dry cell at x = 10.1 km, z = 3.95 km, immediately beneath the water body. Its volume is 20,000 m³ per metre of out-of-plane depth. All four incident face permeabilities and relative Darcy fluxes are exactly zero.

The upper face carries liquid downward at 55.5288222854 m/year, with upwind phi = 1. Its area is 200 m² per metre of depth, giving 11,105.7644571 m³/year per metre of depth carried into the cell. Over the actual step of 5.44173933653e-5 years, this predicts delta_phi = 3.02173376541e-5, matching the saved value. Darcy and conduction enthalpy increments are zero, and this cell's solid divergence is zero. The equivalent ice volume leaves the cell through its other faces. Thus first wetting here is grid-cell replacement by moving material, not demonstrated pore opening in a stationary dry parcel.

The whole lower half receives 25.2951832052 m³ per metre of depth in this first step, fully accounted for by carried-liquid flux. Its Darcy contribution is zero. The bulk transport discretization is first-order upwind; this accounting does not separate exact interface motion from numerical front spreading.

`analyze_centered_blob_saved_budget.py` reads archived MAT data through MATLAB's read-only MAT-file library and writes `analysis/saved_flux_budget.json` plus four-face CSVs. This does not rerun the flow or interpolate any fields.

## Confirmed inherited pressure-reference bias

An independent frozen-flow control restores the same pressure-head reference term used by the validated S3 code: `fsVec = fsVec + (Pi_5 + Ra)`. The legacy simple-test copy lacks that term. These controls are separate from the ongoing trajectory, and do not advance temperature or enthalpy.

| Frozen-flow quantity | Inherited forcing | S3 reference restored | Zero Darcy |
| --- | ---: | ---: | ---: |
| Initial maximum solid-velocity variable [m/year] | 918823.87 | 109.77 | 109.78 |
| Initial downward matrix velocity at the dry-cell upper face [m/year] | 55.5288 | 57.9197 | 58.1651 |
| Initial downward carried-liquid Q across z=4 km [m³/year per m depth] | 464836.36 | 433233.23 | 432692.99 |
| Initial relative Darcy Q across z=4 km | 0 | 0 | 0 |
| Step-100 downward Darcy Q across z=4 km [m³/year per m depth] | 206.8744 | 20.2123 | not tested |

The dry-region bulk descent exists with zero Darcy flow and with the S3 reference restored, supporting buoyancy-driven aggregate circulation as the initial transport mode. However, the large inherited pure-water phase velocities are not harmless everywhere in the centered geometry: maximum actual liquid volume flux per area on internal pure-water faces is approximately 724,212 m/year for the initial inherited solve, compared with about 110 m/year with the reference restored. In the previous flat-layer setup the phase components nearly cancelled; that local conclusion must not be generalized to this centered geometry.

At the same frozen step-100 phase distribution, the inherited formulation produces about **10.24 times** the corrected-reference Darcy transfer across z = 4 km. The ongoing unchanged run is consequently a **diagnostic baseline with a known forcing bias**, not a validated physical prediction of infiltration or dilation. Its later growing Darcy fraction must be interpreted with that qualification. No silent correction was applied to the continued solver.

These controls establish strong sensitivity to the inherited pressure-head reference. They are not corrected full-trajectory calculations, grid convergence, or validation of the pure-liquid constitutive limit. See `analysis/forcing_control/forcing_control.json`, the archived control driver, and full frozen-flow MAT files. `audit_centered_blob_forcing.m` reproduces these controls; `plot_centered_forcing_control.m` plots the saved results.

## Why the pressure-reference mismatch produces the observed enormous flux

For upward-positive z, the code solves for the head-form pressure `P = p_water + rho_water*g*z`, and computes relative Darcy flux as `q = -(k/mu_water)*grad(P)`. The momentum body force must be transformed using that same pressure reference.

At uniform melting temperature, divide the inherited vertical forcing by `C = g*d^3/(eta0*Dthermal)`. Its terms combine to

`F_inherited/C = (rho_water-rho_ice)*phi - rho_water - rho_ice*alpha*DeltaT`.

The consistent head-form buoyancy forcing at that temperature is

`F_head/C = -(rho_water-rho_ice)*(1-phi)`.

Their difference is the constant reference density `rho_ice*(1+alpha*DeltaT)`. With the present parameters, it is 945.4656 kg/m³. In the pure-water region, the correct reference forcing is zero, while the inherited expression retains this residual. Restoring `(Pi_5+Ra)` removes it and retains the temperature-dependent buoyancy variations.

The uncancelled pressure-gradient scale is `945.4656 * 1.315 = 1243.287264 Pa/m`. At phi = 1, `k = 1.85e-8 m²` and `mu_water = 1e-3 Pa s`, so

`q_scale = (1.85e-8/1e-3)*1243.287264 = 0.023000814384 m/s = 725445.685671 m/year`.

This scale closely matches the measured initial centered-case maximum relative Darcy flux, 725392.833743 m/year, and the flat-layer maximum, 725445.395728 m/year. It explains the magnitude of the excessive computed flux rather than merely observing that changing the RHS changes the answer. The density-difference buoyancy scale is only `(1000-920)*1.315 = 105.2 Pa/m`.

The factor 10.24 in the frozen step-100 integrated Darcy Q is a result of the complete coupled solve at that nonuniform state, not an assumed universal multiplier. Later permeability/pressure feedback can change it. In particular, the initial constant-gradient estimate does not predict the full migration trajectory or replace a corrected coupled run and convergence checks.

The working shared S3 solver already includes this reference correction. The minimally copied old simple-test solver does not; its forcing was deliberately retained with the initialization-only change. This difference should be made explicit when comparing either test to the validated porosity-wave setup.
