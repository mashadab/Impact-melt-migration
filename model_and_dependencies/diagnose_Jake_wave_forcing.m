% CHANGE NF-01 START: Separate callable solver, options argument and documented closed-domain behavior.
% CHANGE NF-01 SOURCE: original lines 1-1; see NOFLOW_BASE_CHANGES.diff.
function result = diagnose_Jake_wave_forcing(fn,eta_0,E_a,kc,test,simple_test,options)
% Separate variant of simple_test_1D: closed, insulated top, base and sides.
% Enthalpy and melt fraction evolve freely in EVERY cell, including the lid.
% Includes the permeability-matrix and pressure-head consistency fixes.
% Default runs omit passive tracers and legacy 2D graphics/video; neither
% feeds back into the flow/enthalpy solution. See Simple_test_noflow_wrapper.

% END CHANGE NF-01
    %{
    Function to evolve impact melt chambers on Europa. Simulations end
    when there is a negligible amount of melt left from the impact. The
    ouputs are saved at the breakpoint in line 294. This model is meant for
    short term simulations, on the order of the sinking of impact melts.
    
    Variables:
        fn (string): is the directory to find the initial conditions (the
        outputs from the impact simulation)
        eta_0 (int): basal viscosity of ice in Pa s, 1e14 is a common value
        E_a (int): visocisty activation energy in Arrhenihus relationship
        given in J/mol, 50e3 is a common value
        no_of_tracers: Number of tracers = 0, 1, 2

        kc: is the permeability coefficient with units in m^2

    Author: Mohammad Afzal Shadab, mashadab@utexas.edu, June 6, 2023 (search %%%%); 
            Evan Carnahan, evan.carnahan@utexas.edu, 11/20/2022
    %}
% CHANGE NF-02 START: Read run options and restore the caller warning state on return.
% CHANGE NF-02 SOURCE: original lines 21-21; see NOFLOW_BASE_CHANGES.diff.

    if nargin < 7, options = struct(); end
    options = nf_options(options);
    previous_warnings = warning;
    warning_cleanup = onCleanup(@() warning(previous_warnings)); %#ok<NASGU>
% END CHANGE NF-02

    set(groot,'defaultAxesFontName','Times')
    set(groot,'defaultAxesFontSize',14)
    set(groot,'defaulttextinterpreter','latex')
    set(groot,'defaultAxesTickLabelInterpreter','latex')
    set(groot,'defaultLegendInterpreter','latex')
    set(groot, 'DefaultFigureVisible', 'off');
    warning off; % matrix is close to singular due to viscosity contrast
    %% Load initial condition to be evolved
    % make ice shell thickness based on impact code passed from iSALE
    if any([all(fn == '03321') all(fn == '03800') all(fn == '04304')])
        d = 10*1e3; % ice shell thickness, m  
    elseif any([all(fn == '03314') all(fn == '03402') all(fn == '03400')])
        d = 20*1e3; % ice shell thickness, m
    elseif any([all(fn == '03313') all(fn == '03701')])
        d = 30*1e3; % ice shell thickness, m
    elseif all(fn == '03330')
        d = 40*1e3; % ice shell thickness, m
    end

    % threshold of intial fluid left in ice shell to stop simulation at
    termFrac = 0.005;
    
    % load simulations from initial conditions folder (Digitized output via
    % Python from iSALE simulations)
% CHANGE NF-03 START: Resolve initial-condition files relative to this solver.
% CHANGE NF-03 SOURCE: original lines 46-46; see NOFLOW_BASE_CHANGES.diff.
    % S3 CHANGE: wave CSV replaces impact initial condition; original scales retained.
    phi0=1e-3;
    delta0=sqrt(kc*phi0^2*eta_0/(phi0*1e-3));
    d=128*delta0;
