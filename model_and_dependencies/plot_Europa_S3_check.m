function plot_Europa_S3_check
root=fileparts(mfilename('fullpath'));
out=fullfile(root,'..','Output','Europa_S3_smoke_20261023_182849');
s=load(fullfile(out,'noflow_kc_1.850e-08.mat'),'result');r=s.result;
nx=r.Grid.p.Nx;ny=r.Grid.p.Ny;
x=r.Grid.p.xc*r.length_scale_m/1000;z=r.Grid.p.yc*r.length_scale_m/1000;
T0=reshape(r.full_T_K(:,1),ny,nx);T1=reshape(r.full_T_K(:,end),ny,nx);
P0=reshape(r.full_phi(:,1),ny,nx);P1=reshape(r.full_phi(:,end),ny,nx);
f=figure('Visible','off','Color','w','Position',[50 50 1500 920]);
t=tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
fields={T0,T1,T1-T0,P0,P1,P1-P0};
names={'Initial temperature','Final temperature','Temperature change','Initial melt fraction','Final melt fraction','Melt-fraction change'};
for j=1:6
 ax=nexttile(t);imagesc(ax,x,z,fields{j});set(ax,'YDir','normal');
 xlabel(ax,'Radius [km]');ylabel(ax,'Elevation [km]');title(ax,names{j});
 hold(ax,'on');yline(ax,-2,'k-','LineWidth',2);yline(ax,0,'k:');
 if j<=2,caxis(ax,[100 273]);colormap(ax,parula(256));
 elseif j==4 || j==5,caxis(ax,[0 max(P0(:))]);colormap(ax,turbo(256));
 else
  a=max(abs(fields{j}(:)));if a==0,a=eps;end;caxis(ax,[-a a]);
  colormap(ax,interp1([1 129 257],[.1 .3 .7;1 1 1;.8 .15 .1],1:257));
 end
 cb=colorbar(ax);if j<=3,cb.Label.String='K';else,cb.Label.String='Volume fraction';end
end
title(t,sprintf('Europa: S3 cylindrical solver | %d steps | %.5g years (%.3g days)',r.completed_steps,r.time_years(end),r.time_years(end)*365.25),'FontSize',18);
xlabel(t,sprintf('Bottom line: impermeable base at -2 km. Dotted line: internal z=0. Max basal Darcy flux = %.2g; advective heat flux = %.2g (dimensionless).',r.max_base_darcy_flux,r.max_base_advective_heat_flux));
exportgraphics(f,fullfile(out,'Europa_S3_results.png'),'Resolution',150);close(f);
fid=fopen(fullfile(out,'plot_summary.txt'),'w');
fprintf(fid,'Time %.12g years / %.12g days\nTemperature change [%.12g %.12g] K\nMelt change [%.12g %.12g]\nBasal solid flux %.12g\nBasal Darcy flux %.12g\nBasal advective heat %.12g\n',r.time_years(end),r.time_years(end)*365.25,min(T1(:)-T0(:)),max(T1(:)-T0(:)),min(P1(:)-P0(:)),max(P1(:)-P0(:)),r.max_base_solid_flux,r.max_base_darcy_flux,r.max_base_advective_heat_flux);fclose(fid);
fprintf('PLOT_SAVED %s\n',fullfile(out,'Europa_S3_results.png'));
type(fullfile(out,'plot_summary.txt'));
end
