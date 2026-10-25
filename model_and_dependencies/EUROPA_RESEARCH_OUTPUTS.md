# Europa research run: saved data and schedule

Run entry point: `run_Europa_until_depleted`. Case: `impact_melt_europa`.
An optional second argument changes only the permeability coefficient in the
launcher; the original default remains 1.85e-8 m^2. For example,
`run_Europa_until_depleted([],1.85e-16)` starts a fresh output folder with the
same initial conditions, boundaries, stopping criterion, and save schedule.
The user selected cubic permeability for Europa: k=kc*phi^3, kc=1.85e-8 m^2.
The wave key retains the validated S3 phi^2 law. Other shared pressure/transport
equations are unchanged. Lower region z<0 initially has phi=0 and T=273 K.
Stop: total melt in all z>=0 cells <=0.005 times its actual initialized volume.
For this impact, the threshold is approximately 0.1589017564 km^3. No fixed
year cutoff; the 10-million-step cap is a safety limit and is never labelled
successful melt depletion.

## Why these outputs

The manuscript's Figures 6 and 7 use temperature/melt maps and penetration depth
and melt-volume histories. Figure 4 compares ocean delivery across kc. These
outputs support that analysis; they do not reproduce old results automatically.
The paper's organic-tracer extension is discussed as future work. Passive tracer
evolution is disabled here; no chemical partitioning is inferred from water flux.

## Schedule

- At launch: configuration JSON and MAT, a copy of all top-level MATLAB source
  files from model_and_dependencies/, and the exact raw ic03321_100.mat input.
- At t=0: full temperature, phi, enthalpy and grid; no flow fields have yet been
  computed, so initial velocity/pressure arrays are empty rather than fabricated.
- Early states: every step 1 through 10, then steps 25, 50, 100, 250, 500, 1000.
- Additional requested times (years): .001, .003, .005, .008, .01, .013, .016,
  .03, .06, .1, .11, .16, .29, .3, .42, .482, .62, .93, 1, 1.24, 1.84, 3,
  5.196, 10, 30, 100. These save the first available step at or after each time;
  if a step crosses several requests, it is saved once with its actual time.
  No timestep is modified to force these requested output times.
- Thereafter at least once per 10 simulated years, based on actual available
  steps. Saving extra early step/time requests may reset that interval.
- Every step: diagnostics are accumulated in memory, including melt budgets,
  penetration depth and the existing thermal/material/energy checks.
- At step 1 and every 100 steps: state checkpoint, progress.json, and complete
  melt_budget.csv through that step. Log updates occur at step 1 and every 50.
- At termination: final field state, full result, final CSV, status and summary.
  COMPLETE.txt is written only if the melt threshold was actually reached.
  Failure/safety-limit exits receive FAILED.txt and keep their saved outputs.

## Files

- `noflow_kc_1.850e-08.mat`: result struct, field snapshots of T/phi/H, grid,
  history, melt budget, configuration flags, final state and completion status.
- `states/state_XXXXXXXX.mat`: standalone field states in physical units:
  temperature K, phi, dimensionless enthalpy, solid/fluid velocities m/s,
  Darcy flux m/s, pressure-head potential Pa, reconstructed fluid pressure Pa,
  and overpressure Pa; grid, axes in metres, kc and exponent are included.
  Pressure head here is pressure-valued potential, not head in metres.
- `checkpoint.mat`: latest H/T/phi/grid, step, time, length scale and options.
  This is a saved state; automatic restart is not implemented in the launcher.
- `melt_budget.csv`: time, liquid volumes in domain/shell/lower region, cumulative
  net downward transfer across z=0, and signed net refreezing in each region.
  Volumes are liquid-water-equivalent m^3; divide by 1e9 for km^3.
  Refreezing is freezing minus new melting, not cumulative gross freeze/remelt
  events or uniquely tagged impact-origin water.
- Front diagnostics in the CSV: deepest shell cell with phi>=1e-3 and its depth
  below the surface. This is an explicit detection threshold, not a new physical
  constraint. Positions are cell-centre estimates at 100-m grid resolution.
- `run.log`: time/iteration progress, temperature, energy checks, shell melt
  fraction, delivery and net refreezing.
- `run_configuration.json`, `run_options.mat`, `source/`, input MAT: provenance.

The explicit flow/transport scheme computes velocities and pressures at the
START of a timestep, then advances temperature/enthalpy to the END. Each state
file records both `flow_time_years` and `time_years`; flow fields must not be
mistaken for a recomputed end-of-step solution. The final result is also saved
if it falls between scheduled snapshots.
