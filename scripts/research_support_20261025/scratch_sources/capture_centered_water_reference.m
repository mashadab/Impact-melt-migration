root='C:/Users/lenovo/Desktop/Research/Impact-melt-migration';
addpath(fullfile(root,'model_and_dependencies'));
out=strtrim(fileread(fullfile(root,'tmp','centered_water_verification_output.txt')));
diary(fullfile(out,'baseline.log'));
o=struct('max_steps',1,'snapshot_steps',[0 1], ...
 'correct_head_reference',true,'use_actual_conductivity_timestep',true, ...
 'output_dir',fullfile(out,'wave_before'));
r=run_darcy_stokes_case('porosity_wave',o);
assert(strcmp(r.status,'completed'));
clear r;
o.max_steps=3;o.snapshot_steps=[0 1 3];o.output_dir=fullfile(out,'europa_before');
r=run_darcy_stokes_case('impact_melt_europa',o);
assert(strcmp(r.status,'completed'));
diary off;
