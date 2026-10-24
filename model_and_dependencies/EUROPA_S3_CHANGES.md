# Europa cylindrical adaptation of the working S3 solver

Baseline: `porosity_wave_2D_Jake_minimal.m`, copied directly; no original files modified.
The exact source diff is `EUROPA_S3_CHANGES.diff`.

## Files and use

- Solver: `impactorTempMeltFuncDarcyStokesModPresForm2Stokes_Europa_noflow.m`
- Callable wrapper: `Europa_wrapper_noflow.m`
- Short verification: `verify_Europa_S3.m`

```matlab
addpath('model_and_dependencies')
r = Europa_wrapper_noflow(struct('max_steps',3));
```

The default wrapper uses impact key 03321, eta0=1e14 Pa s, Ea=50e3 J/mol,
and kc=1.85e-8 m^2, matching the original Europa wrapper. The default step
limit is 1000, inherited from S3. Each call starts a new simulation, not a restart.
Use a fresh `options.output_dir` for each production run to keep prior results.
No production run has been launched.

## Changes from S3

1. Restore Europa density (920 kg/m^3), gravity (1.315 m/s^2), shell thickness,
   and the original temperature/porosity-dependent viscosity functions.
2. Replace the Cartesian wave grid/CSV initialization with the ORIGINAL Europa
   cylindrical grid and impact initialization: 100 radial by 120 vertical cells,
   r=0 to 20 km, z=-2 to 10 km for key 03321. Load `ic03321_100.mat`, prepend
   the same 20-cell temperate, initially zero-melt lower layer, and retain the
   original `phiGr(Y<0.25)=0` initialization. Thus the copy reproduces the old
   preprocessing, including its suppression of melt below z=2.5 km.
3. Keep S3's sparse operator assembly. Its existing calls to `build_ops` select
   cylindrical radial divergence through `Grid.geom`, and the cylindrical grid
   builder supplies the original annular volumes and face areas. This uses the
   repository's existing cylindrical discretization, with no new mechanics scheme.
4. Keep S3's preserved permeability matrix and pressure head in Darcy/enthalpy
   transport, closed material walls, numerical methods and diagnostic output.
5. Restore the cold surface enthalpy (100 K), remove the old Europa basal
   enthalpy constraint and outflow designation, and keep basal enthalpy/melt free.
6. Keep the COMPLETE S3 pressure-head correction, +(Pi_5+Ra). The +Ra shifts
   -Ra*Tprime to Ra*(1-Tprime), preserving spatial thermal buoyancy while making
   it zero at the melting-temperature reference. An initial adaptation omitted
   +Ra incorrectly; the original three-step output predates this correction.
7. Account for basal prescribed heat and the surface enthalpy constraint in the
   energy budget. Keep the S3 actual-conductivity timestep enabled by default.

## Boundary conditions

Material walls have zero normal solid velocity and zero Darcy flux, with free
slip. Basal permeability rows are zero in both the flow solve and enthalpy flux.
The base is the OUTER computational bottom at z=-2 km, not the internal z=0
ice/lower-layer interface. Material may still cross internal diagnostic planes;
`phiDrain*` measures that internal transport, not loss through the outer base.

The original fixed 100 K surface is retained. Side walls are insulated.
The base defaults to insulated (`options.basal_heat_flux=0`), following S3.
Material impermeability and thermal insulation are independent. To use the
geothermal flux block already present in the old Europa source, set:

```matlab
o=struct('basal_heat_flux',1,'output_dir',fullfile(pwd,'Output','Europa_geothermal'));
r=Europa_wrapper_noflow(o);
```

`basal_heat_flux` is DIMENSIONLESS, not W/m^2. Setting it to 1 reproduces the
old source's qPrime=1 Neumann prescription, which was commented out there.
The active old Europa source instead fixed bottom enthalpy.

## Verification

`verify_Europa_S3` passed three full 100 x 120 grid steps at the original kc.
Checks cover MATLAB parsing, mesh geometry and extent, shell scale, exact initial
porosity and temperature after original Europa preprocessing, finite final state,
zero basal Darcy flux, zero basal advective heat flux, zero basal conduction for
the default insulated case, and negligible basal solid velocity. The integrated
heat-budget residual was approximately 7.98e-15 in nondimensional volume-weighted
enthalpy units. Recovered temperatures ranged from 100 to 273 K.

This is a short setup/boundary verification, not long-term physical validation.
Verification output: `Output/Europa_S3_smoke_20261023_182849/`.

## Pressure-reference correction after initial review

The first Europa adaptation incorrectly retained only +Pi_5. The user identified
this concern; the solver now retains S3's exact +(Pi_5+Ra) correction. Prior plots
and the smoke folder named 20261023_182849 are superseded as physical predictions.
Zero basal flux in that check remains a boundary-enforcement result, not a
validation of the forcing. See subsequent pressure-reference verification output.

Corrected verification passed: Output/Europa_S3_pressure_20261023_185230/. Three full-grid steps, exact original initialization, zero basal solid/Darcy/advective heat flux, thermal/density limiting cases, and heat-budget residual approximately 1.19e-14. This remains a short verification, not long-term validation.

## Shared case-key solver (current implementation)

The separate Europa equation copy has been consolidated into
`darcy_stokes_2D_cases.m`, a direct S3 copy with if/else setup branches. The long
Europa noflow function is now a compatibility entry point only. Use
`run_darcy_stokes_case('porosity_wave',options)` or
`run_darcy_stokes_case('impact_melt_europa',options)`.
`S3_CASE_SWITCH.diff` is the current exact source diff; the earlier
`EUROPA_S3_CHANGES.diff` records the previous separate-copy stage.
