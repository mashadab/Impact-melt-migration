function inspection = inspect_S3_steps()
% Compare the saved full-run step-60 checkpoint with the verified step-1 run.
root=fileparts(mfilename('fullpath')); out=fullfile(root,'..','Output','s3_inspect_steps_1_60');
if ~isfolder(out), mkdir(out); end
b=load(fullfile(root,'..','Output','s3_thermal_wave_50000_steps','s3_wave.mat'),'result'); b=b.result;
a=load(fullfile(root,'..','Output','s3_thermal_wave_1_steps','s3_wave.mat'),'result'); a=a.result;
fprintf('Saved history reaches step %d; checkpoint time %.9g years\n',b.completed_steps,b.checkpoint_years);
assert(size(b.history,1)>=60 && abs(b.checkpoint_years-b.history(60,1))<1e-10);
b.history=b.history(1:60,:);
assert(a.completed_steps==1 && isequal(a.initial_phi,b.initial_phi));
assert(abs(a.history(1,1)-b.history(1,1))<1e-12);
assert(max(abs(a.history(1,:)-b.history(1,:)))<1e-8);
inspection=struct('steps',[0 1 60],'time_years',[0 a.history(1,1) b.checkpoint_years], ...
 'phi',[b.initial_phi a.final_phi b.checkpoint_phi], ...
 'temperature_K',[273*ones(b.Grid.p.N,1) a.final_temperature_K b.checkpoint_temperature_K], ...
 'H',[b.initial_H a.final_H b.checkpoint_H], ...
 'x_m',b.x_m,'z_m',b.z_m,'history',b.history,'history_columns',{b.history_columns});
save(fullfile(out,'steps_1_60.mat'),'inspection','-v7.3');
ny=b.Grid.p.Ny; nx=b.Grid.p.Nx;
f=figure('Visible','off','Color','w','Position',[40 40 1200 1000]);
tiledlayout(2,3,'TileSpacing','compact');
for j=1:3
 nexttile(j); imagesc(b.x_m/1000,b.z_m/1000,reshape(inspection.phi(:,j),ny,nx));
 axis xy equal tight; caxis([min(b.initial_phi) max(b.initial_phi)]); colorbar;
 xlabel('x [km]'); ylabel('Elevation [km]');
 title(sprintf('Melt fraction: step %d, %.4f yr',inspection.steps(j),inspection.time_years(j)));
 nexttile(j+3); imagesc(b.x_m/1000,b.z_m/1000,reshape(inspection.temperature_K(:,j)-273,ny,nx));
 axis xy equal tight; caxis([-1e-10 1e-10]); colorbar;
 xlabel('x [km]'); ylabel('Elevation [km]'); title(sprintf('T - 273 K: step %d',inspection.steps(j)));
end
exportgraphics(f,fullfile(out,'melt_temperature_steps_1_60.png'),'Resolution',150); close(f);
f=figure('Visible','off','Color','w','Position',[40 40 1100 700]); tiledlayout(2,2);
cols=[128 129];
nexttile; hold on;
for j=1:3
 P=reshape(inspection.phi(:,j),ny,nx); plot(mean(P(:,cols),2),b.z_m/1000,'LineWidth',1.5);
end
xlabel('Melt fraction, central two columns'); ylabel('Elevation [km]');
legend('Initial','Step 1','Step 60'); ylim([7.2 8.2]); grid on;
nexttile; plot([0;b.history(:,1)],[b.initial_peak_z_m;b.history(:,2)]/1000,'r-'); hold on;
t=[0;b.history(:,1)]; plot(t,(b.initial_peak_z_m-b.expected_speed_m_yr*t)/1000,'b--');
xlabel('Time [years]'); ylabel('Peak elevation [km]'); legend('Grid peak','Theory 5w0'); grid on;
nexttile; plot(b.history(:,1),b.history(:,8:9)-273); xlabel('Time [years]'); ylabel('T - 273 K'); legend('Minimum','Maximum'); grid on;
nexttile; plot(b.history(:,1),b.history(:,[4 10])); xlabel('Time [years]'); ylabel('Relative conservation error'); legend('Melt','Enthalpy'); grid on;
exportgraphics(f,fullfile(out,'profiles_and_diagnostics.png'),'Resolution',150); close(f);
preview=b; preview.options.output_dir=out; preview.snapshot_phi=inspection.phi;
preview.snapshot_temperature_K=inspection.temperature_K; preview.snapshot_years=inspection.time_years;
make_S3_video(preview);
fid=fopen(fullfile(out,'inspection_summary.txt'),'w');
for j=2:3
 h=b.history(inspection.steps(j),:);
 line=sprintf('step=%d time=%.9g yr phi=[%.12g %.12g] T=[%.12g %.12g] peak_z=%.9g m melt_error=%.3g H_error=%.3g residual=%.3g', ...
 inspection.steps(j),inspection.time_years(j),min(inspection.phi(:,j)),max(inspection.phi(:,j)), ...
 min(inspection.temperature_K(:,j)),max(inspection.temperature_K(:,j)),h(2),h(4),h(10),h(7));
 fprintf('%s\n',line); fprintf(fid,'%s\n',line);
end
fprintf('initial_peak=%.9g m expected_displacement_step60=%.9g m actual_grid_peak_displacement=%.9g m\n', ...
 b.initial_peak_z_m,b.expected_speed_m_yr*b.checkpoint_years,b.initial_peak_z_m-b.history(60,2));
fclose(fid);
end
