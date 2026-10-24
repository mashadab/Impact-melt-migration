function video_path = make_S3_video(result)
% Export recovered-temperature and melt-fraction snapshots to a video.
% Can also be called on an in-progress checkpoint loaded from s3_wave.mat.
if ischar(result) || isstring(result)
 d=load(result,'result'); result=d.result;
end
video_path=fullfile(result.options.output_dir,'s3_melt_temperature.avi');
w=VideoWriter(video_path,'Motion JPEG AVI'); w.FrameRate=12; open(w);
cleanup=onCleanup(@() close(w));
f=figure('Visible','off','Position',[100 100 960 720],'Color','w');
figcleanup=onCleanup(@() close(f));
tl=tiledlayout(f,1,2); a=nexttile(tl); b=nexttile(tl);
lims=[min(result.initial_phi) max(result.initial_phi)];
framefile=fullfile(result.options.output_dir,'video_frame.png');
for j=1:numel(result.snapshot_years)
 imagesc(a,result.x_m/1000,result.z_m/1000,reshape(result.snapshot_phi(:,j),result.Grid.p.Ny,result.Grid.p.Nx));
 axis(a,'xy','equal','tight'); caxis(a,lims); colorbar(a);
 title(a,'Melt volume fraction'); xlabel(a,'x [km]'); ylabel(a,'Elevation [km]');
 imagesc(b,result.x_m/1000,result.z_m/1000,reshape(result.snapshot_temperature_K(:,j),result.Grid.p.Ny,result.Grid.p.Nx));
 axis(b,'xy','equal','tight'); caxis(b,[272 274]); colorbar(b);
 title(b,'Temperature [K], from enthalpy'); xlabel(b,'x [km]'); ylabel(b,'Elevation [km]');
 title(tl,sprintf('S3 exact realization | t = %.2f years',result.snapshot_years(j)));
 exportgraphics(f,framefile,'Resolution',100);
 writeVideo(w,imread(framefile));
end
fprintf('S3_VIDEO_SAVED %s (%d frames)\n',video_path,numel(result.snapshot_years));
end
