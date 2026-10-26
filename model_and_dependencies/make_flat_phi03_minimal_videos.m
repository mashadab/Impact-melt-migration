function report=make_flat_phi03_minimal_videos(output_dir,modes)
% Minimal 2D and 1D videos from the existing computed snapshots.
if nargin<2,modes=1:2;end
loaded=load(fullfile(output_dir,'noflow_kc_1.850e-08.mat'),'result');r=loaded.result;
assert(strcmp(r.status,'completed'));
G=r.Grid.p;d=r.length_scale_m;times=r.time_years(:);steps=r.steps(:);
out=fullfile(output_dir,'videos_minimal');if ~isfolder(out),mkdir(out);end
fps=24;play=round(times/times(end)*30*fps);
repeats=max(1,diff(play));repeats(end+1,1)=4*fps;repeats(1)=repeats(1)+2*fps;
writetable(table(steps,times,repeats,'VariableNames', ...
 {'step','actual_time_years','frame_repetitions'}),fullfile(out,'frame_manifest.csv'));
font='Times New Roman';col=floor(G.Nx/2)+1;
ids=(col-1)*G.Ny+(1:G.Ny);z=G.yc(:)*d/1000;
selected=unique([1 ceil(numel(times)/2) numel(times)]);
report=struct('status','passed','source_result',r.output_file,'saved_states',numel(times), ...
 'final_time_years',times(end),'data_interpolation',false);
if isfile(fullfile(out,'verification.json'))
 report=jsondecode(fileread(fullfile(out,'verification.json')));
end
for mode=modes
 f=figure('Visible','off','Color','w','Units','inches','Position',[.5 .5 12.8 7.2], ...
  'PaperUnits','inches','PaperPosition',[0 0 12.8 7.2],'PaperSize',[12.8 7.2]);
 fc=onCleanup(@()close(f));
 if mode==1
  stem='flat_phi03_2D_minimal';
  ax=axes('Parent',f,'Position',[.12 .13 .72 .71]);
  im=imagesc(ax,G.xc*d/1000,z,reshape(r.full_phi(:,1),G.Ny,G.Nx));
  set(ax,'YDir','normal');axis(ax,'image');caxis(ax,[0 1]);colormap(ax,parula);
  xlabel(ax,'x [km]','Interpreter','none');ylabel(ax,'z [km]','Interpreter','none');
  cb=colorbar(ax,'eastoutside');cb.Label.String='Melt fraction';cb.Label.Interpreter='none';
  cb.Ticks=[0 .25 .5 .75 1];cb.FontName=font;cb.FontSize=13;
  ax.Position=[.12 .13 .72 .71];axes_list=ax;
 else
  stem='flat_phi03_1D_minimal';
  a=axes('Parent',f,'Position',[.10 .14 .35 .68]);
  linephi=plot(a,r.full_phi(ids,1),z,'Color',[.02 .35 .65],'LineWidth',2);
  xlim(a,[-.015 1.015]);ylim(a,[-2 10]);
  xlabel(a,'Melt fraction','Interpreter','none');ylabel(a,'z [km]','Interpreter','none');
  b=axes('Parent',f,'Position',[.59 .14 .32 .68]);
  lineT=plot(b,r.full_T_K(ids,1),z,'Color',[.85 .3 .05],'LineWidth',2);
  temp=r.full_T_K(ids,:);tlo=min(temp(:));thi=max(temp(:));pad=max(.5,.05*(thi-tlo));
  xlim(b,[tlo-pad thi+pad]);ylim(b,[-2 10]);
  xlabel(b,'T [K]','Interpreter','none');axes_list=[a b];
 end
 for ax=axes_list
  set(ax,'FontName',font,'FontSize',15,'TickLabelInterpreter','none','Box','on', ...
   'XGrid','off','YGrid','off','LineWidth',.7);
 end
 if mode==1
  clock=annotation(f,'textbox',[.35 .91 .30 .05],'String','','LineStyle','none', ...
   'HorizontalAlignment','center','FontName',font,'FontSize',18,'Interpreter','none');
 else
  clock=title(a,'','FontName',font,'FontSize',18,'FontWeight','normal','Interpreter','none');
 end
 path=fullfile(out,[stem '.mp4']);writer=VideoWriter(path,'MPEG-4');
 writer.FrameRate=fps;writer.Quality=94;open(writer);wc=onCleanup(@()close(writer));
 for j=1:numel(times)
  clock.String=sprintf('t = %.3f yr',times(j));
  if mode==1
   im.CData=reshape(r.full_phi(:,j),G.Ny,G.Nx);
  else
   linephi.XData=r.full_phi(ids,j);lineT.XData=r.full_T_K(ids,j);
  end
  drawnow;frame=print(f,'-RGBImage','-r100');assert(isequal(size(frame),[720 1280 3]));
  if ismember(j,selected),imwrite(frame,fullfile(out,sprintf('%s_%04d.png',stem,j)));end
  for k=1:repeats(j),writeVideo(writer,frame);end
  if j==1 || mod(j,20)==0 || j==numel(times)
   fprintf('MINIMAL_VIDEO %s %d/%d\n',stem,j,numel(times));
  end
 end
 clear wc fc;
 reader=VideoReader(path);assert(reader.Width==1280 && reader.Height==720 && reader.FrameRate==fps);
 assert(abs(reader.Duration-sum(repeats)/fps)<1/fps+.001);
 starts=[0;cumsum(repeats(1:end-1))]/fps;errors=zeros(size(selected));
 for k=1:numel(selected)
  j=selected(k);reader.CurrentTime=min(starts(j)+repeats(j)/(2*fps),reader.Duration-1/fps);
  actual=readFrame(reader);expected=imread(fullfile(out,sprintf('%s_%04d.png',stem,j)));
  assert(isequal(size(actual),size(expected)));
  errors(k)=mean(abs(double(actual(:))-double(expected(:))));assert(errors(k)<8);
  imwrite(actual,fullfile(out,sprintf('%s_decoded_%04d.png',stem,j)));
 end
 report.(stem)=struct('path',path,'width',reader.Width,'height',reader.Height, ...
  'fps',fps,'duration_seconds',reader.Duration,'mean_absolute_RGB_errors',errors);
 fprintf('MINIMAL_VERIFIED %s\n',stem);
end
fid=fopen(fullfile(out,'verification.json'),'w');fprintf(fid,'%s',jsonencode(report));fclose(fid);
fprintf('MINIMAL_VIDEOS_COMPLETE %s\n',jsonencode(report));
end
