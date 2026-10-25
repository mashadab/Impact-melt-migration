function audit_Europa_face_fluxes
% Numerical face-by-face proof using actual research states and operators.
% Original solver and research outputs are read only. No interpolated states.
root=fileparts(mfilename('fullpath'));addpath(root);project=fileparts(root);
out=fullfile(project,'Output','Europa_face_flux_proof_20261024');
scratch=fullfile(project,'tmp','Europa_face_flux_proof');
if ~isfolder(out),mkdir(out);end
if ~isfolder(scratch),mkdir(scratch);end
diary(fullfile(out,'face_flux_audit.log'));cl=onCleanup(@() diary('off')); %#ok<NASGU>
runs={fullfile(project,'Output','Europa_kc_1.850e-08_until_depleted_20261023_195524'), ...
      fullfile(project,'Output','Europa_kc_1.850e-16_until_depleted_20261024_085440')};
labels={'high','low'};kcs=[1.85e-8 1.85e-16];
source=fileread(fullfile(root,'darcy_stokes_2D_cases.m'));
for k=1:2,assert(strcmp(source,fileread(fullfile(runs{k},'source','darcy_stokes_2D_cases.m'))));end
initial=cell(1,2);first=cell(1,2);budgets=cell(1,2);d0=cell(1,2);
for k=1:2
 initial{k}=read_state(runs{k},0);first{k}=read_state(runs{k},1);
 budgets{k}=readtable(fullfile(runs{k},'melt_budget.csv'));
 d0{k}=diagnose(initial{k},first{k},budgets{k},1,labels{k},true);
end
assert(max(abs(d0{1}.phi0-d0{2}.phi0))==0);
G=initial{1}.Grid.p;d=initial{1}.length_scale_m;
[R,Z]=meshgrid(G.xc*d,G.yc*d);ny=G.Ny;nx=G.Nx;
vertical=reshape(G.Nfx+(1:G.Nfy),ny+1,nx);top=vertical(2:end,:);top=top(:);
common=d0{1}.phi0==0 & d0{1}.phi1>1e-12 & d0{2}.phi1>1e-12 & Z(:)>=0;
down=common & d0{1}.Qadv(top)<0 & d0{2}.Qadv(top)<0;
idx=find(down);
if isempty(idx)
 idx=find(common);selection='No common downward top-face event in step 1; lowest common newly wet cell selected.';
else
 selection='Lowest common initially dry cell wetted in step 1 with liquid entering downward through its top face.';
end
assert(~isempty(idx),'No common newly wetted cell found.');
[~,order]=sortrows([Z(idx),R(idx)],[1 2]);target=idx(order(1));
[~,ir]=min(abs(G.xc*d-1300));[~,iz]=min(abs(G.yc*d-8750));legacy=(ir-1)*ny+iz;
targets=[target legacy];targetnames={'selected_example','previous_example'};
fprintf('SELECTED_CELL r=%.12g m z=%.12g m; %s\n',R(target),Z(target),selection);
report=struct('seconds_per_year',3.154e7,'selection',selection, ...
 'cell_volume_m3',G.V(target)*d^3,'target_radius_m',R(target),'target_elevation_m',Z(target), ...
 'definition','q is Darcy volume flux per face area [m/s]; Q=q*A is volume/time; local Q_into is positive inward. All cells are full axisymmetric annuli.', ...
 'first_step',struct,'later',struct);
face_rows=struct([]);cell_rows=struct([]);interface_rows=struct([]);event_rows=struct([]);
for k=1:2
 for step=1:10
  before=read_state(runs{k},step-1);after=read_state(runs{k},step);
  diag=diagnose(before,after,budgets{k},step,labels{k},true);
  save(fullfile(out,sprintf('%s_step_%08d_all_faces.mat',labels{k},step)),'diag','-v7.3');
  for j=1:numel(targets)
   [frow,crow]=local_rows(diag,targets(j),targetnames{j});
   face_rows=append_rows(face_rows,frow);cell_rows=append_rows(cell_rows,crow);
   if step==1 && j==1
    report.first_step.(labels{k})=struct('cell',crow,'faces',frow);
   end
  end
  interface_rows=append_rows(interface_rows,interface_summary(diag));
  if step==1
   born=find(diag.phi0==0 & diag.phi1>1e-12);
   for j=1:numel(born)
    [~,crow]=local_rows(diag,born(j),'all_newly_wet');event_rows=append_rows(event_rows,crow);
   end
  end
 end
 fprintf('SAVED_FIRST_TEN_STEPS %s\n',labels{k});
