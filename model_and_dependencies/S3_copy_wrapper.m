function result = S3_copy_wrapper(max_steps,final_years)
% Exact full-resolution S3 realization. No resampling of the input wave.
% S3_copy_wrapper(1,0.5) is a one-step smoke run.
% S3_copy_wrapper(50000,800) requests the full benchmark.
if nargin<1, max_steps=50000; end
if nargin<2, final_years=800; end
root=fileparts(mfilename('fullpath'));
options=struct('max_steps',max_steps,'final_years',final_years, ...
 'output_dir',fullfile(root,'..','Output',sprintf('s3_thermal_wave_%d_steps',max_steps)));
result=simple_test_S3_copy(options);
plot_S3_copy_results(result);
make_S3_video(result);
end
