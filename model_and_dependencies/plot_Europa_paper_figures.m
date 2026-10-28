function helpers=plot_Europa_paper_figures(output_dir,build_dir,live_dir,middle_dir)
% Manuscript figure style, corrected saved data, no interpolated field states.
% Reuses conventions from Europa_video_creation, plot_Europa_saved_times and
% plot_Europa_permeability_comparison. This postprocessor never advances flow.
% H=plot_Europa_paper_figures('helpers') exposes these same saved-data helpers.
if nargin==1 && strcmp(output_dir,'helpers')
 helpers=struct('read_case',@read_case,'select_states',@select_states,'load_fields',@load_fields, ...
  'field_strip',@field_strip,'history_figure',@history_figure,'new_figure',@new_figure, ...
  'style',@style,'kc_label',@kc_label,'finish',@finish,'footnote',@footnote,'panel_letter',@panel_letter, ...
  'horizontal_scale',@horizontal_scale);return;
end
root=fileparts(mfilename('fullpath'));repo=fileparts(root);
if nargin<3,live_dir=strtrim(fileread(fullfile(repo,'tmp','Europa_S3_latest_run.txt')));end
if nargin<2
 p=jsondecode(fileread(fullfile(repo,'tmp','manuscript_figures_latest.json')));
 output_dir=p.output_dir;build_dir=p.build_dir;
end
if ~isfolder(output_dir),mkdir(output_dir);end
if ~isfolder(fullfile(build_dir,'pages')),mkdir(fullfile(build_dir,'pages'));end
set(groot,'defaultAxesFontName','Times New Roman','defaultTextFontName','Times New Roman', ...
 'defaultAxesFontSize',13,'defaultTextFontSize',13,'defaultTextInterpreter','tex', ...
 'defaultAxesTickLabelInterpreter','tex','defaultLegendInterpreter','tex', ...
 'defaultFigureVisible','off');
if nargin>=4 && ~isempty(middle_dir)
 three_case_figures(output_dir,build_dir,live_dir,middle_dir,repo);return;
end
low=read_case(fullfile(repo,'Output','Europa_kc_1.850e-16_until_depleted_20261024_085440'),'low',build_dir,false);
high=read_case(fullfile(repo,'Output','Europa_kc_1.850e-08_until_depleted_20261023_195524'),'completed_high',build_dir,false);
live=read_case(live_dir,'current_high',build_dir,true);
low.requested=[0 100 300 500 650 1000 2000 5000 20000 low.index.time_years(end)];
live.requested=[0 30 60 75 80 85 100 200 400 live.index.time_years(end)];
high.requested=[0 30 60 75 80 85 100 300 1000 high.index.time_years(end)];
low=select_states(low);live=select_states(live);high=select_states(high);
writetable(low.selected,fullfile(output_dir,'Figure6_low_selected_states.csv'));
writetable(live.selected,fullfile(output_dir,'Figure6_current_high_selected_states.csv'));
writetable(high.selected,fullfile(output_dir,'Figure6_completed_high_selected_states.csv'));
facts=struct('reference_pdf','Impact_melt_foundering (1).pdf','font','Times New Roman', ...
 'main_low_run',low.directory,'main_high_run',live.directory, ...
 'completed_high_for_final_delivery',high.directory,'main_high_status',live.status, ...
 'main_high_cutoff_years',live.budget.time_years(end),'main_high_cutoff_step',height(live.budget)-1, ...
 'main_history_phi_threshold',.001,'seconds_per_year',3.154e7,'data_interpolation',false, ...
 'missing_cases',{{'corrected Titan evolution','Europa kc=1.85e-10','empirical permeability scatter/error bars'}}, ...
 'field_display','Actual cell values; temperature and melt colormaps discretized for display; no temperature-band outlines.', ...
 'depth_definition','Surface minus deepest shell cell centre with phi>=0.001; deepest shell centre is z=0.05 km.', ...
 'source_plot_scripts',{{'Europa_video_creation.m','plot_Europa_saved_times.m','plot_Europa_permeability_comparison.m'}});
