# How melt enters a cell that initially has zero porosity

The code has two ways to transport liquid: liquid carried with the moving ice, and liquid moving relative to the ice by Darcy flow. Zero harmonic permeability switches off the Darcy contribution. The Stokes part can still move the ice–melt material across the fixed grid.

## 1. The material itself moves

The sketch uses the actual first step of the high-permeability run. The selected cell at r = 100 m, z = 6250 m starts dry at 273 K. Its top face has zero permeability and zero relative Darcy flux. Nevertheless, the computed solid velocity is 13.768 m/year downward. The incoming material contains 25% liquid.

The carried liquid rate is:

`125663.706 m² × 0.25 × 13.768143 m/year = 432538.975 m³/year`.

Over the actual first step this brings in 1417.79 m³ of liquid. The same net volume of ice leaves. Total cell volume does not change. Dividing by the cell volume gives phi = 0.000112824180155035, exactly matching the saved result to numerical precision. There is no conductive or Darcy enthalpy contribution to this cell's first wetting.

![Measured first-step sketch](C:/Users/lenovo/Desktop/Research/Impact-melt-migration/Output/Europa_simple_explanation_20261024/01_dry_cell_sketch.png)

This is movement of the mixture through a fixed grid cell, not evidence that empty pores were created in a stationary parcel of dry ice.

The low-permeability run starts similarly: the same cell receives 422665.903 m³/year with the solid and zero relative Darcy flux. The initial carried rates differ by only 2.34%.

## 2. Once a cell is wet, Darcy flow becomes possible

After that first step the cell has positive liquid fraction. Its permeability is then positive through k = kc * phi^3. At the next flow, its top-face Darcy rate is 0.233949 m³/year in the high-kc case and 2.424e-9 m³/year in the low-kc case. These are separately labelled adaptive steps, not identical elapsed times. Carried flow still dominates at this early location.

Later, the high-kc case develops strong melt–ice segregation. The low-kc case transports liquid predominantly with the deforming aggregate, consistent with viscous foundering. The figure shows actual later flux components. Upward carried liquid partly cancels the large downward Darcy contribution in the high-kc example.

![Two measured transport modes](C:/Users/lenovo/Desktop/Research/Impact-melt-migration/Output/Europa_simple_explanation_20261024/02_two_transport_modes.png)

The example flow states occur at different times, explicitly labelled. Their rates illustrate the transport mechanisms and must not be used as an equal-time velocity ratio. The time to deliver half the initial shell melt compares the same volume milestone: 82.5 years versus 623.5 years.

## 3. The advancing front also has numerical spreading

The first-order transport scheme can smear a moving sharp boundary. A separate control with zero Darcy flow and no melting source develops a positive-porosity tail ahead of the exact translated front. That tail shrinks with finer cells. In the coupled code, a numerically positive phi can activate positive permeability too.

![Numerical spreading control](C:/Users/lenovo/Desktop/Research/Impact-melt-migration/Output/Europa_simple_explanation_20261024/03_numerical_spreading.png)

This control establishes a discretization effect. Its tail lengths are not measured errors in the Europa runs. The physical and numerical contributions to their front propagation remain unseparated without a coupled resolution study.

The supported dry-front mechanism is material advection followed by Darcy redistribution, with a numerical front-spreading contribution. This evidence does not establish spontaneous pore nucleation, fracture formation, or a quantitatively converged physical invasion speed. It does not imply that dilation is absent in already wet material: the subsequent saved-field budget in `EUROPA_DILATION_EVIDENCE.md` measures a strong positive dilation contribution in the high-permeability case.

## Saved sources

Figures, editable SVG copies, and control-test profile CSVs are in `Output/Europa_simple_explanation_20261024/`. The reproducible drawing script is `model_and_dependencies/explain_Europa_migration.m`. Underlying face-by-face numbers and provenance are in `Output/Europa_face_flux_proof_20261024/` and `docs/EUROPA_FACE_FLUX_PROOF.md`.

The research solver and completed simulations were not modified, and no research state or time was interpolated.
