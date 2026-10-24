function result=run_Jake_head_reference_trial()
% Ten-year trial, using only the optional reference correction in the solver.
root=fileparts(mfilename('fullpath')); out=fullfile(root,'..','Output','Jake_head_reference_trial_10yr');
if isfile(fullfile(out,'noflow_kc_5.600e-11.mat'))
 error('Trial output already exists; choose a fresh output folder.');
end
options=struct('correct_head_reference',true,'use_actual_conductivity_timestep',true, ...
 'max_steps',100,'final_years',10,'snapshot_steps',[0 1], ...
 'snapshot_interval_years',2,'checkpoint_steps',10, ...
 'legacy_outputs',false,'evolve_tracers',false,'stop_on_melt_loss',false,'output_dir',out);
result=porosity_wave_2D_Jake_minimal('03321',1e14,50e3,5.6e-11, ...
 'effe_vel','temperate_blob_settle',options);
assert(strcmp(result.status,'completed') && abs(result.history(end,1)-10)<1e-8);
assert(all(isfinite(result.full_phi),'all') && all(isfinite(result.full_T_K),'all'));
analyze_Jake_head_reference_trial(result);
end
