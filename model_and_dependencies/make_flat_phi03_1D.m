function info=make_flat_phi03_1D(output_dir)
% Actual center-column melt/temperature profiles, static plot, data and video.
loaded=load(fullfile(output_dir,'noflow_kc_1.850e-08.mat'),'result');r=loaded.result;
assert(strcmp(r.status,'completed'));
G=r.Grid.p;d=r.length_scale_m;times=r.time_years(:);steps=r.steps(:);
% Use the actual column immediately right of the domain midpoint; no averaging.
col=floor(G.Nx/2)+1;ids=(col-1)*G.Ny+(1:G.Ny);
z=G.yc(:)*d/1000;x=G.xc(col)*d/1000;
phi=r.full_phi(ids,:);T=r.full_T_K(ids,:);
out=fullfile(output_dir,'profiles_1D');if ~isfolder(out),mkdir(out);end
initial_final=table(z,phi(:,1),phi(:,end),T(:,1),T(:,end), ...
 'VariableNames',{'elevation_km','initial_porosity','final_porosity','initial_temperature_K','final_temperature_K'});
writetable(initial_final,fullfile(out,'initial_final_profiles.csv'));
[zz,tt]=ndgrid(z,times);
step_rows=reshape(repmat(steps',G.Ny,1),[],1);
all_profiles=table(tt(:),step_rows,zz(:),phi(:),T(:), ...
 'VariableNames',{'time_years','step','elevation_km','porosity','temperature_K'});
writetable(all_profiles,fullfile(out,'all_saved_profiles.csv'));
font='Times New Roman';navy=[.12 .24 .38];blue=[.02 .35 .65];orange=[.85 .3 .05];
phimax=max(.35,ceil(max(phi(:))*20)/20);pmax=min(1,phimax);
tmin=min(T(:));tmax=max(T(:));tpad=max(.5,.05*(tmax-tmin));
tlimits=[tmin-tpad tmax+tpad];
f=figure('Visible','off','Color','w','Units','inches','Position',[.5 .5 12.8 7.2], ...
 'PaperUnits','inches','PaperPosition',[0 0 12.8 7.2],'PaperSize',[12.8 7.2]);
fc=onCleanup(@()close(f)); %#ok<NASGU>
annotation(f,'textbox',[.07 .91 .9 .06],'String','Flat layer | vertical melt and temperature profiles', ...
 'LineStyle','none','FontName',font,'FontSize',23,'Color',navy,'Interpreter','none');
clock=annotation(f,'textbox',[.07 .85 .9 .045],'String','','LineStyle','none', ...
 'FontName',font,'FontSize',13,'Color',navy,'Interpreter','none');
a=axes('Parent',f,'Position',[.10 .19 .35 .59]);hold(a,'on');
b=axes('Parent',f,'Position',[.59 .19 .33 .59]);hold(b,'on');
for ax=[a b]
 set(ax,'FontName',font,'FontSize',13,'TickLabelInterpreter','none','Box','on','Layer','top');
 ylim(ax,[-2 10]);yticks(ax,-2:2:10);grid(ax,'on');
 yline(ax,4,'--','Color',[.6 .6 .6],'LineWidth',.8,'HandleVisibility','off');
 ylabel(ax,'Elevation z [km]','Interpreter','none');
end
xlim(a,[-.015 pmax+.015]);xlim(b,tlimits);
xlabel(a,'Melt fraction / porosity','Interpreter','none');
xlabel(b,'Temperature [K]','Interpreter','none');
title(a,'Melt','Interpreter','none');title(b,'Temperature','Interpreter','none');
annotation(f,'textbox',[.07 .04 .9 .08], ...
 'String',{sprintf('Actual grid column x = %.1f km. Initial upper-half porosity = 0.3; lower half = 0; T = 273 K.',x), ...
 'Closed and insulated domain. Profiles show computed states without spatial or temporal interpolation.'}, ...
 'LineStyle','none','FontName',font,'FontSize',11,'Color',[.4 .45 .5],'Interpreter','none');
firstphi=plot(a,phi(:,1),z,'--','Color',[.55 .55 .55],'LineWidth',1.8,'DisplayName','Initial');
firstT=plot(b,T(:,1),z,'--','Color',[.55 .55 .55],'LineWidth',1.8,'DisplayName','Initial');
linephi=plot(a,phi(:,1),z,'-','Color',blue,'LineWidth',2.1,'DisplayName','Current');
lineT=plot(b,T(:,1),z,'-','Color',orange,'LineWidth',2.1,'DisplayName','Current');
legend(a,'Location','southwest','Interpreter','none');legend(b,'Location','southwest','Interpreter','none');
fps=24;play=round(times/times(end)*30*fps);
repeats=max(1,diff(play));repeats(end+1,1)=4*fps;repeats(1)=repeats(1)+2*fps;
manifest=table(steps,times,repeats,'VariableNames',{'step','actual_time_years','frame_repetitions'});
writetable(manifest,fullfile(out,'frame_manifest.csv'));
path=fullfile(out,'flat_phi03_melt_temperature_1D.mp4');
writer=VideoWriter(path,'MPEG-4');writer.FrameRate=fps;writer.Quality=94;open(writer);
wc=onCleanup(@()close(writer)); %#ok<NASGU>
selected=unique([1 ceil(numel(times)/2) numel(times)]);
for j=1:numel(times)
 linephi.XData=phi(:,j);lineT.XData=T(:,j);
 clock.String=sprintf('Time = %.6g years | computed step %d | column x = %.1f km',times(j),steps(j),x);
 drawnow;frame=print(f,'-RGBImage','-r100');assert(isequal(size(frame),[720 1280 3]));
 if ismember(j,selected),imwrite(frame,fullfile(out,sprintf('preview_%04d.png',j)));end
 for k=1:repeats(j),writeVideo(writer,frame);end
 if j==1 || mod(j,10)==0 || j==numel(times),fprintf('PROFILE_VIDEO_FRAME %d/%d t=%.6g\n',j,numel(times),times(j));end
end
clear wc;
% Static plot: actual initial, midpoint and final saved profiles.
delete([firstphi firstT linephi lineT]);
colors=[.5 .5 .5;.1 .6 .5;.02 .35 .65];styles={'--',':','-'};
chosen=unique([1 ceil(numel(times)/2) numel(times)]);
for k=1:numel(chosen)
 j=chosen(k);label=sprintf('t = %.4g yr',times(j));
 plot(a,phi(:,j),z,styles{k},'Color',colors(k,:),'LineWidth',2,'DisplayName',label);
 plot(b,T(:,j),z,styles{k},'Color',colors(k,:),'LineWidth',2,'DisplayName',label);
end
clock.String=sprintf('Initial and saved evolution through %.6g years | actual column x = %.1f km',times(end),x);
legend(a,'Location','southwest','Interpreter','none');legend(b,'Location','southwest','Interpreter','none');
drawnow;imwrite(print(f,'-RGBImage','-r150'),fullfile(out,'flat_phi03_melt_temperature_1D.png'));
savefig(f,fullfile(out,'flat_phi03_melt_temperature_1D.fig'));
reader=VideoReader(path);assert(reader.Width==1280 && reader.Height==720 && reader.FrameRate==fps);
assert(abs(reader.Duration-sum(repeats)/fps)<1/fps+.001);
starts=[0;cumsum(repeats(1:end-1))]/fps;errors=zeros(size(selected));
for k=1:numel(selected)
 j=selected(k);reader.CurrentTime=min(starts(j)+repeats(j)/(2*fps),reader.Duration-1/fps);
 actual=readFrame(reader);expected=imread(fullfile(out,sprintf('preview_%04d.png',j)));
 assert(isequal(size(actual),size(expected)));
 errors(k)=mean(abs(double(actual(:))-double(expected(:))));assert(errors(k)<8);
 imwrite(actual,fullfile(out,sprintf('decoded_%04d.png',j)));
end
info=struct('status','passed','path',path,'saved_states',numel(times), ...
 'final_time_years',times(end),'width',reader.Width,'height',reader.Height, ...
 'fps',fps,'duration_seconds',reader.Duration,'actual_column_x_km',x, ...
 'spatial_interpolation',false,'temporal_interpolation',false, ...
 'mean_absolute_RGB_errors',errors,'selected_profile_time_years',times(chosen)');
fid=fopen(fullfile(out,'verification.json'),'w');fprintf(fid,'%s',jsonencode(info));fclose(fid);
fprintf('FLAT_PHI03_1D_VERIFIED %s\n',jsonencode(info));
end
