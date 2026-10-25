# Centered-water test in the corrected shared S3 solver

The new case is `centered_water` in `model_and_dependencies/darcy_stokes_2D_cases.m`. It uses the same evolving solver as the working `porosity_wave` and `impact_melt_europa` cases. The previous `simple_test_1D_centered_blob_closed.m` is not called. The original `porosity_wave_2D_Jake_minimal.m` remains unchanged.

The prior calculation with the inherited pressure-reference bias was stopped gracefully at step 4979, 0.2717792053389223 years. Its final full state and source are preserved in `Output/centered_blob_continuation_20261024_210127/`. The corrected calculation starts fresh from the original initial condition; it does not restart from that biased trajectory.

## Minimal setup changes

- Add a third case key and its initialization branch.
- Use the existing Cartesian 100 x 120 grid: x = 0–20 km, z = −2–10 km.
- Initially set phi = 1 for x = 5–15 km, z = 4–10 km; phi = 0 elsewhere. Set T = 273 K everywhere.
- Select the existing closed and insulated wave boundary block.
- Retain the existing Europa material parameters, rheology, gravity, and permeability law k = kc phi³, with kc = 1.85e-8 m². The wave benchmark retains its own constant intrinsic viscosity, physical parameters, and phi² law.
- Record Cartesian inventories, actual face fluxes, and separated transport contributions. The Europa z = 0 delivery diagnostic does not apply to this test. Cartesian volumes are per metre of out-of-plane depth.

The **205-line block containing buoyancy, the pressure-reference correction, the Stokes/Darcy solve, timestep selection, enthalpy transport, conduction, and phase recovery is text-identical to the working shared solver before this change**. Its sparse Stokes operator helper is also identical. This comparison is recorded in `CENTERED_WATER_S3_PROVENANCE.json`; the full solver diff is `CENTERED_WATER_S3_SETUP.diff`.

The existing head correction `fsVec=fsVec+(Pi_5+Ra)*ones(size(fsVec))` is retained. Both `correct_head_reference` and `use_actual_conductivity_timestep` are explicitly true in the new run wrapper. No new flow equations, permeability floors, or phase-fraction floors were introduced.

Read-only accounting and output calls surround the shared block. They retain start-of-step flow and end-of-step thermodynamic timestamps separately. A `STOP_REQUESTED` file in the output directory requests an exact saved endpoint and graceful exit.

## Run

From the project directory in MATLAB:

```matlab
addpath('model_and_dependencies')
r = run_centered_water_S3(1);  % one simulated year, fresh initial condition
```

For a few steps in the same shared solver:

```matlab
o = struct('max_steps',3,'snapshot_steps',[0 1 2 3], ...
    'correct_head_reference',true,'use_actual_conductivity_timestep',true, ...
    'output_dir',fullfile(pwd,'Output','my_centered_water_trial'));
r = run_darcy_stokes_case('centered_water',o);
```

`run_centered_water_S3` preserves the exact used source text in the new output directory. Scalar budgets are saved every update in `diagnostics.csv`; full flux/state checkpoints are saved at early steps, requested snapshots, every 250 steps, and the final/stopped endpoint. `noflow_kc_1.850e-08.mat` includes the actual initial and final fields and sampled full fields. `plot_centered_water_S3(output_dir)` plots those actual saved fields without interpolation.

## Verification

`verify_centered_water_S3` compares results saved before and after adding the setup key: one full-grid wave step and three Europa steps. It requires bit-for-bit identical H, phi, T, solid/fluid velocities, Darcy flux, pressure head, time, and history. It also checks that the new initial H/phi/T exactly reproduce the original centered-water initialization and that its initial velocity and Darcy flux match the independently audited corrected-reference frozen flow.

These are implementation and conservation checks. They do not establish convergence or physical validity of the fully liquid constitutive limit. The wave benchmark and the centered phi = 0/1 test have different initial conditions and material choices even though they share the numerical method.

The completed verification is in `Output/centered_water_S3_verification_20261024_213417/verification.json`. Both existing cases were bit-for-bit identical before and after this addition. The new initial H, phi, T, and grid were identical to the preserved centered-water setup. Against the independent corrected frozen-flow control, maximum differences were 1.34e-15 m/s for the solid velocity and 1.41e-16 m/s for Darcy flux; relative L2 differences were 2.44e-10 and 7.43e-10. This independent comparison is a tolerance match, not a bitwise match. Every face touching an initially dry cell had exactly zero Darcy flux and permeability.

The fresh corrected run reached **one simulated year in 187 steps**. All measured external material and heat fluxes were exactly zero, and maximum relative enthalpy imbalance was 5.76e-15. The saved final temperature is 273 K throughout. Its output is `Output/centered_water_S3_verification_20261024_213417/centered_corrected_1yr/`; it is completed, rather than continuing in the background.
