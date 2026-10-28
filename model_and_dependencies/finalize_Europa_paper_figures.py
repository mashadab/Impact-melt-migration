"""Assemble and verify the manuscript-style figure pack after MATLAB plotting."""
from pathlib import Path
import csv
import hashlib
import json
import re
import shutil
import sys
import numpy as np
import pypdfium2 as pdfium
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
paths=json.loads((ROOT/'tmp/manuscript_figures_latest.json').read_text(encoding='utf-8-sig'))
OUT=Path(paths['output_dir']);BUILD=Path(paths['build_dir'])
assert (OUT/'PLOTTING_COMPLETE.txt').is_file(), 'MATLAB plotting is incomplete.'
pages=sorted((BUILD/'pages').glob('*.pdf'))
assert len(pages)==8, f'Expected 8 figures, found {len(pages)}'
book=pdfium.PdfDocument.new();reports=[]
for page_path in pages:
    document=pdfium.PdfDocument(page_path)
    assert len(document)==1
    text=document[0].get_textpage().get_text_range()
    assert len(text)>60, 'Expected editable vector text.'
    png=OUT/(page_path.stem+'.png')
    image=document[0].render(scale=2.5).to_pil().convert('RGB')
    image.save(png)
    array=np.asarray(image)
    assert float(np.mean(np.min(array,axis=2)<230))>.008,'Figure appears empty'
    book.import_pages(document)
    reports.append(dict(figure=page_path.stem,png=str(png),width=image.width,height=image.height,
                        vector_text_characters=len(text)))
    document.close()
combined=OUT/'Europa_manuscript_style_figures.pdf';book.save(combined);book.close()
assert len(pdfium.PdfDocument(combined))==8

data=OUT/'data';data.mkdir(exist_ok=True)
for folder in (BUILD/'inputs').iterdir():
    shutil.copytree(folder,data/folder.name,dirs_exist_ok=True)
provenance=json.loads((OUT/'plot_provenance.json').read_text())
budget_sources={'low':'low','current_high':'current_high','completed_high':'completed_high'}
selection_checks=[]
for path in sorted(OUT.glob('*selected_states.csv'))+sorted(OUT.glob('*_selections.csv')):
    if 'completed_high' in path.name:label='completed_high'
    elif 'current_high' in path.name or 'paper_time_high' in path.name:label='current_high'
    else:label='low'
    with (data/label/'budget_snapshot.csv').open(newline='') as handle:
        budget=list(csv.DictReader(handle))
    with path.open(newline='') as handle:
        selected=list(csv.DictReader(handle))
    assert len(selected)==10
    for row in selected:
        step=int(row['step']);stamp=float(row['time_years'])
        assert abs(stamp-float(budget[step]['time_years']))<1e-7
        assert Path(row['source']).is_file()
    selection_checks.append(dict(file=path.name,states=10,all_times_match_actual_budget_rows=True))

for label in budget_sources:
    with (data/label/'budget_snapshot.csv').open(newline='') as handle:
        rows=list(csv.DictReader(handle))
    times=np.array([float(r['time_years']) for r in rows]);assert times[0]==0 and np.all(np.diff(times)>0)
    initial=float(rows[0]['melt_shell_m3'])
    for row in rows:
        assert abs(float(row['melt_shell_m3'])+float(row['delivered_net_m3'])+
                   float(row['refrozen_net_shell_m3'])-initial)<.02

solver=Path(provenance['main_high_run'])/'runtime/model_and_dependencies/darcy_stokes_2D_cases.m'
solver_sha=hashlib.sha256(solver.read_bytes()).hexdigest()
assert solver_sha=='16dcab8b484d6751dfdb263fccd546a5c72bc40d03519e8d6eab2ed4bcc7f667'
for name in ['plot_Europa_paper_figures.m','polish_Europa_paper_figures.m','finalize_Europa_paper_figures.py']:
    shutil.copy2(ROOT/'model_and_dependencies'/name,OUT/name)
verification=dict(passed=True,figures=reports,selected_state_checks=selection_checks,
    data_interpolation=False,main_high_solver_sha256=solver_sha,live_solver_unchanged=True,
    plot_status='Visually reviewed all eight final figures' if '--visual-reviewed' in sys.argv else 'Rendered; visual review still required',
    pressure_accuracy_tested=False)
