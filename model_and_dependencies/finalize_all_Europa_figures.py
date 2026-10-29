"""Verify, render and package the complete Europa manuscript figure set."""
from pathlib import Path
import csv
import hashlib
import json
import shutil
import sys
import zipfile

import numpy as np
import pypdfium2 as pdfium
from PIL import Image, ImageDraw, ImageFont

from preserve_Europa_paper_outputs import MatReader

ROOT = Path(__file__).resolve().parents[1]
paths = json.loads((ROOT / 'tmp/all_Europa_figures_latest.json').read_text(encoding='utf-8-sig'))
OUT = Path(paths['output_dir'])
BUILD = Path(paths['build_dir'])
assert (OUT / 'PLOTTING_COMPLETE.txt').exists()
facts = json.loads((OUT / 'plot_provenance.json').read_text())
cases = facts['cases']
assert [c['kc_m2'] for c in cases] == [1.85e-16, 1.85e-14, 1.85e-12, 1.85e-11, 1.85e-10, 1.85e-8]
assert all(c['status'] == 'complete' for c in cases)
assert 'user instruction' in facts['completion_policy']
budgets = {}
checks = []
for case in cases:
    label = case['label']
    folder = OUT / 'data' / label
    shutil.copytree(BUILD / 'inputs' / label, folder, dirs_exist_ok=True)
    run = Path(case['directory'])
    for name in ['launch_provenance.json', 'startup_verification.json', 'launch_verification.json',
                 'STOPPED_BY_USER.json', 'STOPPED_BY_USER.txt', 'STOP_PROCESS_RECORD.json']:
        if (run / name).exists():
            shutil.copy2(run / name, folder / name)
    sources = [run / 'runtime/model_and_dependencies/darcy_stokes_2D_cases.m',
               run / 'source/darcy_stokes_2D_cases.m']
    source = next((p for p in sources if p.exists()), None)
    if case['label'] == 'e11':
        for name in ['checkpoint.mat', 'final_state.npz', 'endpoint_summary.json']:
            shutil.copy2(run / 'stopped_result' / name, folder / name)
    source_hash = None
    if source:
        source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
        shutil.copy2(source, folder / 'archived_solver_source.m')
    with (folder / 'budget_snapshot.csv').open(newline='') as handle:
        rows = list(csv.DictReader(handle))
    budgets[label] = rows
    times = np.array([float(r['time_years']) for r in rows])
    assert times[0] == 0 and np.all(np.diff(times) > 0)
    assert len(rows) == case['cutoff_step'] + 1
    assert abs(times[-1] - case['cutoff_years']) < 1e-7
    initial = float(rows[0]['melt_shell_m3'])
    error = np.array([float(r['melt_shell_m3']) + float(r['delivered_net_m3'])
                      + float(r['refrozen_net_shell_m3']) - initial for r in rows])
    assert max(abs(error)) < .02
    summary = case['summary']
    for column, key in [('melt_shell_m3', 'remaining_shell_melt_km3'),
                        ('delivered_net_m3', 'delivered_net_km3'),
                        ('refrozen_net_shell_m3', 'refrozen_net_shell_km3')]:
        assert abs(float(rows[-1][column]) / 1e9 - summary[key]) < 1e-8
    assert summary['remaining_fraction'] < .01
    assert abs(float(rows[-1]['melt_shell_m3']) / initial - summary['remaining_fraction']) < 1e-10
    checks.append(dict(label=label, status=case['status'], rows=len(rows),
                       original_solver_status=case['original_solver_status'],
                       original_0p5pct_threshold_reached=summary['remaining_fraction'] <= .005,
                       max_shell_budget_error_m3=float(max(abs(error))), archived_solver_sha256=source_hash))

selection_checks = []
for selection in facts['selection_sets']:
    with (OUT / selection['file']).open(newline='') as handle:
        rows = list(csv.DictReader(handle))
    assert len(rows) == 10
    budget = budgets[selection['label']]
    for row in rows:
        assert abs(float(row['time_years']) - float(budget[int(row['step'])]['time_years'])) < 1e-7
        assert Path(row['source']).is_file()
        assert float(row['offset_years']) >= -1e-7
    selection_checks.append(dict(file=selection['file'], actual_saved_timestamps=True, states=10))

# Independently integrate each displayed field on the cylindrical grid.
reader = MatReader(Path('C:/Program Files/MATLAB/R2022b/bin/win64'))
field_checks = []
for path in sorted((OUT / 'selected_fields').glob('*.mat')):
    label = path.stem.split('_step_')[0]
    handle = reader.mat.matOpen(str(path).encode(), b'r')
    assert handle
    value = reader.mat.matGetVariable(handle, b's')
    assert value
    try:
        def array(name):
            return reader.array(reader.field(value, name))
        step = int(array('step')[0])
        years = float(array('time_years')[0])
        radius = array('radius_km') * 1000
        elevation = array('elevation_km') * 1000
        phi = array('phi').reshape((len(elevation), len(radius)), order='F')
        temp = array('temperature_K')
    finally:
        reader.mx.mxDestroyArray(value)
        reader.mat.matClose(handle)
    assert np.all(np.isfinite(phi)) and np.all(np.isfinite(temp))
    assert phi.min() >= -1e-12 and phi.max() <= 1 + 1e-12
    assert temp.min() >= 100 - 1e-7 and temp.max() <= 273 + 1e-7
    dr = float(np.median(np.diff(radius)))
    dz = float(np.median(np.diff(elevation)))
    integrated = float(np.sum(phi[elevation >= 0] * (2 * np.pi * radius * dr * dz)))
    budget = budgets[label][step]
    volume_error = abs(integrated - float(budget['melt_shell_m3']))
    assert abs(years - float(budget['time_years'])) < 1e-7
    assert volume_error < .05, f'Field inventory mismatch: {path.name}'
    field_checks.append(dict(file=path.name, step=step, time_years=years,
                             shell_inventory_error_m3=volume_error))

