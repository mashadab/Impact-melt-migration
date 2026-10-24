% CHANGE NF-01 START: Separate callable solver, options argument and documented closed-domain behavior.
% CHANGE NF-01 SOURCE: original lines 1-1; see NOFLOW_BASE_CHANGES.diff.
function result = darcy_stokes_2D_cases(case_key,fn,eta_0,E_a,kc,test,simple_test,options)
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

    % CASE KEY: only setup branches; flow/transport below are shared S3 code.
    case_key = validatestring(case_key,{'porosity_wave','impact_melt_europa'});
    is_wave = strcmp(case_key,'porosity_wave');
    if nargin < 8, options = struct(); end
    if ~isfield(options,'output_dir')
        options.output_dir=fullfile(fileparts(mfilename('fullpath')),'..','Output',case_key);
    end
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
    if is_wave
    % S3 CHANGE: wave CSV replaces impact initial condition; original scales retained.
    phi0=1e-3;
    delta0=sqrt(kc*phi0^2*eta_0/(phi0*1e-3));
    d=128*delta0;
% END CHANGE NF-03
    % S3 CHANGE: impact-file load removed; exact wave CSV is loaded below.

    else
        fp=fullfile(fileparts(mfilename('fullpath')),'..','initial_conditions','ic');
        load([fp fn '_100.mat'],'T','phi');
    end

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
    if ~is_wave
        rho_i = 920; grav = 1.315; % original Europa material parameters
    end
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
    if is_wave
    % S3 CHANGE: constant intrinsic viscosity for the benchmark.
    ViscTempPhi = @(nonT,phi) ones(size(nonT));
    barrViscPhi = @(nonT,phi) 1-phi; % effective shear viscosity
    end
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
    if ~is_wave, T = (T-T_t)/DT; end

    % thermal condutvity in convective ocean, set to maintain vertical
    % isotherm in ocean
    kappa_c = 100; %thermal cond. W/(m-K) is set high to make ocean isothermal

    if is_wave
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

    else
    %% build cylindirical grid for numerical solution
    % build grid
    grRes = 100; % grid resolution in radial direction
    ocTh = grRes/5; % make ocean below the ice shell: 1/5 factor being 20% of the ice shell
    Gridp.xmin = 0; Gridp.xmax = 2; Gridp.Nx = grRes; %radial direction
    Gridp.ymin = -ocTh/grRes; Gridp.ymax = 1; Gridp.Ny = grRes+ocTh; %vertical direction
    Gridp.geom = 'cylindrical_rz';       %geometry type: cylinderical r-z coordinates
    Grid = build_stokes_grid_cyl(Gridp); %build grid for Stokes equation in 
    [X,Y] = meshgrid(Grid.p.xc,Grid.p.yc);
    
    % convert inital condition to grid
    TGr = reshape(T,grRes,Grid.p.Nx);     %Temp on the grid, K
    phiGr = reshape(phi,grRes,Grid.p.Nx); %porosity on the grid
    Xc = X(:); Yc = Y(:);

    % get initial melt volumes: phiOrig, m^3
    phiOrig = sum(sum(phiGr(10:end,:),1).*Grid.p.V(Grid.p.dof_ymin)' * d^3)
    % First sum is for porosity in the z direction since volume is same
    % Second sum is after multiplying the grid volume at bottom cells
    % Lastly d^3 comes from the redimensionalization to calculate melt volumes
    % First 10 rows are ignored since ocean there is neglected so 
    % phiGr(10:end,:) and not phiGr(1:end,:)
   
    % build ocean layer
    TOc = ones(ocTh,Grid.p.Nx); % lower region initially at 273 K
    phiOc = zeros(ocTh,Grid.p.Nx); % lower region initially has zero melt
    
    % combine ice shell and ocean to get the entire domain fields
    TGr = [TOc; TGr]; %Temperature, K

    if test == 'temprate'
        TGr = TGr * 0 + 1;  %making the temperature 1 everywhere
    end 

    phiGr = [phiOc; phiGr]; %Porosity or melt fraction
    phiGr(Y>=0 & Y<0.25) = 0; % retain original shell mask; exclude ocean
    TGr(Y<0) = 1; % enforce 273 K in the initially zero-melt lower region
    end

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
    if is_wave
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

    else
    % EUROPA: retain the original fixed cold surface, with a free basal enthalpy.
    % Material impermeability does not prescribe a basal melt fraction.
    Param = struct('H',{},'g',{},'dof_dir',{});
    Param(1).H = struct('dof_dir',{},'dof_f_dir',{},'g',{},'dof_neu',{},'dof_f_neu',{},'qb',{},'dof_out',{});
    Param.H(1).dof_dir = Grid.p.dof_ymax;
    Param.H(1).dof_f_dir = Grid.p.dof_f_ymax;
    Param.H(1).g = nonH_fun(0)*ones(numel(Grid.p.dof_ymax),1);
    Param.H(1).dof_neu = [Grid.p.dof_xmin;Grid.p.dof_xmax;Grid.p.dof_ymin];
    Param.H(1).dof_f_neu = [Grid.p.dof_f_xmin;Grid.p.dof_f_xmax;Grid.p.dof_f_ymin];
    Param.H(1).qb = [zeros(size(Grid.p.dof_xmin));zeros(size(Grid.p.dof_xmax));options.basal_heat_flux*ones(size(Grid.p.dof_ymin))];
    Param.H(1).dof_out = [];
    [BH,NH,fn_H] = build_bnd(Param.H,Grid.p,Ip);
    closed_faces = unique([Param.H.dof_f_neu;Grid.p.dof_f_ymax]); % MATERIAL walls

    end

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
        'T_K',[],'phi',[],'H',[],'history',zeros(min(options.max_steps,10000),23));
    result.history_columns = {'time_years','T_min_K','T_max_K','phi_min','phi_max', ...
        'enthalpy_total','base_abs_v_s','base_abs_q_r','base_abs_advective_heat', ...
        'base_abs_conductive_heat','enthalpy_balance_error','base_phi_min','base_phi_max', ...
        'top_abs_v_s','top_abs_q_r','top_abs_advective_heat','top_abs_conductive_heat', ...
        'top_phi_min','top_phi_max','boundary_abs_v_s','boundary_abs_q_r', ...
        'boundary_abs_advective_heat','boundary_abs_conductive_heat'};
    result.boundary_description = 'closed, insulated top/base/sides; enthalpy and melt fraction free in all cells';
    result.case_key = case_key;
    result.baseline = 'porosity_wave_2D_Jake_minimal.m';
    result.permeability_exponent=2;
    if ~is_wave, result.permeability_exponent=3; end
    if ~is_wave
        result.boundary_description='impermeable material walls; fixed cold surface; prescribed basal heat flux; free basal enthalpy';
    end
    result.enthalpy_dirichlet_count = numel(Param.H.dof_dir);
    result.correct_head_reference=options.correct_head_reference;
    result.use_actual_conductivity_timestep=options.use_actual_conductivity_timestep;
    result.initial_enthalpy_total = sum(H.*Grid.p.V);
    cumulative_heat_input = 0; % diagnostics only; no change to time evolution
    result.output_file = fullfile(options.output_dir,sprintf('noflow_kc_%0.3e.mat',kc));
    result = nf_snapshot(result,0,0,T,phi,H,Grid,d,DT,T_t);
    if ~is_wave
        result.melt_budget=europa_melt_budget([],phi,Grid.p,d,0,0,[]);
        phiOrig=result.melt_budget.initial_volume_m3(2); % actual initialized shell melt
        result.initial_shell_melt_m3=phiOrig;
        result.target_shell_melt_m3=options.remaining_melt_fraction*phiOrig;
        result.remaining_melt_fraction_threshold=options.remaining_melt_fraction;
        if options.save_state_snapshots
            save_Europa_state(options.output_dir,0,0,NaN,T,phi,H,Grid,d,DT,T_t, ...
                [],[],[],[],[],[],eta_0,D_T,kc,3);
        end
    end
    if options.initial_only
        result.status='initialized';
        result.history=result.history([],:);
        result.final_state=struct('H',H,'T_dimensionless',T,'phi',phi,'Grid',Grid);
        save(result.output_file,'result');
        if ~is_wave, writetable(result.melt_budget.history,fullfile(options.output_dir,'melt_budget.csv')); end
        return; % initialization only: no flow solve or time advancement
    end
    run_timer = tic;
    % S3 RUN CONTROL: output interval, independent of physical equations.
    next_output_year=options.snapshot_interval_years;
    requested_snapshot_index=1;

    
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
        if ~is_wave, nn=3; end % Europa manuscript law; wave keeps validated S3 law
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
        % TRIAL FLAG: restore the reference removed by the inherited buoyancy.
        % rho_ref/rho_i = 1+alpha*DT; retain P_f=p_f+rho_f*g*z (head form).
        if options.correct_head_reference
            fsVec=fsVec+(Pi_5+Ra)*ones(size(fsVec));
        end
        
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
        u = solve_lbvp(L,fs,B,Param.g,N);
        vx = u(1:Grid.p.Nfx);
        vy = u(Grid.p.Nfx+1:(Grid.p.Nfx+Grid.p.Nfy));
        vm = [vx;vy];       %velocity of the solid phase, m/s
        vmax= max(abs(vm)); %largest solid velocity
        p  = u((Grid.p.Nfx+Grid.p.Nfy+1):end); %Dimless fluid pressure coupled with gravitational head
        %vf = vm - Pi_1 * comp_mean(phiPlot.^(nn-1),1,1,Grid.p) * ( Gp * p + (rho_w/rho_i) * Pi_5 * [zeros(Grid.p.Nfx,1); ones(Grid.p.Nfy,1)]); %calculate the dimless fluid velocity %%%%
        if test == 'harmperm' | test == 'effe_vel'
            vf = vm - Pi_1 * comp_mean(phiPlot.^(nn-1),-1,1,Grid.p) * ( Gp * p ); %calculate the dimless fluid velocity %%%%
        else
            vf = vm - Pi_1 * comp_mean(phiPlot.^(nn-1), 1,1,Grid.p) * ( Gp * p ); %calculate the dimless fluid velocity %%%%
        end
        vfy = vf(Grid.p.Nfx+1:(Grid.p.Nfx+Grid.p.Nfy)); %y-directional fluid velocity

