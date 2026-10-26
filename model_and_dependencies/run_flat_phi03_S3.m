function result=run_flat_phi03_S3(final_years,output_dir)
% Corrected S3 flat upper layer: initial phi=0.3 above, phi=0 below, T=273 K.
% Defaults to the same final time as the earlier centered-body video.
if nargin<1,final_years=8.89348313212041;end
root=fileparts(mfilename('fullpath'));addpath(root,'-begin');
if nargin<2
 output_dir=fullfile(root,'..','Output',['flat_phi03_S3_' datestr(now,'yyyymmdd_HHMMSS')]);
end
if ~isfolder(output_dir),mkdir(output_dir);end
assert(~isfile(fullfile(output_dir,'initial_state.mat')),'Previous results must be preserved.');
diary(fullfile(output_dir,'run.log'));clean=onCleanup(@()diary('off')); %#ok<NASGU>
options=struct('max_steps',200000,'final_years',final_years, ...
 'snapshot_steps',[0 1:10 25 50 100],'snapshot_interval_years',.1, ...
 'checkpoint_steps',250,'correct_head_reference',true, ...
 'use_actual_conductivity_timestep',true,'stop_on_melt_loss',false, ...
 'evolve_tracers',false,'legacy_outputs',false,'output_dir',output_dir);
try
 initial_options=options;initial_options.initial_only=true;
 initial=darcy_stokes_2D_flat_phi03_S3('centered_water','03321',1e14,50e3,1.85e-8,'effe_vel','case_setup',initial_options);
 initial_state=initial.final_state;initial_state.d_m=initial.length_scale_m;
 initial_state.T_K=initial_state.T_dimensionless*173+100;
 G=initial.Grid.p;d=initial.length_scale_m;[X,Z]=meshgrid(G.xc*d,G.yc*d);
 mask=Z(:)>4000;
 assert(isequal(initial_state.phi,.3*double(mask)));
 assert(all(initial_state.phi(Z(:)<4000)==0));
 assert(all(initial_state.T_K==273));
 assert(isequal([G.Nx G.Ny],[100 120]) && strcmp(G.geom,'cartesian'));
 assert(initial.permeability_exponent==3 && initial.enthalpy_dirichlet_count==0);
 save(fullfile(output_dir,'initial_state.mat'),'initial_state');
 verification=struct('status','passed','initial_upper_half_phi',.3,'initial_bottom_half_phi',0, ...
  'initial_temperature_K',273,'mesh',[G.Nx G.Ny], ...
  'initial_liquid_m3_per_m_depth',sum(initial_state.phi.*G.V)*d^2, ...
  'enthalpy_dirichlet_count',initial.enthalpy_dirichlet_count);
 write_json('initial_verification.json',verification);
 fprintf('INITIAL_PHI03_VERIFIED %s\n',jsonencode(verification));
 result=darcy_stokes_2D_flat_phi03_S3('centered_water','03321',1e14,50e3,1.85e-8,'effe_vel','case_setup',options);
 result.test_variant='flat_phi03';result.initial_upper_half_porosity=.3;
 save(result.output_file,'result');
 relative_energy_error=result.max_enthalpy_balance_error/abs(result.initial_enthalpy_total);
 boundary_flux=max([result.max_boundary_solid_flux result.max_boundary_darcy_flux ...
  result.max_boundary_advective_heat_flux result.max_boundary_conductive_heat_flux]);
 assert(strcmp(result.status,'completed') && abs(result.time_years(end)-final_years)<1e-10);
 assert(boundary_flux<1e-12 && relative_energy_error<1e-8);
 assert(all(isfinite(result.full_phi(:))) && all(isfinite(result.full_T_K(:))));
 assert(min(result.full_phi(:))>=-1e-10 && max(result.full_phi(:))<=1+1e-10);
 summary=struct('status',result.status,'completed_steps',result.completed_steps, ...
  'time_years',result.time_years(end),'target_years',final_years, ...
  'relative_enthalpy_error',relative_energy_error,'max_boundary_flux',boundary_flux, ...
  'T_min_K',min(result.history(:,2)),'T_max_K',max(result.history(:,3)), ...
  'initial_liquid_m3_per_m_depth',verification.initial_liquid_m3_per_m_depth, ...
  'final_liquid_m3_per_m_depth',sum(result.final_state.phi.*G.V)*d^2, ...
  'final_liquid_lower_half_m3_per_m_depth',sum(result.final_state.phi(Z(:)<4000).*G.V(Z(:)<4000))*d^2, ...
  'initial_upper_half_phi',.3,'initial_bottom_half_phi',0,'initial_temperature_K',273);
 write_json('summary.json',summary);
 writetable(array2table(result.history,'VariableNames',result.history_columns),fullfile(output_dir,'history.csv'));
 fid=fopen(fullfile(output_dir,'COMPLETE.txt'),'w');fprintf(fid,'Reached %.17g years in %d steps.\n',final_years,result.completed_steps);fclose(fid);
 fprintf('FLAT_PHI03_COMPLETE %s\n',jsonencode(summary));
catch exception
 write_json('error.json',struct('status','failed','message',exception.message, ...
  'report',getReport(exception,'extended','hyperlinks','off')));
 rethrow(exception)
end
 function write_json(name,value)
  fid=fopen(fullfile(output_dir,name),'w');assert(fid>=0);fprintf(fid,'%s',jsonencode(value));fclose(fid);
 end
end
