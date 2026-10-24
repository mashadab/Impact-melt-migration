function video_path=make_Jake_comparison_video(preview_only)
% Six-panel read-only visualization of saved corrected-run snapshots.
% Top: analytic, numerical, difference. Bottom: centerline, peak, temperature.
if nargin<1,preview_only=false;end
root=fileparts(mfilename('fullpath'));
source=fullfile(root,'..','Output','Jake_2D_minimal_800_years_actual_kappa_head_reference');
out=fullfile(source,'comparison_video');if ~isfolder(out),mkdir(out);end
for attempt=1:3
 try,s=load(fullfile(source,'noflow_kc_5.600e-11.mat'),'result');break;
 catch err,if attempt==3,rethrow(err);end;pause(2);end
end
r=s.result;t=r.time_years(:);n=numel(t);ny=r.Grid.p.Ny;nx=r.Grid.p.Nx;
x=r.Grid.p.xc*r.length_scale_m/1000;z=r.Grid.p.yc*r.length_scale_m/1000;
[X,Z]=meshgrid(x,z);P0=reshape(r.full_phi(:,1),ny,nx);phi0=0.001;
c=5*r.kc*83*9.81*phi0/0.001*365.25*86400/1000;
zp=zeros(n,1);amp=zeros(n,1);emax=0;
for j=1:n
 P=reshape(r.full_phi(:,j),ny,nx);
 if j==1,[~,ii]=max(P(:));[iz,ix]=ind2sub(size(P),ii);z0=peak(P,iz,ix,z);end
 win=abs(Z-(z0-c*t(j)))<0.8;S=P;S(~win)=-Inf;
 [amp(j),ii]=max(S(:));[iz,ix]=ind2sub(size(P),ii);zp(j)=peak(P,iz,ix,z);
 Q=interp2(x,z,P0,X,Z+c*t(j),'linear',phi0);
 D=P-Q;emax=max(emax,max(abs(D(win))));
end
emax=max(emax,1e-5);
metrics=table(r.steps(:),t,zp,z0-c*t,amp,'VariableNames',{'step','time_years','numerical_peak_km','theory_peak_km','peak_melt_fraction'});
writetable(metrics,fullfile(out,'video_times_and_peaks.csv'));
% Editorial palette and fixed 1920x1080 export canvas.
ink=[.10 .17 .24];muted=[.39 .45 .50];teal=[.02 .47 .52];gold=[.80 .40 .09];
f=figure('Visible','off','Color',[.965 .972 .978],'Position',[40 40 1920 1080], ...
 'PaperUnits','inches','PaperPosition',[0 0 19.2 10.8],'PaperSize',[19.2 10.8]);
cleanupfig=onCleanup(@() close(f));
annotation(f,'textbox',[.05 .922 .72 .055],'String','THE SOLITARY WAVE', ...
 'EdgeColor','none','FontName','Arial','FontSize',26,'FontWeight','bold','Color',ink);
annotation(f,'textbox',[.052 .884 .77 .035],'String', ...
 'Exact supplied realization  |  Analytic translation at 5w0  |  Recovered domain temperature', ...
 'EdgeColor','none','FontName','Arial','FontSize',12,'Color',muted);
timebox=annotation(f,'textbox',[.79 .923 .16 .05],'String','', ...
 'EdgeColor','none','HorizontalAlignment','right','FontName','Arial','FontSize',23,'FontWeight','bold','Color',teal);
statusbox=annotation(f,'textbox',[.79 .887 .16 .03],'String','', ...
 'EdgeColor','none','HorizontalAlignment','right','FontName','Arial','FontSize',11,'Color',muted);
left=[.055 .375 .695];ax=gobjects(1,6);
for k=1:6
 col=mod(k-1,3)+1;yy=.555;if k>3,yy=.135;end
 ax(k)=axes(f,'Position',[left(col) yy .245 .285],'Color','w','FontName','Arial', ...
  'FontSize',11,'XColor',ink,'YColor',ink,'LineWidth',.8,'Box','off','Layer','top');
end
caps={'01  ANALYTIC WAVE','02  NUMERICAL WAVE','03  NUMERICAL - ANALYTIC', ...
 '04  VERTICAL CENTERLINE','05  PEAK ELEVATION','06  DOMAIN TEMPERATURE'};
for k=1:6
 col=mod(k-1,3)+1;yy=.85;if k>3,yy=.43;end
 annotation(f,'textbox',[left(col)-.003 yy .285 .028],'String',caps{k},'EdgeColor','none', ...
 'FontName','Arial','FontSize',12,'FontWeight','bold','Color',ink);
end
seq=turbo(256);
div=interp1([1 129 257],[.11 .31 .54;.97 .97 .94;.83 .25 .13],1:257);
imgs=gobjects(1,3);
for k=1:3
 imgs(k)=imagesc(ax(k),x,z,P0);set(ax(k),'YDir','normal');
 xlim(ax(k),[min(x) max(x)]);xlabel(ax(k),'x [km]');ylabel(ax(k),'Elevation [km]');
 if k<3,colormap(ax(k),seq);caxis(ax(k),[phi0 max(P0(:))]);else,colormap(ax(k),div);caxis(ax(k),[-emax emax]);end
 cb=colorbar(ax(k));cb.Color=muted;cb.FontSize=10;