% CHANGE NF-09 START: Preserve solved pressure head and use it for the Darcy flux.
% CHANGE NF-09 SOURCE: original lines 396-396; see NOFLOW_BASE_CHANGES.diff.
        p_head = p; % preserve the solved pressure head for all Darcy fluxes
        qr = -Pi_1 * Kdprime * (Gp * p_head);
        p = p_head - (rho_f/rho_i) * Pi_5 * Y(:);  %Calculating fluid from overall pressure  %%%%
% END CHANGE NF-09
        vfmax= max(abs(vf)); %largest solid velocity        
        

        overpressure = GG * spdiags((1./(phi+1e-15).^mm) .* ViscTempPhi(Tplot(:),phi),0,Grid.p.N,Grid.p.N) * (Dp * vm) *eta_0*D_T/d^2 ; %redimensionalizing overpressure [Pa] G * mu./ phi.^m .* (Dp * v);      %Solid pressure
        %   GG * (1-phi)./(phi+1e-15).^mm * Dp * vm

        % Adaptive time stepping based on competition b/w CFL and Neumann
        % conditions in each direction; CFL number set to 0.8
        dt = 0.5*max(min([min(0.5*Grid.p.dx^2/kappa_c),min(Grid.p.dx/vmax),min(Grid.p.dx/vfmax),min(Grid.p.dy/vfmax),min(0.5*Grid.p.dy^2/kappa_c), min(Grid.p.dy/vmax)]));
        
        % S3 RUN CONTROL: shorten only the final step to hit the requested time.
        dt=min(dt,max(0,(options.final_years-tTot)*3.154e7/t_c));

        %% non-linear thermal conducitivity matricies
        kappaPrime = porKappaPrime_fun(phi,T); %thermal conductivity, K
        % select near boundary ocean cells
        ocLog = Y(:) < 2/grRes & phi > 0.5; %Porosity greater than 50% and z (2)
        kappaPrime(ocLog) = kappa_c;
        kappaPrimePlot = reshape(kappaPrime,Grid.p.Ny,Grid.p.Nx);
        
        if test == 'harmperm' | test == 'effe_vel'
            kappaFace = comp_mean(kappaPrimePlot,-1,1,Grid.p);            
        else
            kappaFace = comp_mean(kappaPrimePlot,1,1,Grid.p);
        end
        
                
        % S3 TIMESTEP FLAG: false preserves the original dt above exactly.
        % true uses ACTUAL face conductivity with a 20% diffusion safety margin.
        % Flow, heat/phase equations, and conductivity values are unchanged.
        if options.use_actual_conductivity_timestep
            kmax=max(full(diag(kappaFace)));
            dt_diff=0.4/(kmax*(1/Grid.p.dx^2+1/Grid.p.dy^2));
            dt_adv=0.5*min([Grid.p.dx/vmax,Grid.p.dy/vmax, ...
                           Grid.p.dx/vfmax,Grid.p.dy/vfmax]);
            dt=min([dt_diff,dt_adv, ...
                max(0,(options.final_years-tTot)*3.154e7/t_c)]);
        end

        %% Advection of enthalpy, diffusion of temperature
        %AH = build_adv_op(vm,H,dt,Gp,Grid.p,Param.H,'mc')*H; %Upwinding the enthalpy from center to faces
        %Old approach (do not average)

        %norm(AH - AHnew2)
        %
        if test == 'comb_vel'
                %New approach
            phi_face_vec = comp_mean(phiPlot,1,1,Grid.p)*ones(Grid.p.Nf,1);
            v_tot = vm.*(1-phi_face_vec) + vf.*phi_face_vec;  %%%% This is where we need to add more variation in velocity        
            AHnew2 = build_adv_op(v_tot,((1-phi).*(T-1) + phi*Pi_6),dt,Gp,Grid.p,Param.H,'mc')*((1-phi).*(T-1) + phi*Pi_6);
            AH = AHnew2;
        elseif test == 'effe_vel'
