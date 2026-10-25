function audit_Europa_regularization(reuse_saved_flows)
% Isolated frozen-state flow sweeps and a manufactured dry-front advection test.
% The production solver and all research-run files remain unchanged.
if nargin<1,reuse_saved_flows=false;end
root=fileparts(mfilename('fullpath'));addpath(root);
project=fileparts(root);
out=fullfile(project,'Output','Europa_regularization_audit_20261024');
scratch=fullfile(project,'tmp','Europa_regularization_audit');
if ~isfolder(out),mkdir(out);end
if ~isfolder(scratch),mkdir(scratch);end
diary(fullfile(out,'audit.log'));cleanup=onCleanup(@() diary('off')); %#ok<NASGU>
source=fileread(fullfile(root,'darcy_stokes_2D_cases.m'));
high=fullfile(project,'Output','Europa_kc_1.850e-08_until_depleted_20261023_195524');
low=fullfile(project,'Output','Europa_kc_1.850e-16_until_depleted_20261024_085440');
assert(strcmp(source,fileread(fullfile(high,'source','darcy_stokes_2D_cases.m'))));
assert(strcmp(source,fileread(fullfile(low,'source','darcy_stokes_2D_cases.m'))));
modified=strrep(source,'function result = darcy_stokes_2D_cases(', ...
    'function result = audit_darcy_stokes_2D_cases(');
