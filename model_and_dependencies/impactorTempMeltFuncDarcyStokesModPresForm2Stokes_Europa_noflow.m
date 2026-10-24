function result = impactorTempMeltFuncDarcyStokesModPresForm2Stokes_Europa_noflow(fn,eta_0,E_a,kc,test,simple_test,options)
% Compatibility entry point: all equations now live in the shared S3 copy.
if nargin<7,options=struct();end
result=darcy_stokes_2D_cases('impact_melt_europa',fn,eta_0,E_a,kc,test,simple_test,options);
end
