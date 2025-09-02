%% Titan Time-Evolution Video (Temperature + Melt Fraction)
%% set up plot commands
set(groot,'defaulttextinterpreter','latex')
set(groot,'defaultAxesTickLabelInterpreter','latex')
set(groot,'defaultLegendInterpreter','latex')
set(groot,'defaultTextFontSize',20)
set(groot, 'DefaultAxesFontSize', 20);
addpath ../model_and_dependencies/
clear all; close all;
fs = 18;
fs_small = 12;
%% set up grid
Xmax = 20; %maximum 
Ymax = 60; %maximum  
grRes = 50; % grid resolution in radial direction
grZ = 180; % grid resolution in radial direction
d = 20;
Gridp.xmin = 0; Gridp.xmax = Xmax/d; Gridp.Nx = grRes; %radial direction
Gridp.ymin = -3/5; Gridp.ymax = Ymax/d;  Gridp.Ny = grZ; %vertical direction
Gridp.geom = 'cylindrical_rz';
Grid = build_stokes_grid_cyl(Gridp);
[X,Y] = meshgrid(Grid.p.xc,Grid.p.yc);
angle = 0;

%% make plot dimensions
fp = '../Output/';



%% Time indices
kc_OM =16;   %set the order of magnitude of the permeability 

inds_arr = [1,100:100:1000];

%% Video setup
 v = VideoWriter(sprintf("../figures/Titan_14kc1.85e-%s_Ea_50_output_%dC.mp4",num2str(kc_OM)),'MPEG-4');
v.FrameRate = 2;
open(v);

figure('Units','centimeters','Position',[1,1,22,9.5*2+0.5]);

for k = 1:length(inds_arr)
    % --- Load file ---
    if kc_OM <10
    load(sprintf("../Output/Simple-test_eta0_14kc1.85e-0%s_Ea_50_output_%dC.mat",num2str(kc_OM),inds_arr(k)))
     else
    load(sprintf("../Output/Simple-test_eta0_14kc1.85e-%s_Ea_50_output_%dC.mat",num2str(kc_OM),inds_arr(k)))
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
    xlim(ax1,[-20 20]); ylim(ax1,[0 60]);
    xlabel(ax1,'x [km]'); ylabel(ax1,'z [km]');
    hold(ax1,'on');

    % Add colorbar for temperature
    cb1 = colorbar(ax1,'westoutside');
    title(ax1,'Temperature [K] \quad  Melt Fraction','FontSize',20,'FontWeight','bold');

    % ---------- MELT AXES (right half) ----------
    ax2 = axes;
    contourf(ax2, X*d, Y*d, phiPlot, 40, 'linestyle','none');
    colormap(ax2,flipud(parula));
    caxis(ax2,[0 1]);
    axis(ax2,'equal','tight');
    xlim(ax2,[-20 20]); ylim(ax2,[0 60]);
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
    xticks([-20,-10,0,10,20]);
    %ax1.Yticks.Label = [0,5,10];
    % Annotation
    text(ax2,18,57.5,[num2str(round(tVec(end),2)) ' yrs'], ...
        'HorizontalAlignment','right','VerticalAlignment','top', ...
        'Color','k','FontSize',20,'FontWeight','bold')

    % --- Save frame ---
    frame = getframe(gcf);
    writeVideo(v,frame);
end

close(v);
disp('Video saved as Titan_split_horizontal.mp4');
