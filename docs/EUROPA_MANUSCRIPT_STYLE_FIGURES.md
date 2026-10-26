# Manuscript-style plots from corrected saved results

`plot_Europa_paper_figures.m` adapts the conventions in the existing
`Europa_video_creation.m`, `plot_Europa_saved_times.m`, and
`plot_Europa_permeability_comparison.m`. It reads data only. Temperature uses
`bone`, melt uses reversed `parula`, text uses Times New Roman, and volume/depth
histories use the manuscript's blue/red dual-axis layout.

The figure pack created on 25 October 2026 contains eight pages: Figure 4
delivery/permeability, Figure 5 theoretical timescales, two Figure 6 snapshot
strips, Figure 7 volume/depth, its semilog version, completed reference
histories, and delivery/net-refreezing histories. Corrected Titan cases,
Europa kc=1.85e-10, and unavailable empirical scatter/error bars are omitted.
Theoretical contours evaluate the paper's equations using the archived model
constants; they are not additional simulations.

The main high-kc evolution uses the fresh ongoing run, frozen for the plots
at step 30300 and 798.994530269574 years. The low-kc evolution uses its completed
corrected run. Final-volume Figure 4 uses both completed research runs; the
completed high-kc result is never inserted as an uncomputed future state of
the fresh run. Exact paths and time selections are retained with the figures.

Run from MATLAB after creating fresh output/build folders and recording their
paths as `output_dir` and `build_dir` in `tmp/manuscript_figures_latest.json`:

```matlab
addpath('model_and_dependencies')
plot_Europa_paper_figures
% Optional layout-only pass on editable figures:
polish_Europa_paper_figures
```

Then use the bundled Python runtime to run
`model_and_dependencies/finalize_Europa_paper_figures.py`. It assembles the
PDF, renders PNGs, checks actual-state timestamps and liquid-volume balances,
and retains source/configuration/array provenance. Pass `--visual-reviewed`
only after visually inspecting every final figure. Individual SVG and editable
MATLAB FIG files, selected-state MAT arrays, and the captured scalar histories
are kept alongside the PDF. Rendering requires MATLAB R2022b, Python with
NumPy/Pillow/pypdfium2, and the original saved runs.

No temporal/spatial interpolation of numerical fields is used. Isotherm bands
follow original cell edges. Time-history segments join actual scalar samples.
The main front threshold remains phi>=0.001 and uses 100-m cell centres; labels
are rounded but selection CSVs retain full precision. These are plotting and
conservation checks, not a pressure-accuracy or coupled-convergence study.