end

% Read-only instrumented copy: freeze the input state, capture original flow,
% return before the production thermal update. The later step is reconstructed
% with the recorded research time step and verified against its CSV budgets.
modified=strrep(source,'function result = darcy_stokes_2D_cases(', ...
 'function result = face_flux_audit_solver(');
modified=strrep(modified,"fileparts(mfilename('fullpath'))",['''' strrep(root,'''','''''') '''']);
needle='    run_timer = tic;';assert(count(modified,needle)==1);
modified=strrep(modified,needle,sprintf(['    audit_input=load(options.audit_input,''state'');\n' ...
 '    H=audit_input.state.enthalpy_dimensionless(:);\n%s'],needle));
needle='        vfmax= max(abs(vf));';assert(count(modified,needle)==1);
capture=sprintf(['        audit_flow=struct(''solid_velocity_m_s'',vm*D_T/d, ...\n' ...
 '          ''fluid_velocity_m_s'',vf*D_T/d,''darcy_flux_m_s'',qr*D_T/d, ...\n' ...
 '          ''pressure_head_Pa'',p_head*eta_0*D_T/d^2);\n' ...
 '        result=audit_flow; return; %% No production time advance.\n%s'],needle);
modified=strrep(modified,needle,capture);
fid=fopen(fullfile(scratch,'face_flux_audit_solver.m'),'w');fprintf(fid,'%s',modified);fclose(fid);
fid=fopen(fullfile(scratch,'production_source_used.m.txt'),'w');fprintf(fid,'%s',source);fclose(fid);
addpath(scratch);clear face_flux_audit_solver
latecases={1,'high',NaN;2,'low',NaN;2,'low_main_transfer',11622};
for lateindex=1:size(latecases,1)
 k=latecases{lateindex,1};latekey=latecases{lateindex,2};
 if isnan(latecases{lateindex,3})
  manifest=readtable(fullfile(runs{k},'research_video','frame_manifest.csv'));
  [~,j]=min(abs(manifest.time_years-80));input_step=manifest.iteration(j);
 else
  input_step=latecases{lateindex,3};
 end
 before=read_state(runs{k},input_step);
 options=struct('max_steps',1,'output_dir',fullfile(scratch,labels{k}), ...
  'legacy_outputs',false,'evolve_tracers',false,'save_state_snapshots',false, ...
  'audit_input',fullfile(runs{k},'states',sprintf('state_%08d.mat',input_step)));
 flow=face_flux_audit_solver('impact_melt_europa','03321',1e14,50e3,kcs(k),'effe_vel','case_setup',options);
 after=before;fields=fieldnames(flow);
 for j=1:numel(fields),after.(fields{j})=flow.(fields{j});end
 after.step=input_step+1;after.flow_time_years=before.time_years;
 after.time_years=budgets{k}.time_years(input_step+2);
 diag=diagnose(before,after,budgets{k},input_step+1,labels{k},false);
 report.later.(latekey)=interface_summary(diag);
 report.later.(latekey).input_state_step=input_step;
 interface_rows=append_rows(interface_rows,interface_summary(diag));
 save(fullfile(out,sprintf('%s_later_all_faces.mat',latekey)),'diag','-v7.3');
 ids=diag.interface_ids;
 iface=table(ids,diag.face_r_m(ids),diag.area(ids),diag.vs(ids)*3.154e7,diag.phi_up(ids), ...
  diag.kface(ids),diag.head_gradient(ids),diag.q(ids),diag.Qadv(ids)*3.154e7, ...
  diag.Qdarcy(ids)*3.154e7,diag.Qtotal(ids)*3.154e7, ...
  'VariableNames',{'face_id','radius_m','area_m2','solid_velocity_up_m_per_year','upwind_phi', ...
  'permeability_m2','head_gradient_up_Pa_per_m','Darcy_flux_up_m_per_s', ...
  'Qadv_up_m3_per_year','QDarcy_up_m3_per_year','Qtotal_up_m3_per_year'});
 writetable(iface,fullfile(out,sprintf('%s_later_z0_faces.csv',latekey)));
 fprintf('LATER_INTERFACE %s %s\n',latekey,jsonencode(report.later.(latekey)));
end
writetable(struct2table(face_rows),fullfile(out,'selected_cell_faces.csv'));
writetable(struct2table(cell_rows),fullfile(out,'selected_cell_steps.csv'));
writetable(struct2table(event_rows),fullfile(out,'all_first_step_newly_wet_cells.csv'));
writetable(struct2table(interface_rows),fullfile(out,'interface_Q_comparison.csv'));
fid=fopen(fullfile(out,'face_flux_proof.json'),'w');fprintf(fid,'%s',jsonencode(report));fclose(fid);
make_plot(report,cell_rows,out);
assert(strcmp(source,fileread(fullfile(root,'darcy_stokes_2D_cases.m'))));
fprintf('FACE_FLUX_PROOF_COMPLETE %s\n',out);
end

function s=read_state(run,step)
x=load(fullfile(run,'states',sprintf('state_%08d.mat',step)),'state');s=x.state;
end

function x=append_rows(x,y)
if isempty(x),x=y;else,x=[x y];end
end

function a=diagnose(s0,s1,b,step,label,has_actual_endpoint)
YEAR=3.154e7;G=s0.Grid.p;d=s0.length_scale_m;
[Dp,Gp,~]=build_ops(G);D=Dp/d;grad=Gp/d;
cpi=185+7.037*273;DThermal=3.3/(920*cpi);latent=1000*334000/(920*cpi*173);
waterT=@(H) H*(920*cpi)/(1000*4186)-334000/(173*4186)+1;
[T,phi]=enthMelt(s0.enthalpy_dimensionless(:),latent,@(H)H+1,@(H)H/latent,waterT);
enthalpy=@(P,U)(1-P).*(U-1)+P*1000/(920*cpi*173).*(334000+4186*173*(U-1));
H=enthalpy(phi,T);dt=(s1.time_years-s1.flow_time_years)*YEAR;
assert(abs(s1.flow_time_years-s0.time_years)<1e-7);
vs=s1.solid_velocity_m_s(:);q=s1.darcy_flux_m_s(:);head=s1.pressure_head_Pa(:);
K=comp_mean(reshape(phi.^3,G.Ny,G.Nx),-1,1,G);
kface=s0.kc_m2*full(diag(K));head_gradient=grad*head;
qcheck=-kface/.001.*head_gradient;
assert(norm(q-qcheck,inf)<1e-11*max(norm(q,inf),1e-20));
Ae=build_adv_op(vs,H,dt,Gp,G,struct,'gd');
adv=flux_upwind(vs,G)*phi;phi_up=adv./vs;phi_up(vs==0)=NaN;
tilde=(1-phi).*(T-1)/latent+phi;
Aq=build_adv_op(q,1./tilde,dt,Gp,G,struct,'gd')*spdiags(1./tilde,0,G.N,G.N);
Hadv=Ae*H;Hdarcy=Aq*H;AH=(Ae+Aq)*H;
[R,Z]=meshgrid(G.xc*d,G.yc*d);
k=(phi*.56+(1-phi)*3.3)/3.3;k(Z(:)<200 & phi>.5)=100;
kf=comp_mean(reshape(k,G.Ny,G.Nx),-1,1,G);
Hcond=-DThermal*kf*(grad*T);
dHadv=-dt*D*Hadv;dHdarcy=-dt*D*Hdarcy;dHcond=-dt*D*Hcond;
Hp=H-dt*D*AH+dHcond;Hp(G.dof_ymax)=-1;
[Tp,Pp]=enthMelt(Hp,latent,@(H)H+1,@(H)H/latent,waterT);
Hp=enthalpy(Pp,Tp);
if has_actual_endpoint
 H1=s1.enthalpy_dimensionless(:);P1=s1.phi(:);T1=s1.temperature_K(:);
 reconstruction_error=max(abs(H1-Hp));
 assert(reconstruction_error<1e-11);
else
 H1=Hp;P1=Pp;T1=Tp*173+100;reconstruction_error=NaN;
end
area=G.A*d^2;vol=G.V*d^3;
[Rf,Zr]=meshgrid(G.xf*d,G.yc*d);[Rz,Zf]=meshgrid(G.xc*d,G.yf*d);
vertical=reshape(G.Nfx+(1:G.Nfy),G.Ny+1,G.Nx);
[~,j]=min(abs(G.yf*d));assert(abs(G.yf(j)*d)<1e-8);interface=vertical(j,:);interface=interface(:);
Qadv=adv.*area;Qdarcy=q.*area;Qtotal=Qadv+Qdarcy;
expected_rate=(b.delivered_net_m3(step+1)-b.delivered_net_m3(step))/(dt/YEAR);
calculated_rate=-sum(Qtotal(interface))*YEAR;
rate_error=calculated_rate-expected_rate;
assert(abs(rate_error)<1e-5*max(1,abs(expected_rate)));
shell=Z(:)>=0;volume_error=sum(Pp(shell).*vol(shell))-b.melt_shell_m3(step+1);
assert(abs(volume_error)<1e-10*max(1,b.melt_shell_m3(step+1)));
a=struct('run',label,'step',step,'flow_time_years',s0.time_years,'time_years',s1.time_years, ...
 'dt_years',dt/YEAR,'kc_m2',s0.kc_m2,'G',G,'d',d,'area',area,'volume',vol, ...
 'cell_r_m',R(:),'cell_z_m',Z(:),'face_r_m',[Rf(:);Rz(:)],'face_z_m',[Zr(:);Zf(:)], ...
 'phi0',phi,'phi1',P1,'T0_K',T*173+100,'T1_K',T1,'H0',H,'H1',H1, ...
 'vs',vs,'q',q,'phi_up',phi_up,'kface',kface,'head_gradient',head_gradient, ...
 'Qadv',Qadv,'Qdarcy',Qdarcy,'Qtotal',Qtotal,'Qmixture',(vs+q).*area, ...
 'Qsolid',(vs-adv).*area,'Hadv_flux',Hadv,'Hdarcy_flux',Hdarcy,'Hconductive_flux',Hcond, ...
 'dHadv',dHadv,'dHdarcy',dHdarcy,'dHcond',dHcond,'latent',latent, ...
 'Dphysical',D,'interface_ids',interface,'actual_endpoint_available',has_actual_endpoint, ...
 'max_H_reconstruction_error',reconstruction_error,'interface_rate_error_m3_per_year',rate_error, ...
 'shell_volume_error_m3',volume_error);
end

function [fr,cr]=local_rows(a,cellid,targetname)
ny=a.G.Ny;ir=floor((cellid-1)/ny)+1;iz=mod(cellid-1,ny)+1;
ids=[(ir-1)*ny+iz;ir*ny+iz;a.G.Nfx+(ir-1)*(ny+1)+iz;a.G.Nfx+(ir-1)*(ny+1)+iz+1];
normal=[-1;1;-1;1];names={'left','right','bottom','top'};YEAR=3.154e7;
rows=struct([]);
for j=1:4
 id=ids(j);n=normal(j);
 row=struct('run',a.run,'kc_m2',a.kc_m2,'step',a.step,'flow_time_years',a.flow_time_years, ...
  'time_years',a.time_years,'target',targetname,'r_cell_m',a.cell_r_m(cellid),'z_cell_m',a.cell_z_m(cellid), ...
  'cell_id',cellid,'face',names{j},'face_id',id,'face_area_m2',a.area(id),'outward_normal_axis_sign',n, ...
  'solid_velocity_axis_m_per_s',a.vs(id),'solid_velocity_axis_m_per_year',a.vs(id)*YEAR, ...
  'solid_velocity_into_cell_m_per_year',-n*a.vs(id)*YEAR,'upwind_phi',a.phi_up(id), ...
  'harmonic_face_permeability_m2',a.kface(id),'head_gradient_axis_Pa_per_m',a.head_gradient(id), ...
  'Darcy_flux_axis_m_per_s',a.q(id),'Qadv_into_m3_per_s',-n*a.Qadv(id), ...
  'QDarcy_into_m3_per_s',-n*a.Qdarcy(id),'Qtotal_into_m3_per_s',-n*a.Qtotal(id), ...
  'Qadv_into_m3_per_year',-n*a.Qadv(id)*YEAR,'QDarcy_into_m3_per_year',-n*a.Qdarcy(id)*YEAR, ...
  'Qtotal_into_m3_per_year',-n*a.Qtotal(id)*YEAR, ...
  'Qmixture_into_m3_per_year',-n*a.Qmixture(id)*YEAR,'Qsolid_into_m3_per_year',-n*a.Qsolid(id)*YEAR);
 if j==1,rows=row;else,rows(j)=row;end %#ok<AGROW>
end
fr=rows;
netadv=-sum(normal.*a.Qadv(ids))*YEAR;netdarcy=-sum(normal.*a.Qdarcy(ids))*YEAR;
dphi_adv=netadv*a.dt_years/a.volume(cellid);dphi_darcy=netdarcy*a.dt_years/a.volume(cellid);
cr=struct('run',a.run,'kc_m2',a.kc_m2,'step',a.step,'flow_time_years',a.flow_time_years, ...
 'time_years',a.time_years,'dt_years',a.dt_years,'target',targetname,'cell_id',cellid, ...
 'r_m',a.cell_r_m(cellid),'z_m',a.cell_z_m(cellid),'volume_m3',a.volume(cellid), ...
 'phi_before',a.phi0(cellid),'phi_after',a.phi1(cellid),'T_before_K',a.T0_K(cellid),'T_after_K',a.T1_K(cellid), ...
 'Qadv_net_in_m3_per_year',netadv,'QDarcy_net_in_m3_per_year',netdarcy,'Qtotal_net_in_m3_per_year',netadv+netdarcy, ...
 'Qsolid_net_in_m3_per_year',-sum(normal.*a.Qsolid(ids))*YEAR, ...
 'Qmixture_net_in_m3_per_year',-sum(normal.*a.Qmixture(ids))*YEAR, ...
 'delta_phi_carried_flux',dphi_adv,'delta_phi_Darcy_flux',dphi_darcy, ...
 'delta_phi_phase_residual',a.phi1(cellid)-a.phi0(cellid)-dphi_adv-dphi_darcy, ...
 'H_before',a.H0(cellid),'H_after',a.H1(cellid),'delta_H_advection',a.dHadv(cellid), ...
 'delta_H_Darcy',a.dHdarcy(cellid),'delta_H_conduction',a.dHcond(cellid), ...
 'solid_divergence_per_s',a.Dphysical(cellid,:)*a.vs, ...
 'mixture_divergence_per_s',a.Dphysical(cellid,:)*(a.vs+a.q), ...
 'liquid_gain_m3',(a.phi1(cellid)-a.phi0(cellid))*a.volume(cellid), ...
 'actual_endpoint_available',a.actual_endpoint_available,'max_H_reconstruction_error',a.max_H_reconstruction_error);
end

function r=interface_summary(a)
ids=a.interface_ids;YEAR=3.154e7;
r=struct('run',a.run,'kc_m2',a.kc_m2,'step',a.step,'flow_time_years',a.flow_time_years,'time_years',a.time_years, ...
 'Qadv_down_m3_per_year',-sum(a.Qadv(ids))*YEAR,'QDarcy_down_m3_per_year',-sum(a.Qdarcy(ids))*YEAR, ...
 'Qtotal_down_m3_per_year',-sum(a.Qtotal(ids))*YEAR,'Qmixture_down_m3_per_year',-sum(a.Qmixture(ids))*YEAR, ...
 'recomputed_minus_recorded_Q_m3_per_year',a.interface_rate_error_m3_per_year, ...
 'recomputed_minus_recorded_shell_melt_m3',a.shell_volume_error_m3);
end

function make_plot(r,cells,out)
set(groot,'defaultTextInterpreter','tex','defaultLegendInterpreter','tex','defaultAxesTickLabelInterpreter','tex');
f=figure('Visible','off','Color','w','Position',[40 40 1500 850]);
tl=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
h=r.first_step.high;l=r.first_step.low;cols=[.02 .47 .53;.85 .38 .12];
ax=nexttile(tl);vals=[[h.faces.Qadv_into_m3_per_year]' [l.faces.Qadv_into_m3_per_year]']/1e6;
bb=bar(ax,vals);bb(1).FaceColor=cols(1,:);bb(2).FaceColor=cols(2,:);
xticklabels(ax,{'Left','Right','Bottom','Top'});ylabel(ax,'Q into selected cell [million m^3/year]');
title(ax,'First flow: carried liquid through each face');
legend(ax,{'kc = 1.85e-8','kc = 1.85e-16'},'Location','best');set(ax,'XGrid','on','YGrid','on');
ax=nexttile(tl);axis(ax,'off');
text(ax,0,.95,sprintf('Initially dry cell: r = %.0f m, z = %.0f m',r.target_radius_m,r.target_elevation_m),'FontSize',12,'FontWeight','bold');
text(ax,0,.77,sprintf('Cell volume = %.7g m^3',r.cell_volume_m3),'FontSize',11);
text(ax,0,.60,'All face permeabilities and Darcy fluxes = 0 at t = 0.','FontSize',11);
text(ax,0,.43,sprintf('High kc: Q_in = %.6g m^3/yr; dt = %.6g yr',h.cell.Qtotal_net_in_m3_per_year,h.cell.dt_years),'FontSize',11,'Color',cols(1,:));
text(ax,0,.30,sprintf('phi: %.3g -> %.7g',h.cell.phi_before,h.cell.phi_after),'FontSize',11,'Color',cols(1,:));
text(ax,0,.15,sprintf('Low kc: Q_in = %.6g m^3/yr; dt = %.6g yr',l.cell.Qtotal_net_in_m3_per_year,l.cell.dt_years),'FontSize',11,'Color',cols(2,:));
text(ax,0,.02,sprintf('phi: %.3g -> %.7g',l.cell.phi_before,l.cell.phi_after),'FontSize',11,'Color',cols(2,:));
ax=nexttile(tl);hold(ax,'on');keys={'high','low'};
for k=1:2
 keep=arrayfun(@(x)strcmp(x.run,keys{k})&&strcmp(x.target,'selected_example'),cells);
 c=cells(keep);scatter(ax,[0 [c.time_years]],[c(1).phi_before [c.phi_after]],35,cols(k,:),'filled');
end
xlabel(ax,'Actual simulated time [years]');ylabel(ax,'Liquid fraction in selected cell');
title(ax,'First ten saved updates; markers only');set(ax,'XGrid','on','YGrid','on');
legend(ax,{'kc = 1.85e-8','kc = 1.85e-16'},'Location','best');
ax=nexttile(tl);axis(ax,'off');
text(ax,0,.95,'Actual-state flow near 80 years: z = 0 transfer','FontSize',12,'FontWeight','bold');
keys={'high','low'};
for k=1:2
 a=r.later.(keys{k});y=.76-(k-1)*.38;
 text(ax,0,y,sprintf('%s kc; flow time %.7g yr',keys{k},a.flow_time_years),'FontSize',11,'Color',cols(k,:));
 text(ax,0,y-.12,sprintf('Q_Darcy = %+.5g; Q_carried = %+.5g km^3/yr',a.QDarcy_down_m3_per_year/1e9,a.Qadv_down_m3_per_year/1e9),'FontSize',10);
 text(ax,0,y-.24,sprintf('Q_net = %+.6g km^3/yr',a.Qtotal_down_m3_per_year/1e9),'FontSize',11);
end
title(tl,'Europa: a face-by-face numerical proof','FontSize',20);
xlabel(tl,{'Local face signs are positive into the cell. Interface signs are positive downward.', ...
 'Initial flow states are at the same time t = 0; adaptive first-step durations differ. Later states are separately labelled; no interpolation.'});
exportgraphics(f,fullfile(out,'Europa_face_flux_proof.png'),'Resolution',150);close(f);
end
