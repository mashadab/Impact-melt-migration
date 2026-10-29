function plot_all_Europa_figures(output_dir,build_dir)
% All saved Europa cases; reuses the existing manuscript plot/data helpers.
root=fileparts(mfilename('fullpath'));repo=fileparts(root);
if nargin<2
 p=jsondecode(fileread(fullfile(repo,'tmp','all_Europa_figures_latest.json')));
 output_dir=p.output_dir;build_dir=p.build_dir;
end
if ~isfolder(output_dir),mkdir(output_dir);end
if ~isfolder(fullfile(build_dir,'pages')),mkdir(fullfile(build_dir,'pages'));end
set(groot,'defaultAxesFontName','Times New Roman','defaultTextFontName','Times New Roman', ...
 'defaultAxesFontSize',12,'defaultTextFontSize',12,'defaultTextInterpreter','tex', ...
 'defaultAxesTickLabelInterpreter','tex','defaultLegendInterpreter','tex','defaultFigureVisible','off');
H=plot_Europa_paper_figures('helpers');
sweep=strtrim(fileread(fullfile(repo,'tmp','Europa_S3_latest_sweep.txt')));
folders={fullfile(repo,'Output','Europa_kc_1.850e-16_until_depleted_20261024_085440'), ...
 fullfile(sweep,'kc_1.850e-14'),fullfile(sweep,'kc_1.850e-12'), ...
 strtrim(fileread(fullfile(repo,'tmp','Europa_S3_kc11_run.txt'))),fullfile(sweep,'kc_1.850e-10'), ...
 fullfile(repo,'Output','Europa_S3_corrected_kc_1.850e-08_20261025_130101')};
labels={'e16','e14','e12','e11','e10','e08'};coefficients=[1.85e-16 1.85e-14 1.85e-12 1.85e-11 1.85e-10 1.85e-8];
n=numel(labels);cases=cell(1,n);records=cell(1,n);selections={};
for k=1:n
 c=H.read_case(folders{k},labels{k},build_dir,k~=1);assert(c.kc==coefficients(k));
 % All saved endpoints are accepted as depletion complete by the user.
 % Preserve the original solver stop reason separately from this classification.
 c.original_solver_status=c.status;c.status='complete';c.minimal_figure=true;
 b=c.budget;initial=b.melt_shell_m3(1);requested=zeros(1,10);
 fractions=[1 .985 .97 .9 .75 .5 .25 .1 .02];
 for j=2:9,idx=find(b.melt_shell_m3<=fractions(j)*initial,1);assert(~isempty(idx));requested(j)=b.time_years(idx);end
 requested(end)=b.time_years(end);c.requested=requested;c=H.select_states(c);
 file=['all_states_' c.label '.csv'];writetable(c.selected,fullfile(output_dir,file));
 selections{end+1}=struct('file',file,'label',c.label,'purpose','matched shell-melt stages');
 cases{k}=c;records{k}=struct('label',c.label,'directory',c.directory,'kc_m2',c.kc, ...
  'status',c.status,'original_solver_status',c.original_solver_status, ...
  'summary',c.summary,'cutoff_step',height(b)-1,'cutoff_years',b.time_years(end));
end
colors=[.28 .25 .60;.08 .60 .65;.16 .52 .24;.15 .15 .15;.85 .40 .08;.72 .13 .20];
styles={'-',':','-.','-','--','-'};
status=strings(n,1);for k=1:n,status(k)=string(cases{k}.status);end
assert(all(status=="complete"));
endpoint_table=table(coefficients(:),status(:),'VariableNames',{'kc_m2','status'});
columns={'steps','time_years','initial_shell_km3','delivered_net_km3','refrozen_net_shell_km3','remaining_shell_km3','remaining_fraction'};
for j=1:numel(columns),endpoint_table.(columns{j})=zeros(n,1);end
for k=1:n
 s=cases{k}.summary;
 endpoint_table.steps(k)=s.steps;endpoint_table.time_years(k)=s.time_years;
 endpoint_table.initial_shell_km3(k)=s.initial_shell_melt_km3;
 endpoint_table.delivered_net_km3(k)=s.delivered_net_km3;
 endpoint_table.refrozen_net_shell_km3(k)=s.refrozen_net_shell_km3;
 endpoint_table.remaining_shell_km3(k)=s.remaining_shell_melt_km3;
 endpoint_table.remaining_fraction(k)=s.remaining_fraction;
