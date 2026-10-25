# Time-resolved output for the manuscript plots

The reference is `Impact_melt_foundering (1).pdf`, Figures 4–7, including the
semilog versions named in the Figure 7 caption. These are plotting/data
requirements; the revised solver is not expected to reproduce the old,
superseded migration times.

| Manuscript output | Required data | Available/save policy |
|---|---|---|
| Figure 6 temperature/melt panels | Full T, phi, grid coordinates, actual time; flow fields where saved | Original `states/`; additional checkpoint copies under `paper_outputs/checkpoints/` |
| Figure 7 and Supplementary S4 | Melt remaining in shell and penetration depth vs time, including semilog axes | `paper_outputs/time_history.csv`, one row per completed solver timestep plus t=0 |
| Figure 4a delivered volume vs permeability | Cumulative **net downward** liquid transfer across z=0 and completion status for each kc | Original `melt_budget.csv` and expanded plotting history; requires separate completed parameter cases |
| Figure 4b permeability/data comparison | k=kc*phi^3 and the independent published permeability datasets | Source/configuration retains the model law; external datasets are not simulation output |
| Figure 5 theoretical timescales | The paper's theoretical equations, physical constants, initial volume and temperature assumptions | Archived source, initial state, run configuration; theoretical postprocessing remains separate |
| Figures 2–3 and Supplementary S3 | Titan equivalents | Require separately configured Titan simulations; the active run is Europa |
| Added phase-budget analysis | Domain/shell/lower liquid, net refreezing, delivery and rates | Expanded per-step history with m3, km3 and normalized quantities |

## The active frozen run

The active run started on 25 October 2026 uses its immutable committed source.
Its scalar history already samples **every timestep**, written to the main CSV
in batches of 100 steps and at normal termination. The exporter below copies
that history and preserves each complete checkpoint it observes from startup,
normally one per 100 steps. The exporter neither edits the solver nor changes
its timestep. It cannot recover previous checkpoints that were overwritten.

```powershell
python model_and_dependencies/preserve_Europa_paper_outputs.py RUN_DIRECTORY --watch
```

The exporter writes under `RUN_DIRECTORY/paper_outputs/`:

- `time_history.csv`: every available timestep, actual dt, all inventories in
  m3/km3, cumulative net delivery and net refreezing, normalized shell melt,
  delivery/refreezing rates over each actual step, current and deepest-so-far
  shell penetration. Rates at t=0 are undefined (NaN).
- `checkpoints/checkpoint_step_XXXXXXXX.mat`: byte-exact copies of observed
  checkpoint files containing H/T/phi/Grid, step, time, scale and options.
- Matching `.npz` files: portable, unaltered numerical arrays plus axes in m,
  annular cell volumes in m3, actual time and step. Cell arrays are flattened
  in MATLAB column-major order: `phi.reshape((Ny,Nx),order='F')`.
- `checkpoint_fronts.csv`: additional depth thresholds phi>=0.001, 0.01,
  0.05, 0.1 and 0.5 at the archived checkpoint times. Both shell and whole
  domain front elevations are retained; these are **not** every-step series.
- `field_manifest.json`: paths, actual timestamps, steps, SHA-256 hashes and
  whether a file contains solved flow. The extra thermodynamic checkpoints
  do not contain pressure or velocity. Original `states/` files do.
- `paper_snapshot_times.csv`: actual available states at/after each Figure 6
  timestamp, with the time offset explicit. `panel_matches_run_kc` identifies
  the paper panel applicable to this run. No interpolated fields are created.
- `sampling_metadata.json`, `status.json`, and an exact exporter-source copy.

Depth means surface elevation minus the deepest **cell centre** above the
labelled melt threshold. The main history retains its established phi>=0.001
definition. The 100-m vertical cells put the deepest shell centre at z=50 m,
so its maximum cell-centre penetration is 9.95 km. No artificial extension to
10 km is added. Threshold sensitivity is retained because small upwind tails
must not silently define a physically resolved percolation front. There is
no fracture/pore-opening variable or impact-origin tag in this solver.

Net refreezing is freezing minus new melting, evaluated by the existing liquid
volume balance. It includes initial phase-equilibration adjustments. It is
not cumulative gross refreezing. Net delivery subtracts upward return flow.
Pressure reproducibility remains unresolved and is not certified by these
read-only output checks.

## Future research launches

The working shared solver has **output controls only** added outside its
flow/transport block. Their defaults are disabled for existing callers.
`run_Europa_until_depleted` enables full-field snapshots at:

- the first ten steps and existing selected early steps;
- every 100 completed steps;
- the first actual step at/after all Figure 6 panel times, plus a logarithmic
  requested-time grid with 50 requests per decade from 0.001 to 100000 yr;
- a change of at least 0.5% of initial shell volume in either remaining shell
  liquid or cumulative delivery since the last full snapshot;
- a front-depth change of at least 100 m since the last full snapshot;
- the existing 10-year interval and termination.

Requests crossed in one timestep produce one actual state. No timestep is
shortened to hit a requested timestamp and no interpolation is used. These
new full-state triggers apply to subsequent launches, not the already loaded
frozen simulation. The active run receives the separate checkpoint archive.

## Verification

`verify_Europa_paper_outputs` ran three steps with the new full-state controls
enabled. Saved temperature, melt fraction, enthalpy and final time matched
the active frozen run's corresponding state exactly; basal solid and Darcy
flux stayed zero. The report is in
`Output/Europa_paper_output_check_20261025_144054/verification.json`.
The source block covering buoyancy, flow, pressure, timestep and enthalpy
transport is byte-identical to the active frozen source. Separate exporter
checks tested signed delivery rates and running maximum depth, checked copied
MAT hashes, verified exact NPZ array preservation, and compared archived liquid
inventories with their actual-step CSV rows. These are output checks, not a
pressure-accuracy or spatial-convergence study.
