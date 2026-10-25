# Corrected centered-water run: 100-year target

Started at the user's request on 24 October 2026. This is a fresh run from the same initial condition as the verified one-year test. The only run-parameter change is the final time, from 1 to 100 years. No solver source was edited to launch it.

- Entry point: `run_centered_water_S3(100, output_dir)`.
- Case key: `centered_water` in the corrected shared S3 solver.
- kc = 1.85e-8 m²; permeability exponent nn = 3.
- Same Cartesian 100 x 120 grid, 273 K initial temperature, and centered upper-half water body.
- Closed, insulated exterior; head-reference correction and actual-conductivity timestep enabled.
- Output: `Output/centered_water_S3_100yr_20261024_214605/`.
- Frozen executable source: `tmp/centered_water_100yr_20261024_214605/source/`.
- Shared solver SHA-256: `16dcab8b484d6751dfdb263fccd546a5c72bc40d03519e8d6eab2ed4bcc7f667`, identical to the verified one-year solver.

`configuration.json` records source hashes and settings. Actual source text is also archived under the output's `source/` directory. The live state is in `progress.json`; per-step flux, phase, and enthalpy diagnostics are in `diagnostics.csv`. Full state/flux records are saved at early steps, approximately every 0.1 simulated year, every 250 steps, and at the final or gracefully stopped endpoint. These are actual computed states, with flow and endpoint timestamps retained separately.

The hidden MATLAB launch process is recorded in `process.json`; its launcher PID is not necessarily the worker PID. Startup stdout/stderr are in the launch directory. The wrapper records failures in `error.json`. Completion requires reaching 100 years; `COMPLETE.txt` is written only after that endpoint and final plotting succeed. A step-limit exit is not completion.

To stop gracefully, create `STOP_REQUESTED` inside the output directory. The solver checks it after each update and saves the current full state before stopping. The previous one-year result and the stopped biased trajectory remain preserved in their separate output directories.
