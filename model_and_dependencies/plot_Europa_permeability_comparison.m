function plot_Europa_permeability_comparison
% Actual diagnostic time steps and measured saved-state flow statistics.
root=fileparts(mfilename('fullpath'));
out=fullfile(root,'..','Output','Europa_permeability_comparison_20261024');
r=jsondecode(fileread(fullfile(out,'comparison.json')));
H=readtable(fullfile(r.runs.high.directory,'melt_budget.csv'));
L=readtable(fullfile(r.runs.low.directory,'melt_budget.csv'));
f=figure('Visible','off','Color','w','Position',[30 30 1560 1110]);
clean=onCleanup(@() close(f)); %#ok<NASGU>
tl=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
col=[.02 .47 .53;.85 .38 .12];tables={H,L};keys={'high','low'};
names={'kc = 1.85e-8 m^2','kc = 1.85e-16 m^2'};
for panel=1:3
 ax=nexttile(tl);hold(ax,'on');
 curves=gobjects(2,1);
 for k=1:2
  b=tables{k};keep=b.time_years>0;
  if panel==1,y=100*b.delivered_net_m3/b.melt_shell_m3(1);
  elseif panel==2,y=100*b.melt_shell_m3/b.melt_shell_m3(1);
  else,y=100*b.refrozen_net_shell_m3/b.melt_shell_m3(1);end
  curves(k)=plot(ax,b.time_years(keep),y(keep),'Color',col(k,:),'LineWidth',2.4);
  if panel==1
   q=r.runs.(keys{k}).milestones.delivery_50pct_of_initial;
   plot(ax,q.time_years,y(q.step+1),'o','Color',col(k,:), ...
    'MarkerFaceColor',col(k,:),'MarkerSize',6);
   text(ax,q.time_years*1.25,47,sprintf('%.1f yr',q.time_years),'Color',col(k,:), ...
    'FontSize',11,'Rotation',0,'VerticalAlignment','top');
  end
 end
 set(ax,'XScale','log','FontName','Arial','FontSize',11,'Box','off', ...
  'XLim',[.003 60000],'XTick',[.01 .1 1 10 100 1000 10000]);
 grid(ax,'on');xlabel(ax,'Simulated time [years; logarithmic scale]');
 if panel==1
  title(ax,'Net melt delivery across z = 0');ylabel(ax,'Transfer / initial shell melt [%]');ylim(ax,[0 102]);
  yline(ax,50,':','50% initial volume','Color',[.5 .5 .5],'LabelHorizontalAlignment','left');
  legend(ax,curves,names,'Location','northwest','Box','off');
 elseif panel==2
  set(ax,'YScale','log');ylim(ax,[.4 110]);yticks(ax,[.5 1 10 100]);
  title(ax,'Melt remaining in the shell');ylabel(ax,'Shell melt / initial volume [%]');
  yline(ax,.5,'--','Stopping threshold','Color',[.5 .5 .5],'LabelHorizontalAlignment','left');
 else
  title(ax,'Recorded net refreezing in the shell');ylabel(ax,'Net refreezing / initial volume [%]');ylim(ax,[0 20]);
 end
end
ax=nexttile(tl);
h=r.runs.high.half_delivery_saved_flow;l=r.runs.low.half_delivery_saved_flow;
speeds=abs([h.mushy_melt_weighted_relative_vertical_m_per_year h.mushy_melt_weighted_solid_vertical_m_per_year; ...
 l.mushy_melt_weighted_relative_vertical_m_per_year l.mushy_melt_weighted_solid_vertical_m_per_year]);
bars=bar(ax,speeds,'grouped');bars(1).FaceColor=[.21 .42 .73];bars(2).FaceColor=[.48 .56 .60];
set(ax,'YScale','log','YLim',[1e-6 1e3],'XTick',1:2,'FontName','Arial','FontSize',11,'Box','off');
xticklabels(ax,{sprintf('1.85e-8; %.1f yr',h.time_years),sprintf('1.85e-16; %.1f yr',l.time_years)});
xlabel(ax,'kc [m^2]; actual saved time');
ylabel(ax,'Downward speed [m/year; logarithmic scale]');
title(ax,'Different mechanisms during main transfer');grid(ax,'on');
legend(ax,{'Melt relative to ice','Ice motion'},'Location','northwest','Box','off');
title(tl,'Europa: permeability changes the transport mechanism','FontName','Arial','FontSize',20);
xlabel(tl,{'Curves use actual diagnostic time steps; bars use two labelled saved states and melt-weighted speeds in shell cells with 0.01 <= phi <= 0.5.', ...
 'No temporal interpolation. Net refreezing includes the same 0.36729 km^3 initialization adjustment in both runs.'},'FontSize',10);
file=fullfile(out,'Europa_permeability_mechanism_comparison.png');
exportgraphics(f,file,'Resolution',160);
fprintf('PERMEABILITY_COMPARISON_FIGURE %s\n',file);
end
