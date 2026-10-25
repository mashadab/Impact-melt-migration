from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import difflib
import hashlib
import json
import shutil

root=Path(__file__).resolve().parents[1]
code=root/'model_and_dependencies'
parent=code/'darcy_stokes_2D_cases.m'
baseline_sha=hashlib.sha256(parent.read_bytes()).hexdigest()
assert baseline_sha=='16dcab8b484d6751dfdb263fccd546a5c72bc40d03519e8d6eab2ed4bcc7f667',baseline_sha
before=parent.read_text()
after=before
replacements=[
 ('function result = darcy_stokes_2D_cases(case_key,fn,eta_0,E_a,kc,test,simple_test,options)',
  'function result = darcy_stokes_2D_centered_cold_bottom_S3(case_key,fn,eta_0,E_a,kc,test,simple_test,options)'),
 ("    case_key = validatestring(case_key,{'porosity_wave','impact_melt_europa','centered_water'});",
  "    assert(strcmp(case_key,'centered_water'),'This separate copy is only for the cold-bottom centered test.');\n"
  "    case_key = validatestring(case_key,{'porosity_wave','impact_melt_europa','centered_water'});"),
 ('    TGr=ones(size(X)); % 273 K everywhere, initial condition only',
  '    TGr=ones(size(X)); % upper half: original 273 K, initial condition only\n'
  '    TGr(Y<=(Grid.p.ymin+Grid.p.ymax)/2)=(253.15-T_t)/DT; % ONLY physical setup change: bottom half -20 C'),
 ('    result.case_key = case_key;',
  "    result.case_key = case_key;\n    result.test_variant='centered_water_cold_bottom';\n    result.initial_bottom_temperature_K=253.15;"),
 ('    stop_requested=false;',
  '    stop_requested=false;\n    cold_budget=[]; % read-only cumulative thermal accounting'),
 ('            diagnostic.permeability_m2=full(diag(Kdprime))*kc;',
  '            diagnostic.permeability_m2=full(diag(Kdprime))*kc;\n'
  '            [diagnostic,cold_budget]=centered_cold_bottom_heat_budget(diagnostic,Grid,d,cold_budget);'),
 ('                diagnostic,T,Grid,d,energy_error,result.initial_enthalpy_total,result.steps(end)==i);',
  '                diagnostic,T,Grid,d,energy_error,result.initial_enthalpy_total, ...\n'
  '                result.steps(end)==i || diagnostic.cold_bottom.first_new_liquid);'),
]
for old,new in replacements:
 assert after.count(old)==1,old
 after=after.replace(old,new)
start='        %% Bouyancy force as the body force to Stokes flow'
end='        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5'
block=lambda s:s[s.index(start):s.index(end)+len(end)]
assert block(before)==block(after)
assert before[before.index('function [D,Edot,'):] == after[after.index('function [D,Edot,'):]
variant=code/'darcy_stokes_2D_centered_cold_bottom_S3.m'
assert not variant.exists(),'Variant exists; inspect before replacing.'
variant.write_text(after,newline='\n')
stamp=datetime.now(ZoneInfo('America/New_York')).strftime('%Y%m%d_%H%M%S')
launch=root/'tmp'/('centered_cold_bottom_'+stamp)
frozen=launch/'source';frozen.mkdir(parents=True)
names=['darcy_stokes_2D_centered_cold_bottom_S3.m','run_centered_water_cold_bottom_S3.m',
 'centered_cold_bottom_heat_budget.m','record_centered_water_step.m','centered_blob_diagnostics.m',
 'build_stokes_grid_cyl.m','build_grid.m','build_ops.m','build_bnd.m','solve_lbvp.m',
 'comp_mean.m','comp_mean_corners.m','barrViscPhase.m','enthMelt.m','flux_upwind.m',
 'build_adv_op.m','smoothness.m','comp_limiter.m']
for name in names:shutil.copy2(code/name,frozen/name)
out=root/'Output'/('centered_cold_bottom_S3_100yr_'+stamp)
diff=''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),
 fromfile='corrected_shared_centered_S3_baseline',tofile=variant.name))
(frozen/'minimal_changes.diff').write_text(diff)
shutil.copy2(parent,frozen/'baseline_shared_solver.m.txt')
hashes={n:hashlib.sha256((frozen/n).read_bytes()).hexdigest() for n in names}
(frozen/'source_hashes.json').write_text(json.dumps(hashes,indent=2))
config=dict(output_dir=str(out),frozen_source_dir=str(frozen),target_years=100,max_steps=200000,
 previous_warm_centered_run=str(root/'Output/centered_water_S3_100yr_20261024_214605'),
 baseline_shared_sha256=baseline_sha,flow_heat_phase_block_identical=True,stokes_helper_identical=True,
 actual_solver=variant.name,kc_m2=1.85e-8,permeability_exponent=3,
 cold_bottom=dict(temperature_K=253.15,temperature_C=-20,z_range_m=[-2000,4000]),
 upper_temperature_K=273,domain_x_m=[0,20000],domain_z_m=[-2000,10000],mesh=[100,120],
 initialization_change_only=True,closed_and_insulated=True,
 diagnostics='Every-step Eulerian heat contributions, cumulative cell budgets, liquid import, effective net refreezing, term-omission fields on the same frozen step.',
 limitations='Same original material/rheology/thermal laws; model melting point remains 273 K; fixed-grid warming is not a material-parcel history; no data interpolation.')
(frozen/'configuration.json').write_text(json.dumps(config,indent=2))
starter=f"""addpath('{frozen.as_posix()}','-begin');
assert(strcmp(strrep(which('darcy_stokes_2D_centered_cold_bottom_S3'),'\\','/'),'{(frozen/variant.name).as_posix()}'));
for file={{'darcy_stokes_2D_centered_cold_bottom_S3.m','run_centered_water_cold_bottom_S3.m','centered_cold_bottom_heat_budget.m'}}
 messages=checkcode(fullfile('{frozen.as_posix()}',file{{1}}),'-id');
 assert(~any(strcmp({{messages.id}},'PARSE')),'MATLAB parse error in %s',file{{1}});
end
try
 result=run_centered_water_cold_bottom_S3(100,'{out.as_posix()}');
catch exception
 out='{out.as_posix()}';if ~isfolder(out),mkdir(out);end
 record=struct('status','failed','message',exception.message,'report',getReport(exception,'extended','hyperlinks','off'));
 fid=fopen(fullfile(out,'error.json'),'w');fprintf(fid,'%s',jsonencode(record));fclose(fid);
 rethrow(exception)
end
"""
(launch/'start_cold_bottom.m').write_text(starter)
(root/'tmp/centered_cold_bottom_output.txt').write_text(str(out))
(root/'tmp/centered_cold_bottom_launcher.txt').write_text(str(launch/'start_cold_bottom.m'))
(root/'docs/CENTERED_COLD_BOTTOM_S3.diff').write_text(diff)
print(json.dumps(dict(output_dir=str(out),launcher=str(launch/'start_cold_bottom.m'),
 baseline_sha256=baseline_sha,variant_sha256=hashes[variant.name],flow_heat_phase_block_identical=True),indent=2))
