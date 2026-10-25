function plot_centered_warm_cold_conduction(output_dir)
% Standard MATLAB plots of actual saved endpoints and heat-budget accounting.
root=fileparts(mfilename('fullpath'));
if nargin<1,output_dir=strtrim(fileread(fullfile(root,'..','tmp','centered_warm_cold_audit_output.txt')));end
report=jsondecode(fileread(fullfile(output_dir,'comparison.json')));
warm=load(report.cases.warm.checkpoint,'checkpoint');warm=warm.checkpoint;
cold=load(report.cases.cold.checkpoint,'checkpoint');cold=cold.checkpoint;
assert(warm.time_years==100 && cold.time_years==100);
G=cold.Grid.p;d=cold.d_m;x=G.xc*d/1000;z=G.yc*d/1000;
profiles=readtable(fullfile(output_dir,'center_profiles_100yr.csv'));
font='Times New Roman';blue=[.12 .43 .70];orange=[.85 .32 .10];gray=[.45 .45 .45];
set(groot,'DefaultFigureVisible','off','DefaultAxesFontName',font,'DefaultTextFontName',font, ...
 'DefaultTextInterpreter','none','DefaultAxesTickLabelInterpreter','none','DefaultLegendInterpreter','none');
f=canvas(12,10);caption(f,[.045 .94 .92 .04],'Centered water body | warm versus cold at 100 years',20,true);
caption(f,[.045 .902 .92 .03],'Warm: 273 K throughout initially | Cold: bottom half initially 253.15 K (-20 C) | kc = 1.85e-8 m2',11,false);
map_positions={[.075 .58 .37 .28],[.565 .58 .37 .28]};
for k=1:2
 ax=axes('Parent',f,'Position',map_positions{k});
 if k==1,phi=warm.phi;name='Warm case at 100 yr';else,phi=cold.phi;name='Cold case at 100 yr';end
 imagesc(ax,x,z,reshape(phi,G.Ny,G.Nx));set(ax,'YDir','normal');axis(ax,'image');clim(ax,[0 1]);hold(ax,'on');
 colormap(ax,[linspace(.935,.137,256)' linspace(.953,.533,256)' linspace(.961,.722,256)']);
 plot(ax,[10.1 10.1],[-2 10],'--','Color',[.1 .1 .1],'LineWidth',.8);
 plot(ax,[0 20],[4 4],':','Color',gray,'LineWidth',.8);
 xlabel(ax,'x [km]');ylabel(ax,'z [km]');title(ax,name,'FontWeight','bold','FontSize',14);
 ax.XTick=[0 5 10 15 20];ax.YTick=[-2 0 4 10];ax.FontSize=12;ax.Position=map_positions{k};
 if k==2
  cb=colorbar(ax);cb.Position=[.951 .58 .012 .28];cb.Ticks=[0 .5 1];cb.Label.String='';cb.FontName=font;cb.FontSize=11;
  caption(f,[.947 .868 .045 .025],'phi',11,false);
  ax.Position=map_positions{k};
 end
end
ax=axes('Parent',f,'Position',[.075 .16 .37 .31]);hold(ax,'on');
[p,zp]=cell_profile(profiles.initial_phi,profiles.z_m/1000);hi=plot(ax,p,zp,'--','Color',gray,'LineWidth',1.1);
[p,zp]=cell_profile(profiles.warm_phi,profiles.z_m/1000);hw=plot(ax,p,zp,'Color',blue,'LineWidth',1.8);
[p,zp]=cell_profile(profiles.cold_phi,profiles.z_m/1000);hc=plot(ax,p,zp,'Color',orange,'LineWidth',1.8);
ylim(ax,[-2 10]);xlim(ax,[-.03 1.04]);ax.XTick=[0 .25 .5 .75 1];ax.YTick=[-2 0 4 10];grid(ax,'on');ax.GridAlpha=.12;ax.FontSize=12;
xlabel(ax,'Liquid fraction');ylabel(ax,'z [km]');title(ax,'Center profile: x = 10.1 km','FontWeight','bold','FontSize',14);
legend(ax,[hw hc hi],{'Warm at 100 yr','Cold at 100 yr','Common initial profile'},'Location','northeast','Box','off','FontSize',10);
ax=axes('Parent',f,'Position',[.565 .16 .37 .31]);hold(ax,'on');
[p,zp]=cell_profile(profiles.cold_initial_T_K,profiles.z_m/1000);hi=plot(ax,p,zp,'--','Color',gray,'LineWidth',1.1);
[p,zp]=cell_profile(profiles.warm_T_K,profiles.z_m/1000);hw=plot(ax,p,zp,'Color',blue,'LineWidth',1.8);
[p,zp]=cell_profile(profiles.cold_T_K,profiles.z_m/1000);hc=plot(ax,p,zp,'Color',orange,'LineWidth',1.8);
ylim(ax,[-2 10]);xlim(ax,[251.5 275]);ax.XTick=[253.15 263.15 273];ax.YTick=[-2 0 4 10];grid(ax,'on');ax.GridAlpha=.12;ax.FontSize=12;
xlabel(ax,'Temperature [K]');ylabel(ax,'z [km]');title(ax,'Center temperature: x = 10.1 km','FontWeight','bold','FontSize',14);
legend(ax,[hw hc hi],{'Warm at 100 yr','Cold at 100 yr','Cold initial profile'},'Location','northwest','Box','off','FontSize',10);
caption(f,[.045 .059 .92 .045],sprintf('Liquid below z = 4 km: warm %.2f; cold %.2f million m3 per m depth. Domain net liquid loss: warm ~0; cold %.2f million m3 per m depth.', ...
 report.cases.warm.liquid_below_z4_m3_per_m_depth/1e6,report.cases.cold.liquid_below_z4_m3_per_m_depth/1e6,report.cases.cold.domain_net_liquid_loss_m3_per_m_depth/1e6),10.5,false);
caption(f,[.045 .019 .92 .03],'Profiles follow actual cells in one center column; no field or time interpolation. Both runs use the same closed S3 solver and material laws.',10,false);
save_vector(f,output_dir,'01_centered_warm_cold_profiles_100yr');

f=canvas(12,6.4);caption(f,[.045 .925 .92 .05],'Conduction has a local effect; advection supplies most net heat',18,true);
caption(f,[.045 .865 .92 .05],sprintf('Cold lower-half heat gain at 100 yr: net advection %.3g J/m; conduction %.3g J/m (%.4f%% of net heat gain).', ...
 report.conduction.net_advected_heat_into_lower_J_per_m_depth,report.conduction.net_conductive_heat_into_lower_J_per_m_depth, ...
 report.conduction.conduction_fraction_of_net_lower_enthalpy_gain*100),11,false);
ax=axes('Parent',f,'Position',[.075 .38 .43 .40]);
Escale=920*(185+7.037*273)*173;
cond=cold.diagnostic.cold_bottom.budget.cumulative_dH_conduction;
imagesc(ax,x,z,reshape(cond,G.Ny,G.Nx)*Escale/1e6);set(ax,'YDir','normal');axis(ax,'image');clim(ax,[-10 10]);
n=128;cmap=[linspace(blue(1),1,n)' linspace(blue(2),1,n)' linspace(blue(3),1,n)'; ...
 linspace(1,orange(1),n)' linspace(1,orange(2),n)' linspace(1,orange(3),n)']; %#ok<NASGU>
colormap(ax,cmap);xlabel(ax,'x [km]');ylabel(ax,'z [km]');title(ax,'Cumulative conductive energy change','FontSize',13,'FontWeight','bold');
ax.FontSize=11;ax.XTick=[0 5 10 15 20];ax.YTick=[-2 0 4 10];
cax=axes('Parent',f,'Position',[.075 .26 .43 .026]);
imagesc(cax,linspace(-10,10,256),[0 1],repmat(linspace(-10,10,256),2,1));
colormap(cax,cmap);clim(cax,[-10 10]);cax.YTick=[];cax.XTick=[-10 -5 0 5 10];cax.FontSize=10;
xlabel(cax,'MJ/m3: blue = net conductive cooling; orange = heating','FontSize',10);
ax=axes('Parent',f,'Position',[.625 .38 .30 .36]);
sample=report.conduction.first_update.center_sample;
vals=[sample.phi_advection_only sample.phi_after]*1e4;
b=bar(ax,[1 2],vals,.55,'FaceColor','flat');b.CData=[blue;orange];
ax.XTick=[1 2];ax.XTickLabel={'Omit conduction','Actual update'};ax.FontSize=10.5;ax.YLim=[0 7];
ylabel(ax,'Liquid fraction (x 10^-4)');title(ax,{'First update at x = 10.1, z = 3.95 km','Initially dry, T = 253.15 K'},'FontWeight','bold','FontSize',12);
for j=1:2,text(ax,j,vals(j)+.15,sprintf('%.3f',vals(j)),'HorizontalAlignment','center','FontName',font,'FontSize',12);end
caption(f,[.61 .77 .33 .06],sprintf('Actual first update ends at %.3f years',report.conduction.first_update.time_years),11,false);
caption(f,[.045 .105 .92 .06],sprintf('Conduction alone in this cell warms it to %.3f K and leaves phi = 0. With advection present, conduction increases the first-step phi by %.1f%% of its final value.', ...
 report.conduction.first_update.center_conduction_only_temperature_K,report.conduction.first_update.center_phi_conduction_fraction*100),10.5,false);
caption(f,[.045 .058 .92 .04],'The omitted-term bars keep the actual flow fixed for one step; they are not separate 100-year simulations. Signed cell contributions can cancel in regional totals.',10,false);
caption(f,[.045 .015 .92 .035],'Inherited conductivity enhancement below z = 200 m remains active in wet cells. The 100 m vertical cells do not fully resolve the ~73 m dry-ice diffusion scale.',10,false);
save_vector(f,output_dir,'02_conduction_role_centered_cold');
fprintf('CENTERED_WARM_COLD_FIGURES %s\n',output_dir);
end

function f=canvas(width,height)
f=figure('Visible','off','Color','w','Units','inches','Position',[.5 .5 width height], ...
 'PaperUnits','inches','PaperPosition',[0 0 width height],'PaperSize',[width height],'Renderer','painters');
end
function caption(f,pos,value,size,bold)
weight='normal';if bold,weight='bold';end
annotation(f,'textbox',pos,'String',value,'LineStyle','none','FontName','Times New Roman', ...
 'FontSize',size,'FontWeight',weight,'Interpreter','none','Color',[.08 .16 .22],'Margin',0);
end
function [v,z]=cell_profile(values,centers)
dz=centers(2)-centers(1);edges=[centers(1)-dz/2;centers+dz/2];
v=repelem(values,2);z=reshape([edges(1:end-1)';edges(2:end)'],[],1);
end
function save_vector(f,folder,stem)
objects=findall(f,'-property','FontName');set(objects,'FontName','Times New Roman');
drawnow;print(f,fullfile(folder,[stem '.pdf']),'-dpdf','-painters');
print(f,fullfile(folder,[stem '.svg']),'-dsvg','-painters');close(f);
end
