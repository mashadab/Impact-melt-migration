# Figure 1: Europa surface, initial melt body and migration mechanism

The renderer is [`model_and_dependencies/make_surface_cutout.py`](../model_and_dependencies/make_surface_cutout.py). It assembles the current compact, large-text figure from saved simulation cells and NASA photographs. The central initial condition retains temperature shading; the small pool in the context section uses the actual initial melt blob without temperature shading. The caption is in [`FIGURE1_CAPTION.md`](FIGURE1_CAPTION.md).

This script reads existing results and does not advance or modify the research solver. Native cells are reflected about the axis, without field smoothing. The planetary shell and ocean are schematic; the context is not a reconstruction of the subsurface at Mannann’an.

## Requirements

- Windows, with Arial and Segoe UI Symbol in `C:/Windows/Fonts`.
- Python with `numpy`, `Pillow` and `reportlab`.
- MATLAB R2022b libraries in `C:/Program Files/MATLAB/R2022b/bin/win64`, read through the tracked `preserve_Europa_paper_outputs.MatReader` helper. Adjust the library path in the renderer for a different installation.
- Poppler's `pdftoppm` for PNG export.

## Saved inputs

The renderer resolves all project paths relative to the repository. Input data and photographs remain under the ignored `Output` directory and are not bundled with the source code. To reproduce the figure, provide these existing files:

```text
Output/Europa_paper_minimal_20261029_164901/selected_fields/
    e08_step_00000000.mat
    e16_step_00000000.mat
    e16_step_00002815.mat
    e16_step_00007889.mat
    e16_step_00011000.mat
    e08_step_00003289.mat
    e08_step_00006042.mat
    e08_step_00009518.mat
Output/figure1_big_picture_20261029/
    low_initial_arrays.npz
    high_initial_arrays.npz
Output/pdf/melt_percolation_mechanism/online_assets/
    PIA19048_Europa.jpg
    PIA01402_Mannannan.jpg
```

Each MAT file contains the saved structure `s` with `step`, `time_years`, `radius_km`, `elevation_km`, `phi` and `temperature_K`. The two NPZ files contain the initial phase/enthalpy fields, ice divergence, staggered relative liquid fluxes and their grid coordinates used in panel d.

Photo sources and credits: [Europa mosaic](https://assets.science.nasa.gov/content/dam/science/psd/photojournal/pia/pia19/pia19048/PIA19048.jpg), NASA/JPL-Caltech/SETI Institute; [Mannann’an crater](https://science.nasa.gov/missions/europa-clipper/europa-clipper-resources/mannannan-crater/), NASA/JPL/University of Arizona.

## Render and export

From the repository root:

```powershell
python model_and_dependencies/make_surface_cutout.py
pdftoppm -r 600 -png -singlefile Output/figure1_surface_cutout_20261029/compact_large_text_render.pdf Output/figure1_surface_cutout_20261029/Europa_compact_large_text
```

Use the full executable paths if Python or Poppler is not on `PATH`. The PDF is an internal rendering intermediate. The final deliverable is `Output/figure1_surface_cutout_20261029/Europa_compact_large_text.png` (183 × 170 mm; 4,323 × 4,016 pixels at 600 dpi). The renderer also writes input hashes, exact plotting extents, scale calibration and text bounds to JSON files beside the figure.

Evolution snapshots use a common 8 pt/km scale, with different vertical crops retaining the complete displayed melt bodies. The initial condition is separately enlarged. Panel d compares the low-permeability solution on the left with the high-permeability solution on the right; it is not a single asymmetric calculation. Its flux arrows use a common scale and its divergence colours span −30 to +30 per year.

The protected `Output/figure1_last_known_good_20261029` snapshot is separate and is not modified by this renderer.
