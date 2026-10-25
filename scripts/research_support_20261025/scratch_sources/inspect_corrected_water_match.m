root='C:/Users/lenovo/Desktop/Research/Impact-melt-migration';
addpath(fullfile(root,'model_and_dependencies'));
audit=strtrim(fileread(fullfile(root,'tmp','centered_water_verification_output.txt')));
out=fullfile(audit,'centered_corrected_1yr');
a=load(fullfile(out,'states','state_00000001.mat'),'checkpoint');a=a.checkpoint;
b=load(fullfile(root,'Output','centered_blob_continuation_20261024_210127','analysis','forcing_control','initial_S3_reference.mat'),'flow');b=b.flow;
report=struct;
for pair={'solid_velocity_m_s','Darcy_flux_m_s'}
 key=pair{1};other=key;if strcmp(key,'Darcy_flux_m_s'),other='darcy_flux_m_s';end
 u=a.(other);v=b.(key);
 report.(key)=struct('max_abs_m_s',max(abs(u-v)),'relative_L2',norm(u-v)/norm(v), ...
  'actual_max_m_year',max(abs(u))*3.154e7,'reference_max_m_year',max(abs(v))*3.154e7);
end
report.phi_before_difference=max(abs(a.diagnostic.phi_before-b.phi));
report.T_before_difference=max(abs(a.diagnostic.T_before_K-(b.T_dimensionless*173+100)));
report.K_difference=max(abs(a.diagnostic.permeability_m2-b.K_m2));
report.grid_identical=isequaln(a.Grid,b.Grid);
disp(jsonencode(report));
fid=fopen(fullfile(audit,'initial_flow_comparison.json'),'w');fprintf(fid,'%s',jsonencode(report));fclose(fid);
plot_centered_water_S3(out);
