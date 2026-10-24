%Darcy-Stokes at a steady state (h-form)
%Author: Mohammad Afzal Shadab
%Date: June 15, 2023
clc 
close all 
clear all
set(groot,'defaulttextinterpreter','latex')
set(groot,'defaultAxesTickLabelInterpreter','latex')
set(groot,'defaultLegendInterpreter','latex')
set(groot, 'DefaultFigureVisible', 'off');
warning off; % matrix is close to singular due to viscosity contrast

%Parameters
yr2s   = 365.25 * 24 * 60 * 60; %year to second conversion [s/year]
mu_max = 1e14; %Maximum solid viscosity [Pa.s]
phi_min= 0.2; phi_max= 0.7; %Minimum and Maximum solid porosities [-]
G      = 1.0; %Coefficient in the bulk viscosity formulation [-]
k0     = 5.6e-11; %Relative permeability [m^2] {Meyer and Hewitt, 2017}
mu_f   = 1e-3;%Viscosity of the fluid [Pa.s]
m      = 1;   %Power law coefficient in compaction viscosity = (G/phi^m * mu_s) [-]
n      = 2;   %Power law coefficient in porosity permeability relationship k = k0*phi^n [-]
rho_s  = 917; %Density of solid [kg/m^3]
rho_f  = 1e3; %Density of fluid [kg/m^3]
Gamma  = 0;   %Rate of melting [kg/m^3-s]
grav   = 9.81;   %Acceleration due to gravity []m/s^2]
Delta_rho = rho_f - rho_s; %Difference in density of the two phases [kg/m^3]
vt     = 1e-3;   %Tangential velocity [m/s]

%Transient
Nt     = 1000;  %Number of time steps
tf     = 200;%Final time [s]
dt     = tf/Nt; %Time step [s]

%% Build staggered grids
Gridp.xmin = 0; Gridp.xmax = 1; Gridp.Nx = 50;
Gridp.ymin = 0; Gridp.ymax = 1; Gridp.Ny = 50;
Grid = build_stokes_grid(Gridp);
[Xc,Yc] = meshgrid(Grid.p.xc,Grid.p.yc); %Cell centers
[Xp,Yp] = meshgrid(Grid.x.xc,Grid.y.yc); %Corner points

%mu = mu_max*(Yc(:)/Grid.p.ymax).^n;  %linearly decaying viscosity with depth

%Initial condition
mu = mu_max*ones(size(Yc(:)));  %This will be a function of temperature later but is constant right now
phi= phi_min * ones(Grid.p.N,1);%+ (phi_max - phi_min)*(Yc(:)/Grid.p.ymax);  %Decays with depth

%% Build Stokes operators
[D,Edot,Dp,Gp,Z,I,Ms,Mp] = build_stokes_ops_Darcy_Stokes(Grid);
%fs = spalloc(Grid.N,1,0);

%% Build operators for porosity evolution 
Ip     = speye(Grid.p.N); %Identity on pressure grid
IM_phi = Ip;              %Implicit operator
EX_phi = @(v,dt) Ip - dt * Dp * flux_upwind(v,Grid.p);       %Implicit operator
fs_phi = @(v) Gamma/rho_s*ones(Grid.p.N,1) + Dp * v; %Melting term RHS term and compaction term

%% Build BC's
%Flow equation: Darcy-Stokes
BC.dof_dir = [Grid.dof_ymax_vt(2:end-1);...  % tangential velocity on the top
              Grid.dof_pene;...     % no penetration on all bnd's
              Grid.dof_ymin_vt(2:end-1);...  
              Grid.dof_xmin_vt(2:end-1);...  
              Grid.dof_xmax_vt(2:end-1);...  
              Grid.dof_pc];         % pressure constraint
BC.dof_f_dir = [];         
BC.g       = [vt*ones(length(Grid.dof_ymax_vt(2:end-1)),1);...       % tangential velocity on the top
              zeros(Grid.N_pene,1);...      % no penetration on all bnd's
              zeros(length(Grid.dof_ymin_vt(2:end-1)),1);...  
              zeros(length(Grid.dof_xmin_vt(2:end-1)),1);...  
              zeros(length(Grid.dof_xmax_vt(2:end-1)),1);...  
              0];                           % pressure constraint
[B,N,fn] = build_bnd(BC,Grid,I);

%Transport equation: Porosity
BC.phi.dof_dir   = [];
BC.phi.dof_f_dir = [];         
BC.phi.g         = [];                      % pressure constraint
[B_phi,N_phi,fn_phi] = build_bnd(BC.phi,Grid.p,Ip);

