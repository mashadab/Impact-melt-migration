"""Preserve the matched e-11 endpoint after stopping its MATLAB/exporter processes.

Run once from the repository; existing stopped_result folders are never replaced.
No state is advanced or interpolated. Later unflushed raw fields remain intact.
"""
from pathlib import Path
import hashlib
import json
import shutil
import sys
from datetime import datetime

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'model_and_dependencies'))
from preserve_Europa_paper_outputs import MatReader, checkpoint_metrics, read_budget

run = Path((ROOT / 'tmp/Europa_S3_kc11_run.txt').read_text(encoding='utf-8-sig').strip())
rows = read_budget(run / 'melt_budget.csv')
manifest = json.loads((run / 'paper_outputs/field_manifest.json').read_text())
available = [m for m in manifest if m['kind'] == 'thermodynamic_checkpoint'
             and m['step'] < len(rows) and abs(m['time_years']-rows[m['step']]['time_years']) < 1e-7]
record = max(available, key=lambda m: m['step'])
source = run / record['source']
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(source) == record['sha256']
reader = MatReader(Path('C:/Program Files/MATLAB/R2022b/bin/win64'))
metrics, portable = checkpoint_metrics(reader.checkpoint(source))
step = metrics['step']
row = rows[step]
assert abs(metrics['melt_shell_km3']-row['melt_shell_m3']/1e9) < 1e-8
assert abs(metrics['time_years']-row['time_years']) < 1e-7
out = run / 'stopped_result'
out.mkdir(exist_ok=False)
shutil.copy2(source, out / 'checkpoint.mat')
np.savez_compressed(out / 'final_state.npz', **portable)
raw = (run / 'melt_budget.csv').read_bytes().splitlines(keepends=True)
(out / 'melt_budget.csv').write_bytes(b''.join(raw[:step+2]))
initial = rows[0]['melt_shell_m3']
config = json.loads((run / 'run_configuration.json').read_text())
summary = dict(status='stopped_by_user', analysis_status='depletion_complete',
               kc_m2=config['kc'], time_years=row['time_years'], steps=step,
               initial_shell_melt_km3=initial/1e9,
               remaining_shell_melt_km3=row['melt_shell_m3']/1e9,
               remaining_fraction=row['melt_shell_m3']/initial,
               target_fraction=config['remaining_melt_fraction'],
               depletion_reached=row['melt_shell_m3']/initial <= config['remaining_melt_fraction'],
               delivered_net_km3=row['delivered_net_m3']/1e9,
               refrozen_net_shell_km3=row['refrozen_net_shell_m3']/1e9)
process_record = json.loads((run / 'STOP_PROCESS_RECORD.json').read_text(encoding='utf-8-sig'))
stop = dict(**summary, stopped_local=process_record['requested_local'],
            preserved_local=datetime.now().astimezone().isoformat(),
            reason='User requested stopping and replotting all figures; endpoint accepted as depletion complete.',
            preserved_checkpoint=str(out / 'checkpoint.mat'), checkpoint_sha256=sha(out / 'checkpoint.mat'),
            archived_portable_state=str(run / record['portable_npz']),
            matched_budget=str(out / 'melt_budget.csv'),
            full_state=str(run / f'states/state_{step:08d}.mat'),
            result_plot_directory=str(out),
            note='Uses the last complete checkpoint matched to the flushed every-step budget. Later raw field files remain preserved.')
assert Path(stop['full_state']).is_file()
for path, data in [(run / 'summary.json', summary), (run / 'STOPPED_BY_USER.json', stop),
                   (out / 'endpoint_summary.json', summary)]:
    path.write_text(json.dumps(data, indent=2))
(run / 'STOPPED_BY_USER.txt').write_text(
    f'Accepted depletion-complete endpoint: step {step}, {row["time_years"]:.12g} years.\n'
    'Recorded on user request. Original numerical values and solver stop criterion are retained.\n')
print(json.dumps(stop, indent=2))