fid=fopen(fullfile(output_dir,'plot_provenance.json'),'w');fprintf(fid,'%s',jsonencode(facts));fclose(fid);

% Figure 4: completed-volume points; model law, omitting unavailable scatter.
f=new_figure(1100,450);
ax=axes(f,'Position',[.095 .21 .36 .69]);hold(ax,'on');
plot(ax,[low.kc high.kc],[low.summary.delivered_net_km3 high.summary.delivered_net_km3], ...
 '^','LineStyle','none','Color',[.28 .28 .28],'MarkerFaceColor','w','MarkerSize',9,'LineWidth',1.25);
set(ax,'XScale','log','XLim',[1e-16 3e-8],'YLim',[0 40],'XTick',10.^(-16:2:-8),'YTick',0:5:40);
style(ax);xlabel(ax,'Permeability coefficient k_0 [m^2]');ylabel(ax,'Melt delivered to ocean [km^3]');
legend(ax,{'Mannann''an crater, completed runs'},'Location','southwest','Box','off','FontSize',10);
panel_letter(ax,'(a)');
ax=axes(f,'Position',[.575 .21 .35 .69]);hold(ax,'on');
phi=logspace(-3,0,300);coefficients=[1.85e-8 1.85e-9 1.85e-10 1.85e-12 1.85e-14];
handles=gobjects(1,numel(coefficients));labels=cell(size(coefficients));
for j=1:numel(coefficients)
 shade=.12+.13*(j-1);handles(j)=plot(ax,phi,coefficients(j)*phi.^3,'Color',shade*[1 1 1],'LineWidth',1.1);
 labels{j}=['k_0 = 1.85 \times 10^{' num2str(round(log10(coefficients(j)/1.85))) '} m^2'];
end
set(ax,'XScale','log','YScale','log','XLim',[1e-3 1],'YLim',[1e-17 1e-9], ...
 'XTick',[.001 .01 .1 1],'YTick',10.^(-17:2:-9));style(ax);
xlabel(ax,'\phi [-]');ylabel(ax,'k [m^2]');panel_letter(ax,'(b)');
legend(ax,handles,labels,'Location','southeast','Box','on','Color','w','EdgeColor','none','FontSize',9);
footnote(f,'Completed Europa endpoints only. Titan points, empirical scatter, confidence bands and unsupplied error bars omitted.');
finish(f,'01_Figure4_delivery_and_permeability',output_dir,build_dir);

% Figure 5: analytic equations 9-11, using explicitly recorded model constants.
f=new_figure(1100,780);TC=linspace(-20,0,181);Vt=linspace(50,500,181);Ve=linspace(10,100,181);
theory=struct('melting_point_K',273,'eta0_Pa_s',1e14,'Ea_J_mol',50000,'R_J_mol_K',8.314, ...
 'rho_water_kg_m3',1000,'rho_ice_kg_m3',920,'mu_water_Pa_s',1e-3,'seconds_per_year',3.154e7, ...
 'Titan_g_m_s2',1.352,'Titan_shell_m',60000,'Europa_g_m_s2',1.315,'Europa_shell_m',10000);
