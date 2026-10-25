function result=run_centered_blob_closed_test(max_steps,kc,output_dir)
% Short trial of a SEPARATE centered-water initialization of the same solver.
if nargin<1,max_steps=100;end
if nargin<2,kc=1.85e-8;end
if ischar(max_steps) || isstring(max_steps)
 output_dir=char(max_steps);
 saved=dir(fullfile(output_dir,'noflow_kc_*.mat'));assert(numel(saved)==1);
 loaded=load(fullfile(output_dir,saved.name),'result');result=loaded.result;
 loaded=load(fullfile(output_dir,'initial_state.mat'),'initial_state');
 plot_centered_blob(loaded.initial_state,result,output_dir);return
end
root=fileparts(mfilename('fullpath'));addpath(root);
if nargin<3,output_dir=fullfile(root,'..','Output',['centered_blob_closed_' datestr(now,'yyyymmdd_HHMMSS')]);end
if ~isfolder(output_dir),mkdir(output_dir);end
diary(fullfile(output_dir,'run.log'));clean=onCleanup(@()diary('off')); %#ok<NASGU>
copyfile(fullfile(root,'simple_test_1D_centered_blob_closed.m'),fullfile(output_dir,'solver_used.m.txt'));
options=struct('max_steps',max_steps,'snapshot_steps',unique([0 1 10 50 max_steps]), ...
 'legacy_outputs',false,'evolve_tracers',false,'stop_on_melt_loss',false,'output_dir',output_dir);
result=simple_test_1D_centered_blob_closed('03321',1e14,50e3,kc, ...
 'effe_vel','temprate_homog_column',options);
assert(strcmp(result.status,'completed') && result.completed_steps==max_steps);
load(fullfile(output_dir,'initial_state.mat'),'initial_state');
G=initial_state.Grid.p;d=initial_state.d_m;
[X,Y]=meshgrid(G.xc*d,G.yc*d);
expected=double(X>5000 & X<15000 & Y>4000);
assert(isequal(initial_state.phi,expected(:)));
assert(all(initial_state.T_dimensionless*173+100==273));
assert(strcmp(G.geom,'cartesian') && G.Nx==100 && G.Ny==120);
assert(max([result.max_boundary_solid_flux result.max_boundary_darcy_flux ...
 result.max_boundary_advective_heat_flux result.max_boundary_conductive_heat_flux])<1e-12);
assert(result.max_enthalpy_balance_error<1e-8*abs(result.initial_enthalpy_total));
summary=struct('status',result.status,'completed_steps',result.completed_steps, ...
 'time_years',result.time_years(end),'kc',kc,'mesh',result.mesh, ...
 'water_initial_x_km',[5 15],'water_initial_z_km',[4 10], ...
 'initial_phi_values',unique(initial_state.phi)', ...
 'T_min_K',min(result.final_state.T_dimensionless)*173+100, ...
 'T_max_K',max(result.final_state.T_dimensionless)*173+100, ...
 'max_phi_initially_dry',max(result.final_state.phi(expected(:)==0)), ...
 'max_phi_initial_lower_half',max(result.final_state.phi(Y(:)<4000)), ...
 'relative_enthalpy_error',result.max_enthalpy_balance_error/abs(result.initial_enthalpy_total), ...
 'max_boundary_flux_dimensionless',max([result.max_boundary_solid_flux result.max_boundary_darcy_flux ...
 result.max_boundary_advective_heat_flux result.max_boundary_conductive_heat_flux]));
fid=fopen(fullfile(output_dir,'summary.json'),'w');fprintf(fid,'%s',jsonencode(summary));fclose(fid);
writetable(array2table(result.history,'VariableNames',result.history_columns),fullfile(output_dir,'history.csv'));
plot_centered_blob(initial_state,result,output_dir);
fprintf('CENTERED_BLOB_RESULT %s\nCENTERED_BLOB_OUTPUT %s\n',jsonencode(summary),output_dir);
end

function plot_centered_blob(initial,result,out)
G=initial.Grid.p;d=initial.d_m;
x=G.xc*d/1000;z=G.yc*d/1000;
fields={reshape(initial.phi,G.Ny,G.Nx),reshape(result.final_state.phi,G.Ny,G.Nx)};
f=figure('Visible','off','Color','w','Units','inches','Position',[.5 .5 12.8 6.8], ...
 'PaperUnits','inches','PaperPosition',[0 0 12.8 6.8],'PaperSize',[12.8 6.8]);
height=.36*12.8*.6/6.8;positions={[.065 .27 .36 height],[.565 .27 .36 height]};
for k=1:2
 ax=axes('Parent',f,'Position',positions{k});imagesc(ax,x,z,fields{k});set(ax,'YDir','normal','FontName','Arial','FontSize',12);
 axis(ax,'image');clim(ax,[0 1]);colormap(ax,parula);
 if k==2,cb=colorbar(ax);cb.Position=[.94 .27 .012 height];cb.Ticks=[0 .5 1];end
 ax.Position=positions{k};
 xlabel(ax,'x [km]');ylabel(ax,'z [km]');
 if k==1,label='Initial liquid fraction';
 else,label=sprintf('Step %d | %.6g years',result.completed_steps,result.time_years(end));end
 annotation(f,'textbox',[positions{k}(1) .735 .37 .05],'String',label, ...
  'LineStyle','none','FontName','Arial','FontSize',14,'Interpreter','none');
end
annotation(f,'textbox',[.065 .87 .90 .065],'String','Centered upper-half water body', ...
 'LineStyle','none','FontName','Arial','FontSize',19,'Interpreter','none');
annotation(f,'textbox',[.065 .085 .90 .08], ...
 'String',sprintf(['Cartesian 100 x 120 grid | initially 273 K | closed and insulated\n' ...
 'Initial water: x = 5-15 km, z = 4-10 km | maximum phi below z = 4 km: %.4g'], ...
 max(result.final_state.phi(repmat(G.yc*d<4000,G.Nx,1)))), ...
 'LineStyle','none','FontName','Arial','FontSize',10.5,'Interpreter','none');
drawnow;print(f,fullfile(out,'centered_blob_initial_and_trial.png'),'-dpng','-r160');close(f);
end
