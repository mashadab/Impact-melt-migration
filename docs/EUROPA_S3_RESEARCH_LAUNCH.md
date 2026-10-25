# Corrected Europa case in the shared S3 solver

The research case is `impact_melt_europa` in
`model_and_dependencies/darcy_stokes_2D_cases.m`, selected by
`run_darcy_stokes_case`. The same evolving flow/transport implementation also
serves the validated `porosity_wave` setup. The legacy `Europa_wrapper.m` is
not the entry point for this corrected research case.

From the repository root on Windows:

```powershell
./scripts/launch_Europa_S3_research.ps1
# Optional second permeability case:
# ./scripts/launch_Europa_S3_research.ps1 -Kc 1.85e-16
```

Commit the tracked changes first. The launcher records that commit and hashes
all copied MATLAB sources and the raw impact input. MATLAB executes the frozen
`runtime/model_and_dependencies/` copy inside a fresh output directory. Its
relative `../initial_conditions/` path resolves to the frozen input. Startup
checks verify the executable path, cubic permeability, corrected pressure
reference, timestep flag, grid, and lower-region initial fields.

The default is the previously selected Europa configuration: `kc=1.85e-8 m^2`,
`eta0=1e14 Pa s`, activation energy `50 kJ/mol`, impact key `03321`, cylindrical
100-by-120 cells, radius 0–20 km, elevation -2–10 km, and a 10-km ice shell.
The lower region starts at zero melt and 273 K. Material walls are impermeable
and free slip; the surface is held at 100 K and the other thermal boundaries
are insulated. Net delivery is measured across internal `z=0`.

These choices correspond to the manuscript's Europa impact geometry and
temperate-ice lower layer, with the corrected S3 pressure/transport method and
the user-selected closed base. They do not assert reproduction of the older
manuscript's migration times.

`run_Europa_until_depleted` supplies the existing save schedule and stopping
criterion: integrated liquid in all `z>=0` cells falls to 0.5% of its actual
initial volume. There is no year cutoff; the 10-million-step cap is a safety
limit. The launcher leaves MATLAB running independently, records its process
ID in `launch.json`, and writes the new directory to ignored
`tmp/Europa_S3_latest_run.txt`. Inspect `startup_verification.json`,
`launch_provenance.json`, `run.log`, `progress.json`, `melt_budget.csv`, and
`states/`. The existing checkpoint is saved state, not automatic restart.

No numerical solver equations are changed by this launcher. See
`model_and_dependencies/EUROPA_RESEARCH_OUTPUTS.md` for output definitions and
`docs/EUROPA_REPRODUCIBILITY.md` for the independent 100-step comparison.
