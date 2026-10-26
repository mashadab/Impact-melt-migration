function info=make_flat_phi03_video(output_dir)
% Same layout and timing as the previous centered-body movie; saved states only.
loaded=load(fullfile(output_dir,'noflow_kc_1.850e-08.mat'),'result');r=loaded.result;
assert(strcmp(r.status,'completed'));
G=r.Grid.p;d=r.length_scale_m;phi=r.full_phi;T=r.full_T_K;
times=r.time_years(:);steps=r.steps(:);assert(all(diff(times)>0));
out=fullfile(output_dir,'videos');if ~isfolder(out),mkdir(out);end
diary(fullfile(output_dir,'video_work.log'));dc=onCleanup(@()diary('off')); %#ok<NASGU>
fps=24;play=round(times/times(end)*30*fps);
repeats=max(1,diff(play));repeats(end+1,1)=4*fps;repeats(1)=repeats(1)+2*fps;
manifest=table(steps,times,repeats,'VariableNames',{'step','actual_time_years','frame_repetitions'});
writetable(manifest,fullfile(out,'flat_phi03_frame_manifest.csv'));
f=figure('Visible','off','Color','w','Units','inches','Position',[.5 .5 12.8 7.2], ...
 'PaperUnits','inches','PaperPosition',[0 0 12.8 7.2],'PaperSize',[12.8 7.2]);
fc=onCleanup(@()close(f)); %#ok<NASGU>
navy=[.12 .24 .38];gray=[.4 .45 .5];font='Times New Roman';
annotation(f,'textbox',[.055 .90 .91 .06],'String','Flat upper layer | initial porosity = 0.3', ...
 'LineStyle','none','FontName',font,'FontSize',23,'Color',navy,'Interpreter','none');
annotation(f,'textbox',[.055 .84 .91 .045], ...
 'String','Corrected shared S3 | Cartesian, closed and insulated | kc = 1.85e-8 m^2 | k = kc phi^3', ...
 'LineStyle','none','FontName',font,'FontSize',11,'Color',gray,'Interpreter','none');
position=[.065 .29 .51 .544];ax=axes('Parent',f,'Position',position);
im=imagesc(ax,G.xc*d/1000,G.yc*d/1000,reshape(phi(:,1),G.Ny,G.Nx));
set(ax,'YDir','normal','FontName',font,'FontSize',11,'TickLabelInterpreter','none');
axis(ax,'image');caxis(ax,[0 1]);colormap(ax,parula);
xlabel(ax,'x [km]','Interpreter','none');ylabel(ax,'z [km]','Interpreter','none');
hold(ax,'on');yline(ax,4,'--','Color',[.6 .6 .6],'LineWidth',.7);
cb=colorbar(ax,'southoutside');cb.Position=[.065 .205 .51 .016];cb.Ticks=[0 .25 .5 .75 1];
cb.Label.String='Porosity / liquid fraction';cb.Label.Interpreter='none';ax.Position=position;
clock=annotation(f,'textbox',[.65 .72 .30 .07],'String','','LineStyle','none', ...
 'FontName',font,'FontSize',25,'Color',navy,'Interpreter','none');
metrics=annotation(f,'textbox',[.65 .37 .30 .28],'String','','LineStyle','none', ...
 'FontName',font,'FontSize',14,'Color',navy,'Interpreter','none');
annotation(f,'textbox',[.65 .24 .30 .11], ...
 'String',{'Time changes only at saved states.','Frames are held; data are not interpolated.'}, ...
 'LineStyle','none','FontName',font,'FontSize',10,'Color',gray,'Interpreter','none');
annotation(f,'textbox',[.055 .055 .92 .09], ...
 'String',{'Initially: flat upper half phi = 0.3; bottom half phi = 0. No lateral perturbation is imposed.', ...
 'Initial temperature = 273 K throughout. Temperature and porosity evolve freely; same original rheology.'}, ...
 'LineStyle','none','FontName',font,'FontSize',10,'Color',gray,'Interpreter','none');
path=fullfile(out,'flat_phi03.mp4');writer=VideoWriter(path,'MPEG-4');writer.FrameRate=fps;writer.Quality=94;open(writer);
wc=onCleanup(@()close(writer)); %#ok<NASGU>
[~,Z]=meshgrid(G.xc*d,G.yc*d);lower=Z(:)<4000;V=G.V*d^2;
initial_total=sum(phi(:,1).*V);selected=unique([1 ceil(size(phi,2)/2) size(phi,2)]);
for j=1:size(phi,2)
 im.CData=reshape(phi(:,j),G.Ny,G.Nx);clock.String=sprintf('%.4g years',times(j));
 total=sum(phi(:,j).*V);below=sum(phi(lower,j).*V(lower));
 metrics.String=sprintf(['Computed step %d\n\nLiquid below z = 4 km\n%.4g million m^3 / m\n\n' ...
  'Initial liquid: %.3g million m^3 / m\nTemperature: %.5g to %.5g K\nRelative liquid change: %.2g'], ...
  steps(j),below/1e6,initial_total/1e6,min(T(:,j)),max(T(:,j)),(total-initial_total)/initial_total);
 drawnow;frame=print(f,'-RGBImage','-r100');assert(isequal(size(frame),[720 1280 3]));
 if ismember(j,selected),imwrite(frame,fullfile(out,sprintf('preview_%04d.png',j)));end
 if j==1,imwrite(frame,fullfile(out,'initial_condition.png'));end
 if j==size(phi,2),imwrite(frame,fullfile(out,'final_state.png'));end
 for k=1:repeats(j),writeVideo(writer,frame);end
 if j==1 || mod(j,10)==0 || j==size(phi,2)
  fprintf('VIDEO_FRAME %d/%d t=%.6g years\n',j,size(phi,2),times(j));
 end
end
clear wc;
reader=VideoReader(path);assert(reader.Width==1280 && reader.Height==720 && reader.FrameRate==fps);
assert(abs(reader.Duration-sum(repeats)/fps)<1/fps+.001);
starts=[0;cumsum(repeats(1:end-1))]/fps;errors=zeros(size(selected));
for j=1:numel(selected)
 id=selected(j);reader.CurrentTime=min(starts(id)+repeats(id)/(2*fps),reader.Duration-1/fps);
 actual=readFrame(reader);expected=imread(fullfile(out,sprintf('preview_%04d.png',id)));
 assert(isequal(size(actual),size(expected)));
 errors(j)=mean(abs(double(actual(:))-double(expected(:))));assert(errors(j)<8);
 imwrite(actual,fullfile(out,sprintf('decoded_%04d.png',id)));
end
info=struct('status','passed','path',path,'saved_states',numel(times), ...
 'final_time_years',times(end),'width',reader.Width,'height',reader.Height, ...
 'fps',fps,'duration_seconds',reader.Duration,'data_interpolation',false, ...
 'decoded_source_indices',selected,'mean_absolute_RGB_errors',errors);
fid=fopen(fullfile(out,'video_verification.json'),'w');fprintf(fid,'%s',jsonencode(info));fclose(fid);
fprintf('FLAT_PHI03_VIDEO_VERIFIED %s\n',jsonencode(info));
end