% END CHANGE NF-03
    % S3 CHANGE: impact-file load removed; exact wave CSV is loaded below.

    %% Set physical parameters and make dimensionless scales
    % physical parameters for ice
    T_t = 100; % surface temperature, K
    a = 185; % ice specific heat parameter
    b = 7.037; % ice specific heat parameter
    T_b = 273; % melting temperature, K
    rho_i = 917; % S3 CHANGE: benchmark density
    % rho_i = 920; % ice density at melting temperature, kg/m^3
    grav = 9.81; % S3 CHANGE: benchmark gravity
    % grav = 1.315; % Europa gravity, m/s^2 
    DT = T_b - T_t; % difference in temperature
    alpha = 1.6e-4; % thermal expansion coefficient, 1/K
    R = 8.314; % universal gas constant, J K^-1 mol^-1
    Apar = E_a/R/T_b; % viscosity exponenet

    % physical properties of water
    latHeat = 334e3; % latent heat of fusion, J/kg
    rho_w = 1e3; % density of water, kg/m^3
    c_pw = 4.186e3; % specific ehat of water, J/kg
    kappa_w = 0.56; %thermal diffusivity of water, W/(m K)
    porViscPar = 45;%How much a certain amt of melt reduce viscosity of ice  %%%% effective solid visc
    
    % temperature and melt fraction dependent viscosity, Pa s
    %barrViscPhi = @(nonT,phi) max(exp(Apar*(T_b./(DT.*nonT+T_t)-1)).*exp(-porViscPar*phi),1e-2);
    %barrViscPhi = @(nonT,phi) max(exp(Apar*(T_b./(DT.*nonT+T_t)-1)).*exp(-porViscPar*phi).*(1-phi),1e-5); %%%%New viscosity of solid (1-phi)*mu_s
    %barrViscPhi = @(nonT,phi) max(exp(Apar*(T_b./(DT.*nonT+T_t)-1)).*exp(-porViscPar*phi),1e-2); %Old viscosity
    ViscTempPhi = @(nonT,phi) max(exp(Apar*(T_b./(DT.*nonT+T_t)-1)).*exp(-porViscPar*phi),1e-5); %viscosity with temperature variation with water softening
    barrViscPhi = @(nonT,phi) max(exp(Apar*(T_b./(DT.*nonT+T_t)-1).*(1-phi)).*exp(-porViscPar*phi),1e-5); %Old viscosity with water softening
    % S3 CHANGE: constant intrinsic viscosity for the benchmark.
    ViscTempPhi = @(nonT,phi) ones(size(nonT));
    barrViscPhi = @(nonT,phi) 1-phi; % effective shear viscosity
    % viscosity is max of Temp dependence on viscosity, melt dependence, threshold
    % threshold 1e-2 means two orders of magnitude reduction is essentially inviscid
    c_fun = @(nonT) a+b*(DT*nonT+T_t); %specific heat function, J/(kg K)
    kappa_b = 3.3; %thermal conductivity of ice, set to be consistent with Cox and Bauer, 2015
    D_T = kappa_b/(rho_i *c_fun(1)); % thermal diffusicvity of ice, m^2/s
    c_pi = c_fun(1); %constant specific heat, J/(kg K)
    
    % thershold for melting: dimensionless boundary between partial and
    % fully melted regions
    mixZone = (rho_w*latHeat)/(rho_i*c_pi*DT); %fully ice to fully water mix spectrum
                                               %similar to Stefan number = latent heat / sensible heat
    
    phi_fun = @(nonH) nonH * (rho_i*c_pi*DT)/(rho_w*latHeat); %porosity: fully ice = 0 to fully water = 1
    TWater_fun = @(nonH) nonH * (rho_i*c_pi)/(rho_w*c_pw) - latHeat/(DT*c_pw) + 1; %Dim Temperature, K
    compBouy_fun = @(phi)  phi*rho_i*(rho_w/rho_i-1)*(grav*d^3/(eta_0*D_T)); %Dimless RHS of mom balance
                                                                             %Ice is lighter than water
    
    % conversion in dimensionless units with constant specific heat
    nonH_fun = @(nonT) nonT - 1; 
    nonT_fun = @(nonH) nonH + 1;
    % condictivity is weighted average of mixture components
    porKappaPrime_fun = @(phi,nonT) (phi*kappa_w + (1-phi).*kappa_b)/kappa_b; %thermal cond. W/(m-K)
    porNonH_fun = @(phi,nonT) (1-phi).*(nonH_fun(nonT)) + ...
        (phi*rho_w)./(rho_i*c_pi*DT).*(latHeat+c_pw*DT*(nonT-1)); %Dimless enthalpy
    
    % characteristic scales for general convection
    t_c = d^2/D_T; % convection time scale, s
    Ra = rho_i*grav*alpha*d^3*DT/(eta_0*D_T); % basal Rayleigh number
    
    %%%%%%%%%
    mu_f = 1e-3;  %Viscosity of water phase [in Pa.s] (Duh)
    rho_f = 1e3;  %Density of water phase [in kg/m^3] (Duh) 
    
    
    Pi_1 = eta_0 * kc/(mu_f * d^2);      %For updated hydraulic condcutivity of total mass balance
    Pi_3 = kc*d*rho_f*grav/(mu_f * D_T); %For RHS of mass balance (fluid diffusion over heat diffusion)
    Pi_5 = d^3 * rho_i * grav / (eta_0 * D_T);      %Pi 5 from the notes
    Pi_6 = mixZone;                      %Pi 6 from the notes
    %%%%%%%%%
    
    % non-dimensionalize temperature
    % S3 CHANGE: initial dimensionless temperature is set in TGr below.

    % thermal condutvity in convective ocean, set to maintain vertical
    % isotherm in ocean
    kappa_c = 100; %thermal cond. W/(m-K) is set high to make ocean isothermal

    % S3 CHANGE START: Cartesian grid and EXACT original wave realization.
    grRes=100; ocTh=0; % original legacy diagnostic parameter; no ocean layer
    Gridp.xmin=0; Gridp.xmax=32*delta0/d; Gridp.Nx=256;
    Gridp.ymin=0; Gridp.ymax=128*delta0/d; Gridp.Ny=1024;
    Gridp.geom='cartesian';
    Grid=build_stokes_grid(Gridp);
    [X,Y]=meshgrid(Grid.p.xc,Grid.p.yc);
    Xc=X(:); Yc=Y(:);
    init_dir=fullfile(fileparts(mfilename('fullpath')),'porosity-wave-test','MATLAB','porosity-wave-init');
    phi_init=csvread(fullfile(init_dir,'phi_5.csv'));
    vfx_init=csvread(fullfile(init_dir,'vfx_5.csv'));
    vfy_init=csvread(fullfile(init_dir,'vfy_5.csv')); %#ok<NASGU>
    phiodd=phi_init; phieven=phi_init;
    phiodd(1:2:end-1)=[];
    phieven(2:2:end)=[];
    A_init=[phiodd';phieven'];
    phi_init=mean(A_init,1);
    Nc_init=length(vfx_init)-1;
    phi_init=reshape(phi_init,Nc_init,Nc_init);
    phiGr=phi0*ones(Grid.p.Ny,Grid.p.Nx);
    begin_y_por_wave=Gridp.ymax-40*delta0/d;
    ind=find(Grid.p.yc>begin_y_por_wave);
    phiGr(ind(1):ind(1)+256-1,:)=phi0*phi_init;
    TGr=ones(size(phiGr)); % INITIAL temperature only, not prescribed thereafter
    phiOrig=sum(phiGr(:).*Grid.p.V)*d^3;
    % S3 CHANGE END: original equations and time stepping below retained.

    T = TGr(:); %Making Temperature array from grid, N by 1
    phi = phiGr(:); %Making porosity array from grid, N by 1
    H = porNonH_fun(phi,T); %Dimensionless enthalpy array

    %%%%
    %initializing tracer with max conc. unity in a certain region
    %1. Organic tracer
    %dimensionless z = 0.8 to 1.0
    trc1 = ones(Grid.p.N,1); %initializing tracer with max conc. unity
    trc1(Y(:)<0.975) = 0;    %How thick is the organics layer? 1 - 0.975 dimensional units
    
    trc1(phiGr>0.1) = 1;     %Melted region being initialized
    trc1(Y(:)<0.1) = 0;      %Taking out the ocean
    
    %Clathrates tracer
    %dimensionless z = 0.8 to 1.0
    trc2 = ones(Grid.p.N,1); %initializing tracer with max conc. unity
    trc2(Y(:)<0.9) = 0;      %How thick is the clathrate layer? 1 - 0.975 dimensional units
    
    trc2(phiGr>0.1) = 1;%Melted region being initialized
    trc2(Y(:)<0.1)  = 1; %second layer
    trc2(Y(:)<0.0)  = 0; %Taking out the ocean
    
    %%%%
    
    %% build operators