% CHANGE NF-10 START: Use the same permeability and pressure head in enthalpy advection.
% CHANGE NF-10 SOURCE: original lines 434-434; see NOFLOW_BASE_CHANGES.diff.
            qr = -Pi_1 * Kdprime * (Gp * p_head); %Dimless Darcy flux
% END CHANGE NF-10
            D_k = (T-1)/Pi_6;
            tilde_phi = (1-phi).*D_k + phi;
            %v_tot = (vm.*(1-phi_face_vec).*(T_face_vec-1) + vf.*phi_face_vec*Pi_6)./((1-phi_face_vec).*(T_face_vec-1) + phi_face_vec*Pi_6);  %%%% This is where we need to add more variation in velocity        
            %AHnew3 = build_adv_op(v_tot,((1-phi).*(T-1) + phi*Pi_6),dt,Gp,Grid.p,Param.H,'gd')*((1-phi).*(T-1) + phi*Pi_6);
            %Effective velocity
            Aq =  build_adv_op(qr,(1./tilde_phi),dt,Gp,Grid.p,Param.H,'gd')*spdiags(1./tilde_phi,0,Grid.p.N,Grid.p.N);  %%%%Advection operator of dimensionless Darcy flux       
            Ae =  build_adv_op(vm,H,dt,Gp,Grid.p,Param.H,'gd');  %%%%  %Advection operator of dimensionless solid velocity; H' = Pi_6*tilde_phi       
            AH =  (Aq + Ae)*H; %advection operator multiplied to the dimensionless enthalpy

        else
            AHs = build_adv_op(vm,(1-phi).*(T-1),dt,Gp,Grid.p,Param.H,'mc')*((1-phi).*(T-1)); %Upwinding the solid enthalpy from center to faces %%%%%%%
            AHf = build_adv_op(vf,phi*Pi_6,dt,Gp,Grid.p,Param.H,'mc')*(phi*Pi_6); %Upwinding the fluid enthalpy from center to faces %%%%%%%
            AH  = AHs + AHf; %Combine the advection operator
        end         

        %AHnew2 = build_adv_op(vm,((1-phi).*(T-1) + phi*Pi_6),dt,Gp,Grid.p,Param.H,'mc')*((1-phi).*(T-1) + phi*Pi_6);
        %AHnew3 = (build_adv_op(vm,(1-phi).*(T-1),dt,Gp,Grid.p,Param.H,'mc')*((1-phi).*(T-1))+build_adv_op(vm,phi*Pi_6,dt,Gp,Grid.p,Param.H,'mc')*(phi*Pi_6))
        %norm(H - ((1-phi).*(T-1) + phi*Pi_6))
        
        if ~is_wave
            % Diagnostic only: total liquid-volume flux = phi*v_s + Darcy flux.
            liquid_flux_diagnostic=flux_upwind(vm,Grid.p)*phi + qr;
        end
        L_T_I = Ip;  % Implicit operator (Unity as the method is explicit) 
        L_T_E_T = - dt*(-Dp*kappaFace*Gp); %Linear operator of heat diffusion
        L_T_E_H = H - dt*(Dp*AH);         %Linear operator of heat advection
        RHS_T = L_T_E_H + L_T_E_T*T + (fn_H)*dt; %RHS of enthalpy balance
        H = solve_lbvp(L_T_I,RHS_T,BH,Param.H.g,NH); %time marching the enthalpy equation
        % Diagnostics: account for prescribed heat and surface thermostat exchange.
        cumulative_heat_input = cumulative_heat_input + dt*sum(fn_H.*Grid.p.V) ...
            + sum((H(Param.H.dof_dir)-RHS_T(Param.H.dof_dir)).*Grid.p.V(Param.H.dof_dir));
        

        %%%%%%%%%%%%%new add extra
        [T,phi] = enthMelt(H,mixZone,nonT_fun,phi_fun,TWater_fun);
        %T(T>1) = 1;
        H = porNonH_fun(phi,T);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
% CHANGE NF-11 START: Make passive-tracer updates optional; disabled for these column tests.
% CHANGE NF-11 SOURCE: original lines 466-466; see NOFLOW_BASE_CHANGES.diff.
        if options.evolve_tracers
% END CHANGE NF-11
        %% Advection of organic tracer fn_c is the same as natural BCs
        %Organics
        %Ac1 = build_adv_op(vm,trc1,dt,Gp,Grid.p,Param.c,'mc');%Upwinding the tracer conc. from center to faces
        %Ac1s = build_adv_op(vm,trc1.*(1-phi),dt,Gp,Grid.p,Param.c,'mc');%Upwinding the tracer conc. from center to faces (solid)  %%%%
        %Ac1f = build_adv_op(vf,trc1.*phi,dt,Gp,Grid.p,Param.c,'mc');%Upwinding the tracer conc. from center to faces (fluid) %%%%       
        %Ac1  = Ac1s + Ac1f; %Total transport flux of tracer 1 %%%%
        phi_face_vec = comp_mean(phiPlot,1,1,Grid.p)*ones(Grid.p.Nf,1);
        v_tot = vm.*(1-phi_face_vec) + vf.*phi_face_vec;  %%%% This is where we need to add more variation in velocity
        Ac1 = build_adv_op(v_tot,trc1,dt,Gp,Grid.p,Param.c,'mc');%Upwinding the tracer conc. from center to faces
        L_c_I = Ip;  % Implicit operator (Unity as the method is explicit) 
        L_c_E1 = Ip - dt*(Dp * Ac1);% Explicit operator of tracer advection
        RHS_c1 = L_c_E1 * trc1 + (fn_c) * dt; %Forming the vector B of Ax = B
        trc1 = solve_lbvp(L_c_I,RHS_c1, B_c, Param.c.g,N_c); %time marching the tracer equation
        
        %Clathrates
        %Ac2 = build_adv_op(vm,trc2,dt,Gp,Grid.p,Param.c,'mc');%Upwinding the tracer conc. from center to faces
        %Ac2s = build_adv_op(vm,trc2.*(1-phi),dt,Gp,Grid.p,Param.c,'mc');%Upwinding the tracer conc. from center to faces (solid)  %%%%
        %Ac2f = build_adv_op(vf,trc2.*phi,dt,Gp,Grid.p,Param.c,'mc');%Upwinding the tracer conc. from center to faces (fluid) %%%%       
        %Ac2  = Ac2s + Ac2f; %Total transport flux of tracer 1 %%%%
        Ac2 = build_adv_op(v_tot,trc2,dt,Gp,Grid.p,Param.c,'mc');%Upwinding the tracer conc. from center to faces
        L_c_E2 = Ip - dt*(Dp * Ac2);% Explicit operator of tracer advection
        RHS_c2 = L_c_E2 * trc2 + (fn_c) * dt; %Forming the vector B of Ax = B
        trc2 = solve_lbvp(L_c_I,RHS_c2, B_c, Param.c.g,N_c); %time marching the tracer equation
        
