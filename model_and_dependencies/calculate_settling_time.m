%% set demo defaults
clc; close all; clear all;

set(groot,'defaultAxesFontName','Times')
set(groot,'defaultAxesFontSize',20)
set(groot,'defaulttextinterpreter','latex')
set(groot,'defaultAxesTickLabelInterpreter','latex')
set(groot,'defaultLegendInterpreter','latex')
set(groot, 'DefaultFigureVisible', 'on');
set(groot, 'DefaultLineLineWidth', 2);

%% Calculate the settling time

%Titan
grav      = 1.352;%gravity: Europa =1.315, Titan = 1.352, [m/s^2]
V  = linspace(100,5000,1000); %volume of the melt [km^3] 
d_ice= [50, 60, 75, 150]' ;  %thickness of ice sheet [km]

%{
%Europa
grav      = 1.315; %Titan = 1.352, [m/s^2]
V  = linspace(0.1,1000,1000); %volume of the melt [km^3] 
d_ice= [5, 10, 15, 20]' ;  %thickness of ice sheet [km]
%}

%Parameters
rho_melt  = 1000; %density of the melt (water) [kg/m^3]
rho_matrix= 917;  %density of the bath (ice) [kg/m^3] 
mu        = 1e14; %dynamic viscosity [Pa.s]
yr2s      = 365.25*24*60*60; %year to second conversion [s/year]

%% Calculations 

R    = (3.*V./(4.*pi)).^(1/3);  %calculate radius of the blob [km]

%Calculating the settling velocity

V_settling = (2/9)*(rho_melt - rho_matrix).*(R*1e3).^2.*grav./mu.*(yr2s/1e3); %[km/year]
t_settling = d_ice./ V_settling; %settling time [years]
blacks = linspace(0.9,0,length(d_ice));

labels=num2str(d_ice,'$$d_{ice}=$$%d km');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Simple Titan simulations
R_simple = 10*[0.05, 0.1, 0.2]; %Radius [in km];
Vol_simple = 4/3 .* pi .* R_simple.^3; %Volume [in km^3] 
V_simple_Europa_analy = (2/9)*(rho_melt - rho_matrix).*(R_simple*1e3).^2.*grav./mu.*(yr2s/1e3);
t_settling_simple_Europa_analy = (7.5-R_simple)./ V_simple_Europa_analy; %settling time [years]
t_settling_simple_Europa_sim = [3723, 469, 113] ; %time for actual results
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

i = 1;
h=figure()
%xlim([min(V) max(V)]);
ylabel('Settling time, years');
xlabel('Melt volume, km$$^3$$');
set(gca, 'YScale', 'log')
set(gca, 'XScale', 'log')
    hold on
    
while true
    loglog(V,t_settling(i,:),color=[blacks(i) blacks(i) blacks(i)]);
    
    i = i+1;
    if i > length(d_ice), break ; end
end 

%{
%Europa
plot(Vol_simple,t_settling_simple_Europa_analy,'rX', 'MarkerSize',14);
plot(Vol_simple,t_settling_simple_Europa_sim,'ro', 'MarkerSize',14);
plot(31, 270, 'ro', 'MarkerSize',14,color=[blacks(2) blacks(2) blacks(2)]);  %Theoretical Europa ice shell
plot(31, 350, 'kX', 'MarkerSize',14,color=[blacks(2) blacks(2) blacks(2)]);  %Actual sim Europa ice shell
%}

%Europa
plot(450, 338, 'rX', 'MarkerSize',14,color=[blacks(2) blacks(2) blacks(2)]);  %Theoretical Europa ice shell
plot(450, 1870, 'ko', 'MarkerSize',14,color=[blacks(2) blacks(2) blacks(2)]);  %Actual sim Europa ice shell
legend(labels,'location','best')
saveas(h,sprintf('../figures/Output.png'))