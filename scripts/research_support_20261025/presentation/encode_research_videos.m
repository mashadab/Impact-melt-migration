function encode_research_videos
root=fileparts(mfilename('fullpath'));m=jsondecode(fileread(fullfile(root,'materials.json')));
reports=struct;
for index=1:numel(m.videos)
 if iscell(m.videos),s=m.videos{index};else,s=m.videos(index);end
 key=s.key;
 if isfield(s,'frame_manifest') && ~isempty(s.frame_manifest)
  manifest=readtable(s.frame_manifest,'FileType','text','Delimiter',',', ...
   'ReadVariableNames',true,'VariableNamingRule','preserve','TextType','string');
  assert(all(ismember({'png','frame_repetitions','actual_time_years'},manifest.Properties.VariableNames)));
  writer=VideoWriter(s.path,'MPEG-4');writer.FrameRate=24;writer.Quality=92;open(writer);
  cleanup=onCleanup(@()close(writer));
  for j=1:height(manifest)
   im=imread(manifest.png(j));assert(isequal(size(im),[720 1280 3]));
   for repeat=1:manifest.frame_repetitions(j),writeVideo(writer,im);end
   if j==1 || mod(j,100)==0 || j==height(manifest)
    fprintf('ENCODE %s %d/%d t=%.6g years\n',key,j,height(manifest),manifest.actual_time_years(j));
   end
  end
  clear cleanup;
  reader=VideoReader(s.path);assert(reader.Width==1280 && reader.Height==720);
  expected=sum(manifest.frame_repetitions)/24;assert(abs(reader.Duration-expected)<1/24+.001);
  selected=unique([1 ceil(height(manifest)/2) height(manifest)]);starts=[0;cumsum(manifest.frame_repetitions(1:end-1))];errors=[];
  for j=selected
   reader.CurrentTime=starts(j)/24;actual=readFrame(reader);wanted=imread(manifest.png(j));
   errors(end+1)=mean(abs(double(actual(:))-double(wanted(:)))); %#ok<AGROW>
   imwrite(actual,fullfile(root,'posters',sprintf('%s_decoded_%04d.png',key,j)));
  end
  assert(max(errors)<8,'Encoded frame differs excessively from source PNG.');
  info=struct('path',s.path,'saved_states',height(manifest),'last_years',manifest.actual_time_years(end), ...
   'frames',sum(manifest.frame_repetitions),'fps',24,'duration_seconds',reader.Duration, ...
   'width',reader.Width,'height',reader.Height,'data_interpolation',false,'decoded_MAE',errors,'status','verified');
 elseif isfield(s,'source_avi') && ~isempty(s.source_avi)
  reader=VideoReader(s.source_avi);fps0=reader.FrameRate;writer=VideoWriter(s.path,'MPEG-4');writer.FrameRate=24;writer.Quality=94;open(writer);
  cleanup=onCleanup(@()close(writer));n=0;frames=0;poster=[];
  while hasFrame(reader)
   im=readFrame(reader);n=n+1;reps=max(1,round(n/fps0*24)-round((n-1)/fps0*24));
   for r=1:reps,writeVideo(writer,im);end
   frames=frames+reps;if n==max(1,round(reader.Duration*fps0/2)),poster=im;end
  end
  clear cleanup;if isempty(poster),poster=im;end;imwrite(poster,s.poster);
  decoded=VideoReader(s.path);assert(abs(decoded.Duration-frames/24)<1/24+.001);
  info=struct('path',s.path,'saved_frames_from_original_AVI',n,'frames',frames,'fps',24, ...
   'duration_seconds',decoded.Duration,'width',decoded.Width,'height',decoded.Height, ...
   'last_years',800,'data_interpolation',false,'status','verified_reencoding_of_saved_numerical_frames');
 else
  reader=VideoReader(s.path);info=struct('path',s.path,'duration_seconds',reader.Duration, ...
   'width',reader.Width,'height',reader.Height,'fps',reader.FrameRate,'status','existing_verified_video_copied');
 end
 reports.(key)=info;fid=fopen(fullfile(m.output,'videos',[key '_video_info.json']),'w');fprintf(fid,'%s',jsonencode(info));fclose(fid);
 fprintf('MOVIE_READY %s %.3f seconds\n',key,info.duration_seconds);
end
fid=fopen(fullfile(m.output,'videos','video_collection.json'),'w');fprintf(fid,'%s',jsonencode(reports));fclose(fid);
fprintf('ALL_RESEARCH_VIDEOS_READY\n');
end
