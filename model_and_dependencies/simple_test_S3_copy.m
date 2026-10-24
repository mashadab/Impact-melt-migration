function result = simple_test_S3_copy(options)
% S3 exact realization with evolving enthalpy and recovered temperature.
% Derived from fixed closed-lid mechanics: sparse operators, intact mobility
% matrices, preserved pressure head, and consistently sealed Darcy faces.
% Units: length delta0, velocity w0, time delta0/w0, pressure mu*w0/delta0.
if nargin<1, options=struct(); end
root=fileparts(mfilename('fullpath'));
def=struct('max_steps',50000,'final_years',800,'dt_years',0.5, ...
    'snapshot_years',0:5:800,'initialize_only',false, ...
    'output_dir',fullfile(root,'..','Output','s3_thermal_wave'));
names=fieldnames(def);
for k=1:numel(names)
    if ~isfield(options,names{k}), options.(names{k})=def.(names{k}); end
end
validateattributes(options.max_steps,{'numeric'},{'scalar','integer','positive'});
validateattributes(options.dt_years,{'numeric'},{'scalar','positive','finite'});
validateattributes(options.final_years,{'numeric'},{'scalar','positive','finite'});
if ~isfolder(options.output_dir), mkdir(options.output_dir); end
yr=365.25*86400; phi0=1e-3; mu=1e14; k0=5.6e-11;
muf=1e-3; rho_i=917; rho_f=1000; g=9.81;
delta0=sqrt(k0*phi0^2*mu/(phi0*muf));
w0=k0*(rho_f-rho_i)*g*phi0/muf;
ts=delta0/w0;
gp=struct('xmin',0,'xmax',32,'Nx',256,'ymin',0,'ymax',128,'Ny',1024);
Grid=build_stokes_grid(gp); [X,Y]=meshgrid(Grid.p.xc,Grid.p.yc);
initdir=fullfile(root,'porosity-wave-test','MATLAB','porosity-wave-init');
raw=readmatrix(fullfile(initdir,'phi_5.csv'));
vfx=readmatrix(fullfile(initdir,'vfx_5.csv'));
% EXACT original pairing, averaging, reshape, scaling and placement.
phiodd=raw; phieven=raw;
phiodd(1:2:end-1)=[]; phieven(2:2:end)=[];
patch=mean([phiodd';phieven'],1);
patch=reshape(patch,length(vfx)-1,length(vfx)-1);
assert(isequal(size(patch),[256 256]));
phi=phi0*ones(Grid.p.Ny,Grid.p.Nx);
ind=find(Grid.p.yc>Grid.p.ymax-40);
phi(ind(1):ind(1)+256-1,:)=phi0*patch; phi=phi(:);
% Same enthalpy/phase relation as the fixed solver. Temperature is initialized
% at melting and thereafter RECOVERED from evolved H, never reset to 273 K.
T_t=100; T_b=273; DT=T_b-T_t; c_pi=185+7.037*T_b;
latent=334e3; c_pw=4186;
mixZone=rho_f*latent/(rho_i*c_pi*DT);
phi_fun=@(h) h/mixZone;
TWater_fun=@(h) h*rho_i*c_pi/(rho_f*c_pw)-latent/(DT*c_pw)+1;
T=ones(Grid.p.N,1);
H=(1-phi).*(T-1)+phi*rho_f/(rho_i*c_pi*DT).*(latent+c_pw*DT*(T-1));
initial_H_total=sum(H);
result=struct('status','initialized','options',options,'delta0_m',delta0, ...
    'w0_m_s',w0,'expected_speed_m_yr',5*w0*yr,'Grid',Grid, ...
    'initial_phi',phi,'snapshot_phi',phi,'snapshot_years',0, ...
    'x_m',Grid.p.xc*delta0,'z_m',Grid.p.yc*delta0, ...
    'history',zeros(0,10),'history_columns',{{'time_years','peak_z_m', ...
    'peak_phi','relative_melt_error','max_boundary_solid','max_boundary_darcy', ...
    'relative_linear_residual','T_min_K','T_max_K','relative_enthalpy_error'}},'completed_steps',0);
