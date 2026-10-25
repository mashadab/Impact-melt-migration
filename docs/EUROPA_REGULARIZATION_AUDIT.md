# Compaction regularization and dry-front audit

Audit date: 2026-10-24. The production solver and completed research runs were not changed. The tests confirm a pressure-diagnostic inconsistency and numerical spreading of the transported front. They do not support attributing bulk motion to the `1e-15` term.

## Scope and reproducibility

The driver is `model_and_dependencies/audit_Europa_regularization.m`. It creates an instrumented copy in `tmp/Europa_regularization_audit/`, rooted at the original input/helper directory. This copy loads a saved enthalpy state, assembles the existing flow equations, and returns before advancing temperature or enthalpy. It does not continue either long simulation.

Frozen-state sensitivity was tested at four inputs:

| Input | kc [m²] | State iteration | State time [years] |
| --- | ---: | ---: | ---: |
| High, initial | 1.85e-8 | 0 | 0 |
| High, main transfer | 1.85e-8 | 8091 | 80.02433835 |
| Low, initial | 1.85e-16 | 0 | 0 |
| Low, main transfer | 1.85e-16 | 11622 | 561.55682625 |

The later inputs are end-of-step thermodynamic states used for fresh flow solves at those times. They are not the start-of-step velocities archived in the same state file. At the initial state, the reproduced baseline solid velocity and Darcy flux agree with the archived first flow to relative L2 differences below 5.4e-17.

The production solver SHA-256 before and after this audit is:

`D48A4A7BF6636D06B233D16F3AFCCD50E363FE5A24336DE8D04B96828E8E7990`

It matches the solver archived with both research runs. The original source used by the audit is retained in the scratch folder.

## 1. Zero permeability does not impose zero solid velocity

The momentum equation solves for the deforming matrix velocity. The Darcy coefficient multiplies the pressure-head gradient to determine relative liquid flux. The mixture constraint is `Dp*(vm + qr) = 0`. Where all incident Darcy fluxes vanish, this constrains the solid divergence to zero, not the solid velocity itself.

For a direct control, the audit removes Darcy flow everywhere and solves the incompressible Stokes limit with the same rheology, forcing, and external boundary constraints. The compaction term is absent, so neither `1e-5` nor `1e-15` appears in this control. Solid velocity remains nonzero:

| Frozen input | Maximum solid speed on faces adjoining dry cells [m/year] |
| --- | ---: |
| Initial, either kc | 38.4446 |
| High, main transfer | 10.1381 |
| Low, main transfer | 4.66374 |

These are maxima of face velocity components, not estimates of liquid drainage speed. The control retains numerical conditioning warnings, discussed below. It nevertheless directly demonstrates that this implementation permits aggregate movement without a permeability or compaction regularization term.

At the previously identified initially dry cell, r = 1300 m, z = 8750 m, the high-kc baseline first flow gives:

| Face | Signed solid velocity [m/year] | Upwind liquid fraction | Relative Darcy flux [m/s] |
| --- | ---: | ---: | ---: |
| Left | -36.7903 | 0 | 0 |
| Right | -32.6714 | 0.25 | 0 |
| Bottom | +17.7303 | 0.25 | 0 |
| Top | +18.3425 | 0 | 0 |

Radial velocity is positive outward and vertical velocity positive upward. Thus material enters this fixed cell from its right and bottom faces. The carried liquid flux uses the upstream liquid fraction; the harmonic permeability controls only the relative Darcy term. This explains the positive enthalpy increment independently of compaction-driven pore creation.

## 2. Sensitivity to the actual flow regularization

The flow assembly uses `(phi + 1e-5)` in its compaction-viscosity coefficient, with no additive permeability floor. The audit repeats each frozen flow using epsilon = 1e-3, 1e-5, 1e-7, and 1e-9. Temperature and phase distribution are fixed within each sweep.

Reducing epsilon from 1e-5 to 1e-7 changes the whole-field L2 norms by:

| Input | Solid velocity difference / baseline norm | Darcy-flux difference / baseline norm |
| --- | ---: | ---: |
| High, initial | 6.8652e-7 | 1.5625e-6 |
| High, main transfer | 9.4637e-7 | 6.6368e-7 |
| Low, initial | 1.2068e-11 | 4.8662e-11 |
| Low, main transfer | 2.6560e-6 | 1.3558e-7 |

The largest solid-velocity difference in this comparison is 0.000266%. Relative Darcy flux on faces adjoining exactly dry cells remains exactly zero in every sweep. These results give no evidence that the finite compaction regularization is responsible for the observed bulk motion at these four states. They are not a sensitivity study of the complete trajectories or their depletion times.

## 3. Confirmed overpressure diagnostic inconsistency

The flow coefficient at production solver line 461 is proportional to

`[(1-phi)/(phi+1e-5) - (2/3)*(1-phi)] * intrinsic_viscosity`.

The overpressure at line 529 is calculated afterward using

`intrinsic_viscosity/(phi+1e-15) * divergence(vm)`.

The diagnostic uses a different regularization. It is not used by the momentum solve, Darcy flux, or enthalpy update; it is saved and plotted. At exactly zero porosity, the denominator mismatch alone multiplies the same divergence by 1e10.

