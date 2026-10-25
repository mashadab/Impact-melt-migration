# Europa research video

From the repository root in MATLAB:

```matlab
addpath('model_and_dependencies')
make_Europa_research_video([],true);  % three preview PNGs
make_Europa_research_video;          % encode the completed run
verify_Europa_research_video;        % decode and check three video samples
```

An optional first argument selects a different completed Europa output folder,
including `Output/Europa_kc_1.850e-16_until_depleted_20261024_085440/`.
This script only reads numerical results; it does not run or modify the solver.

The default source is
`Output/Europa_kc_1.850e-08_until_depleted_20261023_195524/`.
The video and its supporting files are saved in that folder's `research_video/`:

- `Europa_impact_melt_migration_1080p.mp4`: 1920 by 1080, 24 fps, MPEG-4.
- `preview_initial.png`, `preview_transfer.png`, `preview_final.png`.
- `frame_manifest.csv`: each saved iteration and time, its exact diagnostic row,
  playback start time, and integer number of repeated encoded frames.
- `video_info.json`: measured video dimensions, duration, and provenance.
- `video_verification.json` and `decoded_*.png`: checks of the encoded initial,
  transfer, and final frames against their corresponding source previews.

Every map shows the actual saved values on the original grid. No temporal or
spatial interpolation of simulation data is used. The maps have fixed colour
limits: 100 to 273 K and melt fraction 0 to 1. Frame holds and repetitions vary
the playback speed; the displayed simulated time and iteration always identify
the displayed saved state. All saved states, including initialization and final
termination, are included. The volume readouts use the matching saved diagnostic
row, rather than interpolated diagnostics. Dim history curves show completed-run
context; the coloured curves stop at the displayed time.

The film gives more playback time to rapid transfer and compresses the long
residual evolution. Playback chapters use actual diagnostic times at 1% and 90%
of peak net delivery, then 1% shell melt remaining and final termination. Only
the playback clock is scaled; fields and diagnostics are never interpolated.
The initial state is held for three seconds and the final state for five seconds.
Every saved state receives at least one encoded frame. The frame manifest
records the exact resulting timing. The capture method is checked against the
source PNG before encoding; `capture_verification.json` records that check.

Net refreezing is a signed budget diagnostic, not gross cumulative freezing.
It includes the known 0.3672852028 km^3 initialization adjustment, which remains
uncorrected in the numerical run and is identified on screen.