[~,peak]=max(phi); result.initial_peak_z_m=Y(peak)*delta0;
result.temperature_model='evolved enthalpy and conduction; temperature recovered by enthMelt';
result.initial_H=H;
result.temperature_K=T*DT+T_t;
result.snapshot_H=H;
result.snapshot_temperature_K=result.temperature_K;
result.output_file=fullfile(options.output_dir,'s3_wave.mat');
save(result.output_file,'result','-v7.3');
if options.initialize_only, return; end
[D,E,Dp,Gp,I,Gyy]=s3_ops(Grid);
[rows,~]=find(Gyy>0);
bnd=unique([Grid.p.dof_f_xmin;Grid.p.dof_f_xmax; ...
    Grid.p.dof_f_ymin;Grid.p.dof_f_ymax]);
% No penetration everywhere; no slip north/south; natural zero shear east/west.
fixed=unique([Grid.dof_pene;Grid.dof_ymin_vt;Grid.dof_ymax_vt;Grid.p.Nf+1]);
free=setdiff((1:Grid.N)',fixed);
ez=[zeros(Grid.p.Nfx,1);ones(Grid.p.Nfy,1)];
initial_mass=sum(phi); t=0; nextsnap=2;
run_timer=tic;
targets=unique([0 options.snapshot_years options.final_years]);
targets=targets(targets<=options.final_years);
result.status='running';
for step=1:options.max_steps
    [T,phi]=enthMelt(H,mixZone,@(h) h+1,phi_fun,TWater_fun);
    P=reshape(phi,Grid.p.Ny,Grid.p.Nx);
    % Constant intrinsic ice viscosity, effective stress weighted by ice fraction.
    ax=zeros(Grid.x.Nfx,1); ax(Grid.x.Ny+Grid.p.dof)=1-phi;
    ay=zeros(Grid.y.Nfy,1); ay(rows)=1-phi;
    ac=comp_mean_corners(1-P,-1,Grid.p);
    visc=[ax;ay;ac]; visc(~isfinite(visc))=0;
    M=spdiags(visc,0,length(visc),length(visc));
    Z=spdiags((1./phi-2/3).*(1-phi),0,Grid.p.N,Grid.p.N);
    % Arithmetic face permeability as in the original wave implementation.
    K=comp_mean(P.^2,1,1,Grid.p)/phi0;
    K(bnd,:)=0;
    facephi=comp_mean(P,1,1,Grid.p)*ones(Grid.p.Nf,1);
    rhs=[-(1-facephi).*ez;zeros(Grid.p.N,1)];
    L=[2*D*M*E+Gp*Z*Dp,-Gp;Dp,-Dp*K*Gp];
    u=zeros(Grid.N,1); u(free)=L(free,free)\rhs(free);
    res=norm(L(free,:)*u-rhs(free),inf)/max(1,norm(rhs(free),inf));
    vs=u(1:Grid.p.Nf); p_head=u(Grid.p.Nf+1:end);
    qr=-K*(Gp*p_head); qr(bnd)=0;
    % Fixed-code effective transport: total melt flux = phi*vs + qr.
    % At constant melting temperature H is proportional to phi.
    rate=abs(Dp)*abs(vs)+abs(Dp)*abs(qr)./max(phi,eps);
    % Conductive heat flux is active, with the fixed solver's mixture law.
    kappa=(1-phi)*3.3+phi*0.56;
    kface=comp_mean(reshape(kappa,Grid.p.Ny,Grid.p.Nx),-1,1,Grid.p)/(rho_i*c_pi*delta0*w0);
    kface(bnd,:)=0;
    thermal_rate=max(sum(abs(Dp)*kface*abs(Gp),2));
    dt=min([options.dt_years*yr/ts,0.4/max(rate),0.4/thermal_rate,options.final_years*yr/ts-t]);
    if nextsnap<=numel(targets)
        dt=min(dt,targets(nextsnap)*yr/ts-t);
    end
    % Effective enthalpy advection from the fixed code, including sensible
    % heat. No temperature clamping or direct update of phi is performed.
    tilde_phi=(1-phi).*(T-1)/mixZone+phi;
    assert(all(tilde_phi>0),'Effective enthalpy transport requires positive tilde_phi.');
    AH=flux_upwind(vs,Grid.p)*H+flux_upwind(qr,Grid.p)*(H./tilde_phi);
    H=H-dt*Dp*AH+dt*Dp*kface*(Gp*T);
    [T,phi]=enthMelt(H,mixZone,@(h) h+1,phi_fun,TWater_fun);
    result.temperature_K=T*DT+T_t;
    assert(all(isfinite(H)) && all(isfinite(T)) && all(result.temperature_K>0), ...
        'Nonfinite enthalpy or invalid recovered temperature.');
    assert(all(isfinite(phi)) && all(phi>0) && all(phi<1), ...
        'Invalid melt fraction; reduce dt_years. No clipping is applied.');
    t=t+dt; years=t*ts/yr;
    [peakphi,peak]=max(phi);
    result.history(end+1,:)=[years,Y(peak)*delta0,peakphi, ...
        (sum(phi)-initial_mass)/initial_mass,max(abs(vs(bnd))),max(abs(qr(bnd))),res, ...
        min(result.temperature_K),max(result.temperature_K),(sum(H)-initial_H_total)/initial_H_total];
    result.completed_steps=step;
    if nextsnap<=numel(targets) && abs(years-targets(nextsnap))<1e-7
        result.snapshot_phi(:,end+1)=phi;
        result.snapshot_temperature_K(:,end+1)=result.temperature_K;
        result.snapshot_H(:,end+1)=H;
        result.snapshot_years(end+1)=years; nextsnap=nextsnap+1;
        save(result.output_file,'result','-v7.3');
    end
    if step==1 || mod(step,20)==0
        result.checkpoint_phi=phi;
        result.checkpoint_H=H;
        result.checkpoint_temperature_K=result.temperature_K;
        result.wall_seconds=toc(run_timer);
        result.checkpoint_years=years;
        save(result.output_file,'result','-v7.3');
        fprintf('S3 step=%d t=%.6f yr peak=%.6f melt_error=%.3g residual=%.3g T=[%.12g %.12g] H_error=%.3g wall=%.1fs\n', ...
            step,years,peakphi,result.history(end,4),res, ...
            result.history(end,8),result.history(end,9),result.history(end,10),toc(run_timer));
    end
    if years>=options.final_years-1e-8, break; end
end
result.final_phi=phi;
result.final_H=H;
result.final_temperature_K=result.temperature_K;
result.final_flow=struct('v_s',vs,'q_r',qr,'p_head',p_head, ...
    'state_time_years',years-dt*ts/yr);
result.status='step_limit';
if years>=options.final_years-1e-8, result.status='completed'; end
if abs(result.snapshot_years(end)-years)>1e-8
    result.snapshot_phi(:,end+1)=phi;
        result.snapshot_temperature_K(:,end+1)=result.temperature_K;
        result.snapshot_H(:,end+1)=H; result.snapshot_years(end+1)=years;
end
save(result.output_file,'result','-v7.3');
end

function [D,E,Dp,Gp,I,Gyy]=s3_ops(Grid)
% Sparse Cartesian form of the fixed solver's staggered operators.
[Dx,Gx,~]=build_ops(Grid.x); [Dy,Gy,~]=build_ops(Grid.y);
[Dp,Gp,~]=build_ops(Grid.p);
Dxx=Dx(:,1:Grid.x.Nfx); Dxy=Dx(:,Grid.x.Nfx+1:Grid.x.Nf);
Dyx=Dy(:,1:Grid.y.Nfx); Dyy=Dy(:,Grid.y.Nfx+1:Grid.y.Nf);
Gxx=Gx(1:Grid.x.Nfx,:); Gxy=Gx(Grid.x.Nfx+1:Grid.x.Nf,:);
Gyx=Gy(1:Grid.y.Nfx,:); Gyy=Gy(Grid.y.Nfx+1:Grid.y.Nf,:);
E=[Gxx,sparse(Grid.x.Nfx,Grid.y.N);sparse(Grid.y.Nfy,Grid.x.N),Gyy;.5*Gxy,.5*Gyx];
D=[Dxx,sparse(Grid.x.N,Grid.y.Nfy),Dxy;sparse(Grid.y.N,Grid.x.Nfx),Dyy,Dyx];
I=speye(Grid.N);
end