verification['svg_font_families']={p.name:sorted(set(re.findall(r"font-family:'([^']+)'",p.read_text())))
    for p in OUT.glob('0*.svg')}
(OUT/'verification.json').write_text(json.dumps(verification,indent=2))

font=ImageFont.truetype('C:/Windows/Fonts/times.ttf',18)
sheet=Image.new('RGB',(1600,4*410),'#eeeeee');draw=ImageDraw.Draw(sheet)
for i,report in enumerate(reports):
    im=Image.open(report['png']);im.thumbnail((775,365))
    x=(i%2)*800+12;y=(i//2)*410+12
    sheet.paste(im,(x,y));draw.text((x,y+372),report['figure'],font=font,fill='black')
sheet.save(OUT/'contact_sheet.png')

README=f'''Manuscript-style Europa figures

Reference: Impact_melt_foundering (1).pdf, Figures 4-7 and caption-described semilog Figure S4.
All eight figures are in Europa_manuscript_style_figures.pdf. Individual PNG, SVG,
and editable MATLAB FIG versions are alongside it. Times New Roman is used.

01 Figure 4: two completed Europa endpoint volumes (kc=1.85e-16 and 1.85e-8),
   plus the model permeability curves. Titan points, empirical permeability
   scatter, confidence bands and unavailable error bars are omitted.
02 Figure 5: theoretical foundering/infiltration contours, not additional runs.
   Uses manuscript equations 9-11 and the explicit archived model constants in
   Figure5_theory_parameters.json. Simulation-location dots are omitted because
   a unique corresponding mean ice temperature is not defined for these runs.
03 Figure 6: actual corrected evolution times, original three-row strip design.
   Row (a) is completed low-kc Europa; row (b) is unavailable; row (c) is the
   ongoing fresh high-kc run through its available checkpoints.
04 Figure 6: original paper time requests, showing the first actual checkpoint
   at/after each request. Actual times, not requested times, are printed.
05 Figure 7: shell melt volume and penetration depth on twin coloured axes.
   Display windows: (a) 0-1500 years; (c) 0-500 years. Data are retained intact.
06 Figure S4: the same available histories on semilog time axes.
07 Completed reference histories: includes the earlier completed high-kc run,
   rather than substituting its uncomputed future into the ongoing fresh run.
08 Net downward delivery and signed net shell refreezing histories.

The main current-run history was frozen at step {provenance['main_high_cutoff_step']},
time {provenance['main_high_cutoff_years']:.12g} years for this figure pack. New
simulation output can continue without changing these snapshot data files.

Sources and exact timestamp selections are in plot_provenance.json, data/ and
the selection CSVs. selected_fields/ retains the actual displayed T/phi arrays.
The plotting script adapts the colormaps/composition of Europa_video_creation.m
and the existing saved-time and permeability-comparison plotters. The simulation
source, boundaries, time stepping and field arrays are never changed.

No temporal interpolation, field smoothing, synthetic simulation states or
extrapolation. Image colours are display mappings of actual cell values;
field panels have no added temperature-band outlines. Theoretical
Figure 5 evaluates continuous equations on an explicitly generated grid.
Straight segments in time-history curves connect recorded diagnostic samples.
Timestamp labels are rounded for display; the CSVs retain full precision.

The paper's phi threshold was not explicitly specified. These corrected depth
curves use the established saved threshold phi>=0.001 and 100-m cell centres:
maximum shell penetration is 9.95 km, not an invented 10 km. Net refreezing
includes initial phase equilibration and is freezing minus new melting.
Pressure reproducibility/physical front convergence remain outside these
plotting checks. These are new corrected results in the manuscript's style,
not a claim of numerical agreement with the old manuscript.

To regenerate from this repository in MATLAB:
addpath('model_and_dependencies'); plot_Europa_paper_figures
Then run model_and_dependencies/finalize_Europa_paper_figures.py using the
bundled Python runtime. The latest output/build directories are recorded in
ignored tmp/manuscript_figures_latest.json.
'''
(OUT/'README.txt').write_text(README)
file_hashes={p.relative_to(OUT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
             for p in OUT.rglob('*') if p.is_file() and p.name!='artifact_hashes.json'}
(OUT/'artifact_hashes.json').write_text(json.dumps(file_hashes,indent=2))
print(json.dumps(dict(output=str(OUT),pdf=str(combined),pages=len(pages),verification=str(OUT/'verification.json'))))
