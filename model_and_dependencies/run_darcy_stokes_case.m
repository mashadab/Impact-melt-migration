function result = run_darcy_stokes_case(case_key,options)
% One S3-derived solver, three setup keys. Options may override fn, eta_0, E_a, kc.
% Example: r=run_darcy_stokes_case('porosity_wave',struct('max_steps',1));
% Example: r=run_darcy_stokes_case('impact_melt_europa',struct('max_steps',3));
if nargin<2,options=struct();end
case_key=validatestring(case_key,{'porosity_wave','impact_melt_europa','centered_water'});
fn='03321';eta_0=1e14;E_a=50e3;
if strcmp(case_key,'porosity_wave'),kc=5.6e-11;else,kc=1.85e-8;end
if isfield(options,'fn'),fn=options.fn;end
if isfield(options,'eta_0'),eta_0=options.eta_0;end
if isfield(options,'E_a'),E_a=options.E_a;end
if isfield(options,'kc'),kc=options.kc;end
result=darcy_stokes_2D_cases(case_key,fn,eta_0,E_a,kc,'effe_vel','case_setup',options);
end
