from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[1]
model = root / 'model_and_dependencies'
stamp = datetime.now(ZoneInfo('America/New_York')).strftime('%Y%m%d_%H%M%S')
launch = root / 'tmp' / ('centered_water_100yr_' + stamp)
frozen = launch / 'source'
frozen.mkdir(parents=True)
out = root / 'Output' / ('centered_water_S3_100yr_' + stamp)
assert not out.exists()
provenance = json.loads((root / 'docs/CENTERED_WATER_S3_PROVENANCE.json').read_text())
assert provenance['verification']['passed']
names = ['darcy_stokes_2D_cases.m','run_darcy_stokes_case.m','run_centered_water_S3.m',
 'record_centered_water_step.m','centered_blob_diagnostics.m','build_stokes_grid_cyl.m',
 'build_grid.m','build_ops.m','build_bnd.m','solve_lbvp.m','comp_mean.m',
 'comp_mean_corners.m','barrViscPhase.m','enthMelt.m','flux_upwind.m',
 'build_adv_op.m','smoothness.m','comp_limiter.m','plot_centered_water_S3.m']
hashes = {}
for name in names:
    source = model / name
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    expected = provenance['archived_source_files'].get(name)
    if expected:
        assert digest == expected, f'Changed since verification: {name}'
    shutil.copy2(source, frozen / name)
    hashes[name] = digest
config = dict(target_years=100,case_key='centered_water',kc_m2=1.85e-8,
 permeability_exponent=3,correct_head_reference=True,
 use_actual_conductivity_timestep=True,initialization='fresh original centered-water initial condition',
 output_dir=str(out),frozen_source_dir=str(frozen),source_sha256=hashes,
 scalar_diagnostics='every step',full_state='early steps, ~0.1-year intervals, every 250 steps, final or stop',
 graceful_stop_file=str(out/'STOP_REQUESTED'))
(launch / 'configuration.json').write_text(json.dumps(config,indent=2))
matlab = f"""addpath('{frozen.as_posix()}','-begin');
out='{out.as_posix()}';
expected='{(frozen/'darcy_stokes_2D_cases.m').as_posix()}';
assert(strcmp(strrep(which('darcy_stokes_2D_cases'),'\\','/'),expected));
try
 result=run_centered_water_S3(100,out);
 copyfile('{(launch/'configuration.json').as_posix()}',fullfile(out,'configuration.json'));
 if strcmp(result.status,'completed')
  assert(result.time_years(end)>=100-1e-10);
  plot_centered_water_S3(out);
  fid=fopen(fullfile(out,'COMPLETE.txt'),'w');fprintf(fid,'Reached %.17g years in %d steps.\\n',result.time_years(end),result.completed_steps);fclose(fid);
 end
catch exception
 if ~isfolder(out),mkdir(out);end
 record=struct('status','failed','message',exception.message,'report',getReport(exception,'extended','hyperlinks','off'));
 fid=fopen(fullfile(out,'error.json'),'w');fprintf(fid,'%s',jsonencode(record));fclose(fid);
 fid=fopen(fullfile(out,'progress.json'),'w');fprintf(fid,'%s',jsonencode(record));fclose(fid);
 rethrow(exception)
end
"""
(launch/'start_centered_water_100yr.m').write_text(matlab)
(root/'tmp/centered_water_100yr_output.txt').write_text(str(out))
(root/'tmp/centered_water_100yr_launch.txt').write_text(str(launch))
print(json.dumps({'output_dir':str(out),'launch_dir':str(launch),'solver_sha256':hashes[names[0]]},indent=2))
