function result = Europa_wrapper_noflow(options)
% Europa impact setup using the working S3 solver as the baseline.
% Run Europa_wrapper_noflow(struct('max_steps',3)) for a short check.
% Basal heat defaults to zero; set options.basal_heat_flux=1 for geothermal heat.
if nargin<1, options=struct(); end
result=impactorTempMeltFuncDarcyStokesModPresForm2Stokes_Europa_noflow( ...
    '03321',1e14,50e3,1.85e-8,'effe_vel','Europa_impact',options);
end