for row=1:2
 if row==1,V=Vt;g=1.352;d=60000;bottom=.57;else,V=Ve;g=1.315;d=10000;bottom=.15;end
 [Tmesh,Vmesh]=meshgrid(TC,V);radius=(3*Vmesh*1e9/(4*pi)).^(1/3);
 eta=1e14*exp((50000/8.314/273)*(273./(273+Tmesh)-1));
 speed=(2/9)*80*g*radius.^2./eta;foundering=d./speed/3.154e7;
 ax=axes(f,'Position',[.085 bottom .29 .32]);
 contourf(ax,Tmesh,Vmesh,foundering,linspace(0,ceil(max(foundering(:))/500)*500,17),'LineColor',[.15 .15 .15],'LineWidth',.35);
 colormap(ax,parula(256));style(ax);xlim(ax,[-20 0]);ylim(ax,[min(V) max(V)]);
 xlabel(ax,'Ice shell temperature [^oC]');ylabel(ax,'Melt volume [km^3]');
 cb=colorbar(ax);cb.Position=[.395 bottom .018 .32];cb.Label.String='Foundering time [years]';cb.FontName='Times New Roman';cb.FontSize=10;cb.Label.FontSize=11;
 set(ax,'Position',[.085 bottom .29 .32]);panel_letter(ax,sprintf('(%c)','a'+2*(row-1)));
 pp=logspace(-3,0,201);kk=logspace(-16,-8,161);[PHI,KC]=meshgrid(pp,kk);
 infiltration=d./(KC.*PHI.^2*1000*g/1e-3)/3.154e7;
 ax=axes(f,'Position',[.59 bottom .29 .32]);
 contourf(ax,PHI,KC,log10(infiltration),-2:1:14,'LineColor',[.15 .15 .15],'LineWidth',.35);
 colormap(ax,parula(256));caxis(ax,[-2 14]);set(ax,'YScale','log','XLim',[0 1],'YLim',[1e-16 1e-8], ...
 'XTick',0:.2:1,'YTick',10.^(-16:2:-8));style(ax);
 xlabel(ax,'Melt fraction, \phi [-]');ylabel(ax,'Permeability coefficient k_0 [m^2]');
 cb=colorbar(ax);cb.Ticks=-2:2:14;cb.TickLabels=arrayfun(@(q)sprintf('10^{%d}',q),-2:2:14,'UniformOutput',false);
 cb.Position=[.91 bottom .018 .32];cb.Label.String='Infiltration time [years]';cb.FontName='Times New Roman';cb.FontSize=10;cb.Label.FontSize=11;
 set(ax,'Position',[.59 bottom .29 .32]);panel_letter(ax,sprintf('(%c)','b'+2*(row-1)));
end
footnote(f,'Theory from manuscript equations 9-11; model constants recorded separately. Simulation-location markers omitted.');
finish(f,'02_Figure5_theoretical_timescales',output_dir,build_dir);
fid=fopen(fullfile(output_dir,'Figure5_theory_parameters.json'),'w');fprintf(fid,'%s',jsonencode(theory));fclose(fid);

% Figure 6 main: the paper's three-row strip, actual informative corrected times.
field_strip(low,live,'03_Figure6_corrected_evolution',output_dir,build_dir, ...
 'Corrected timescales; panel (c) is the current run, ongoing. Each label is an actual saved time.');
paperlow=low;paperlow.requested=[0 23 52 93 140 259 455 682 1465 7041];paperlow=select_states(paperlow);
paperhigh=live;paperhigh.requested=[0 .003 .005 .008 .010 .013 .016 .110 .482 5.196];paperhigh=select_states(paperhigh);
writetable(paperlow.selected,fullfile(output_dir,'Figure6_paper_time_low_selections.csv'));
writetable(paperhigh.selected,fullfile(output_dir,'Figure6_paper_time_high_selections.csv'));
field_strip(paperlow,paperhigh,'04_Figure6_original_time_requests',output_dir,build_dir, ...
 'Original Figure 6 requested times; first available saved state at/after each request, with actual time labels.');

% Figure 7 and its semilog version. Markers correspond exactly to main Figure 6.
history_figure(low,live,false,'05_Figure7_volume_and_penetration',output_dir,build_dir);
history_figure(low,live,true,'06_FigureS4_semilog_volume_and_penetration',output_dir,build_dir);
history_figure(low,high,true,'07_completed_Europa_reference_histories',output_dir,build_dir);