end
writetable(endpoint_table,fullfile(output_dir,'Europa_case_endpoints.csv'));

% Figure 4: observed endpoints and model permeability law.
f=H.new_figure(1120,480);ax=axes(f,'Position',[.085 .20 .37 .70]);hold(ax,'on');
p1=plot(ax,coefficients,endpoint_table.delivered_net_km3,'^','LineStyle','none', ...
 'MarkerSize',9,'Color',[.15 .15 .15],'MarkerFaceColor',[.15 .15 .15]);
set(ax,'XScale','log','XLim',[1e-16 3e-8],'YLim',[0 40],'XTick',10.^(-16:2:-8));H.style(ax);
xlabel(ax,'Permeability coefficient k_0 [m^2]');ylabel(ax,'Net melt delivered [km^3]');H.panel_letter(ax,'(a)');
ax=axes(f,'Position',[.575 .20 .35 .70]);hold(ax,'on');phi=logspace(-3,0,301);
% This band uses the manuscript's reported k0 fit, not a new empirical fit.
lo=10^(-7.71-2*.42)*phi.^3;hi=10^(-7.71+2*.42)*phi.^3;
fill(ax,[phi fliplr(phi)],[lo fliplr(hi)],[.89 .92 .95],'EdgeColor','none','HandleVisibility','off');
hh=gobjects(1,n);ll=cell(1,n);
for k=1:n,hh(k)=plot(ax,phi,coefficients(k)*phi.^3,'Color',colors(k,:),'LineStyle',styles{k},'LineWidth',1.2);ll{k}=H.kc_label(cases{k});end
set(ax,'XScale','log','YScale','log','XLim',[1e-3 1],'YLim',[1e-22 1e-7], ...
 'XTick',[.001 .01 .1 1],'YTick',10.^(-22:3:-7));H.style(ax);
xlabel(ax,'Melt fraction, \phi [-]');ylabel(ax,'Permeability k [m^2]');H.panel_letter(ax,'(b)');
legend(ax,hh,ll,'Location','southeast','Box','on','Color','w','EdgeColor','none','FontSize',8.5);
H.finish(f,'01_Figure4_Europa_delivery_and_permeability',output_dir,build_dir);

% Figure 5c,d: analytic Europa timescales, with no contour-edge overlays.
theory=struct('T_m_K',273,'eta0_Pa_s',1e14,'Ea_J_mol',50000,'R_J_mol_K',8.314, ...
 'rho_water_kg_m3',1000,'rho_ice_kg_m3',920,'mu_water_Pa_s',1e-3,'gravity_m_s2',1.315, ...
 'shell_thickness_m',10000,'seconds_per_year',3.154e7,'source_equations',[9 10 11]);
TC=linspace(-20,0,241);V=linspace(10,100,241);[TT,VV]=meshgrid(TC,V);
radius=(3*VV*1e9/(4*pi)).^(1/3);eta=theory.eta0_Pa_s*exp(theory.Ea_J_mol/theory.R_J_mol_K/theory.T_m_K*(theory.T_m_K./(theory.T_m_K+TT)-1));
speed=(2/9)*(theory.rho_water_kg_m3-theory.rho_ice_kg_m3)*theory.gravity_m_s2*radius.^2./eta;
foundering=theory.shell_thickness_m./speed/theory.seconds_per_year;
ph=linspace(.001,1,301);logkc=linspace(-16,log10(3e-8),241);[PH,KK]=meshgrid(ph,10.^logkc);
infiltration=theory.shell_thickness_m./(KK.*PH.^2*theory.rho_water_kg_m3*theory.gravity_m_s2/theory.mu_water_Pa_s)/theory.seconds_per_year;
f=H.new_figure(1120,480);ax=axes(f,'Position',[.085 .20 .31 .69]);imagesc(ax,TC,V,foundering);set(ax,'YDir','normal');
colormap(ax,parula(256));H.style(ax);xlabel(ax,'Ice temperature [^oC]');ylabel(ax,'Initial melt volume [km^3]');H.panel_letter(ax,'(c)');
cb=colorbar(ax);cb.Position=[.41 .20 .017 .69];cb.Label.String='Foundering time [years]';set(ax,'Position',[.085 .20 .31 .69]);
ax=axes(f,'Position',[.59 .20 .29 .69]);imagesc(ax,ph,logkc,log10(infiltration));set(ax,'YDir','normal','YTick',-16:2:-8, ...
 'YTickLabel',arrayfun(@(v)sprintf('10^{%d}',v),-16:2:-8,'UniformOutput',false));