% CHANGE NF-12 START: Make passive-tracer updates optional; disabled for these column tests.
% CHANGE NF-12 SOURCE: original lines 490-490; see NOFLOW_BASE_CHANGES.diff.
        end % optional passive-tracer update
% END CHANGE NF-12
        if is_wave
        %% calculate net melt and melt transported to "ocean"
        % make two planes to measure the melt transported through
        % plane 1
        abInd = 5;
        phiGr = reshape(phi,Grid.p.Ny,Grid.p.Nx);
        bdPhi = mean(phiGr(ocTh+abInd:ocTh+abInd+1,:),1).*Grid.p.V(Grid.p.dof_ymin)';
        vyGr = reshape(vfy,Grid.y.Ny,Grid.y.Nx);
        bdVy = vyGr(ocTh+abInd+1,:);
        meltTrans = bdPhi .* bdVy / Grid.p.dy * dt * d^3;
        phiDrain2 = phiDrain2 - sum(meltTrans(bdVy < 0)); % m^3
        phiDrain2Vec = [phiDrain2Vec phiDrain2];
        
        % plane 2
        phiGr = reshape(phi,Grid.p.Ny,Grid.p.Nx);
        bdPhi = mean(phiGr(ocTh+(abInd-1):ocTh+(abInd-1)+1,:),1).*Grid.p.V(Grid.p.dof_ymin)';
        vyGr = reshape(vfy,Grid.y.Ny,Grid.y.Nx);
        bdVy = vyGr(ocTh+(abInd-1)+1,:);
        meltTrans = bdPhi .* bdVy / Grid.p.dy * dt * d^3;
        phiDrain1 = phiDrain1 - sum(meltTrans(bdVy < 0)); % m^3
        phiDrain1Vec = [phiDrain1Vec phiDrain1];
        
        % total melt left
        netMelt = [netMelt sum(phi .* Grid.p.V * d^3)];
        % select near bouundary ocean cells
        % time stepping
        tTot = tTot + dt*t_c/(3.154e7); %Yrs
        tVec = [tVec tTot];
    
        % calculate remaining phi above near ocean, bottom 20% of ice shell
        phiRem = sum(sum(phiGr(ocTh+grRes/5:end,:),1).*Grid.p.V(Grid.p.dof_ymin)' * d^3);
        phiFracRem = [phiFracRem phiRem/phiOrig];

        
        else
            % Europa volume budgets: shell z>=0; delivery plane exactly z=0.
            tTot=tTot+dt*t_c/(3.154e7);
            tVec=[tVec tTot];
            result.melt_budget=europa_melt_budget(result.melt_budget,phi,Grid.p,d,tTot,dt,liquid_flux_diagnostic);
            phiGr=reshape(phi,Grid.p.Ny,Grid.p.Nx);
            phiRem=result.melt_budget.liquid_volume_m3(end,2);
            netMelt=[netMelt phiRem]; % melt remaining in the ice shell
            phiFracRem=[phiFracRem phiRem/phiOrig];
            % Both legacy names now refer to the ONE selected plane and net flux.
            phiDrain1=result.melt_budget.delivered_net_m3(end);
            phiDrain2=phiDrain1;
            phiDrain1Vec=[phiDrain1Vec phiDrain1];
            phiDrain2Vec=[phiDrain2Vec phiDrain2];
        end

% CHANGE NF-13 START: Add flux/energy checks and checkpoints; make early stopping optional.
% CHANGE NF-13 SOURCE: original lines 523-526; see NOFLOW_BASE_CHANGES.diff.
        % Closed-domain checks: no material/heat flux and no imposed enthalpy.
        fb = Grid.p.dof_f_ymin;
        ft = Grid.p.dof_f_ymax;
        conductive = -kappaFace*(Gp*T);
        if ~is_wave, conductive(fb)=options.basal_heat_flux; end
        enthalpy_now = sum(H.*Grid.p.V);
        energy_error = enthalpy_now-result.initial_enthalpy_total-cumulative_heat_input;
        if i>size(result.history,1)
            result.history(min(options.max_steps,size(result.history,1)+10000),23)=0;
        end
        result.history(i,:) = [tTot,min(T)*DT+T_t,max(T)*DT+T_t,min(phi),max(phi), ...
            enthalpy_now,max(abs(vm(fb))),max(abs(qr(fb))),max(abs(AH(fb))), ...
            max(abs(conductive(fb))),energy_error, ...
            min(phi(Grid.p.dof_ymin)),max(phi(Grid.p.dof_ymin)), ...
            max(abs(vm(ft))),max(abs(qr(ft))),max(abs(AH(ft))),max(abs(conductive(ft))), ...
            min(phi(Grid.p.dof_ymax)),max(phi(Grid.p.dof_ymax)), ...
            max(abs(vm(closed_faces))),max(abs(qr(closed_faces))), ...
            max(abs(AH(closed_faces))),max(abs(conductive(closed_faces)))];
        if i==1 || mod(i,50)==0
            fprintf('no-flow kc=%g step=%d/%d t=%.6g yr wall=%.1fs T=[%.6g %.6g] base_phi=[%.6g %.6g] E_error=%.3g\n', ...
                kc,i,options.max_steps,tTot,toc(run_timer),min(T)*DT+T_t,max(T)*DT+T_t, ...
                min(phi(Grid.p.dof_ymin)),max(phi(Grid.p.dof_ymin)),energy_error);
            if ~is_wave
                fprintf('shell_melt=%.9g km3 remaining_fraction=%.9g target_fraction=%.9g delivered_net=%.9g km3 refrozen_net_shell=%.9g km3\n', ...
                    phiRem/1e9,phiFracRem(end),options.remaining_melt_fraction,phiDrain1/1e9,result.melt_budget.refrozen_net_m3(end,2)/1e9);
            end
            drawnow;
        end
        requested_snapshot_due=requested_snapshot_index<=numel(options.snapshot_years) ...
            && tTot>=options.snapshot_years(requested_snapshot_index);
        if any(i==options.snapshot_steps) || tTot>=next_output_year || requested_snapshot_due
            while requested_snapshot_index<=numel(options.snapshot_years) ...
                    && tTot>=options.snapshot_years(requested_snapshot_index)
                requested_snapshot_index=requested_snapshot_index+1;
            end
            next_output_year=tTot+options.snapshot_interval_years;
            result = nf_snapshot(result,i,tTot,T,phi,H,Grid,d,DT,T_t);
            if ~is_wave && options.save_state_snapshots
                save_Europa_state(options.output_dir,i,tTot,tTot-dt*t_c/3.154e7, ...
                    T,phi,H,Grid,d,DT,T_t,vm,vf,qr,p_head,p,overpressure,eta_0,D_T,kc,nn);
            end
            save(result.output_file,'result');
        end
        if any(~isfinite(H)) || any(~isfinite(T)) || any(~isfinite(phi)) || min(T)*DT+T_t <= 0
            result.status = 'failed';
            result.failure_message = 'Non-finite state or non-positive absolute temperature.';
            break;
        end

        % S3 RUN CONTROL: lightweight restart-state checkpoint; no field changes.
        if i==1 || mod(i,options.checkpoint_steps)==0
            save(fullfile(options.output_dir,'checkpoint.mat'),'H','T','phi','Grid', ...
                'tTot','i','d','options','-v7.3');
            if ~is_wave
                progress=struct('step',i,'time_years',tTot,'melt_remaining_m3',phiRem, ...
                    'remaining_fraction',phiFracRem(end),'target_fraction',options.remaining_melt_fraction, ...
                    'delivered_net_m3',phiDrain1,'refrozen_net_shell_m3',result.melt_budget.refrozen_net_m3(end,2));
                fid=fopen(fullfile(options.output_dir,'progress.json'),'w');fprintf(fid,'%s',jsonencode(progress));fclose(fid);
                writetable(result.melt_budget.history,fullfile(options.output_dir,'melt_budget.csv'));
            end
        end
        if tTot>=options.final_years-1e-10, break; end

        % condition for ending simulation
        if options.stop_on_melt_loss && ((is_wave && (phiFracRem(end)<termFrac || i>10000)) ...
                || (~is_wave && phiFracRem(end)<=options.remaining_melt_fraction))
            if ~is_wave, result.stop_reason='melt_depleted'; end
            %  point
            save([options.output_dir filesep fn '_eta0_' num2str(log10(eta_0)) '_Ea_' num2str(E_a/1e3) '_output_' num2str(i) 'kc' num2str(kc) 'C.mat'],...
                'Tplot','phi','Grid','phiDrain1Vec','phiDrain2Vec','phiOrig','tVec',...
                'phiFracRem','T','phi','tVec','phiDrain1Vec','phiDrain2Vec','phiOrig')
% END CHANGE NF-13
            break
        end
    
        %% PLOTTING
% CHANGE NF-14 START: Make the original 2D graphics optional.
% CHANGE NF-14 SOURCE: original lines 533-533; see NOFLOW_BASE_CHANGES.diff.
         if options.legacy_outputs && (mod(i,100) == 0 || i==1)
% END CHANGE NF-14
            greens = interp1([0;1],[1 1 1; 0.45, 0.65, 0.38],linspace(0,1,256));
            reds = interp1([0;1],[1 1 1;  190/255  30/255  45/255],linspace(0,1,256));
            blues = interp1([0;1],[1 1 1; 39/255  170/255  225/255],linspace(0,1,256));
            
             i
             %{
            %streamfunction plot
            h=figure('Visible', 'on'); %For visibility: h=figure(4);
            set(gcf,'units','points','position',[0,0,3125,1250])
            % Enlarge figure to full screen.
            [PSI,psi_min,psi_max] = comp_streamfun(vm,Grid.p);
            set(gcf, 'Position', [50 50 1500 600])
            ax1 = subplot(1,3,1);
            cla;
            hold on
            axis equal
            Tplot_dummy=Tplot;
            contourf(X*d/1e3,Y*d/1e3-Grid.p.dy,Tplot*DT+T_t,40,'linestyle','none'),view(2),hold on
            c1 = colorbar('NorthOutside');
            caxis([min(Tplot(:)) max(Tplot(:))]*DT+T_t);
            cStrVal = linspace(min(PSI(:)),max(PSI(:)),10);
            %contour(Grid.p.xf*d/1e3,Grid.p.yf*d/1e3,PSI,'k','LevelList',cStrVal);
            c1.Label.String = 'Temperature, K';
            xlabel('x-dir, km');
            ylabel('z-dir, km');
            colormap(ax1,reds);
            clim([T_t T_b])
            %melt fraction plot
            ax2 = subplot(1,3,2);
            t = sgtitle(sprintf('time=%.3f years',tTot)); t.FontSize = 20;
            cla;
            axis equal
            hold on
            contourf(X,Y,reshape(phi,Grid.p.Ny,Grid.p.Nx),40,'linestyle','none'),view(2),hold on
            phi_dummy=phi;       
            contourf(X*d/1e3,Y*d/1e3-Grid.p.dy,reshape(phi_dummy,Grid.p.Ny,Grid.p.Nx),40,'linestyle','none'),view(2),hold on
            c2 = colorbar('NorthOutside');
            colormap(ax2,blues);
            xlabel('x-dir, km');
            ylabel('z-dir, km');
            c2.Label.String = 'Melt fraction, 1';

            %melt fraction plot
            ax3 = subplot(1,3,3);
            t = sgtitle(sprintf('time=%.3f years',tTot)); t.FontSize = 20;
            cla;
            axis equal
            hold on
            phi_sign = ones(size(phi)); phi_sign(phi<1e-6) = 0;
            %oneminusphi_sign = ones(size(phi)); oneminusphi_sign(1-phi<1e-6) = 0;            
            %overpressure_two_phase = phi_sign.*oneminusphi_sign.*overpressure;
            overpressure_two_phase = overpressure;
            %overpressure_two_phase(overpressure_two_phase==0) = nan;
            contourf(X*d/1e3,Y*d/1e3,log10(abs(reshape(overpressure,Grid.p.Ny,Grid.p.Nx))),40,'linestyle','none'),view(2),hold on       
            %contourf(X*d/1e3,Y*d/1e3-Grid.p.dy,((reshape(overpressure_two_phase,Grid.p.Ny,Grid.p.Nx))),40,'linestyle','none'),view(2),hold on
            c2 = colorbar('NorthOutside');
            colormap(ax3,'hot');
            xlabel('x-dir, km');
            ylabel('z-dir, km');
            c2.Label.String = 'log[Overpressure], log Pa';
            %}
            
            
            %clim([0 10])


                       %streamfunction plot
            h=figure('Visible', 'on'); %For visibility: h=figure(4);
            set(gcf,'units','points','position',[0,0,3125,1250])
            % Enlarge figure to full screen.
            [PSI,psi_min,psi_max] = comp_streamfun(vm,Grid.p);
            set(gcf, 'Position', [50 50 1500 600])

            ax1 = subplot(3,3,1);
            t = sgtitle(sprintf('time=%.3f years',tTot)); t.FontSize = 20;
            cla;
            hold on
            axis equal
            Tplot_dummy=Tplot;
            contourf(X*d/1e3,Y*d/1e3-Grid.p.dy,Tplot*DT+T_t,40,'linestyle','none'),view(2),hold on
            c1 = colorbar('NorthOutside');
            if min(Tplot(:))  == max(Tplot(:))
                caxis([T_t T_b]);
            else
                caxis([min(Tplot(:)) max(Tplot(:))]*DT+T_t);
            end 
            cStrVal = linspace(min(PSI(:)),max(PSI(:)),10);
            %contour(Grid.p.xf*d/1e3,Grid.p.yf*d/1e3,PSI,'k','LevelList',cStrVal);
            c1.Label.String = 'Temperature, K';
            xlabel('x-dir, km');
            ylabel('z-dir, km');
            colormap(ax1,reds);
            %clim([T_t T_b])



            %melt fraction plot
            ax2 = subplot(3,3,2);
            t = sgtitle(sprintf('time=%.3f years',tTot)); t.FontSize = 20;
            cla;
            axis equal
            hold on
            contourf(X,Y,reshape(phi,Grid.p.Ny,Grid.p.Nx),40,'linestyle','none'),view(2),hold on
            phi_dummy=phi;       
            contourf(X*d/1e3,Y*d/1e3-Grid.p.dy,reshape(phi_dummy,Grid.p.Ny,Grid.p.Nx),40,'linestyle','none'),view(2),hold on
            c2 = colorbar('NorthOutside');
            colormap(ax2,blues);
            xlabel('x-dir, km');
            ylabel('z-dir, km');
            c2.Label.String = 'Melt fraction, 1';

            %melt fraction plot
            ax3 = subplot(3,3,3);
            t = sgtitle(sprintf('time=%.3f years',tTot)); t.FontSize = 20;
            cla;
            axis equal
            hold on
            phi_sign = ones(size(phi)); phi_sign(phi<1e-6) = 0;
            contourf(X*d/1e3,Y*d/1e3-Grid.p.dy,log10(abs(reshape(p*eta_0*D_T/d^2,Grid.p.Ny,Grid.p.Nx))),40,'linestyle','none'),view(2),hold on
            c2 = colorbar('NorthOutside');
            colormap(ax3,'hot');
            xlabel('x-dir, km');
            ylabel('z-dir, km');
            c2.Label.String = 'log_{10} Fluid pressure, log_{10} Pa';
            clim([6 7])

            %melt fraction plot
            ax3 = subplot(3,3,4);
            t = sgtitle(sprintf('time=%.3f years',tTot)); t.FontSize = 20;
            cla;
            axis equal
            hold on
            phi_sign = ones(size(phi)); phi_sign(phi<1e-6) = 0;
            %oneminusphi_sign = ones(size(phi)); oneminusphi_sign(1-phi<1e-6) = 0;            
            %overpressure_two_phase = phi_sign.*oneminusphi_sign.*overpressure;
            contourf(X*d/1e3,Y*d/1e3,log10(abs(reshape(overpressure,Grid.p.Ny,Grid.p.Nx))),40,'linestyle','none'),view(2),hold on       
            
            c2 = colorbar('NorthOutside');
            colormap(ax3,'hot');
            xlabel('x-dir, km');
            ylabel('z-dir, km');
            c2.Label.String = 'log_{10}|Overpressure|, log_{10} Pa';

            %velocity difference plot
            ax5 = subplot(3,3,5);
            t = sgtitle(sprintf('time=%.3f years',tTot)); t.FontSize = 20;
            cla;
            axis equal
            hold on
            phi_sign = ones(size(phi)); phi_sign(phi<1e-6) = 0;
            %oneminusphi_sign = ones(size(phi)); oneminusphi_sign(1-phi<1e-6) = 0;            
            %overpressure_two_phase = phi_sign.*oneminusphi_sign.*overpressure;
            Mp = Dp; Mp(Mp~=0)=0.5;%Mean matrix adhoc to find cell center values without boundary treatment
            Mp(:,1:Grid.p.Nfx) = 0;
            contourf(X*d/1e3,Y*d/1e3,reshape(D_T/d*Mp*vf,Grid.p.Ny,Grid.p.Nx),40,'linestyle','none'),view(2),hold on       
            
            c2 = colorbar('NorthOutside');
            colormap(ax5,'hot');
            xlabel('x-dir, km');
            ylabel('z-dir, km');
            c2.Label.String = 'v_w in y-dir, m/s';
 
            %velocity difference plot
            ax6 = subplot(3,3,6);
            t = sgtitle(sprintf('time=%.3f years',tTot)); t.FontSize = 20;
            cla;
            axis equal
            hold on
            Mp = Dp; Mp(Mp~=0)=0.5;%Mean matrix adhoc to find cell center values without boundary treatment
            Mp(:,1:Grid.p.Nfx) = 0;
            vy_only = vf - vm; %vy_only(1:Grid.p.Nfx) = 0;
            contourf(X*d/1e3,Y*d/1e3,reshape(D_T/d*Mp*vy_only,Grid.p.Ny,Grid.p.Nx),40,'linestyle','none'),view(2),hold on       
            
            c2 = colorbar('NorthOutside');
            colormap(ax6,'hot');
            xlabel('x-dir, km');
            ylabel('z-dir, km');
            c2.Label.String = 'v_w - v_i in y-dir, m/s';

            %strain rates of ice phase

            EE = Edot*vm;
            Exx = EE(1:Grid.x.Nfx,:); Eyy = EE(Grid.x.Nfx+1:Grid.x.Nfx+Grid.y.Nfy,:); Exy = EE(Grid.x.Nfx+Grid.y.Nfy+1:end,:);
            Exx = reshape(Exx,Gridp.Ny,Gridp.Nx+2); Eyy = reshape(Eyy,Gridp.Ny+2,Gridp.Nx); Exy = reshape(Exy,Gridp.Ny+1,Gridp.Nx+1); 

            [Xf,Yf] = meshgrid(Grid.p.xf,Grid.p.yf);

             
            oneminusphi_sign = ones(size(phi)); oneminusphi_sign(1-phi<1e-4) = nan; 
            oneminusphi_sign = reshape(oneminusphi_sign,Grid.p.Ny,Grid.p.Nx);
            ax7 = subplot(3,3,7);
            t = sgtitle(sprintf('time=%.3f years',tTot)); t.FontSize = 20;
            cla;
            axis equal
            hold on
            contourf(X*d/1e3,Y*d/1e3,log10(D_T/d^2*abs(oneminusphi_sign.*Exx(:,2:end-1))),40,'linestyle','none'),view(2),hold on       
            
            c2 = colorbar('NorthOutside');
            %colormap(ax7,'hot');
            xlabel('x-dir, km');
            ylabel('z-dir, km');
            c2.Label.String = 'log_{10}|\epsilon_{xx}|, log_{10} 1/s';


            ax8 = subplot(3,3,8);
            t = sgtitle(sprintf('time=%.3f years',tTot)); t.FontSize = 20;
            cla;
            axis equal
            hold on
            contourf(X*d/1e3,Y*d/1e3,log10(D_T/d^2*abs(oneminusphi_sign.*Eyy(2:end-1,:))),40,'linestyle','none'),view(2),hold on         
            
            c2 = colorbar('NorthOutside');
            %colormap(ax8,'hot');
            xlabel('x-dir, km');
            ylabel('z-dir, km');
            c2.Label.String = 'log_{10}|\epsilon_{yy}|, log_{10} 1/s';

            ax8 = subplot(3,3,9);
             
            oneminusphi_sign = ones(size(ncVecPhi)); oneminusphi_sign(1-ncVecPhi<1e-4) = nan; 
            oneminusphi_sign = reshape(oneminusphi_sign,Grid.p.Ny+1,Grid.p.Nx+1);
            t = sgtitle(sprintf('time=%.3f years',tTot)); t.FontSize = 20;
            cla;
            axis equal
            hold on
            contourf(Xf*d/1e3,Yf*d/1e3,log10(D_T/d^2*abs(oneminusphi_sign.*Exy)),40,'linestyle','none'),view(2),hold on       
            
            c2 = colorbar('NorthOutside');
            %colormap(ax8,'hot');
            xlabel('x-dir, km');
            ylabel('z-dir, km');
            c2.Label.String = 'log_{10}|\epsilon_{xy}|, log_{10} 1/s';
           

%             %melt fraction plot
%             ax3 = subplot(1,3,3);
%             t = sgtitle(sprintf('time=%.3f years',tTot)); t.FontSize = 20;
%             cla;
%             axis equal
%             hold on
%             %contourf(X,Y,log10(abs(reshape(overpressure,Grid.p.Ny,Grid.p.Nx))),40,'linestyle','none'),view(2),hold on       
%             contourf(X*d/1e3,Y*d/1e3-Grid.p.dy,log10(abs(reshape(overpressure,Grid.p.Ny,Grid.p.Nx))),40,'linestyle','none'),view(2),hold on
%             c2 = colorbar('NorthOutside');
%             colormap(ax3,'hot');
%             xlabel('x-dir, km');
%             ylabel('z-dir, km');
%             c2.Label.String = 'log[Overpressure], log Pa';
%             clim([0 10])
            
            if rem(i,100)==0 || i==1

                if test == 'harmperm'                

% CHANGE NF-15 START: Keep optional legacy files inside the separate run output directory.
% CHANGE NF-15 SOURCE: original lines 787-787; see NOFLOW_BASE_CHANGES.diff.
                                save([options.output_dir filesep 'harm_perm_Europa' fn '_eta0_' num2str(log10(eta_0)) 'kc' num2str(kc) '_Ea_' num2str(E_a/1e3) '_output_' num2str(i) 'C.mat'],...
                    'overpressure','p','Exx','Eyy','Exy','Tplot','phi','Grid','phiDrain1Vec','phiDrain2Vec','phiOrig','tVec',...
                    'phiFracRem','T','phi','tVec','phiDrain1Vec','phiDrain2Vec','phiOrig','trc1','trc2')
% END CHANGE NF-15

                elseif test == 'comb_vel'

% CHANGE NF-16 START: Keep optional legacy files inside the separate run output directory.
% CHANGE NF-16 SOURCE: original lines 793-797; see NOFLOW_BASE_CHANGES.diff.
                                save([options.output_dir filesep 'combined_vel_Europa' fn '_eta0_' num2str(log10(eta_0)) 'kc' num2str(kc) '_Ea_' num2str(E_a/1e3) '_output_' num2str(i) 'C.mat'],...
                    'overpressure','p','Exx','Eyy','Exy','Tplot','phi','Grid','phiDrain1Vec','phiDrain2Vec','phiOrig','tVec',...
                    'phiFracRem','T','phi','tVec','phiDrain1Vec','phiDrain2Vec','phiOrig','trc1','trc2')
                elseif test == 'effe_vel'
                                save([options.output_dir filesep 'new_eff_vel_Europa' fn '_eta0_' num2str(log10(eta_0)) 'kc' num2str(kc) '_Ea_' num2str(E_a/1e3) '_output_' num2str(i) 'C.mat'],...
                    'overpressure','p','Exx','Eyy','Exy','Tplot','phi','Grid','phiDrain1Vec','phiDrain2Vec','phiOrig','tVec',...
                    'phiFracRem','T','phi','tVec','phiDrain1Vec','phiDrain2Vec','phiOrig','trc1','trc2')
% END CHANGE NF-16

                elseif test == 'temprate'

% CHANGE NF-17 START: Keep optional legacy files inside the separate run output directory.
% CHANGE NF-17 SOURCE: original lines 803-807; see NOFLOW_BASE_CHANGES.diff.
                                save([options.output_dir filesep 'temperate_Europa' fn '_eta0_' num2str(log10(eta_0)) 'kc' num2str(kc) '_Ea_' num2str(E_a/1e3) '_output_' num2str(i) 'C.mat'],...
                    'overpressure','p','Exx','Eyy','Exy','Tplot','phi','Grid','phiDrain1Vec','phiDrain2Vec','phiOrig','tVec',...
                    'phiFracRem','T','phi','tVec','phiDrain1Vec','phiDrain2Vec','phiOrig','trc1','trc2')
                else 
                                save([options.output_dir filesep 'original_Europa' fn '_eta0_' num2str(log10(eta_0)) 'kc' num2str(kc) '_Ea_' num2str(E_a/1e3) '_output_' num2str(i) 'C.mat'],...
                    'overpressure','p','Exx','Eyy','Exy','Tplot','phi','Grid','phiDrain1Vec','phiDrain2Vec','phiOrig','tVec',...
                    'phiFracRem','T','phi','tVec','phiDrain1Vec','phiDrain2Vec','phiOrig','trc1','trc2')
% END CHANGE NF-17

                end 
            end


                if test == 'harmperm'                
% CHANGE NF-18 START: Keep optional legacy files inside the separate run output directory.
% CHANGE NF-18 SOURCE: original lines 816-825; see NOFLOW_BASE_CHANGES.diff.
                    saveas(h,fullfile(options.output_dir,sprintf('harm_perm_Europa_res_fig%dkc%d.png',i, kc)));   
                elseif test == 'comb_vel'
                    saveas(h,fullfile(options.output_dir,sprintf('combined_vel_Europa_res_fig%dkc%d.png',i, kc)));   
                elseif test == 'temprate'
                    saveas(h,fullfile(options.output_dir,sprintf('temperate_Europa_res_fig%dkc%d.png',i, kc)));  

                elseif test == 'effe_vel'
                    saveas(h,fullfile(options.output_dir,sprintf('newer_effective_vel_Europa_res_fig%dkc%d.png',i, kc))); 
                else 
                    saveas(h,fullfile(options.output_dir,sprintf('original_Europa_res_fig%dkc%d.png',i, kc)));   
% END CHANGE NF-18

                end 

            %if i<1500
       
            %end
   
            
            % convert the image to a frame
            frameno = frameno + 1;
            FF(frameno) = getframe(gcf) ;
         end
    end
    
%%%%
% CHANGE NF-19 START: Make video generation optional and isolate the video path.
% CHANGE NF-19 SOURCE: original lines 841-841; see NOFLOW_BASE_CHANGES.diff.
if options.legacy_outputs && frameno > 0
% END CHANGE NF-19
%% Making a video out of frames
 % create the video writer with fps of the original video

 if test == 'harmperm'                
% CHANGE NF-20 START: Keep optional legacy files inside the separate run output directory.
% CHANGE NF-20 SOURCE: original lines 845-853; see NOFLOW_BASE_CHANGES.diff.
    Data_result= fullfile(options.output_dir,sprintf('harm_perm_Europa_kc_%s_t%syrs.avi',num2str(kc),num2str(tTot))); 
 elseif test == 'comb_vel'
    Data_result= fullfile(options.output_dir,sprintf('combined_vel_Europa_kc_%s_t%syrs.avi',num2str(kc),num2str(tTot)));         
 elseif test == 'temprate'
    Data_result= fullfile(options.output_dir,sprintf('temperate_Europa_kc_%s_t%syrs.avi',num2str(kc),num2str(tTot))); 
 elseif test == 'effe_vel'
    Data_result= fullfile(options.output_dir,sprintf('new_effective_vel_Europa_kc_%s_t%syrs.avi',num2str(kc),num2str(tTot))); 
 else 
    Data_result= fullfile(options.output_dir,sprintf('original_Europa_kc_%s_t%syrs.avi',num2str(kc),num2str(tTot)));  
% END CHANGE NF-20
 end 

 writerObj = VideoWriter(Data_result);
 writerObj.FrameRate = 5; % set the seconds per image
 open(writerObj); % open the video writer
% write the frames to the video
for i=1:frameno
    %'Frame number'; i
    % convert the image to a frame
    frameimg = FF(i) ;
    writeVideo(writerObj, frameimg);
end
% close the writer object
% CHANGE NF-21 START: Finalize results; add options, middle-column and sparse-operator helpers.
% CHANGE NF-21 SOURCE: original lines 867-870; see NOFLOW_BASE_CHANGES.diff.
close(writerObj);
end % optional legacy video

    if ~strcmp(result.status,'failed'), result.status = 'completed'; end
    if isfinite(options.final_years) && tTot<options.final_years-1e-10 && ~strcmp(result.status,'failed')
        result.status='step_limit';
    end
    if ~is_wave && options.stop_on_melt_loss && ~strcmp(result.status,'failed')
        result.remaining_shell_melt_fraction=phiFracRem(end);
        result.depletion_reached=phiFracRem(end)<=options.remaining_melt_fraction;
        if result.depletion_reached
            result.status='melt_depleted';
        elseif i>=options.max_steps
            result.status='step_limit'; % safety limit is not depletion completion
        else
            result.status='time_limit';
        end
    end
    result.completed_steps = i;
    result.history = result.history(1:i,:);
    if result.steps(end) ~= i
        result = nf_snapshot(result,i,tTot,T,phi,H,Grid,d,DT,T_t);
    end
    result.final_state = struct('H',H,'T_dimensionless',T,'phi',phi, ...
        'Grid',Grid,'v_s_dimensionless',vm,'v_f_dimensionless',vf, ...
        'q_r_dimensionless',qr,'p_head_dimensionless',p_head);
    result.max_base_solid_flux = max(result.history(:,7));
    result.max_base_darcy_flux = max(result.history(:,8));
    result.max_base_advective_heat_flux = max(result.history(:,9));
    result.max_base_conductive_heat_flux = max(result.history(:,10));
    result.max_top_solid_flux = max(result.history(:,14));
    result.max_top_darcy_flux = max(result.history(:,15));
    result.max_top_advective_heat_flux = max(result.history(:,16));
    result.max_top_conductive_heat_flux = max(result.history(:,17));
    result.max_boundary_solid_flux = max(result.history(:,20));
    result.max_boundary_darcy_flux = max(result.history(:,21));
    result.max_boundary_advective_heat_flux = max(result.history(:,22));
    result.max_boundary_conductive_heat_flux = max(result.history(:,23));
    result.max_enthalpy_balance_error = max(abs(result.history(:,11)));
    if ~is_wave && options.save_state_snapshots
        save_Europa_state(options.output_dir,i,tTot,tTot-dt*t_c/3.154e7, ...
            T,phi,H,Grid,d,DT,T_t,vm,vf,qr,p_head,p,overpressure,eta_0,D_T,kc,nn);
    end
    save(result.output_file,'result');
    if ~is_wave, writetable(result.melt_budget.history,fullfile(options.output_dir,'melt_budget.csv')); end
    fprintf('FINISHED no-flow kc=%g steps=%d status=%s T=[%.9g %.9g] base_phi=[%.6g %.6g] E_error=%.3g\n', ...
        kc,i,result.status,min(T)*DT+T_t,max(T)*DT+T_t, ...
        min(phi(Grid.p.dof_ymin)),max(phi(Grid.p.dof_ymin)),result.max_enthalpy_balance_error);
    
    %%%%
    
end

function options = nf_options(options)
defaults = struct('snapshot_years',[],'save_state_snapshots',false,'initial_only',false,'basal_heat_flux',0,'correct_head_reference',true,'use_actual_conductivity_timestep',true,'final_years',Inf,'snapshot_interval_years',Inf,'checkpoint_steps',100, ...
    'max_steps',1000,'snapshot_steps',[0 100 250 500 1000], ...
    'legacy_outputs',false,'evolve_tracers',false,'stop_on_melt_loss',false,'remaining_melt_fraction',0.005, ...
    'output_dir',fullfile(fileparts(mfilename('fullpath')),'..','Output','s3_minimal'));
names = fieldnames(defaults);
for k=1:numel(names)
    if ~isfield(options,names{k}), options.(names{k})=defaults.(names{k}); end
end
validateattributes(options.remaining_melt_fraction,{'numeric'},{'scalar','real','positive','<',1});
validateattributes(options.initial_only,{'logical'},{'scalar'});
validateattributes(options.basal_heat_flux,{'numeric'},{'scalar','real','finite'});
validateattributes(options.max_steps,{'numeric'},{'scalar','integer','positive'});
validateattributes(options.use_actual_conductivity_timestep,{'logical'},{'scalar'});
validateattributes(options.save_state_snapshots,{'logical'},{'scalar'});
if ~isempty(options.snapshot_years), validateattributes(options.snapshot_years,{'numeric'},{'vector','real','nonnegative','finite'}); end
options.snapshot_years=sort(unique(options.snapshot_years(:)'));
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
