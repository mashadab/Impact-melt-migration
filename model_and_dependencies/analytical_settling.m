%Analytical 
set(groot,'defaultAxesFontName','Times')
set(groot,'defaultAxesFontSize',20)
set(groot,'defaulttextinterpreter','latex')
set(groot,'defaultAxesTickLabelInterpreter','latex')
set(groot,'defaultLegendInterpreter','latex')
set(groot, 'DefaultFigureVisible', 'on');
set(groot, 'DefaultLineLineWidth', 2);

clc; close all; clear all;

%%%% Adding the viscosity change due to temperature

R = 8.314; % universal gas constant, J K^-1 mol^-1
T_b = 273.16; % melting temperature, K
E_a = 50e3; % viscosity activation energy
Apar = E_a/R/T_b; % viscosity exponent
mu_b = 1e14; %basal dynamic viscosity [Pa.s]

%% Input variables
%Thermodynamics
Ti_C = -10;   %surrounding ice temperature [C]      

klist = [0.25, 0.5, 0.75, 1.0]; depth_var_array = []; timestamp_var_array=[];
Ti =  273.16 + Ti_C; 

for k1 = 1:length(klist)
mu = klist(k1) * mu_b*exp(Apar*(T_b/Ti-1));%Temperature corrected basal viscosity [Pa.s]

%Viscosity

%Settling
%{
%Titan
grav      = 1.352;%gravity: Europa =1.315, Titan = 1.352, [m/s^2]
V  = linspace(100,5000,1000); %volume of the melt [km^3] 
d_ice= [50, 80, 100, 150]' ;  %thickness of ice sheet [km]
%}

%Europa
grav= 1.315; %Titan = 1.352, [m/s^2]
%V  = 31%linspace(0.1,1000,1000); %volume of the melt [km^3] 
d_ice= [7.5]' ;  %thickness of ice sheet [km]
% Calculations 
%R    = (3.*V./(4.*pi)).^(1/3);  %calculate radius of the blob [km]
R = 1; %Radius [in km]
yr2s = 365.25*24*60*60; %year to second conversion [s/year]

%% Thermodynamic parameters
L    = 333.6e3;  %latent heat of fusion [J/kg]
cp_i = 2.1e3;    %Specific heat of ice [J/kg-K]
rho_i= 917;      %density of ice [kg/m^3]
Tm =  273.16;    %melting temperature; temperature of the drop [K]
k  =  2.22;       %thermal conductivity [W/m-K]
kappa = k / (rho_i * cp_i); %Thermal diffusivity [m^2/s]



%% Calculate solidification: Stefan problem
tau_max = @(beta)  1./6 + 1./(6.*beta) - 1./(3.*(2.*pi).^0.5.*beta.^(1.5));


figure();
beta_array = logspace(-1,3,1000);
loglog(beta_array,tau_max(beta_array))
xlabel 'Beta'
ylabel 'Dim-less time, Tau'


beta = L/(cp_i*(Tm - Ti)); %Stefan number

S = linspace(0,1-1e-10,10000); %S is the dimless location of the front w.r.t initial position
tau  =  (3.*S.^2 - 2.*S.^3)./6 + S.^2 ./ (6.*beta) - S.^2./(45.*beta.^2.*(1-S)); %dimless time

S(S> S(find(tau==max(tau)))) = nan;   %Near full melt limit
tau(S> S(find(tau==max(tau)))) = nan; %Near full melt limit

figure();
plot(tau,S);
xlim([0 0.3])
ylabel 'S'
xlabel 'Dimless time, tau'
t_solid = tau_max(beta) * beta * (R*1e3).^2 / (kappa * yr2s); %redimensionalizing time

%% Calculate Settling: Stokes settling
%Parameters
rho_melt  = 1000; %density of the melt (water) [kg/m^3]
rho_matrix= 917;  %density of the bath (ice) [kg/m^3] 
yr2s      = 365.25*24*60*60; %year to second conversion [s/year]

%Calculating the settling velocity

V_settling = (2/9)*(rho_melt - rho_matrix).*(R*1e3).^2.*grav./mu.*(yr2s/1e3); %[km/year]
t_settling_without_refreezing = d_ice./ V_settling %settling time [years]
blacks = linspace(0.9,0,length(d_ice));

labels=num2str(d_ice,'$$d_{ice}=$$%d km');


%Variable radius settling

Var_R = (1 - S).*R   %Transient radius of the drop
V_settling_var = (2/9)*(rho_melt - rho_matrix).*(Var_R*1e3).^2.*grav./mu.*(yr2s/1e3); %[km/year]
timestamp_var  = tau .* beta * (R*1e3).^2 ./ (kappa * yr2s) %redimensionalizing time array [years]
timestamp_var(timestamp_var<0)  = 0;
V_settling_var(V_settling_var<0)= 0;

figure();
loglog(timestamp_var,V_settling_var)
ylabel 'V [km/year]'
xlabel 'Time [year]'


i = 1;
z = zeros(1,9999);
depth_var(1) = 0
while true
    
    %depth_var(i+1) = V_settling_var(i).*(timestamp_var(i+1) - timestamp_var(i)); %instantaneous depth [km]
    depth_var(i+1) = depth_var(i)+V_settling_var(i).*(timestamp_var(i+1) - timestamp_var(i)); %instantaneous depth [km]
    
    i = i+1
    
    if i >= 10000, break ; end
    
end 

depth_var_array      = [depth_var_array; depth_var];
timestamp_var_array  = [timestamp_var_array; timestamp_var];
end 

blues = linspace(0.9,0,length(klist));

h = figure();
max_timestamp = max(timestamp_var);  %Finding the max time analytically
depth_var(depth_var<0) = nan; i = 1;
while true
    plot(timestamp_var_array(i,:),depth_var_array(i,:),'b-',color=[blues(i) blues(i) 1])
    hold on
    i = i+1;
    if i > length(klist), break ; end
end 


%Actual simulation result
filename  = sprintf('save_data%dC_R1km_.mat',Ti_C);
%load('save_data-10C.mat');
%load('save_data-20C_R1km_.mat');
load(filename);
plot(data(:,1), 10*(data(1,2) - data(:,2)), 'r-')
hold on


%xline(t_solid,'k--')
set(gca, 'YDir','reverse')
xlabel 't [years]'
ylabel 'Depth [km]'
ylim([0, 6])
xlim([0, 1.4*max(data(:,1))])

klist = klist';
labels=num2str(klist,'Theory, k=%.2f');
labels = [labels; 'Simulation    ']
legend(labels,'location','northeast')
saveas(h,sprintf('../figures/Comparison-bw-analy-theoretical%d.pdf',Ti))


function [x,y] = create_circle(radius,xlocation,ylocation)
        % Create a vectortheta.
        theta=linspace(0,2*pi,200);
        x    = xlocation + radius * cos(theta);
        y    = ylocation + radius * sin(theta);    
end 