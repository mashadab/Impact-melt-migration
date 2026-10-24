function run_S3_800_uninterrupted()
% Standalone full run; no model/API calls are made by this MATLAB program.
root=fileparts(mfilename('fullpath'));
out=fullfile(root,'..','Output','s3_800_uninterrupted');
if ~isfolder(out), mkdir(out); end
if isfile(fullfile(out,'s3_wave.mat'))
 error('Output already exists. Choose a fresh folder before starting again.');
end
options=struct('max_steps',50000,'final_years',800, ...
 'snapshot_years',0:5:800,'output_dir',out);
try
 r=simple_test_S3_copy(options);
 assert(strcmp(r.status,'completed'),'Run reached step limit before 800 years.');
 plot_S3_copy_results(r); make_S3_video(r);
 fid=fopen(fullfile(out,'COMPLETE.txt'),'w');
 fprintf(fid,'Reached %.12g years in %d steps.\n',r.history(end,1),r.completed_steps);
 fprintf(fid,'Temperature range: %.12g to %.12g K.\n',min(r.final_temperature_K),max(r.final_temperature_K));
 fclose(fid);
 fprintf('S3_800_COMPLETE years=%.12g steps=%d\n',r.history(end,1),r.completed_steps);
catch err
 fid=fopen(fullfile(out,'FAILED.txt'),'w');
 fprintf(fid,'%s\n',getReport(err,'extended','hyperlinks','off')); fclose(fid);
 rethrow(err);
end
end
