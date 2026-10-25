function path=plot_centered_water_S3(output_dir)
% Plot actual saved initial/final fields; no interpolation of simulation data.
files=dir(fullfile(output_dir,'noflow_kc_*.mat'));assert(numel(files)==1);
loaded=load(fullfile(files.folder,files.name),'result');r=loaded.result;
assert(strcmp(r.case_key,'centered_water') && r.correct_head_reference);
G=r.Grid.p;d=r.length_scale_m;x=G.xc*d/1000;z=G.yc*d/1000;
fields={reshape(r.full_phi(:,1),G.Ny,G.Nx),reshape(r.final_state.phi,G.Ny,G.Nx)};
f=figure('Visible','off','Color','w','Units','inches','Position',[.5 .5 12.8 6.8], ...
 'PaperUnits','inches','PaperPosition',[0 0 12.8 6.8],'PaperSize',[12.8 6.8]);
height=.36*12.8*.6/6.8;positions={[.065 .27 .36 height],[.565 .27 .36 height]};
for k=1:2
 ax=axes('Parent',f,'Position',positions{k});imagesc(ax,x,z,fields{k});
 set(ax,'YDir','normal','FontName','Arial','FontSize',12,'TickLabelInterpreter','none');
 axis(ax,'image');clim(ax,[0 1]);colormap(ax,parula);
 if k==2,cb=colorbar(ax);cb.Position=[.94 .27 .012 height];cb.Ticks=[0 .5 1];end
 ax.Position=positions{k};xlabel(ax,'x [km]','Interpreter','none');ylabel(ax,'z [km]','Interpreter','none');
 if k==1,label='Initial liquid fraction';
 else,label=sprintf('%.6g years | step %d',r.time_years(end),r.completed_steps);end
 annotation(f,'textbox',[positions{k}(1) .735 .37 .05],'String',label, ...
  'LineStyle','none','FontName','Arial','FontSize',14,'Interpreter','none');
end
annotation(f,'textbox',[.065 .87 .90 .065],'String','Centered water test | corrected shared S3 solver', ...
 'LineStyle','none','FontName','Arial','FontSize',19,'Interpreter','none');
annotation(f,'textbox',[.065 .085 .90 .08], ...
 'String',sprintf(['Cartesian 100 x 120 grid | 273 K initially | closed and insulated | kc = 1.85e-8 m^2 | k = kc phi^3\n' ...
 'Actual saved fields, without interpolation | relative enthalpy error: %.3g'], ...
 r.max_enthalpy_balance_error/abs(r.initial_enthalpy_total)), ...
 'LineStyle','none','FontName','Arial','FontSize',10.5,'Interpreter','none');
drawnow;path=fullfile(output_dir,'centered_water_S3_initial_final.png');
print(f,path,'-dpng','-r160');print(f,fullfile(output_dir,'centered_water_S3_initial_final.svg'),'-dsvg');close(f);
fprintf('CORRECTED_CENTERED_FIGURE %s\n',path);
end
