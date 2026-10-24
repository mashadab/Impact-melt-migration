function plot_Europa_saved_times
root=fileparts(mfilename('fullpath'));
run_dir=fullfile(root,'..','Output','Europa_kc_1.850e-08_until_depleted_20261023_195524');
requested=[1 300 600 900 1200];
files=dir(fullfile(run_dir,'states','state_*.mat'));steps=zeros(numel(files),1);
for k=1:numel(files),steps(k)=sscanf(files(k).name,'state_%d.mat');end
chosen=zeros(size(requested));times=chosen;states=cell(size(requested));
for j=1:numel(requested)
 [~,k]=min(abs(steps-requested(j)));chosen(j)=steps(k);
 q=load(fullfile(files(k).folder,files(k).name),'state');states{j}=q.state;times(j)=q.state.time_years;
end
f=figure('Visible','off','Color','w','Position',[40 40 2060 1050]);
annotation(f,'textbox',[.045 .935 .91 .05],'String','Europa: saved temperature and melt evolution', ...
 'EdgeColor','none','FontSize',22,'FontWeight','bold');
annotation(f,'textbox',[.045 .893 .91 .035],'String', ...
 'kc = 1.85e-8 m^2 | cubic permeability | actual saved states; no time interpolation', ...
 'EdgeColor','none','FontSize',12,'Color',[.3 .3 .3]);
for j=1:5
 s=states{j};G=s.Grid.p;[X,Z]=meshgrid(G.xc*s.length_scale_m/1000,G.yc*s.length_scale_m/1000);
 P=reshape(s.phi,G.Ny,G.Nx);T=reshape(s.temperature_K,G.Ny,G.Nx);
 for row=1:2
  yy=.535;if row==2,yy=.115;end
  ax=axes(f,'Position',[.045+(j-1)*.181 yy .146 .31],'FontSize',10);
  if row==1
   contourf(ax,X,Z,T,linspace(100,273,36),'LineStyle','none');colormap(ax,parula(256));caxis(ax,[100 273]);
   title(ax,sprintf('Step %d | %.4g yr',chosen(j),times(j)),'FontSize',12);
  else
   contourf(ax,X,Z,P,0:.025:1,'LineStyle','none');colormap(ax,turbo(256));caxis(ax,[0 1]);
   title(ax,sprintf('Step %d | %.4g yr',chosen(j),times(j)),'FontSize',12);
  end
  hold(ax,'on');if row==1,yline(ax,0,'k--','LineWidth',.8);else,yline(ax,0,'w--','LineWidth',.8);end
  xlim(ax,[0 20]);ylim(ax,[-2 10]);xlabel(ax,'Radius [km]');
  if j==1,ylabel(ax,'Elevation [km]');end
  set(ax,'Layer','top');
  if j==5
   cb=colorbar(ax);set(ax,'Position',[.045+(j-1)*.181 yy .146 .31]);
   cb.Position=[.947 yy .009 .31];
   if row==1,cb.Label.String='Temperature [K]';else,cb.Label.String='Melt volume fraction';end
  end
 end
end
annotation(f,'textbox',[.045 .855 .5 .026],'String','TEMPERATURE','EdgeColor','none','FontSize',13,'FontWeight','bold');
annotation(f,'textbox',[.045 .435 .5 .026],'String','MELT FRACTION','EdgeColor','none','FontSize',13,'FontWeight','bold');
annotation(f,'textbox',[.045 .025 .91 .04],'String', ...
 'Requested steps: 1, 300, 600, 900, 1200. Closest saved: 1, 254, 694, 1000, 1172. Dashed line: z = 0.', ...
 'EdgeColor','none','FontSize',12,'Color',[.3 .3 .3]);
file=fullfile(run_dir,'Europa_saved_time_comparison.png');exportgraphics(f,file,'Resolution',150);close(f);
writetable(table(requested(:),chosen(:),times(:),'VariableNames',{'requested_step','saved_step','time_years'}), ...
 fullfile(run_dir,'saved_time_comparison.csv'));
fprintf('SAVED_TIME_PLOT %s\n',file);disp(table(requested(:),chosen(:),times(:)));
end
