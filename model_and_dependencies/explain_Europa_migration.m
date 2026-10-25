function explain_Europa_migration
% Simple measured sketches and a controlled numerical-spreading figure.
% Reads completed audits; does not run or modify the research solver.
root=fileparts(mfilename('fullpath'));addpath(root);project=fileparts(root);
out=fullfile(project,'Output','Europa_simple_explanation_20261024');
if ~isfolder(out),mkdir(out);end
proof=jsondecode(fileread(fullfile(project,'Output','Europa_face_flux_proof_20261024','face_flux_proof.json')));
comparison=jsondecode(fileread(fullfile(project,'Output','Europa_permeability_comparison_20261024','comparison.json')));
C=struct('ink',[.10 .16 .23],'muted',[.35 .42 .49],'ice',[.84 .91 .97], ...
 'iceArrow',[.26 .43 .64],'water',[.00 .47 .53],'orange',[.84 .38 .13], ...
 'paper',[.97 .98 .99],'line',[.72 .78 .82]);
first_step_sketch(proof,C,out);
transport_modes(proof,comparison,C,out);
numerical_tail(C,out);
fprintf('SIMPLE_EUROPA_EXPLANATION %s\n',out);
end

function [f,ax]=canvas(C)
f=figure('Visible','off','Color','w','Position',[20 20 1600 920]);
ax=axes(f,'Position',[0 0 1 1]);axis(ax,[0 1600 0 920]);axis(ax,'off');
set(ax,'YDir','reverse');hold(ax,'on');
set(f,'DefaultTextFontName','Arial','DefaultAxesFontName','Arial');
set(f,'DefaultTextInterpreter','none','DefaultAxesTickLabelInterpreter','none','DefaultLegendInterpreter','none');
rectangle(ax,'Position',[0 0 1600 920],'FaceColor','w','EdgeColor','none');
end

function t=label(ax,x,y,str,sz,color,weight,align)
if nargin<8,align='left';end
if nargin<7,weight='normal';end
t=text(ax,x,y,str,'FontName','Arial','FontSize',sz,'Color',color,'FontWeight',weight, ...
 'Interpreter','none','HorizontalAlignment',align,'VerticalAlignment','middle');
end

function arrow(ax,p0,p1,color,width)
v=p1-p0;v=v/norm(v);n=[-v(2) v(1)];tip=28;
base=p1-tip*v;
pts=[p0+width/2*n; base+width/2*n; base+width*n; p1; ...
 base-width*n; base-width/2*n; p0-width/2*n];
patch(ax,pts(:,1),pts(:,2),color,'EdgeColor','none');
end

function card(ax,box,C)
rectangle(ax,'Position',box,'FaceColor',C.paper,'EdgeColor',C.line,'LineWidth',1.1,'Curvature',.035);
end

function save_figure(f,out,name)
% Preserve the full canvas and its margins rather than a tight content crop.
set(f,'PaperPositionMode','auto');
print(f,fullfile(out,[name '.png']),'-dpng','-r150');
print(f,fullfile(out,[name '.svg']),'-dsvg');close(f);
end

