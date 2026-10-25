function report=verify_flat_and_centered_water_videos(output_dir)
% Decode actual video samples and compare with source renderings.
if nargin<1
 root=fileparts(fileparts(mfilename('fullpath')));
 output_dir=strtrim(fileread(fullfile(root,'tmp','flat_centered_video_output.txt')));
end
comparison=jsondecode(fileread(fullfile(output_dir,'video_comparison.json')));
out=fullfile(output_dir,'videos');report=struct('status','passed','data_interpolation',false);
for cellstem={'flat_layer_corrected','centered_water_corrected'}
 stem=cellstem{1};path=fullfile(out,[stem '.mp4']);reader=VideoReader(path);
 manifest=readtable(fullfile(out,[stem '_frame_manifest.csv']));
 indices=unique([1 ceil(height(manifest)/2) height(manifest)]);
 starts=[0;cumsum(manifest.frame_repetitions(1:end-1))]/reader.FrameRate;
 errors=zeros(numel(indices),1);decoded_times=errors;
 for j=1:numel(indices)
  id=indices(j);sample=starts(id)+manifest.frame_repetitions(id)/(2*reader.FrameRate);
  sample=min(sample,reader.Duration-1/reader.FrameRate);
  reader.CurrentTime=sample;actual=readFrame(reader);
  expected=imread(fullfile(out,sprintf('%s_preview_%04d.png',stem,id)));
  assert(isequal(size(actual),size(expected)));
  errors(j)=mean(abs(double(actual(:))-double(expected(:))));
  assert(errors(j)<8,'Decoded video differs from its source preview.');
  imwrite(actual,fullfile(out,sprintf('%s_decoded_%04d.png',stem,id)));
  decoded_times(j)=sample;
 end
 assert(reader.Width==1280 && reader.Height==720 && reader.FrameRate==24);
 assert(abs(manifest.actual_time_years(end)-comparison.common_end_time_years)<1e-10);
 item=struct('status','passed','width',reader.Width,'height',reader.Height, ...
  'duration_seconds',reader.Duration,'saved_states',height(manifest), ...
  'source_state_indices',indices,'source_steps',manifest.step(indices)', ...
  'source_time_years',manifest.actual_time_years(indices)', ...
  'decoded_sample_seconds',decoded_times','mean_absolute_RGB_errors',errors');
 report.(stem)=item;
 fprintf('VIDEO_VERIFIED %s %s\n',stem,jsonencode(item));
end
fid=fopen(fullfile(output_dir,'video_verification.json'),'w');fprintf(fid,'%s',jsonencode(report));fclose(fid);
end
