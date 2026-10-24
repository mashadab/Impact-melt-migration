function result=porosity_wave_2D_Jake_wrapper(max_steps,use_actual_conductivity_timestep)
% Minimal setup adapter for the fixed original solver. Defaults to ONE step.
if nargin<1, max_steps=1; end
% TIMESTEP SWITCH: false = original timestep; true = actual conductivity bound.
% Example: porosity_wave_2D_Jake_wrapper(1,true)
if nargin<2, use_actual_conductivity_timestep=false; end
root=fileparts(mfilename('fullpath'));
options=struct('use_actual_conductivity_timestep',use_actual_conductivity_timestep,'max_steps',max_steps,'snapshot_steps',unique([0 1 max_steps]), ...
 'legacy_outputs',false,'evolve_tracers',false,'stop_on_melt_loss',false, ...
 'output_dir',fullfile(root,'..','Output',sprintf('s3_minimal_%d_steps',max_steps)));
if use_actual_conductivity_timestep
    options.output_dir=[options.output_dir '_actual_kappa'];
end
result=porosity_wave_2D_Jake_minimal('03321',1e14,50e3,5.6e-11, ...
 'effe_vel','temperate_blob_settle',options);
end