% Additional requested diagnostics: delivery and signed net refreezing vs time.
f=new_figure(1150,480);colors=[.21 .36 .63;.75 .18 .17];cases={low,live};
for panel=1:2
 ax=axes(f,'Position',[.09+(panel-1)*.48 .21 .36 .68]);hold(ax,'on');hh=gobjects(1,2);
 for k=1:2
  c=cases{k};b=c.budget;positive=b.time_years>0;
  if panel==1,y=b.delivered_net_m3/1e9;else,y=b.refrozen_net_shell_m3/1e9;end
  hh(k)=plot(ax,b.time_years(positive),y(positive),'Color',colors(k,:),'LineWidth',1.5);
 end
 set(ax,'XScale','log','XLim',[.003 5e4]);style(ax);xlabel(ax,'Time [years]');
 if panel==1,ylabel(ax,'Melt delivered to ocean [km^3]');ylim(ax,[0 35]);
 else,ylabel(ax,'Net refrozen in shell [km^3]');ylim(ax,[0 6]);end
 legend(ax,hh,{'k_0 = 1.85 \times 10^{-16} m^2, complete','k_0 = 1.85 \times 10^{-8} m^2, ongoing'}, ...
  'Location','northwest','Box','off','FontSize',10);panel_letter(ax,sprintf('(%c)','a'+panel-1));
end
footnote(f,'Net downward transfer across z=0. Net refreezing includes initial equilibration and offsets new melting. t=0 omitted on log axes.');
finish(f,'08_delivery_and_refreezing_histories',output_dir,build_dir);
fid=fopen(fullfile(output_dir,'PLOTTING_COMPLETE.txt'),'w');fprintf(fid,'Eight figure pages created using immutable saved states.\n');fclose(fid);
fprintf('PAPER_FIGURES_COMPLETE %s\n',output_dir);
end

function c=read_case(folder,label,build,is_live)
target=fullfile(build,'inputs',label);if ~isfolder(target),mkdir(target);end
budget_file=fullfile(folder,'melt_budget.csv');
if isfile(fullfile(folder,'STOPPED_BY_USER.json'))
 stopped=jsondecode(fileread(fullfile(folder,'STOPPED_BY_USER.json')));
 budget_file=stopped.matched_budget;copyfile(fullfile(folder,'STOPPED_BY_USER.json'),target);
end
for attempt=1:10
 try
  info1=dir(budget_file);raw=fileread(budget_file);info2=dir(budget_file);
  assert(info1.bytes==info2.bytes && info1.datenum==info2.datenum && any(raw(end)==[10 13]));
  fid=fopen(fullfile(target,'melt_budget.csv'),'w');fprintf(fid,'%s',raw);fclose(fid);
  budget=readtable(fullfile(target,'melt_budget.csv'));assert(budget.time_years(1)==0 && all(diff(budget.time_years)>0));break;
 catch err
  if attempt==10,rethrow(err);end;pause(.5);
 end
end
c=struct('directory',folder,'budget',budget,'label',label,'status','complete');
config=jsondecode(fileread(fullfile(folder,'run_configuration.json')));c.kc=config.kc;
copyfile(fullfile(folder,'run_configuration.json'),target);
if isfile(fullfile(folder,'summary.json')),c.summary=jsondecode(fileread(fullfile(folder,'summary.json')));else,c.summary=[];end
if is_live && ~isfile(fullfile(folder,'COMPLETE.txt')),c.status='ongoing';end
if isfile(fullfile(folder,'STOPPED_BY_USER.json'))
 c.status='stopped_by_user';
 assert(height(budget)==c.summary.steps+1 && abs(budget.time_years(end)-c.summary.time_years)<1e-7);
end
if ~isempty(c.summary),copyfile(fullfile(folder,'summary.json'),target);end
steps=[];times=[];paths={};kinds={};
if is_live && isfile(fullfile(folder,'paper_outputs','field_manifest.json'))
 m=jsondecode(fileread(fullfile(folder,'paper_outputs','field_manifest.json')));
 for j=1:numel(m)
  if iscell(m),s=m{j};else,s=m(j);end
  if s.step<height(budget) && abs(s.time_years-budget.time_years(s.step+1))<1e-7
   steps(end+1)=s.step;times(end+1)=s.time_years;paths{end+1}=fullfile(folder,s.source);kinds{end+1}=s.kind; %#ok<AGROW>
  end
 end
