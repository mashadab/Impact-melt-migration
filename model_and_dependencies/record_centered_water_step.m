function stop_requested=record_centered_water_step(options,step,time_years,flow_time_years,diagnostic,T,Grid,d,energy_error,initial_energy,snapshot_due)
% Read-only output for the centered_water case of the shared S3 solver.
stop_requested=isfile(fullfile(options.output_dir,'STOP_REQUESTED'));
reached_time=time_years>=options.final_years-1e-10;
row=diagnostic.row;row.step=step;row.flow_time_years=flow_time_years;
row.time_years=time_years;row.dt_years=diagnostic.dt_years;
row.relative_enthalpy_error=energy_error/initial_energy;
names=fieldnames(row);values=cellfun(@(name)row.(name),names);
path=fullfile(options.output_dir,'diagnostics.csv');
if step==1
 fid=fopen(path,'w');assert(fid>=0);fprintf(fid,'%s\n',strjoin(names,','));fclose(fid);
end
fid=fopen(path,'a');assert(fid>=0);fprintf(fid,'%.17g',values(1));
fprintf(fid,',%.17g',values(2:end));fprintf(fid,'\n');fclose(fid);
if snapshot_due || mod(step,options.checkpoint_steps)==0 || stop_requested || reached_time
 folder=fullfile(options.output_dir,'states');if ~isfolder(folder),mkdir(folder);end
 checkpoint=struct('step',step,'time_years',time_years,'flow_time_years',flow_time_years, ...
  'H',diagnostic.H_after,'T_dimensionless',T, ...
  'phi',diagnostic.phi_after,'Grid',Grid,'d_m',d,'dt_years',diagnostic.dt_years, ...
  'solid_velocity_m_s',diagnostic.solid_velocity_m_s, ...
  'darcy_flux_m_s',diagnostic.darcy_flux_m_s, ...
  'pressure_head_dimensionless',diagnostic.pressure_head_dimensionless,'diagnostic',diagnostic);
 checkpoint.diagnostic.row=row;
 save(fullfile(folder,sprintf('state_%08d.mat',step)),'checkpoint');
end
progress=row;progress.status='running';progress.target_years=options.final_years;
progress.solver='darcy_stokes_2D_cases';progress.case_key='centered_water';
progress.correct_head_reference=options.correct_head_reference;
if stop_requested,progress.status='stopped_by_user';elseif reached_time,progress.status='completed';end
fid=fopen(fullfile(options.output_dir,'progress.json'),'w');assert(fid>=0);
fprintf(fid,'%s',jsonencode(progress));fclose(fid);
end