colormap(ax,parula(256));H.style(ax);xlabel(ax,'Melt fraction, \phi [-]');ylabel(ax,'Permeability coefficient k_0 [m^2]');H.panel_letter(ax,'(d)');
cb=colorbar(ax);cb.Position=[.90 .20 .017 .69];cb.Ticks=-2:2:12;cb.TickLabels=arrayfun(@(v)sprintf('10^{%d}',v),cb.Ticks,'UniformOutput',false);
cb.Label.String='Infiltration time [years]';set(ax,'Position',[.59 .20 .29 .69]);
H.finish(f,'02_Figure5_Europa_theoretical_timescales',output_dir,build_dir);
save(fullfile(output_dir,'Europa_theory_grid.mat'),'TC','V','foundering','ph','logkc','infiltration','theory');
write_json(fullfile(output_dir,'Europa_theory_parameters.json'),theory);

% Main manuscript Figure 6/7/S4 grouping: e-16, e-10, e-8.
middle_index=find(strcmp(labels,'e10'));high_index=find(strcmp(labels,'e08'));focus_index=find(strcmp(labels,'e11'));
main={cases{1},cases{middle_index},cases{high_index}};
requests={ [0 100 300 500 650 1000 2000 5000 20000 cases{1}.budget.time_years(end)], ...
 [0 30 100 150 165 180 300 1000 10000 cases{middle_index}.budget.time_years(end)], ...
 [0 30 60 75 80 85 100 200 400 cases{high_index}.budget.time_years(end)]};
for k=1:3
 main{k}.requested=requests{k};main{k}=H.select_states(main{k});file=['main_states_' main{k}.label '.csv'];
 writetable(main{k}.selected,fullfile(output_dir,file));selections{end+1}=struct('file',file,'label',main{k}.label,'purpose','main manuscript grouping');
end
note='';
H.field_strip(main{1},main{3},'03_Figure6_Europa_evolution',output_dir,build_dir,note,main{2});
H.history_figure(main{1},main{3},false,'04_Figure7_Europa_volume_and_depth',output_dir,build_dir,main{2});
H.history_figure(main{1},main{3},true,'05_FigureS4_Europa_semilog',output_dir,build_dir,main{2});

% All cases, aligned by actual shell-melt milestones (not equal time).
all_field_strip(cases,H,'06_all_cases_evolution',output_dir,build_dir);
overview(cases,colors,styles,H,'07_all_case_histories',output_dir,build_dir);

% Exact inventories at the observed endpoints.
f=H.new_figure(1120,500);ax=axes(f,'Position',[.085 .24 .86 .66]);hold(ax,'on');
values=[endpoint_table.delivered_net_km3 endpoint_table.refrozen_net_shell_km3 endpoint_table.remaining_shell_km3];
bars=bar(ax,1:n,values,'stacked','BarWidth',.64);palette=[.18 .37 .69;.85 .38 .10;.50 .55 .59];
for j=1:3,bars(j).FaceColor=palette(j,:);bars(j).EdgeColor='none';end
exponents=round(log10(coefficients/1.85));
set(ax,'XLim',[.4 n+.6],'XTick',1:n,'XTickLabel',arrayfun(@(e)['1.85 \times 10^{' num2str(e) '}'],exponents,'UniformOutput',false),'YLim',[0 35]);
H.style(ax);xlabel(ax,'Permeability coefficient k_0 [m^2]');ylabel(ax,'Volume [km^3]');
legend(ax,bars,{'Net delivered','Net refrozen in shell','Remaining in shell'},'Location','northoutside','Orientation','horizontal','Box','off');
H.finish(f,'08_Europa_endpoint_volume_budgets',output_dir,build_dir);

% First actual timestep attaining diagnostic thresholds; no time interpolation.
milestones=table(coefficients(:),'VariableNames',{'kc_m2'});
fields={'delivery_25pct_years','delivery_50pct_years','delivery_75pct_years','remaining_10pct_years','remaining_1pct_years','remaining_0p5pct_years','front_9p95km_years'};
for j=1:numel(fields),milestones.(fields{j})=NaN(n,1);end
for k=1:n
 b=cases{k}.budget;initial=b.melt_shell_m3(1);
 masks={b.delivered_net_m3>=.25*initial,b.delivered_net_m3>=.50*initial,b.delivered_net_m3>=.75*initial, ...
  b.melt_shell_m3<=.10*initial,b.melt_shell_m3<=.01*initial,b.melt_shell_m3<=.005*initial,b.penetration_depth_km>=9.95-1e-9};
 for j=1:numel(fields),idx=find(masks{j},1);value=NaN;if ~isempty(idx),value=b.time_years(idx);end;milestones.(fields{j})(k)=value;end
