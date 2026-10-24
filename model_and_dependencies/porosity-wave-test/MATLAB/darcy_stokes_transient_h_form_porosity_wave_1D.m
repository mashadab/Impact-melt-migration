%Darcy-Stokes at a steady state (h-form)
%Author: Mohammad Afzal Shadab
%Date: April 29, 2024
clc 
close all 
clear all

set(groot,'defaultAxesFontName','Times')
set(groot,'defaultAxesFontSize',20)
set(groot,'defaulttextinterpreter','latex')
set(groot,'defaultAxesTickLabelInterpreter','latex')
set(groot,'defaultLegendInterpreter','latex')
set(groot, 'DefaultFigureVisible', 'off');

%Parameters
yr2s   = 365.25 * 24 * 60 * 60; %year to second conversion [s/year]
mu_max = 1e14; %Maximum solid viscosity [Pa.s]
phi_min= 1e-3; phi_max= 0.7; %Minimum and Maximum solid porosities [-]
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
vt     = 0;   %Tangential velocity [m/s]

%Transient
Nt     = 1600;  %Number of time steps
tf     = 800*yr2s;%Final time [s]
dt     = tf/Nt; %Time step [s]

%Characteristic scales
phic = phi_min
delta0 = sqrt(k0*phic^n*mu_max/(phic^m*mu_f)) %Compaction length
Kc = k0*Delta_rho*grav*phic^n/mu_f %Compaction hydraulic conductivity

%% Build staggered grids
Gridp.xmin = 0*delta0; Gridp.xmax = 10*delta0; Gridp.Nx = 5;
Gridp.ymin = 0*delta0; Gridp.ymax = 128*delta0; Gridp.Ny = 1024;
Grid = build_stokes_grid(Gridp);
[Xc,Yc] = meshgrid(Grid.p.xc,Grid.p.yc); %Cell centers
[Xp,Yp] = meshgrid(Grid.x.xc,Grid.y.yc); %Corner points


%mu = mu_max*(Yc(:)/Grid.p.ymax).^n;  %linearly decaying viscosity with depth


%Analytic solution
HD = Grid.p.ymax/delta0;
zDa = linspace(0,HD,1e3);
% coefficients
c1 = @(H) (exp(-H)-1)./(exp(H)-exp(-H));
c2 = @(H) (exp(H)-1)./(exp(H)-exp(-H));
% potentials
hDa = @(z,H) z + c1(H).*exp(z) + c2(H).*exp(-z);
uDa = @(z,H) -z - c1(H).*exp(z) - c2(H).*exp(-z);
% overpressure
pDa = @(z,H) c1(H).*exp(z) + c2(H).*exp(-z);
% flux & velocity
qDa = @(z,H) -1 - c1(H).*exp(z) + c2(H).*exp(-z);
vDa = @(z,H) 1 + c1(H).*exp(z) - c2(H).*exp(-z);


%Initial condition
mu = mu_max*ones(size(Yc(:)));  %This will be a function of temperature later but is constant right now
phi= phi_min * ones(Grid.p.N,1);%+ (phi_max - phi_min)*(Yc(:)/Grid.p.ymax);  %Decays with depth

%Adding a porosity wave
Amp = 22.63; %amplitude for lambda=5, wave speed
cX = 0*delta0; cY = Gridp.ymax-40*delta0; r = 10*delta0 %Center X,Y coordinates
%phi(sqrt((Yc-cY).^2) <r) = Amp*phi_min* exp((-5*(Yc((sqrt((Yc-cY).^2) <r))-cY).^2)/(r).^2); %1D porosity wave
%phi(sqrt(Xc.^2 + Yc.^2) <0.2*delta0) = A*phi_min* exp(-(Xc((sqrt(Xc.^2 + Yc.^2) <0.2*delta0)).^2 + Yc((sqrt(Xc.^2 + Yc.^2) <0.2*delta0)).^2)/(0.2*delta0).^2);

