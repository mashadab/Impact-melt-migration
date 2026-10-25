from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import difflib
import hashlib
import json
import shutil

root=Path(__file__).resolve().parents[1]
stamp=datetime.now(ZoneInfo('America/New_York')).strftime('%Y%m%d_%H%M%S')
center=Path((root/'tmp/centered_water_100yr_output.txt').read_text().strip())
original=Path(json.loads((center/'configuration.json').read_text(encoding='utf-8-sig'))['frozen_source_dir'])
launch=root/'tmp'/('flat_centered_videos_'+stamp)
frozen=launch/'flat_source';frozen.mkdir(parents=True)
for path in original.glob('*.m'):shutil.copy2(path,frozen/path.name)
parent=(original/'darcy_stokes_2D_cases.m').read_text()
assert hashlib.sha256((original/'darcy_stokes_2D_cases.m').read_bytes()).hexdigest()=='16dcab8b484d6751dfdb263fccd546a5c72bc40d03519e8d6eab2ed4bcc7f667'
old="""    phiGr=double(Y>(Grid.p.ymin+Grid.p.ymax)/2 & ...
        X>Grid.p.xmin+0.25*(Grid.p.xmax-Grid.p.xmin) & ...
        X<Grid.p.xmin+0.75*(Grid.p.xmax-Grid.p.xmin));"""
assert parent.count(old)==1
modified=parent.replace(old,'    phiGr=double(Y>(Grid.p.ymin+Grid.p.ymax)/2); % flat upper-half initialization')
(frozen/'darcy_stokes_2D_cases.m').write_text(modified,newline='\n')
helper=frozen/'centered_blob_diagnostics.m'
text=helper.read_text();old_dry='initial_dry=~(X(:)>5000 & X(:)<15000 & Z(:)>4000);'
assert text.count(old_dry)==1
helper.write_text(text.replace(old_dry,'initial_dry=Z(:)<=4000; % diagnostic mask for flat upper-half initial condition'),newline='\n')
start='        %% Bouyancy force as the body force to Stokes flow'
end='        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5'
block=lambda text:text[text.index(start):text.index(end)+len(end)]
assert block(parent)==block(modified)
out=root/'Output'/('flat_and_centered_S3_videos_'+stamp)
out.mkdir();shutil.copy2(original/'darcy_stokes_2D_cases.m',out/'centered_parent_source.m.txt')
(out/'flat_initialization_only.diff').write_text(''.join(difflib.unified_diff(parent.splitlines(True),modified.splitlines(True),fromfile='corrected_centered_parent',tofile='corrected_flat_variant')))
files=sorted((center/'states').glob('state_*.mat'))
assert len(files)>2
# Exclude the newest file in case MATLAB is currently writing it.
files=files[:-1]
config=dict(centered_run=str(center),flat_frozen_source=str(frozen),output_dir=str(out),
 centered_files=[str(f) for f in files],kc_m2=1.85e-8,permeability_exponent=3,
 flat_physical_change='initial phi mask only; x restriction removed',
 diagnostic_change='initially dry mask follows flat initialization',
 flow_and_transport_block_identical=True,
 flat_source_sha256=hashlib.sha256((frozen/'darcy_stokes_2D_cases.m').read_bytes()).hexdigest(),
 centered_source_sha256=hashlib.sha256((original/'darcy_stokes_2D_cases.m').read_bytes()).hexdigest(),
 note='Shared case_key remains centered_water as the solver family; flat variant is identified by its archived initial mask and this configuration.')
(out/'configuration.json').write_text(json.dumps(config,indent=2))
(root/'tmp/flat_centered_video_output.txt').write_text(str(out))
script=f"addpath('{(root/'model_and_dependencies').as_posix()}');\nmake_flat_and_centered_water_videos('{out.as_posix()}');\n"
(launch/'start_videos.m').write_text(script)
(root/'tmp/flat_centered_video_launcher.txt').write_text(str(launch/'start_videos.m'))
print(json.dumps({'output_dir':str(out),'launcher':str(launch/'start_videos.m'),'centered_saved_states':len(files),'cutoff_state':files[-1].name},indent=2))