end
milestones.depletion_complete_years=endpoint_table.time_years;
writetable(milestones,fullfile(output_dir,'Europa_first_sample_milestone_times.csv'));
f=H.new_figure(1120,500);markers={'o','s','^'};
for panel=1:2
 ax=axes(f,'Position',[.085+(panel-1)*.49 .23 .36 .67]);hold(ax,'on');hh=gobjects(1,3);
 for j=1:3
  field=fields{j+3*(panel-1)};if panel==2 && j==3,field='depletion_complete_years';end
  hh(j)=plot(ax,coefficients,milestones.(field),'LineStyle','none','Marker',markers{j}, ...
   'MarkerSize',7,'Color',palette(j,:),'MarkerFaceColor',palette(j,:));
 end
 set(ax,'XScale','log','YScale','log','XLim',[1e-16 3e-8],'XTick',10.^(-16:2:-8));H.style(ax);
 xlabel(ax,'Permeability coefficient k_0 [m^2]');ylabel(ax,'Time [years]');H.panel_letter(ax,sprintf('(%c)','a'+panel-1));
 if panel==1,ll={'25% delivered','50% delivered','75% delivered'};else,ll={'10% remaining','1% remaining','End time'};end
 if panel==1,ylim(ax,[50 2000]);else,ylim(ax,[50 1e5]);end
 legend(ax,hh,ll,'Location','northoutside','Orientation','horizontal','Box','off','FontSize',9);
end
H.finish(f,'09_Europa_delivery_and_depletion_times',output_dir,build_dir);

endpoint_fields(cases,H,'10_Europa_initial_and_endpoint_fields',output_dir,build_dir);

% Late residual melt and liquid stored in the model lower layer.
f=H.new_figure(1120,500);
for panel=1:2
 ax=axes(f,'Position',[.085+(panel-1)*.49 .23 .36 .66]);hold(ax,'on');hh=gobjects(1,n);
 for k=1:n
  b=cases{k}.budget;keep=b.time_years>0;
  if panel==1,y=b.melt_shell_m3/1e9;else,y=b.melt_ocean_region_m3/1e9;end
  hh(k)=plot(ax,b.time_years(keep),y(keep),'Color',colors(k,:),'LineStyle',styles{k},'LineWidth',1.4);
 end
 set(ax,'XScale','log','XLim',[.003 1e5]);H.style(ax);xlabel(ax,'Time [years]');
 if panel==1,set(ax,'YScale','log','YLim',[.1 35]);ylabel(ax,'Shell melt remaining [km^3]');
 else,ylabel(ax,'Liquid inventory below z=0 [km^3]');ylim(ax,[0 35]);end
 H.panel_letter(ax,sprintf('(%c)','a'+panel-1));
 if panel==1,legend(ax,hh,case_labels(cases,H),'Location','northwest','Box','on','Color','w','EdgeColor','none','FontSize',8.5);end
end
H.finish(f,'11_Europa_residual_melt_and_lower_inventory',output_dir,build_dir);

% Original manuscript requested timestamps, using only actual saved states.
paper=main;paper_requests={ [0 23 52 93 140 259 455 682 1465 7041], ...
 [0 .06 .16 .29 .42 .62 .93 1.24 1.84 12.73], [0 .003 .005 .008 .010 .013 .016 .110 .482 5.196]};
for k=1:3
 paper{k}.requested=paper_requests{k};paper{k}=H.select_states(paper{k});file=['paper_times_' paper{k}.label '.csv'];
 writetable(paper{k}.selected,fullfile(output_dir,file));selections{end+1}=struct('file',file,'label',paper{k}.label,'purpose','original manuscript requested times');
end
H.field_strip(paper{1},paper{3},'12_Europa_original_requested_times',output_dir,build_dir,'',paper{2});

% Additional manuscript-layout comparison for the newly accepted e-11 endpoint.
focus={main{1},cases{focus_index},main{3}};
H.field_strip(focus{1},focus{3},'13_Europa_kc11_temperature_and_melt',output_dir,build_dir,'',focus{2});
H.history_figure(focus{1},focus{3},false,'14_Europa_kc11_volume_and_depth',output_dir,build_dir,focus{2});
H.history_figure(focus{1},focus{3},true,'15_Europa_kc11_semilog',output_dir,build_dir,focus{2});

