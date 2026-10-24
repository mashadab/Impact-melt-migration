function run_Europa_10000(output_dir)
% 10,000-year Europa case using the shared S3-derived equations.
root=fileparts(mfilename('fullpath'));addpath(root);
if nargin<1
 output_dir=fullfile(root,'..','Output',['Europa_kc_1.850e-16_10000yr_' datestr(now,'yyyymmdd_HHMMSS')]);
end
if ~isfolder(output_dir),mkdir(output_dir);end
assert(~isfile(fullfile(output_dir,'checkpoint.mat')),'Existing checkpoint: use a fresh output directory.');
diary(fullfile(output_dir,'run.log'));cleanup=onCleanup(@() diary('off'));
options=struct('kc',1.85e-16,'max_steps',10000000,'final_years',10000, ...
 'snapshot_steps',[0 1 10 100 1000],'snapshot_interval_years',25,'checkpoint_steps',100, ...
 'correct_head_reference',true,'use_actual_conductivity_timestep',true, ...
 'stop_on_melt_loss',false,'legacy_outputs',false,'evolve_tracers',false,'output_dir',output_dir);
fid=fopen(fullfile(output_dir,'run_configuration.json'),'w');fprintf(fid,'%s',jsonencode(options));fclose(fid);
fprintf('START EUROPA: kc=1.85e-16 m2, target=10000 years, shell+lower domain, initial lower phi=0 T=273K.\n');
try
 r=run_darcy_stokes_case('impact_melt_europa',options);
 assert(strcmp(r.status,'completed') && abs(r.history(end,1)-10000)<1e-7, ...
  'Run stopped before the target; inspect status and saved fields.');
 assert(r.max_base_solid_flux<1e-10 && r.max_base_darcy_flux==0,'Nonzero basal material flux');
 b=r.melt_budget;
 summary=struct('kc_m2',r.kc,'time_years',r.history(end,1),'completed_steps',r.completed_steps, ...
  'melt_initial_km3',b.initial_volume_m3(1)/1e9,'melt_shell_km3',b.liquid_volume_m3(end,2)/1e9, ...
  'melt_lower_region_km3',b.liquid_volume_m3(end,3)/1e9,'delivered_net_km3',b.delivered_net_m3(end)/1e9, ...
  'refrozen_net_domain_km3',b.refrozen_net_m3(end,1)/1e9);
 fid=fopen(fullfile(output_dir,'summary.json'),'w');fprintf(fid,'%s',jsonencode(summary));fclose(fid);
 fid=fopen(fullfile(output_dir,'COMPLETE.txt'),'w');fprintf(fid,'Reached %.12g years in %d steps.\n',r.history(end,1),r.completed_steps);fclose(fid);
 fprintf('EUROPA_10000_COMPLETE %s\n',jsonencode(summary));
catch err
 fid=fopen(fullfile(output_dir,'FAILED.txt'),'w');fprintf(fid,'%s\n',getReport(err,'extended','hyperlinks','off'));fclose(fid);
 fprintf('EUROPA_10000_FAILED %s\n',err.message);
 rethrow(err);
end
end
