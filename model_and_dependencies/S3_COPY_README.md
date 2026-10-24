# S3 exact-realization test of the fixed solver

```matlab
addpath('model_and_dependencies')
r = S3_copy_wrapper(1,0.1);       % full-grid smoke run
r = S3_copy_wrapper(50000,800);   % full benchmark
```

The exact original CSV wave is imported from `porosity-wave-test/MATLAB/porosity-wave-init`. Consecutive values are averaged, reshaped in MATLAB column-major order to 256 by 256, scaled by 0.001, and placed above ymax-40*delta0 in the original 256-by-1024 domain. No resampling or wave fitting is performed. Porosity is melt volume fraction.

Mechanical parameters match S3: intrinsic ice viscosity 1e14 Pa s, ice density 917 kg/m3, water density 1000 kg/m3, gravity 9.81 m/s2, water viscosity 0.001 Pa s, permeability 5.6e-11 m2, permeability exponent 2 and compaction exponent 1. Intrinsic viscosity is constant for this benchmark. Length and velocity scales are delta0 and w0.

The sparse staggered flow operators, intact face mobility, preserved pressure head and consistent Darcy flux follow the fixed closed-lid code. Solid boundaries have no penetration, north/south have no slip, and east/west have natural zero shear. Outer Darcy and conductive fluxes are sealed. A pressure gauge is fixed in the first cell.

## Temperature is a diagnostic, not prescribed

273 K is ONLY the initial temperature. Enthalpy evolves by effective solid/Darcy advection plus mixture thermal conduction. Temperature and melt fraction are recovered with the existing `enthMelt` phase relation at each step; they are never overwritten with constant fields. The partially molten equilibrium branch of that constitutive relation gives the melting temperature, so 273 K is expected while the evolving enthalpy remains in that branch. This sanity test can reveal transport and conservation failures, but a flat temperature alone does not prove the full thermal solver correct.

The enthalpy parameters follow the fixed solver: latent heat 334000 J/kg, water heat capacity 4186 J/(kg K), ice heat capacity 185+7.037*273 J/(kg K), and conductivities 3.3 and 0.56 W/(m K). No direct melt-fraction update or temperature clipping is used. Range and finite-value assertions halt invalid states.

## Outputs

The corrected runs use `Output/s3_thermal_wave_<max_steps>_steps`. Full fields of melt fraction, recovered temperature and enthalpy are stored at t=0 and every five simulated years, including requested endpoints. History stores peak position, melt conservation, flow residual, boundary fluxes, temperature extrema and total enthalpy error for every step. Checkpoints are saved at the first step and every 20 steps. The adaptive timestep observes transport and thermal stability limits; reaching the step limit produces `step_limit`, not `completed`.

The plotter exports unmasked melt fields, the theoretical/simulated peak trajectory and temperature/enthalpy sanity diagnostics. `make_S3_video` exports melt fraction and recovered temperature side by side to `s3_melt_temperature.avi`. Saved final velocities correspond to the start of the last step and are timestamped.

## Superseded run

The earlier mechanical-only run under `Output/s3_wave_10000_steps` was stopped after the user clarified that temperature must emerge from evolving enthalpy. Its prescribed-temperature fields and preview video are NOT thermal verification results. Use the corrected `s3_thermal_wave` outputs. The original fixed solver, original wave folder and exact initialization CSV are unchanged. `simple_test_S3_closed_lid_reference.m.txt` preserves the starting fixed-code copy.

## Corrected smoke verification

The full-grid two-step test reached 0.1 simulated years, changed enthalpy from its initial field, recovered temperature at 273 K, and conserved total enthalpy with relative error -2.81e-15. Both melt/thermal diagnostic plots and a two-frame AVI were exported. This validates short-step execution, not the long-term settling speed. The corrected full run logs to `Output/s3_thermal_full_run.log`. Its completion must be checked from the saved status and time.
