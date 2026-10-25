function facts=make_humanized_water_mechanism_figures(comparison_dir)
% Plain-language scientific diagrams; actual fields, schematic force/flow arrows.
% All text uses Times New Roman. No new flow solve or data interpolation.
root=fileparts(fileparts(mfilename('fullpath')));
if nargin<1,comparison_dir=strtrim(fileread(fullfile(root,'tmp','flat_centered_video_output.txt')));end
config=jsondecode(fileread(fullfile(comparison_dir,'configuration.json')));
comparison=jsondecode(fileread(fullfile(comparison_dir,'video_comparison.json')));
out=fullfile(comparison_dir,'mechanism_figures_times');if ~isfolder(out),mkdir(out);end
assert(any(strcmpi(listfonts,'Times New Roman')),'Times New Roman is not installed.');
loaded=load(fullfile(comparison_dir,'flat_layer_run','flat_result.mat'),'flat');flat=loaded.flat;
files=cellstr(config.centered_files);
loaded=load(files{1},'checkpoint');first=loaded.checkpoint;
loaded=load(files{end},'checkpoint');last=loaded.checkpoint;
G=flat.Grid.p;d=flat.length_scale_m;YEAR=3.154e7;
initial=first.diagnostic.phi_before;final=last.phi;
row=last.diagnostic.row;
[~,iz]=min(abs(G.yf*d-4000));faces=G.Nfx+iz+(0:G.Nx-1)'*(G.Ny+1);
vs=first.solid_velocity_m_s(faces)*YEAR;x=G.xc*d;
assert(all(first.darcy_flux_m_s(faces)==0));
assert(max(vs(x<5000))>0 && max(vs(x>15000))>0);
assert(row.Q_carried_down_m3_per_year_per_m_depth<0 && row.Q_Darcy_down_m3_per_year_per_m_depth>0);
flat_checkpoint=load(fullfile(comparison_dir,'flat_layer_run','states','state_00000001.mat'),'checkpoint');
flat_checkpoint=flat_checkpoint.checkpoint;
facts=struct('font','Times New Roman','data_interpolation',false, ...
 'comparison_time_years',comparison.common_end_time_years, ...
 'flat_max_phi_change',max(abs(flat.final_state.phi-flat.full_phi(:,1))), ...
 'flat_max_ice_speed_m_year',max(abs(flat_checkpoint.solid_velocity_m_s))*YEAR, ...
 'flat_initial_Darcy_Q_across_z4',flat_checkpoint.diagnostic.row.Q_Darcy_down_m3_per_year_per_m_depth, ...
 'centered_first_contact_Darcy_Q',first.diagnostic.row.Q_Darcy_down_m3_per_year_per_m_depth, ...
 'centered_first_contact_carried_Q_m3_year_m_depth',first.diagnostic.row.Q_carried_down_m3_per_year_per_m_depth, ...
 'centered_left_outer_ice_max_up_speed_m_year',max(vs(x<5000)), ...
 'centered_right_outer_ice_max_up_speed_m_year',max(vs(x>15000)), ...
 'centered_final_flow_time_years',last.flow_time_years, ...
 'centered_Q_carried_down_million_m3_year_m_depth',row.Q_carried_down_m3_per_year_per_m_depth/1e6, ...
 'centered_Q_Darcy_down_million_m3_year_m_depth',row.Q_Darcy_down_m3_per_year_per_m_depth/1e6, ...
 'centered_Q_net_down_million_m3_year_m_depth',row.Q_total_down_m3_per_year_per_m_depth/1e6, ...
 'centered_liquid_below_z4_million_m3_m_depth',row.liquid_lower_m3_per_m_depth/1e6, ...
 'arrow_interpretation','Arrows are schematic and show direction, not numerical vector magnitude.', ...
 'rheology_note','Both cases retain the same regularized matrix rheology with 1e9 Pa s minimum shear coefficient.');
