clear all, close all, clc

vfx = csvread('vfx_5.csv'); vfy = csvread('vfy_5.csv');

phi = csvread('phi_5.csv');
phiodd = phi; phieven=phi;
phiodd(1:2:end-1) = [];
phieven(2:2:end)  = [];
A = [phiodd';
    phieven'];
phi = mean(A,1);
phic = 1e-3;

N = length(vfx);
Nc = length(vfx)-1;

phi    = reshape(phi,Nc,Nc);

Grid.xmin = 0; Grid.xmax = 32; Grid.Nx = length(vfx);
Grid.ymin = 0; Grid.ymax = 32; Grid.Ny = length(vfy);

Grid.x = linspace(Grid.xmin,Grid.xmax,Grid.Nx); dx= Grid.x(2)-Grid.x(1);
Grid.y = linspace(Grid.ymin,Grid.ymax,Grid.Ny); dy= Grid.y(2)-Grid.y(1);

Grid.xc = linspace(Grid.xmin+dx,Grid.xmax-dx,Grid.Nx-1);
Grid.yc = linspace(Grid.ymin+dy,Grid.ymax-dy,(Grid.Ny-1));

[X,Y] = meshgrid(Grid.x,Grid.y);
[Xc,Yc] = meshgrid(Grid.xc,Grid.yc);


%Plotting the porosity wave initialization
fs = 11;
lw = 2;
f = figure;
f.Units = 'centimeters';
f.Position = [1,1,9.5,11.5];
hold on;
set(gca,'FontSize',fs);
contourf(Xc,Yc,phi)
colorbar()
ax = f.CurrentAxes;
ax.Position(4) = ax.Position(3);
axis(ax,'equal')
max(phi,[],'all')