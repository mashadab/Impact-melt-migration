function show_Europa_initial_state
root=fileparts(mfilename('fullpath'));addpath(root);
out=fullfile(root,'..','Output',['Europa_initial_ocean_' datestr(now,'yyyymmdd_HHMMSS')]);
r=run_darcy_stokes_case('impact_melt_europa',struct('initial_only',true,'output_dir',out));
assert(r.completed_steps==0 && r.time_years==0 && strcmp(r.status,'initialized'));
nx=r.Grid.p.Nx;ny=r.Grid.p.Ny;
x=r.Grid.p.xc*r.length_scale_m/1000;z=r.Grid.p.yc*r.length_scale_m/1000;
[X,Z]=meshgrid(x,z);P=reshape(r.full_phi(:,1),ny,nx);T=reshape(r.full_T_K(:,1),ny,nx);
oc=Z<0;assert(all(P(oc)==0));assert(max(abs(T(oc)-273))<1e-10);
% Verify shell unchanged relative to the pre-ocean-change initialized fields.
s=load(fullfile(root,'..','Output','Europa_S3_pressure_20261023_185230','noflow_kc_1.850e-08.mat'),'result');
Pold=reshape(s.result.full_phi(:,1),ny,nx);Told=reshape(s.result.full_T_K(:,1),ny,nx);
assert(isequal(P(~oc),Pold(~oc)) && isequal(T(~oc),Told(~oc)));
% Existing phase recovery must retain zero melt at the requested temperature.
rhoi=920;rhow=1000;cpi=185+7.037*273;cpw=4186;DT=173;L=334e3;mix=rhow*L/(rhoi*cpi*DT);
[Tr,Pr]=enthMelt(r.final_state.H,mix,@(h)h+1,@(h)h/mix,@(h)h*(rhoi*cpi)/(rhow*cpw)-L/(DT*cpw)+1);
assert(all(Pr(oc(:))==0) && max(abs(Tr(oc(:))*DT+100-273))<1e-10);
f=figure('Visible','off','Color','w','Position',[60 60 1360 820]);
tl=tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
fields={T,P};names={'Temperature [K]','Melt volume fraction'};
for j=1:2
 ax=nexttile(tl);imagesc(ax,x,z,fields{j});set(ax,'YDir','normal','FontSize',12);
 xlabel(ax,'Radius [km]');ylabel(ax,'Elevation [km]');title(ax,names{j},'FontSize',16);
 hold(ax,'on');yline(ax,0,'w--','LineWidth',1.6);yline(ax,-2,'k-','LineWidth',2);
 if j==1,colormap(ax,parula(256));caxis(ax,[100 273]);else,colormap(ax,turbo(256));caxis(ax,[0 1]);end
 cb=colorbar(ax);cb.Label.String=names{j};
 text(ax,10,-1,'Lower region: melt = 0, T = 273 K','HorizontalAlignment','center','FontWeight','bold', ...
  'Color','k','BackgroundColor','w','Margin',4,'FontSize',11);
end
title(tl,'Europa initial state | t = 0 | cylindrical r-z domain','FontSize',20);
xlabel(tl,'Dashed line: internal ocean interface at z = 0. Bottom line: impermeable boundary at z = -2 km.','FontSize',12);
exportgraphics(f,fullfile(out,'Europa_initial_state.png'),'Resolution',150);close(f);
fid=fopen(fullfile(out,'verification.txt'),'w');
fprintf(fid,'No time advancement; 0 steps.\nOcean cells: %d\nOcean melt: [%.12g %.12g]\nOcean temperature: [%.12g %.12g] K\nShell initial fields unchanged: true\nOcean enthalpy/phase round trip passed.\n',nnz(oc),min(P(oc)),max(P(oc)),min(T(oc)),max(T(oc)));fclose(fid);
fprintf('INITIAL_STATE_VERIFIED %s\n',out);type(fullfile(out,'verification.txt'));
end