% CHANGE NF-04 START: Use sparse zero storage and equivalent sparse Stokes operators.
% CHANGE NF-04 SOURCE: original lines 202-204; see NOFLOW_BASE_CHANGES.diff.
    Zp = sparse(Grid.p.N,Grid.p.N); %N by N Zero matrix
    Ip = speye(Grid.p.N); %N by N indentity matrix
    [D,Edot,Dp,Gp,I,Gyy]=nf_stokes_ops(Grid); %Making stokes operators
% END CHANGE NF-04
    % Refer to https://mhesse.github.io/numerical_modeling/spring2022/StokesOps.pdf
    % D: Stokes divergence, Edot = operator for strain rate = \nabla (v) + \nabla (v))^T
    % when operates on a velocity vector v, Dp: N by Nf divergence operator on pressure grid
    % Gp: Nf by N gradient operator on pressure grid
    % I is (Nf + N) by (Nf + N) identity matrix to apply BCs
    % Gyy: Gradient of y directional grid in y-direction
    
    linInds = find(Gyy > 0);
    [row,~] = ind2sub(size(Gyy),linInds);
    
    %% Build boundary conditions for temperature and flow equation
% CHANGE NF-05 START: Remove top/base enthalpy constraints; close and insulate every outer face.
% CHANGE NF-05 SOURCE: original lines 216-255; see NOFLOW_BASE_CHANGES.diff.
    % Closed, insulated domain: no prescribed enthalpy or melt fraction.
    Param = struct('H',{},'g',{},'dof_dir',{});
    Param(1).H = struct('dof_dir',{},'dof_f_dir',{},'g',{},'dof_neu',{},'dof_f_neu',{},'qb',{},'dof_out',{});
    Param.H(1).dof_dir = [];
    Param.H(1).dof_f_dir = [];
    Param.H(1).g = [];
    Param.H(1).dof_neu = [Grid.p.dof_xmin;Grid.p.dof_xmax;Grid.p.dof_ymin;Grid.p.dof_ymax];
    Param.H(1).dof_f_neu = [Grid.p.dof_f_xmin;Grid.p.dof_f_xmax;Grid.p.dof_f_ymin;Grid.p.dof_f_ymax];
    Param.H(1).qb = zeros(size(Param.H(1).dof_neu));
    Param.H(1).dof_out = [];
    [BH,NH,fn_H] = build_bnd(Param.H,Grid.p,Ip);
    closed_faces = unique(Param.H.dof_f_neu);

