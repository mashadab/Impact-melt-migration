# Why the high-permeability calculation transports melt faster

This analysis uses the corrected shared S3 solver, with the pressure-head reference correction enabled. It is separate from the ongoing 100-year calculation, which remains unchanged. The compared values are kc = 1.85e-8 and 1.85e-16 m².

## Controlled evidence

Four frozen flow solves use identical enthalpy, phase fraction, temperature, geometry, gravity, viscosity law and external boundaries within each pair. The first pair uses the actual initial state. The second pair uses the saved endpoint of the corrected high-kc one-year test. Only kc changes. Pressure and velocity are then recomputed by the coupled solve; pressure is not artificially held fixed. No enthalpy or time advancement occurs in these controls, and no saved state is interpolated.

The later low-kc control is **not** a low-kc simulation evolved to one year. It is the high-kc one-year shape re-solved at low permeability to isolate the instantaneous effect of kc.

At the initially dry interface, x = 10.1 km, z = 4 km:

| Quantity | High kc | Low kc |
| --- | ---: | ---: |
| Downward solid velocity [m/year] | 57.9197487 | 58.1650819 |
| Relative Darcy flux across that face | 0 | 0 |
| Carried-liquid Q across the whole z = 4 km plane [m³/year per metre depth] | 433233.226 | 432693.092 |

The initial bulk speeds are essentially the same; the selected high-kc speed is actually slightly smaller. Therefore the statement that permeability simply multiplies the initial bulk advection speed is contradicted by this test.

On the identical one-year shape, integrated fluxes across z = 4 km are:

| Downward Q [m³/year per metre out-of-plane depth] | High kc | Low kc |
| --- | ---: | ---: |
| Carried with solid, phi_upwind v_s | -17941467.079 | +406986.862 |
| Relative Darcy | +21887463.382 | +0.351411 |
| Net liquid transfer | +3945996.303 | +406987.213 |

The high-kc net downward transfer is **9.6956 times** the low-kc value at this same frozen state. The high-kc carried-liquid contribution is upward; it partly cancels downward Darcy transport. The low-kc transfer is almost entirely carried with the ice. Neither maximum formal solid velocity nor Darcy flux alone measures delivered melt.

Over already partially molten cells, defined here by 1e-4 <= phi <= 0.9, the largest positive dilation contribution `(1-phi)*div(v_s)` is 11.21867/year at high kc and 2.89501e-7/year at low kc. These maxima may occur in different cells. They are local instantaneous rates, not net liquid production or annual extrapolations. The positive-volume integrals are 4.20297e6 and 0.0803094 m³/year per metre depth; these positive-only integrals also are not net production.

## Mechanism in the implemented equations

The actual volume flux is `F_liquid = phi_upwind*v_s + q`. Harmonic face permeability controls only the relative term, `q = -(k_face/mu_water)*grad(P_head)`, with `k_face = kc*harmonic(phi_left^3,phi_right^3)`.

Larger kc increases hydraulic mobility in already wet material. The pressure adjusts in the coupled momentum/mass solve, so q and migration speed do not simply increase by the factor 1e8 in kc. This is why a fixed-pressure-gradient scaling alone cannot predict the run-speed ratio.

The source-free mixture constraint is `div(v_s + q) = 0`, hence `div(v_s) = -div(q)`. Relative liquid convergence permits expansion of the solid framework, while relative divergence permits compaction. For constant solid density and negligible phase change, following the solid gives `D_s(phi)/Dt = (1-phi)*div(v_s)`. These are the incompressible, no-source limits of the [ASPECT melt-transport equations](https://aspect-documentation.readthedocs.io/en/stable/user/methods/melt-transport.html).

Porosity changes then affect permeability through phi³ and affect viscosity through the existing melt-softening law. The solid and liquid fields can consequently reorganize as the calculation evolves. The supported mechanism is **permeability-enhanced liquid segregation coupled to viscous compaction and dilation**. This control changes the coupled flow response; it does not independently assign a fraction of the speed-up to dilation alone.

At an exactly dry harmonic face, k_face and q remain zero in both cases. The initially moving material changes which material occupies a fixed grid cell. First-order upwind front spreading can also supply positive phi. Once both sides are wet, the relative-flow path becomes active. These statements do not establish spontaneous pore nucleation or fracture in initially dry ice.

## Limits and reproducibility

This comparison isolates a mechanism in the code. It is not a completion-time ratio between two evolved centered-water runs, and it does not establish a spatially converged physical invasion speed. The previously identified first-order front spreading, pure-liquid constitutive limit, and conditioning issues still require separate checks for physical interpretation. Very small algebraic residuals alone do not establish pressure accuracy in an ill-conditioned system.

The reproducible audit is `model_and_dependencies/audit_centered_water_permeability.m`; the plotting script is `model_and_dependencies/plot_centered_water_permeability_proof.m`. Output is `Output/centered_water_permeability_proof_20261024_215923/`, including four full face/cell MAT records, `matched_flow_comparison.csv`, `permeability_proof.json`, and PNG/SVG figures. The original corrected solver text and the temporary frozen driver are under `source/`. The parent solver SHA-256 is `16dcab8b484d6751dfdb263fccd546a5c72bc40d03519e8d6eab2ed4bcc7f667`.
