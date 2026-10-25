"""Preserve paper-plot data from a live Europa run without editing its solver.

Usage: python preserve_Europa_paper_outputs.py RUN_DIRECTORY [--watch]
Reads complete solver CSV/checkpoints, never interpolates or advances a state.
"""
from pathlib import Path
import argparse
import csv
import ctypes as ct
import hashlib
import io
import json
import math
import os
import shutil
import time
from datetime import datetime, timezone
import numpy as np

THRESHOLDS = (1e-3, 1e-2, .05, .1, .5)
PAPER_TIMES = {
    'Fig6a_kc_1.85e-16': [0, 23, 52, 93, 140, 259, 455, 682, 1465, 7041],
    'Fig6b_kc_1.85e-10': [0, .06, .16, .29, .42, .62, .93, 1.24, 1.84, 12.73],
    'Fig6c_kc_1.85e-8': [0, .003, .005, .008, .010, .013, .016, .110, .482, 5.196],
}


def atomic_text(path, text):
    tmp = path.with_name(path.name + '.partial')
    with tmp.open('w', encoding='utf-8', newline='') as handle:
        handle.write(text)
    os.replace(tmp, path)


def write_csv(path, rows):
    if not rows:
        return
    stream = io.StringIO(newline='')
    writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
    writer.writeheader()
    writer.writerows(rows)
    atomic_text(path, stream.getvalue())


def read_budget(path):
    before = path.stat()
    raw = path.read_text(encoding='utf-8-sig')
    after = path.stat()
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise RuntimeError('Budget is being updated; retry later.')
    if not raw.endswith('\n'):
        raise RuntimeError('Budget write is incomplete; retry later.')
    rows = [{key: float(value) for key, value in row.items()}
            for row in csv.DictReader(io.StringIO(raw))]
    assert rows and rows[0]['time_years'] == 0
    times = np.array([r['time_years'] for r in rows])
    assert np.all(np.diff(times) > 0), 'Budget must contain every completed step in order.'
    initial = rows[0]['melt_shell_m3']
    for row in rows:
        assert abs(row['melt_domain_m3'] - row['melt_shell_m3'] - row['melt_ocean_region_m3']) < .01
        assert abs(initial - row['melt_shell_m3'] - row['delivered_net_m3']
                   - row['refrozen_net_shell_m3']) < .01
    return rows


def plotting_history(rows):
    out = []
    deepest = float('nan')
    initial = rows[0]['melt_shell_m3']
    for step, row in enumerate(rows):
        record = {'step': step, **row}
        for name, value in row.items():
            if name.endswith('_m3'):
                record[name[:-3] + '_km3'] = value / 1e9
        record['remaining_shell_fraction'] = row['melt_shell_m3'] / initial
        record['delivered_net_fraction_of_initial'] = row['delivered_net_m3'] / initial
        depth = row['penetration_depth_km']
        if np.isfinite(depth):
            deepest = max(deepest, depth) if np.isfinite(deepest) else depth
        record['deepest_shell_penetration_so_far_km_phi_ge_0p001'] = deepest
        dt = row['time_years'] - rows[step-1]['time_years'] if step else 0
        record['dt_years'] = dt
        record['net_delivery_rate_km3_per_year'] = ((row['delivered_net_m3']
            - rows[step-1]['delivered_net_m3']) / dt / 1e9) if step else float('nan')
        record['net_shell_refreezing_rate_km3_per_year'] = ((row['refrozen_net_shell_m3']
            - rows[step-1]['refrozen_net_shell_m3']) / dt / 1e9) if step else float('nan')
        out.append(record)
    return out


