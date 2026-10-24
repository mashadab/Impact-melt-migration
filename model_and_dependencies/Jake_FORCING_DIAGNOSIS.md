# Diagnosis of excessive wave speed in the minimal S3 adaptation

The production simulation is stopped. No production equations were changed by this diagnostic.

## Evidence

`diagnose_Jake_wave_forcing.m` imports the exact initial state and assembles the unmodified minimal solver's flow matrix. It solves that SAME matrix with three RHS vectors; permeability, viscosities, grid, constraints and transport-rate measurement are identical. The local initial translation speed is estimated by projecting the melt-fraction time derivative on its vertical gradient, rather than evolving a long simulation.

| Forcing RHS | Initial downward speed (m/year) | Ratio to theory |
| --- | ---: | ---: |
| Current inherited forcing | 87.544 | 12.168 |
| Current, thermal buoyancy omitted | 85.378 | 11.867 |
| Original wave benchmark density-difference forcing | 7.1175 | 0.98928 |

The theoretical speed is approximately 7.19464 m/year for kc=5.6e-11 m2. Dimensional versus nondimensional Darcy mobility differs by less than 4e-16 relatively in all three tests. The linear residuals are below 3e-12. Raw results are under `Output/Jake_forcing_audit`.

## Forcing mismatch

Let C=g*d^3/(eta_0*D_T), Delta_rho=rho_f-rho_i=83 kg/m3. At the initial uniform melting temperature, the current code's three interior terms combine to

    fsVec/C = -rho_i*alpha*DT + Delta_rho*phi_face - rho_f

The original supplied wave solver's RHS is

    fsVec_benchmark/C = -Delta_rho*(1-phi_face)

Here rho_f=1000, rho_i=917, alpha=1.6e-4, DT=173. The current constant contribution corresponds to 1025.38256 kg/m3 rather than 83 kg/m3. Their difference is rho_i*(1+alpha*DT)=942.38256 kg/m3. The large absolute-density contribution remains after changing the code to this head-based wave benchmark, and thermal buoyancy adds a smaller extra contribution despite an initially uniform melting temperature.

A benchmark-specific RHS branch equivalent to the original wave script is:

    fsVec = fs_por - Pi_5*((rho_f-rho_i)/rho_i)*ones(Grid.p.Nfy,1);

This excludes thermal buoyancy for the mechanical S3 forcing while leaving enthalpy/temperature evolution active. It should be introduced explicitly behind a benchmark flag if adopted, retaining the original forcing branch. It has NOT been installed in the production solver.

## What this does and does not establish

This confirms the dominant speed error is the S3 forcing/reference mismatch, rather than the value of kc or its mobility scaling. Changing kc to fit the measured speed would mask the mismatch. The roughly 1.1 percent remaining initial-rate discrepancy is not yet attributed: retained face averaging, compaction regularization, boundaries and derivative estimator differ from the original benchmark. It requires a short corrected trajectory and refinement checks before claiming validation. Long-time agreement is not established by this initial-rate diagnostic.

The supplied `porosity-wave-init/xy_forsolwave.m` reads and plots the CSV realization; it does not generate the solitary-wave solution. The zip contains the same CSV/plotting files, not Jake's original generator. The forcing comparison therefore uses the available original `darcy_stokes_transient_h_form_porosity_wave.m` and its explicit density-difference RHS, and does not claim an audit of absent generator source.

## Ten-year trial completed

The minimal optional correction is now implemented as `options.correct_head_reference` (default false). It adds only `(Pi_5+Ra)` to the inherited momentum RHS, preserving thermal buoyancy variation and the existing head-form matrix/Darcy flux. The fixed original file is unchanged. `JAKE_HEAD_REFERENCE_TRIAL.diff` records this trial's production-code edits.

The isolated trial reached 10 years in 31 steps. Fitted subcell peak speed was 6.93502 m/year versus theory 7.19464 m/year (3.6085 percent slower); the early uncorrected trajectory was 87.0838 m/year. Endpoint displacement was 69.3653 m versus 71.9464 m theoretically, a 2.5811 m difference, smaller than the 9.3541 m vertical grid spacing. This does not eliminate the measured speed error: subcell peak interpolation is still an estimator. Relative L2 difference from the theoretically translated initial wave was 0.0043131. Temperature was recovered at 273 K throughout; maximum relative enthalpy error was 1.21e-14. Long-time and refinement validation remain outstanding. Outputs and plots are in `Output/Jake_head_reference_trial_10yr`. The trial is finished and no 800-year run was restarted.
