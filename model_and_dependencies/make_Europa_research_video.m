function video_path=make_Europa_research_video(run_dir,preview_only)
% Render saved Eulerian cell values only: no field or time interpolation.
% Nonuniform playback uses integer frame holds; numerical files are read only.
if nargin<1 || isempty(run_dir)
 root=fileparts(mfilename('fullpath'));
 run_dir=fullfile(root,'..','Output','Europa_kc_1.850e-08_until_depleted_20261023_195524');
end
if nargin<2,preview_only=false;end
out=fullfile(run_dir,'research_video');if ~isfolder(out),mkdir(out);end
summary=jsondecode(fileread(fullfile(run_dir,'summary.json')));
assert(strcmp(summary.status,'melt_depleted'),'Expected completed reference run.');
budget=readtable(fullfile(run_dir,'melt_budget.csv'));
files=dir(fullfile(run_dir,'states','state_*.mat'));n=numel(files);
assert(n>1,'No saved state sequence.');
times=zeros(n,1);steps=zeros(n,1);row=zeros(n,1);
T=zeros(12000,n);P=T;
for j=1:n
 q=load(fullfile(files(j).folder,files(j).name),'state');s=q.state;
 assert(s.permeability_exponent==3 && s.kc_m2==summary.kc_m2);
 times(j)=s.time_years;steps(j)=s.step;
 if j==1
  G=s.Grid.p;nx=G.Nx;ny=G.Ny;
  T=zeros(nx*ny,n);P=T;
  radius=s.radius_m(:)'/1000;elevation=s.elevation_m(:)'/1000;
 end
 T(:,j)=s.temperature_K;P(:,j)=s.phi;
 [err,row(j)]=min(abs(budget.time_years-times(j)));
 assert(err<1e-7,'No exact diagnostic row for saved state.');
end
assert(all(diff(times)>0) && steps(end)==summary.steps);
assert(abs(times(end)-summary.time_years)<1e-8);
assert(all(isfinite(T(:))) && all(isfinite(P(:))));
assert(min(P(:))>=-1e-10 && max(P(:))<=1+1e-10);

% Playback anchors are actual diagnostic times, not interpolated states.
peak_delivery=max(budget.delivered_net_m3);
assert(peak_delivery>0,'This pacing requires a run with positive net delivery.');
onset=find(budget.delivered_net_m3>=.01*peak_delivery,1);
middle=find(budget.delivered_net_m3>=.50*peak_delivery,1);
transferred=find(budget.delivered_net_m3>=.90*peak_delivery,1);
residual=find(budget.melt_shell_m3<=.01*budget.melt_shell_m3(1),1);
stage_times=[0 budget.time_years(onset) budget.time_years(transferred) ...
 budget.time_years(residual) times(end)];
assert(all(diff(stage_times)>0),'Playback stages must advance in time.');
stage_seconds=[0 12 42 60 74];
early_limit=min(times(end),max(150,ceil(1.25*stage_times(3)/50)*50));
fps=24;play=zeros(n,1);
for j=1:n
 t=times(j);
 segment=min(find(t<=stage_times(2:end),1),4);
 play(j)=stage_seconds(segment)+(stage_seconds(segment+1)-stage_seconds(segment))* ...
  (t-stage_times(segment))/(stage_times(segment+1)-stage_times(segment));
end
repeats=max(1,diff(round(play*fps)));repeats(end+1,1)=5*fps;
repeats(1)=repeats(1)+3*fps;
playback_start=[0;cumsum(repeats(1:end-1))]/fps;
manifest=table(steps,times,row,playback_start,repeats, ...
 'VariableNames',{'iteration','time_years','diagnostic_row','playback_start_s','frame_repetitions'});
writetable(manifest,fullfile(out,'frame_manifest.csv'));

bg=[.030 .048 .078];card=[.050 .077 .115];ink=[.94 .97 1];
muted=[.59 .69 .79];border=[.15 .23 .32];teal=[.17 .88 .76];
blue=[.36 .65 1];amber=[1 .66 .30];
f=figure('Visible','off','Color',bg,'Position',[30 30 1920 1080], ...
 'PaperUnits','inches','PaperPosition',[0 0 19.2 10.8], ...
 'PaperSize',[19.2 10.8],'InvertHardcopy','off','GraphicsSmoothing','off');