% Keep every input and helper path rooted at the original solver directory.
modified=strrep(modified,"fileparts(mfilename('fullpath'))", ...
    ['''' strrep(root,'''','''''') '''']);
needle='    run_timer = tic;';assert(count(modified,needle)==1);
replacement=sprintf(['    audit_start=load(options.audit_state_path,''state'');\n' ...
    '    H=audit_start.state.enthalpy_dimensionless(:);\n%s'],needle);
modified=strrep(modified,needle,replacement);
needle='        % Adaptive time stepping based on competition b/w CFL and Neumann';
assert(count(modified,needle)==1);
capture=sprintf(['        audit_data=struct(''tau'',tau,''Gp'',Gp,''Dp'',Dp,''phi'',phi,''T'',T,''Zd'',Zd, ...\n' ...
    '            ''intrinsic_eta'',ViscTempPhi(Tplot(:),phi), ...\n' ...
    '            ''Pi1'',Pi_1,''K'',Kdprime,''fs'',fs,''B'',B,''g'',Param.g,''N'',N, ...\n' ...
    '            ''eta0'',eta_0,''DThermal'',D_T,''d'',d,''Grid'',Grid,''u'',u, ...\n' ...
    '            ''qr'',qr,''overpressure'',overpressure,''options'',options);\n' ...
    '        result=options.audit_callback(audit_data);\n' ...
    '        save(fullfile(options.output_dir,''frozen_flow_sweep.mat''),''result'',''-v7.3'');\n' ...
    '        return; %% AUDIT ONLY: no thermal advance or long simulation\n\n%s'],needle);
modified=strrep(modified,needle,capture);
fid=fopen(fullfile(scratch,'audit_darcy_stokes_2D_cases.m'),'w');fprintf(fid,'%s',modified);fclose(fid);
fid=fopen(fullfile(scratch,'production_source_used.m.txt'),'w');fprintf(fid,'%s',source);fclose(fid);
addpath(scratch);clear audit_darcy_stokes_2D_cases
cases={ 'high_initial',high,0,1.85e-8; 'high_main',high,8091,1.85e-8; ...
        'low_initial',low,0,1.85e-16; 'low_main',low,11622,1.85e-16};
results=struct;
for j=1:size(cases,1)
    label=cases{j,1};caseout=fullfile(out,label);if ~isfolder(caseout),mkdir(caseout);end
    options=struct('max_steps',1,'output_dir',caseout,'save_state_snapshots',false, ...
        'legacy_outputs',false,'evolve_tracers',false,'audit_callback',@capture_flow, ...
        'audit_state_path',fullfile(cases{j,2},'states',sprintf('state_%08d.mat',cases{j,3})), ...
        'audit_label',label,'audit_reference_run',cases{j,2},'audit_input_step',cases{j,3});
    cached=fullfile(caseout,'frozen_flow_sweep.mat');
    if reuse_saved_flows && isfile(cached)
        prior=load(cached,'result');
        assert(strcmp(prior.result.input_state,options.audit_state_path));
        assert(isfield(prior.result,'zero_Darcy_incompressible_control'));
        assert(isfield(prior.result.sweep,'normwise_free_equation_backward_error'));
        results.(label)=prior.result;
        fprintf('REUSED_COMPLETED_FROZEN_FLOW_AUDIT %s\n',label);
    else
        fprintf('START_FROZEN_FLOW_AUDIT %s\n',label);
        results.(label)=audit_darcy_stokes_2D_cases('impact_melt_europa','03321',1e14,50e3,cases{j,4},'effe_vel','case_setup',options);
        fprintf('END_FROZEN_FLOW_AUDIT %s\n',label);
    end
end
results.transport=transport_test(out);
results.scope='Frozen-state flow sensitivity, not reruns of either trajectory; controlled advection benchmark, not full coupled grid convergence.';
fid=fopen(fullfile(out,'regularization_audit.json'),'w');fprintf(fid,'%s',jsonencode(results));fclose(fid);
assert(strcmp(source,fileread(fullfile(root,'darcy_stokes_2D_cases.m'))));
fprintf('REGULARIZATION_AUDIT_COMPLETE %s\n',fullfile(out,'regularization_audit.json'));
end

function result=capture_flow(a)
epsilons=[1e-3 1e-5 1e-7 1e-9];
eta=a.intrinsic_eta;
[basewm,basewi]=lastwarn;
basev=a.u(1:a.Grid.p.Nf);baseq=a.qr;
vscale=a.DThermal/a.d;pscale=a.eta0*a.DThermal/a.d^2;
dry=a.phi==0;dry_face=false(a.Grid.p.Nf,1);
nx=a.Grid.p.Nx;ny=a.Grid.p.Ny;d2=reshape(dry,ny,nx);
mx=false(ny,nx+1);mz=false(ny+1,nx);
mx(:,2:nx)=d2(:,1:end-1)|d2(:,2:end);
mz(2:ny,:)=d2(1:end-1,:)|d2(2:end,:);dry_face(:)=[mx(:);mz(:)];
div0=a.Dp*basev;
% Phase-weighted bulk stress, not the phase pressure difference p_water-p_ice.
% The latter divides this value by (1-phi), where both phases exist.
consistent=(1-a.phi)./(a.phi+1e-5).*eta.*div0*pscale;
raw=eta./(a.phi+1e-15).*div0*pscale;
assert(max(abs(raw-a.overpressure))<=1e-12*max(1,max(abs(raw))));
result=struct('input_step',a.options.audit_input_step, ...
    'input_state',a.options.audit_state_path,'input_time_years',NaN, ...
    'legacy_dry_overpressure_max_abs_Pa',max(abs(raw(dry))), ...
    'same_flow_regularized_bulk_stress_dry_max_abs_Pa',max(abs(consistent(dry))), ...
    'legacy_overpressure_reconstruction_relative_error',norm(raw-a.overpressure)/max(norm(raw),realmin));
initial=load(a.options.audit_state_path,'state');result.input_time_years=initial.state.time_years;
if a.options.audit_input_step==0
    s=load(fullfile(a.options.audit_reference_run,'states','state_00000001.mat'),'state');
    rv=s.state.solid_velocity_m_s(:)/vscale;rq=s.state.darcy_flux_m_s(:)/vscale;
    result.baseline_solid_relative_difference_from_saved_first_flow=norm(basev-rv)/max(norm(rv),realmin);
    result.baseline_Darcy_relative_difference_from_saved_first_flow=norm(baseq-rq)/max(norm(rq),realmin);
    assert(result.baseline_solid_relative_difference_from_saved_first_flow<1e-10);
    assert(result.baseline_Darcy_relative_difference_from_saved_first_flow<1e-10);
    [~,ir]=min(abs(a.Grid.p.xc*a.d-1300));[~,iz]=min(abs(a.Grid.p.yc*a.d-8750));
    ids=[(ir-1)*ny+iz;ir*ny+iz;a.Grid.p.Nfx+(ir-1)*(ny+1)+iz;a.Grid.p.Nfx+(ir-1)*(ny+1)+iz+1];
    adv=flux_upwind(basev,a.Grid.p)*a.phi;
    result.example_cell=struct('r_m',a.Grid.p.xc(ir)*a.d,'z_m',a.Grid.p.yc(iz)*a.d, ...
        'phi',a.phi((ir-1)*ny+iz),'face_order',{{'left','right','bottom','top'}}, ...
        'solid_velocity_m_per_year',basev(ids)*vscale*3.154e7, ...
        'Darcy_flux_m_per_s',baseq(ids)*vscale, ...
        'upwind_phi',adv(ids)./basev(ids), ...
        'liquid_carried_flux_m_per_year',adv(ids)*vscale*3.154e7);
end
rows=struct([]);
for j=1:numel(epsilons)
    ep=epsilons(j);Zd=spdiags(((1-a.phi)./(a.phi+ep)-2/3*(1-a.phi)).*eta,0,numel(a.phi),numel(a.phi));
    if ep==1e-5,Zd=a.Zd;end
    L=[a.tau+a.Gp*Zd*a.Dp,-a.Gp; a.Dp,-a.Dp*a.Pi1*a.K*a.Gp];
    lastwarn('');started=tic;
    if ep==1e-5,u=a.u;else,u=solve_lbvp(L,a.fs,a.B,a.g,a.N);end
    [wm,wi]=lastwarn;if ep==1e-5,wm=basewm;wi=basewi;end
    v=u(1:a.Grid.p.Nf);p=u(a.Grid.p.Nf+1:end);q=-a.Pi1*a.K*(a.Gp*p);
    residual=a.N'*(L*u-a.fs);
    denominator=abs(a.N')*(abs(L)*abs(u)+abs(a.fs));
    mass=a.Dp*(v+q);massden=abs(a.Dp)*(abs(v)+abs(q));
    row=struct('epsilon',ep,'seconds',toc(started),'all_finite',all(isfinite(u)), ...
        'solid_L2_relative_difference_from_baseline',norm(v-basev)/max(norm(basev),realmin), ...
        'Darcy_L2_relative_difference_from_baseline',norm(q-baseq)/max(norm(baseq),realmin), ...
        'max_solid_speed_m_per_year',max(abs(v))*vscale*3.154e7, ...
        'max_solid_speed_on_dry_adjacent_faces_m_per_year',max(abs(v(dry_face)))*vscale*3.154e7, ...
        'max_Darcy_speed_on_dry_adjacent_faces_m_per_s',max(abs(q(dry_face)))*vscale, ...
        'max_dry_solid_divergence_per_s',max(abs(a.Dp(dry,:)*v))*a.DThermal/a.d^2, ...
        'max_mass_residual_per_s',max(abs(mass))*a.DThermal/a.d^2, ...
        'mass_residual_relative_to_max_face_throughput',max(abs(mass))/max(max(massden),realmin), ...
        'componentwise_free_equation_backward_error',max(abs(residual)./max(denominator,realmin)), ...
        'normwise_free_equation_backward_error',max(abs(residual))/max(max(denominator),realmin), ...
        'warning_id',wi,'warning_message',wm);
    if j==1,rows=row;else,rows(j)=row;end %#ok<AGROW>
    fprintf('EPSILON_SWEEP %s %s\n',a.options.audit_label,jsonencode(row));
end
result.sweep=rows;
% Exact zero-Darcy incompressible Stokes limit: no permeability term and no
% compaction-viscosity term or regularization anywhere in this control.
L0=[a.tau,-a.Gp;a.Dp,sparse(numel(a.phi),numel(a.phi))];
lastwarn('');u0=solve_lbvp(L0,a.fs,a.B,a.g,a.N);[wm,wi]=lastwarn;
v0=u0(1:a.Grid.p.Nf);
result.zero_Darcy_incompressible_control=struct( ...
    'all_finite',all(isfinite(u0)), ...
    'max_solid_speed_on_dry_adjacent_faces_m_per_year',max(abs(v0(dry_face)))*vscale*3.154e7, ...
    'max_divergence_per_s',max(abs(a.Dp*v0))*a.DThermal/a.d^2, ...
    'solid_L2_relative_difference_from_baseline',norm(v0-basev)/max(norm(basev),realmin), ...
    'Darcy_flux_m_per_s',0,'compaction_regularization','absent', ...
    'warning_id',wi,'warning_message',wm);
fprintf('ZERO_DARCY_CONTROL %s %s\n',a.options.audit_label,jsonencode(result.zero_Darcy_incompressible_control));
end

function result=transport_test(out)
% Exact cell-average translation of a top-hat in a prescribed incompressible
% velocity. No Darcy flow, phase source, heat conduction, or interpolation.
nys=[120 240 480];cfls=[.4 .4 .4 .2 .8];nys=[nys 120 120];
phi0=.2;speed=-10;duration=100;lower=4000;upper=6000;
rows=struct([]);profiles=cell(1,3);
for k=1:numel(nys)
    gp=struct('xmin',0,'xmax',600,'Nx',3,'ymin',0,'ymax',12000,'Ny',nys(k),'geom','cylindrical_rz');
    grid=build_grid(gp);[D,G,~]=build_ops(grid);
    z=grid.yc;dz=grid.dy;
    exact_average=@(lo,hi) phi0*max(0,min(z+dz/2,hi)-max(z-dz/2,lo))/dz;
    start=exact_average(lower,upper);phi=repmat(start,grid.Nx,1);
    H=phi;v=[zeros(grid.Nfx,1);speed*ones(grid.Nfy,1)];q=zeros(size(v));
    dt=cfls(k)*dz/abs(speed);steps=ceil(duration/dt);
    initial=sum(phi.*grid.V);
    for n=1:steps
        stepdt=min(dt,duration-(n-1)*dt);
        Ae=build_adv_op(v,H,stepdt,G,grid,struct,'gd');
        % This checks the sparse H=0, tilde_phi=0 path as implemented too.
        Aq=build_adv_op(q,1./phi,stepdt,G,grid,struct,'gd')*spdiags(1./phi,0,grid.N,grid.N);
        AH=(Ae+Aq)*H;assert(all(isfinite(AH)));
        H=H-stepdt*D*AH;phi=H;
    end
    shifted_lower=lower+speed*duration;shifted_upper=upper+speed*duration;
    exact=exact_average(shifted_lower,shifted_upper);numeric=phi(1:grid.Ny);
    L1=sum(abs(numeric-exact))*dz;
    % Cells wholly ahead of the exact support avoid classifying partial cells.
    ahead=z+dz/2<=shifted_lower;
    tail=find(numeric>=.01*phi0,1,'first');
    row=struct('dz_m',dz,'CFL',cfls(k),'last_step_CFL',stepdt*abs(speed)/dz,'steps',steps, ...
        'absolute_L1_error_m',L1,'L1_error_over_exact_integral',L1/(phi0*(upper-lower)), ...
        'relative_liquid_volume_error',(sum(phi.*grid.V)-initial)/initial, ...
        'liquid_ahead_of_exact_front_m_per_unit_area',sum(numeric(ahead))*dz, ...
        'one_percent_tail_ahead_of_exact_front_m',max(0,shifted_lower-(z(tail)-dz/2)), ...
        'Darcy_flux_m_per_year',0,'compaction_rate_per_year',max(abs(D*v)));
    if k==1,rows=row;else,rows(k)=row;end %#ok<AGROW>
    fprintf('DRY_FRONT_TRANSPORT %s\n',jsonencode(row));
    if k<=3,profiles{k}=struct('z',z,'phi',numeric,'exact',exact);end
end
result=struct('definition','Prescribed vertical velocity -10 m/year, initial phi=0.2 top-hat from z=4 to 6 km, transported for 100 years; exact cell averages, no interpolation.', ...
    'scope','Transport-operator benchmark only; not a coupled Europa trajectory convergence study.','results',rows);
f=figure('Visible','off','Color','w','Position',[30 30 1250 660]);
ax=axes(f);hold(ax,'on');colors=lines(3);hh=gobjects(4,1);
for k=1:3
    a=profiles{k};hh(k)=stairs(ax,(a.z-a.z(2)/2+a.z(1)/2)/1000,a.phi, ...
        'LineWidth',1.8,'Color',colors(k,:));
end
hh(4)=plot(ax,[2 3 3 5 5 6],[0 0 phi0 phi0 0 0],'k--','LineWidth',1.8);
xlim(ax,[2.3 5.7]);ylim(ax,[-.005 .215]);set(ax,'XGrid','on','YGrid','on');
xlabel(ax,'Elevation z [km]');ylabel(ax,'Liquid fraction');
title(ax,'Dry-front transport audit: spreading with zero Darcy flux');
legend(ax,hh,{'dz = 100 m','dz = 50 m','dz = 25 m','Exact translated front'},'Location','south');
subtitle(ax,{'Same Godunov transport operator; prescribed velocity -10 m/year; t = 100 years; CFL = 0.4.', ...
    'No conduction or melting source. Profiles show computed cell averages; no interpolation.'});
exportgraphics(f,fullfile(out,'dry_front_transport_resolution.png'),'Resolution',160);close(f);
end