Correction to the earlier interpretation: absence of the `(1-phi)` factor is not by itself an error. The manuscript defines the phase-pressure difference as `p_water - p_ice = G*eta/phi^c * div(v_ice)` (Equation 8), while its bulk viscosity is `zeta_phi = G*eta*(1-phi)/phi^c`. Thus `zeta_phi*div(v_ice)` is the phase-weighted pressure difference `(1-phi)*(p_water-p_ice)`, rather than the phase-pressure difference itself. In the ASPECT convention, compaction pressure is `(1-phi)*(p_ice-p_water)`, with the opposite sign. The diagnostic's denominator mismatch remains confirmed; a missing phase-weighting factor must not be claimed without first specifying which pressure is being reported. The production comment calling this quantity solid pressure is also ambiguous.

For comparison only, the audit calculates `(1-phi)*intrinsic_viscosity/(phi+1e-5) * divergence(vm)` with the same solved velocity and the same sign as the legacy diagnostic. This is a regularized, phase-weighted bulk stress; it is not a corrected phase-pressure difference:

| Frozen input | Maximum absolute legacy diagnostic in dry cells [Pa] | Same-flow value using the regularized bulk-law coefficient [Pa] |
| --- | ---: | ---: |
| High, initial | 1.10205e13 | 1.10205e3 |
| High, main transfer | 1.70574e22 | 1.70574e12 |
| Low, initial | 7.34535e8 | 7.34535e-2 |
| Low, main transfer | 4.50490e21 | 4.50490e11 |

Neither column should be interpreted as a verified physical solid–fluid pressure difference in exactly dry ice. There is no liquid phase there, and even the consistent-coefficient calculation can greatly amplify tiny divergence residuals in extremely viscous cold cells. Changing the diagnostic denominator alone is not enough to establish pressure accuracy. The pressure convention, phase weighting, dry-cell mask, and numerical conditioning all need attention before interpreting pressure plots.

## 4. Confirmed numerical spreading at the dry front

The controlled test calls the same `build_adv_op(...,'gd')` and divergence operators. It transports a phi = 0.2 top-hat, initially at z = 4–6 km, at prescribed vertical velocity -10 m/year for 100 years. Darcy flux, conduction, compaction, and phase sources are zero. The exact translated support is z = 3–5 km. The reference solution is computed from exact cell intersections, not interpolated data.

At nominal CFL = 0.4:

| Vertical cell size | Relative L1 profile error | Low-porosity tail ahead of the exact front |
| --- | ---: | ---: |
| 100 m | 19.34% | 600 m |
| 50 m | 13.75% | 400 m |
| 25 m | 9.75% | 300 m |

The tail criterion is phi >= 0.002, which is 1% of the imposed top-hat value. Distances use the leading edge of the first qualifying cell. Total liquid volume is conserved to about 1.2e-15 relative error. Thus an excellent global volume budget does not guarantee an accurate front shape.

At 100 m resolution, reducing CFL from 0.4 to 0.2 increases the profile error to 22.37%; nominal CFL = 0.8 reduces it to 11.34% (the final step is shortened to CFL = 0.4 to reach exactly 100 years). A smaller time step alone therefore does not remove this first-order spatial diffusion. This agrees with the standard upwind modified equation, whose numerical diffusivity is approximately `abs(v)*dz*(1-CFL)/2` for constant one-dimensional velocity. See [LeVeque's finite-volume lecture notes](https://faculty.washington.edu/rjl/classes/am574w2011/lectures/am574lecture7nup3.pdf).

This is a transport-operator benchmark, not a calculation of a 600 m error in the Europa runs. In the coupled solver, a numerically produced positive phi gives positive phi^3 permeability, so numerical front spreading can feed back on subsequent flow. Its effect on the reported delivery times remains unquantified without a coupled resolution study using consistent initial data.

The sparse `1/tilde_phi` path also produces finite transported fluxes in this zero-Darcy test despite dry cells having zero enthalpy; it does not produce NaNs in the checked benchmark.

## 5. Conditioning remains an unresolved limitation

The flow matrices generate `MATLAB:nearlySingularMatrix` warnings, including at the baseline epsilon. Baseline reciprocal-condition estimates are approximately 2e-25 to 5e-25; the production solver suppresses warnings globally. All audited solutions are finite and satisfy the mixture constraint closely, but these facts do not establish accurate pressures or every local momentum balance. At the high main-transfer baseline, the audit's maximum componentwise free-equation backward error is about 1.12e-3; the corresponding normwise measure is about 1.86e-6.

The observed sensitivity at epsilon = 1e-9 can include conditioning error, not only a physical constitutive-law response. Substituting an even smaller epsilon into the flow solve is not a demonstrated remedy.

## Consequences for interpretation

Bulk motion is allowed by the stated deformable-matrix equations. The checked dry-to-wet updates cannot be claimed as evidence of spontaneous pore opening or fracture formation. The legacy overpressure diagnostic is inconsistent, and the transport scheme demonstrably broadens a moving front. Consequently, the current audit supports the existence of bulk advection while leaving the physical front thickness, infiltration rate, and precise depletion-time comparison subject to coupled spatial convergence and pressure/conditioning checks.

No production fixes were applied during this audit. The smallest next corrections would be a consistent and appropriately masked pressure diagnostic, followed by a controlled coupled resolution study. Imposing zero matrix velocity wherever permeability is zero would instead change the physical problem to prevent solid deformation.

## Artifacts

`Output/Europa_regularization_audit_20261024/` contains `regularization_audit.json`, one `frozen_flow_sweep.mat` for each input, `audit.log`, and `dry_front_transport_resolution.png`. To repeat the numerical tests, run `audit_Europa_regularization` in MATLAB with `model_and_dependencies` on the path. Passing `true` reuses the already completed frozen-flow sweeps and regenerates the small transport tests and figure.
