function result=run_centered_blob_continuation(output_dir)
% Verify a restart, then continue the saved centered-water case unchanged.
if nargin<1
 root=fileparts(fileparts(mfilename('fullpath')));
 output_dir=strtrim(fileread(fullfile(root,'tmp','centered_continuation_output.txt')));
end
config=jsondecode(fileread(fullfile(output_dir,'configuration.json')));
source_dir=fullfile(output_dir,'source');addpath(source_dir);
path_clean=onCleanup(@()rmpath(source_dir)); %#ok<NASGU>
diary(fullfile(output_dir,'run.log'));diary_clean=onCleanup(@()diary('off')); %#ok<NASGU>
copyfile([mfilename('fullpath') '.m'],fullfile(source_dir,'run_centered_blob_continuation.m.txt'));
try
 write_json(fullfile(output_dir,'progress.json'),struct('status','verifying_restart', ...
  'target_years',config.target_years,'message','Uninterrupted 101-step reference versus 100+1 restart.'));
 direct_dir=fullfile(output_dir,'verification_direct');mkdir(direct_dir);mkdir(fullfile(direct_dir,'states'));
 direct_options=options_for(direct_dir,101,config.target_years,'');
 direct=centered_blob_continuation_driver('03321',1e14,50e3,config.kc,'effe_vel','temprate_homog_column',direct_options);
 prior=load(config.restart_file,'result');prior=prior.result;
 a=load(fullfile(direct_dir,'states','state_00000100.mat'),'checkpoint');a=a.checkpoint;
 errors=struct;
 errors.reference_100_H_max_abs=max(abs(a.H-prior.final_state.H));
 errors.reference_100_phi_max_abs=max(abs(a.phi-prior.final_state.phi));
 errors.reference_100_T_max_abs=max(abs(a.T_dimensionless-prior.final_state.T_dimensionless));
 assert(max([errors.reference_100_H_max_abs errors.reference_100_phi_max_abs errors.reference_100_T_max_abs])<1e-13, ...
  'The instrumented driver does not reproduce the original saved 100-step state.');
 resumed_dir=fullfile(output_dir,'verification_resumed');mkdir(resumed_dir);mkdir(fullfile(resumed_dir,'states'));
 resumed_options=options_for(resumed_dir,101,config.target_years,config.restart_file);
 resumed=centered_blob_continuation_driver('03321',1e14,50e3,config.kc,'effe_vel','temprate_homog_column',resumed_options);
 for name={'H','phi','T_dimensionless','v_s_dimensionless','q_r_dimensionless','p_head_dimensionless'}
  key=name{1};u=direct.final_state.(key);v=resumed.final_state.(key);
  errors.([key '_101_max_abs'])=max(abs(u-v));
  errors.([key '_101_relative_L2'])=norm(u-v)/max(norm(u),realmin);
  assert(norm(u-v)<=1e-12*max(norm(u),realmin)+1e-16,'Restart mismatch in %s.',key);
 end
 errors.time_101_abs_years=abs(direct.time_years(end)-resumed.time_years(end));
 assert(errors.time_101_abs_years<1e-15);
 errors.passed=true;write_json(fullfile(output_dir,'restart_verification.json'),errors);
 fprintf('CENTERED_RESTART_VERIFIED %s\n',jsonencode(errors));
 % The long calculation starts from the original saved step 100, not the replay.
 mkdir(fullfile(output_dir,'states'));
 copyfile(fullfile(config.restart_run,'initial_state.mat'),fullfile(output_dir,'original_initial_state.mat'));
 copyfile(config.restart_file,fullfile(output_dir,'restart_input.mat'));
 copyfile(fullfile(direct_dir,'states','state_00000100.mat'),fullfile(output_dir,'states','state_00000100.mat'));
 options=options_for(output_dir,200000,config.target_years,fullfile(output_dir,'restart_input.mat'));
 result=centered_blob_continuation_driver('03321',1e14,50e3,config.kc,'effe_vel','temprate_homog_column',options);
 progress=struct('status',result.status,'step',result.completed_steps, ...
  'time_years',result.time_years(end),'target_years',config.target_years, ...
  'wall_seconds',result.wall_seconds,'restart_verified',true);
 write_json(fullfile(output_dir,'progress.json'),progress);
 writetable(array2table(result.history,'VariableNames',result.history_columns),fullfile(output_dir,'history.csv'));
 fprintf('CENTERED_CONTINUATION_STOPPED %s\n%s\n',output_dir,jsonencode(progress));
catch exception
 error_record=struct('status','failed','message',exception.message,'identifier',exception.identifier, ...
  'report',getReport(exception,'extended','hyperlinks','off'));
 write_json(fullfile(output_dir,'error.json'),error_record);
 write_json(fullfile(output_dir,'progress.json'),error_record);rethrow(exception)
end
end
function options=options_for(out,max_steps,final_years,restart)
options=struct('max_steps',max_steps,'snapshot_steps',[0 1:10 50 100 101 150 200], ...
 'save_every_steps',250,'final_years',final_years,'restart_file',restart, ...
 'legacy_outputs',false,'evolve_tracers',false,'stop_on_melt_loss',false,'output_dir',out);
end
function write_json(path,value)
fid=fopen(path,'w');assert(fid>=0);fprintf(fid,'%s',jsonencode(value));fclose(fid);
end
