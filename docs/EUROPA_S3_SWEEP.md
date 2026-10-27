# Europa permeability sweep

The remaining Europa cases are kc = 1.85e-10, 1.85e-12 and 1.85e-14 m2.
They use the existing impact_melt_europa switch, k = kc phi^3, the same
03321 initial condition, cylindrical 100 x 120 grid, impermeable outer base
and net delivery accounting at z=0. Each starts fresh and stops when shell
melt is at most 0.5% of its initial integrated volume.

Run `scripts/launch_Europa_S3_sweep.ps1` from PowerShell. It prepares all three
cases using `launch_Europa_S3_research.ps1 -PrepareOnly`, freezing and hashing
the committed MATLAB sources and initial condition before starting any case.
One detached queue worker then runs them sequentially. It automatically starts
the existing paper-output exporter for each case. Solver source is unchanged.

The latest queue path is in `tmp/Europa_S3_latest_sweep.txt`. Its `queue.json`
records queued/running/completed/failed states, process IDs, source revision,
output folders and completion summaries. The worker and exporter source copies
are inside the sweep directory. Per-case startup checks verify the actual
executable, exponent, geometry and initial lower-layer temperature/melt.

A worker can continue an existing queue with `-Worker -SweepDirectory PATH`.
It starts only entries marked `queued`. A deliberately ended partial run is
marked `stopped_by_user`, retains its actual checkpoint/time and melt budget,
and is never labelled as having reached the depletion criterion.

Existing completed 1.85e-8 and 1.85e-16 results are preserved; this launcher
does not rerun them. No Titan cases are included in this Europa queue.
Scalar histories retain every timestep. Field saving uses the existing
100-step, requested-time, 10-year, volume-change and front-depth triggers,
plus termination. Saved numerical fields are not interpolated.
