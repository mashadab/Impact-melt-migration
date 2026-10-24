function verify_Europa_independent_replica
% Independent MATLAB-process comparison against the live long run; no changes to solver.
root=fileparts(mfilename('fullpath'));addpath(root);
reference_dir=fullfile(root,'..','Output','Europa_kc_1.850e-08_until_depleted_20261023_195524');
out=fullfile(root,'..','Output',['Europa_independent_replica_100steps_' datestr(now,'yyyymmdd_HHMMSS')]);
mkdir(out);diary(fullfile(out,'verification.log'));cleanup=onCleanup(@() diary('off'));
solver=which('darcy_stokes_2D_cases');
assert(strcmpi(solver,fullfile(root,'darcy_stokes_2D_cases.m')),'Unexpected solver path');
assert(isequal(fileread(solver),fileread(fullfile(reference_dir,'source','darcy_stokes_2D_cases.m'))));
s=load(fullfile(reference_dir,'run_options.mat'),'options');o=s.options;
o.max_steps=100;o.output_dir=out;
fprintf('INDEPENDENT_REPLICA solver=%s\ncase=impact_melt_europa kc=%.12g steps=100. All other options copied from long run.\n',solver,o.kc);
r=run_darcy_stokes_case('impact_melt_europa',o);
assert(r.completed_steps==100 && strcmp(r.status,'step_limit'));
assert(r.permeability_exponent==3);
files=dir(fullfile(out,'states','state_*.mat'));
fields={'temperature_K','phi','enthalpy_dimensionless','solid_velocity_m_s','fluid_velocity_m_s', ...
 'darcy_flux_m_s','pressure_head_Pa','fluid_pressure_Pa','overpressure_Pa','time_years','flow_time_years'};
max_difference=zeros(size(fields));identical=true;steps=zeros(1,numel(files));
for k=1:numel(files)
 a=load(fullfile(out,'states',files(k).name),'state');
 b=load(fullfile(reference_dir,'states',files(k).name),'state');
 steps(k)=a.state.step;identical=identical && isequaln(a.state,b.state);
 for j=1:numel(fields)
  x=a.state.(fields{j});y=b.state.(fields{j});
  assert(isequal(size(x),size(y)),'Field size differs');
  d=abs(x(:)-y(:));d=d(isfinite(d));
  if ~isempty(d),max_difference(j)=max(max_difference(j),max(d));end
 end
end
for attempt=1:5
 try
  q=load(fullfile(reference_dir,'noflow_kc_1.850e-08.mat'),'result');
  assert(numel(q.result.melt_budget.time_years)>=101);
  break;
 catch err
  if attempt==5,rethrow(err);end;pause(1);
 end
end
budget_identical=isequaln(r.melt_budget.history,q.result.melt_budget.history(1:101,:));
checks_identical=isequaln(r.history,q.result.history(1:100,:));
assert(isequal(fileread(solver),fileread(fullfile(reference_dir,'source','darcy_stokes_2D_cases.m'))),'Solver changed during comparison');
report=struct('solver_path',solver,'reference_dir',reference_dir,'replica_dir',out, ...
 'kc_m2',r.kc,'permeability_exponent',r.permeability_exponent,'completed_steps',r.completed_steps, ...
 'time_years',r.time_years(end),'saved_states_compared',numel(files),'steps_compared',sort(steps), ...
 'all_states_bitwise_identical',identical,'melt_budget_bitwise_identical',budget_identical, ...
 'thermal_flux_energy_history_bitwise_identical',checks_identical,'compared_fields',{fields}, ...
 'maximum_absolute_differences',max_difference);
fid=fopen(fullfile(out,'comparison_report.json'),'w');fprintf(fid,'%s',jsonencode(report));fclose(fid);
disp(table(fields(:),max_difference(:),'VariableNames',{'field','maximum_absolute_difference'}));
fprintf('REPLICA_COMPARISON %s\n',jsonencode(report));
assert(identical && budget_identical && checks_identical,'Replica comparison differs; inspect saved report.');
end
