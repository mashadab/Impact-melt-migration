%% demo for manannan crater simulation in figure 3
clear all; close all;
%% model parameters
% manannan crater key from Cox and Bauer, 2018 simulations
cox_and_bauer_impact_key = '03321';
basal_viscosity = 1e14; % basal viscosity of ice
viscosity_activation_energy = 50e3; % viscosity activation energy

% Permeability coefficient k = kc * phi^3
kc = 0%1.85e-08 ; %Absolute permeability [in m^2] 

%% model run simulation
%impactorTempMeltFuncDarcyStokesModPresForm2Stokes_Europa(cox_and_bauer_impact_key,basal_viscosity, ...
%    viscosity_activation_energy,kc) %main driver routine
simple_test = 'temprate_homog_column'  %'temperate_blob_settle' or 'temprate_homog_column'

% Testing: 'harmperm': harmonic_permeability,'comb_vel':combined
% velocity, 'temprate': temperate ice sheet, 'original'
simple_test_1D(cox_and_bauer_impact_key,basal_viscosity, ...
    viscosity_activation_energy,kc, 'effe_vel',simple_test) %main driver routine


% test 'comb_vel', 'temprate', 'harmperm', 'original','effe_vel'