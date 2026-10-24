function verify_S3_case_switch
root=fileparts(mfilename('fullpath'));addpath(root);
f=fullfile(root,'darcy_stokes_2D_cases.m');
m=checkcode(f,'-id');for j=1:numel(m),if strcmp(m(j).id,'PARSE'),error('%s',m(j).message);end,end
out=fullfile(root,'..','Output',['S3_case_switch_check_' datestr(now,'yyyymmdd_HHMMSS')]);
o=struct('correct_head_reference',true,'use_actual_conductivity_timestep',true, ...
 'max_steps',1,'snapshot_steps',[0 1],'output_dir',fullfile(out,'original_S3'));
fprintf('REGRESSION: original untouched S3, one full-grid step.\n');
a=porosity_wave_2D_Jake_minimal('03321',1e14,50e3,5.6e-11,'effe_vel','case_setup',o);
o.output_dir=fullfile(out,'shared_wave');
fprintf('REGRESSION: shared solver, porosity_wave key, identical options.\n');
b=run_darcy_stokes_case('porosity_wave',o);
assert(strcmp(a.status,'completed') && strcmp(b.status,'completed'));
assert(isequaln(a.full_H,b.full_H) && isequaln(a.full_phi,b.full_phi) && isequaln(a.full_T_K,b.full_T_K));
assert(isequaln(a.final_state,b.final_state) && isequaln(a.history,b.history));
fprintf('PASS: wave state, velocities, Darcy flux, pressure head, history are bit-for-bit identical.\n');
wave_time=b.time_years(end);clear a b;
o.max_steps=3;o.snapshot_steps=[0 1 3];o.output_dir=fullfile(out,'shared_europa');
r=run_darcy_stokes_case('impact_melt_europa',o);
s=load(fullfile(root,'..','Output','Europa_S3_pressure_20261023_185230','noflow_kc_1.850e-08.mat'),'result');a=s.result;
assert(strcmp(r.status,'completed') && isequal(r.mesh,[100 120]));
assert(strcmp(r.Grid.p.geom,'cylindrical_rz'));
% The ocean initialization was intentionally changed after the original regression.
[~,Z]=meshgrid(r.Grid.p.xc,r.Grid.p.yc);oc=Z(:)<0;
assert(all(r.full_phi(oc,1)==0));
assert(max(abs(r.full_T_K(oc,1)-273))<1e-10);
assert(isequaln(a.full_phi(~oc,1),r.full_phi(~oc,1)));
assert(isequaln(a.full_T_K(~oc,1),r.full_T_K(~oc,1)));
assert(all(isfinite(r.final_state.H)));
assert(r.max_base_solid_flux==0 && r.max_base_darcy_flux==0 && r.max_base_advective_heat_flux==0);
summary=struct('wave_bitwise_match',true,'wave_steps',1,'wave_years',wave_time, ...
 'europa_initialization_verified',true,'europa_steps',3,'europa_years',r.time_years(end), ...
 'europa_basal_solid_flux',r.max_base_solid_flux,'europa_basal_darcy_flux',r.max_base_darcy_flux, ...
 'output_dir',out);
fid=fopen(fullfile(out,'verification.json'),'w');fprintf(fid,'%s',jsonencode(summary));fclose(fid);
fprintf('CASE_SWITCH_VERIFIED %s\n',jsonencode(summary));
end
