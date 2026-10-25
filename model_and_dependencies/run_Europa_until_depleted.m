function run_Europa_until_depleted(output_dir,kc)
% Run a fresh Europa case until <=0.5% of initial shell melt remains.
% Optional kc defaults to 1.85e-8 m^2; k=kc*phi^3 in both runs.
root=fileparts(mfilename('fullpath'));addpath(root);
if nargin<2 || isempty(kc),kc=1.85e-8;end
validateattributes(kc,{'numeric'},{'scalar','real','finite','positive'});
if nargin<1 || isempty(output_dir)
 output_dir=fullfile(root,'..','Output',sprintf('Europa_kc_%.3e_until_depleted_%s',kc,datestr(now,'yyyymmdd_HHMMSS')));
end
if ~isfolder(output_dir),mkdir(output_dir);end
assert(~isfile(fullfile(output_dir,'checkpoint.mat')),'Use a fresh output folder.');
diary(fullfile(output_dir,'run.log'));cleanup=onCleanup(@() diary('off'));
options=struct('kc',kc,'max_steps',10000000,'final_years',Inf, ...
 'stop_on_melt_loss',true,'remaining_melt_fraction',0.005, ...
 'snapshot_steps',[0:10 25 50 100 250 500 1000], ...
 'snapshot_years',unique([logspace(-3,5,401) 0.001 0.003 0.005 0.008 0.01 0.013 0.016 0.03 0.06 0.1 0.11 0.16 0.29 0.3 0.42 0.482 0.62 0.93 1 1.24 1.84 3 5.196 10 12.73 23 30 52 93 100 140 259 455 682 1465 7041]), ...
 'snapshot_every_steps',100,'snapshot_melt_fraction_change',0.005,'snapshot_depth_change_km',0.1, ...
 'save_state_snapshots',true,'snapshot_interval_years',10,'checkpoint_steps',100, ...
 'correct_head_reference',true,'use_actual_conductivity_timestep',true, ...
 'legacy_outputs',false,'evolve_tracers',false,'output_dir',output_dir);
source_dir=fullfile(output_dir,'source');if ~isfolder(source_dir),mkdir(source_dir);end
copyfile(fullfile(root,'*.m'),source_dir);
copyfile(fullfile(root,'..','initial_conditions','ic03321_100.mat'),fullfile(output_dir,'ic03321_100.mat'));
save(fullfile(output_dir,'run_options.mat'),'options');
fid=fopen(fullfile(output_dir,'run_configuration.json'),'w');fprintf(fid,'%s',jsonencode(options));fclose(fid);
fprintf('START EUROPA DEPLETION: kc=%.12g m2; k=kc*phi^3; stop at <=0.5 percent initial melt integrated over all z>=0 cells. No final-year cutoff.\n',kc);
try
 r=run_darcy_stokes_case('impact_melt_europa',options);
 assert(strcmp(r.status,'melt_depleted') && r.depletion_reached, ...
  'Melt-depletion criterion not reached; inspect saved status.');
 b=r.melt_budget;
 summary=struct('status',r.status,'kc_m2',r.kc,'time_years',r.history(end,1),'steps',r.completed_steps, ...
  'initial_shell_melt_km3',r.initial_shell_melt_m3/1e9,'remaining_shell_melt_km3',b.liquid_volume_m3(end,2)/1e9, ...
  'remaining_fraction',r.remaining_shell_melt_fraction,'target_fraction',options.remaining_melt_fraction, ...
  'delivered_net_km3',b.delivered_net_m3(end)/1e9,'refrozen_net_shell_km3',b.refrozen_net_m3(end,2)/1e9);
 fid=fopen(fullfile(output_dir,'summary.json'),'w');fprintf(fid,'%s',jsonencode(summary));fclose(fid);
 fid=fopen(fullfile(output_dir,'COMPLETE.txt'),'w');fprintf(fid,'Depletion criterion reached: fraction %.12g after %.12g years, %d steps.\n',r.remaining_shell_melt_fraction,r.history(end,1),r.completed_steps);fclose(fid);
 fprintf('EUROPA_DEPLETION_COMPLETE %s\n',jsonencode(summary));
catch err
 fid=fopen(fullfile(output_dir,'FAILED.txt'),'w');fprintf(fid,'%s\n',getReport(err,'extended','hyperlinks','off'));fclose(fid);
 fprintf('EUROPA_DEPLETION_FAILED %s\n',err.message);rethrow(err);
end
end
