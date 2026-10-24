function run_porosity_wave_2D_Jake_800(use_actual_conductivity_timestep,correct_head_reference)
% Run minimal original solver with explicit timestep/reference flags.
% run_porosity_wave_2D_Jake_800(true,true) enables both trial-tested flags.
if nargin<1, use_actual_conductivity_timestep=false; end
if nargin<2, correct_head_reference=false; end
root=fileparts(mfilename('fullpath'));
out=fullfile(root,'..','Output','Jake_2D_minimal_800_years');
if use_actual_conductivity_timestep, out=[out '_actual_kappa']; end
if correct_head_reference, out=[out '_head_reference']; end
if ~isfolder(out), mkdir(out); end
if isfile(fullfile(out,'checkpoint.mat')) || isfile(fullfile(out,'noflow_kc_5.600e-11.mat'))
 error('Existing run data found. Use a fresh output folder rather than overwrite.');
end
options=struct('correct_head_reference',correct_head_reference,'use_actual_conductivity_timestep',use_actual_conductivity_timestep,'max_steps',1000000,'final_years',800, ...
 'snapshot_steps',[0 1 60],'snapshot_interval_years',5,'checkpoint_steps',100, ...
 'legacy_outputs',false,'evolve_tracers',false,'stop_on_melt_loss',false,'output_dir',out);
try
 r=porosity_wave_2D_Jake_minimal('03321',1e14,50e3,5.6e-11, ...
     'effe_vel','temperate_blob_settle',options);
 assert(strcmp(r.status,'completed') && abs(r.history(end,1)-800)<1e-8, ...
     'Solver did not reach 800 years. Inspect its saved status.');
 % Adapt saved output metadata ONLY to the existing plot/video helpers.
 v=struct('options',struct('output_dir',out),'Grid',r.Grid, ...
 'x_m',r.Grid.p.xc*r.length_scale_m,'z_m',r.Grid.p.yc*r.length_scale_m, ...
 'initial_phi',r.full_phi(:,1),'snapshot_phi',r.full_phi, ...
 'snapshot_temperature_K',r.full_T_K,'snapshot_years',r.time_years);
 make_S3_video(v);
 fid=fopen(fullfile(out,'COMPLETE.txt'),'w');
 fprintf(fid,'Completed %.12g years in %d steps.\n',r.history(end,1),r.completed_steps);
 fclose(fid);
catch err
 fid=fopen(fullfile(out,'FAILED.txt'),'w');
 fprintf(fid,'%s\n',getReport(err,'extended','hyperlinks','off'));fclose(fid);
 rethrow(err);
end
end
