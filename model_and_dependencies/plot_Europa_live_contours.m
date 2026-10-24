function plot_Europa_live_contours(run_dir)
% Read saved fields only; the running simulation is not modified.
if nargin<1
 root=fileparts(mfilename('fullpath'));
 run_dir=fullfile(root,'..','Output','Europa_kc_1.850e-08_until_depleted_20261023_195524');
end
for attempt=1:3
 try
  c=load(fullfile(run_dir,'checkpoint.mat'),'T','phi','Grid','d','tTot','i');
  break;
 catch err
  if attempt==3,rethrow(err);end;pause(1);
 end
end
G=c.Grid.p;[X,Z]=meshgrid(G.xc*c.d/1000,G.yc*c.d/1000);
T=reshape(c.T*173+100,G.Ny,G.Nx);P=reshape(c.phi,G.Ny,G.Nx);
f=figure('Visible','off','Color','w','Position',[60 60 1460 810]);
tl=tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
ax=nexttile(tl);contourf(ax,X,Z,T,linspace(100,273,36),'LineStyle','none');
hold(ax,'on');[C,h]=contour(ax,X,Z,T,[150 200 250 270],'Color',[.2 .2 .2],'LineWidth',.45);
clabel(C,h,'FontSize',9,'Color',[.2 .2 .2]);
colormap(ax,parula(256));caxis(ax,[100 273]);cb=colorbar(ax);cb.Label.String='Temperature [K]';
title(ax,'Temperature contours','FontSize',17);yline(ax,0,'k--','LineWidth',1.2);
ax2=nexttile(tl);contourf(ax2,X,Z,P,0:.025:1,'LineStyle','none');hold(ax2,'on');
[C,h]=contour(ax2,X,Z,P,[.001 .01 .1 .5 .9],'Color',[.15 .15 .15],'LineWidth',.5);
clabel(C,h,'FontSize',9,'Color',[.1 .1 .1]);
colormap(ax2,turbo(256));caxis(ax2,[0 1]);cb=colorbar(ax2);cb.Label.String='Melt volume fraction';
title(ax2,'Melt-fraction contours','FontSize',17);yline(ax2,0,'w--','LineWidth',1.2);
for a=[ax ax2]
 xlabel(a,'Radius [km]');ylabel(a,'Elevation [km]');
 set(a,'FontSize',12,'Layer','top');xlim(a,[0 20]);ylim(a,[-2 10]);
end
title(tl,sprintf('Europa | t = %.5g years | iteration %d | kc = 1.85e-8 m^2 | k = kc phi^3',c.tTot,c.i),'FontSize',19);
xlabel(tl,'Dashed line: z = 0 delivery plane. Impermeable base: z = -2 km. Saved-state view; simulation continues.','FontSize',12);
file=fullfile(run_dir,sprintf('Europa_contours_step_%08d.png',c.i));
exportgraphics(f,file,'Resolution',150);close(f);
fid=fopen(fullfile(run_dir,'latest_contour_plot.txt'),'w');fprintf(fid,'%s\n',file);fclose(fid);
fprintf('CONTOURS_SAVED step=%d time=%.12g years\n%s\n',c.i,c.tTot,file);
end
