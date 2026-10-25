function plot_Europa_latest_results(run_dir)
% Read final state after completion, otherwise matched checkpoint/CSV rows.
if nargin<1
 root=fileparts(mfilename('fullpath'));
 run_dir=fullfile(root,'..','Output','Europa_kc_1.850e-08_until_depleted_20261023_195524');
end
for attempt=1:5
 try
  if isfile(fullfile(run_dir,'COMPLETE.txt'))
   summary=jsondecode(fileread(fullfile(run_dir,'summary.json')));
   saved=load(fullfile(run_dir,'states',sprintf('state_%08d.mat',summary.steps)),'state');
   s=saved.state;
   c=struct('T',(s.temperature_K-100)/173,'phi',s.phi,'Grid',s.Grid, ...
    'd',s.length_scale_m,'tTot',s.time_years,'i',s.step,'kc_m2',s.kc_m2);
  else
   c=load(fullfile(run_dir,'checkpoint.mat'),'T','phi','Grid','d','tTot','i','options');
   c.kc_m2=c.options.kc;
  end
  b=readtable(fullfile(run_dir,'melt_budget.csv'));
  b=b(b.time_years<=c.tTot+1e-8,:);
  assert(~isempty(b) && abs(b.time_years(end)-c.tTot)<1e-8,'Budget/checkpoint synchronization pending');
  break;
 catch err
  if attempt==5,rethrow(err);end;pause(1);
 end
end
G=c.Grid.p;x=G.xc*c.d/1000;z=G.yc*c.d/1000;
T=reshape(c.T*173+100,G.Ny,G.Nx);P=reshape(c.phi,G.Ny,G.Nx);
f=figure('Visible','off','Color','w','Position',[50 50 1520 1120]);
tl=tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
ax=nexttile(tl);imagesc(ax,x,z,T);set(ax,'YDir','normal');
colormap(ax,parula(256));caxis(ax,[100 273]);cb=colorbar(ax);cb.Label.String='Temperature [K]';
title(ax,'Temperature');yline(ax,0,'k--','LineWidth',1.2);
ax2=nexttile(tl);imagesc(ax2,x,z,P);set(ax2,'YDir','normal');
colormap(ax2,turbo(256));caxis(ax2,[0 1]);cb=colorbar(ax2);cb.Label.String='Melt volume fraction';
title(ax2,'Melt fraction');yline(ax2,0,'w--','LineWidth',1.2);
for a=[ax ax2]
 xlabel(a,'Radius [km]');ylabel(a,'Elevation [km]');xlim(a,[0 20]);ylim(a,[-2 10]);set(a,'Layer','top','FontSize',11);
end
ax3=nexttile(tl);hold(ax3,'on');
plot(ax3,b.time_years,b.melt_shell_m3/1e9,'Color',[.02 .44 .49],'LineWidth',2);
yline(ax3,b.melt_shell_m3(1)/1e9,'--','Initial','Color',[.5 .5 .5]);
yline(ax3,.005*b.melt_shell_m3(1)/1e9,'--','Stopping threshold','Color',[.75 .2 .1]);
plot(ax3,c.tTot,b.melt_shell_m3(end)/1e9,'o','MarkerFaceColor',[.02 .44 .49],'MarkerEdgeColor','w','MarkerSize',7);
xlabel(ax3,'Time [years]');ylabel(ax3,'Melt remaining above z = 0 [km^3]');
title(ax3,'Melt remaining in the shell');ylim(ax3,[0 b.melt_shell_m3(1)/1e9*1.07]);grid(ax3,'on');box(ax3,'off');
ax4=nexttile(tl);hold(ax4,'on');
plot(ax4,b.time_years,b.delivered_net_m3/1e9,'Color',[.12 .34 .72],'LineWidth',2);
plot(ax4,b.time_years,b.refrozen_net_shell_m3/1e9,'Color',[.83 .37 .08],'LineWidth',2);
xlabel(ax4,'Time [years]');ylabel(ax4,'Cumulative net volume [km^3]');
title(ax4,'Net delivery and net refreezing');legend(ax4,{'Delivered across z = 0','Refrozen in shell (net)'},'Location','northwest','Box','off');grid(ax4,'on');box(ax4,'off');
for a=[ax3 ax4],set(a,'FontSize',11);xlim(a,[0 c.tTot]);end
title(tl,sprintf('Europa | %.5g simulated years | iteration %d | kc = %.3g m^2 | cubic permeability',c.tTot,c.i,c.kc_m2),'FontSize',19);
xlabel(tl,'Dashed line: z = 0. Impermeable outer base. Saved grid cells with no interpolation; matched budget history.','FontSize',11);
file=fullfile(run_dir,sprintf('Europa_latest_results_step_%08d.png',c.i));exportgraphics(f,file,'Resolution',150);close(f);
s=struct('step',c.i,'time_years',c.tTot,'kc_m2',c.kc_m2,'data_interpolation',false,'remaining_shell_km3',b.melt_shell_m3(end)/1e9, ...
 'initial_shell_km3',b.melt_shell_m3(1)/1e9,'remaining_fraction',b.melt_shell_m3(end)/b.melt_shell_m3(1), ...
 'delivered_net_km3',b.delivered_net_m3(end)/1e9,'refrozen_net_shell_km3',b.refrozen_net_shell_m3(end)/1e9, ...
 'front_elevation_km',b.front_elevation_km(end),'plot_path',file);
fid=fopen(fullfile(run_dir,'latest_result_plot.json'),'w');fprintf(fid,'%s',jsonencode(s));fclose(fid);
fprintf('LATEST_RESULTS %s\n',jsonencode(s));
end