facts=struct('font','Times New Roman','figure_style','minimal manuscript style: axes, panel letters, parameter values and essential legends only', ...
 'figure_status_annotations',false,'figure_explanatory_footers',false, ...
 'cases',{records},'selection_sets',{selections}, ...
 'case_order','kc = 1.85e-16, 1.85e-14, 1.85e-12, 1.85e-11, 1.85e-10, 1.85e-8 m2', ...
 'reference_main_pdf',fullfile(repo,'docs','Impact_melt_foundering.pdf'), ...
 'reference_supplement_pdf',fullfile(repo,'docs','Impact_melt_foundering (1).pdf'), ...
 'data_interpolation',false,'temperature_band_outlines',false,'image_smoothing',false, ...
 'depth_phi_threshold',.001,'maximum_cell_centre_depth_km',9.95,'theory',theory, ...
 'empirical_band_source','Main manuscript Figure 4 caption; reported log10(k0) mean -7.71 and standard deviation 0.42; not refitted.', ...
 'missing_data',{{'Raw empirical permeability scatter and error bars','Corrected Titan simulations'}}, ...
 'milestones','First actual diagnostic row; unavailable thresholds remain NaN.', ...
 'completion_policy','All six recorded endpoints accepted as depletion complete by user instruction, 2026-10-28 and 2026-10-29; original solver stop reasons and residual melt are preserved.', ...
 'completion_time_definition','Recorded accepted endpoint, not a substituted 0.5-percent threshold-crossing time.', ...
 'solver_advanced_for_figures',false,'pressure_accuracy_certified',false);
write_json(fullfile(output_dir,'plot_provenance.json'),facts);
fid=fopen(fullfile(output_dir,'PLOTTING_COMPLETE.txt'),'w');fprintf(fid,'Fifteen Europa figures created from saved data only.\n');fclose(fid);
fprintf('ALL_EUROPA_FIGURES_COMPLETE %s\n',output_dir);
end

function all_field_strip(cases,H,stem,out,build)
n=numel(cases);f=H.new_figure(1500,210*n);cache=fullfile(out,'selected_fields');if ~isfolder(cache),mkdir(cache);end
rowy=linspace(.84,.15,n);width=.086;height=.60/n;left=.075;
annotation(f,'textbox',[.43 .965 .12 .025],'String','t [years]','EdgeColor','none','FontSize',16);
annotation(f,'arrow',[.55 .83],[.98 .98]);
for row=1:n
 c=cases{row};
 for col=1:10
  s=H.load_fields(c.selected(col,:));cache_state(s,c.label,cache);
  r=s.radius_km(:);z=s.elevation_km(:);P=reshape(s.phi,numel(z),numel(r));T=reshape(s.temperature_K,size(P));
  ix=r<10;iz=z>=0;P=P(iz,ix);T=T(iz,ix);
  ax=axes(f,'Position',[left+(col-1)*width rowy(row) width height]);
  rgb=field_rgb(T,P);imagesc(ax,r(ix),z(iz),rgb);set(ax,'YDir','normal','XLim',[0 10],'YLim',[0 10], ...
   'XTick',[],'YTick',[],'Box','on','LineWidth',.45,'FontName','Times New Roman','FontSize',10);
  if col==1,set(ax,'YTick',[0 5 10]);ylabel(ax,'z [km]');if row==n,set(ax,'XTick',[0 5 10]);xlabel(ax,'r [km]');end;end
  title(ax,time_text(s.time_years),'FontWeight','normal','FontSize',11);
 end
 caption=H.kc_label(c);
 annotation(f,'textbox',[left rowy(row)+height+.08/n .65 .11/n],'String',caption,'EdgeColor','none','Margin',0,'FontSize',9.5);
 annotation(f,'textbox',[.012 rowy(row)+height-.005 .05 .03],'String',sprintf('(%c)','a'+row-1),'EdgeColor','none','FontSize',18);
end
H.horizontal_scale(f,[.30 .11 .27 .012],[0 1],flipud(parula(256)),0:.2:1,'Melt fraction');
H.horizontal_scale(f,[.68 .11 .25 .012],[100 273],bone(256),[100 150 200 250],'Temperature [K]');
H.finish(f,stem,out,build);
end