else
 files=dir(fullfile(folder,'states','state_*.mat'));
 for j=1:numel(files)
  step=sscanf(files(j).name,'state_%d.mat');
  if step<height(budget)
   steps(end+1)=step;times(end+1)=budget.time_years(step+1);paths{end+1}=fullfile(files(j).folder,files(j).name);kinds{end+1}='full_solver_state'; %#ok<AGROW>
  end
 end
end
[steps,order]=sort(steps);times=times(order);paths=paths(order);kinds=kinds(order);
[steps,keep]=unique(steps,'stable');times=times(keep);paths=paths(keep);kinds=kinds(keep);
c.index=table(steps(:),times(:),paths(:),kinds(:),'VariableNames',{'step','time_years','source','kind'});
assert(height(c.index)>10 && all(diff(c.index.time_years)>0));
writetable(budget,fullfile(target,'budget_snapshot.csv'));
end

function c=select_states(c)
selection=zeros(1,numel(c.requested));
for j=1:numel(selection)
 idx=find(c.index.time_years>=c.requested(j)-1e-9*max(1,c.requested(j)),1);
 assert(~isempty(idx),'Requested state is not available.');selection(j)=idx;
end
c.selected=c.index(selection,:);c.selected.requested_years=c.requested(:);
c.selected.offset_years=c.selected.time_years-c.selected.requested_years;
end

function s=load_fields(row)
path=row.source{1};kind=row.kind{1};
if strcmp(kind,'full_solver_state')
 q=load(path,'state');a=q.state;
 s=struct('phi',a.phi,'temperature_K',a.temperature_K,'radius_km',a.radius_m/1000, ...
  'elevation_km',a.elevation_m/1000,'step',a.step,'time_years',a.time_years);
 assert(a.permeability_exponent==3);
else
 a=load(path,'T','phi','Grid','d','i','tTot');
 s=struct('phi',a.phi,'temperature_K',a.T*173+100,'radius_km',a.Grid.p.xc*a.d/1000, ...
  'elevation_km',a.Grid.p.yc*a.d/1000,'step',a.i,'time_years',a.tTot);
end
assert(s.step==row.step && abs(s.time_years-row.time_years)<1e-7);
assert(all(isfinite(s.phi)) && all(isfinite(s.temperature_K)));
end

function field_strip(low,high,stem,out,build,note,middle)
if nargin<7,middle=[];end
f=new_figure(1420,700);rowy=[.71 .445 .18];width=.086;height=.176;left=.075;
cache=fullfile(out,'selected_fields');if ~isfolder(cache),mkdir(cache);end
annotation(f,'textbox',[.43 .95 .12 .04],'String','t [year]','EdgeColor','none','FontSize',17);
annotation(f,'arrow',[.55 .83],[.968 .968],'LineWidth',1.4);
cases={low,middle,high};panels=find(~cellfun(@isempty,cases));
for row=panels
 c=cases{row};
 for col=1:10
  s=load_fields(c.selected(col,:));r=s.radius_km(:);z=s.elevation_km(:);
  cachefile=fullfile(cache,sprintf('%s_step_%08d.mat',c.label,s.step));
  if ~isfile(cachefile),save(cachefile,'s');end
  nr=numel(r);nz=numel(z);P=reshape(s.phi,nz,nr);T=reshape(s.temperature_K,nz,nr);
  ix=r<10;iz=z>=0;r=r(ix);z=z(iz);P=P(iz,ix);T=T(iz,ix);
  ax=axes(f,'Position',[left+(col-1)*width rowy(row) width height]);hold(ax,'on');
  bone_map=bone(256);melt_map=flipud(parula(256));
  rgb=ind2rgb(1+floor(255*max(0,min(1,(T-100)/173))),bone_map);
  melt_rgb=ind2rgb(1+floor(255*max(0,min(1,P))),melt_map);
  wet=repmat(P>=1e-3,1,1,3);rgb(wet)=melt_rgb(wet);
  img=imagesc(ax,r,z,rgb);
  if isprop(img,'Interpolation'),img.Interpolation='nearest';end
  set(ax,'YDir','normal','XLim',[0 10],'YLim',[0 10],'XTick',[],'YTick',[], ...
   'Box','on','LineWidth',.45,'Layer','top','FontName','Times New Roman','FontSize',11);
  if col==1
   set(ax,'YTick',[0 5 10]);ylabel(ax,'z-dir [km]');
   if row==3,set(ax,'XTick',[0 5 10]);xlabel(ax,'r [km]');end
  end
  title(ax,time_label(s.time_years),'FontName','Times New Roman','FontWeight','normal','FontSize',14);
 end
 annotation(f,'textbox',[.012 rowy(row)+height-.005 .055 .05],'String',sprintf('(%c)','a'+row-1), ...
  'EdgeColor','none','FontSize',21,'FitBoxToText','on');
 if ~isempty(middle)
  caption=kc_label(c);
  if strcmp(c.status,'stopped_by_user'),caption=[caption '  |  user-stopped'];end
  annotation(f,'textbox',[left rowy(row)+height+.035 .64 .025],'String',caption, ...
   'EdgeColor','none','Margin',0,'FontSize',11);
 end
