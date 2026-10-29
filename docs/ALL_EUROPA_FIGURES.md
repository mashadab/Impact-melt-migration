# Complete Europa figure set

`plot_all_Europa_figures.m` reuses the saved-data and manuscript-style helpers
exported by `plot_Europa_paper_figures('helpers')`. It reads all six research
cases and makes fifteen pages covering main Figures 4, 5c/d, 6 and 7, Supplementary
S4, all-case histories/evolution, endpoint inventories, measured milestone times,
initial/end fields, lower-layer inventory and original paper time requests.

All six cases use kc=1.85 times 10 to powers -16, -14, -12, -11, -10 and -8 m2.
All recorded endpoints are accepted as depletion complete by the user's
2026-10-28 and 2026-10-29 instructions. Labels and endpoint markers treat every case equally.
The measured residuals, histories and original solver stop reasons are retained
in the data archive. Completion times mean recorded accepted endpoints; they do
not replace the separately stored actual 0.5% threshold-crossing times or NaNs.
The original main grouping e-16/e-10/e-8 retains the user's 1500-yr and 500-yr
linear windows for panels (a) and (c). Semilog/all-case pages retain full times.
The new e-11 endpoint is the matched checkpoint/budget at step 67,700 and
34,847.2439243349 years. All six cases appear in the summary pages, and pages
13-15 add the e-16/e-11/e-8 comparison using the existing manuscript helpers.
The e-11 output path is read from `tmp/Europa_S3_kc11_run.txt`.
After the MATLAB and exporter processes are stopped, the one-time
`scripts/preserve_stopped_Europa_kc11.py` preserves and validates its last
checkpoint/budget pair without overwriting the original results.

The 27-page `docs/Impact_melt_foundering.pdf` is the main manuscript. Its Figure
4 caption provides the reported permeability-fit band; raw empirical scatter
is unavailable and omitted. Europa Figure 5 uses equations 9-11, the actual
model constants, and no invented unique shell temperature. The 8-page
`Impact_melt_foundering (1).pdf` is the supplement, including Figure S4.

Set fresh output/build folders in `tmp/all_Europa_figures_latest.json`, then:

```matlab
addpath('model_and_dependencies')
plot_all_Europa_figures
```

Run `model_and_dependencies/finalize_all_Europa_figures.py` with the bundled
Python runtime. It verifies every history, selected timestamp, displayed field
inventory integrated with cylindrical annular volumes and first-sample milestone.
It exports a combined PDF, 300-dpi PNGs, SVGs, MATLAB FIGs, CSVs, selected arrays,
source/configuration provenance and ZIP. `--visual-reviewed` is set only after
checking all fifteen rendered pages. No simulation is advanced or modified.

Times New Roman, actual saved cell colours, no contour outlines, no numerical
field interpolation and no image smoothing are retained. The near overlap of
the e-14 and e-16 trajectories is shown without artificial display offsets.
Pressure accuracy and physical convergence remain outside these plotting checks.
