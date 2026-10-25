from pathlib import Path
import hashlib
import json
import shutil
import zipfile
import xml.etree.ElementTree as E

B=Path(__file__).resolve().parent
m=json.loads((B/'materials.json').read_text())
out=Path(m['output']);deck=out/'Melt_migration_tests_and_mechanisms.pptx'
assert deck.is_file()
sources={Path(v['path']).name:hashlib.sha256(Path(v['path']).read_bytes()).hexdigest() for v in m['videos']}
with zipfile.ZipFile(deck) as z:
    embedded={n:hashlib.sha256(z.read(n)).hexdigest() for n in z.namelist() if n.startswith('ppt/media/') and n.lower().endswith('.mp4')}
    assert len(embedded)==7
    assert set(embedded.values())==set(sources.values()),'Embedded movies differ from standalone files'
    notes=[n for n in z.namelist() if n.startswith('ppt/notesSlides/notesSlide') and n.endswith('.xml')]
    assert len(notes)==27
    for n in notes:
        text=' '.join(E.fromstring(z.read(n)).itertext())
        assert 'Sources' in text
report=json.loads((B/'powerpoint_final_verification.json').read_text(encoding='utf-8-sig'))
assert len(report['slides'])==27 and len(report['movies'])==7
assert report['native_chart_count']==5 and report['native_table_count']==7
for slide in report['slides']:assert slide['notes_characters']>300
verification=dict(deck=str(deck),sha256=hashlib.sha256(deck.read_bytes()).hexdigest(),
 embedded_video_count=7,embedded_videos_match_standalone_files=True,native_powerpoint_opened_and_rendered=True,
 all_27_slides_visually_reviewed=True,source_notes_on_all_slides=True,
 standalone_videos=sources,embedded_media=embedded,playback_visually_tested=False)
(B/'handoff_verification.json').write_text(json.dumps(verification,indent=2))

readme='''Melt migration tests and mechanisms

The PowerPoint contains 27 slides with speaker notes, original result figures,
editable tables and quantitative charts, and seven embedded MP4 movies.

Open the PPTX in PowerPoint. In Slide Show, click a movie to play it.
Movie slides: 5 (wave), 8 (Europa), 13 (geometry), 17 (warm/cold centered).
The separate videos folder and ZIP provide standalone copies of the same movie bytes.

The seven movies cover:
1. Porosity wave, 0-800 simulated years.
2. Europa, kc=1.85e-8 m2, to the shell-depletion threshold.
3. Europa, kc=1.85e-16 m2, to the same depletion threshold.
4. Corrected flat water layer, to 8.893 years (two actual states).
5. Corrected centered water body, to 8.893 years (107 actual states).
6. Warm centered body, to 100 years (996 actual states including initial).
7. Cold-bottom centered body, to 100 years (1025 actual states including initial).

Movies use actual saved fields held between states. No numerical field or
simulation time is interpolated. Each movie retains its own recorded clock.
The two Europa cases and the warm/cold cases have distinct adaptive time steps.
The analytic reference on the wave benchmark figure uses a translated reference
interpolant, while the accompanying numerical movie uses the original saved AVI frames.

Speaker notes contain the methods, scientific discussion, assumptions, precise
source run folders, and limits. Use PowerPoint's Notes pane or Notes Page view.

Units matter: Europa volumes are full axisymmetric km3. Cartesian box volumes
are m3 per metre of out-of-plane depth. The warm initial temperature is 273 K,
approximately 0 C. The cold lower half is 253.15 K (-20 C), and the model retains
its original 273 K melting point.

The appendix distinguishes earlier runs with a known reference-force bias from
the corrected results. A reproducible numerical budget does not establish a
converged physical invasion speed or spontaneous pore nucleation in dry ice.
'''
(out/'README.txt').write_text(readme)
(out/'videos'/'README.txt').write_text(readme)
zip_path=out/'Research_simulation_videos.zip'
with zipfile.ZipFile(zip_path,'w') as z:
    for p in sorted((out/'videos').iterdir()):
        if p.is_file():z.write(p,arcname='videos/'+p.name,compress_type=zipfile.ZIP_STORED if p.suffix=='.mp4' else zipfile.ZIP_DEFLATED)
with zipfile.ZipFile(zip_path) as z:assert z.testzip() is None
figures=out/'figures';figures.mkdir(exist_ok=True)
for key,value in m['assets'].items():shutil.copy2(value,figures/(key+'.png'))
shutil.copy2(B/'slide_index.json',out/'slide_sources.json')
print(json.dumps(dict(powerpoint=str(deck),powerpoint_bytes=deck.stat().st_size,
 videos_zip=str(zip_path),videos_zip_bytes=zip_path.stat().st_size,slides=27,embedded_movies=7),indent=2))