cleanupfig=onCleanup(@() close(f)); %#ok<NASGU>
annotation(f,'rectangle',[.035 .315 .35 .495],'FaceColor','none','Color',border,'LineWidth',.7);
annotation(f,'rectangle',[.399 .315 .35 .495],'FaceColor','none','Color',border,'LineWidth',.7);
annotation(f,'rectangle',[.764 .315 .201 .495],'FaceColor',card,'Color',border,'LineWidth',.7);
label([.043 .945 .68 .03],'EUROPA  /  IMPACT MELT MIGRATION',12,teal,true);
label([.04 .884 .72 .06],'From the ice shell to the ocean interface',29,ink,true);
label([.043 .845 .85 .035], ...
 sprintf('Axisymmetric Darcy-Stokes  |  kc = %.3g m^2  |  k = kc \\phi^3  |  sealed outer base',summary.kc_m2),12,muted,false,'tex');
clock=label([.752 .91 .21 .065],'',32,ink,true);set(clock,'HorizontalAlignment','right');
chapter=label([.742 .872 .22 .03],'',11,teal,true);set(chapter,'HorizontalAlignment','right');
label([.052 .765 .30 .03],'01  TEMPERATURE',14,ink,true);
label([.416 .765 .30 .03],'02  MELT FRACTION',14,ink,true);

a=axes(f,'Position',[.069 .408 .282 .301]);
b=axes(f,'Position',[.433 .408 .282 .301]);
imageT=imagesc(a,radius,elevation,reshape(T(:,1),ny,nx));
imageP=imagesc(b,radius,elevation,reshape(P(:,1),ny,nx));
for ax=[a b]
 set(ax,'YDir','normal','Color',card,'FontName','Arial','FontSize',11, ...
  'XColor',muted,'YColor',muted,'LineWidth',.7,'Box','off','Layer','top', ...
  'XTick',0:5:20,'YTick',-2:2:10);
 axis(ax,'image');xlim(ax,[0 20]);ylim(ax,[-2 10]);
 xlabel(ax,'Radius [km]','Color',muted);ylabel(ax,'Elevation [km]','Color',muted);
 yline(ax,0,'--','Color',[.90 .95 1],'LineWidth',1.0);
end
colormap(a,parula(256));caxis(a,[100 273]);
colormap(b,turbo(256));caxis(b,[0 1]);
cb=colorbar(a,'southoutside');cb.Position=[.069 .350 .282 .012];
cb.Color=muted;cb.FontSize=10;cb.Ticks=[100 150 200 250 273];
cb.Label.String='Temperature [K]';cb.Label.Color=muted;
cb=colorbar(b,'southoutside');cb.Position=[.433 .350 .282 .012];
cb.Color=muted;cb.FontSize=10;cb.Ticks=[0 .25 .5 .75 1];
cb.Label.String='Melt volume fraction';cb.Label.Color=muted;
set(a,'Position',[.069 .408 .282 .301]);set(b,'Position',[.433 .408 .282 .301]);

label([.782 .753 .17 .035],'MELT IN THE SHELL',11,muted,true);
shell=label([.779 .690 .18 .065],'',29,ink,true);
label([.919 .705 .035 .035],'km^3',13,muted,false,'tex');
fraction=label([.782 .652 .17 .04],'',12,muted,false);
annotation(f,'line',[.783 .947],[.636 .636],'Color',border,'LineWidth',.8);
label([.782 .589 .17 .035],'NET DELIVERED',11,teal,true);
delivery=label([.779 .530 .18 .065],'',27,teal,true);
label([.919 .545 .035 .035],'km^3',13,teal,false,'tex');
label([.782 .503 .17 .032],'Downward across z = 0',10,muted,false);
label([.782 .441 .17 .035],'NET REFREEZING*',11,amber,true);
freezing=label([.779 .382 .18 .065],'',27,amber,true);
label([.919 .397 .035 .035],'km^3',13,amber,false,'tex');
label([.782 .335 .175 .045],'*Includes 0.36729 km^3 initial adjustment',9,muted,false,'tex');

