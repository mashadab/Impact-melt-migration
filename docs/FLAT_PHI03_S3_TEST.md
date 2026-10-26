# Flat-layer test with initial porosity 0.3

The new test uses the corrected S3 solver from the original centered/flat-layer
comparison, with a flat partially molten upper half:

| Initial field | Value |
| --- | --- |
| Porosity, 4 < z < 10 km, all x | 0.3 |
| Porosity, -2 < z < 4 km, all x | 0 |
| Temperature, entire domain | 273 K |
| Domain | 0 < x < 20 km; -2 < z < 10 km |
| Grid | 100 by 120 Cartesian cells |
| Permeability | k = 1.85e-8 phi^3 m^2 |
| Boundary conditions | Closed and insulated on every side |
| Final time | 8.89348313212041 years, matching the previous flat/centered videos |

No lateral perturbation is imposed. Temperature and porosity evolve freely
after initialization. The original viscosity, pressure reference, fluxes and
time stepping are retained.

The solver is `model_and_dependencies/darcy_stokes_2D_flat_phi03_S3.m`.
`run_flat_phi03_S3.m` checks the initialized fields and the final time,
boundary fluxes, porosity range and enthalpy conservation. The case key
`centered_water` inside this copied solver identifies the inherited S3 setup
family; the run is explicitly labeled `flat_phi03` in its saved result.

`make_flat_phi03_video.m` creates the 2D porosity video in the earlier layout.
`make_flat_phi03_1D.m` creates a two-panel melt/temperature video, a static
profile figure, an editable MATLAB figure, and CSV exports of every saved
profile. The profiles use the actual column at x = 10.1 km, without spatial
averaging. Videos hold actual saved states without temporal interpolation;
both exporters decode selected frames and compare them with their source
renderings.

`make_flat_phi03_minimal_videos.m` exports minimal 2D melt and 1D
melt/temperature videos to `videos_minimal/`, keeping only the plots, axis
labels, color scale, and time. It uses the same saved snapshots and verifies
decoded frames from both exports.

The output folder contains frozen runtime sources and hashes, initialization
diffs, configuration, the saved initial state, full-field snapshots, scalar
diagnostics at every step, and verification reports. Its location is recorded
in `tmp/flat_phi03_output.txt`.

To run another instance from MATLAB:

```matlab
addpath('model_and_dependencies')
out = fullfile(pwd,'Output','flat_phi03_new_run'); % use a new directory
run_flat_phi03_S3(8.89348313212041,out);
make_flat_phi03_video(out);
make_flat_phi03_1D(out);
make_flat_phi03_minimal_videos(out);
```

The optional `scripts/prepare_flat_phi03_test.py` recreates the frozen launch
folder used locally. It requires the archived original centered run and
flat/centered video configuration under `Output/`; those generated archives
are not included in Git. The MATLAB commands above use the checked-in solver
and do not require those archives.
