"""Freeze the corrected S3 test with a flat upper layer at initial phi=0.3."""
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import difflib
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[1]
baseline = root / 'Output/centered_water_S3_100yr_20261024_214605'
config = json.loads((baseline / 'configuration.json').read_text(encoding='utf-8-sig'))
original = baseline / 'source/darcy_stokes_2D_cases.m.txt'
assert hashlib.sha256(original.read_bytes()).hexdigest() == config['source_sha256']['darcy_stokes_2D_cases.m']
parent = original.read_text()
old = '''    phiGr=double(Y>(Grid.p.ymin+Grid.p.ymax)/2 & ...
        X>Grid.p.xmin+0.25*(Grid.p.xmax-Grid.p.xmin) & ...
        X<Grid.p.xmin+0.75*(Grid.p.xmax-Grid.p.xmin));'''
assert parent.count(old) == 1
modified = parent.replace('function result = darcy_stokes_2D_cases(',
                          'function result = darcy_stokes_2D_flat_phi03_S3(', 1)
modified = modified.replace(old, '    phiGr=0.3*double(Y>(Grid.p.ymin+Grid.p.ymax)/2); % flat upper-half layer')
modified = modified.replace('% SETUP ONLY: the same Cartesian domain and centered upper-half water.',
                            '% SETUP ONLY: the same Cartesian domain, flat upper-half layer at phi=0.3.')
modified = modified.replace('diagnostic=centered_blob_diagnostics(', 'diagnostic=flat_phi03_diagnostics(')
solver = root / 'model_and_dependencies/darcy_stokes_2D_flat_phi03_S3.m'
if solver.exists():
    assert solver.read_text() == modified, 'Preserve local edits to the solver.'
else:
    solver.write_bytes(modified.encode())

stamp = datetime.now(ZoneInfo('America/New_York')).strftime('%Y%m%d_%H%M%S')
out = root / 'Output' / ('flat_phi03_S3_' + stamp)
runtime = out / 'runtime'
runtime.mkdir(parents=True)
for path in (baseline / 'source').glob('*.m.txt'):
    name = path.name.removesuffix('.txt')
    expected = config['source_sha256'].get(name)
    assert expected is None or hashlib.sha256(path.read_bytes()).hexdigest() == expected, name
    shutil.copy2(path, runtime / name)
diagnostic = runtime / 'centered_blob_diagnostics.m'
diagnostic_parent = diagnostic.read_text()
old_dry = 'initial_dry=~(X(:)>5000 & X(:)<15000 & Z(:)>4000);'
assert diagnostic_parent.count(old_dry) == 1
diagnostic_modified = diagnostic_parent.replace(old_dry, 'initial_dry=Z(:)<=4000; % flat upper-half initialization')
diagnostic.write_bytes(diagnostic_modified.encode())
(out / 'diagnostic_mask_only.diff').write_text(''.join(difflib.unified_diff(
    diagnostic_parent.splitlines(True), diagnostic_modified.splitlines(True),
    fromfile='centered_initially_dry_diagnostic', tofile='flat_initially_dry_diagnostic')))
for name in [solver.name, 'flat_phi03_diagnostics.m', 'run_flat_phi03_S3.m',
             'make_flat_phi03_video.m', 'make_flat_phi03_1D.m',
             'make_flat_phi03_minimal_videos.m']:
    shutil.copy2(root / 'model_and_dependencies' / name, runtime / name)
shutil.copy2(original, out / 'baseline_shared_solver.m.txt')
(out / 'initialization_only.diff').write_text(''.join(difflib.unified_diff(
    parent.splitlines(True), modified.splitlines(True),
    fromfile='original_centered_phi1_S3', tofile='flat_phi03_S3')))
previous_video = root / 'Output/flat_and_centered_S3_videos_20261024_221928/video_comparison.json'
target = json.loads(previous_video.read_text())['common_end_time_years']
record = dict(
    baseline_run=str(baseline), reference_video=str(previous_video),
    source_dir=str(runtime), output_dir=str(out), target_years=target,
    initial_upper_half_porosity=0.3,
    initial_bottom_half_porosity=0.0, initial_temperature_K=273.0,
    layer_x_range_m=[0, 20000], layer_z_range_m=[4000, 10000],
    domain_x_range_m=[0, 20000], domain_z_range_m=[-2000, 10000],
    kc_m2=1.85e-8, permeability_exponent=3,
    physical_change='Flat upper-half layer at phi=0.3; lower half phi=0; same original physics.',
    source_sha256={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in runtime.glob('*.m')})
(out / 'configuration.json').write_text(json.dumps(record, indent=2))
launch = out / 'start_run.m'
launch.write_text(f"addpath('{runtime.as_posix()}','-begin');\n"
                  f"run_flat_phi03_S3({target:.17g},'{out.as_posix()}');\n"
                  f"make_flat_phi03_video('{out.as_posix()}');\n"
                  f"make_flat_phi03_1D('{out.as_posix()}');\n"
                  f"make_flat_phi03_minimal_videos('{out.as_posix()}');\n")
(root / 'tmp').mkdir(exist_ok=True)
(root / 'tmp/flat_phi03_output.txt').write_text(str(out))
print(json.dumps(dict(output_dir=str(out), launcher=str(launch), target_years=target), indent=2))
