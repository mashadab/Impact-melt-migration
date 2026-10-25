# Centered water body with a cold bottom half

The separate executable is `model_and_dependencies/darcy_stokes_2D_centered_cold_bottom_S3.m`, copied directly from the corrected shared S3 solver used by the completed 100-year warm centered-body calculation. The baseline solver is unchanged. Its SHA-256 is `16dcab8b484d6751dfdb263fccd546a5c72bc40d03519e8d6eab2ed4bcc7f667`.

The only physical setup change is the initial temperature of the bottom half, z = -2 to 4 km: 253.15 K (-20 degrees Celsius). The upper half remains at the original 273 K. The centered water body remains x = 5-15 km and z = 4-10 km, with phi = 1; phi = 0 elsewhere. Cartesian domain x = 0-20 km, z = -2 to 10 km, 100 x 120 cells, closed and insulated walls, kc = 1.85e-8 m2, exponent 3, material properties, pressure correction, viscosity regularization and time-step rules are retained. The model melting point remains 273 K. Temperature evolves freely after initialization.

The target is 100 simulated years, matching the previous completed warm centered-body case. The safety limit is 200000 steps, which is not completion if reached first. Create `STOP_REQUESTED` in the output directory for a graceful stop and an exact saved endpoint.

```matlab
addpath('model_and_dependencies')
r = run_centered_water_cold_bottom_S3(100);
```

The launched calculation uses an immutable copied source directory and archives its exact executable files, hashes, configuration, and minimal diff in the output. The 205-line buoyancy/flow/heat/phase block and sparse Stokes helper are text-identical to the previous solver. Additional code only records diagnostics and requests a checkpoint at the first appearance of liquid in the initially cold half. See `CENTERED_COLD_BOTTOM_S3.diff` for every solver change.

## Saved measurements

- `initial_state.mat`: actual initial H, T, phi and grid, saved before the first flow solve.
- `initial_verification.json`: exact checks of geometry, porosity mask, two initial temperatures and exponent.
- `diagnostics.csv`, every actual step: lower-half temperature statistics, liquid inventory, separated bulk/Darcy fluxes, cumulative enthalpy contributions from bulk advection, Darcy transport and conduction, and liquid import minus inventory change.
- `states/state_*.mat`: full actual state and flow, each cell's three enthalpy increments, cumulative cell budgets and one-step fields obtained by omitting conduction or advection. Saved for early steps, approximately every 0.1 simulated year, every 250 steps, the first lower-half liquid event and the final/stopped endpoint.
- `progress.json`: latest scalar measurements and actual simulated time.
- `summary.json`, `COMPLETE.txt`: produced only after the run returns, with completion distinguished from a safety limit or user stop.

For the sample cell x = 10.1 km, z = 3.95 km, the CSV also saves actual temperature, phi and cumulative enthalpy components. Below the initial freezing threshold H = 0, energy gain warms ice; positive H corresponds to liquid at the model melting temperature until fully liquid. The initial image is generated from the saved MAT arrays by `plot_centered_cold_bottom_initial.py`, using Times New Roman and no field interpolation.

## Interpretation

Conduction transports energy without carrying liquid volume. Bulk enthalpy advection carries sensible and latent heat with the moving material; relative Darcy flow also carries enthalpy. A fixed-cell temperature or porosity increase alone does not establish heating of the original material parcel or spontaneous pore nucleation.

The effective net refreezing budget is cumulative net liquid import minus the inventory increase in the lower half. It follows the implemented discrete liquid/enthalpy budget and includes the consequences of upwind mixing and phase equilibration. It is not a separately measured gross physical freezing rate. Domain net liquid loss is also reported, as the walls are impermeable.

The conduction-only/advection-only diagnostic fields omit terms from a single actual step with the same frozen velocity and pressure. They identify threshold crossings within that step; they are not independent evolved control trajectories and do not partition nonlinear cumulative melting uniquely. No saved states or times are interpolated. The original numerical front spreading and pure-liquid rheology limitations remain applicable.
