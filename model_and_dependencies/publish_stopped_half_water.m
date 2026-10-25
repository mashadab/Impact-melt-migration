function report=publish_stopped_half_water(output_dir)
% Advisor figures and a video from actual archived states of the stopped run.
% No new flow solves, interpolated simulation states, or invented endpoint.
if nargin<1
 root=fileparts(fileparts(mfilename('fullpath')));
 output_dir=strtrim(fileread(fullfile(root,'tmp','half_water_1yr_output.txt')));
end
out=fullfile(output_dir,'advisor');if ~isfolder(out),mkdir(out);end
frames=fullfile(out,'video_frames');if ~isfolder(frames),mkdir(frames);end
initial=load(fullfile(output_dir,'initial_state.mat'),'initial_state');initial=initial.initial_state;
files=dir(fullfile(output_dir,'states','state_*.mat'));[~,order]=sort({files.name});files=files(order);
states={initial};times=0;steps=0;sources={'initial_state.mat'};
for j=1:numel(files)
 try
  loaded=load(fullfile(output_dir,'states',files(j).name),'checkpoint');a=loaded.checkpoint;
  assert(isfield(a,'phi') && all(isfinite(a.phi)));
 catch
  continue % an interrupted write must never become a video frame
 end
 states{end+1}=a;times(end+1)=a.time_years;steps(end+1)=a.completed_steps; %#ok<AGROW>
 sources{end+1}=fullfile('states',files(j).name); %#ok<AGROW>
end
assert(numel(states)>1);last=states{end};
G=last.Grid.p;d=last.d_m;[~,Z]=meshgrid(G.xc*d,G.yc*d);
report=struct('status','stopped_by_user','last_full_saved_step',last.completed_steps, ...
 'last_full_saved_time_years',last.time_years,'last_full_saved_source',sources{end}, ...
 'max_phi_initial_lower_half',max(last.phi(Z(:)<4000)), ...
 'max_temperature_change_K',max(abs((last.T_dimensionless-initial.T_dimensionless)*173)), ...
 'number_of_actual_video_states',numel(states),'no_state_or_time_interpolation',true);
if isfile(fullfile(output_dir,'progress_last_reported_before_stop.json'))
 report.last_live_report=jsondecode(fileread(fullfile(output_dir,'progress_last_reported_before_stop.json')));
end
copyfile(fullfile(output_dir,'initial_state.mat'),fullfile(out,'initial_state.mat'));
copyfile(fullfile(output_dir,sources{end}),fullfile(out,'last_saved_state.mat'));
f=draw_comparison(initial,last,report);
print(f,fullfile(out,'initial_vs_last_saved.png'),'-dpng','-r200');
print(f,fullfile(out,'initial_vs_last_saved.svg'),'-dsvg');close(f);
f=draw_state(initial,0,0);print(f,fullfile(out,'initial_snapshot.png'),'-dpng','-r180');close(f);
f=draw_state(last,times(end),steps(end));print(f,fullfile(out,'last_saved_snapshot.png'),'-dpng','-r180');close(f);
writer=VideoWriter(fullfile(out,'flat_layer_saved_states.mp4'),'MPEG-4');
writer.FrameRate=24;writer.Quality=95;open(writer);counts=zeros(numel(states),1);
for j=1:numel(states)
 f=draw_state(states{j},times(j),steps(j));
 png=fullfile(frames,sprintf('frame_%04d.png',j));print(f,png,'-dpng','-r100');close(f);
 pixels=imread(png);
 if j<numel(states),hold_seconds=12*(times(j+1)-times(j))/times(end);else,hold_seconds=2;end
 if j==1,hold_seconds=hold_seconds+1;end
 counts(j)=max(1,round(hold_seconds*writer.FrameRate));
 for k=1:counts(j),writeVideo(writer,pixels);end
end
close(writer);
mapping=table(steps(:),times(:),sources(:),counts, ...
 'VariableNames',{'step','actual_time_years','source_file','held_video_frames'});
writetable(mapping,fullfile(out,'video_frame_sources.csv'));
reader=VideoReader(fullfile(out,'flat_layer_saved_states.mp4'));
report.video_frame_rate=reader.FrameRate;report.video_duration_seconds=reader.Duration;
report.video_size_pixels=[reader.Width reader.Height];report.planned_video_frames=sum(counts);
assert(reader.Width==1280 && reader.Height==720);
assert(abs(reader.Duration-sum(counts)/24)<1/24);
fid=fopen(fullfile(out,'preservation_report.json'),'w');fprintf(fid,'%s',jsonencode(report));fclose(fid);
fid=fopen(fullfile(output_dir,'stop_record.json'),'w');fprintf(fid,'%s',jsonencode(report));fclose(fid);
fid=fopen(fullfile(out,'README.md'),'w');
fprintf(fid,['# Flat-layer test: preserved advisor artifacts\n\n' ...
 'The run was stopped by the user. The last complete archived state is step %d at %.12g years. ' ...
 'The final live report was step %d at %.12g years; there is no full archived field for that later live report. ' ...
 'The figures and video explicitly use the last complete saved state.\n\n' ...
 'The minimal comparison is initial_vs_last_saved.png (editable SVG also supplied). ' ...
 'Initial and last-saved snapshots show liquid fraction and temperature. ' ...
 'The video uses %d actual states; frame holds approximate elapsed simulated-time intervals with opening/closing holds. ' ...
 'No simulation fields or times were interpolated. video_frame_sources.csv lists every source and hold.\n\n' ...
 'Initial water occupies the full width and the upper half, z=4 to 10 km. ' ...
 'The Cartesian domain is x=0 to 20 km and z=-2 to 10 km, with 100 by 120 cells, ' ...
 'kc=1.85e-8 m^2, 273 K initially, and closed, insulated outer boundaries. ' ...
 'The last saved lower-half maximum liquid fraction is %.6g and maximum temperature change is %.6g K.\n\n' ...
 'No visible interface migration occurs. This is not a validation of pore nucleation or pure-water phase velocities: ' ...
 'large cancelling solid-velocity and relative-Darcy components remain in the inherited formulation. ' ...
 'Initial/final MAT files and original run/source files are preserved.\n'], ...
 report.last_full_saved_step,report.last_full_saved_time_years, ...
 report.last_live_report.completed_steps,report.last_live_report.time_years, ...
 numel(states),report.max_phi_initial_lower_half,report.max_temperature_change_K);
