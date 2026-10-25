# Numerical proof of transport into an initially dry cell

Audit date: 2026-10-24. The production solver and both research runs are unchanged. All numbers below come from the research runs or isolated flow replays from their exact saved states. No states or times were interpolated.

## Definitions

`q` is relative Darcy volume flux per unit face area, in m/s. `Q` is volume per time, obtained by multiplying a face flux by its actual cylindrical area. Local face tables use positive Q into the selected cell. Interface tables use positive Q downward across z = 0.

The code's liquid-volume flux is:

`Q_liquid = A * (phi_upwind * v_s + q)`

`q = -(k_face / mu_f) * grad(pressure_head)`

`k_face = kc * harmonic_mean(phi_left^3, phi_right^3)`

The carried contribution uses the upstream liquid fraction; the relative Darcy contribution uses harmonic face permeability. These are different operations. The evolution itself uses enthalpy advection, followed by phase recovery. The audit reconstructs that update using the actual `build_adv_op`, `comp_mean`, `build_ops`, and `enthMelt` functions, rather than assuming a liquid-volume update is always equivalent when freezing or heat conduction occurs.

## The selected downward-front cell

The audit automatically selected the lowest common initially dry cell that becomes wet in the first step in both runs and receives liquid downward through its top face:

- Cell ID 83, centered at r = 100 m and z = 6250 m.
- Radial interval 0–200 m; vertical interval 6200–6300 m.
- This is the full axisymmetric annular cell, including the complete 2-pi revolution.
- Initial phi = 0, temperature = 273 K, enthalpy = 0.
- The cell immediately above initially has phi = 0.25.
- Top-face area = pi * 200^2 = 125663.706143592 m².
- Cell volume = top-face area * 100 = 12566370.6143592 m³.

The first flow in both cases is evaluated at exactly t = 0 with identical thermodynamic initial data. Their adaptive first-step durations differ.

### Top-face numbers

| Quantity | kc = 1.85e-8 m² | kc = 1.85e-16 m² |
| --- | ---: | ---: |
| Harmonic face permeability [m²] | 0 | 0 |
| Pressure-head gradient, positive upward [Pa/m] | 1128.16399085 | 1185.44845099 |
| Solid velocity, positive upward [m/s] | -4.36529587196118e-7 | -4.26565426470094e-7 |
| Downward solid speed [m/year] | 13.7681431802 | 13.4538735509 |
| Upwind liquid fraction | 0.25 | 0.25 |
| Darcy flux q [m/s] | 0 | 0 |
| Q_Darcy into cell [m³/year] | 0 | 0 |
| Q_carried into cell [m³/s] | 0.0137139814421 | 0.0134009481007 |
| Q_carried into cell [m³/year] | 432538.974684 | 422665.903097 |
| First-step duration [years] | 0.00327783285454 | 0.00332803148552 |
| Liquid gained [m³] | 1417.79046209 | 1406.64543336 |
| Actual saved phi after the step | 0.000112824180155035 | 0.000111937286948716 |

For the high-kc run:

`Q_Darcy = -(0 / 0.001) * 1128.16399085 * 125663.706143592 = 0 m³/s`.

`Q_carried = 0.25 * 13.7681431802 * 125663.706143592 = 432538.974684 m³/year` downward.

`delta_V_liquid = Q_carried * dt = 1417.79046209 m³`.

`phi_after = delta_V_liquid / V_cell = 0.000112824180155035`.

This reproduces the actual saved liquid fraction. In this cell, the Darcy and conductive contributions to the enthalpy increment are both exactly zero. The carried-liquid calculation and actual phase change agree to about 1e-20 in phi. Across the full grid, the reconstructed first-step enthalpy matches the saved endpoint to 5.6e-16 dimensionless units or better.

### All four faces, including displaced ice

Velocities below are positive radially outward or vertically upward. Q values are positive into the cell.

| Face | High-kc solid velocity [m/year] | Low-kc solid velocity [m/year] | Initial upwind phi | High-kc liquid Q [m³/year] | Low-kc liquid Q [m³/year] |
| --- | ---: | ---: | ---: | ---: | ---: |
| Left/axis | 0 | 0 | Undefined; zero face area | 0 | 0 |
| Right | +1.577055543 | +1.659014538 | 0 | 0 | 0 |
| Bottom | -12.191087637 | -11.794859013 | 0 | 0 | 0 |
| Top | -13.768143180 | -13.453873551 | 0.25 | +432538.974684 | +422665.903097 |

Every face has zero harmonic permeability and zero relative Darcy flux at this first flow. The right and bottom faces carry dry ice out of the cell. The top face carries a mixture in.

For the high-kc case, the aggregate volume entering through the top is 1730155.898735 m³/year. The aggregate volume leaving through the bottom and right is:

`1531977.254435 + 198178.644300 = 1730155.898735 m³/year`.