# Check each diagnostic milestone is the first actual sample meeting its definition.
with (OUT / 'Europa_first_sample_milestone_times.csv').open(newline='') as handle:
    milestones = list(csv.DictReader(handle))
for case, milestone in zip(cases, milestones):
    rows = budgets[case['label']]
    assert abs(float(milestone['depletion_complete_years']) - float(rows[-1]['time_years'])) < 1e-7
    initial = float(rows[0]['melt_shell_m3'])
    definitions = [('delivery_25pct_years', 'delivered_net_m3', .25 * initial, True),
                   ('delivery_50pct_years', 'delivered_net_m3', .50 * initial, True),
                   ('delivery_75pct_years', 'delivered_net_m3', .75 * initial, True),
                   ('remaining_10pct_years', 'melt_shell_m3', .10 * initial, False),
                   ('remaining_1pct_years', 'melt_shell_m3', .01 * initial, False),
                   ('remaining_0p5pct_years', 'melt_shell_m3', .005 * initial, False),
                   ('front_9p95km_years', 'penetration_depth_km', 9.95 - 1e-9, True)]
    for name, column, threshold, increasing in definitions:
        hits = [r for r in rows if (float(r[column]) >= threshold if increasing else float(r[column]) <= threshold)]
        reported = float(milestone[name])
        if hits:
            assert abs(reported - float(hits[0]['time_years'])) < 1e-7
        else:
            assert np.isnan(reported)

pages = sorted((BUILD / 'pages').glob('*.pdf'))
assert len(pages) == 15
book = pdfium.PdfDocument.new()
reports = []
for path in pages:
    document = pdfium.PdfDocument(path)
    assert len(document) == 1
    text = document[0].get_textpage().get_text_range()
    assert len(text) > 80
    assert all(word not in text.lower() for word in ['user-stopped', 'partial endpoint', 'open squares'])
    png = OUT / (path.stem + '.png')
    image = document[0].render(scale=300/72, no_smoothimage=True).to_pil().convert('RGB')
    assert np.mean(np.min(np.asarray(image), axis=2) < 230) > .006
    image.save(png, dpi=(300, 300))
    book.import_pages(document)
    reports.append(dict(figure=path.stem, width=image.width, height=image.height, png_dpi=300))
    document.close()
combined = OUT / 'All_Europa_figures.pdf'
book.save(combined)
book.close()
for svg in OUT.glob('*.svg'):
    content = svg.read_text()
    if '<image ' in content and 'image-rendering:pixelated' not in content:
        svg.write_text(content.replace('<image ', '<image style="image-rendering:pixelated" '))