class MatReader:
    def __init__(self, matlab_bin):
        self.dll_directory = os.add_dll_directory(str(matlab_bin))
        self.mat = ct.CDLL(str(matlab_bin / 'libmat.dll'))
        self.mx = ct.CDLL(str(matlab_bin / 'libmx.dll'))
        self.mat.matOpen.argtypes = [ct.c_char_p, ct.c_char_p]
        self.mat.matOpen.restype = ct.c_void_p
        self.mat.matGetVariable.argtypes = [ct.c_void_p, ct.c_char_p]
        self.mat.matGetVariable.restype = ct.c_void_p
        self.mat.matClose.argtypes = [ct.c_void_p]
        self.mx.mxGetField.argtypes = [ct.c_void_p, ct.c_size_t, ct.c_char_p]
        self.mx.mxGetField.restype = ct.c_void_p
        self.mx.mxGetNumberOfElements.argtypes = [ct.c_void_p]
        self.mx.mxGetNumberOfElements.restype = ct.c_size_t
        self.mx.mxGetPr.argtypes = [ct.c_void_p]
        self.mx.mxGetPr.restype = ct.POINTER(ct.c_double)
        self.mx.mxDestroyArray.argtypes = [ct.c_void_p]

    def array(self, value):
        assert value, 'Missing MATLAB value.'
        count = self.mx.mxGetNumberOfElements(value)
        return np.ctypeslib.as_array(self.mx.mxGetPr(value), shape=(count,)).copy()

    def field(self, value, name):
        result = self.mx.mxGetField(value, 0, name.encode())
        assert result, name
        return result

    def checkpoint(self, path):
        handle = self.mat.matOpen(str(path).encode(), b'r')
        assert handle, path
        owned = []
        def variable(name):
            value = self.mat.matGetVariable(handle, name.encode())
            assert value, name
            owned.append(value)
            return value
        try:
            result = {key: self.array(variable(key)) for key in ['H', 'T', 'phi', 'i', 'tTot', 'd']}
            grid = self.field(variable('Grid'), 'p')
            for key in ['xc', 'yc', 'V', 'Nx', 'Ny', 'ymax']:
                result[key] = self.array(self.field(grid, key))
        finally:
            for value in owned:
                self.mx.mxDestroyArray(value)
            self.mat.matClose(handle)
        return result


def checkpoint_metrics(data):
    step = int(data['i'][0]); stamp = float(data['tTot'][0]); d = float(data['d'][0])
    nx = int(data['Nx'][0]); ny = int(data['Ny'][0])
    phi = data['phi']; temp = data['T'] * 173 + 100
    assert len(phi) == nx*ny and len(temp) == nx*ny and len(data['H']) == nx*ny
    assert np.all(np.isfinite(phi)) and np.all(np.isfinite(temp)) and np.all(np.isfinite(data['H']))
    assert phi.min() >= 0 and phi.max() <= 1
    z = np.tile(data['yc'] * d / 1000, nx); shell = z >= 0
    volume = data['V'] * d**3
    record = {'step': step, 'time_years': stamp,
              'temperature_min_K': float(temp.min()), 'temperature_max_K': float(temp.max()),
              'melt_shell_km3': float(np.dot(phi[shell], volume[shell])/1e9),
              'melt_domain_km3': float(np.dot(phi, volume)/1e9)}
    for threshold in THRESHOLDS:
        suffix = str(threshold).replace('.', 'p')
        active = phi >= threshold
        wet_shell = shell & active
        front = float(z[wet_shell].min()) if wet_shell.any() else float('nan')
        record['shell_front_elevation_km_phi_ge_'+suffix] = front
        record['shell_penetration_depth_km_phi_ge_'+suffix] = float(data['ymax'][0]*d/1000-front)
        record['domain_front_elevation_km_phi_ge_'+suffix] = float(z[active].min()) if active.any() else float('nan')
    return record, dict(phi=phi, temperature_K=temp, enthalpy_dimensionless=data['H'],
        radius_m=data['xc']*d, elevation_m=data['yc']*d, cell_volume_m3=volume,
        step=np.array(step), time_years=np.array(stamp), array_order=np.array('MATLAB column-major'))


