function results = plot_simple_noflow_results(output_dir,previous_dir)
% Plot closed-domain cases; optionally compare earlier fixed-enthalpy results.
% NEW FILE NF-PLOTTER: all code in this plotter was added for this test.
if nargin<1
    output_dir=fullfile(fileparts(mfilename('fullpath')),'..','Output','closed_lid_1000_steps');
end
if nargin<2, previous_dir=''; end
% NEW SECTION NF-PLOTTER: load completed case files.
kc_values=[0 1.85e-12 1.85e-8]; results=cell(size(kc_values));
for n=1:numel(kc_values)
    data=load(fullfile(output_dir,sprintf('noflow_kc_%0.3e.mat',kc_values(n))),'result');
    results{n}=data.result;
    assert(strcmp(results{n}.status,'completed'),'A case did not complete. Inspect its saved status.');
end
set(groot,'defaulttextinterpreter','none','defaultAxesTickLabelInterpreter','none', ...
    'defaultLegendInterpreter','none','defaultAxesFontName','Arial');
colors=[.52 .55 .59; .16 .48 .65; .30 .63 .45; .86 .40 .18; .63 .16 .32];
case_colors=[.20 .45 .65; .25 .60 .40; .75 .25 .20];
limits=[273 273];
for n=1:numel(results)
    p=results{n}; limits=[min(limits(1),min(p.history(:,2))),max(limits(2),max(p.history(:,3)))];
end
if diff(limits)<.01, limits=[272.8 273.2]; else, limits=limits+[-1 1]*max(.01,.05*diff(limits)); end
% NEW SECTION NF-PLOTTER: middle-domain temperature and melt-fraction snapshots.
fig=figure('Visible','off','Color','w','Position',[20 20 1950 990]);
tl=tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');
rows=table(); summary=table();
for n=1:numel(results)
    p=results{n};
    for panel=1:2
        ax=nexttile(tl,n+(panel-1)*3); hold(ax,'on');
        for j=1:numel(p.steps)
            if panel==1, value=p.T_K(:,j); else, value=p.phi(:,j); end
            style='-'; if j==1, style='--'; end
            c=colors(min(j,size(colors,1)),:);
            plot(ax,value,p.z_km,style,'Color',c,'LineWidth',1.6, ...
                'DisplayName',sprintf('step %d | %.3g yr',p.steps(j),p.time_years(j)));
        end
        grid(ax,'on'); ax.GridAlpha=.12; ax.FontSize=11; ax.Box='off';
        ylim(ax,[-2 10]); ylabel(ax,'z (km above ice-shell base)');
        yline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off');
        if panel==1
            xlim(ax,limits); xlabel(ax,'Temperature (K)');
            title(ax,sprintf('kc = %.3g m^2: temperature',p.kc));
        else
            xlim(ax,[0 1.02]); xlabel(ax,'Melt fraction');
            title(ax,sprintf('kc = %.3g m^2: melt fraction',p.kc));
            legend(ax,'Location','best','Box','off','FontSize',9);
        end
    end
    for j=1:numel(p.steps)
        count=numel(p.z_km);
        rows=[rows;table(repmat(p.kc,count,1),repmat(p.steps(j),count,1), ...
            repmat(p.time_years(j),count,1),repmat(p.x_km,count,1),p.z_km,p.T_K(:,j),p.phi(:,j),p.H(:,j), ...
            'VariableNames',{'kc_m2','step','time_years','x_km','z_km','temperature_K','melt_fraction','enthalpy_dimensionless'})]; %#ok<AGROW>
    end
    summary=[summary;table(p.kc,p.completed_steps,p.time_years(end), ...
        min(p.history(:,2)),max(p.history(:,3)),p.history(end,12),p.history(end,13), ...
        p.max_base_solid_flux,p.max_base_darcy_flux,p.max_base_advective_heat_flux, ...
        p.max_base_conductive_heat_flux,p.max_enthalpy_balance_error, ...
        p.history(end,18),p.history(end,19),p.max_boundary_solid_flux, ...
        p.max_boundary_darcy_flux,p.max_boundary_advective_heat_flux,p.max_boundary_conductive_heat_flux, ...
        'VariableNames',{'kc_m2','completed_steps','time_years','T_min_K','T_max_K', ...
        'basal_phi_min','basal_phi_max','max_base_solid_flux','max_base_darcy_flux', ...
        'max_base_advective_heat_flux','max_base_conductive_heat_flux','max_enthalpy_balance_error', ...
        'top_phi_min','top_phi_max','max_boundary_solid_flux','max_boundary_darcy_flux', ...
        'max_boundary_advective_heat_flux','max_boundary_conductive_heat_flux'})]; %#ok<AGROW>
    fprintf('SUMMARY kc=%g steps=%d years=%.9g T=[%.9g %.9g] basal_phi=[%.9g %.9g] basal_fluxes=[%.3g %.3g %.3g %.3g] E_error=%.3g\n', ...
        p.kc,p.completed_steps,p.time_years(end),min(p.history(:,2)),max(p.history(:,3)), ...
        p.history(end,12),p.history(end,13),p.max_base_solid_flux,p.max_base_darcy_flux, ...
        p.max_base_advective_heat_flux,p.max_base_conductive_heat_flux,p.max_enthalpy_balance_error);