%%%%%%%%%%%%%%%%%%
%Importing porosity wave initialization
phi_init = csvread('./porosity-wave-init/phi_5.csv'); 
vfx_init = csvread('./porosity-wave-init/vfx_5.csv'); 
vfy_init = csvread('./porosity-wave-init/vfy_5.csv');
phiodd = phi_init; phieven=phi_init;
phiodd(1:2:end-1) = [];
phieven(2:2:end)  = [];
A_init = [phiodd';
    phieven'];
phi_init = mean(A_init,1);
phic = 1e-3;

N_init = length(vfx_init);
Nc_init = length(vfx_init)-1;

phi_init    = reshape(phi_init,Nc_init,Nc_init);
%%%%%%%%%%%%%%%%%%
phi = reshape(phi,Grid.p.Ny,Grid.p.Nx);
begin_y_por_wave = Gridp.ymax-40*delta0;
ind = find(Grid.p.yc>begin_y_por_wave);
phi(ind(1):ind(1)+256-1,:) = kron(ones(1,Grid.p.Nx),phi_min*phi_init(1:256,128));
phi = phi(:);


%% Build Stokes operators
[D,Edot,Dp,Gp,Z,I,Ms,Mp] = build_stokes_ops_Darcy_Stokes(Grid);

%% Build operators for porosity evolution 
Ip     = speye(Grid.p.N); %Identity on pressure grid
IM_phi = Ip;              %Implicit operator
EX_phi = @(v,dt) Ip - dt * Dp * flux_upwind(v,Grid.p);       %Implicit operator
fs_phi = @(v) Gamma/rho_s*ones(Grid.p.N,1) + Dp * v; %Melting term RHS term and compaction term


%% Build BC's
BC.dof_dir = [Grid.dof_ymax_vt(2:end-1);...  % tangential velocity on the top
              Grid.dof_pene;...     % no penetration on all bnd's
              Grid.dof_ymin_vt(2:end-1);...   
              Grid.dof_pc_comp_col];         % pressure constraint
BC.dof_f_dir = [];         
BC.g       = [zeros(length(Grid.dof_ymax_vt(2:end-1)),1);...       % tangential velocity on the top
              zeros(Grid.N_pene,1);...      % no penetration on all bnd's
              zeros(length(Grid.dof_ymin_vt(2:end-1)),1);...  
              hDa(Grid.p.dy/(2*delta0),HD)*delta0];                           % pressure constraint
[B,N,fn] = build_bnd(BC,Grid,I);

%Transport equation: Porosity
BC.phi.dof_dir   = [];
BC.phi.dof_f_dir = [];         
BC.phi.g         = [];                      % pressure constraint
[B_phi,N_phi,fn_phi] = build_bnd(BC.phi,Grid.p,Ip);

tTot = 0;    %total time initialization [s]
frameno = 0; %Initializing frame number for plotting

tTot_array  = [];        %Time array [s]
phi_array   = [];        %porosity array [-]
vf_array = [];           %Fluid velocity [m/s]
v_array  = [];           %Solid velocity [m/s]
max_phi_loc_array = [];  %Location of maximum porosity/ center of porosity wave [m]

for i = 1:Nt
    %Evaluating different means
    %Mud = comp_mean(mu,Ms,-1,Grid.p,1); %Average viscosity
    Mud =  spdiags(Ms * (mu .* (1-phi)), 0, length(Edot),length(Edot));
    Zd  = build_Zd(G,phi,m,mu,Grid.p);
    Kd  = build_Kd(k0,n,phi,mu_f,Grid.p,Mp); 
    
    A = D*2*Mud*Edot;
    L = [A + Gp*Zd*Dp,  -Delta_rho*grav*Gp;...
         Dp          ,  -Delta_rho*grav*Dp*Kd*Gp ];
    %fs = spalloc(Grid.N,1,0);
    fs = build_RHS(phi,Kd,Grid.p,Mp,Dp,rho_f,rho_s,Gamma,grav);
    
    
    %% Solve for Stokes flow
    u = solve_lbvp(L,fs+fn,B,BC.g,N);
    v = u(1:Grid.p.Nf); h = u(Grid.p.Nf+1:end); %Solid velocity and overpressure head
    PSI = comp_streamfun(v,Grid.p);             %Solid velocity stream function
    
    p  = (Delta_rho * grav) * (h - Yc(:));    %Overpressure [Pa]
    pf =  p - rho_s * grav * Yc(:);           %Fluid pressure [Pa]
    ps =  pf- G * mu./ phi.^m .* (Dp * v);      %Solid pressure
    %Fluid velocity
    vf = v - spdiags(1./(Mp * phi),0,Grid.p.Nf,Grid.p.Nf) * Kd * (Gp * p + rho_f * grav * [zeros(Grid.p.Nfx,1);ones(Grid.p.Nfy,1)]);
    PSIf = comp_streamfun(vf,Grid.p);            %Fluid velocity stream function

    %Solving for ice-mass balance / porosity evolution    
    phi = solve_lbvp(IM_phi,EX_phi(v,dt)*phi + dt*(fs_phi(v)+fn_phi),B_phi,BC.phi.g,N_phi);
    
    tTot = tTot + dt;  
    tTot_array  = [tTot_array;tTot];    %Time array [s]
    phi_array = [phi_array;phi'];       %porosity
    vf_array = [vf_array;vf'];           %Fluid velocity [m/s]
    v_array  = [v_array;v'];            %Solid velocity [m/s]
    max_phi_loc_array =  [max_phi_loc_array;Yc(find(phi==max(phi)))]; %Location of maximum porosity/ center of porosity wave [m]

     %Plotting
    if mod(i,20)==0 || i==1
        i
%         p  = (Delta_rho * grav) * (h - Yc(:));    %Overpressure [Pa]
%         pf =  p - rho_s * grav * Yc(:);           %Fluid pressure [Pa]
%         ps =  pf- G * mu./ phi.^m .* (Dp * v);      %Solid pressure
%         %Fluid velocity
%         vf = v - spdiags(1./(Mp * phi),0,Grid.p.Nf,Grid.p.Nf) * Kd * (Gp * p + rho_f * grav * [zeros(Grid.p.Nfx,1);ones(Grid.p.Nfy,1)]);
%         PSIf = comp_streamfun(vf,Grid.p);            %Fluid velocity stream function
%         
        %% Plot solution


%         psi_max = max(PSI(:));
%       
%         h=figure(4);
%         set(gcf,'units','points','position',[0,0,3125,1250])
%         set(gcf, 'Position', [50 50 1500 600])
%         %set(gcf, 'Position', [50 50 1500 600])
%         sgtitle(sprintf('time=%.3f seconds',tTot));
%         subplot 141
%         cla;
%         contourf(Xc,Yc,reshape(phi,Grid.p.Ny,Grid.p.Nx),100);
%         c1 = colorbar;
%         xlabel('x','fontsize',14)
%         ylabel('z','fontsize',14)
%         title 'Porosity';
%         axis square
% 
%         subplot 142
%         cla;
%         contourf(Xc,Yc,reshape(pf,Grid.p.Ny,Grid.p.Nx),100);
%         c2 = colorbar;
%         xlabel('x','fontsize',14)
%         ylabel('z','fontsize',14)
%         title 'Fluid pressure [Pa]';
%         axis square
% 
%         subplot 143
%         cla;
%         contourf(Xc,Yc,reshape(p,Grid.p.Ny,Grid.p.Nx),100);
%         c2 = colorbar;
%         xlabel('x','fontsize',14)
%         ylabel('z','fontsize',14)
%         title 'Overpressure [Pa]';
%         axis square
% 
%         subplot 144
%         cla;
%         contour(Xp,Yp,PSI,50,'k'), hold on
%         contour(Xp,Yp,PSIf,50,'b--')
%         legend('solid','fluid','location','southoutside')
%         axis square
%         xlabel('x','fontsize',14)
%         ylabel('z','fontsize',14)
%         xlim([0 1]), ylim([0 1])
%         ta = annotation('textarrow');
%         s = ta.FontSize;
%         ta.FontSize = 12;
%         ta.Position = [0.4000 .9500 0.2000 0.0000];
%         ta.VerticalAlignment = 'bot';
%         ta.HorizontalAlignment = 'right';
%         str = strcat('v_{lid}=',num2str(vt),'m/s');
%         text(.45,1.06,str,'fontsize',12)
%         % convert the image to a frame
%         frameno = frameno + 1;
%         FF(frameno) = getframe(gcf) ;
        
    
    hhh=figure()
    set(gcf,'units','points','position',[0,0,3125,1250])
    % Enlarge figure to full screen.
    set(gcf, 'Position', [50 50 1500 600])
    t=sgtitle(sprintf('Dim-less depth = %.1f, Porosity = %0.3f, time = %0.1f yr',HD, phic,tTot/yr2s)); t.FontSize = 20;
    %% Plotting and post-processing
    subplot 151
    plot(hDa(zDa,HD)*delta0,zDa*delta0,'linewidth',2), hold on
    plot(h(1:Grid.p.Ny),Grid.p.yc,'--','linewidth',2)
    xlabel('h [m]','fontsize',22)
    ylabel('z [m]','fontsize',22)
    legend('analytic','numerical','location','northwest')
    set(gca,'fontsize',18)
    
    subplot 152
    plot(pDa(zDa,HD)*Delta_rho*grav*delta0,zDa*delta0,'linewidth',2), hold on
    plot(p(1:Grid.p.Ny),Grid.p.yc,'--','linewidth',2)
    xlabel('Overpressure [Pa]','fontsize',22)
    ylabel('z [m]','fontsize',22)
    legend('analytic','numerical','location','northeast')
    set(gca,'fontsize',18)
    
    subplot 153
    plot(vDa(zDa,HD)*Kc,zDa*delta0,'linewidth',2), hold on
    plot(v(Grid.p.Nfx+1:Grid.p.Nfx+1+Grid.p.Ny),Grid.p.yf,'--','linewidth',2)
    xlabel('Solid velocity [m/s]','fontsize',22)
    ylabel('z[m]','fontsize',22)
    legend('analytic','numerical','location','northeast')
    set(gca,'fontsize',18)

    subplot 154
    plot(qDa(zDa,HD)*Kc/phi_min,zDa*delta0,'linewidth',2), hold on
    plot(vf(Grid.p.Nfx+1:Grid.p.Nfx+1+Grid.p.Ny),Grid.p.yf,'--','linewidth',2)
    xlabel('Melt velocity [m/s]','fontsize',22)
    ylabel('z[m]','fontsize',22)
    legend('analytic','numerical','location','northeast')
    set(gca,'fontsize',18)

    subplot 155
    plot(phi_min*ones(Grid.p.Ny,1),Grid.p.yc,'linewidth',2), hold on
    plot(phi(1:Grid.p.Ny),Grid.p.yc,'--','linewidth',2)
    xlabel('Porosity [-]','fontsize',22)
    ylabel('z[m]','fontsize',22)
    legend('analytic','numerical','location','northeast')
    set(gca,'fontsize',18)
    %saveas(hhh,sprintf('transient_comp_column_phic%d_HD%d_t%d.png',phic,HD,tTot));
            % convert the image to a frame
    frameno = frameno + 1;
    FF(frameno) = getframe(gcf) ;
    end
end

%%%%
%% Making a video out of frames
 % create the video writer with fps of the original video
 Data_result= sprintf('case_t%syrs.avi',num2str(tTot/yr2s));
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


    %Analyzing porosity wave
    set(groot, 'DefaultFigureVisible', 'on');
    %     set(groot, 'DefaultFigureVisible', 'on');
    figure()
    plot(tTot_array(1:end)/yr2s,max_phi_loc_array)
    figure()
    plot(phi_array(1,1:Grid.p.Ny),Grid.p.yc); hold on;
    plot(phi_array(1500,1:Grid.p.Ny),Grid.p.yc);


    figure()
    plot(tTot_array(1:end-1)/yr2s,(max_phi_loc_array(2:end)-max_phi_loc_array(1:end-1))/dt)
    figure()
    semilogx(vf_array(1,Grid.p.Nfx+1:Grid.p.Nfx+1+Grid.p.Ny),Grid.p.yf)
    figure()
    hist(v(1,Grid.p.Nfx+1:Grid.p.Nfx+1+Grid.p.Ny),100)



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
    fv = -Delta_rho*grav*(Mp*(1-phi)).* [zeros(Grid.Nfx,1); ones(Grid.Nfy,1)] ;
    
    %fp at cell centers
    fp =-(rho_f - rho_s)/(rho_f * rho_s) * Gamma * ones(Grid.N,1);
    
    F = [fv;fp];
end