label([.051 .270 .33 .03],sprintf('03  EARLY TRANSFER  /  FIRST %.0f YEARS',early_limit),11,ink,true);
label([.442 .270 .30 .03],'04  FULL SIMULATION',11,ink,true);
h1=axes(f,'Position',[.069 .145 .30 .105]);
h2=axes(f,'Position',[.460 .145 .281 .105]);
curves=gobjects(2,3);dots=gobjects(2,3);cursor=gobjects(1,2);
values=[budget.melt_shell_m3 budget.delivered_net_m3 budget.refrozen_net_shell_m3]/1e9;
colors=[blue;teal;amber];
for k=1:2
 ax=h1;if k==2,ax=h2;end
 hold(ax,'on');
 for q=1:3
  plot(ax,budget.time_years,values(:,q),'Color',.24*colors(q,:)+.76*bg,'LineWidth',1);
  curves(k,q)=plot(ax,budget.time_years(1),values(1,q),'Color',colors(q,:),'LineWidth',2.2);
  dots(k,q)=plot(ax,budget.time_years(1),values(1,q),'o', ...
   'MarkerSize',4,'MarkerFaceColor',colors(q,:),'MarkerEdgeColor',colors(q,:));
 end
 cursor(k)=xline(ax,0,'Color',[.65 .75 .85],'LineWidth',.7);
 yline(ax,.005*summary.initial_shell_melt_km3,':','Color',muted,'LineWidth',.6);
 set(ax,'Color',bg,'FontName','Arial','FontSize',10,'XColor',muted,'YColor',muted, ...
  'LineWidth',.6,'Box','off','GridColor',border,'GridAlpha',.5,'Layer','top');
 grid(ax,'on');ylim(ax,[0 34]);
 ylabel(ax,'Volume [km^3]','Color',muted);xlabel(ax,'Simulated time [years]','Color',muted);
end
xlim(h1,[0 early_limit]);h1.XTickMode='auto';
xlim(h2,[0 times(end)]);h2.XTickMode='auto';
label([.054 .073 .23 .025],'BLUE: in shell',10,blue,false);
label([.215 .073 .23 .025],'TEAL: net delivered',10,teal,false);
label([.442 .073 .24 .025],'AMBER: net refreezing*',10,amber,false);
label([.782 .259 .17 .03],'SAVED ITERATION',10,muted,true);
iteration=label([.779 .207 .18 .055],'',25,ink,true);
status=label([.782 .166 .175 .036],'',12,teal,true);
label([.782 .113 .17 .052],'Stop: shell melt volume <= 0.5% of its initial value',10,muted,false);
annotation(f,'line',[.043 .963],[.057 .057],'Color',border,'LineWidth',.7);
label([.043 .015 .92 .034], ...
 'Saved grid cells only. No data interpolation. Frames are held/repeated at variable playback speed. Dashed line: z = 0; impermeable base: z = -2 km.',10,muted,false);

% Inspect three real states before encoding the full sequence.
[~,mid]=min(abs(times-budget.time_years(middle)));
preview_indices=[1 mid n];preview_names={'preview_initial.png','preview_transfer.png','preview_final.png'};
for k=1:3
 render(preview_indices(k));print(f,fullfile(out,preview_names{k}),'-dpng','-r100');
end
% Capture the computed scientific figure in memory; never capture the desktop.
% A PNG comparison checks layout/orientation before selecting the faster path.
reference_image=imread(fullfile(out,'preview_final.png'));
capture_flip=false;capture_backend='print-rgb';
capture_timer=tic;rgb=print(f,'-RGBImage','-r100');print_seconds=toc(capture_timer);
direct_error=mean(abs(double(rgb(:))-double(reference_image(:))));
flipped=flip(rgb,1);flip_error=mean(abs(double(flipped(:))-double(reference_image(:))));
if flip_error<direct_error,capture_flip=true;rgb=flipped;end
assert(isequal(size(rgb),size(reference_image)) && min(direct_error,flip_error)<3, ...
 'In-memory scientific figure does not match its source preview.');
capture_error=min(direct_error,flip_error);capture_seconds=print_seconds;
getframe_size=[];getframe_error=NaN;getframe_seconds=NaN;getframe_message='';
try
 gf=getframe(f); % warm up the offscreen figure buffer before timing it
 capture_timer=tic;gf=getframe(f);getframe_seconds=toc(capture_timer);
 getframe_size=size(gf.cdata);
 if isequal(size(gf.cdata),size(reference_image))
  getframe_error=mean(abs(double(gf.cdata(:))-double(reference_image(:))));
  if getframe_error<3 && getframe_seconds<print_seconds
   capture_backend='figure-buffer';capture_flip=false;
   capture_error=getframe_error;capture_seconds=getframe_seconds;
  end
 end
catch capture_exception
 getframe_message=capture_exception.message;
 % Offscreen figure capture is optional; print-rgb is checked above.
end
capture=struct('backend',capture_backend,'seconds',capture_seconds, ...
 'mean_absolute_RGB_error_against_PNG',capture_error,'flip_vertical',capture_flip, ...
 'getframe_size',getframe_size,'getframe_error',getframe_error, ...
 'getframe_seconds',getframe_seconds,'getframe_message',getframe_message);