% END CHANGE NF-05
    % Free slip boundary condition for Stokes equation
    %Dirichlet BC below; Natural BCs are automatically defined
    Param(1).dof_dir =  [...
                      Grid.x.dof_xmax;...           %set x_max x-vel
                      Grid.x.dof_xmin;...           %set x_min x-vel
                      Grid.x.N+Grid.y.dof_ymin;...  %set y_min y-vel
                      Grid.x.N+Grid.y.dof_ymax;...  %set y_max y-vel
                      Grid.p.Nf+1];                 %set pressure
    Param(1).g = 0*Param.dof_dir;
    Param.g(end) = 0;
    B = I([Param.dof_dir],:);
    N = I;
    N(:,[Param.dof_dir]) = [];
    fs_T = nan(size(T));
    
    %%%% 
    %% Build boundary conditions for conservative tracer equation, c   
    Param(1).c = struct('dof_dir',{},'dof_f_dir',{},'g',{},'dof_neu',{},'dof_f_neu',{},'qb',{},'dof_out',{}); %%%%
    
    Param.c(1).dof_dir   =  [];
    Param.c(1).dof_f_dir =  [];
    Param.c(1).g         =  [];
    Param.c(1).dof_neu   =  [];
    Param.c(1).dof_f_neu =  [];
    Param.c(1).qb        =  [];
