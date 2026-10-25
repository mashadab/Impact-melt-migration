function audit_Europa_dilation_evidence
% Read-only screening of dilation in existing face-flux audit states.
% A budget decomposition, not a Lagrangian or causal validation experiment.
root=fileparts(mfilename('fullpath'));addpath(root);project=fileparts(root);
input=fullfile(project,'Output','Europa_face_flux_proof_20261024');
out=fullfile(project,'Output','Europa_dilation_evidence_20261024');
if ~isfolder(out),mkdir(out);end
files={'high_step_00000001_all_faces.mat','low_step_00000001_all_faces.mat', ...
 'high_later_all_faces.mat','low_later_all_faces.mat','low_main_transfer_later_all_faces.mat'};
keys={'high_initial','low_initial','high_main','low_near_80','low_main'};
result=struct;summary=struct([]);local=struct([]);YEAR=3.154e7;
for k=1:numel(files)
 loaded=load(fullfile(input,files{k}),'diag');a=loaded.diag;
 C=a.Dphysical*a.vs;
 Fadv=flux_upwind(a.vs,a.G)*a.phi0;
 bulk=-a.Dphysical*Fadv+a.phi0.*C;
 dilation=(1-a.phi0).*C;
 dphidt=(a.phi1-a.phi0)/(a.dt_years*YEAR);
 phase=dphidt+a.Dphysical*(Fadv+a.q);
 mass_correction=-a.Dphysical*a.q-C;
 % bulk approximates -v_s.grad(phi), and includes the upwind truncation error.
 % phase is an effective residual of the enthalpy/phase update, not gross melting.
 dry=a.phi0==0;
 wet=a.cell_z_m>=0 & a.phi0>=1e-4 & a.phi0<=.5;
 warm=abs(a.T0_K-273)<1e-9;
 W=reshape(warm,a.G.Ny,a.G.Nx);neighbours=false(size(W));
 neighbours(2:end-1,2:end-1)=W(2:end-1,2:end-1)&W(1:end-2,2:end-1)&W(3:end,2:end-1)&W(2:end-1,1:end-2)&W(2:end-1,3:end);
 valid=wet & neighbours(:) & a.phi1<1 & C>0;
 if ~any(valid),valid=wet&C>0;end
 ids=find(valid);[~,j]=max(dilation(ids));id=ids(j);
 sample=struct('cell_id',id,'r_m',a.cell_r_m(id),'z_m',a.cell_z_m(id), ...
  'phi_before',a.phi0(id),'phi_after',a.phi1(id),'temperature_K',a.T0_K(id), ...
  'all_neighbours_initially_at_273K',neighbours(id), ...
  'solid_divergence_per_year',C(id)*YEAR, ...
  'dilation_porosity_rate_per_year',dilation(id)*YEAR, ...
  'upwind_bulk_transport_rate_per_year',bulk(id)*YEAR, ...
  'effective_enthalpy_phase_residual_per_year',phase(id)*YEAR, ...
  'total_porosity_rate_per_year',dphidt(id)*YEAR, ...
  'bulk_transport_corrected_rate_per_year',(dphidt(id)-bulk(id))*YEAR, ...
  'mixture_constraint_correction_per_year',mass_correction(id)*YEAR);
 sample.net_relative_liquid_inflow_m3_per_year=-(a.Dphysical(id,:)*a.q)*a.volume(id)*YEAR;
 sample.cell_volume_m3=a.volume(id);
 localrow=sample;localrow.case_name=keys{k};localrow.dt_years=a.dt_years;
 localrow.delta_phi_dilation=dilation(id)*a.dt_years*YEAR;
 localrow.delta_phi_bulk=bulk(id)*a.dt_years*YEAR;
 localrow.delta_phi_total=a.phi1(id)-a.phi0(id);
 localrow.dilation_fraction_of_local_increase=localrow.delta_phi_dilation/localrow.delta_phi_total;
 row=struct('case_name',keys{k},'flow_time_years',a.flow_time_years,'dt_years',a.dt_years, ...
  'wet_mush_cells',sum(wet),'wet_mush_cells_with_positive_C',sum(wet&C>0), ...
  'max_positive_C_wet_per_year',max(C(wet))*YEAR, ...
  'max_abs_C_in_exactly_dry_cells_per_year',max(abs(C(dry)))*YEAR, ...
  'actual_endpoint_available',a.actual_endpoint_available);
 result.(keys{k})=struct('summary',row,'sample',sample);
 if k==1,summary=row;local=localrow;else,summary(k)=row;local(k)=localrow;end %#ok<AGROW>
 save(fullfile(out,[keys{k} '_budget_fields.mat']),'C','bulk','dilation','phase','dphidt','mass_correction','wet','warm','sample','row');
 fprintf('DILATION_SCREEN %s %s\n',keys{k},jsonencode(result.(keys{k})));