fid=fopen(fullfile(out,'capture_verification.json'),'w');fprintf(fid,'%s',jsonencode(capture));fclose(fid);
fprintf('EUROPA_VIDEO_CAPTURE %s\n',jsonencode(capture));
if preview_only,video_path=fullfile(out,'preview_transfer.png');return;end

video_path=fullfile(out,'Europa_impact_melt_migration_1080p.mp4');
w=VideoWriter(video_path,'MPEG-4');w.FrameRate=fps;w.Quality=96;open(w);
cleanupvideo=onCleanup(@() close(w));
started=tic;
for j=1:n
 render(j);
 if strcmp(capture_backend,'figure-buffer')
  gf=getframe(f);I=gf.cdata;
 else
  I=print(f,'-RGBImage','-r100');if capture_flip,I=flip(I,1);end
 end
 assert(size(I,1)==1080 && size(I,2)==1920,'Unexpected video resolution.');
 for q=1:repeats(j),writeVideo(w,I);end
 if j==1 || mod(j,10)==0 || j==n
  progress=struct('saved_state',j,'saved_states',n,'iteration',steps(j), ...
   'time_years',times(j),'wall_seconds',toc(started));
  fid=fopen(fullfile(out,'render_progress.json'),'w');fprintf(fid,'%s',jsonencode(progress));fclose(fid);
  fprintf('EUROPA_VIDEO state=%d/%d iteration=%d time=%.6g yr wall=%.1fs\n',j,n,steps(j),times(j),toc(started));
 end
end
clear cleanupvideo;
v=VideoReader(video_path);
info=struct('video_path',video_path,'width',v.Width,'height',v.Height, ...
 'frames_per_second',v.FrameRate,'duration_seconds',v.Duration, ...
 'saved_states',n,'encoded_frames',sum(repeats),'first_iteration',steps(1), ...
 'last_iteration',steps(end),'final_time_years',times(end),'kc_m2',summary.kc_m2, ...
 'permeability_exponent',3,'playback_stage_time_years',stage_times, ...
 'preview_iterations',steps(preview_indices)','capture_backend',capture_backend, ...
 'data_interpolation',false,'playback','Integer repeats of actual saved states; variable speed', ...
 'temperature_color_limits_K',[100 273],'melt_color_limits',[0 1], ...
 'net_refreezing_includes_initial_adjustment_km3',0.3672852028284378);
fid=fopen(fullfile(out,'video_info.json'),'w');fprintf(fid,'%s',jsonencode(info));fclose(fid);
fprintf('EUROPA_VIDEO_COMPLETE %s\n',jsonencode(info));

 function h=label(position,str,fontsize,color,bold,interpreter)
  if nargin<6,interpreter='none';end
  weight='normal';if bold,weight='bold';end
  h=annotation(f,'textbox',position,'String',str,'EdgeColor','none', ...
   'FontName','Arial','FontSize',fontsize,'FontWeight',weight,'Color',color, ...
   'Interpreter',interpreter,'Margin',0,'VerticalAlignment','middle','FitBoxToText','off');
 end
 function render(j)
  set(imageT,'CData',reshape(T(:,j),ny,nx));set(imageP,'CData',reshape(P(:,j),ny,nx));
  if times(j)<1,ts=sprintf('%.4f YEARS',times(j));else,ts=sprintf('%.2f YEARS',times(j));end
  set(clock,'String',ts);
  if j==n,phase='STOPPING THRESHOLD REACHED';
  elseif times(j)<stage_times(2),phase='01  INITIAL EVOLUTION';
  elseif times(j)<stage_times(3),phase='02  RAPID TRANSFER';
  elseif times(j)<stage_times(4),phase='03  RESIDUAL EVOLUTION';
  else,phase='04  LATE EVOLUTION';end
  set(chapter,'String',phase);bi=row(j);
  set(shell,'String',sprintf('%.3f',values(bi,1)));
  set(fraction,'String',sprintf('%.5f%% of initial melt',100*values(bi,1)/summary.initial_shell_melt_km3));
  set(delivery,'String',sprintf('%.3f',values(bi,2)));
  set(freezing,'String',sprintf('%.3f',values(bi,3)));
  set(iteration,'String',sprintf('%d',steps(j)));
  if j==n,set(status,'String','RUN COMPLETED');else,set(status,'String','ACTUAL SAVED STATE');end
  for aidx=1:2
   for vidx=1:3
    set(curves(aidx,vidx),'XData',budget.time_years(1:bi),'YData',values(1:bi,vidx));
    set(dots(aidx,vidx),'XData',times(j),'YData',values(bi,vidx));
   end
   set(cursor(aidx),'Value',times(j));
  end
  drawnow;
 end
end