% CHANGE NF-06 START: Supply optional passive-tracer boundary metadata.
% CHANGE NF-06 SOURCE: original lines 281-281; see NOFLOW_BASE_CHANGES.diff.
    Param.c(1).dof_out   =  [];
% END CHANGE NF-06
    [B_c,N_c,fn_c]    =  build_bnd(Param.c(1),Grid.p,Ip);
    %%%%
    
    % create arrays for time evolution storage
    it = 1e9;
    netMelt = [];
    phiDrain1 = 0;
    phiDrain2 = 0;
    tTot = 0;
    tVec = [];
    phiDrain1Vec = []; 
    phiDrain2Vec = [];
    phiFracRem = [];
    frameno = 0; %%%%Initializing frame number for plotting
% CHANGE NF-07 START: Initialize diagnostics/snapshots and bound the requested step count.
% CHANGE NF-07 SOURCE: original lines 295-297; see NOFLOW_BASE_CHANGES.diff.
    result = struct('kc',kc,'mesh',[Grid.p.Nx Grid.p.Ny], ...
        'status','running','completed_steps',0,'steps',[],'time_years',[], ...
        'T_K',[],'phi',[],'H',[],'history',zeros(options.max_steps,23));
    result.history_columns = {'time_years','T_min_K','T_max_K','phi_min','phi_max', ...
        'enthalpy_total','base_abs_v_s','base_abs_q_r','base_abs_advective_heat', ...
        'base_abs_conductive_heat','enthalpy_balance_error','base_phi_min','base_phi_max', ...
        'top_abs_v_s','top_abs_q_r','top_abs_advective_heat','top_abs_conductive_heat', ...
        'top_phi_min','top_phi_max','boundary_abs_v_s','boundary_abs_q_r', ...
        'boundary_abs_advective_heat','boundary_abs_conductive_heat'};
    result.boundary_description = 'closed, insulated top/base/sides; enthalpy and melt fraction free in all cells';
    result.enthalpy_dirichlet_count = numel(Param.H.dof_dir);
    result.use_actual_conductivity_timestep=options.use_actual_conductivity_timestep;
    result.initial_enthalpy_total = sum(H.*Grid.p.V);
    result.output_file = fullfile(options.output_dir,sprintf('noflow_kc_%0.3e.mat',kc));
    result = nf_snapshot(result,0,0,T,phi,H,Grid,d,DT,T_t);
    run_timer = tic;
    % S3 RUN CONTROL: output interval, independent of physical equations.
    next_output_year=options.snapshot_interval_years;

    
    %% temporal evolution
    for i = 1:options.max_steps
