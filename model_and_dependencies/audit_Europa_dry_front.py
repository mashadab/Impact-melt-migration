"""Reconstruct saved, consecutive Europa enthalpy updates without rerunning flow.

Uses physical finite-volume face fluxes and the actual cylindrical cell geometry.
No source states, solver files, or research outputs are changed.
"""
import csv
import ctypes as c
import json
import os
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Output/Europa_permeability_comparison_20261024'
RUNS = {
    'high': ROOT / 'Output/Europa_kc_1.850e-08_until_depleted_20261023_195524',
    'low': ROOT / 'Output/Europa_kc_1.850e-16_until_depleted_20261024_085440',
}
YEAR = 3.154e7
CP = 185 + 7.037 * 273
DIFFUSIVITY = 3.3 / (920 * CP)
LATENT = 1000 * 334000 / (920 * CP * 173)
WATER_HEAT_CAPACITY_RATIO = 1000 * 4186 / (920 * CP)
THRESHOLD = 1e-6
bindir = Path(r'C:\Program Files\MATLAB\R2022b\bin\win64')
dll_dir = os.add_dll_directory(str(bindir))
h = c.CDLL(str(bindir / 'hdf5.dll'))
hid = c.c_longlong
h.H5open.restype = c.c_int
assert h.H5open() >= 0
for name, (args, result) in {
    'H5Fopen': ([c.c_char_p, c.c_uint, hid], hid),
    'H5Dopen2': ([hid, c.c_char_p, hid], hid),
    'H5Dget_space': ([hid], hid),
    'H5Sget_simple_extent_ndims': ([hid], c.c_int),
    'H5Sget_simple_extent_dims': ([hid, c.POINTER(c.c_ulonglong), c.POINTER(c.c_ulonglong)], c.c_int),
    'H5Dread': ([hid, hid, hid, hid, hid, c.c_void_p], c.c_int),
    'H5Fclose': ([hid], c.c_int),
    'H5Dclose': ([hid], c.c_int),
    'H5Sclose': ([hid], c.c_int),
}.items():
    fn = getattr(h, name)
    fn.argtypes, fn.restype = args, result
native = hid.in_dll(h, 'H5T_NATIVE_DOUBLE_g').value


class State:
    def __init__(self, path):
        self.f = h.H5Fopen(str(path).encode(), 0, 0)
        assert self.f >= 0

    def read(self, name):
        d = h.H5Dopen2(self.f, ('/state/' + name).encode(), 0)
        assert d >= 0, name
        space = h.H5Dget_space(d)
        rank = h.H5Sget_simple_extent_ndims(space)
        dims = (c.c_ulonglong * rank)()
        h.H5Sget_simple_extent_dims(space, dims, None)
        a = np.empty(int(np.prod(list(dims))), dtype=np.float64)
        assert h.H5Dread(d, native, 0, 0, 0, a.ctypes.data_as(c.c_void_p)) >= 0
        h.H5Sclose(space)
        h.H5Dclose(d)
        return a

    def close(self):
        h.H5Fclose(self.f)


def phase(H):
    phi = np.clip(H / LATENT, 0, 1)
    T = np.where(H <= 0, H + 1,
                 np.where(H < LATENT, 1, 1 + (H - LATENT) / WATER_HEAT_CAPACITY_RATIO))
    return phi, T


def faces(a, shape):
    nx, ny = shape
    return a[:(nx + 1) * ny].reshape(nx + 1, ny), a[(nx + 1) * ny:].reshape(nx, ny + 1)


def upwind(q, cell):
    nx, ny = cell.shape
    fx, fz = faces(q, cell.shape)
    left = np.zeros((nx + 1, ny)); right = left.copy()
    left[1:] = cell; right[:-1] = cell
    down = np.zeros((nx, ny + 1)); up = down.copy()
    down[:, 1:] = cell; up[:, :-1] = cell
    return np.where(fx >= 0, fx * left, fx * right), np.where(fz >= 0, fz * down, fz * up)