ink=[.13 .20 .25];muted=[.36 .40 .43];blue=[.15 .43 .64];orange=[.72 .36 .16];
ice=[.93 .95 .96];water=[.40 .71 .87];green=[.15 .43 .34];
map=[linspace(ice(1),water(1),256)',linspace(ice(2),water(2),256)',linspace(ice(3),water(3),256)'];

f=canvas();
box(f,[.055 .90 .91 .06],'The flat layer: why it stays nearly still',25,ink);
box(f,[.055 .845 .91 .045],'An exactly flat water layer has no difference from one vertical column to the next.',15,muted);
ax=field_axes(f,[.065 .39 .43 .378],flat.full_phi(:,1),G,d,map);
box(f,[.065 .785 .43 .045],'Initial state',17,ink);
text(ax,10,7.4,{'Water','denser'},'FontName','Times New Roman','FontSize',17, ...
 'HorizontalAlignment','center','Color',ink,'Interpreter','none');
text(ax,10,1,{'Ice','lighter'},'FontName','Times New Roman','FontSize',17, ...
 'HorizontalAlignment','center','Color',ink,'Interpreter','none');
arrow(ax,3.5,8.7,0,-2.2,orange);arrow(ax,16.5,6.5,0,2.2,blue);
text(ax,3.5,9.35,'Weight','FontName','Times New Roman','FontSize',13,'Color',orange,'HorizontalAlignment','center');
text(ax,16.5,9.35,'Pressure force','FontName','Times New Roman','FontSize',13,'Color',blue,'HorizontalAlignment','center');
yline(ax,4,'-','Color',ink,'LineWidth',1.2);
text(ax,10,4.55,'No relative Darcy flow at the dry interface', ...
 'FontName','Times New Roman','FontSize',12,'HorizontalAlignment','center','Interpreter','none','Color',ink);
box(f,[.56 .785 .39 .045],'Three parts of the explanation',17,ink);
callout(f,.56,.65,'1  Every column starts alike', ...
 {'There is no lateral density variation.','The exactly symmetric state remains symmetric.'},ink,muted);
callout(f,.56,.50,'2  Pressure balances the weight', ...
 {'The model admits a hydrostatic equilibrium.','Gravity alone does not break the symmetry.'},ink,muted);
callout(f,.56,.35,'3  The first dry face has zero permeability', ...
 {'The harmonic mean is zero at that face.','Relative water flow through it is zero.'},ink,muted);
band(f,[.055 .145 .90 .14]);
box(f,[.075 .235 .85 .035],sprintf('What the actual %.3f-year calculation shows',facts.comparison_time_years),15,ink);
box(f,[.075 .17 .39 .055],sprintf('Largest change in melt fraction: %.2g',facts.flat_max_phi_change),15,ink);
box(f,[.52 .17 .40 .055],sprintf('Largest ice speed: %.2g m/year',facts.flat_max_ice_speed_m_year),15,ink);
box(f,[.055 .075 .91 .045],'This checks a perfectly symmetric equilibrium; it does not test its stability.',12,muted);
box(f,[.055 .025 .91 .04], ...
 'Actual initial field; force arrows are schematic.  Corrected S3, kc = 1.85e-8 m^2, same viscosity floor in both tests.',10,muted);
export_figure(f,out,'01_flat_layer_mechanism');

f=canvas();
box(f,[.055 .90 .91 .06],'The centered body: water has a route downward',25,ink);
box(f,[.055 .845 .91 .045],'Lateral density differences allow circulation; water and the ice framework can then move differently.',14.5,muted);
pos1=[.065 .435 .36 .316];pos2=[.565 .435 .36 .316];
ax1=field_axes(f,pos1,initial,G,d,map);ax2=field_axes(f,pos2,final,G,d,map);
box(f,[.065 .77 .38 .045],'Initially',17,ink);
box(f,[.565 .77 .38 .045],sprintf('After %.3f years',last.time_years),17,ink);
arrow(ax1,10,8.8,0,-2.4,blue);
arrow(ax1,2.3,2,0,3.2,muted);arrow(ax1,17.7,2,0,3.2,muted);
text(ax1,10,5.6,'Water descends','FontName','Times New Roman','FontSize',13, ...
 'HorizontalAlignment','center','Color',ink,'Interpreter','none');
text(ax1,10,0.1,'Ice moves around the sides','FontName','Times New Roman','FontSize',12, ...
 'HorizontalAlignment','center','Color',muted,'Interpreter','none');
rectangle(ax2,'Position',[5 4 10 6],'EdgeColor',muted,'LineStyle','--','LineWidth',1);
text(ax2,10,6.8,'Water','FontName','Times New Roman','FontSize',17, ...
 'HorizontalAlignment','center','Color',ink,'Interpreter','none');
box(f,[.065 .322 .38 .055],{'1  Wet material moves into new grid cells.','At the first dry face, Darcy flow is still zero.'},12.5,ink);
box(f,[.565 .322 .38 .055],{'2  The body deforms and water redistributes.','Dashed outline: the initial water body.'},12.5,ink);
box(f,[.055 .278 .91 .035],sprintf('Two transport contributions across z = 4 km, evaluated at %.3f years',last.flow_time_years),14,ink);
band(f,[.055 .155 .90 .13]);
annotation(f,'arrow',[.09 .09],[.18 .255],'Color',muted,'LineWidth',3,'HeadWidth',10,'HeadLength',10);
annotation(f,'arrow',[.40 .40],[.255 .18],'Color',blue,'LineWidth',3.5,'HeadWidth',11,'HeadLength',11);
annotation(f,'arrow',[.72 .72],[.255 .18],'Color',green,'LineWidth',3,'HeadWidth',10,'HeadLength',10);
box(f,[.115 .175 .25 .09],sprintf('Carried with the framework\n%.2f  (upward)',facts.centered_Q_carried_down_million_m3_year_m_depth),15,muted);
box(f,[.425 .175 .25 .09],sprintf('Relative Darcy flow\n+%.2f  (downward)',facts.centered_Q_Darcy_down_million_m3_year_m_depth),15,blue);
box(f,[.745 .175 .20 .09],sprintf('Net liquid transfer\n+%.2f  (downward)',facts.centered_Q_net_down_million_m3_year_m_depth),15,green);
box(f,[.055 .115 .91 .033],'Rates: million m^3/year per metre of depth; downward is positive. Arrow lengths are schematic.',11,muted);
box(f,[.055 .065 .91 .04],'3  In wet material, converging relative flow permits dilation; diverging flow permits compaction.',13,ink);
box(f,[.055 .018 .91 .04], ...
 'Actual saved fields, no interpolation.  Same viscosity floor; flat case starts with twice the water. Upwind front spreading is also present.',10,muted);
export_figure(f,out,'02_centered_body_mechanism');
fid=fopen(fullfile(out,'mechanism_facts.json'),'w');fprintf(fid,'%s',jsonencode(facts));fclose(fid);
copyfile([mfilename('fullpath') '.m'],fullfile(out,'figure_script_used.m.txt'));
fprintf('HUMANIZED_WATER_FIGURES %s\n%s\n',out,jsonencode(facts));
end

function f=canvas()
f=figure('Visible','off','Color','w','Units','inches','Position',[.3 .3 12 8.2], ...
 'PaperUnits','inches','PaperPosition',[0 0 12 8.2],'PaperSize',[12 8.2], ...
 'GraphicsSmoothing','off','InvertHardcopy','off');
set(f,'DefaultAxesFontName','Times New Roman','DefaultTextFontName','Times New Roman');
end
function h=box(f,position,message,size,color)
a=axes('Parent',f,'Units','normalized','Position',position,'Visible','off', ...
 'Color','none','FontName','Times New Roman','XLim',[0 1],'YLim',[0 1]);
h=text(a,0,1,message,'Units','normalized','FontName','Times New Roman', ...
 'FontSize',size,'Color',color,'Interpreter','none','VerticalAlignment','top', ...
 'HorizontalAlignment','left','Clipping','off');
end
function band(f,position)
a=axes('Parent',f,'Units','normalized','Position',position,'Visible','off', ...
 'FontName','Times New Roman','XLim',[0 1],'YLim',[0 1]);
rectangle(a,'Position',[0 0 1 1],'FaceColor',[.965 .973 .976],'EdgeColor','none');
end
function callout(f,x,y,title_text,body,ink,muted)
box(f,[x y+.062 .40 .04],title_text,16,ink);
box(f,[x y-.005 .40 .063],body,13.5,muted);
end
function ax=field_axes(f,position,phi,G,d,map)
ax=axes('Parent',f,'Position',position);
imagesc(ax,G.xc*d/1000,G.yc*d/1000,reshape(phi,G.Ny,G.Nx));
set(ax,'YDir','normal','FontName','Times New Roman','FontSize',12, ...
 'TickLabelInterpreter','none','Box','on','XTick',0:5:20,'YTick',-2:2:10, ...
 'LineWidth',.8,'Layer','top');
axis(ax,'image');xlim(ax,[0 20]);ylim(ax,[-2 10]);clim(ax,[0 1]);colormap(ax,map);
xlabel(ax,'x [km]','FontName','Times New Roman','Interpreter','none');
ylabel(ax,'z [km]','FontName','Times New Roman','Interpreter','none');
hold(ax,'on');ax.Position=position;
end
function arrow(ax,x,z,u,v,color)
quiver(ax,x,z,u,v,0,'Color',color,'LineWidth',2.3,'MaxHeadSize',.35);
end
function export_figure(f,out,stem)
drawnow;
objects=findall(f,'-property','FontName');
for j=1:numel(objects)
 if ~strcmpi(objects(j).FontName,'Times New Roman'),objects(j).FontName='Times New Roman';end
end
for j=1:numel(objects),assert(strcmpi(objects(j).FontName,'Times New Roman'));end
warmup=print(f,'-RGBImage','-r200'); %#ok<NASGU> settle font metrics before the saved raster
drawnow;
print(f,fullfile(out,[stem '.png']),'-dpng','-r200');
print(f,fullfile(out,[stem '.svg']),'-dsvg','-painters');
print(f,fullfile(out,[stem '.pdf']),'-dpdf','-painters');
close(f);
end