end
hold(ax(4),'on');cols=[floor((nx+1)/2) ceil((nx+1)/2)];
pnum=plot(ax(4),mean(P0(:,cols),2),z,'Color',teal,'LineWidth',2.4);
pana=plot(ax(4),mean(P0(:,cols),2),z,'--','Color',gold,'LineWidth',2);
xlim(ax(4),[0 max(P0(:))*1.13]);xlabel(ax(4),'Melt volume fraction');ylabel(ax(4),'Elevation [km]');grid(ax(4),'on');
legend(ax(4),[pnum pana],{'Numerical','Analytic'},'Location','southwest','Box','off','FontSize',10);
hold(ax(5),'on');
plot(ax(5),t,z0-c*t,'--','Color',gold,'LineWidth',2);
ptraj=plot(ax(5),t(1),zp(1),'-','Color',teal,'LineWidth',2.4);
pdot=plot(ax(5),t(1),zp(1),'o','Color',teal,'MarkerFaceColor',teal,'MarkerSize',6);
xlim(ax(5),[0 max(t(end),1)]);ylim(ax(5),[min(z0-c*t)-.15 z0+.15]);
xlabel(ax(5),'Time [years]');ylabel(ax(5),'Peak elevation [km]');grid(ax(5),'on');
legend(ax(5),{'Analytic 5w0','Numerical'},'Location','northeast','Box','off','FontSize',10);
itemp=imagesc(ax(6),x,z,reshape(r.full_T_K(:,1),ny,nx));set(ax(6),'YDir','normal');
colormap(ax(6),parula(256));caxis(ax(6),[272.95 273.05]);
xlabel(ax(6),'x [km]');ylabel(ax(6),'Elevation [km]');
cb=colorbar(ax(6));cb.Label.String='Temperature [K]';cb.Color=muted;cb.FontSize=10;
annotation(f,'textbox',[.052 .485 .86 .028],'String', ...
 'Top row: wave-following view, identical spatial limits and melt scales.  Difference is signed.', ...
 'EdgeColor','none','FontName','Arial','FontSize',11,'Color',muted);
footer=annotation(f,'textbox',[.052 .045 .9 .035],'String','', ...
 'EdgeColor','none','FontName','Arial','FontSize',11,'Color',muted);
annotation(f,'line',[.055 .94],[.095 .095],'Color',[.80 .84 .87],'LineWidth',.8);
framefile=fullfile(out,'frame.png');
render(n);print(f,fullfile(out,'preview.png'),'-dpng','-r100');
if preview_only,video_path=fullfile(out,'preview.png');return;end
video_path=fullfile(out,sprintf('Jake_2D_analytic_numeric_temperature_%dyr.mp4',round(t(end))));
w=VideoWriter(video_path,'MPEG-4');w.FrameRate=24;w.Quality=95;open(w);
cleanupvideo=onCleanup(@() close(w));
for j=1:n
 render(j);print(f,framefile,'-dpng','-r100');I=imread(framefile);
 if j<n,repeats=max(1,round((t(j+1)-t(j))/20*w.FrameRate));else,repeats=24;end
 for q=1:repeats,writeVideo(w,I);end
 if j==1 || mod(j,20)==0 || j==n,fprintf('VIDEO frame %d/%d t=%.3f years\n',j,n,t(j));end
end
clear cleanupvideo;
fid=fopen(fullfile(out,'video_info.txt'),'w');
fprintf(fid,'Video: %s\nSaved time range: 0 to %.9g simulated years\nSnapshots: %d\n1920 x 1080, 24 fps; approximately 20 simulated years per playback second.\nTop: wave-following analytic, numerical, signed difference. Bottom: vertical centerline, peak trajectory, full-domain recovered temperature.\nAnalytic reference is the supplied initial wave translated at 5w0. Frames are held between saved snapshots; no simulation data are altered.\n',video_path,t(end),n);fclose(fid);
fprintf('SIX_PANEL_VIDEO_COMPLETE %s\n',video_path);
 function render(j)
  P=reshape(r.full_phi(:,j),ny,nx);Q=interp2(x,z,P0,X,Z+c*t(j),'linear',phi0);
  set(imgs(1),'CData',Q);set(imgs(2),'CData',P);set(imgs(3),'CData',P-Q);
  yl=[z0-c*t(j)-.8 z0-c*t(j)+.8];
  for a=1:4,ylim(ax(a),yl);end
  set(pnum,'XData',mean(P(:,cols),2));set(pana,'XData',mean(Q(:,cols),2));
  set(ptraj,'XData',t(1:j),'YData',zp(1:j));set(pdot,'XData',t(j),'YData',zp(j));
  T=reshape(r.full_T_K(:,j),ny,nx);set(itemp,'CData',T);
  set(timebox,'String',sprintf('%06.1f years',t(j)));
  set(statusbox,'String',sprintf('%.1f%% of 800-year target',100*t(j)/800));
  set(footer,'String',sprintf('w0 = %.4f m/year   |   Wave speed = 5w0 = %.4f m/year   |   Recovered T = %.6f to %.6f K',c*1000/5,c*1000,min(T(:)),max(T(:))));
  drawnow;
 end
end
function zz=peak(P,iz,ix,z)
zz=z(iz);if iz>1 && iz<size(P,1)
 den=P(iz-1,ix)-2*P(iz,ix)+P(iz+1,ix);
 if den<0,dz=.5*(P(iz-1,ix)-P(iz+1,ix))/den;if abs(dz)<=1,zz=zz+dz*(z(2)-z(1));end;end
end
end