end
if isempty(middle)
annotation(f,'textbox',[.012 rowy(2)+height-.005 .055 .05],'String','(b)','EdgeColor','none','FontSize',21);
annotation(f,'textbox',[.30 rowy(2)+.07 .52 .06], ...
 'String','k_0 = 1.85 \times 10^{-10} m^2: corrected simulation not yet available', ...
 'EdgeColor','none','HorizontalAlignment','center','FontSize',14,'Color',[.45 .45 .45]);
end
scale_y=.115;if ~isempty(middle),scale_y=.145;end
horizontal_scale(f,[.30 scale_y .27 .014],[0 1],flipud(parula(256)),0:.2:1,'Melt fraction');
horizontal_scale(f,[.68 scale_y .25 .014],[100 273],bone(256),[100 150 200 250],'Temperature, K');
note_y=.435;if ~isempty(middle),note_y=.018;end
annotation(f,'textbox',[.08 note_y .87 .035],'String',note,'EdgeColor','none','Margin',0,'FontSize',8.5,'HorizontalAlignment','center');
finish(f,stem,out,build);
end

function history_figure(low,high,is_log,stem,out,build,middle)
if nargin<7,middle=[];end
f=new_figure(1100,470);cases={low,middle,high};blue=[.20 .37 .65];red=[.76 .16 .15];
panels=find(~cellfun(@isempty,cases));
for panel=panels
 c=cases{panel};b=c.budget;pos=[.08+(panel-1)*.305 .21 .205 .69];
 if is_log,xlimits=[.003 10^ceil(log10(b.time_years(end)))];keep=b.time_years>0;
 else
  if panel==1,xlimits=[0 1500];elseif panel==2,xlimits=[0 5000];else,xlimits=[0 500];end
  keep=true(height(b),1);
 end
 ax=axes(f,'Position',pos);hold(ax,'on');plot(ax,b.time_years(keep),b.melt_shell_m3(keep)/1e9,'Color',blue,'LineWidth',1.6);
 rows=c.selected.step+1;valid=b.time_years(rows)>0 | ~is_log;
 plot(ax,b.time_years(rows(valid)),b.melt_shell_m3(rows(valid))/1e9,'o','Color',blue,'MarkerFaceColor',blue,'MarkerSize',4);
 set(ax,'XLim',xlimits,'YLim',[0 35],'YTick',0:5:35,'YColor',blue,'LineWidth',.7,'TickDir','in','Box','off');
 if is_log
  powers=unique([ceil(log10(xlimits(1))):2:floor(log10(xlimits(2))) floor(log10(xlimits(2)))]);
  if ~isempty(middle),powers=ceil(log10(xlimits(1))):2:floor(log10(xlimits(2)));end
  set(ax,'XScale','log','XTick',10.^powers);
 else
  if panel==1,ticks=0:500:1500;elseif panel==2,ticks=0:2500:5000;else,ticks=0:100:500;end
  set(ax,'XTick',ticks,'XTickLabelRotation',0);ax.XAxis.Exponent=0;
 end
 xlabel(ax,'Time [years]');ylabel(ax,'Melt volume [km^3]');
 if ~isempty(middle)
  title(ax,kc_label(c),'FontSize',11,'FontWeight','normal');
  if panel~=1,ylabel(ax,'');end
 end
 text(ax,.95,.98,sprintf('(%c)','a'+panel-1),'Units','normalized','HorizontalAlignment','right','VerticalAlignment','top','Color','k','FontSize',17);
 dep=axes(f,'Position',pos,'Color','none','YAxisLocation','right','YDir','reverse','XLim',xlimits, ...
  'YLim',[3 10],'YTick',3:10,'XTick',[],'YColor',red,'XColor','none','LineWidth',.7,'Box','off');hold(dep,'on');
 if is_log,set(dep,'XScale','log');end
 plot(dep,b.time_years(keep),b.penetration_depth_km(keep),'--','Color',red,'LineWidth',1.5);
 plot(dep,b.time_years(rows(valid)),b.penetration_depth_km(rows(valid)),'o','Color',red,'MarkerFaceColor',red,'MarkerSize',4);
 if strcmp(c.status,'stopped_by_user')
  plot(ax,b.time_years(end),b.melt_shell_m3(end)/1e9,'s','Color',blue,'MarkerFaceColor','w','MarkerSize',6);
  plot(dep,b.time_years(end),b.penetration_depth_km(end),'s','Color',red,'MarkerFaceColor','w','MarkerSize',6);
 end
 ylabel(dep,'Penetration depth [km]');
 if ~isempty(middle) && panel~=3,ylabel(dep,'');end
 if strcmp(c.status,'ongoing')
  labelpos=[.35 .90];if is_log,labelpos=[.06 .70];end
  if is_log,status_label=sprintf('Ongoing to %.4g yr',b.time_years(end));else,status_label='Run ongoing';end
  text(ax,labelpos(1),labelpos(2),status_label,'Units','normalized','FontSize',9,'Color',[.25 .25 .25]);
 end
