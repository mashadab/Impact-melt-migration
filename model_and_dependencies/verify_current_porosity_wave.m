function verify_current_porosity_wave
root=fileparts(mfilename('fullpath'));addpath(root);
out=fullfile(root,'..','Output',['wave_after_Europa_changes_' datestr(now,'yyyymmdd_HHMMSS')]);
o=struct('correct_head_reference',true,'use_actual_conductivity_timestep',true, ...
 'max_steps',1,'snapshot_steps',[0 1],'output_dir',out);
r=run_darcy_stokes_case('porosity_wave',o);
s=load(fullfile(root,'..','Output','S3_case_switch_check_20261023_185621','original_S3','noflow_kc_5.600e-11.mat'),'result');a=s.result;
assert(strcmp(r.status,'completed') && r.completed_steps==1);
assert(strcmp(r.case_key,'porosity_wave') && strcmp(r.Grid.p.geom,'cartesian'));
assert(~isfield(r,'melt_budget'));
assert(isequaln(a.final_state,r.final_state));
assert(isequaln(a.full_H,r.full_H) && isequaln(a.full_T_K,r.full_T_K) && isequaln(a.full_phi,r.full_phi));
assert(isequaln(a.history,r.history));
summary=struct('bitwise_match_with_original_S3',true,'steps',r.completed_steps,'time_years',r.time_years(end), ...
 'temperature_min_K',min(r.full_T_K(:,end)),'temperature_max_K',max(r.full_T_K(:,end)), ...
 'max_boundary_darcy_flux',r.max_boundary_darcy_flux,'output_dir',out);
fid=fopen(fullfile(out,'verification.json'),'w');fprintf(fid,'%s',jsonencode(summary));fclose(fid);
fprintf('CURRENT_WAVE_VERIFIED %s\n',jsonencode(summary));
end
