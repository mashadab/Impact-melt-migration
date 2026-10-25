function [diagnostic,budget]=centered_cold_bottom_heat_budget(diagnostic,Grid,d,budget)
% Read-only heat/phase accounting of an ACTUAL step of the copied S3 solver.
% Counterfactual fields omit terms from this step using the same frozen flow;
% they are not separately evolved conduction-only/advection-only simulations.
YEAR=3.154e7;DT=173;rho_i=920;rho_w=1000;
c_pi=185+7.037*273;c_pw=4186;latent_J_kg=334e3;
energy_scale=rho_i*c_pi*DT;L=diagnostic.latent_dimensionless;
V=diagnostic.cell_volume_m3_per_m_depth;
[X,Z]=meshgrid(Grid.p.xc*d,Grid.p.yc*d);
lower=Z(:)<(Grid.p.ymin+Grid.p.ymax)*d/2;
dt_s=diagnostic.dt_years*YEAR;
if isempty(budget)
 budget=struct('initial_H',diagnostic.H_before,'initial_phi',diagnostic.phi_before, ...
  'initial_T_K',diagnostic.T_before_K,'lower_mask',lower, ...
  'cumulative_dH_bulk',zeros(size(V)),'cumulative_dH_Darcy',zeros(size(V)), ...
  'cumulative_dH_conduction',zeros(size(V)), ...
  'cumulative_liquid_transport_delta_phi',zeros(size(V)), ...
  'cumulative_effective_phase_delta_phi',zeros(size(V)), ...
  'first_liquid_in_lower_seen',false,'enthalpy_scale_J_m3',energy_scale);
end
budget.cumulative_dH_bulk=budget.cumulative_dH_bulk+diagnostic.dH_bulk;
budget.cumulative_dH_Darcy=budget.cumulative_dH_Darcy+diagnostic.dH_Darcy;
budget.cumulative_dH_conduction=budget.cumulative_dH_conduction+diagnostic.dH_conduction;
transport_delta=(diagnostic.bulk_transport_rate_per_s+diagnostic.dilation_rate_per_s+ ...
 diagnostic.mixture_constraint_correction_per_s)*dt_s;
phase_delta=diagnostic.effective_phase_residual_per_s*dt_s;
budget.cumulative_liquid_transport_delta_phi=budget.cumulative_liquid_transport_delta_phi+transport_delta;
budget.cumulative_effective_phase_delta_phi=budget.cumulative_effective_phase_delta_phi+phase_delta;
Hcond=diagnostic.H_before+diagnostic.dH_conduction;
Hadv=diagnostic.H_before+diagnostic.dH_bulk+diagnostic.dH_Darcy;
[Tcond,phi_cond]=recover(Hcond);[Tadv,phi_adv]=recover(Hadv);
dry=diagnostic.phi_before==0;new_liquid=lower & diagnostic.phi_after>1e-8;
first_liquid=~budget.first_liquid_in_lower_seen && any(new_liquid);
budget.first_liquid_in_lower_seen=budget.first_liquid_in_lower_seen || any(new_liquid);
Hsum=budget.initial_H+budget.cumulative_dH_bulk+budget.cumulative_dH_Darcy+budget.cumulative_dH_conduction;
phi_sum=budget.initial_phi+budget.cumulative_liquid_transport_delta_phi+budget.cumulative_effective_phase_delta_phi;
row=diagnostic.row;
row.lower_T_min_K=min(diagnostic.T_after_K(lower));
row.lower_T_max_K=max(diagnostic.T_after_K(lower));
row.lower_T_mean_K=sum(diagnostic.T_after_K(lower).*V(lower))/sum(V(lower));
row.lower_warmed_over_0p01K_cells=sum(lower & diagnostic.T_after_K>budget.initial_T_K+.01);
row.lower_at_melting_temperature_cells=sum(lower & diagnostic.T_after_K>=273-1e-8);
row.lower_liquid_cells=sum(new_liquid);
row.lower_bulk_heat_cumulative_J_per_m_depth=sum(budget.cumulative_dH_bulk(lower).*V(lower))*energy_scale;
row.lower_Darcy_heat_cumulative_J_per_m_depth=sum(budget.cumulative_dH_Darcy(lower).*V(lower))*energy_scale;
row.lower_conductive_heat_cumulative_J_per_m_depth=sum(budget.cumulative_dH_conduction(lower).*V(lower))*energy_scale;
row.lower_enthalpy_change_J_per_m_depth=sum((diagnostic.H_after(lower)-budget.initial_H(lower)).*V(lower))*energy_scale;
row.lower_cumulative_net_liquid_import_m3_per_m_depth=sum(budget.cumulative_liquid_transport_delta_phi(lower).*V(lower));
row.lower_effective_net_refrozen_m3_per_m_depth=-sum(budget.cumulative_effective_phase_delta_phi(lower).*V(lower));
row.domain_net_liquid_loss_m3_per_m_depth=sum((budget.initial_phi-diagnostic.phi_after).*V);
row.lower_dry_cells_wet_with_conduction_only_this_step=sum(lower & dry & phi_cond>1e-8);
row.lower_dry_cells_wet_with_advection_only_this_step=sum(lower & dry & phi_adv>1e-8);
row.first_liquid_in_lower_this_step=double(first_liquid);
row.cumulative_enthalpy_reconstruction_error=max(abs(diagnostic.H_after-Hsum));
row.cumulative_phi_reconstruction_error=max(abs(diagnostic.phi_after-phi_sum));
[~,sample_id]=min((X(:)-10100).^2+(Z(:)-3950).^2);
row.sample_x_m=X(sample_id);row.sample_z_m=Z(sample_id);
row.sample_T_K=diagnostic.T_after_K(sample_id);row.sample_phi=diagnostic.phi_after(sample_id);
row.sample_H=diagnostic.H_after(sample_id);
row.sample_cumulative_dH_bulk=budget.cumulative_dH_bulk(sample_id);
row.sample_cumulative_dH_Darcy=budget.cumulative_dH_Darcy(sample_id);
row.sample_cumulative_dH_conduction=budget.cumulative_dH_conduction(sample_id);
diagnostic.row=row;
diagnostic.cold_bottom=struct('budget',budget,'first_new_liquid',first_liquid, ...
 'T_conduction_only_this_step_K',Tcond,'phi_conduction_only_this_step',phi_cond, ...
 'T_advection_only_this_step_K',Tadv,'phi_advection_only_this_step',phi_adv, ...
 'interpretation',['Eulerian heat and liquid budgets. Bulk enthalpy transport includes latent heat and upwind mixing. ' ...
 'Effective net refreezing is liquid import minus inventory change, not an independent gross phase-change measurement. ' ...
 'Term-omission fields use one actual frozen step; no trajectories or fields are interpolated.']);
 function [Tk,ph]=recover(H)
  [Tn,ph]=enthMelt(H,L,@(h)h+1,@(h)h/L, ...
   @(h)h*(rho_i*c_pi)/(rho_w*c_pw)-latent_J_kg/(DT*c_pw)+1);
  Tk=Tn*DT+100;
 end
end