end
if isempty(middle)
annotation(f,'textbox',[.405 .55 .18 .20],'String',{'(b)','k_0 = 1.85 \times 10^{-10} m^2','Not yet simulated'}, ...
 'HorizontalAlignment','center','EdgeColor','none','FontSize',12,'Color',[.45 .45 .45]);
if is_log,note='Semilog time axis; t=0 omitted. ';else,note='Display limits: (a) 0-1500 yr; (c) 0-500 yr. ';end
footnote(f,[note 'Markers are selected actual saved states. Red depth uses \phi \geq 0.001 and 100-m cell centres.']);
else
 note='';if is_log,note='Log time (t>0). ';end
 if strcmp(middle.status,'stopped_by_user')
  note=[note sprintf('Panel (b) stopped: %.0f yr, %.3f%% remaining. ',middle.budget.time_years(end),100*middle.summary.remaining_fraction)];
  note=[note 'Open squares: partial endpoints. '];
 elseif all(cellfun(@(c)strcmp(c.status,'complete'),cases))
  note=[note 'All cases: depletion complete. '];
 end
 footnote(f,[note 'Depth: \phi \geq 0.001.']);
end
finish(f,stem,out,build);
end
function label=kc_label(c)
label=['k_0 = 1.85 \times 10^{' num2str(round(log10(c.kc/1.85))) '} m^2'];
end

function three_case_figures(out,build,high_dir,middle_dir,repo)
low=read_case(fullfile(repo,'Output','Europa_kc_1.850e-16_until_depleted_20261024_085440'),'low',build,false);
middle=read_case(middle_dir,'middle',build,true);
high=read_case(high_dir,'high',build,true);
assert(low.kc==1.85e-16 && middle.kc==1.85e-12 && high.kc==1.85e-8);
assert(strcmp(low.summary.status,'melt_depleted') && strcmp(high.summary.status,'melt_depleted'));
assert(strcmp(middle.status,'stopped_by_user') && ~middle.summary.depletion_reached);
low.requested=[0 100 300 500 650 1000 2000 5000 20000 low.budget.time_years(end)];
middle.requested=[0 100 300 600 800 900 1000 2000 5000 middle.budget.time_years(end)];
high.requested=[0 30 60 75 80 85 100 200 400 high.budget.time_years(end)];
low=select_states(low);middle=select_states(middle);high=select_states(high);
cases={low,middle,high};records=cell(1,3);
for k=1:3
 c=cases{k};writetable(c.selected,fullfile(out,[c.label '_selected_states.csv']));
 records{k}=struct('label',c.label,'panel',char('a'+k-1),'directory',c.directory, ...
  'kc_m2',c.kc,'status',c.status,'summary',c.summary,'cutoff_step',height(c.budget)-1, ...
  'cutoff_years',c.budget.time_years(end));
