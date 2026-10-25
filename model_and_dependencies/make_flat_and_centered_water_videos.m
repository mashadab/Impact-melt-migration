function make_flat_and_centered_water_videos(output_dir)
% Matched corrected baseline; videos contain only actual computed states.
config=jsondecode(fileread(fullfile(output_dir,'configuration.json')));
diary(fullfile(output_dir,'video_work.log'));diary_clean=onCleanup(@()diary('off')); %#ok<NASGU>
files=cellstr(config.centered_files);last=load(files{end},'checkpoint');last=last.checkpoint;
target=last.time_years;flat_dir=fullfile(output_dir,'flat_layer_run');
addpath(config.flat_frozen_source,'-begin');path_clean=onCleanup(@()rmpath(config.flat_frozen_source)); %#ok<NASGU>
assert(strcmp(strrep(which('darcy_stokes_2D_cases'),'\','/'), ...
 strrep(fullfile(config.flat_frozen_source,'darcy_stokes_2D_cases.m'),'\','/')));
if isfile(fullfile(flat_dir,'flat_result.mat'))
 loaded=load(fullfile(flat_dir,'flat_result.mat'),'flat');flat=loaded.flat;
else
 flat=run_centered_water_S3(target,flat_dir);
end
G=flat.Grid.p;d=flat.length_scale_m;[~,Z]=meshgrid(G.xc*d,G.yc*d);
assert(isequal(flat.full_phi(:,1),double(Z(:)>4000)));
assert(all(flat.full_T_K(:,1)==273));
assert(strcmp(flat.status,'completed') && abs(flat.time_years(end)-target)<1e-10);
flat.test_variant='flat_layer';save(fullfile(flat_dir,'flat_result.mat'),'flat');
fprintf('CORRECTED_FLAT_COMPLETE target=%.17g years steps=%d max_delta_phi=%.9g\n', ...
 target,flat.completed_steps,max(abs(flat.final_state.phi-flat.full_phi(:,1))));
initial=load(files{1},'checkpoint');initial=initial.checkpoint;
center_phi=zeros(G.N,numel(files)+1);center_T=center_phi;
center_phi(:,1)=initial.diagnostic.phi_before;center_T(:,1)=initial.diagnostic.T_before_K;
times=zeros(numel(files)+1,1);steps=times;
for j=1:numel(files)
 loaded=load(files{j},'checkpoint');s=loaded.checkpoint;
 center_phi(:,j+1)=s.phi;center_T(:,j+1)=s.T_dimensionless*173+100;
 times(j+1)=s.time_years;steps(j+1)=s.step;
end
assert(all(diff(times)>0) && times(end)==target);
video_dir=fullfile(output_dir,'videos');mkdir(video_dir);
flat_info=render_water_video(video_dir,'flat_layer_corrected','Flat water layer', ...
 flat.full_phi,flat.full_T_K,flat.time_years(:),flat.steps(:),G,d);
center_info=render_water_video(video_dir,'centered_water_corrected','Centered water body', ...
 center_phi,center_T,times,steps,G,d);
report=struct('status','completed','common_end_time_years',target, ...
 'flat',flat_info,'centered',center_info,'data_interpolation',false, ...
 'flat_max_phi_change',max(abs(flat.final_state.phi-flat.full_phi(:,1))), ...
 'flat_initial_liquid_m3_per_m_depth',sum(flat.full_phi(:,1).*G.V)*d^2, ...
 'centered_initial_liquid_m3_per_m_depth',sum(center_phi(:,1).*G.V)*d^2, ...
 'physical_change_between_setups','initial water shape only; flat starts with twice the water volume', ...
 'rheology','same regularized Europa shear law; 1e9 Pa s minimum shear coefficient');
fid=fopen(fullfile(output_dir,'video_comparison.json'),'w');fprintf(fid,'%s',jsonencode(report));fclose(fid);
fprintf('WATER_COMPARISON_VIDEOS %s\n',jsonencode(report));
end

function info=render_water_video(out,stem,label,phi,T,times,steps,G,d)
fps=24;target=times(end);play=round(times/target*30*fps);
repeats=max(1,diff(play));repeats(end+1,1)=4*fps;repeats(1)=repeats(1)+2*fps;
manifest=table(steps,times,repeats,'VariableNames',{'step','actual_time_years','frame_repetitions'});
writetable(manifest,fullfile(out,[stem '_frame_manifest.csv']));
f=figure('Visible','off','Color','w','Units','inches','Position',[.5 .5 12.8 7.2], ...
 'PaperUnits','inches','PaperPosition',[0 0 12.8 7.2],'PaperSize',[12.8 7.2]);
fc=onCleanup(@()close(f)); %#ok<NASGU>
navy=[.12 .24 .38];gray=[.4 .45 .5];
annotation(f,'textbox',[.055 .90 .91 .06],'String',label,'LineStyle','none', ...
 'FontName','Arial','FontSize',23,'Color',navy,'Interpreter','none');
annotation(f,'textbox',[.055 .84 .91 .045], ...
 'String','Corrected shared S3 | Cartesian, closed and insulated | kc = 1.85e-8 m^2 | k = kc phi^3', ...
 'LineStyle','none','FontName','Arial','FontSize',11,'Color',gray,'Interpreter','none');
position=[.065 .29 .51 .544];ax=axes('Parent',f,'Position',position);
im=imagesc(ax,G.xc*d/1000,G.yc*d/1000,reshape(phi(:,1),G.Ny,G.Nx));
set(ax,'YDir','normal','FontName','Arial','FontSize',11,'TickLabelInterpreter','none');
axis(ax,'image');clim(ax,[0 1]);colormap(ax,parula);
xlabel(ax,'x [km]','Interpreter','none');ylabel(ax,'z [km]','Interpreter','none');
hold(ax,'on');yline(ax,4,'--','Color',[.6 .6 .6],'LineWidth',.7);
cb=colorbar(ax,'southoutside');cb.Position=[.065 .205 .51 .016];cb.Ticks=[0 .25 .5 .75 1];
cb.Label.String='Liquid fraction';cb.Label.Interpreter='none';ax.Position=position;
clock=annotation(f,'textbox',[.65 .72 .30 .07],'String','','LineStyle','none', ...
 'FontName','Arial','FontSize',25,'Color',navy,'Interpreter','none');
metrics=annotation(f,'textbox',[.65 .37 .30 .28],'String','','LineStyle','none', ...
 'FontName','Arial','FontSize',14,'Color',navy,'Interpreter','none');
annotation(f,'textbox',[.65 .24 .30 .11], ...
 'String',{'Time changes only at saved states.','Frames are held; data are not interpolated.'}, ...
 'LineStyle','none','FontName','Arial','FontSize',10,'Color',gray,'Interpreter','none');
annotation(f,'textbox',[.055 .055 .92 .09], ...
 'String',{'Same regularized rheology in both tests: minimum Stokes shear coefficient = 1e9 Pa s.', ...
 'The flat layer starts with twice the liquid volume. No lateral perturbation is imposed in that test.'}, ...
 'LineStyle','none','FontName','Arial','FontSize',10,'Color',gray,'Interpreter','none');
path=fullfile(out,[stem '.mp4']);writer=VideoWriter(path,'MPEG-4');writer.FrameRate=fps;writer.Quality=94;open(writer);
wc=onCleanup(@()close(writer)); %#ok<NASGU>
[~,Z]=meshgrid(G.xc*d,G.yc*d);lower=Z(:)<4000;V=G.V*d^2;
initial_total=sum(phi(:,1).*V);selected=unique([1,ceil(size(phi,2)/2),size(phi,2)]);
for j=1:size(phi,2)
 im.CData=reshape(phi(:,j),G.Ny,G.Nx);
 clock.String=sprintf('%.4g years',times(j));
 total=sum(phi(:,j).*V);below=sum(phi(lower,j).*V(lower));
 metrics.String=sprintf(['Computed step %d\n\nLiquid below z = 4 km\n%.4g million m^3 / m\n\n' ...
  'Initial liquid: %.3g million m^3 / m\nTemperature: %.5g to %.5g K\nRelative liquid change: %.2g'], ...
  steps(j),below/1e6,initial_total/1e6,min(T(:,j)),max(T(:,j)),(total-initial_total)/initial_total);
 drawnow;frame=print(f,'-RGBImage','-r100');assert(isequal(size(frame),[720 1280 3]));
 if ismember(j,selected),imwrite(frame,fullfile(out,sprintf('%s_preview_%04d.png',stem,j)));end
 for k=1:repeats(j),writeVideo(writer,frame);end
 if j==1 || mod(j,10)==0 || j==size(phi,2)
  fprintf('VIDEO_FRAME %s %d/%d t=%.6g years\n',stem,j,size(phi,2),times(j));
 end
end
clear wc;
reader=VideoReader(path);assert(reader.Width==1280 && reader.Height==720);
assert(abs(reader.Duration-sum(repeats)/fps)<1/fps+.001);
info=struct('path',path,'saved_states',numel(times),'final_time_years',times(end), ...
 'width',reader.Width,'height',reader.Height,'fps',fps,'duration_seconds',reader.Duration, ...
 'first_step',steps(1),'last_step',steps(end),'data_interpolation',false);
fid=fopen(fullfile(out,[stem '_video_info.json']),'w');fprintf(fid,'%s',jsonencode(info));fclose(fid);
end
