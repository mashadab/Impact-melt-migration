"""Render and verify the saved-data manuscript comparison of three Europa cases."""
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

ROOT = Path(__file__).resolve().parents[1]
paths = json.loads((ROOT / 'tmp/manuscript_three_cases_latest.json').read_text(encoding='utf-8-sig'))
OUT = Path(paths['output_dir'])
BUILD = Path(paths['build_dir'])
assert (OUT / 'PLOTTING_COMPLETE.txt').exists(), 'MATLAB plotting has not completed.'
provenance = json.loads((OUT / 'plot_provenance.json').read_text())
assert [c['kc_m2'] for c in provenance['cases']] == [1.85e-16, 1.85e-12, 1.85e-8]
assert provenance['cases'][1]['status'] == 'stopped_by_user'

data = OUT / 'data'
data.mkdir(exist_ok=True)
checks = []
for case in provenance['cases']:
    label = case['label']
    shutil.copytree(BUILD / 'inputs' / label, data / label, dirs_exist_ok=True)
    with (data / label / 'budget_snapshot.csv').open(newline='') as handle:
        rows = list(csv.DictReader(handle))
    times = np.array([float(r['time_years']) for r in rows])
    assert times[0] == 0 and np.all(np.diff(times) > 0)
    assert len(rows) == case['cutoff_step'] + 1
    assert abs(times[-1] - case['cutoff_years']) < 1e-7
    initial = float(rows[0]['melt_shell_m3'])
    errors = [abs(float(r['melt_shell_m3']) + float(r['delivered_net_m3'])
                  + float(r['refrozen_net_shell_m3']) - initial) for r in rows]
    assert max(errors) < .02, 'Shell liquid-volume budget does not close.'
    summary = case['summary']
    for column, key in [('melt_shell_m3', 'remaining_shell_melt_km3'),
                        ('delivered_net_m3', 'delivered_net_km3'),
                        ('refrozen_net_shell_m3', 'refrozen_net_shell_km3')]:
        assert abs(float(rows[-1][column]) / 1e9 - summary[key]) < 1e-8
    with (OUT / (label + '_selected_states.csv')).open(newline='') as handle:
        selected = list(csv.DictReader(handle))
    assert len(selected) == 10
    for state in selected:
        step = int(state['step'])
        assert abs(float(state['time_years']) - times[step]) < 1e-7
        assert Path(state['source']).is_file()
        assert float(state['offset_years']) >= -1e-7
    checks.append(dict(label=label, kc_m2=case['kc_m2'], rows=len(rows),
                       max_budget_error_m3=max(errors), selected_saved_states=10,
                       status=case['status'], cutoff_years=float(times[-1])))

pages = sorted((BUILD / 'pages').glob('*.pdf'))
assert len(pages) == 3
book = pdfium.PdfDocument.new()
reports = []
for path in pages:
    document = pdfium.PdfDocument(path)
    assert len(document) == 1
    page = document[0]
    text = page.get_textpage().get_text_range()
    assert len(text) > 100 and 'stopped' in text.lower()
    png = OUT / (path.stem + '.png')
    image = page.render(scale=2.5).to_pil().convert('RGB')
    assert np.mean(np.min(np.asarray(image), axis=2) < 230) > .008
    image.save(png)
    book.import_pages(document)
    reports.append(dict(figure=path.stem, width=image.width, height=image.height))
    document.close()
combined = OUT / 'Europa_three_case_manuscript_figures.pdf'
book.save(combined)
book.close()

font = ImageFont.truetype('C:/Windows/Fonts/times.ttf', 23)
sheet = Image.new('RGB', (1600, 3 * 660), '#eeeeee')
draw = ImageDraw.Draw(sheet)
for i, report in enumerate(reports):
    image = Image.open(OUT / (report['figure'] + '.png'))
    image.thumbnail((1550, 600))
    sheet.paste(image, ((1600 - image.width) // 2, i * 660 + 8))
    draw.text((25, i * 660 + 617), report['figure'], font=font, fill='black')
sheet.save(OUT / 'contact_sheet.png')

for name in ['plot_Europa_paper_figures.m', 'finalize_Europa_three_case_figures.py']:
    shutil.copy2(ROOT / 'model_and_dependencies' / name, OUT / name)
verification = dict(passed=True, data_interpolation=False,
                    cases=checks, figures=reports,
                    partial_endpoint_identified=True, simulation_source_modified=False,
                    pressure_accuracy_tested=False,
                    visually_reviewed='--visual-reviewed' in sys.argv)
(OUT / 'verification.json').write_text(json.dumps(verification, indent=2))
(OUT / 'README.txt').write_text('''Europa manuscript-style comparison: kc = 1.85e-16, 1.85e-12 and 1.85e-8 m2.

Panels (a), (b), (c) correspond to these cases, respectively. The first and
third cases reached the 0.5% shell-melt stopping threshold. The middle case
was stopped by the user at step 33600, 54817.746120019896 simulated years,
with 0.628152451% initial shell melt remaining. Its endpoint is partial.

01: manuscript volume/depth histories; time limits (a) 0-1500 yr,
    (b) 0-5000 yr and (c) 0-500 yr. Full histories are retained in data/.
02: full-time semilog version; t=0 is omitted from the logarithmic plots.
03: temperature and melt evolution using selected actual saved states.
    Each printed timestamp is the actual saved time, rounded for display.

All plots use Times New Roman. PNG, vector SVG, editable MATLAB FIG and a
combined three-page PDF are provided. The plotting code adapts the existing
manuscript figure helpers. No simulation is advanced or edited to make these
figures. The active kc=1.85e-14 case is not included in this comparison.

No temporal or spatial interpolation of numerical fields. Scalar-history
line segments connect actual recorded samples. Field colours show original
cell values; temperature-band outlines follow cell edges. Selected field
arrays and exact timestamp/source selections are retained alongside the plots.
Depth uses phi>=0.001 and 100-m vertical cell centres (maximum 9.95 km).
Net delivery is downward minus upward transfer at z=0; net refreezing is
freezing minus new melting, including initial phase equilibration.

Run provenance, case status, exact endpoints and display windows are in
plot_provenance.json. verification.json checks the saved timestamps, endpoint
summaries and shell liquid-volume balances. These checks do not certify
pressure accuracy or physical convergence of the melt front.

To regenerate, call plot_Europa_paper_figures(out,build,high_dir,middle_dir)
in MATLAB, supplying the explicit completed high-kc and stopped middle-kc run
directories from plot_provenance.json. Then run the accompanying Python
finalizer. The latest output/build paths are recorded separately in
tmp/manuscript_three_cases_latest.json; the earlier eight-page pack is retained.
''')
hashes = {p.relative_to(OUT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
          for p in OUT.rglob('*') if p.is_file() and p.name != 'artifact_hashes.json'}
(OUT / 'artifact_hashes.json').write_text(json.dumps(hashes, indent=2))
with zipfile.ZipFile(OUT.with_suffix('.zip'), 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted(OUT.rglob('*')):
        if path.is_file():
            archive.write(path, path.relative_to(OUT.parent))
print(json.dumps(dict(output=str(OUT), pdf=str(combined), pages=len(pages),
                      zip=str(OUT.with_suffix('.zip')), visually_reviewed=verification['visually_reviewed'])))
