# Minimal S3 adaptation of the fixed ORIGINAL code

Source: `simple_test_1D_noflow_base.m`. New copy: `porosity_wave_2D_Jake_minimal.m`. All new edits are marked `S3 CHANGE`; `S3_MINIMAL.diff` contains the complete diff. The source is unchanged. The earlier rewritten `simple_test_S3_copy.m` is superseded and is not called here.

```matlab
addpath('model_and_dependencies')
r = porosity_wave_2D_Jake_wrapper(1);   % one step; not an automatic 800-year run
```

Changes are confined to the function name/output path, benchmark setup and full-field snapshot output:

- Explicit Cartesian geometry and `build_stokes_grid`, original 256-by-1024 grid, physical dimensions 32*delta0 by 128*delta0. Original nondimensionalization is retained with d=128*delta0.
- The exact CSV realization, original pair averaging, MATLAB reshape, 0.001 scaling and original placement replace impact-file loading and the homogeneous-column/ocean initialization.
- Ice density 917 kg/m3, gravity 9.81 m/s2, permeability exponent 2, constant intrinsic viscosity with effective shear weighted by ice fraction. Other benchmark inputs are passed by the small wrapper.
- Full melt fraction, recovered temperature and enthalpy are saved beside the original center-column snapshots.

The equations and numerical updates in the temporal-evolution section are retained; the permeability exponent setting is 2 instead of 3. Optional final-time and output controls are separately marked S3 RUN CONTROL. The original block flow solve, pressure-head fix, harmonic face means for effe_vel, compaction regularization, flux formulas, thermal conduction, enthalpy/phase recovery, adaptive timestep, boundary conditions and diagnostics are preserved. In particular, temperature is initialized at 273 K and then recovered from evolved enthalpy using the original code.

This deliberately retains differences from the older wave script: harmonic rather than arithmetic permeability, original free-slip solid boundaries, original phi+1e-5 regularization, original time conversion and timestep limits. No claim of exact discrete equivalence to that script is made. Those choices can be reviewed individually in the original code instead of silently changing the solver.

Legacy ocean/drainage diagnostics remain in the copy for minimality; ocTh=0 and the original grRes=100 diagnostic parameter keep them in bounds, but their physical interpretation is not relevant to the wave benchmark. Legacy graphics and tracer evolution remain disabled through existing options. The one-step wrapper retains the original step-count interface; a separate optional launcher supplies final-time run control as documented below.

Source SHA256 before changes: 034dc043e817d4234d1c678b01ca93ecd8981c45976e6549767695fe55b5456f.

Verification: MATLAB R2022b one-step run passed on the full 256-by-1024 Cartesian grid. Exact initial CSV peak and initial 273 K field were verified. The retained original adaptive timestep advanced 0.00405901786542 years; recovered temperature remained 273 K, and absolute nondimensional total enthalpy error was 9.22e-19. No long simulation was started.

## Optional 800-year run control

`run_porosity_wave_2D_Jake_800` launches the minimal original-code test to 800 years. The solver retains its original timestep formula, with only the final step shortened to land at the target. Defaults retain step-count behavior (`final_years=Inf`). Additional run-control edits are marked `S3 RUN CONTROL`: five-year output cadence, a separate checkpoint every 100 steps, and final-time stopping. Full snapshots also capture steps 0, 1 and 60. Output is isolated in `Output/Jake_2D_minimal_800_years`. Checkpoints contain state but automatic restart is not implemented. The existing video helper runs after completion using output metadata only. This is a multi-week run at the measured original timestep and per-step cost; the earlier 36-hour estimate applied to the superseded rewritten solver.

## Optional actual-conductivity timestep

The commented `options.use_actual_conductivity_timestep` flag defaults to false, preserving the original timestep. `r=porosity_wave_2D_Jake_wrapper(1,true)` enables the actual face-conductivity diffusion limit with a 20 percent safety margin and retains the original advective limits and final-time cap. Flagged runs save separately under `s3_minimal_<steps>_steps_actual_kappa`. Equations and conductivity values are unchanged. The chosen flag is recorded in result. The standalone 800-year launcher still defaults to the original timestep until explicitly given this option.

## Head-reference trial flag

`options.correct_head_reference` defaults to false. When true, the single additive term `(Pi_5+Ra)` is added to the existing momentum RHS. This restores the reference removed by the inherited reduced buoyancy, with rho_ref/rho_i=1+alpha*DT. The head variable, matrix, Darcy flux, thermal buoyancy variation, enthalpy and phase equations are unchanged. The trial-only diff is `JAKE_HEAD_REFERENCE_TRIAL.diff`. `run_Jake_head_reference_trial` runs an isolated ten-year comparison with the correction and actual-conductivity timestep enabled; it does not launch an 800-year run. Outputs go to `Output/Jake_head_reference_trial_10yr`.
