addpath('C:/Users/lenovo/Desktop/Research/Impact-melt-migration/model_and_dependencies');
out=strtrim(fileread('C:/Users/lenovo/Desktop/Research/Impact-melt-migration/tmp/flat_centered_video_output.txt'));
timer=tic;
while ~isfile(fullfile(out,'video_comparison.json')) && toc(timer)<180,pause(2);end
assert(isfile(fullfile(out,'video_comparison.json')),'Video rendering has not completed.');
verify_flat_and_centered_water_videos;
