# Evidence for dilation-assisted melt segregation

Date: 2026-10-24. This is a read-only analysis of existing saved flow and thermodynamic fields. The research solver and completed simulations are unchanged. No research state or time is interpolated.

## What the existing results support

There is strong positive solid dilation in some already partially molten cells of the high-permeability calculation. The corresponding term in a local first-step porosity budget is much larger than in the low-permeability calculation. The earlier dry-cell audit did not test whether dilation was present elsewhere in the melt body.

This supports **dilation-assisted melt segregation within partially molten ice**. It does not yet demonstrate that dilation creates the first pores in exactly dry ice, or that dilation alone explains the full delivery-time difference. The numerical transport scheme also spreads the moving dry front.

## Meaning of dilation

Let `C = div(v_ice)`. Positive C is volumetric expansion of the solid framework; negative C is compaction. For incompressible solid with no phase change, solid mass conservation gives

`D_ice(phi)/Dt = (1-phi)*C`,

where `D_ice/Dt = partial_t + v_ice dot grad` follows the moving ice. Thus a fixed-cell increase in phi is insufficient: it can arise from wet material advecting into that cell. Melting/refreezing must also be separated. With no phase change, an independently followed material parcel should satisfy

`1-phi(t) = (1-phi(0))*exp(-integral C dt)`.

