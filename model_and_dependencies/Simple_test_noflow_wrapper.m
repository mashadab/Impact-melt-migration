function results = Simple_test_noflow_wrapper(max_steps,case_indices)
% Run the separate closed/insulated-domain solver; original files are untouched.
% NEW FILE NF-WRAPPER: all code in this wrapper was added for this test.
% Examples:
%   Simple_test_noflow_wrapper(1000);       % all three kc values and plots
%   Simple_test_noflow_wrapper(1000,3);     % kc=1.85e-8 only
if nargin<1, max_steps=1000; end
if nargin<2, case_indices=1:3; end
% NEW SECTION NF-WRAPPER: case settings and isolated output directory.
kc_values=[0 1.85e-12 1.85e-8];
validateattributes(case_indices,{'numeric'},{'vector','integer','>=',1,'<=',3});
model_dir=fileparts(mfilename('fullpath'));
options=struct('max_steps',max_steps,'snapshot_steps',unique([0 round(max_steps*[.1 .25 .5 1])]), ...
    'legacy_outputs',false,'evolve_tracers',false,'stop_on_melt_loss',false, ...
    'output_dir',fullfile(model_dir,'..','Output',sprintf('closed_lid_%d_steps',max_steps)));
results=cell(size(kc_values));
% NEW SECTION NF-WRAPPER: run cases and check all boundaries and total enthalpy.
for j=case_indices
    results{j}=simple_test_1D_noflow_base('03321',1e14,50e3,kc_values(j), ...
        'effe_vel','temprate_homog_column',options);
    assert(strcmp(results{j}.status,'completed') && results{j}.completed_steps==max_steps, ...
        'No-flow run failed before reaching the requested step count; inspect the saved result.');
    a=results{j};
    assert(a.enthalpy_dirichlet_count==0,'Enthalpy must evolve freely in every cell.');
    assert(max([a.max_boundary_solid_flux a.max_boundary_darcy_flux ...
        a.max_boundary_advective_heat_flux a.max_boundary_conductive_heat_flux])<1e-12, ...
        'A closed/insulated boundary flux check failed.');
    assert(a.max_enthalpy_balance_error<1e-8*abs(a.initial_enthalpy_total), ...
        'Closed-domain global enthalpy conservation failed.');
end
% NEW SECTION NF-WRAPPER: generate temperature and melt-fraction plots.
if numel(case_indices)==numel(kc_values)
    plot_simple_noflow_results(options.output_dir);
end
end
