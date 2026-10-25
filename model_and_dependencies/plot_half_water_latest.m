function summary=plot_half_water_latest(output_dir)
% Read-only figure from the latest complete saved checkpoint; no interpolation.
if nargin<1
 root=fileparts(fileparts(mfilename('fullpath')));
 output_dir=strtrim(fileread(fullfile(root,'tmp','half_water_1yr_output.txt')));
end
files=dir(fullfile(output_dir,'states','state_*.mat'));
assert(~isempty(files),'No full checkpoint is available yet.');
[~,order]=sort({files.name});files=files(order);
ok=false;
for j=numel(files):-1:1
 try
  loaded=load(fullfile(output_dir,'states',files(j).name),'checkpoint');
  a=loaded.checkpoint;assert(isfield(a,'phi'));ok=true;break
 catch
  % A running simulation may still be writing its newest file.
 end
end
assert(ok,'No readable checkpoint is available.');
loaded=load(fullfile(output_dir,'initial_state.mat'),'initial_state');initial=loaded.initial_state;
G=a.Grid.p;d=a.d_m;nx=G.Nx;ny=G.Ny;
x=G.xc*d/1000;z=G.yc*d/1000;zf=G.yf*d/1000;
phi=reshape(a.phi,ny,nx);T=reshape(a.T_dimensionless*173+100,ny,nx);
phi0=reshape(initial.phi,ny,nx);T0=reshape(initial.T_dimensionless*173+100,ny,nx);
[~,Z]=meshgrid(x,z);lower=Z<4;
cols=[floor((nx+1)/2) ceil((nx+1)/2)];
profile=mean(phi(:,cols),2);profile0=mean(phi0(:,cols),2);
temperature=mean(T(:,cols),2);temperature0=mean(T0(:,cols),2);
summary=struct('checkpoint_file',files(j).name,'completed_steps',a.completed_steps, ...
 'checkpoint_time_years',a.time_years,'flow_time_years',a.flow_time_years, ...
 'max_phi_initial_lower_half',max(phi(lower)),'temperature_range_K',[min(T(:)) max(T(:))], ...
 'max_abs_temperature_change_K',max(abs(T(:)-T0(:))), ...
 'max_abs_phi_change',max(abs(phi(:)-phi0(:))), ...
 'relative_enthalpy_error',(sum(a.H.*G.V)-sum(initial.H.*G.V))/sum(initial.H.*G.V), ...
 'max_abs_solid_speed_m_per_year',max(abs(a.solid_velocity_m_s))*3.154e7, ...
 'max_abs_relative_Darcy_m_per_year',max(abs(a.darcy_flux_m_s))*3.154e7);
if isfile(fullfile(output_dir,'progress.json'))
 summary.live_progress_when_read=jsondecode(fileread(fullfile(output_dir,'progress.json')));
end
out=fullfile(output_dir,'figures');if ~isfolder(out),mkdir(out);end
f=figure('Visible','off','Color','w','Position',[40 40 1450 920]);
tl=tiledlayout(f,2,2,'Padding','compact','TileSpacing','compact');
ax=nexttile(tl);imagesc(ax,x,z,phi);set(ax,'YDir','normal');
colormap(ax,parula);clim(ax,[0 1]);colorbar(ax);yline(ax,4,'w--','LineWidth',1.2);
xlabel(ax,'x [km]');ylabel(ax,'z [km]');title(ax,'Liquid fraction');
ax=nexttile(tl);imagesc(ax,x,z,T);set(ax,'YDir','normal');
colormap(ax,parula);clim(ax,[272.99 273.01]);colorbar(ax);yline(ax,4,'w--','LineWidth',1.2);
xlabel(ax,'x [km]');ylabel(ax,'z [km]');title(ax,'Temperature [K]');
ax=nexttile(tl);hold(ax,'on');
zstep=reshape([zf(1:end-1)';zf(2:end)'],[],1);
plot(ax,repelem(profile0,2),zstep,'k-','LineWidth',2.5);
plot(ax,repelem(profile,2),zstep,'--','Color',[.85 .3 .12],'LineWidth',1.8);
xlabel(ax,'Liquid fraction');ylabel(ax,'z [km]');xlim(ax,[-.05 1.05]);ylim(ax,[-2 10]);grid(ax,'on');
title(ax,'Middle profile: initial and latest checkpoint');
legend(ax,{'Initial','Latest'},'Location','southeast');
ax=nexttile(tl);hold(ax,'on');
plot(ax,repelem(temperature0,2),zstep,'k-','LineWidth',2.5);
plot(ax,repelem(temperature,2),zstep,'--','Color',[.85 .3 .12],'LineWidth',1.8);
xlabel(ax,'Temperature [K]');ylabel(ax,'z [km]');xlim(ax,[272.99 273.01]);ylim(ax,[-2 10]);grid(ax,'on');
title(ax,'Middle temperature profile');
legend(ax,{'Initial','Latest'},'Location','southeast');
text(ax,273,8.8,sprintf('Whole-domain max change: %.2g K',summary.max_abs_temperature_change_K), ...
 'HorizontalAlignment','center','FontSize',11);
set(findall(f,'Type','axes'),'FontName','Arial','FontSize',12);
title(tl,sprintf('Half water over ice | kc = 1.85e-8 m^2 | saved step %d, t = %.6f years', ...
 a.completed_steps,a.time_years),'FontName','Arial','FontSize',18,'Interpreter','none');
xlabel(tl,sprintf(['Maximum liquid fraction below z = 4 km: %.3g | sealed and insulated boundaries.\n' ...
 'Actual saved cell values; temperature color scale is fixed; no time or state interpolation.'], ...
 summary.max_phi_initial_lower_half),'FontName','Arial','FontSize',11,'Interpreter','none');
set(f,'PaperPositionMode','auto');
name=sprintf('latest_step_%08d',a.completed_steps);
print(f,fullfile(out,[name '.png']),'-dpng','-r140');close(f);
summary.figure=fullfile(out,[name '.png']);
fid=fopen(fullfile(out,[name '_summary.json']),'w');fprintf(fid,'%s',jsonencode(summary));fclose(fid);
fprintf('LATEST_HALF_WATER %s\n',jsonencode(summary));
end