% END CHANGE NF-07
        
        % calculate porosity from enthalpy
        [T,phi] = enthMelt(H,mixZone,nonT_fun,phi_fun,TWater_fun);
        %T(T>1) = 1;
        H = porNonH_fun(phi,T);
        %% Bouyancy force as the body force to Stokes flow
        %temp bouyancy
        Tplot= reshape(T,Grid.p.Ny,Grid.p.Nx);
        Tdiag = comp_mean(Tplot,1,1,Grid.p);
        Tvec = diag(Tdiag);
        Ty = Tvec(Grid.p.Nfx+1:Grid.p.Nf);
        fs_T(Ty>1) = -Ra*1;         %All melt only has maximum RHS of Rayleigh number (T>Tm)
        fs_T(Ty<=1) = -Ra*Ty(Ty<=1);%Cold ice without melt has a lower magnitude Ra than 1 (T<=Tm)
        
        %compositional bouyancy
        phiPlot= reshape(phi,Grid.p.Ny,Grid.p.Nx);
        phiDiag = diag(comp_mean(phiPlot,1,1,Grid.p));
        phiY = phiDiag(Grid.p.Nfx+1:Grid.p.Nf);
        fs_por = compBouy_fun(phiY); %calculating RHS of momentum balance
        
        %Gxx variable viscosity matrix
        nxxVec = zeros(Grid.x.Nfx,1);
        nxxVec(Grid.x.Ny+Grid.p.dof) = Tplot;
        
        %Gyy variable viscosity matrix
        nyyVec = zeros(Grid.y.Nfy,1);
        nyyVec(row) = Tplot;
        ncVec = comp_mean_corners(Tplot,-1,Grid.p);
        tempVec = [nxxVec;nyyVec;ncVec];
        
        %% Porosity and temperature dependent viscosity
        % porosity dependent viscosity
        phiPlot = reshape(phi,Grid.p.Ny,Grid.p.Nx);
        nxxVecPhi = zeros(Grid.x.Nfx,1);
        nxxVecPhi(Grid.x.Ny+Grid.p.dof) = phiPlot;
        
        %Gyy variable viscosity matrix
        nyyVecPhi = zeros(Grid.y.Nfy,1);
        nyyVecPhi(row) = phiPlot;
        
        ncVecPhi = comp_mean_corners(phiPlot,-1,Grid.p);
        phiVec = [nxxVecPhi;nyyVecPhi;ncVecPhi];
        
        % merge temperature and melt fraction viscosities
        viscVec = barrViscPhase(tempVec,phiVec,barrViscPhi); %%%% effective solid visc;
        viscVec(isnan(viscVec)) = 0; %Due to mean, 1/0 appear at corners so making them 0
        viscMat = spdiags(viscVec,0,length(viscVec),length(viscVec));
        
        %%%%
        GG = 1; %G from compaction viscosity relation
        mm = 1; %m from compaction viscosity relation
        Zd_vec = ( GG * (1-phi)./(phi+1e-5).^mm - 2/3*(1-phi)).*ViscTempPhi(Tplot(:),phi); %dim-less compaction viscosity

        %size(Zd_vec) 
        %size(comp_mean_corners(Zd_vec,-1,Grid.p))
        Zd = spdiags(Zd_vec,0,Grid.p.N,Grid.p.N);   %transforming into a matrix
        nn  = 2; % S3 CHANGE: permeability exponent
        % nn = 3; %porosity-permeability relation
        
        if test == 'art_perm'
            Kdprime_vec = comp_mean(phiPlot.^nn, 1,1,Grid.p);
        else 
            Kdprime_vec = comp_mean(phiPlot.^nn,-1,1,Grid.p);
        end
% CHANGE NF-08 START: Keep the matrix returned by comp_mean and seal its boundary faces.
% CHANGE NF-08 SOURCE: original lines 361-361; see NOFLOW_BASE_CHANGES.diff.
        Kdprime = Kdprime_vec; % comp_mean already returns a diagonal matrix
        % Use the SAME sealed-boundary mobility in the flow and heat equations.
        Kdprime(closed_faces,:) = 0; % no Darcy flux through the top, base or sides