function first_step_sketch(p,C,out)
[f,ax]=canvas(C);h=p.first_step.high.cell;
label(ax,65,50,'How a dry grid cell receives melt when Darcy flow is zero',29,C.ink,'bold');
label(ax,65,99,'Measured first step: kc = 1.85e-8 m²; cell at r = 100 m, z = 6250 m',18,C.muted);
% Fixed cells in an r-z slice. Phase colors are illustrative, not pore geometry.
rectangle(ax,'Position',[180 180 340 170],'FaceColor',C.ice,'EdgeColor',C.line,'LineWidth',1.5);
rectangle(ax,'Position',[435 180 85 170],'FaceColor',C.water,'EdgeColor','none');
rectangle(ax,'Position',[180 350 340 170],'FaceColor',C.ice,'EdgeColor',C.ink,'LineWidth',3);
rectangle(ax,'Position',[180 520 340 110],'FaceColor',C.ice,'EdgeColor',C.line,'LineWidth',1.5);
rectangle(ax,'Position',[520 350 160 170],'FaceColor',C.ice,'EdgeColor',C.line,'LineWidth',1.5);
label(ax,340,215,sprintf('Upstream mixture\n25%% liquid + 75%% ice'),19,C.ink,'bold','center');
label(ax,350,454,sprintf('FIXED GRID CELL\nInitially dry: φ = 0'),22,C.ink,'bold','center');
label(ax,149,435,'axis r = 0',14,C.muted,'normal','center');
arrow(ax,[350 267],[350 401],C.water,21);
label(ax,65,298,sprintf('Mixture\nmoves down\n13.77 m/year'),15,C.water,'bold');
arrow(ax,[350 493],[350 603],C.iceArrow,18);
label(ax,372,573,sprintf('Dry ice out\n12.19 m/year'),16,C.iceArrow,'bold');
arrow(ax,[478 420],[630 420],C.iceArrow,15);
label(ax,558,475,sprintf('Dry ice out\n1.58 m/year'),16,C.iceArrow,'bold','center');
plot(ax,[520 700 740],[350 300 300],'Color',C.ink,'LineWidth',1.5);
label(ax,548,261,sprintf('Shared face:\nk = 0; Darcy Q = 0'),18,C.ink,'bold');
label(ax,350,663,'Material moves across the fixed grid.',18,C.ink,'bold','center');
card(ax,[815 180 710 477],C);
label(ax,850,225,sprintf('Over the first step (%.2f days)',h.dt_years*3.154e7/86400),22,C.ink,'bold');
label(ax,850,301,sprintf('Liquid gained: +%.0f m³',h.liquid_gain_m3),29,C.water,'bold');
label(ax,850,366,sprintf('Ice lost, net:  −%.0f m³',h.liquid_gain_m3),26,C.iceArrow,'bold');
label(ax,850,438,'Total cell volume: unchanged',23,C.ink,'bold');
label(ax,850,518,sprintf('Saved liquid fraction:\n0  →  %.9f',h.phi_after),23,C.ink);
label(ax,850,607,'Darcy gain = 0. Conductive gain = 0.',18,C.muted);
card(ax,[65 727 1460 115],C);
label(ax,95,761,'Carried liquid Q = face area × upstream liquid fraction × solid speed',22,C.ink,'bold');
label(ax,95,807,'125,664 m² × 0.25 × 13.768 m/year  ≈  432,539 m³/year',25,C.water,'bold');
label(ax,65,885,'Sketch: directions only; not to scale. Phase colors show fractions, not resolved pore structure.',16,C.muted);
save_figure(f,out,'01_dry_cell_sketch');
end

function transport_modes(p,c,C,out)
[f,ax]=canvas(C);h=p.later.high;l=p.later.low_main_transfer;
label(ax,65,50,'Once melt is connected, the two transport modes differ',29,C.ink,'bold');
label(ax,65,99,'Measured liquid flux across z = 0. Arrow widths are schematic; all rates below are km³/year.',18,C.muted);
card(ax,[65 155 715 553],C);card(ax,[820 155 715 553],C);
label(ax,422,196,'HIGH kc = 1.85e-8 m²',24,C.water,'bold','center');
label(ax,1177,196,'LOW kc = 1.85e-16 m²',24,C.orange,'bold','center');
label(ax,422,240,sprintf('Selected flow at %.3f years',h.flow_time_years),17,C.muted,'normal','center');
label(ax,1177,240,sprintf('Selected flow at %.3f years',l.flow_time_years),17,C.muted,'normal','center');
arrow(ax,[250 303],[250 480],C.water,28);
arrow(ax,[580 480],[580 303],C.iceArrow,28);
arrow(ax,[1005 303],[1005 480],C.water,4);
arrow(ax,[1335 303],[1335 480],C.iceArrow,28);
label(ax,250,535,sprintf('Darcy, relative to ice\n%.2f DOWN',h.QDarcy_down_m3_per_year/1e9),21,C.water,'bold','center');
label(ax,580,535,sprintf('Melt carried with ice\n%.2f UP',-h.Qadv_down_m3_per_year/1e9),20,C.iceArrow,'bold','center');
label(ax,1005,535,sprintf('Darcy, relative to ice\n0.0000000853 DOWN'),18,C.water,'bold','center');
label(ax,1335,535,sprintf('Melt carried with ice\n%.4f DOWN',l.Qadv_down_m3_per_year/1e9),20,C.iceArrow,'bold','center');
label(ax,422,648,sprintf('Net delivery: %.3f DOWN',h.Qtotal_down_m3_per_year/1e9),25,C.ink,'bold','center');
label(ax,1177,648,sprintf('Net delivery: %.4f DOWN',l.Qtotal_down_m3_per_year/1e9),25,C.ink,'bold','center');
label(ax,800,752,'Time to deliver HALF of the initial melt — same milestone',22,C.ink,'bold','center');
label(ax,422,803,sprintf('%.1f years',c.runs.high.milestones.delivery_50pct_of_initial.time_years),31,C.water,'bold','center');
label(ax,1177,803,sprintf('%.1f years',c.runs.low.milestones.delivery_50pct_of_initial.time_years),31,C.orange,'bold','center');
label(ax,65,885,'Flux examples use different labelled times to illustrate the modes. The half-delivery times compare the same volume.',15,C.muted);
save_figure(f,out,'02_two_transport_modes');
end

