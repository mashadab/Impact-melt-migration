function result=run_centered_water_cold_bottom_S3(final_years,output_dir)
% Separate minimal copy of corrected S3 centered body; bottom half -20 C.
% r=run_centered_water_cold_bottom_S3(100); % fresh initial condition
if nargin<1,final_years=100;end
root=fileparts(mfilename('fullpath'));addpath(root);
if nargin<2
 output_dir=fullfile(root,'..','Output',['centered_cold_bottom_S3_' datestr(now,'yyyymmdd_HHMMSS')]);
end
assert(~isfolder(output_dir),'Choose a new output directory; previous runs are preserved.');
mkdir(output_dir);
mkdir(fullfile(output_dir,'source'));
for name={'darcy_stokes_2D_centered_cold_bottom_S3.m','run_centered_water_cold_bottom_S3.m', ...
 'centered_cold_bottom_heat_budget.m','record_centered_water_step.m','centered_blob_diagnostics.m', ...
 'build_stokes_grid_cyl.m','build_grid.m','build_ops.m','build_bnd.m','solve_lbvp.m', ...
 'comp_mean.m','comp_mean_corners.m','barrViscPhase.m','enthMelt.m','flux_upwind.m', ...
 'build_adv_op.m','smoothness.m','comp_limiter.m'}
 copyfile(fullfile(root,name{1}),fullfile(output_dir,'source',name{1}));
end
for name={'configuration.json','minimal_changes.diff','source_hashes.json','baseline_shared_solver.m.txt'}
 if isfile(fullfile(root,name{1})),copyfile(fullfile(root,name{1}),fullfile(output_dir,name{1}));end
end
diary(fullfile(output_dir,'run.log'));clean=onCleanup(@()diary('off')); %#ok<NASGU>
options=struct('max_steps',200000,'final_years',final_years, ...
 'snapshot_steps',[0 1:10 25 50 100],'snapshot_interval_years',.1, ...
 'checkpoint_steps',250,'correct_head_reference',true, ...
 'use_actual_conductivity_timestep',true,'stop_on_melt_loss',false, ...
 'evolve_tracers',false,'legacy_outputs',false,'output_dir',output_dir);
kc=1.85e-8;
try
 initial_options=options;initial_options.initial_only=true;
 initial=darcy_stokes_2D_centered_cold_bottom_S3('centered_water','03321',1e14,50e3,kc,'effe_vel','case_setup',initial_options);
 initial_state=initial.final_state;initial_state.d_m=initial.length_scale_m;
 initial_state.T_K=initial_state.T_dimensionless*173+100;
 save(fullfile(output_dir,'initial_state.mat'),'initial_state');
 G=initial.Grid.p;[X,Z]=meshgrid(G.xc*initial.length_scale_m,G.yc*initial.length_scale_m);
 lower=Z(:)<4000;
 assert(all(abs(initial_state.T_K(lower)-253.15)<1e-10));
 assert(all(initial_state.T_K(~lower)==273));
 assert(isequal(initial_state.phi,double(X(:)>5000 & X(:)<15000 & Z(:)>4000)));
 assert(initial.permeability_exponent==3 && strcmp(G.geom,'cartesian'));
 assert(isequal([G.Nx G.Ny],[100 120]) && initial.enthalpy_dirichlet_count==0);
 verification=struct('initial_condition_passed',true,'cold_lower_half_K',253.15, ...
  'upper_half_K',273,'lower_z_range_m',[-2000 4000],'kc_m2',kc, ...
  'permeability_exponent',3,'initial_liquid_m3_per_m_depth',sum(initial_state.phi.*G.V)*initial.length_scale_m^2);
 write_json('initial_verification.json',verification);
 result=darcy_stokes_2D_centered_cold_bottom_S3('centered_water','03321',1e14,50e3,kc,'effe_vel','case_setup',options);
 result.test_variant='centered_water_cold_bottom';
 result.initial_bottom_temperature_K=253.15;
 save(result.output_file,'result');
 initial_energy_magnitude=sum(abs(initial_state.H).*G.V);
 summary=struct('status',result.status,'step',result.completed_steps, ...
  'time_years',result.time_years(end),'target_years',final_years, ...
  'test_variant',result.test_variant,'kc_m2',kc,'permeability_exponent',3, ...
  'enthalpy_error_relative_initial_absolute_energy',result.max_enthalpy_balance_error/initial_energy_magnitude, ...
  'max_boundary_flux_dimensionless',max([result.max_boundary_solid_flux result.max_boundary_darcy_flux ...
  result.max_boundary_advective_heat_flux result.max_boundary_conductive_heat_flux]));
 assert(summary.max_boundary_flux_dimensionless<1e-12);
 assert(summary.enthalpy_error_relative_initial_absolute_energy<1e-8);
 write_json('summary.json',summary);
 writetable(array2table(result.history,'VariableNames',result.history_columns),fullfile(output_dir,'history.csv'));
 if strcmp(result.status,'completed')
  assert(result.time_years(end)>=final_years-1e-10);
  fid=fopen(fullfile(output_dir,'COMPLETE.txt'),'w');fprintf(fid,'Reached %.17g years in %d steps.\n',result.time_years(end),result.completed_steps);fclose(fid);
 end
 fprintf('COLD_BOTTOM_CENTERED %s\nOUTPUT %s\n',jsonencode(summary),output_dir);
catch exception
 record=struct('status','failed','message',exception.message,'report',getReport(exception,'extended','hyperlinks','off'));
 write_json('error.json',record);rethrow(exception)
end
 function write_json(name,value)
  fid=fopen(fullfile(output_dir,name),'w');assert(fid>=0);fprintf(fid,'%s',jsonencode(value));fclose(fid);
 end
end