end
result.scope=['Frozen saved-flow budget screening. bulk contains upwind diffusion; phase is an effective enthalpy residual. ' ...
 'Algebraic budget closure is an identity, not an independent verification. Positive C in wet material does not prove pore creation in initially dry material or causal control of the migration speed.'];
fid=fopen(fullfile(out,'dilation_evidence.json'),'w');fprintf(fid,'%s',jsonencode(result));fclose(fid);
writetable(struct2table(summary),fullfile(out,'dilation_summary.csv'));
writetable(struct2table(local),fullfile(out,'selected_cell_budgets.csv'));
plot_initial_budget(result,out);
fprintf('DILATION_EVIDENCE_SAVED %s\n',out);
end

function plot_initial_budget(r,out)
h=r.high_initial.sample;l=r.low_initial.sample;
assert(h.cell_id==l.cell_id && h.phi_before==l.phi_before);
dt=[r.high_initial.summary.dt_years;r.low_initial.summary.dt_years];
bulk=[h.upwind_bulk_transport_rate_per_year;l.upwind_bulk_transport_rate_per_year].*dt*100;
dilation=[h.dilation_porosity_rate_per_year;l.dilation_porosity_rate_per_year].*dt*100;
total=([h.phi_after;l.phi_after]-h.phi_before)*100;
share=dilation(1)/total(1)*100;
f=figure('Visible','off','Color','w','Position',[30 30 1450 820]);
tl=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
ax=nexttile(tl);b=bar(ax,[bulk dilation],'stacked');
b(1).FaceColor=[.25 .43 .65];b(2).FaceColor=[.86 .40 .14];
set(ax,'XTick',1:2,'XTickLabel',{'kc = 1.85e-8','kc = 1.85e-16'}, ...
 'FontName','Arial','FontSize',13,'Box','off','YGrid','on');
ylabel(ax,'Porosity increase [percentage points]');ylim(ax,[0 4.7]);
legend(ax,b,{'Bulk transport term','Dilation term'},'Location','northwest','Box','off');
for k=1:2
 text(ax,k,total(k)+.16,sprintf('+%.4f points',total(k)),'HorizontalAlignment','center','FontSize',13);
end
title(ax,'First-step porosity budget at the same initially wet cell');
ax=nexttile(tl);axis(ax,'off');
text(ax,.03,.94,sprintf('Cell: r = %.2f km, z = %.2f km',h.r_m/1000,h.z_m/1000), ...
 'FontName','Arial','FontSize',15,'FontWeight','bold');
text(ax,.03,.82,sprintf('Both start at phi = %.2f%%\nand T = 273 K.',h.phi_before*100),'FontSize',14);
text(ax,.03,.64,sprintf('High kc: %.1f%% of this increase\nis assigned to dilation.',share), ...
 'FontSize',16,'FontWeight','bold','Color',[.8 .34 .1]);
text(ax,.03,.47,sprintf('Low kc: dilation contributes %.3g\npercentage points in this first step.',dilation(2)),'FontSize',14);
text(ax,.03,.30,sprintf('Thermal/phase residual\nis negligible here.'),'FontSize',14);
text(ax,.03,.12,sprintf('Evidence for dilation in connected melt.\nDry-pore creation remains unproven.'), ...
 'FontSize',14,'FontWeight','bold');
title(tl,'Dilation in already partially molten material','FontName','Arial','FontSize',21);
xlabel(tl,sprintf(['Actual first saved updates: high dt = %.4f days; low dt = %.4f days. ' ...
 'Dilation = (1 - phi) div(v_s).\nThe bulk term includes upwind truncation error; this is a discrete budget, not an independent Lagrangian or causal validation.'], ...
 dt(1)*3.154e7/86400,dt(2)*3.154e7/86400),'FontSize',11);
set(f,'PaperPositionMode','auto');
print(f,fullfile(out,'initial_wet_cell_dilation_budget.png'),'-dpng','-r150');
print(f,fullfile(out,'initial_wet_cell_dilation_budget.svg'),'-dsvg');close(f);
end