font = ImageFont.truetype('C:/Windows/Fonts/times.ttf', 18)
sheet_rows = (len(reports)+1)//2
sheet = Image.new('RGB', (1600, sheet_rows*430), '#eeeeee')
draw = ImageDraw.Draw(sheet)
for i, report in enumerate(reports):
    image = Image.open(OUT / (report['figure'] + '.png'))
    image.thumbnail((775, 380))
    x = (i % 2)*800 + 10
    y = (i // 2)*430 + 8
    sheet.paste(image, (x + (775-image.width)//2, y))
    draw.text((x, y+390), report['figure'], font=font, fill='black')
sheet.save(OUT / 'contact_sheet.png')
for part in range((sheet_rows+2)//3):
    sheet.crop((0, part*1290, 1600, min(sheet.height, (part+1)*1290))).save(OUT / f'contact_sheet_{part+1}.png')

for name in ['plot_all_Europa_figures.m', 'plot_Europa_paper_figures.m',
             'finalize_all_Europa_figures.py', 'preserve_Europa_paper_outputs.py']:
    shutil.copy2(ROOT / 'model_and_dependencies' / name, OUT / name)
shutil.copy2(ROOT / 'scripts/preserve_stopped_Europa_kc11.py', OUT / 'preserve_stopped_Europa_kc11.py')
verification = dict(passed=True, cases=checks, selections=selection_checks,
                    displayed_field_checks=field_checks, milestone_first_samples_verified=True,
                    accepted_depletion_endpoints_verified=True, completion_policy=facts['completion_policy'],
                    figures=reports, data_interpolation=False, image_smoothing=False,
                    temperature_band_outlines=False, simulation_advanced=False,
                    pressure_accuracy_tested=False, visually_reviewed='--visual-reviewed' in sys.argv)
(OUT / 'verification.json').write_text(json.dumps(verification, indent=2))
README = '''Complete Europa figure set

Six kc values (m2): 1.85e-16, 1.85e-14, 1.85e-12, 1.85e-11, 1.85e-10, 1.85e-8.
All six saved endpoints are classified as depletion complete, as requested
by the user on 2026-10-28 and 2026-10-29. Every case has less than 1% initial
shell melt remaining. Labels and endpoint markers treat all six cases equally.
Original solver stop reasons and all measured values remain in the archive.

01 Figure 4: Europa net delivery vs permeability; all depletion-complete points
   use the same marker. Permeability curves use k=kc*phi^3. The shaded band
   uses the MAIN manuscript Figure 4 caption's reported log10(kc) mean -7.71
   and standard deviation 0.42 (+/-2 sigma); no empirical refit was done.
   Raw empirical scatter and unavailable error bars are omitted.
02 Figure 5c,d: Europa theoretical foundering and infiltration times, using
   main manuscript equations 9-11 and archived physical constants. These are
   analytic maps, not new simulations. No isothermal-shell case dot is invented.
03 Figure 6: primary manuscript grouping e-16/e-10/e-8 at informative actual times.
04 Figure 7: melt volume and depth, primary grouping. Display windows remain
   1500, 5000 and 500 years for panels (a), (b), (c); complete data are retained.
05 Supplementary S4: the primary grouping over full available times, semilog.
06 Six-case evolution: rows share shell-melt milestones, not common times.
07 Six-case full-time histories: melt remaining, depth, net delivery/refreezing.
08 Exact endpoint shell-volume budgets (delivered + refrozen + remaining).
09 First recorded delivery and 10%/1% remaining thresholds, plus the accepted
   depletion-complete endpoint times for all six cases. The separate 0.5%
   crossing column retains actual values or NaN; completion is not substituted
   into that quantitative threshold column. No interpolation is used.
10 Initial state and actual endpoints: full-domain temperature and melt fraction.
11 Residual shell-melt tails and lower-layer liquid inventory. That inventory
   includes local phase change; it differs from net transfer across z=0.
12 Original manuscript Figure 6 requested timestamps, showing first actual
   available saved states at/after those times. The fields are corrected results,
   not reproductions of the old paper's physical migration times.
13-15 Additional e-16/e-11/e-8 comparison in the same manuscript layout:
   temperature/melt evolution, linear melt/depth histories and semilog histories.

PNG (300 dpi), vector SVG, editable MATLAB FIG, and a combined 15-page PDF
are provided. Text uses Times New Roman. Selected actual field arrays, scalar
histories, selection CSVs, endpoint/milestone tables and run-source provenance
are retained. No numerical field smoothing or temporal/spatial interpolation.
Time-history segments connect recorded diagnostic samples. Field pixels use
the original cell values; image smoothing and band outlines are disabled.
Analytic Figure 5 evaluates equations on an explicitly generated model grid.

Depth = surface minus deepest shell cell centre with phi>=0.001. Maximum
cell-centre penetration is 9.95 km on the 100-m vertical grid. This threshold
is a plotting diagnostic, not a proof of a resolved physical wetting front.
Net delivery subtracts upward return flow at z=0; net refreezing subtracts
new melting and includes initial phase equilibration. Delivered melt is not
an impact-origin tracer. The lower layer starts with zero melt at 273 K and
the outer base is impermeable; z=0 is an internal interface.

The main reference is docs/Impact_melt_foundering.pdf (27 pages). The separate
Impact_melt_foundering (1).pdf is the 8-page supplement, including Figure S4.
Figure/data mapping, paths, completion policy and formula constants are in
plot_provenance.json. No Titan run is substituted into the Europa results.

Verification checks every scalar row's shell-volume closure, actual snapshot
times, all displayed field inventories integrated on the cylindrical grid,
and exact first-sample milestones. These checks do not certify pressure
accuracy, physical front convergence or the proposed migration mechanism.

Regenerate in MATLAB: addpath('model_and_dependencies'); plot_all_Europa_figures
Then run model_and_dependencies/finalize_all_Europa_figures.py with the bundled
Python runtime. Paths are in tmp/all_Europa_figures_latest.json. Pass
--visual-reviewed only after visually inspecting every rendered final page.
The earlier figure packs and all original simulation results are preserved.
'''
(OUT / 'README.txt').write_text(README)
hashes = {p.relative_to(OUT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
          for p in OUT.rglob('*') if p.is_file() and p.name != 'artifact_hashes.json'}
(OUT / 'artifact_hashes.json').write_text(json.dumps(hashes, indent=2))
with zipfile.ZipFile(OUT.with_suffix('.zip'), 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted(OUT.rglob('*')):
        if path.is_file():
            archive.write(path, path.relative_to(OUT.parent))
print(json.dumps(dict(output=str(OUT), pdf=str(combined), zip=str(OUT.with_suffix('.zip')),
                      figures=len(pages), checked_field_states=len(field_checks),
                      visually_reviewed=verification['visually_reviewed'])))
