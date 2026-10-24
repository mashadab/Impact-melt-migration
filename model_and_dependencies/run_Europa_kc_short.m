function result = run_Europa_kc_short(kc,max_steps)
% Short Europa trial; uses the shared S3-derived solver without changing it.
if nargin<1,kc=1.85e-16;end
if nargin<2,max_steps=3;end
root=fileparts(mfilename('fullpath'));addpath(root);
out=fullfile(root,'..','Output',sprintf('Europa_kc_%0.3e_%dsteps_%s',kc,max_steps,datestr(now,'yyyymmdd_HHMMSS')));
options=struct('kc',kc,'max_steps',max_steps,'snapshot_steps',[0 1 max_steps], ...
 'correct_head_reference',true,'use_actual_conductivity_timestep',true,'output_dir',out);
result=run_darcy_stokes_case('impact_melt_europa',options);
r=result;
assert(strcmp(r.status,'completed') && r.completed_steps==max_steps);
assert(r.kc==kc && all(isfinite(r.final_state.H)));
assert(r.max_base_solid_flux==0 && r.max_base_darcy_flux==0);
assert(min(r.final_state.phi)>=-1e-12 && max(r.final_state.phi)<=1+1e-12);
B=r.melt_budget;
summary=struct('kc_m2',kc,'steps',r.completed_steps,'time_years',r.time_years(end), ...
 'initial_melt_km3',B.initial_volume_m3(1)/1e9,'remaining_shell_melt_km3',B.liquid_volume_m3(end,2)/1e9, ...
 'remaining_lower_region_melt_km3',B.liquid_volume_m3(end,3)/1e9, ...
 'net_delivered_m3',B.delivered_net_m3(end),'net_refrozen_domain_km3',B.refrozen_net_m3(end,1)/1e9, ...
 'T_min_K',min(r.full_T_K(:,end)),'T_max_K',max(r.full_T_K(:,end)), ...
 'base_solid_flux',r.max_base_solid_flux,'base_darcy_flux',r.max_base_darcy_flux,'output_dir',out);
fid=fopen(fullfile(out,'summary.json'),'w');fprintf(fid,'%s',jsonencode(summary));fclose(fid);
nx=r.Grid.p.Nx;ny=r.Grid.p.Ny;x=r.Grid.p.xc*r.length_scale_m/1000;z=r.Grid.p.yc*r.length_scale_m/1000;
fields={reshape(r.full_T_K(:,1),ny,nx),reshape(r.full_T_K(:,end),ny,nx), ...
 reshape(r.full_phi(:,1),ny,nx),reshape(r.full_phi(:,end),ny,nx)};
f=figure('Visible','off','Color','w','Position',[60 60 1380 1000]);
tl=tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
names={'Initial temperature','Final temperature','Initial melt fraction','Final melt fraction'};
for j=1:4
 ax=nexttile(tl);imagesc(ax,x,z,fields{j});set(ax,'YDir','normal','FontSize',11);
 xlabel(ax,'Radius [km]');ylabel(ax,'Elevation [km]');title(ax,names{j},'FontSize',14);
 hold(ax,'on');yline(ax,0,'w--','LineWidth',1.2);yline(ax,-2,'k-','LineWidth',2);
 cb=colorbar(ax);
 if j<=2,caxis(ax,[100 max(273,max(r.full_T_K(:)))]);colormap(ax,parula(256));cb.Label.String='K';
 else,caxis(ax,[0 1]);colormap(ax,turbo(256));cb.Label.String='Melt volume fraction';end
end
title(tl,sprintf('Europa | kc = %.3g m^2 | %d steps | %.5g years',kc,max_steps,r.time_years(end)),'FontSize',19);
xlabel(tl,'Dashed line: net-delivery plane z = 0. Bottom: impermeable. Lower region initially phi = 0, T = 273 K.','FontSize',11);
exportgraphics(f,fullfile(out,'Europa_short_results.png'),'Resolution',150);close(f);
fprintf('EUROPA_SHORT_COMPLETE %s\n',jsonencode(summary));
end
