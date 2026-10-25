"""Generate an archived restartable driver without changing model physics."""
from pathlib import Path
import hashlib
import difflib
import json
from datetime import datetime
from zoneinfo import ZoneInfo

root=Path(__file__).resolve().parents[1]
model=root/'model_and_dependencies'
previous=Path((root/'tmp/centered_blob_output.txt').read_text(encoding='utf-8-sig').strip())
stamp=datetime.now(ZoneInfo('America/New_York')).strftime('%Y%m%d_%H%M%S')
out=root/'Output'/('centered_blob_continuation_'+stamp)
source_dir=out/'source';source_dir.mkdir(parents=True)
parent=model/'simple_test_1D_centered_blob_closed.m'
source=parent.read_text(encoding='utf-8');driver=source
def one(old,new):
    global driver
    assert driver.count(old)==1,old[:100]
    driver=driver.replace(old,new,1)
one('function result = simple_test_1D_centered_blob_closed(',
    'function result = centered_blob_continuation_driver(')
one("fp = fullfile(fileparts(mfilename('fullpath')),'..','initial_conditions','ic');",
    "fp = fullfile('"+root.as_posix()+"','initial_conditions','ic');")
one('    run_timer = tic;',"""    % CONTINUATION: restore only evolving state and output history.
    start_step=0;
    if isfield(options,'restart_file') && ~isempty(options.restart_file)
        loaded=load(options.restart_file,'result');prior=loaded.result;
        assert(prior.kc==kc && isequal(prior.mesh,[Grid.p.Nx Grid.p.Ny]));
        start_step=prior.completed_steps;H=prior.final_state.H;
        T=prior.final_state.T_dimensionless;phi=prior.final_state.phi;
        tTot=prior.time_years(end);
        result.history(1:start_step,:)=prior.history(1:start_step,:);
        for key={'steps','time_years','T_K','phi','H','initial_enthalpy_total'}
            result.(key{1})=prior.(key{1});
        end
        result.completed_steps=start_step;
    end
    half_save_years=[.01 .05 .1 .25 .5 .75 options.final_years];
    run_timer=tic;
""")
one('    for i = 1:options.max_steps','    for i = start_step+1:options.max_steps')
one('        H = porNonH_fun(phi,T);\n        %% Bouyancy force',
    '        H = porNonH_fun(phi,T);\n        diagnostic_H0=H;diagnostic_T0=T;diagnostic_phi0=phi;diagnostic_flow_time=tTot;\n        %% Bouyancy force')
one('        %% non-linear thermal conducitivity matricies',
    "        dt=min(dt,max(0,options.final_years-tTot)*3.154e7/t_c); % CONTINUATION final-time cap\n        %% non-linear thermal conducitivity matricies")
needle='% CHANGE NF-11 START: Make passive-tracer updates optional; disabled for these column tests.'
one(needle,"""        % CONTINUATION: read-only decomposition of this actual update.
        diagnostic=centered_blob_diagnostics(Grid,d,D_T,t_c,dt, ...
            diagnostic_H0,diagnostic_T0,diagnostic_phi0,H,T,phi,vm,qr,p_head, ...
            Kdprime,kappaFace,Ae,Aq,Pi_6);
"""+needle)
one('        if i==1 || mod(i,50)==0',"""        stop_requested=isfile(fullfile(options.output_dir,'STOP_REQUESTED'));
        reached_time=tTot>=options.final_years-8*eps(max(1,options.final_years));
        diagnostic.row.step=i;diagnostic.row.flow_time_years=diagnostic_flow_time;
        diagnostic.row.time_years=tTot;diagnostic.row.dt_years=dt*t_c/3.154e7;
        diagnostic.row.relative_enthalpy_error=energy_error/result.initial_enthalpy_total;
        if i==start_step+1
            csv_names=fieldnames(diagnostic.row);
            diagnostic_fid=fopen(fullfile(options.output_dir,'diagnostics.csv'),'w');
            fprintf(diagnostic_fid,'%s\\n',strjoin(csv_names,','));fclose(diagnostic_fid);
        end
        csv_values=cellfun(@(key)diagnostic.row.(key),csv_names);
        diagnostic_fid=fopen(fullfile(options.output_dir,'diagnostics.csv'),'a');
        fprintf(diagnostic_fid,'%.17g',csv_values(1));fprintf(diagnostic_fid,',%.17g',csv_values(2:end));
        fprintf(diagnostic_fid,'\\n');fclose(diagnostic_fid);
        if i==start_step+1 || mod(i,50)==0 || stop_requested || reached_time
            progress=diagnostic.row;progress.status='running';progress.target_years=options.final_years;
            progress.wall_seconds=toc(run_timer);progress.resumed_from_step=start_step;
            diagnostic_fid=fopen(fullfile(options.output_dir,'progress.tmp.json'),'w');
            fprintf(diagnostic_fid,'%s',jsonencode(progress));fclose(diagnostic_fid);
            movefile(fullfile(options.output_dir,'progress.tmp.json'),fullfile(options.output_dir,'progress.json'),'f');
        end
        if i==start_step+1 || mod(i,50)==0""")