class Preserver:
    def __init__(self, run, matlab_bin):
        self.run = run.resolve(); self.out = self.run / 'paper_outputs'
        self.archive = self.out / 'checkpoints'; self.archive.mkdir(parents=True, exist_ok=True)
        self.reader = MatReader(matlab_bin)
        self.manifest_path = self.out / 'field_manifest.json'
        self.fields = json.loads(self.manifest_path.read_text()) if self.manifest_path.exists() else []
        self.known = {r['source'] for r in self.fields}
        self.metrics = []
        if (self.out/'checkpoint_fronts.csv').exists():
            with (self.out/'checkpoint_fronts.csv').open(newline='') as handle:
                self.metrics = list(csv.DictReader(handle))
        self.last_budget_signature = None
        self.last_checkpoint_signature = None
        config = json.loads((self.run/'run_configuration.json').read_text())
        self.config = config
        self.started = datetime.now(timezone.utc).isoformat()
        atomic_text(self.out/'sampling_metadata.json', json.dumps(dict(
            run=str(self.run), started_utc=self.started, kc_m2=config['kc'],
            diagnostic_sampling='Every solver timestep; solver flushes the complete CSV every 100 steps.',
            extra_field_sampling='Each stable checkpoint observed from exporter startup, normally every 100 steps.',
            preexisting_full_states='Original scheduled states remain in ../states/; previous overwritten checkpoints are unavailable.',
            front_definition='Deepest cell centre at or above an explicitly labelled phi threshold; shell z>=0.',
            main_history_phi_threshold=.001, sensitivity_phi_thresholds=THRESHOLDS,
            depth_resolution_m=100, net_delivery_plane_z_m=0,
            freezing_definition='Signed net freezing minus melting, from volume balance; not gross freezing or impact-origin tagging.',
            pressure_note='Pressure reproducibility is unresolved; copied checkpoints contain H/T/phi/Grid, not solved flow fields.',
            data_interpolation=False, seconds_per_year=3.154e7,
            manuscript_figures={'6':'Full T/phi fields, axes, actual timestamps, saved flow fields where available.',
                '7_and_S4':'Every-step shell melt volume and penetration depth; linear and semilog axes.',
                '4a':'Net delivered volume per completed permeability case.',
                '4b':'Permeability law and independent published datasets; not generated by a simulation.',
                '5':'Theoretical timescale formulas and archived physical parameters, not a simulated curve.',
                '2_3_and_S3':'Titan equivalents require separately configured Titan simulations.'}), indent=2))

    def add_field(self, source, step, stamp, kind, extra=None):
        key = source.relative_to(self.run).as_posix()
        if key in self.known:
            return
        record = dict(source=key, step=step, time_years=stamp, kind=kind,
                      sha256=hashlib.sha256(source.read_bytes()).hexdigest())
        if extra:
            record.update(extra)
        self.fields.append(record); self.known.add(key)

    def update(self):
        budget_path = self.run/'melt_budget.csv'
        signature = (budget_path.stat().st_size, budget_path.stat().st_mtime_ns)
        source = self.run/'checkpoint.mat'
        checkpoint_signature = (source.stat().st_size, source.stat().st_mtime_ns) if source.exists() else None
        if signature == self.last_budget_signature and checkpoint_signature == self.last_checkpoint_signature:
            return False
        rows = read_budget(budget_path)
        write_csv(self.out/'time_history.csv', plotting_history(rows))
        for source in sorted((self.run/'states').glob('state_*.mat')):
            key = source.relative_to(self.run).as_posix()
            step = int(source.stem.split('_')[-1])
            if key not in self.known and step < len(rows) and time.time()-source.stat().st_mtime > 2:
                self.add_field(source, step, rows[step]['time_years'], 'full_solver_state', dict(
                    contains_flow=step>0, flow_time_years=rows[step-1]['time_years'] if step else None))
        source = self.run/'checkpoint.mat'
        if source.exists() and time.time()-source.stat().st_mtime > 2:
            before = source.stat(); sig = (before.st_size, before.st_mtime_ns)
            if sig != self.last_checkpoint_signature:
                tmp = self.archive/'copy_in_progress.mat'
                shutil.copyfile(source, tmp)
                after = source.stat()
                if sig != (after.st_size, after.st_mtime_ns):
                    raise RuntimeError('Checkpoint changed during copy; retry later.')
                data = self.reader.checkpoint(tmp); metrics, portable = checkpoint_metrics(data)
                step = metrics['step']
                if step >= len(rows):
                    raise RuntimeError('Checkpoint is newer than the flushed CSV; retry later.')
                assert abs(metrics['time_years']-rows[step]['time_years']) < 1e-9
                assert abs(metrics['melt_shell_km3']-rows[step]['melt_shell_m3']/1e9) < 1e-8
                target = self.archive/f'checkpoint_step_{step:08d}.mat'
                if not target.exists():
                    os.replace(tmp, target)
                    np.savez_compressed(target.with_suffix('.npz'), **portable)
                    self.metrics.append(metrics)
                elif tmp.exists():
                    tmp.unlink()
                self.add_field(target, step, metrics['time_years'], 'thermodynamic_checkpoint',
                    dict(contains_flow=False, portable_npz=target.with_suffix('.npz').relative_to(self.run).as_posix()))
                self.last_checkpoint_signature = sig
        self.fields.sort(key=lambda r: (r['step'], r['kind']))
        atomic_text(self.manifest_path, json.dumps(self.fields, indent=2))
        write_csv(self.out/'checkpoint_fronts.csv', self.metrics)
        selections = []
        for panel, targets in PAPER_TIMES.items():
            panel_kc = {'Fig6a_kc_1.85e-16': 1.85e-16,
                        'Fig6b_kc_1.85e-10': 1.85e-10,
                        'Fig6c_kc_1.85e-8': 1.85e-8}[panel]
            for target in targets:
                available = [r for r in self.fields if r['time_years'] >= target]
                selected = min(available, key=lambda r: (r['time_years'], r['kind']!='full_solver_state')) if available else None
                selections.append(dict(paper_panel=panel,
                    panel_matches_run_kc=math.isclose(panel_kc, self.config['kc'], rel_tol=1e-12, abs_tol=0),
                    requested_years=target,
                    actual_saved_years=selected['time_years'] if selected else '',
                    step=selected['step'] if selected else '', source=selected['source'] if selected else '',
                    offset_years=selected['time_years']-target if selected else '',
                    selection='first available saved state at/after request' if selected else 'pending'))
        write_csv(self.out/'paper_snapshot_times.csv', selections)
        atomic_text(self.out/'status.json', json.dumps(dict(updated_utc=datetime.now(timezone.utc).isoformat(),
            last_step=len(rows)-1, last_time_years=rows[-1]['time_years'], history_rows=len(rows),
            indexed_fields=len(self.fields), extra_checkpoints=len(self.metrics), data_interpolation=False), indent=2))
        self.last_budget_signature = signature
        return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    parser.add_argument('--watch', action='store_true')
    parser.add_argument('--poll-seconds', type=float, default=3)
    parser.add_argument('--matlab-bin', type=Path, default=Path('C:/Program Files/MATLAB/R2022b/bin/win64'))
    args = parser.parse_args()
    preserver = Preserver(args.run, args.matlab_bin)
    shutil.copyfile(Path(__file__), preserver.out/'exporter_source.py')
    while True:
        try:
            if preserver.update():
                print((preserver.out/'status.json').read_text(), flush=True)
        except (OSError, ValueError, AssertionError, RuntimeError) as error:
            if not args.watch:
                raise
            print(f'Retry after incomplete/live write: {error}', flush=True)
        if not args.watch or (preserver.out/'STOP_EXPORTER').exists():
            break
        if any((args.run/name).exists() for name in ['COMPLETE.txt','FAILED.txt','LAUNCH_FAILED.txt']):
            break
        time.sleep(max(.5, args.poll_seconds))


if __name__ == '__main__':
    main()
