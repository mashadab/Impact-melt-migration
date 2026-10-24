function result = plot_S3_copy_results(result)
% Unmasked melt fraction and peak trajectory; shared color scale.
if nargin<1
 root=fileparts(mfilename('fullpath'));
 d=load(fullfile(root,'..','Output','s3_thermal_wave_50000_steps','s3_wave.mat'),'result');
 result=d.result;
end
f=figure('Visible','off');
requested=[0 350 700 result.snapshot_years(end)];
idx=arrayfun(@(t) find(abs(result.snapshot_years-t)==min(abs(result.snapshot_years-t)),1),requested);
idx=unique(idx,'stable'); n=numel(idx); tiledlayout(1,n);
cl=[min(result.initial_phi) max(result.initial_phi)];
for jj=1:n
 j=idx(jj); nexttile;
 imagesc(result.x_m/1000,result.z_m/1000, ...
 reshape(result.snapshot_phi(:,j),result.Grid.p.Ny,result.Grid.p.Nx));
 axis xy equal tight; caxis(cl); colorbar;
 xlabel('x [km]'); ylabel('Elevation [km]');
 title(sprintf('%.3g years',result.snapshot_years(j)));
end
saveas(f,fullfile(result.options.output_dir,'melt_fraction.png')); close(f);
if isempty(result.history), return; end
f=figure('Visible','off');
t=[0;result.history(:,1)]; z=[result.initial_peak_z_m;result.history(:,2)];
plot(t,z/1000,'r-',t,(z(1)-result.expected_speed_m_yr*t)/1000,'b--');
xlabel('Time [years]'); ylabel('Peak elevation [km]');
legend('Simulated','Theoretical 5w0','Location','best'); grid on;
saveas(f,fullfile(result.options.output_dir,'peak_trajectory.png')); close(f);
if size(result.history,2)>=10
 f=figure('Visible','off'); tiledlayout(2,1);
 nexttile; plot(result.history(:,1),result.history(:,8:9)-273);
 xlabel('Time [years]'); ylabel('T - 273 K'); legend('Minimum','Maximum'); grid on;
 nexttile; plot(result.history(:,1),result.history(:,10));
 xlabel('Time [years]'); ylabel('Relative total enthalpy error'); grid on;
 saveas(f,fullfile(result.options.output_dir,'thermal_sanity.png')); close(f);
end
end