one('        if any(i==options.snapshot_steps)',"""        milestone=any(half_save_years>diagnostic_flow_time & half_save_years<=tTot);
        if any(i==options.snapshot_steps) || mod(i,options.save_every_steps)==0 || milestone || reached_time || stop_requested""")
one("            save(result.output_file,'result');","""            result.completed_steps=i;
            checkpoint=struct('step',i,'time_years',tTot,'flow_time_years',diagnostic_flow_time, ...
                'H',H,'T_dimensionless',T,'phi',phi,'Grid',Grid,'d_m',d,'dt_years',dt*t_c/3.154e7, ...
                'solid_velocity_m_s',vm*D_T/d,'darcy_flux_m_s',qr*D_T/d, ...
                'pressure_head_dimensionless',p_head,'diagnostic',diagnostic);
            checkpoint_path=fullfile(options.output_dir,'states',sprintf('state_%08d.mat',i));
            save(checkpoint_path,'checkpoint');
            save(result.output_file,'result');""")
one('        % condition for ending simulation',
    '        if stop_requested || reached_time,break;end % CONTINUATION control only\n\n        % condition for ending simulation')
one("    if ~strcmp(result.status,'failed'), result.status = 'completed'; end","""    if ~strcmp(result.status,'failed')
        if stop_requested,result.status='stopped_by_user';
        elseif reached_time,result.status='completed';else,result.status='step_limit';end
    end
    result.target_years=options.final_years;result.wall_seconds=toc(run_timer);""")
(source_dir/'centered_blob_continuation_driver.m').write_text(driver,encoding='utf-8',newline='\n')
(source_dir/'parent_solver_used.m.txt').write_text(source,encoding='utf-8')
(source_dir/'continuation_changes.diff').write_text(''.join(difflib.unified_diff(
 source.splitlines(True),driver.splitlines(True),fromfile=parent.name,tofile='centered_blob_continuation_driver.m')),encoding='utf-8')
helpers=['centered_blob_diagnostics.m','enthMelt.m','barrViscPhase.m','build_grid.m',
 'build_stokes_grid_cyl.m','build_ops.m','build_bnd.m','solve_lbvp.m','comp_mean.m',
 'comp_mean_corners.m','flux_upwind.m','build_adv_op.m','smoothness.m','comp_limiter.m']
for name in helpers:(source_dir/name).write_bytes((model/name).read_bytes())
config={'target_years':1,'kc':1.85e-8,'restart_run':str(previous),
 'restart_file':str(previous/'noflow_kc_1.850e-08.mat'),'output_dir':str(out),
 'parent_sha256':hashlib.sha256(parent.read_bytes()).hexdigest(),
 'driver_sha256':hashlib.sha256((source_dir/'centered_blob_continuation_driver.m').read_bytes()).hexdigest(),
 'physical_changes':'none; restart, diagnostics, checkpoints, final-time cap and graceful stop only',
 'save_every_steps':250,'progress_every_steps':50,
 'graceful_stop_file':str(out/'STOP_REQUESTED')}
(out/'configuration.json').write_text(json.dumps(config,indent=2),encoding='utf-8')
(root/'tmp/centered_continuation_output.txt').write_text(str(out),encoding='utf-8')
print(json.dumps(config,indent=2))
