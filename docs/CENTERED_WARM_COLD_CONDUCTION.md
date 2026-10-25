# Centered-body comparison and the role of conduction

This is a read-only analysis of the completed warm and cold-bottom S3 tests at exactly 100 simulated years. No flow is re-solved and neither research run is modified. Both use kc = 1.85e-8 m2 and permeability exponent 3, the same Cartesian 100 x 120 grid, initial water body, closed/insulated boundaries and material laws. The warm run starts at 273 K (approximately 0 C); the cold run changes only the lower-half initial temperature to 253.15 K (-20 C). The melting point remains the original 273 K.

The buoyancy/flow/enthalpy/phase update block in the two frozen sources is text-identical; all common numerical helpers have identical bytes. New cold-run code only initializes temperature and records diagnostics. Both actual endpoint times are 100 years. Profiles use the actual column at x = 10.1 km (the closest cell column to the domain center on its right), represented as constant values over each grid cell. No field/time interpolation or averaging across columns is used.

## Endpoint comparison

Volumes are per metre of out-of-plane depth, not axisymmetric volumes.

| Quantity at 100 years | Warm | Cold bottom half |
| --- | ---: | ---: |
| Initial liquid [million m3/m] | 60.00 | 60.00 |
| Liquid below z = 4 km [million m3/m] | 59.4279 | 40.6104 |
| Final liquid in whole domain [million m3/m] | 60.0000 | 55.8656 |
| Domain net liquid loss [million m3/m] | ~0 | 4.13437 |
| Net liquid loss / initial liquid | ~0 | 6.89062% |
| Lowest center-column cell center with phi >= 0.5 [km] | -1.95 | -0.05 |
| Liquid-weighted centroid z [km] | -0.372687 | 2.887675 |

The warm water has reached the closed base by 100 years; the colder body is higher and still descending. Therefore comparing their instantaneous final fluxes would not be a useful measure of their overall migration-speed difference. The cold run's dry-ice viscosity initially exceeds the warm value by a factor 5.6257 under the retained temperature law. Temperature also changes buoyancy and phase equilibration. The slower cold trajectory cannot be assigned to conduction alone from these two runs.

## What conduction did

The exact cumulative lower-half energy budget in the cold case is:

- Net advected enthalpy: 1.524291761e16 J/m.
- Net conductive input: 2.237050093e12 J/m.
- Total enthalpy gain: 1.524515466e16 J/m.
- Conductive fraction of net lower-half enthalpy gain: 0.0146738%.

This fraction measures net conductive transfer across the boundary of a fixed region. Heat conducted from liquid to nearby ice *within* that region cancels in its net total. It must not be interpreted as zero local conductive effect or as the fraction of migration/refreezing caused by conduction.

Signed cumulative cell contributions show both local heating and cooling. The positive cell sum is 5.068152061e12 J/m and the negative cell sum is its opposite, consistent with an insulated whole domain. These are signs of the final time-integrated cell budgets, not gross positive/negative heat-transfer integrals over time. Maximum net conductive cell contributions are +0.0196236 and -0.0283089 in dimensionless H, equivalent to +3.395 and -4.897 K if applied to ice with no phase change; these are not actual parcel temperature histories.

At x = 10.1 km, z = 3.95 km, the actual first update ends at 0.714175 years. It starts with T = 253.15 K and phi = 0. Its dimensionless enthalpy budget is:

```
initial H          -0.114739884393064
bulk advection     +0.115184495305557
Darcy              +0
conduction         +0.000127719850852
final H            +0.000572330763345
```

Using this actual starting state and its frozen flow, omitting conduction from that single update gives phi = 0.000446218; the actual update gives phi = 0.000574399. The conductive increment corresponds to 22.3157% of this small final cell phi. This selected local first-update fraction is not a domain or migration fraction. Conduction alone warms that cell to 253.172096 K and leaves phi = 0; it does not reach the 273 K melting threshold. All 15540 recorded updates give zero cold dry-cell transitions to liquid in the diagnostic that retains only each step's conductive increment. These checks do not evolve independent no-conduction trajectories and do not establish the complete causal effect of conduction over 100 years.

Bulk enthalpy transport includes latent heat, material motion and the numerical mixing of the first-order upwind scheme. The appearance of liquid in a fixed initially cold cell does not by itself establish pore nucleation or heating of the original material parcel. Net refreezing is the effective liquid-volume budget of the enthalpy model, not an independently measured gross physical freezing rate.

The warm run remains at 273 K within 1.18e-9 K over all recorded steps; its final conductive increment is exactly zero.

## Retained conductivity and resolution limits

The inherited code sets kappaPrime = 100 in cells with z < 200 m and phi > 0.5. With kappa_b = 3.3 W/(m K), this is 330 W/(m K), an ocean-style enhancement rather than molecular water conductivity. It is retained in both tests and active in 62 cold-run cells in the final flow. Elsewhere cell conductivity is phi*0.56 + (1-phi)*3.3 W/(m K), before harmonic face averaging.

Dry-ice diffusivity is 1.70313e-6 m2/s and sqrt(diffusivity*100 years) = 73.29 m. The grid has 100 m vertical and 200 m horizontal cells. Thus the dry-ice conductive layer is not fully resolved. Refinement and a separately evolved no-conduction control would be needed to quantify a converged causal effect on migration or freezing. The existing diagnostics establish the role of the recorded terms in these calculations.

## Reproduction

Run `audit_centered_warm_cold_conduction.py` with the bundled Python interpreter; it reads existing MAT files through MATLAB's MAT-file library and writes exact profiles, cell fields, budgets and provenance to a new output directory. `tmp/centered_warm_cold_audit_output.txt` points to that directory.

In MATLAB, add `model_and_dependencies` and call `plot_centered_warm_cold_conduction`. It uses the recorded output directory and writes standard MATLAB PDF/SVG figures. Then run `render_centered_conduction_figures.py` to render the canonical PDFs to PNG and verify that all SVG text uses Times New Roman. The output includes `comparison.json`, `center_profiles_100yr.csv`, `center_cold_enthalpy_budget_100yr.csv`, `cold_heat_history.csv`, and both figures with editable SVG/vector PDF versions.