tTot = 0;    %total time initialization [s]
frameno = 0; %Initializing frame number for plotting
for i = 1:Nt
    %% Build Stokes operator
    %Evaluating different means
    %Mud = comp_mean(mu,Ms,-1,Grid.p,1); %Average viscosity
    Mud =  spdiags(Ms * (mu .* (1-phi)), 0, length(Edot),length(Edot));
    Zd  = build_Zd(G,phi,m,mu,Grid.p);
    Kd  = build_Kd(k0,n,phi,mu_f,Grid.p,Mp); 
    
    %Evaluating operators
    A = D*2*Mud*Edot;
    L = [A + Gp*Zd*Dp,  -Delta_rho*grav*Gp;...
         Dp          ,  -Delta_rho*grav*Dp*Kd*Gp ];
    fs = build_RHS(phi,Kd,Grid.p,Mp,Dp,rho_f,rho_s,Gamma,grav);
    %Solving for solid velocity and over pressure head
    u = solve_lbvp(L,fs+fn,B,BC.g,N);
    v = u(1:Grid.p.Nf); h = u(Grid.p.Nf+1:end); %Solid velocity and overpressure head
    PSI = comp_streamfun(v,Grid.p);             %Solid velocity stream function
    
    %Solving for ice-mass balance / porosity evolution    
    phi = solve_lbvp(IM_phi,EX_phi(v,dt)*phi + dt*(fs_phi(v)+fn_phi),B_phi,BC.phi.g,N_phi);
    
    tTot = tTot + dt;  
    %Plotting
    if mod(i,20)==0
        i
        p  = (Delta_rho * grav) * (h - Yc(:));    %Overpressure [Pa]
        pf =  p - rho_s * grav * Yc(:);           %Fluid pressure [Pa]
        ps =  pf- G * mu./ phi.^m .* (Dp * v);      %Solid pressure
        %Fluid velocity
        vf = v - spdiags(1./(Mp * phi),0,Grid.p.Nf,Grid.p.Nf) * Kd * (Gp * p + rho_f * grav * [zeros(Grid.p.Nfx,1);ones(Grid.p.Nfy,1)]);
        PSIf = comp_streamfun(vf,Grid.p);            %Fluid velocity stream function

        %% Plot solution
        psi_max = max(PSI(:));
      
        h=figure(4);
        set(gcf,'units','points','position',[0,0,3125,1250])
        set(gcf, 'Position', [50 50 1500 600])
        %set(gcf, 'Position', [50 50 1500 600])
        sgtitle(sprintf('time=%.3f seconds',tTot));
        subplot 141
        cla;
        contourf(Xc,Yc,reshape(phi,Grid.p.Ny,Grid.p.Nx),100);
        c1 = colorbar;
        xlabel('x','fontsize',14)
        ylabel('z','fontsize',14)
        title 'Porosity';
        axis square

        subplot 142
        cla;
        contourf(Xc,Yc,reshape(pf,Grid.p.Ny,Grid.p.Nx),100);
        c2 = colorbar;
        xlabel('x','fontsize',14)
        ylabel('z','fontsize',14)
        title 'Fluid pressure [Pa]';
        axis square

        subplot 143
        cla;
        contourf(Xc,Yc,reshape(p,Grid.p.Ny,Grid.p.Nx),100);
        c2 = colorbar;
        xlabel('x','fontsize',14)
        ylabel('z','fontsize',14)
        title 'Overpressure [Pa]';
        axis square

        subplot 144
        cla;
        contour(Xp,Yp,PSI,50,'k'), hold on
        contour(Xp,Yp,PSIf,50,'b--')
        legend('solid','fluid','location','southoutside')
        axis square
        xlabel('x','fontsize',14)
        ylabel('z','fontsize',14)
        xlim([0 1]), ylim([0 1])
        ta = annotation('textarrow');
        s = ta.FontSize;
        ta.FontSize = 12;
        ta.Position = [0.4000 .9500 0.2000 0.0000];
        ta.VerticalAlignment = 'bot';
        ta.HorizontalAlignment = 'right';
        str = strcat('v_{lid}=',num2str(vt),'m/s');
        text(.45,1.06,str,'fontsize',12)
        % convert the image to a frame
        frameno = frameno + 1;
        FF(frameno) = getframe(gcf) ;
        
    end
end

%%%%
%% Making a video out of frames
 % create the video writer with fps of the original video
 Data_result= sprintf('case_t%syrs.avi',num2str(tTot));
 writerObj = VideoWriter(Data_result);
 writerObj.FrameRate = 20; % set the images per second
 open(writerObj); % open the video writer
% write the frames to the video
for i=1:frameno
    %'Frame number'; i
    % convert the image to a frame
    frameimg = FF(i) ;
    writeVideo(writerObj, frameimg);
end
% close the writer object
close(writerObj);    
    %%%%

h=figure(5);
set(gcf,'units','points','position',[0,0,3125,1250])
contour(Xp,Yp,PSI,100,'k'), hold on
contour(Xp,Yp,PSI,psi_max*[.2:.2:1],'r-')
legend('main circulation','corner eddies','location','south')
axis square
xlabel('x','fontsize',14)
ylabel('z','fontsize',14)
set(gca,'xtick',[0:.2:1],'ytick',[0:.2:1])
xlim([0 1]), ylim([0 1])
ta = annotation('textarrow');
s = ta.FontSize;
ta.FontSize = 12;
ta.Position = [0.4000 .9500 0.2000 0.0000];
ta.VerticalAlignment = 'bot';
ta.HorizontalAlignment = 'right';
text(.45,1.06,'v_{lid}','fontsize',12)


function Zd = build_Zd(G,phi,m,mu,Grid) %building zeta^*_phi at cell centers
    Zd = (G ./ (phi.^m) - 2/3) .* mu .* (1-phi);
    Zd = spdiags(Zd,0,Grid.N,Grid.N);
end

function Kd = build_Kd(k0,n,phi,mu_f,Grid,Mp) %building Kd at cell faces
    Kd = Mp * ( k0 .* phi.^n ./ mu_f);
    Kd = spdiags(Kd,0,Grid.Nf,Grid.Nf);
end

function F = build_RHS(phi,Kd,Grid,Mp,Dp,rho_f,rho_s,Gamma,grav)
    Delta_rho = rho_f - rho_s;
    %fv at cell faces
    fv = Delta_rho*grav*(Mp*(1-phi)).* [zeros(Grid.Nfx,1); ones(Grid.Nfy,1)] ;
    
    %fp at cell centers
    fp =-(rho_f - rho_s)/(rho_f * rho_s) * Gamma * ones(Grid.N,1);
    
    F = [fv;fp];
end