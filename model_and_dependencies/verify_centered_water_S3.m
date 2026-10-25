function report=verify_centered_water_S3(reference_dir,reuse_saved)
% Compare existing cases before/after the new setup; check the new initial flow.
root=fileparts(mfilename('fullpath'));addpath(root);
if nargin<1
 reference_dir=strtrim(fileread(fullfile(root,'..','tmp','centered_water_verification_output.txt')));
end
if nargin<2,reuse_saved=false;end
diary(fullfile(reference_dir,'verification.log'));clean=onCleanup(@()diary('off')); %#ok<NASGU>
for file={'darcy_stokes_2D_cases.m','run_darcy_stokes_case.m', ...
 'record_centered_water_step.m','run_centered_water_S3.m'}
 messages=checkcode(fullfile(root,file{1}),'-id');
 assert(~any(strcmp({messages.id},'PARSE')),'Parse error in %s.',file{1});
end
report=struct;
for key={'porosity_wave','impact_melt_europa'}
 name=key{1};steps=1;prefix='wave';
 if strcmp(name,'impact_melt_europa'),steps=3;prefix='europa';end
 files=dir(fullfile(reference_dir,[prefix '_before'],'noflow_kc_*.mat'));assert(numel(files)==1);
 baseline=load(fullfile(files.folder,files.name),'result');a=baseline.result;
 o=struct('max_steps',steps,'snapshot_steps',a.steps, ...
  'correct_head_reference',true,'use_actual_conductivity_timestep',true, ...
  'output_dir',fullfile(reference_dir,[prefix '_after']));
 if reuse_saved
  files=dir(fullfile(o.output_dir,'noflow_kc_*.mat'));assert(numel(files)==1);
  loaded=load(fullfile(files.folder,files.name),'result');b=loaded.result;
 else
  b=run_darcy_stokes_case(name,o);
 end
 for field={'full_H','full_phi','full_T_K','final_state','history','time_years','steps'}
  assert(isequaln(a.(field{1}),b.(field{1})),'Existing %s changed: %s.',name,field{1});
 end
 report.([prefix '_bitwise_identical'])=true;
 fprintf('PASS %s: full states, pressure, velocities, Darcy flux and history identical.\n',name);
 clear a b baseline;
end
out=fullfile(reference_dir,'centered_corrected_1yr');
if reuse_saved
 loaded=load(fullfile(out,'noflow_kc_1.850e-08.mat'),'result');r=loaded.result;
else
 r=run_centered_water_S3(1,out);
end
assert(strcmp(r.status,'completed') && r.time_years(end)==1);
old=load(fullfile(root,'..','Output','centered_blob_closed_20261024_193436','initial_state.mat'),'initial_state');
assert(isequal(r.full_phi(:,1),old.initial_state.phi));
assert(isequal(r.full_T_K(:,1),old.initial_state.T_dimensionless*173+100));
assert(isequal(r.full_H(:,1),old.initial_state.H));
assert(r.length_scale_m==old.initial_state.d_m);
G=r.Grid.p;[X,Z]=meshgrid(G.xc*r.length_scale_m,G.yc*r.length_scale_m);
assert(isequal(r.full_phi(:,1),double(X(:)>5000 & X(:)<15000 & Z(:)>4000)));
assert(all(r.full_T_K(:,1)==273) && strcmp(G.geom,'cartesian'));
frozen=load(fullfile(root,'..','Output','centered_blob_continuation_20261024_210127', ...
 'analysis','forcing_control','initial_S3_reference.mat'),'flow');
actual=load(fullfile(out,'states','state_00000001.mat'),'checkpoint');s=actual.checkpoint;
report.initial_corrected_vs_max_abs_m_s=max(abs(s.solid_velocity_m_s-frozen.flow.solid_velocity_m_s));
report.initial_corrected_q_max_abs_m_s=max(abs(s.darcy_flux_m_s-frozen.flow.Darcy_flux_m_s));
report.initial_corrected_vs_relative_L2=norm(s.solid_velocity_m_s-frozen.flow.solid_velocity_m_s)/norm(frozen.flow.solid_velocity_m_s);
report.initial_corrected_q_relative_L2=norm(s.darcy_flux_m_s-frozen.flow.Darcy_flux_m_s)/norm(frozen.flow.Darcy_flux_m_s);
report.independent_flow_relative_tolerance=1e-8;
assert(max([report.initial_corrected_vs_relative_L2 report.initial_corrected_q_relative_L2])<report.independent_flow_relative_tolerance, ...
 'New-case initial flow differs from the independently audited corrected flow.');
dry=s.diagnostic.phi_before==0;pf=reshape(~dry,G.Ny,G.Nx);
touch_x=false(G.Ny,G.Nx+1);touch_y=false(G.Ny+1,G.Nx);
touch_x(:,2:end-1)=~pf(:,1:end-1) | ~pf(:,2:end);
touch_y(2:end-1,:)=~pf(1:end-1,:) | ~pf(2:end,:);
touch=[touch_x(:);touch_y(:)];
assert(all(s.diagnostic.permeability_m2(touch)==0) && all(s.darcy_flux_m_s(touch)==0));
report.centered_initial_state_identical=true;
report.initial_corrected_flow_matches_within_tolerance=true;
report.zero_Darcy_on_faces_touching_initially_dry_cells=true;
report.corrected_run_steps=r.completed_steps;report.corrected_run_years=r.time_years(end);
report.corrected_initial_max_vs_m_per_year=max(abs(s.solid_velocity_m_s))*3.154e7;
report.corrected_initial_max_q_m_per_year=max(abs(s.darcy_flux_m_s))*3.154e7;
report.corrected_first_dt_years=s.dt_years;
report.max_boundary_flux_dimensionless=max([r.max_boundary_solid_flux r.max_boundary_darcy_flux ...
 r.max_boundary_advective_heat_flux r.max_boundary_conductive_heat_flux]);
report.relative_enthalpy_error=r.max_enthalpy_balance_error/abs(r.initial_enthalpy_total);
report.max_phi_initially_dry=max(r.final_state.phi(r.full_phi(:,1)==0));
report.max_phi_lower=max(r.final_state.phi(Z(:)<4000));
report.temperature_range_K=[min(r.final_state.T_dimensionless)*173+100,max(r.final_state.T_dimensionless)*173+100];
report.output_dir=out;report.passed=true;
fid=fopen(fullfile(reference_dir,'verification.json'),'w');assert(fid>=0);
fprintf(fid,'%s',jsonencode(report));fclose(fid);
fid=fopen(fullfile(root,'..','tmp','centered_water_corrected_output.txt'),'w');
fprintf(fid,'%s',out);fclose(fid);
fprintf('CORRECTED_S3_VERIFIED %s\n',jsonencode(report));
end