fclose(fid);
fprintf('STOPPED_HALF_WATER_PUBLISHED %s\n%s\n',out,jsonencode(report));
end

function f=draw_comparison(initial,last,report)
G=last.Grid.p;d=last.d_m;x=G.xc*d/1000;z=G.yc*d/1000;
f=base_figure(12.8,6.8);height=.36*12.8*.6/6.8;
positions={[.065 .27 .36 height],[.565 .27 .36 height]};
values={initial.phi,last.phi};
for k=1:2
 ax=axes('Parent',f,'Position',positions{k});imagesc(ax,x,z,reshape(values{k},G.Ny,G.Nx));style(ax);clim(ax,[0 1]);colormap(ax,water_map());
 if k==1,label='A   Initial | t = 0';
 else,label=sprintf('B   Last saved | t = %.4f years',last.time_years);cb=colorbar(ax);cb.Ticks=[0 .5 1];cb.Label.String='Liquid fraction';cb.Position=[.94 .27 .012 height];end
 ax.Position=positions{k};
 annotation(f,'textbox',[positions{k}(1) .735 .37 .05],'String',label, ...
  'LineStyle','none','FontName','Arial','FontSize',14,'FontWeight','normal','Interpreter','none');
end
annotation(f,'textbox',[.065 .87 .88 .065],'String','Flat-layer closed-box test', ...
 'LineStyle','none','FontName','Arial','FontSize',19,'Interpreter','none');
annotation(f,'textbox',[.065 .085 .90 .08],'String',sprintf(['100 x 120 Cartesian grid | kc = 1.85e-8 m^2 | initially 273 K | sealed and insulated\n' ...
 'No resolved interface migration | last complete saved step %d'],report.last_full_saved_step), ...
 'LineStyle','none','FontName','Arial','FontSize',10.5,'Interpreter','none');drawnow;
end

function f=draw_state(state,time,step)
G=state.Grid.p;d=state.d_m;x=G.xc*d/1000;z=G.yc*d/1000;
f=base_figure(12.8,7.2);height=.36*12.8*.6/7.2;
p1=[.065 .27 .36 height];p2=[.565 .27 .36 height];
ax=axes('Parent',f,'Position',p1);imagesc(ax,x,z,reshape(state.phi,G.Ny,G.Nx));style(ax);
colormap(ax,water_map());clim(ax,[0 1]);cb=colorbar(ax);cb.Ticks=[0 .5 1];
cb.Position=[.44 .27 .012 height];ax.Position=p1;
ax=axes('Parent',f,'Position',p2);imagesc(ax,x,z,reshape(state.T_dimensionless*173+100,G.Ny,G.Nx));style(ax);
colormap(ax,parula);clim(ax,[272.99 273.01]);cb=colorbar(ax);cb.Ticks=273;
cb.Position=[.94 .27 .012 height];ax.Position=p2;
annotation(f,'textbox',[.065 .70 .36 .05],'String','Liquid fraction', ...
 'LineStyle','none','FontName','Arial','FontSize',14);
annotation(f,'textbox',[.565 .70 .36 .05],'String','Temperature [K]', ...
 'LineStyle','none','FontName','Arial','FontSize',14);
annotation(f,'textbox',[.065 .86 .90 .065], ...
 'String',sprintf('Flat-layer test | saved step %d | t = %.6f years',step,time), ...
 'LineStyle','none','FontName','Arial','FontSize',18,'Interpreter','none');
annotation(f,'textbox',[.065 .11 .90 .06], ...
 'String','Actual saved state | kc = 1.85e-8 m^2 | closed and insulated boundaries', ...
 'LineStyle','none','FontName','Arial','FontSize',10.5,'Interpreter','none');drawnow;
end
function f=base_figure(width,height)
f=figure('Visible','off','Color','w','Units','inches','Position',[.5 .5 width height], ...
 'PaperUnits','inches','PaperPosition',[0 0 width height],'PaperSize',[width height]);
end
function style(ax)
set(ax,'YDir','normal','FontName','Arial','FontSize',12,'Box','on');axis(ax,'image');
xlim(ax,[0 20]);ylim(ax,[-2 10]);xlabel(ax,'x [km]');ylabel(ax,'z [km]');
end
function map=water_map()
map=[linspace(.96,.08,256)' linspace(.98,.36,256)' linspace(1,.64,256)'];
end