Thus the net aggregate-volume influx is zero to roundoff. The liquid-volume increase is balanced by an equal decrease in solid volume. This is a change in the composition occupying a fixed grid cell; it does not require net local dilation or creation of empty pores.

## What happens on the following steps

After step 1 the cell no longer has exactly zero porosity. Its top-face permeability therefore becomes positive. The actual first-ten-step face data show:

| Top face | High kc | Low kc |
| --- | ---: | ---: |
| Step 2 flow time [years] | 0.00327783285 | 0.00332803149 |
| Step 2 face permeability [m²] | 5.313837669e-20 | 5.189506423e-28 |
| Step 2 Darcy q, upward positive [m/s] | -5.902686491e-14 | -6.116131969e-22 |
| Step 2 downward Darcy Q [m³/year] | 0.2339490415 | 2.424088106e-9 |
| Step 10 flow time [years] | 0.02438694039 | 0.02595771518 |
| Step 10 carried Q through top [m³/year] | 775797.9201 | 426360.5478 |
| Step 10 downward Darcy Q through top [m³/year] | 142.2324151 | 1.120461389e-6 |

These are actual labelled steps, not equal-time interpolated values. At the first wetting of this cell, carried Q is only about 2.34% larger in the high-kc case; the disparity is not initially 1e8. Even at step 10, carried liquid dominates the direct liquid influx at this particular cell in both runs. The much larger whole-run difference develops as the connected melt, pressure, and velocity fields evolve.

## Delivery across z = 0 later in the runs

The audit recomputed flow at three exact saved thermodynamic states using an instrumented copy of the production flow equations. It then applied the recorded next time step and reconstructed the original enthalpy update. Calculated net delivery rates agree with the every-step research CSV to within 0.0034 m³/year, and reconstructed shell melt volumes agree within 4.6e-5 m³.

The source states are exactly t = 80.02433835 years, iteration 8091, for the high-kc run; t = 77.85191633 years, iteration 2049, for the low-kc near-time comparison; and t = 561.55682625 years, iteration 11622, for its main-transfer example. These times are not identical and no interpolation was used.

Positive flux below is downward, and all Q values are in km³/year:

| Case / flow time | Q_Darcy | Q_carried | Q_net |
| --- | ---: | ---: | ---: |
| High kc, 80.02433835 yr | +26.2086904574 | -24.2593862076 | +1.94930424977 |
| Low kc, 77.85191633 yr | 1.8460e-55 | -6.7718e-21 | -6.7718e-21 |
| Low kc, 561.55682625 yr | +8.526367725e-8 | +0.056996165724 | +0.056996250988 |

The low-kc near-80-year transfer is negligible. During its later main transfer, its liquid moves overwhelmingly with the solid/aggregate. The high-kc example has large downward relative Darcy transport and a large compensating upward carried-liquid contribution; their difference is the net downward delivery. These components must be added with signs. Q_Darcy alone is not the delivered volume.

These interface data establish how the implementations differ. They do not separate the physical and numerical contributions to the advancing dry-front position. The previously demonstrated first-order front spreading and the flow-conditioning limitations still apply; neither the local budget proof nor the global budget match establishes coupled grid convergence.

## Files saved

All artifacts are in `Output/Europa_face_flux_proof_20261024/`:

- `selected_cell_faces.csv`: all four faces, both selected cells, both cases, all first ten steps; areas, solid velocities, pressure-head gradients, harmonic permeability, Darcy q, and carried/Darcy/solid/mixture Q.
- `selected_cell_steps.csv`: cell porosity, temperature, time step, volume, component increments, net phase fluxes, and enthalpy reconstruction errors.
- `all_first_step_newly_wet_cells.csv`: every initially dry cell above phi = 1e-12 after the first step, avoiding reliance on one selected example.
- `interface_Q_comparison.csv`: every first-ten-step interface total and the three later comparisons.
- `high_later_z0_faces.csv`, `low_later_z0_faces.csv`, `low_main_transfer_later_z0_faces.csv`: all 100 individual annular faces at z = 0 for the later comparisons.
- `high_step_*_all_faces.mat` and `low_step_*_all_faces.mat`: full-grid face and cell diagnostics for the first ten steps, including source-operator matrices and enthalpy fluxes.
- `*_later_all_faces.mat`: full-grid diagnostics for the three later flow replays.
- `face_flux_proof.json`: compact first-step and later quantitative proof.
- `Europa_face_flux_proof.png`: figure of the first-step flux, cell evolution, and near-80-year interface comparison.

The reproducible driver is `model_and_dependencies/audit_Europa_face_fluxes.m`. Its temporary instrumented solver is in `tmp/Europa_face_flux_proof/`; it loads a saved initial enthalpy field, captures the normal flow solution, and returns before production time advancement. It never writes to either research-run directory.
