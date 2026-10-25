# Centered upper-half water body: separate minimal test

`model_and_dependencies/simple_test_1D_centered_blob_closed.m` is a separate copy of the preserved flat-layer test `simple_test_1D_half_water_closed.m`. Its only physical change restricts the initial water to the central half of the horizontal domain:

```matlab
phiGr = double(Y > (Grid.p.ymin+Grid.p.ymax)/2 & ...
    X > Grid.p.xmin+0.25*(Grid.p.xmax-Grid.p.xmin) & ...
    X < Grid.p.xmin+0.75*(Grid.p.xmax-Grid.p.xmin));
```

On the existing domain, this is x = 5 to 15 km and z = 4 to 10 km. Water has phi = 1; all other cells have phi = 0. Temperature is 273 K everywhere. The water body reaches the top lid, just as the upper layer did in the previous test. No perturbation or porosity floor was added.

The grid remains 100 x 120 in Cartesian coordinates, covering x = 0 to 20 km and z = -2 to 10 km. Flow/enthalpy equations, rheology, pressure forcing, harmonic permeability, exponent 3, compaction regularization, adaptive stepping, and sealed/insulated boundaries are inherited unchanged. The new test retains the known pure-water phase-velocity limitations of that formulation. It is not an independently validated replacement for the S3 solver.

The other source changes rename the function, isolate its default output folder, and save the actual full initialization. `CENTERED_BLOB_CLOSED_TEST.diff` lists every change. `CENTERED_BLOB_CLOSED_TEST_PROVENANCE.json` records source hashes and verifies that reversing the documented substitutions reproduces the flat-layer parent exactly. Neither earlier test source is edited.

Restricting water to half the width halves its initial volume: 3,000 fully liquid cells versus 6,000 in the flat-layer test. This is the requested geometry change; comparisons should not assume equal initial melt volume.

## Short trial

```matlab
run_centered_blob_closed_test(100,1.85e-8)
```

The wrapper runs 100 steps, saves the full initialized and final states, center-profile snapshots at steps 0, 1, 10, 50, and 100, every-step boundary/energy diagnostics, a history CSV, a summary JSON, the exact solver source used, and an initial/final liquid-fraction figure. It checks the rectangle's exact initial occupancy, temperature, grid, boundary closure, and energy conservation. No simulated states or times are interpolated.

The first trial output directory is `Output/centered_blob_closed_20261024_193436/`. The previous run and its separate advisor package remain in `Output/half_water_1yr_20261024_190211/`.

The first trial completed 100 steps at kc = 1.85e-8 m², reaching 0.00541848313748 years (about 1.98 days). The maximum liquid fraction in the initially dry lower half is 0.00303338632. Temperature stays within about 6.3e-12 K of 273 K; recorded external fluxes are zero and relative global enthalpy error is 5.01e-15. The lateral geometry therefore produces a response distinguishable from the flat-layer test, but these values alone do not separate bulk advection, relative Darcy transport, and numerical spreading, or establish pressure/dilation accuracy.

To regenerate the saved initial/final figure without evolving the model:

```matlab
run_centered_blob_closed_test('C:/Users/lenovo/Desktop/Research/Impact-melt-migration/Output/centered_blob_closed_20261024_193436')
```