function numerical_tail(C,out)
% Repeat the already audited, inexpensive controlled transport benchmark.
phi0=.2;speed=-10;duration=100;lower=4000;upper=6000;
nys=[120 480];curves=cell(1,2);rows=struct([]);
for k=1:2
 gp=struct('xmin',0,'xmax',600,'Nx',3,'ymin',0,'ymax',12000,'Ny',nys(k),'geom','cylindrical_rz');
 g=build_grid(gp);[D,G,~]=build_ops(g);z=g.yc;dz=g.dy;
 phi=phi0*max(0,min(z+dz/2,upper)-max(z-dz/2,lower))/dz;
 H=repmat(phi,g.Nx,1);v=[zeros(g.Nfx,1);speed*ones(g.Nfy,1)];q=zeros(size(v));
 dt=.4*dz/abs(speed);steps=round(duration/dt);initial=sum(H.*g.V);
 for j=1:steps
  A=build_adv_op(v,H,dt,G,g,struct,'gd');
  H=H-dt*D*(A*H);
 end
 numeric=H(1:g.Ny);front=lower+speed*duration;
 x=flipud(front-(z+dz/2));y=flipud(numeric)*100;
 curves{k}=struct('x',x,'y',y,'dz',dz);
 tail=find(numeric>=.01*phi0,1,'first');tail_distance=front-(z(tail)-dz/2);
 row=struct('dz_m',dz,'tail_distance_at_phi_0p002_m',tail_distance, ...
  'relative_liquid_volume_error',(sum(H.*g.V)-initial)/initial);
 if k==1,rows=row;else,rows(k)=row;end %#ok<AGROW>
 writetable(table(x,y,'VariableNames',{'distance_ahead_of_exact_front_m','liquid_fraction_percent'}), ...
  fullfile(out,sprintf('control_profile_dz_%dm.csv',round(dz))));
end
assert(rows(1).tail_distance_at_phi_0p002_m==600 && rows(2).tail_distance_at_phi_0p002_m==300);
[f,ax]=canvas(C);
label(ax,65,50,'A separate effect: the numerical scheme spreads the front',29,C.ink,'bold');
label(ax,65,99,'Control test only: zero Darcy flow, no melting source, prescribed motion for 100 years.',18,C.muted);
pa=axes(f,'Position',[.075 .20 .58 .58]);hold(pa,'on');
hh=gobjects(3,1);
hh(1)=stairs(pa,curves{1}.x,curves{1}.y,'LineWidth',2.5,'Color',C.iceArrow);
hh(2)=stairs(pa,curves{2}.x,curves{2}.y,'LineWidth',2.5,'Color',C.orange);
hh(3)=plot(pa,[-600 0 0 800],[20 20 0 0],'k--','LineWidth',2.5);
xlim(pa,[-600 800]);ylim(pa,[-.4 21.5]);
set(pa,'FontName','Arial','FontSize',15,'Box','off','XGrid','on','YGrid','on');
xlabel(pa,'Distance ahead of the exact front [m]','FontSize',17,'Interpreter','none');
ylabel(pa,'Liquid fraction [%]','FontSize',17,'Interpreter','none');
legend(pa,hh,{'100 m cells','25 m cells','Exact moving front'},'Location','northeast','FontSize',15,'Interpreter','none');
card(ax,[1110 210 425 455],C);
label(ax,1140,255,'Positive distance = ahead',18,C.ink,'bold');
label(ax,1140,330,sprintf('A small numerical tail\nappears ahead of the\nexactly translated body.'),20,C.ink);
label(ax,1140,445,sprintf('Tail at φ ≥ 0.002:'),20,C.ink,'bold');
label(ax,1140,505,'100 m cells: 600 m',21,C.iceArrow,'bold');
label(ax,1140,555,'25 m cells: 300 m',21,C.orange,'bold');
label(ax,1140,620,'Finer cells → less spreading',17,C.ink,'bold');
label(ax,65,815,'In the coupled code, a numerical tail also has positive φ, so it can activate positive permeability.',20,C.ink,'bold');
label(ax,65,877,'This is a controlled test of the transport operator; these distances are not measured errors in the Europa runs.',16,C.muted);
save_figure(f,out,'03_numerical_spreading');
fid=fopen(fullfile(out,'control_test.json'),'w');fprintf(fid,'%s',jsonencode(rows));fclose(fid);
end