end
facts=struct('font','Times New Roman','data_interpolation',false,'cases',{records}, ...
 'temperature_band_outlines',false,'graphics_smoothing',false, ...
 'linear_xlimits_years',[0 1500;0 5000;0 500],'depth_phi_threshold',.001, ...
 'depth_definition','Surface minus deepest shell cell centre with phi>=0.001.', ...
 'source_plot_scripts',{{'plot_Europa_paper_figures.m','Europa_video_creation.m'}}, ...
 'partial_endpoint_note','The middle case is user-stopped; its endpoint is not a depletion-complete result.');
fid=fopen(fullfile(out,'plot_provenance.json'),'w');fprintf(fid,'%s',jsonencode(facts));fclose(fid);
history_figure(low,high,false,'01_manuscript_volume_and_penetration',out,build,middle);
history_figure(low,high,true,'02_full_time_semilog_histories',out,build,middle);
field_strip(low,high,'03_manuscript_temperature_and_melt',out,build, ...
 'Actual saved times; no interpolation. Panel (b) is user-stopped at 54,818 yr with 0.628% initial shell melt remaining.',middle);
fid=fopen(fullfile(out,'PLOTTING_COMPLETE.txt'),'w');fprintf(fid,'Three-case figures created from saved data only.\n');fclose(fid);
fprintf('THREE_CASE_FIGURES_COMPLETE %s\n',out);
end
function horizontal_scale(f,position,limits,map,ticks,label)
ax=axes(f,'Position',position,'FontName','Times New Roman','FontSize',12);
image(ax,linspace(limits(1),limits(2),256),.5,reshape(map,1,256,3));
set(ax,'XLim',limits,'YLim',[0 1],'YDir','normal','YTick',[],'YColor','none', ...
 'XTick',ticks,'XAxisLocation','bottom','TickDir','out','Box','on','LineWidth',.5,'FontSize',12,'FontName','Times New Roman');
xlabel(ax,label,'FontSize',12);
end

function f=new_figure(w,h)
f=figure('Visible','off','Color','w','Position',[40 40 w h],'GraphicsSmoothing','off', ...
 'PaperUnits','inches','PaperPosition',[0 0 w/110 h/110],'PaperSize',[w/110 h/110],'InvertHardcopy','off');
end
function style(ax)
set(ax,'FontName','Times New Roman','FontSize',12,'Box','on','LineWidth',.75,'TickDir','in','XMinorTick','on','YMinorTick','on');
end
function panel_letter(ax,label)
text(ax,-.12,1.07,label,'Units','normalized','FontSize',19,'Color','k');
end
function footnote(f,note)
annotation(f,'textbox',[.06 .018 .89 .065],'String',note,'EdgeColor','none','HorizontalAlignment','center','FontSize',10);
end
function label=time_label(t)
if t==0,label='0';elseif t<1,label=sprintf('%.3g',t);elseif t<100,label=sprintf('%.3g',t);else,label=sprintf('%.0f',t);end
end
function finish(f,stem,out,build)
drawnow;
print(f,fullfile(build,'pages',[stem '.pdf']),'-dpdf','-painters');
print(f,fullfile(out,[stem '.svg']),'-dsvg','-painters');
savefig(f,fullfile(out,[stem '.fig']),'compact');
close(f);fprintf('FIGURE_SAVED %s\n',stem);
end
