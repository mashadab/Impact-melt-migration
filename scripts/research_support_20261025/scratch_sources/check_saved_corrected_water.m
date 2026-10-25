root='C:/Users/lenovo/Desktop/Research/Impact-melt-migration';
addpath(fullfile(root,'model_and_dependencies'));
audit=strtrim(fileread(fullfile(root,'tmp','centered_water_verification_output.txt')));
verify_centered_water_S3(audit,true); % examine actual saved states, no additional evolution
