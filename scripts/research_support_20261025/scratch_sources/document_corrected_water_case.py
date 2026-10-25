from pathlib import Path
import difflib
import hashlib
import json

root = Path(__file__).resolve().parents[1]
model = root / 'model_and_dependencies'
audit = Path((root / 'tmp/centered_water_verification_output.txt').read_text(encoding='utf-8-sig').strip())
before_path = audit / 'shared_solver_before.m.txt'
after_path = model / 'darcy_stokes_2D_cases.m'
before = before_path.read_text(encoding='utf-8')
after = after_path.read_text(encoding='utf-8')
start = '        %% Bouyancy force as the body force to Stokes flow'
end = '        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5'
def core(text):
    return text[text.index(start):text.index(end) + len(end)]
assert core(before) == core(after), 'Flow/transport equations changed.'
helper = 'function [D,Edot,Dp,Gp,I,Gyy]=nf_stokes_ops(Grid)'
assert before[before.index(helper):] == after[after.index(helper):]
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
diff = ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
    fromfile='working_shared_S3_before', tofile=after_path.name))
(root / 'docs/CENTERED_WATER_S3_SETUP.diff').write_text(diff, encoding='utf-8')
record = {
    'baseline': str(before_path), 'baseline_sha256': sha(before_path),
    'solver': str(after_path), 'solver_sha256': sha(after_path),
    'original_wave_sha256': sha(model / 'porosity_wave_2D_Jake_minimal.m'),
    'case_key': 'centered_water',
    'flow_transport_block_text_identical': True,
    'flow_transport_block_lines': len(core(after).splitlines()),
    'flow_transport_block_sha256': hashlib.sha256(core(after).encode()).hexdigest(),
    'stokes_operator_helper_text_identical': True,
    'independent_before_after_verification_dir': str(audit),
    'setup': {'grid': [100,120], 'x_m':[0,20000], 'z_m':[-2000,10000],
              'initial_water_x_m':[5000,15000], 'initial_water_z_m':[4000,10000],
              'initial_temperature_K':273, 'water_phi':1, 'elsewhere_phi':0,
              'permeability_exponent':3, 'kc_m2':1.85e-8,
              'coordinates':'cartesian', 'walls':'closed, free slip, insulated'},
    'restart_from_biased_run': False,
    'archived_source_files': {p.name:sha(p) for p in (model / '.').glob('*.m')
        if p.name in ['darcy_stokes_2D_cases.m','run_darcy_stokes_case.m',
                      'record_centered_water_step.m','run_centered_water_S3.m',
                      'centered_blob_diagnostics.m']}
}
if (audit / 'verification.json').exists():
    record['verification'] = json.loads((audit/'verification.json').read_text())
    run_dir = Path(record['verification']['output_dir'])
    record['run_source_matches_current'] = {}
    for archived in (run_dir/'source').glob('*.m.txt'):
        current = model/archived.name.removesuffix('.txt')
        record['run_source_matches_current'][current.name] = archived.read_bytes() == current.read_bytes()
    assert all(record['run_source_matches_current'].values()), 'An archived run source differs from disk.'
(root / 'docs/CENTERED_WATER_S3_PROVENANCE.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in record.items() if k not in ['setup','archived_source_files','verification']},indent=2))
