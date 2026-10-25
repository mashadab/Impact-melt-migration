function results=run_half_water_closed_test(max_steps,kc_values)
% Run a short new initialization of the EXISTING 2D closed-box test.
% The copied solver has only one physical change: initial phi is 0/1, not 0.5.
% Example: run_half_water_closed_test(10,1.85e-8)
if nargin<1,max_steps=10;end
if nargin<2,kc_values=1.85e-8;end
if ischar(max_steps) || isstring(max_steps)
 out=char(max_steps);files=dir(fullfile(out,'noflow_kc_*.mat'));results=cell(numel(files),1);
 for j=1:numel(files)
  loaded=load(fullfile(out,files(j).name),'result');a=loaded.result;
  plot_case(a,out,sprintf('kc_%0.3e',a.kc));results{j}=a;
 end
 return % regenerate saved figures only; no solver execution
end
validateattributes(max_steps,{'numeric'},{'scalar','integer','positive'});
validateattributes(kc_values,{'numeric'},{'vector','nonnegative','finite'});
root=fileparts(mfilename('fullpath'));addpath(root);
out=fullfile(root,'..','Output',['half_water_closed_' datestr(now,'yyyymmdd_HHMMSS')]);
mkdir(out);diary(fullfile(out,'run.log'));cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
copyfile(fullfile(root,'simple_test_1D_half_water_closed.m'),fullfile(out,'solver_used.m.txt'));
options=struct('max_steps',max_steps,'snapshot_steps',unique([0 1 2 5 max_steps]), ...
 'legacy_outputs',false,'evolve_tracers',false,'stop_on_melt_loss',false,'output_dir',out);
results=cell(numel(kc_values),1);
for j=1:numel(kc_values)
 a=simple_test_1D_half_water_closed('03321',1e14,50e3,kc_values(j), ...
  'effe_vel','temprate_homog_column',options);
 assert(strcmp(a.status,'completed') && a.completed_steps==max_steps);
 assert(a.enthalpy_dirichlet_count==0);
 assert(all(a.phi(a.z_km<4,1)==0) && all(a.phi(a.z_km>4,1)==1));
 assert(all(abs(a.T_K(:,1)-273)<1e-12));
 G=a.final_state.Grid;d=1e4;
 assert(strcmp(G.p.geom,'cartesian') && G.p.Nx==100 && G.p.Ny==120);
 [Dp,~,~]=build_ops(G.p);
 Dthermal=3.3/(920*(185+7.037*273));vscale=Dthermal/d;
 vs=a.final_state.v_s_dimensionless*vscale;
 qr=a.final_state.q_r_dimensionless*vscale;
 [X,Y]=meshgrid(G.p.xc*d,G.p.yc*d); %#ok<ASGLU>
 [~,iz]=min(abs(G.p.yf*d-4000));
 faces=G.p.Nfx+(0:G.p.Nx-1)'*(G.p.Ny+1)+iz;
 summary=struct('kc_m2',a.kc,'completed_steps',a.completed_steps, ...
  'endpoint_years',a.time_years(end),'mesh',a.mesh, ...
  'x_domain_km',[G.p.xmin G.p.xmax]*d/1000, ...
  'z_domain_km',[G.p.ymin G.p.ymax]*d/1000,'interface_z_km',4, ...
  'initial_upper_phi',1,'initial_lower_phi',0,'initial_T_K',273, ...
  'final_T_range_K',[min(a.final_state.T_dimensionless)*173+100 max(a.final_state.T_dimensionless)*173+100], ...
  'max_endpoint_phi_in_initial_lower_half',max(a.final_state.phi(Y(:)<4000)), ...
  'max_abs_last_flow_interface_Darcy_m_per_year',max(abs(qr(faces)))*3.154e7, ...
  'max_abs_last_flow_interface_solid_m_per_year',max(abs(vs(faces)))*3.154e7, ...
  'max_abs_last_flow_solid_speed_m_per_year',max(abs(vs))*3.154e7, ...
  'max_abs_last_flow_Darcy_m_per_year',max(abs(qr))*3.154e7, ...
  'max_abs_last_flow_dilation_per_year',max(abs(Dp*vs/d))*3.154e7, ...
  'max_abs_last_flow_mixture_divergence_per_year',max(abs(Dp*(vs+qr)/d))*3.154e7, ...
  'relative_enthalpy_error',a.max_enthalpy_balance_error/abs(a.initial_enthalpy_total), ...
  'max_boundary_solid_m_per_year',a.max_boundary_solid_flux*vscale*3.154e7, ...
  'max_boundary_Darcy_m_per_year',a.max_boundary_darcy_flux*vscale*3.154e7, ...
  'max_boundary_advective_H_dimensionless',a.max_boundary_advective_heat_flux, ...
  'max_boundary_conductive_T_dimensionless',a.max_boundary_conductive_heat_flux, ...
  'flow_timestamp_note','Last flow is evaluated before the final thermodynamic update.', ...
  'solver_note','Unchanged inherited forcing, rheology, operators and time stepping; only initial phi differs.');
 tag=sprintf('kc_%0.3e',a.kc);
 fid=fopen(fullfile(out,[tag '_summary.json']),'w');fprintf(fid,'%s',jsonencode(summary));fclose(fid);
 writetable(array2table(a.history,'VariableNames',a.history_columns),fullfile(out,[tag '_history.csv']));
 plot_case(a,out,tag);
 results{j}=a;
 fprintf('HALF_WATER_RESULT %s\n',jsonencode(summary));
