# One solver, two case keys

`darcy_stokes_2D_cases.m` was created by copying `porosity_wave_2D_Jake_minimal.m`
and inserting if/else setup branches. It was not rewritten from scratch.
The original S3 source remains untouched. `S3_CASE_SWITCH.diff` is the complete
source diff; `S3_CASE_SWITCH_PROVENANCE.json` records the original SHA-256.

The full block from buoyancy evaluation through the flow matrix/solve, pressure
head and Darcy flux, timestep, conductivity, and enthalpy transport is identical
to S3. The sparse Stokes operator helper is also identical. There is one shared
pressure correction: `fsVec=fsVec+(Pi_5+Ra)*ones(size(fsVec));`, enabled by default,
matching the working S3 run with both correction/timestep flags true.

## Run

```matlab
addpath('model_and_dependencies')
case_key = 'porosity_wave'; % or 'impact_melt_europa'
o = struct('max_steps',3,'output_dir',fullfile(pwd,'Output','my_fresh_run'));
r = run_darcy_stokes_case(case_key,o);
```

`case_key` selects setup through if/else. The transport selector `test='effe_vel'`
remains separate, with its original S3 branches unchanged.

| Setup | porosity_wave | impact_melt_europa |
|---|---|---|
| Coordinates | Cartesian | Cylindrical r-z |
| Grid | Original 256 x 1024 wave grid | Original 100 x 120 Europa grid |
| Initial fields | Exact Jake CSV wave, 273 K | ic03321_100.mat with original Europa preprocessing |
| Gravity / ice density | 9.81 m/s2 / 917 kg/m3 | 1.315 m/s2 / 920 kg/m3 |
| Viscosity | Original S3 benchmark functions | Original Europa temperature/melt functions |
| Heat boundary | Insulated walls, free enthalpy | Fixed 100 K surface; insulated sides/base by default |
| Material boundary | Closed free-slip walls | Closed free-slip walls, impermeable base |
| Default kc | 5.6e-11 m2 | 1.85e-8 m2 |

For Europa 03321, the outer base is z=-2 km; z=0 is internal. The original
initialization includes `phiGr(Y<0.25)=0`, suppressing melt below z=2.5 km.
Europa basal melt fraction/enthalpy is not fixed. An optional dimensionless
`o.basal_heat_flux=1` reproduces the geothermal Neumann flux block present but
commented out in the old Europa source; default zero follows the closed S3 base.

The case also selects scale/physical constants and viscosity because those differ
between the original validated wave and original Europa setups. The equations
that use those quantities are shared. Only the energy diagnostic is extended to
account for heat added/removed by Europa's prescribed thermal boundaries.

For parameter overrides, set `o.kc`, `o.fn`, `o.eta_0`, or `o.E_a`. Output folders
are separated by case by default. Each call starts a new run; choose a fresh
output folder to avoid overwriting earlier files. The default limit is 1000 steps.

## Verification

`verify_S3_case_switch` compares one full-grid step with the original S3 file,
using identical corrected-run options, then checks three Europa steps against
the corrected saved Europa result. It checks full temperature, melt, enthalpy,
solid/fluid velocities, Darcy flux, pressure head and the diagnostic history.
This verifies equivalence and setup, not long-term physical validity.

Verification passed in `Output/S3_case_switch_check_20261023_185621/`:
wave full state and history were bit-for-bit identical to untouched S3 after one
full-grid step (0.32499127047 years). Europa full state and history matched the
corrected result after three steps (0.009333337794 years), with zero basal solid
and Darcy flux. `verification.json` records the machine-readable results.

`Europa_wrapper_noflow` and its existing long solver entry point now delegate
to this same shared solver; there is no second evolving Europa equation block.
The original S3 file and original Europa solver/wrapper remain untouched.

## Updated Europa ocean initialization

For the Europa key only, all z<0 cells now start at phi=1 and T=273.16 K.
The original shell mask is limited to 0<=z<2.5 km, preserving its previous
values above the interface. The wave branch and shared equations are unchanged.
The earlier Europa bitwise comparison above predates this deliberate initial
condition change. The current verification script now checks the new ocean and
unchanged shell rather than comparing evolution against the old ocean setup.

Use `options.initial_only=true` to save/return t=0 without any flow solve or
time advancement. `show_Europa_initial_state` uses this option, checks the ocean
values and phase-recovery round trip, checks unchanged shell initial fields,
and renders the initial temperature and melt fields.

## Current lower-region and budget setup (supersedes the liquid-ocean initialization above)

The lower region z<0 starts at phi=0 and T=273 K. Europa melt inventory uses
actual cylindrical volumes; delivery is net downward across exactly z=0.
`result.melt_budget`/`melt_budget.csv` report shell, lower-region and domain
inventories plus signed net refreezing. See `EUROPA_MELT_BUDGET.md` for definitions.

## 10,000-year Europa run

`run_Europa_10000` targets 10,000 simulated years with kc=1.85e-16 m^2,
corrected S3 head forcing and actual-conductivity timestep enabled. Melt-loss
stopping is disabled. The safety step limit is 10 million; a step-limit exit
is treated as failure to reach the target, not completion. State checkpoints
are saved every 100 steps and field snapshots every 25 simulated years, with
additional snapshots at steps 1, 10, 100 and 1000. The history array grows in
10,000-row blocks to avoid a large upfront allocation; this changes storage
only. `COMPLETE.txt` is written only after reaching the time target.
