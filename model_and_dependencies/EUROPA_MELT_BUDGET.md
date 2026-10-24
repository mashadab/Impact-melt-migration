# Europa melt inventory, delivery, and net refreezing

The initial lower region z<0 now has phi=0 and T=273 K, as requested. The
shared S3 flow, pressure, timestep and enthalpy equations are unchanged.
The ocean/interface delivery plane is exactly z=0. The external bottom
remains impermeable at z=-2 km for impact key 03321.

## Saved outputs

`result.melt_budget` and `melt_budget.csv` contain an initial row and every
completed step, with volumes in liquid-water-equivalent m^3. Divide by 1e9
for km^3. Regions are whole domain, shell (z>=0), and lower/ocean region (z<0).

- `melt_*_m3`: current integral of phi times actual cylindrical cell volume.
- `delivered_net_m3`: cumulative downward liquid-volume transfer across z=0,
  subtracting upward return flow, following the user's selected definition.
- `refrozen_net_*_m3`: net phase conversion, positive for net freezing and
  negative for net melt production. These are signed values, not clipped.

The liquid-volume flux is `phi*v_s + q_r`. The solid contribution uses the
existing Godunov/upwind operator and the Darcy contribution uses the same qr
as the head-based flow solve. Fluxes are evaluated before the enthalpy step;
new inventories are evaluated after phase recovery. The existing annular
face areas and cell volumes supply cylindrical weighting. No velocity or
enthalpy state is changed by these diagnostics.

Let V_s, V_o denote liquid volume in shell and lower region, and D the
cumulative net downward delivery across z=0. With closed outer material walls:

    net_refrozen_shell = V_s(0) - V_s(t) - D(t)
    net_refrozen_ocean = V_o(0) - V_o(t) + D(t)
    net_refrozen_domain = V_domain(0) - V_domain(t)

This separates transport from net phase change. Pure delivery reduces shell
melt and increases lower-region melt without being counted as freezing.
A downward crossing followed by equal upward return contributes zero net
delivery. New melting offsets freezing in the net-refrozen quantity. It does
not track cumulative gross freeze/remelt cycles or uniquely label impact-origin
water; those require additional diagnostics or provenance tracers.

The Europa legacy `phiDrain1Vec` and `phiDrain2Vec` both now refer to this one
z=0 net-delivery integral, replacing the previous two upward-offset planes.
Europa legacy `netMelt`/`phiFracRem` now refer to melt remaining anywhere in
z>=0, normalized using the actual initialized shell melt. The wave case keeps
its original diagnostic block. The new authoritative budget is saved in the
result struct and CSV even when legacy plotting/tracers are disabled.

## Verification

`verify_Europa_melt_budget` tests synthetic cylindrical volume, pure transport,
return flow, freezing and new melting. It then compares three full-grid steps
against the corrected Europa result with the same zero-melt, 273 K lower-region
initial state, and renders the revised t=0 state with no advancement for that
figure. A three-step comparison is setup/diagnostic verification, not long-term
physical validation.