% END CHANGE NF-08

        fs_fluid_pressure =  - Pi_5 * (rho_f/rho_i) * ones(Grid.p.Nfy,1);  %Extra source term from Pf
        
        % higher porosity acts against Ra bouyancy force 
        fsVec = fs_T + fs_por + fs_fluid_pressure; %adding diffusion and convection equation RHS
        
        %fs_mass = Dp * Kdprime * Pi_3 * [zeros(Grid.p.Nfx,1); ones(Grid.p.Nfy,1)];  %%%%source term of total mass balance; no Gamma term
        fs_mass  = zeros(Grid.p.N,1);   %No source term in mass balance %%%%
        fs = [zeros(Grid.p.Nfx,1); fsVec; fs_mass];  %%%%Added RHS term for total mass balance
        
        %%%%

        %% Stokes Flow calcualtion
        % make linear operators
        tau = D*2*viscMat*Edot;
        % L = [tau,Gp;                             %Two-phase slurry model
        %     Dp,Zp];
        L = [tau+ Gp * Zd * Dp,    -Gp;                 %Darcy-Stokes
           Dp,                    -Dp * Pi_1* Kdprime * Gp];
        % solve for flow velocities
        % DIAGNOSTIC ONLY: reuse the exact original matrix for three RHS cases.
        C=grav*d^3/(eta_0*D_T);
        fs_benchmark=[zeros(Grid.p.Nfx,1); ...
            -(rho_f-rho_i)*(1-phiY)*C; zeros(Grid.p.N,1)];
        fs_no_thermal=[zeros(Grid.p.Nfx,1);fs_por+fs_fluid_pressure;zeros(Grid.p.N,1)];
        F=[fs fs_no_thermal fs_benchmark];
        assert(all(Param.g==0),'Diagnostic assumes homogeneous constraints.');
        reduced=N'*L*N;
        U=N*(reduced\(N'*F));
        labels={'current forcing';'current without thermal buoyancy';'benchmark density-difference forcing'};
        speed=zeros(3,1); mobility_error=zeros(3,1); residual=zeros(3,1);
        [~,gz]=gradient(reshape(phi,Grid.p.Ny,Grid.p.Nx),Grid.p.dx,Grid.p.dy);
        [~,imax]=max(phi); zpeak=Y(imax);
        window=abs(Y(:)-zpeak)<10*delta0/d;
        yr=365.25*86400;
        for j=1:3
            v=U(1:Grid.p.Nf,j); ph=U(Grid.p.Nf+1:end,j);
            q=-Pi_1*Kdprime*(Gp*ph);
            phidot=-Dp*(flux_upwind(v,Grid.p)*phi+q);
            speed(j)=sum(phidot(window).*gz(window))/sum(gz(window).^2)*D_T/d*yr;
            q_physical=-kc/mu_f*Kdprime*(eta_0*D_T/d^3*(Gp*ph));
            mobility_error(j)=norm(q*D_T/d-q_physical,inf)/max(norm(q_physical,inf),eps);
            residual(j)=norm(N'*(L*U(:,j)-F(:,j)),inf)/max(1,norm(N'*F(:,j),inf));
        end
        theoretical=5*kc*(rho_f-rho_i)*grav*phi0/mu_f*yr;
        audit=table(labels,speed,speed/theoretical,mobility_error,residual, ...
            'VariableNames',{'forcing','initial_wave_speed_m_yr','ratio_to_5w0','mobility_scaling_error','linear_residual'});
        disp(audit);
        out=options.output_dir;
        writetable(audit,fullfile(out,'forcing_audit.csv'));
        save(fullfile(out,'forcing_audit.mat'),'audit','theoretical','kc','delta0','d','Ra','Pi_1','Pi_5');
        fid=fopen(fullfile(out,'forcing_audit.txt'),'w');
        fprintf(fid,'kc=%.12g; d=%.12g m; delta0=%.12g m; theoretical=%.12g m/yr\n',kc,d,delta0,theoretical);
        fprintf(fid,'Current effective constant density: rho_f+rho_i*alpha*DT=%.12g kg/m3\n',rho_f+rho_i*alpha*DT);
        fprintf(fid,'Benchmark driving density contrast: %.12g kg/m3\n',rho_f-rho_i);
        for j=1:3
            fprintf(fid,'%s: speed=%.12g m/yr; theory ratio=%.12g; mobility error=%.3g\n',labels{j},speed(j),speed(j)/theoretical,mobility_error(j));
        end
        fclose(fid);
        result.audit=audit;
        return;
    end
end

function options = nf_options(options)
defaults = struct('use_actual_conductivity_timestep',false,'final_years',Inf,'snapshot_interval_years',Inf,'checkpoint_steps',100, ...
    'max_steps',1000,'snapshot_steps',[0 100 250 500 1000], ...
    'legacy_outputs',false,'evolve_tracers',false,'stop_on_melt_loss',false, ...
    'output_dir',fullfile(fileparts(mfilename('fullpath')),'..','Output','s3_minimal'));
names = fieldnames(defaults);
for k=1:numel(names)
    if ~isfield(options,names{k}), options.(names{k})=defaults.(names{k}); end
end
validateattributes(options.max_steps,{'numeric'},{'scalar','integer','positive'});
validateattributes(options.use_actual_conductivity_timestep,{'logical'},{'scalar'});
options.snapshot_steps = unique([0 options.snapshot_steps(:)' options.max_steps]);
options.output_dir = char(options.output_dir);
if ~isfolder(options.output_dir), mkdir(options.output_dir); end
end

function result = nf_snapshot(result,step,time,T,phi,H,Grid,d,DT,T_t)
cols=[floor((Grid.p.Nx+1)/2) ceil((Grid.p.Nx+1)/2)];
left=(cols(1)-1)*Grid.p.Ny+(1:Grid.p.Ny);
right=(cols(2)-1)*Grid.p.Ny+(1:Grid.p.Ny);
result.x_km=mean(Grid.p.xc(cols))*d/1000;
result.z_km=Grid.p.yc(:)*d/1000;
result.steps(end+1)=step;
result.time_years(end+1)=time;
result.T_K(:,end+1)=(T(left)+T(right))/2*DT+T_t;
result.phi(:,end+1)=(phi(left)+phi(right))/2;
result.H(:,end+1)=(H(left)+H(right))/2;
% S3 CHANGE: full-field output alongside existing profiles.
if ~isfield(result,'full_phi')
    result.full_phi=[]; result.full_T_K=[]; result.full_H=[];
end
result.full_phi(:,end+1)=phi;
result.full_T_K(:,end+1)=T*DT+T_t;
result.full_H(:,end+1)=H;
result.Grid=Grid;
result.length_scale_m=d;
end

function [D,Edot,Dp,Gp,I,Gyy]=nf_stokes_ops(Grid)
% Same operators as build_stokes_ops_cyl, using sparse zero blocks.
[Dx,Gx,~]=build_ops(Grid.x); [Dy,Gy,~]=build_ops(Grid.y); [Dp,Gp,~]=build_ops(Grid.p);
Dxx=Dx(:,1:Grid.x.Nfx); Dxy=Dx(:,Grid.x.Nfx+1:Grid.x.Nf);
Dyx=Dy(:,1:Grid.y.Nfx); Dyy=Dy(:,Grid.y.Nfx+1:Grid.y.Nf);
Gxx=Gx(1:Grid.x.Nfx,:); Gxy=Gx(Grid.x.Nfx+1:Grid.x.Nf,:);
Gyx=Gy(1:Grid.y.Nfx,:); Gyy=Gy(Grid.y.Nfx+1:Grid.y.Nf,:);
Edot=[Gxx,sparse(Grid.x.Nfx,Grid.y.N); sparse(Grid.y.Nfy,Grid.x.N),Gyy; .5*Gxy,.5*Gyx];
D=[Dxx,sparse(Grid.x.N,Grid.y.Nfy),Dxy; sparse(Grid.y.N,Grid.x.Nfx),Dyy,Dyx];
I=speye(Grid.N);
end
% END CHANGE NF-21