function overview(cases,colors,styles,H,stem,out,build)
n=numel(cases);f=H.new_figure(1200,850);fields={'melt_shell_m3','penetration_depth_km','delivered_net_m3','refrozen_net_shell_m3'};
ylabs={'Shell melt [km^3]','Penetration depth [km]','Net delivered [km^3]','Net refrozen in shell [km^3]'};
for panel=1:4
 col=mod(panel-1,2);row=floor((panel-1)/2);ax=axes(f,'Position',[.085+col*.49 .57-row*.40 .36 .30]);hold(ax,'on');hh=gobjects(1,n);
 for k=1:n
  b=cases{k}.budget;keep=b.time_years>0;y=b.(fields{panel});if panel~=2,y=y/1e9;end
  hh(k)=plot(ax,b.time_years(keep),y(keep),'Color',colors(k,:),'LineStyle',styles{k},'LineWidth',1.4);
 end
 set(ax,'XScale','log','XLim',[.003 1e5],'XTick',10.^(-2:2:4));H.style(ax);xlabel(ax,'Time [years]');ylabel(ax,ylabs{panel});H.panel_letter(ax,sprintf('(%c)','a'+panel-1));
 if panel==2,set(ax,'YDir','reverse','YLim',[3 10]);elseif panel==4,ylim(ax,[0 6]);else,ylim(ax,[0 35]);end
 if panel==1,legend(ax,hh,case_labels(cases,H),'Location','southwest','Box','off','FontSize',8);end
end
H.finish(f,stem,out,build);
end

function endpoint_fields(cases,H,stem,out,build)
n=numel(cases);ncols=n+1;column_width=.90/ncols;
f=H.new_figure(300*ncols,750);cache=fullfile(out,'selected_fields');
initial=H.load_fields(cases{1}.index(1,:));states=cell(1,ncols);states{1}=initial;
for k=1:n,s=H.load_fields(cases{k}.index(end,:));assert(s.step==cases{k}.summary.steps);states{k+1}=s;cache_state(s,cases{k}.label,cache);end
for col=1:ncols
 s=states{col};r=s.radius_km(:);z=s.elevation_km(:);P=reshape(s.phi,numel(z),numel(r));T=reshape(s.temperature_K,size(P));
 for row=1:2
  row_y=[.65 .24];ax=axes(f,'Position',[.05+(col-1)*column_width row_y(row) .90*column_width .205]);
  if row==1,imagesc(ax,r,z,T);colormap(ax,bone(256));caxis(ax,[100 273]);else,imagesc(ax,r,z,P);colormap(ax,flipud(parula(256)));caxis(ax,[0 1]);end
  set(ax,'YDir','normal','XLim',[0 20],'YLim',[-2 10],'XTick',[0 10 20],'YTick',[-2 0 5 10],'FontSize',10,'Layer','top');
  yline(ax,0,'--','Color',[.45 .45 .45]);if col==1,ylabel(ax,'Elevation [km]');end;xlabel(ax,'Radius [km]');
  if row==1
   if col==1,caption={'Initial state','0 years'};else,caption={H.kc_label(cases{col-1}),sprintf('%.0f yr',s.time_years)};end
   title(ax,caption,'FontWeight','normal','FontSize',10);
  end
 end
end
H.horizontal_scale(f,[.30 .53 .36 .015],[100 273],bone(256),[100 150 200 250],'Temperature [K]');
H.horizontal_scale(f,[.30 .13 .36 .015],[0 1],flipud(parula(256)),0:.2:1,'Melt fraction');
H.finish(f,stem,out,build);
end

function rgb=field_rgb(T,P)
rgb=ind2rgb(1+floor(255*max(0,min(1,(T-100)/173))),bone(256));
wet=repmat(P>=.001,1,1,3);melt=ind2rgb(1+floor(255*max(0,min(1,P))),flipud(parula(256)));rgb(wet)=melt(wet);
end
function cache_state(s,label,folder)
if ~isfolder(folder),mkdir(folder);end;file=fullfile(folder,sprintf('%s_step_%08d.mat',label,s.step));if ~isfile(file),save(file,'s');end
end
function labels=case_labels(cases,H)
labels=cell(size(cases));for k=1:numel(cases),labels{k}=H.kc_label(cases{k});end
end
function write_json(path,data)
fid=fopen(path,'w');fprintf(fid,'%s',jsonencode(data));fclose(fid);
end
function label=time_text(t)
if t>=100,label=sprintf('%.0f',t);else,label=sprintf('%.3g',t);end
end