end
fprintf('HALF_WATER_OUTPUT %s\n',out);
end

function plot_case(a,out,tag)
G=a.final_state.Grid;d=1e4;
x=G.p.xc*d/1000;z=G.p.yc*d/1000;zf=G.p.yf*d/1000;
[~,Y]=meshgrid(x,z);
initial=double(Y>4);final=reshape(a.final_state.phi,G.p.Ny,G.p.Nx);
f=figure('Visible','off','Color','w','Position',[40 40 1400 900]);
tl=tiledlayout(f,2,2,'Padding','compact','TileSpacing','compact');
for k=1:2
 ax=nexttile(tl);if k==1,field=initial;else,field=final;end
 imagesc(ax,x,z,field);set(ax,'YDir','normal','FontName','Arial','FontSize',12);
 axis(ax,'tight');clim(ax,[0 1]);colormap(ax,parula);colorbar(ax);
 yline(ax,4,'w--','LineWidth',1.2);
 xlabel(ax,'x [km]');ylabel(ax,'z [km]');
 if k==1,title(ax,'Initial liquid fraction');
 else,title(ax,sprintf('After %d steps: %.6g years',a.completed_steps,a.time_years(end)));end
end
ax=nexttile(tl);hold(ax,'on');
zstep=reshape([zf(1:end-1)';zf(2:end)'],[],1);
plot(ax,repelem(a.phi(:,1),2),zstep,'k-','LineWidth',2.4);
plot(ax,repelem(a.phi(:,end),2),zstep,'--','Color',[.85 .3 .12],'LineWidth',1.8);
set(ax,'FontName','Arial','FontSize',12);grid(ax,'on');xlim(ax,[-.05 1.05]);ylim(ax,[-2 10]);
xlabel(ax,'Liquid fraction');ylabel(ax,'z [km]');
title(ax,'Middle profile (mean of the two central columns)');
legend(ax,{'Initial','Final'},'Location','southeast','Interpreter','none');
ax=nexttile(tl);hold(ax,'on');
plot(ax,repelem(a.T_K(:,1),2),zstep,'k-','LineWidth',2.4);
plot(ax,repelem(a.T_K(:,end),2),zstep,'--','Color',[.85 .3 .12],'LineWidth',1.8);
set(ax,'FontName','Arial','FontSize',12);grid(ax,'on');ylim(ax,[-2 10]);
xlabel(ax,'Temperature [K]');ylabel(ax,'z [km]');title(ax,'Initial and final temperature profiles');
xlim(ax,[272.99 273.01]);
text(ax,273,9,sprintf('Maximum change: %.2g K',max(abs(a.T_K(:)-273))), ...
 'HorizontalAlignment','center','Interpreter','none','FontSize',11);
legend(ax,{'Initial','Final'},'Location','southeast','Interpreter','none');
title(tl,sprintf('Existing Cartesian closed-box test: only initial phi changed | kc = %.3g m^2',a.kc), ...
 'FontSize',18,'FontName','Arial','Interpreter','none');
xlabel(tl,'Original 100 x 120 grid; sealed and insulated boundaries; actual saved profiles, no time interpolation.', ...
 'Interpreter','none','FontSize',11);
set(f,'PaperPositionMode','auto');print(f,fullfile(out,[tag '_initial_and_final.png']),'-dpng','-r130');
close(f);
end
