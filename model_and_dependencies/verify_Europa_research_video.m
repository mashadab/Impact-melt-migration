function report=verify_Europa_research_video(run_dir)
% Decode initial, transfer and final frames and compare them with source PNGs.
if nargin<1 || isempty(run_dir)
 root=fileparts(mfilename('fullpath'));
 run_dir=fullfile(root,'..','Output','Europa_kc_1.850e-08_until_depleted_20261023_195524');
end
out=fullfile(run_dir,'research_video');
info=jsondecode(fileread(fullfile(out,'video_info.json')));
m=readtable(fullfile(out,'frame_manifest.csv'));
assert(~info.data_interpolation && height(m)==info.saved_states);
v=VideoReader(fullfile(out,'Europa_impact_melt_migration_1080p.mp4'));
assert(v.Width==1920 && v.Height==1080 && abs(v.FrameRate-24)<1e-6);
assert(abs(v.Duration-sum(m.frame_repetitions)/v.FrameRate)<2/v.FrameRate);
if isfield(info,'preview_iterations')
 transfer=find(m.iteration==info.preview_iterations(2),1);
else
 [~,transfer]=min(abs(m.time_years-85));
end
indices=[1 transfer height(m)];
names={'initial','transfer','final'};mae=zeros(1,3);sample_time=zeros(1,3);
for j=1:3
 k=indices(j);
 sample_time(j)=m.playback_start_s(k)+.5*m.frame_repetitions(k)/v.FrameRate;
 v.CurrentTime=sample_time(j);decoded=readFrame(v);
 original=imread(fullfile(out,['preview_' names{j} '.png']));
 assert(isequal(size(original),size(decoded)));
 mae(j)=mean(abs(double(original(:))-double(decoded(:))));
 assert(mae(j)<5,'Decoded video does not match its corresponding source preview.');
 imwrite(decoded,fullfile(out,['decoded_' names{j} '.png']));
end
report=struct('status','passed','decoded_frames_checked',3, ...
 'sample_playback_seconds',sample_time,'source_iterations',m.iteration(indices)', ...
 'source_time_years',m.time_years(indices)','mean_absolute_RGB_error',mae, ...
 'width',v.Width,'height',v.Height,'frames_per_second',v.FrameRate, ...
 'duration_seconds',v.Duration,'manifest_states',height(m),'data_interpolation',false);
fid=fopen(fullfile(out,'video_verification.json'),'w');fprintf(fid,'%s',jsonencode(report));fclose(fid);
fprintf('EUROPA_VIDEO_VERIFIED %s\n',jsonencode(report));
end
