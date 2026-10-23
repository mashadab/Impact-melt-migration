# Closed-lid column test (separate solver)

The original `simple_test_1D.m` and `Simple_test_wrapper.m` are unchanged. The separate solver retains its `_noflow_base` name, but now seals and insulates the top, bottom and sides.

```matlab
Simple_test_noflow_wrapper(1000);    % kc = 0, 1.85e-12, 1.85e-8 m^2
Simple_test_noflow_wrapper(1000,3);  % only kc = 1.85e-8 m^2
plot_simple_noflow_results;         % regenerate plots from completed cases
```

Put `model_and_dependencies` on the MATLAB path. Runs use the original 100 x 120 Cartesian grid. The initial homogeneous column is at 273 K and melt fraction 0.5, INCLUDING the top and bottom cells. No cell has a prescribed enthalpy, temperature or melt fraction. Normal solid flow, Darcy flow, advective enthalpy flux and conductive heat flux are zero on all exterior boundaries. This closed lid is also thermally insulated; it has no imposed surface temperature or heat flux.

The outer base is at z = -2 km (bottom cell centre -1.95 km); z = 0 is internal. Middle profiles average the two central columns at x = 10 km. Each permeability uses its own adaptive timestep; equal step counts need not mean equal physical times.

New results go in `Output/closed_lid_1000_steps/`. Previous fixed-top runs remain in `Output/no_flow_base_1000_steps/`. MAT files contain snapshots, every-step diagnostics and the final full state. Plots include temperature and melt fraction, and CSV files contain the plotted data. Global energy checks now use the change in total enthalpy, with no boundary-reservoir correction.

Passive tracers and legacy 2D graphics/video are disabled by default; they do not feed back into flow or enthalpy. Sparse zero storage preserves the original operators. No temperature clamp was added.

All changed solver blocks are marked with `% CHANGE NF-xx START` / `% END CHANGE NF-xx`. See `NOFLOW_BASE_CHANGES.md` for the index and `NOFLOW_BASE_CHANGES.diff` for every added and removed line. The wrapper and plotter are marked as entirely new files.