These relations follow from the solid-phase conservation equation; see the [ASPECT melt-transport formulation](https://aspect-documentation.readthedocs.io/en/stable/user/methods/melt-transport.html). They are conservation relations, not a microfracture or pore-nucleation law.

## Measured local example from both completed simulations

The script selects the largest positive dilation term among initially wet shell cells with `1e-4 <= phi <= 0.5`, with the cell and its four neighbors at 273 K. Both initial cases select the **same cell**, ID 1062, r = 1.70 km, z = 8.15 km. Both start at phi = 0.4375. This deliberately selected strong-dilation example is not a domain average or a statement about all cells.

Both flow solves are at t = 0. The first adaptive time steps differ slightly; values below use the actual saved updates, not a matched-time interpolation.

| Quantity | kc = 1.85e-8 m² | kc = 1.85e-16 m² |
| --- | ---: | ---: |
| First step [years] | 0.00327783285 | 0.00332803149 |
| C [1/year] | 19.1262559 | 3.34355098e-7 |
| Dilation porosity rate `(1-phi)*C` [1/year] | 10.7585189 | 1.88074743e-7 |
| Discrete bulk-transport porosity rate [1/year] | 1.34124406 | 1.48279493 |
| Effective thermal/phase residual [1/year] | -1.67e-15 | 2.71e-15 |
| Porosity increment assigned to dilation | 0.0352646268 | 6.25918665e-10 |
| Porosity increment assigned to bulk transport | 0.00439637385 | 0.00493478823 |
| Total saved porosity increment | 0.0396610007 | 0.00493478885 |
| Final phi after this step | 0.477161001 | 0.442434789 |

The dilation contribution accounts for **88.915% of the local Eulerian porosity increase** in this selected high-kc example, compared with approximately 0.0000127% in the low-kc example. This percentage is not the fraction of total migration caused by dilation. The per-year values are instantaneous first-flow rates and must not be extrapolated over a year.

![Local first-step porosity budget](C:/Users/lenovo/Desktop/Research/Impact-melt-migration/Output/Europa_dilation_evidence_20261024/initial_wet_cell_dilation_budget.png)

## How the discrete budget is calculated

The audit uses the axisymmetric physical divergence operator and all saved face velocities and relative Darcy fluxes:

```
C = Dphysical * v_ice
Fadv = flux_upwind(v_ice, Grid) * phi_before
bulk = -Dphysical*Fadv + phi_before*C
dilation = (1-phi_before)*C
total_rate = (phi_after-phi_before)/actual_dt
effective_phase_residual = total_rate + Dphysical*(Fadv+q)
mixture_correction = -Dphysical*q-C

total_rate = bulk + dilation + effective_phase_residual + mixture_correction
```

The bulk term approximates `-v_ice dot grad(phi)` and includes the upwind truncation error. The phase term is an effective residual of the actual enthalpy/phase update, not an independently computed gross melting or refreezing rate. Its negligible value in this warm neighborhood is consistent with negligible thermal/phase contribution there. Budget closure is an algebraic identity and is **not independent validation**. For the selected initial cells, actual saved endpoints are available; later screening states use the previously reconstructed next update and are flagged accordingly in the output.

The source-free mixture constraint implies `C = -div(q)`. Thus positive dilation and convergent relative liquid flux are linked in the coupled solve. Their co-location is a useful diagnostic but does not independently establish a direction of causation.

## What is needed for the stronger scientific claim

1. **Locate the deformation.** Plot signed C together with cellwise phi, temperature, and q on actual saved grids at the advancing mush boundary. Demonstrate expansion of already wet material and distinguish any proposed expansion of initially dry material. Report both positive and negative C, rather than only maxima.
2. **Follow the ice and close an independently measured budget.** Save the terms during actual time steps. Follow material parcels or material control volumes, separate phase-change sources, and compare their measured porosity change against accumulated dilation. The present fixed-grid budget is useful screening but is not an independently tracked parcel experiment. Widely spaced snapshots cannot provide exact trajectories.
3. **Test the cause with controlled rheology changes.** In isolated solver copies, vary only a multiplier on the bulk/compaction viscosity while keeping shear rheology, permeability, forcing, thermal laws, boundary conditions, and initial state fixed. Compare integrated dilation, relative liquid transport, and delivery milestones. Do not assume the response will be monotonic. Include a zero-Darcy foundering baseline. In a source-free sealed model, enforcing C = 0 also imposes div(q) = 0, so a no-dilation control constrains segregation by construction; that result alone is not proof of dry-pore nucleation.
4. **Demonstrate numerical convergence.** Repeat the coupled calculation with smaller cells, suitable time steps, consistent initial phase data, and compaction-regularization sensitivity. Compare delivery times, front thickness, and the dilation budget. First-order upwind numerical porosity tails are already demonstrated in a separate control and may activate permeability. The existing frozen-flow epsilon sweep is not full-trajectory convergence.
5. **Check pressure with a stated convention.** Verify the correct fluid-minus-ice pressure difference in cells containing both phases and its constitutive relation to C. This pressure is a constitutive diagnostic, not independent evidence by itself. Reconcile diagnostic and flow regularization and address the previously measured conditioning limitations before interpreting magnitudes.

## Why initially dry pore creation remains unproven

For an exactly dry grid cell, every incident harmonic face mobility is zero in the checked implementation. All incident q vanish; the source-free mixture constraint then requires C approximately zero there. The first documented dry-to-wet update is accounted for by transported enthalpy with moving material, including discretization spreading. The solver does not evolve a separate empty-pore, gas, or damage/fracture variable. A claim that overpressure nucleates pores or fractures in initially dry ice needs an explicit, justified dry-to-wet interface/deformation mechanism and a test that separates it from transport error. Adding an arbitrary porosity or permeability floor would not establish that physics.

## Correction to the earlier pressure audit

The manuscript's Equation 8 defines `p_water-p_ice = G*eta/phi^c * C`. Its bulk viscosity is `zeta_phi = G*eta*(1-phi)/phi^c`. Consequently, the absent `(1-phi)` factor in a phase-pressure-difference diagnostic is not automatically an error. The earlier statement implying that it was necessarily missing was too strong and has been corrected in `EUROPA_REGULARIZATION_AUDIT.md`. The confirmed `1e-15` versus `1e-5` denominator mismatch remains. A phase-weighted bulk stress must not be mislabeled as the unweighted phase-pressure difference.

## Saved reproducible evidence

Run `audit_Europa_dilation_evidence` with `model_and_dependencies` on the MATLAB path. It reads existing `Output/Europa_face_flux_proof_20261024/*all_faces.mat` files, without solving or advancing the research simulation. Outputs in `Output/Europa_dilation_evidence_20261024/` include the PNG/SVG figure, selected-cell CSV, summary CSV, JSON, and full cellwise budget MAT files. The production solver SHA-256 remains `D48A4A7BF6636D06B233D16F3AFCCD50E363FE5A24336DE8D04B96828E8E7990`.
