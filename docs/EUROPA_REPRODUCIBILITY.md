# Independent Europa comparison, 23 October 2026

`verify_Europa_independent_replica.m` launched a separate MATLAB R2022b process
using `darcy_stokes_2D_cases.m` from `model_and_dependencies/`. It copied the
long-run options and changed only the output directory and the 100-step limit.
Both processes used `kc = 1.85e-8 m^2` and permeability exponent `nn = 3`.

The replica completed 100 iterations at 0.43466218250879946 simulated years.
All 21 saved state structs compared equal with MATLAB `isequaln`, at iterations
0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 25, 41, 45, 50, 58, 81, 82, 99, and 100.
The maximum absolute differences in temperature, melt fraction, enthalpy,
solid and fluid velocities, Darcy flux, pressure-head potential, fluid pressure,
overpressure, and recorded times were all zero. Melt-budget and diagnostic
histories through iteration 100 also compared equal with `isequaln`.

The raw report is retained locally in
`Output/Europa_independent_replica_100steps_20261023_215932/comparison_report.json`.
Its reference was
`Output/Europa_kc_1.850e-08_until_depleted_20261023_195524/`.
The comparison script expects those local reference outputs; they are not
included in Git. The solver SHA-256 at verification and at commit preparation
was `D48A4A7BF6636D06B233D16F3AFCCD50E363FE5A24336DE8D04B96828E8E7990`,
matching the source archive saved when the long run started. Git may normalize
line endings, so this hash describes the local file bytes used for the run.

This verifies reproducibility for the compared interval. It does not establish
physical correctness or agreement throughout the full long simulation.

An unresolved initial phase-consistency issue also remains: enthalpy phase
recovery changes shell melt from about 31.7803512837 to 31.4130660809 km^3 at
zero elapsed time. The current signed net-refreezing diagnostic includes that
approximately 0.3672852028 km^3 initialization adjustment. It has not yet been
separated from time-evolved refreezing in the solver or the running simulation.