end
title(tl,{'Closed lid and base: sealed and insulated', ...
    sprintf('x = 10 km | full 100 x 120 grid | %d steps per case',results{1}.completed_steps)},'FontSize',18,'FontWeight','bold');
subtitle(tl,'Enthalpy and melt fraction evolve freely in ALL cells. No imposed top or bottom values.','FontSize',11);
exportgraphics(fig,fullfile(output_dir,'closed_lid_profiles.png'),'Resolution',180);
print(fig,fullfile(output_dir,'closed_lid_profiles.svg'),'-dsvg'); close(fig);
writetable(rows,fullfile(output_dir,'closed_lid_profiles.csv'));
writetable(summary,fullfile(output_dir,'closed_lid_summary.csv'));

% NEW SECTION NF-PLOTTER: top/base melt fraction, all-boundary fluxes, energy balance.
fig=figure('Visible','off','Color','w','Position',[20 20 1850 650]);
tl=tiledlayout(fig,1,4,'TileSpacing','compact','Padding','compact');
for n=1:numel(results)
    p=results{n}; steps=(1:size(p.history,1))'; label=sprintf('kc = %.3g',p.kc);
    ax=nexttile(tl,1); hold(ax,'on');
    plot(ax,steps,p.history(:,12),'Color',case_colors(n,:),'LineWidth',1.5,'DisplayName',label);
    ax=nexttile(tl,2); hold(ax,'on');
    plot(ax,steps,p.history(:,18),'Color',case_colors(n,:),'LineWidth',1.5,'DisplayName',label);
    ax=nexttile(tl,3); hold(ax,'on');
    plot(ax,steps,max(p.history(:,20:23),[],2),'Color',case_colors(n,:),'LineWidth',1.5,'DisplayName',label);
    ax=nexttile(tl,4); hold(ax,'on');
    semilogy(ax,steps,max(abs(p.history(:,11))/abs(p.initial_enthalpy_total),eps), ...
        'Color',case_colors(n,:),'LineWidth',1.5,'DisplayName',label);
end
for j=1:4
    ax=nexttile(tl,j); grid(ax,'on'); ax.GridAlpha=.12; ax.FontSize=11; ax.Box='off';
    xlabel(ax,'Step'); legend(ax,'Location','best','Box','off');
    if j==1, title(ax,'Basal melt fraction (minimum)'); ylabel(ax,'Melt fraction'); ylim(ax,[0 1.02]); end
    if j==2, title(ax,'Lid melt fraction (minimum)'); ylabel(ax,'Melt fraction'); ylim(ax,[0 1.02]); end
    if j==3, title(ax,'Maximum flux on ANY boundary'); ylabel(ax,'Dimensionless flux'); end
    if j==4, ax.YScale='log'; title(ax,'Global enthalpy balance'); ylabel(ax,'Relative residual'); end
end
title(tl,'Checks for the closed, insulated domain','FontSize',18,'FontWeight','bold');
subtitle(tl,'No imposed enthalpy in any cell. The energy residual is the change in total domain enthalpy.','FontSize',11);
exportgraphics(fig,fullfile(output_dir,'closed_lid_checks.png'),'Resolution',180); close(fig);

% NEW SECTION NF-PLOTTER: optional comparison against the earlier boundary conditions.
if ~isempty(previous_dir)
    previous=readtable(fullfile(previous_dir,'simple_test_kc_sweep_3_cases.csv'));
    fig=figure('Visible','off','Color','w','Position',[20 20 1650 790]);
    tl=tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
    for n=1:numel(results)
        p=results{n}; old=previous(previous.kc_m2==p.kc & previous.step==p.completed_steps,:);
        assert(~isempty(old),'Previous case is missing.');
        old=sortrows(old,'z_km'); ax=nexttile(tl,n); hold(ax,'on');
        plot(ax,old.melt_fraction,old.z_km,'--','Color',[.18 .45 .65],'LineWidth',1.8, ...
            'DisplayName',sprintf('Fixed top/base H | %.3g yr',old.time_years(1)));
        plot(ax,p.phi(:,end),p.z_km,'Color',[.8 .3 .18],'LineWidth',1.8, ...
            'DisplayName',sprintf('Closed, free H | %.3g yr',p.time_years(end)));
        title(ax,sprintf('kc = %.3g m^2',p.kc));
        xlabel(ax,'Melt fraction'); ylabel(ax,'z (km above ice-shell base)');
        xlim(ax,[0 1.02]); ylim(ax,[-2 10]); grid(ax,'on'); ax.GridAlpha=.12; ax.FontSize=11; ax.Box='off';
        legend(ax,'Location','best','Box','off');
    end
    title(tl,sprintf('Effect of freeing top and basal enthalpy: step %d',results{1}.completed_steps),'FontSize',18,'FontWeight','bold');
    subtitle(tl,'Closed top/base cells evolve conservatively. Cases use different adaptive timesteps; compare the elapsed times in the legends.','FontSize',11);
    exportgraphics(fig,fullfile(output_dir,'basal_boundary_comparison.png'),'Resolution',180);
    print(fig,fullfile(output_dir,'basal_boundary_comparison.svg'),'-dsvg'); close(fig);
end
end
