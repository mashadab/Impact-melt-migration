%Run darcy_stokes_transient_porosity_wave.m first
%Load the output_2D_porosity_wave.mat array next

%[phi_array,phic,tTot_array] = load("output_2D_porosity_wave.mat", "phi_array","tTot_array");

% Colors Marc likes - or at least used to like
col.red    = [190  30  45]/255; 
col.blue   = [ 39 170 225]/255; 
col.green  = [  0 166  81]/255;
col.orange = [247 148  30]/255;
col.purple = [102  45 145]/255;
col.brown  = [117  76  36]/255;
col.tan    = [199 178 153]/255;

yr2s   = 365.25 * 24 * 60 * 60; %year to second conversion [s/year]

set(groot,'defaultAxesFontName','Times')
set(groot,'defaultAxesFontSize',20)
set(groot,'defaulttextinterpreter','latex')
set(groot,'defaultAxesTickLabelInterpreter','latex')
set(groot,'defaultLegendInterpreter','latex')
set(groot, 'DefaultFigureVisible', 'on');


h=figure(4);
set(gcf,'units','points','position',[0,0,700,400])
set(gcf, 'Position', [50 50 700 400])
subplot 131
phi_iter = phi_array(1,:);
phi_iter = reshape(phi_iter,Grid.p.Ny,Grid.p.Nx);
phi_iter(Yc<1000) = 0; %zeroing out the basal increase in porosity ie below 1km

contourf(Xc,Yc,reshape(phi_iter,Grid.p.Ny,Grid.p.Nx),100, 'LineStyle','none');
colormap("turbo")
% hold on
% Yc_max = Yc(find(phi_iter==max(phi_iter)));
% Yc_max = max(Yc_max);
% Xc_max = Xc(Yc==Yc_max);
% plot(Yc_max,Xc_max)

xlabel('x-dir [km]','fontsize',14)
ylabel('z-dir [km]','fontsize',14)
axis equal

subplot 133
phi_iter = phi_array(1400,:);
phi_iter = reshape(phi_iter,Grid.p.Ny,Grid.p.Nx);
phi_iter(Yc<1000) = 0; %zeroing out the basal increase in porosity ie below 1km

contourf(Xc/1e3,Yc/1e3,reshape(phi_iter,Grid.p.Ny,Grid.p.Nx),100, 'LineStyle','none');
% hold on
% Yc_max = Yc(find(phi_iter==max(phi_iter)));
% Yc_max = max(Yc_max);
% Xc_max = Xc(Yc==Yc_max);
% plot(Xc_max/1e3,Yc_max/1e3,'ro')

c1 = colorbar;
xlabel('x-dir [km]','fontsize',20)
ylabel('z-dir [km]','fontsize',20)
axis equal


subplot 131
phi_iter = phi_array(1,:);
phi_iter = reshape(phi_iter,Grid.p.Ny,Grid.p.Nx);
phi_iter(Yc<1000) = 0; %zeroing out the basal increase in porosity ie below 1km

contourf(Xc/1e3,Yc/1e3,reshape(phi_iter,Grid.p.Ny,Grid.p.Nx),100, 'LineStyle','none');
% hold on
% Yc_max = Yc(find(phi_iter==max(phi_iter)));
% Yc_max = max(Yc_max);
% Xc_max = Xc(Yc==Yc_max);
% plot(Xc_max/1e3,Yc_max/1e3,'ro')

xlabel('x-dir [km]','fontsize',20)
ylabel('z-dir [km]','fontsize',20)
axis equal



subplot 132
phi_iter = phi_array(700,:);
phi_iter = reshape(phi_iter,Grid.p.Ny,Grid.p.Nx);
phi_iter(Yc<1000) = 0; %zeroing out the basal increase in porosity ie below 1km

contourf(Xc/1e3,Yc/1e3,reshape(phi_iter,Grid.p.Ny,Grid.p.Nx),100, 'LineStyle','none');
% hold on
% Yc_max = Yc(find(phi_iter==max(phi_iter)));
% Yc_max = max(Yc_max);
% Xc_max = Xc(Yc==Yc_max);
% plot(Xc_max/1e3,Yc_max/1e3,'ro')
xlabel('x-dir [km]','fontsize',20)
ylabel('z-dir [km]','fontsize',20)
axis equal

saveas(h,sprintf('2D_porosity_wave1e-3.pdf'));


Yc_max_arr = [];

for i = 1:size(phi_array,1)
    phi_iter = phi_array(i,:);
    phi_iter = reshape(phi_iter,Grid.p.Ny,Grid.p.Nx);
    phi_iter(Yc<1000) = 0; %zeroing out the basal increase in porosity ie below 1km
    Yc_max = Yc(find(phi_iter==max(phi_iter)));
    Yc_max = max(Yc_max)
    Yc_max_arr = [Yc_max_arr;Yc_max];
end

figure()
plot(tTot_array/yr2s,Yc_max_arr/1e3,'r-',color=col.red,linewidth=3);
hold on
phi_iter = phi_array(1,:)
phi_iter = reshape(phi_iter,Grid.p.Ny,Grid.p.Nx);
plot(tTot_array/yr2s,(Yc(find(phi_iter==max(phi_array(1,:))))-tTot_array*5*w0)/1e3,color=col.blue,linewidth=3)
legend('Simulated', 'Theoretical',location='best')
ylabel('Elevation [km]')
xlabel('Time [yrs]')
saveas(gcf,'2Dporosity-wave_1e-3_plot.pdf')

