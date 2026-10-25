function report=verify_Europa_paper_outputs(reference_run,output_dir)
% Three-step output-control check against the active frozen run's saved state.
% Verifies saved T/phi/H and impermeability; does not certify pressure accuracy.
root=fileparts(mfilename('fullpath'));addpath(root,'-begin');
if nargin<1
 reference_run=strtrim(fileread(fullfile(root,'..','tmp','Europa_S3_latest_run.txt')));
end
if nargin<2
 output_dir=fullfile(root,'..','Output',['Europa_paper_output_check_' datestr(now,'yyyymmdd_HHMMSS')]);
end
assert(~isfolder(output_dir),'Use a fresh verification directory.');
for name={'darcy_stokes_2D_cases.m','run_Europa_until_depleted.m','verify_Europa_paper_outputs.m'}
 messages=checkcode(fullfile(root,name{1}),'-id');
 assert(~any(strcmp({messages.id},'PARSE')),'Parse error in %s',name{1});
end
o=struct('kc',1.85e-8,'max_steps',3,'snapshot_steps',[0 3], ...
 'save_state_snapshots',true,'snapshot_every_steps',1, ...
 'snapshot_melt_fraction_change',0.005,'snapshot_depth_change_km',0.1, ...
 'output_dir',output_dir);
r=run_darcy_stokes_case('impact_melt_europa',o);
assert(isequal(r.steps,[0 1 2 3]));
assert(r.permeability_exponent==3 && r.correct_head_reference && r.use_actual_conductivity_timestep);
assert(r.max_base_solid_flux==0 && r.max_base_darcy_flux==0);
a=load(fullfile(reference_run,'states','state_00000003.mat'),'state');a=a.state;
temperature_error=max(abs(r.final_state.T_dimensionless*173+100-a.temperature_K));
phi_error=max(abs(r.final_state.phi-a.phi));
enthalpy_error=max(abs(r.final_state.H-a.enthalpy_dimensionless));
time_error=abs(r.time_years(end)-a.time_years);
assert(temperature_error<1e-5 && phi_error<1e-6 && enthalpy_error<1e-6 && time_error<1e-8);
report=struct('passed',true,'steps',r.steps,'output_dir',output_dir, ...
 'reference_run',reference_run,'max_temperature_difference_K',temperature_error, ...
 'max_phi_difference',phi_error,'max_enthalpy_difference',enthalpy_error, ...
 'time_difference_years',time_error,'base_solid_velocity',r.max_base_solid_flux, ...
 'base_Darcy_flux',r.max_base_darcy_flux,'nn',r.permeability_exponent, ...
 'pressure_accuracy_tested',false,'data_interpolation',false);
fid=fopen(fullfile(output_dir,'verification.json'),'w');fprintf(fid,'%s',jsonencode(report));fclose(fid);
fprintf('PAPER_OUTPUT_VERIFIED %s\n',jsonencode(report));
end
