# Three-case manuscript comparison

`plot_Europa_paper_figures(out,build,high_dir,middle_dir)` reuses the existing
manuscript figure helpers to compare kc=1.85e-16, 1.85e-12 and 1.85e-8 m2.
The explicit fourth argument selects this focused three-page output mode;
existing calls with three or fewer arguments retain the earlier figure pack.

The pages are linear volume/depth histories, full-time semilog histories,
and a temperature/melt evolution strip. Panels (a), (b), (c) are low, middle,
high kc. Linear time limits are 1500, 5000 and 500 years, respectively, so the
previously requested limits for (a) and (c) remain in place. Times New Roman
and original saved cell values are used. Markers match actual selected states.
Field panels have no added temperature-band outlines. Image smoothing is
disabled in the PNG renderer, and SVG images use pixelated rendering. The
layout-only `polish_Europa_paper_figures(out,build,'remove_outlines')` mode
removes the earlier outlines from saved figures and verifies unchanged image
colour arrays before exporting them again.

The middle case is explicitly user-stopped at step 33600 and
54817.746120019896 years, with 0.628% initial shell melt remaining. Its input
history comes from the preserved matched budget named in STOPPED_BY_USER.json.
It is not labelled as a completed-depletion endpoint. The high case uses the
completed fresh S3 replay, not the earlier 799-year plotting cutoff.

`finalize_Europa_three_case_figures.py` reads the output/build paths from
`tmp/manuscript_three_cases_latest.json`. It checks timestamps, phase budgets
and summaries, assembles PDF/PNG/SVG/FIG deliverables, retains field arrays and
CSV selections, and writes a ZIP. Pass `--visual-reviewed` only after inspecting
the rendered three pages. Simulation source and the running final sweep case
are unaffected. Unavailable Titan data and pressure/convergence validation
are outside this plot comparison.
