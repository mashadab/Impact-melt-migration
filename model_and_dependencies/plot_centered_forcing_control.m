function plot_centered_forcing_control(output_dir)
% Plot completed frozen-flow controls only; no new solves.
if nargin<1
 root=fileparts(fileparts(mfilename('fullpath')));
 output_dir=strtrim(fileread(fullfile(root,'tmp','centered_continuation_output.txt')));
end
out=fullfile(output_dir,'analysis','forcing_control');
r=jsondecode(fileread(fullfile(out,'forcing_control.json')));
f=figure('Visible','off','Color','w','Position',[40 40 1550 650]);
t=tiledlayout(f,1,3,'Padding','compact','TileSpacing','compact');
ax=nexttile(t);values=[r.initial_legacy.max_abs_vs_m_per_year r.initial_S3_reference.max_abs_vs_m_per_year];
bar(ax,values,'FaceColor',[.23 .43 .65]);set(ax,'YScale','log','YLim',[10 3e6]);
set(ax,'XTick',1:2,'XTickLabel',{'Inherited','S3 reference'});
ylabel(ax,'Maximum solid-velocity variable [m/year]');title(ax,{'Initial state: pressure-reference effect','Logarithmic vertical scale'});
for j=1:2,text(ax,j,values(j)*1.3,sprintf('%.3g',values(j)),'HorizontalAlignment','center');end
ax=nexttile(t);values=[r.initial_legacy.sample_top_solid_down_m_per_year ...
 r.initial_S3_reference.sample_top_solid_down_m_per_year r.initial_zero_Darcy.sample_top_solid_down_m_per_year];
bar(ax,values,'FaceColor',[.23 .53 .43]);ylim(ax,[0 70]);
set(ax,'XTick',1:3,'XTickLabel',{'Inherited','S3 reference','Zero Darcy'});
ylabel(ax,'Downward matrix velocity [m/year]');title(ax,{'Initially dry cell below water','All four face Darcy fluxes are zero'});
for j=1:3,text(ax,j,values(j)+2,sprintf('%.2f',values(j)),'HorizontalAlignment','center');end
ax=nexttile(t);values=[r.step100_legacy.Q_Darcy_down_m3_per_year_per_m_depth ...
 r.step100_S3_reference.Q_Darcy_down_m3_per_year_per_m_depth];
bar(ax,values,'FaceColor',[.82 .43 .20]);ylim(ax,[0 260]);
set(ax,'XTick',1:2,'XTickLabel',{'Inherited','S3 reference'});
ylabel(ax,'Downward Darcy Q [m^3/year per m depth]');title(ax,{'Same frozen step-100 state','Relative flux across z = 4 km'});
for j=1:2,text(ax,j,values(j)+7,sprintf('%.2f',values(j)),'HorizontalAlignment','center');end
set(findall(f,'Type','axes'),'FontName','Arial','FontSize',12,'Box','off','YGrid','on');
title(t,'Bulk descent persists; the inherited pressure reference biases the flow', ...
 'FontName','Arial','FontSize',19,'FontWeight','normal');
xlabel(t,sprintf(['Frozen-flow controls: no thermal advance and no change to the ongoing baseline.\n' ...
 'Darcy transfer at step 100 differs by %.2f times; these are not converged trajectory comparisons.'], ...
 values(1)/values(2)),'FontName','Arial','FontSize',11);
set(f,'PaperPositionMode','auto');print(f,fullfile(out,'pressure_reference_control.png'),'-dpng','-r150');
print(f,fullfile(out,'pressure_reference_control.svg'),'-dsvg');close(f);
end
