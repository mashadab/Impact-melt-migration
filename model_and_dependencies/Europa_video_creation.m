%% Setup
set(groot,'defaulttextinterpreter','latex')
set(groot,'defaultAxesTickLabelInterpreter','latex')
set(groot,'defaultLegendInterpreter','latex')
set(groot,'defaultTextFontSize',20)
set(groot,'DefaultAxesFontSize',20);
addpath ../model_and_dependencies/
clear all; close all;

fs = 12;

%% Grid
Xmax = 20; Ymax = 10;
grRes = 100; grZ = 120;
d = 10;
Gridp.xmin = 0; Gridp.xmax = Xmax/d; Gridp.Nx = grRes;
Gridp.ymin = -3/5; Gridp.ymax = Ymax/d; Gridp.Ny = grZ;
Gridp.geom = 'cylindrical_rz';
Grid = build_stokes_grid_cyl(Gridp);
[X,Y] = meshgrid(Grid.p.xc,Grid.p.yc);

%% Time indices
kc_OM = 16;

if kc_OM == 10
inds_arr = 1:1:620;
end

if kc_OM == 8
inds_arr = [1,10:10:400,500:100:22200];
end

if kc_OM == 16
inds_arr = [1,100:100:20000];
end

%% Video setup
 v = VideoWriter(sprintf("../figures/Europa03321_eta0_14kc1.85e-%s_Ea_50_output_%dC.mp4",num2str(kc_OM)),'MPEG-4');
v.FrameRate = 20;
open(v);

figure('Units','centimeters','Position',[5 5 24 10]);

for k = 1:length(inds_arr)
    % --- Load file ---
    if kc_OM <10
    load(sprintf("../Output/Europa03321_eta0_14kc1.85e-0%s_Ea_50_output_%dC.mat",num2str(kc_OM),inds_arr(k)))
     else
    load(sprintf("../Output/Europa03321_eta0_14kc1.85e-%s_Ea_50_output_%dC.mat",num2str(kc_OM),inds_arr(k)))
    end
    % --- Reshape fields ---
    TPlot   = reshape(T,Grid.p.Ny,Grid.p.Nx)*173+100;
    phiPlot = reshape(phi,Grid.p.Ny,Grid.p.Nx);

    % Clip values
    %phiPlot(phiPlot < 1e-16) = nan;
    TPlot(TPlot>273) = 273;
    TPlot(TPlot<100) = 100;

    clf;

    % ---------- TEMPERATURE AXES (left half) ----------
    ax1 = axes;
    contourf(ax1, -X*d, Y*d, TPlot, 40, 'linestyle','none');
    colormap(ax1,'bone');
    caxis(ax1,[100 273]);
    axis(ax1,'equal','tight');
    xlim(ax1,[-10 10]); ylim(ax1,[0 10]);
    xlabel(ax1,'x [km]'); ylabel(ax1,'z [km]');
    hold(ax1,'on');

    % Add colorbar for temperature
    cb1 = colorbar(ax1,'westoutside');
    title(ax1,'Temperature [K]   \quad  \quad \quad  Melt Fraction','FontSize',20,'FontWeight','bold');

    % ---------- MELT AXES (right half) ----------
    ax2 = axes;
    contourf(ax2, X*d, Y*d, phiPlot, 40, 'linestyle','none');
    colormap(ax2,flipud(parula));
    caxis(ax2,[0 1]);
    axis(ax2,'equal','tight');
    xlim(ax2,[-10 10]); ylim(ax2,[0 10]);
    xlabel(ax2,'x [km]'); ylabel(ax2,'z [km]');
    %title(ax2,'Melt Fraction','FontSize',14,'FontWeight','bold');

    % Add colorbar for melt
    cb2 = colorbar(ax2,'eastoutside');
    %cb2.Label.String = '\phi';

    % Make ax2 transparent so ax1 shows through on left
    ax2.Color = 'none';
    ax2.XColor = 'k'; ax2.YColor = 'k';

    % Sync positions so they overlap perfectly
    ax2.Position = ax1.Position;
    xticks([-10,-5,0,5,10]);
    %ax1.Yticks.Label = [0,5,10];
    % Annotation
    text(ax2,9.8,9.5,[num2str(round(tVec(end),3)) ' yrs'], ...
        'HorizontalAlignment','right','VerticalAlignment','top', ...
        'Color','k','FontSize',20,'FontWeight','bold')

    % --- Save frame ---
    frame = getframe(gcf);
    writeVideo(v,frame);
end

close(v);
disp('Video saved as Europa_split_horizontal.mp4');