report = {
    'method': 'Exact saved consecutive steps only; reconstruct cylindrical finite-volume enthalpy budget from start-of-step recovered phase and saved physical flow.',
    'newly_wet_definition': f'start-of-step phi == 0 and end-of-step phi > {THRESHOLD}',
    'threshold_is_diagnostic_only': True,
    'runs': {},
}
all_rows = []
for label, run in RUNS.items():
    paths = sorted((run / 'states').glob('state_*.mat'))
    steps = {int(p.stem[6:]): p for p in paths}
    pairs = [step for step in steps if step > 0 and step - 1 in steps]
    s = State(steps[0])
    r = s.read('radius_m'); z = s.read('elevation_m')
    shape = len(r), len(z)
    dr, dz = r[1] - r[0], z[1] - z[0]
    redge = np.arange(len(r) + 1) * dr
    volumes = 2 * np.pi * r[:, None] * dr * dz * np.ones(shape)
    initial_phi = s.read('phi').reshape(shape)
    initial_H = s.read('enthalpy_dimensionless').reshape(shape)
    initial_T = s.read('temperature_K').reshape(shape)
    s.close()

    def divergence(f):
        fx, fz = f
        return (redge[1:, None] * fx[1:] - redge[:-1, None] * fx[:-1]) / (r[:, None] * dr) + (fz[:, 1:] - fz[:, :-1]) / dz

    max_error = max_dry_q = max_dry_div_vs = 0.
    max_mix_div = 0.
    events = count_conduction_alone = count_qr_alone = 0
    unique = np.zeros(shape, bool)
    example = None
    stats = []
    for step in pairs:
        prev = State(steps[step - 1]); cur = State(steps[step])
        H = prev.read('enthalpy_dimensionless').reshape(shape)
        start_time = prev.read('time_years')[0]
        phi, T = phase(H)
        phi_end = cur.read('phi').reshape(shape)
        H_end = cur.read('enthalpy_dimensionless').reshape(shape)
        end_time = cur.read('time_years')[0]
        flow_time = cur.read('flow_time_years')[0]
        assert abs(flow_time - start_time) < 1e-7
        dt = (end_time - flow_time) * YEAR
        vs = cur.read('solid_velocity_m_s')
        qr = cur.read('darcy_flux_m_s')
        assert all(np.isfinite(a).all() for a in [H, H_end, phi_end, vs, qr])
        prev.close(); cur.close()
        k = (phi * .56 + (1 - phi) * 3.3) / 3.3
        k[(z[None, :] < 200) & (phi > .5)] = 100
        kx = np.zeros((shape[0] + 1, shape[1])); kz = np.zeros((shape[0], shape[1] + 1))
        kx[1:-1] = 2 * k[:-1] * k[1:] / (k[:-1] + k[1:])
        kz[:, 1:-1] = 2 * k[:, :-1] * k[:, 1:] / (k[:, :-1] + k[:, 1:])
        gx = np.zeros_like(kx); gz = np.zeros_like(kz)
        gx[1:-1] = np.diff(T, axis=0) / dr
        gz[:, 1:-1] = np.diff(T, axis=1) / dz
        d_adv = -dt * divergence(upwind(vs, H))
        # H/tilde_phi = Pi_6 for ice/mush, H for fully liquid cells.
        # A dry, isothermal H=0 cell has no incident Darcy mobility.
        d_darcy = -dt * divergence(upwind(qr, np.where(H >= LATENT, H, LATENT)))
        d_cond = dt * DIFFUSIVITY * divergence((kx * gx, kz * gz))
        predicted = H + d_adv + d_darcy + d_cond
        predicted[:, -1] = -1  # prescribed cold surface enthalpy
        error = np.abs(predicted - H_end)
        max_error = max(max_error, float(error.max()))
        dry = phi == 0
        qx, qz = faces(qr, shape)
        touching_x = np.zeros_like(qx, bool); touching_z = np.zeros_like(qz, bool)
        touching_x[1:-1] = dry[:-1] | dry[1:]
        touching_z[:, 1:-1] = dry[:, :-1] | dry[:, 1:]
        max_dry_q = max(max_dry_q, float(abs(qx[touching_x]).max(initial=0)), float(abs(qz[touching_z]).max(initial=0)))
        max_dry_div_vs = max(max_dry_div_vs, float(abs(divergence(faces(vs, shape))[dry]).max(initial=0)))
        max_mix_div = max(max_mix_div, float(abs(divergence(faces(vs + qr, shape))).max()))
        new = dry & (phi_end > THRESHOLD)
        count = int(new.sum())
        events += count
        unique |= new
        count_conduction_alone += int((new & (H + d_cond > THRESHOLD * LATENT)).sum())
        count_qr_alone += int((new & (H + d_darcy > THRESHOLD * LATENT)).sum())
        row = {'run': label, 'step': step, 'flow_time_years': float(flow_time), 'time_years': float(end_time),
               'dt_years': float(dt / YEAR), 'newly_wet_cells': count,
               'newly_wet_melt_km3': float(np.sum(phi_end[new] * volumes[new]) / 1e9),
               'max_enthalpy_reconstruction_error': float(error.max())}
        stats.append(row); all_rows.append(row)
        if count:
            ij = np.unravel_index(np.argmax(np.where(new, phi_end, -1)), shape)
            ex = {'step': step, 'flow_time_years': float(flow_time), 'time_years': float(end_time),
                  'r_m': float(r[ij[0]]), 'z_m': float(z[ij[1]]),
                  'initial_phi_at_location': float(initial_phi[ij]),
                  'initial_temperature_K_at_location': float(initial_T[ij]),
                  'phi_before': float(phi[ij]), 'phi_after': float(phi_end[ij]),
                  'temperature_before_K': float(100 + 173 * T[ij]), 'H_before': float(H[ij]),
                  'delta_H_bulk_advection': float(d_adv[ij]), 'delta_H_Darcy': float(d_darcy[ij]),
                  'delta_H_conduction': float(d_cond[ij]), 'H_after': float(H_end[ij]),
                  'reconstruction_error': float(error[ij])}
            if example is None or ex['phi_after'] > example['phi_after']:
                example = ex
    summary = {
        'saved_consecutive_steps_checked': len(pairs),
        'checked_step_ranges': [[a[0], a[-1]] for a in np.split(np.array(pairs), np.where(np.diff(pairs) != 1)[0] + 1)],
        'max_enthalpy_reconstruction_error_dimensionless': max_error,
        'max_abs_Darcy_flux_on_faces_touching_exactly_dry_cell_m_per_s': max_dry_q,
        'max_abs_solid_divergence_in_exactly_dry_cells_per_s': max_dry_div_vs,
        'max_abs_mixture_divergence_per_s': max_mix_div,
        'newly_wet_cell_events': events, 'unique_newly_wet_cells_in_checked_steps': int(unique.sum()),
        'events_reproducible_by_conduction_alone': count_conduction_alone,
        'events_reproducible_by_Darcy_alone': count_qr_alone,
        'strongest_single_step_newly_wet_example': example,
        'largest_newly_wet_volume_step': max(stats, key=lambda x: x['newly_wet_melt_km3']),
    }
    report['runs'][label] = summary
    print(label, json.dumps(summary, default=lambda x: int(x)), flush=True)
OUT.mkdir(exist_ok=True)
(OUT / 'dry_front_audit.json').write_text(json.dumps(report, indent=2, default=lambda x: int(x)))
with (OUT / 'dry_front_consecutive_steps.csv').open('w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(all_rows[0])); w.writeheader(); w.writerows(all_rows)
print('DRY_FRONT_AUDIT', OUT / 'dry_front_audit.json', flush=True)
