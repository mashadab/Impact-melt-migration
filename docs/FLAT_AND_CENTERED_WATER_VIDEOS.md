# Flat-layer and centered-water videos on the corrected S3 baseline

The user selected the flat-layer / centered-water pair. Both videos use the corrected shared S3 flow and heat equations, kc = 1.85e-8 m², phi³ permeability, Cartesian 100 x 120 grid, closed insulated boundaries, and the same regularized Europa rheology. The earlier flat-layer video used the inherited pressure-reference mismatch and is preserved separately; it is not used for this corrected comparison.

Output: `Output/flat_and_centered_S3_videos_20261024_221928/`.

The common endpoint is the actual centered-water saved state at **8.8934831321204104 years**, step 3357. The centered 100-year run continues independently. The video input list was frozen before rendering and does not grow while that run advances.

## Flat variant

An isolated copy of the exact frozen centered-water source removes only the x restriction from the initial phi mask. Thus water fills the entire upper half rather than the middle half of its width. The 205-line flow/transport block remains text-identical. The one additional helper edit changes the read-only initially-dry diagnostic mask to match this flat initialization. Source hashes, the original parent, and the exact initialization diff are saved with the comparison.

The internal shared solver family key remains `centered_water`; `configuration.json`, `flat_result.mat.test_variant`, and the archived initialization identify the flat variant explicitly. The primary project solver and the executing 100-year run are unchanged.

The corrected flat test reaches the common endpoint in one adaptive update. Its largest phi change is 1.24034e-9; maximum absolute solid velocity in that update is approximately 3.47e-7 m/year. This is an essentially stationary flat layer without an imposed lateral perturbation. Its movie contains only the two actual computed states, initialization and endpoint. It does not invent intermediate computed states.

The flat layer initially contains 120 million m³ of liquid per metre of out-of-plane depth; the centered body contains 60 million. This intentional volume difference is displayed in each movie and must be retained when interpreting the comparison.

## Video files and provenance

- `videos/flat_layer_corrected.mp4`
- `videos/centered_water_corrected.mp4`
- Separate frame manifests with the actual step/time and integer frame repetitions.
- Source preview PNGs and video information JSONs.
- `video_comparison.json`: common endpoint, state counts, source volumes, and model assumptions.
- `video_verification.json` and decoded PNGs: checks against the initial, middle, and final source renderings (two samples for the two-state flat movie).

The renderer uses original grid values and actual saved timestamps. It does not interpolate fields or time. Frames are repeated to set playback duration; the displayed clock changes only when the actual saved state changes. Both movies use fixed phi color limits of 0–1. Temperature is reported from the actual fields and is approximately 273 K throughout these isothermal tests.

Each video states that the common minimum Stokes shear coefficient is 1e9 Pa·s. This is a comparison within the same regularized ice/melt model, not validation of resolved liquid-water hydrodynamics.

`make_flat_and_centered_water_videos.m` renders the pair and reuses the saved flat result on a rendering-only retry. `verify_flat_and_centered_water_videos.m` decodes the videos, checks dimensions/duration/end times, and compares selected decoded frames with the corresponding source PNGs. Both are under `model_and_dependencies/`.
