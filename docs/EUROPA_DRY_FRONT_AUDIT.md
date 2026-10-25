# Europa: why a previously dry grid cell becomes wet

Audit date: 2026-10-24. This analysis does not change or rerun the research solver.

A subsequent isolated audit, documented in `docs/EUROPA_REGULARIZATION_AUDIT.md`, quantifies compaction-regularization sensitivity, confirms a saved-overpressure inconsistency, and demonstrates numerical spreading in a controlled dry-front transport test. The local budget reconstruction below identifies the contributing term; it does not separate exact interface motion from discretization error.

The checked dry-to-wet events arise from bulk enthalpy advection. They are not caused by a nonzero Darcy permeability floor, and do not demonstrate creation of empty pores or fractures.

## What was checked

`model_and_dependencies/audit_Europa_dry_front.py` reconstructs the explicit enthalpy update using the saved physical solid velocity, Darcy flux, cylindrical finite-volume geometry, thermal conductivity, and the start-of-step phase recovered from enthalpy. It uses only pairs of saved states separated by exactly one iteration. Flow is saved at the start of an iteration; enthalpy and phase are saved at its end.

| Diagnostic | kc = 1.85e-8 m² | kc = 1.85e-16 m² |
| --- | ---: | ---: |
| Consecutive updates checked | 12 | 901 |
| Iterations checked | 1–10, 82, 100 | 1–11, 73, 100, 13519–14406 |
| Maximum dimensionless enthalpy reconstruction error | 8.88e-16 | 3.33e-16 |
| Maximum Darcy flux on interior faces touching exactly dry cells | 0 m/s | 0 m/s |
| Dry-to-wet cell events, phi increasing from exactly 0 to above 1e-6 | 17 | 114 |
| Such events reproducible by conduction alone | 0 | 0 |

These are checks of the available consecutive updates, not every iteration in either run. The 1e-6 threshold is used only for the audit; it is not a porosity floor in the solver. All saved fields read for these updates are finite. The 1/tilde_phi expression in the sparse enthalpy implementation does not introduce a discrepancy in these checked updates.

## A concrete cell

At r = 1300 m and z = 8750 m, the initial condition has phi = 0 and T = 273 K, so dimensionless enthalpy H = 0. In iteration 1 of the high-permeability case:

| Contribution to dimensionless enthalpy | Value |
| --- | ---: |
| Bulk advection | +2.88411834805511e-4 |
| Darcy transport | 0 |
| Thermal conduction | 0 |
| Final enthalpy | 2.88411834805511e-4 |

The final liquid fraction is 2.89454119910811e-4 after 0.00327783285 years. The low-permeability case gives the same qualitative mechanism at that location, with phi = 2.63506275074010e-4 after its first step. Different adaptive time steps mean these two first-step values are not an equal-time comparison.

## Interpretation and limits

The code's phi is liquid volume fraction. It is recovered from enthalpy: phi = 0 for H <= 0, phi = H/Pi_6 in the partially molten interval, and phi = 1 in the fully liquid interval. There is no separate field for empty void space, fracture damage, or cavitation.

Darcy face permeability is the harmonic mean of phi^3. A face touching an exactly dry cell therefore has zero mobility. In the checked updates, all incident Darcy fluxes into exactly dry cells are zero. The bulk velocity can still move melt-bearing material into a fixed grid cell, and the resulting positive enthalpy gives positive liquid fraction. A fixed grid location becoming wet is not equivalent to a dry material parcel spontaneously opening pores.

This explanation is consistent with advection of a melt-bearing body and the enthalpy equations being implemented. It is not a proof that the computed front thickness or penetration rate is physically converged. First-order Godunov transport can smear a moving front; after a small positive liquid fraction appears, phi^3 gives that cell nonzero permeability. A grid-resolution study is needed to quantify this effect on subsequent segregation. The S3 wave benchmark starts with a nonzero background phi = 0.001 and does not by itself validate invasion of exactly dry ice.

Mechanical dilation can change liquid fraction in an already connected two-phase region. The audit does not support describing the initial dry-to-wet events as spontaneous dilation-induced pore nucleation.

## Connection to the permeability comparison

The two research runs use the same archived solver and the same options except kc and output directory. At equal phi and pressure-head gradient, their Darcy mobilities differ by 1e8. Their actual flow speeds do not have to differ by that factor, because pressure, matrix motion, phase distribution, and heat transport evolve together.

At an actual saved flow state near the main transfer in the high-permeability run (flow time 80.0132 yr), the downward Darcy contribution across z = 0 is 26.5787 km³/yr and the solid-carried contribution is -24.5881 km³/yr: there is strong compensating counterflow, with net downward liquid transfer 1.99056 km³/yr. In the low-permeability case at flow time 561.4371 yr, the corresponding terms are 8.52865e-8 and 0.0570398 km³/yr. These are different labelled times; they diagnose the transport mechanism rather than form an equal-time speed ratio.

This supports relative melt–ice segregation in the high-permeability case and transport mainly with the deforming aggregate in the low-permeability case. The time to deliver 50% of the initial shell melt is 82.5247 versus 623.5251 yr (7.56 times longer). The time to reach 0.5% remaining shell melt is 3587.46 versus 47138.25 yr (13.14 times longer); this latter criterion combines delivery and refreezing and is not a pure migration speed.

The recorded net refreezing in both runs includes a common 0.367285 km³ initial phase-equilibration adjustment. Net refreezing is a signed budget residual, not a measurement of gross freezing events or an origin tracer.

Physical background: [Hammond, Parmentier & Barr (2018)](https://arxiv.org/abs/1811.11257) describes the competition between matrix compaction and thermal evolution in ammonia-rich icy shells. It supports the general mechanism, not validation of these pure-water Europa runs.

Machine-readable results and the comparison figure are in `Output/Europa_permeability_comparison_20261024/`: `dry_front_audit.json`, `dry_front_consecutive_steps.csv`, `comparison.json`, and `Europa_permeability_mechanism_comparison.png`.
