from pathlib import Path
import ctypes as c
import csv
import json
import os
import shutil
import sys
import numpy as np
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2]
BUILD=Path(__file__).resolve().parent
OUT=ROOT/'Output/research_presentation_20261025'
for path in [OUT/'videos',BUILD/'assets',BUILD/'posters',BUILD/'renders']:
    path.mkdir(parents=True,exist_ok=True)
def js(path):return json.loads(path.read_text(encoding='utf-8-sig'))
comparison=Path((ROOT/'tmp/centered_warm_cold_audit_output.txt').read_text().strip())
assets={
 'wave':ROOT/'Output/Jake_2D_minimal_800_years_actual_kappa_head_reference/live_comparison/comparison_2D_wave_zoom.png',
 'wave_1d':ROOT/'Output/Jake_2D_minimal_800_years_actual_kappa_head_reference/live_comparison/comparison_1D.png',
 'dry_cell':ROOT/'Output/Europa_simple_explanation_20261024/01_dry_cell_sketch.png',
 'dilation':ROOT/'Output/Europa_dilation_evidence_20261024/initial_wet_cell_dilation_budget.png',
 'flat_mechanism':ROOT/'Output/flat_and_centered_S3_videos_20261024_221928/mechanism_figures_times/01_flat_layer_mechanism.png',
 'center_mechanism':ROOT/'Output/flat_and_centered_S3_videos_20261024_221928/mechanism_figures_times/02_centered_body_mechanism.png',
 'initial_cold':ROOT/'Output/centered_cold_bottom_S3_100yr_20261025_073337/figures/cold_bottom_initial_condition.png',
 'profiles':comparison/'01_centered_warm_cold_profiles_100yr.png',
 'conduction':comparison/'02_conduction_role_centered_cold.png',
 'front_resolution':ROOT/'Output/Europa_regularization_audit_20261024/dry_front_transport_resolution.png',
 'pressure_control':ROOT/'Output/centered_blob_continuation_20261024_210127/analysis/forcing_control/pressure_reference_control.png',
 'legacy_flat':ROOT/'Output/half_water_1yr_20261024_190211/advisor/initial_vs_last_saved.png',
 'boundary_checks':ROOT/'Output/closed_lid_1000_steps/closed_lid_checks.png',
}
for name,p in assets.items():assert p.is_file(),p
# Separate panels retain all axis ticks and titles relevant to the shown quantity.
im=Image.open(assets['profiles']);w,h=im.size
for name,box in [('warm_map',(50,190,1000,840)),('cold_map',(1120,190,2150,840))]:
    target=BUILD/'assets'/f'{name}.png';im.crop(box).save(target);assets[name]=target
im=Image.open(assets['conduction'])
target=BUILD/'assets/conduction_map.png';im.crop((110,180,1110,930)).save(target);assets['conduction_map']=target

video_specs=[
 dict(key='wave',title='Porosity wave',file='01_porosity_wave_800yr.mp4',source_avi=str(ROOT/'Output/Jake_2D_minimal_800_years_actual_kappa_head_reference/s3_melt_temperature.avi'),end_years=800),
 dict(key='europa_high',title='Europa, kc = 1.85e-8 m2',file='02_Europa_kc_1p85e-8.mp4',source=str(ROOT/'Output/Europa_kc_1.850e-08_until_depleted_20261023_195524/research_video/Europa_impact_melt_migration_1080p.mp4'),poster_source=str(ROOT/'Output/Europa_kc_1.850e-08_until_depleted_20261023_195524/research_video/preview_transfer.png'),end_years=3587.457897520297),
 dict(key='europa_low',title='Europa, kc = 1.85e-16 m2',file='03_Europa_kc_1p85e-16.mp4',source=str(ROOT/'Output/Europa_kc_1.850e-16_until_depleted_20261024_085440/research_video/Europa_impact_melt_migration_1080p.mp4'),poster_source=str(ROOT/'Output/Europa_kc_1.850e-16_until_depleted_20261024_085440/research_video/preview_transfer.png'),end_years=47138.2460495),
 dict(key='flat',title='Flat layer',file='04_flat_layer_8p893yr.mp4',source=str(ROOT/'Output/flat_and_centered_S3_videos_20261024_221928/videos/flat_layer_corrected.mp4'),poster_source=str(ROOT/'Output/flat_and_centered_S3_videos_20261024_221928/videos/flat_layer_corrected_preview_0002.png'),end_years=8.89348313212041),
 dict(key='center_short',title='Centered body',file='05_centered_body_8p893yr.mp4',source=str(ROOT/'Output/flat_and_centered_S3_videos_20261024_221928/videos/centered_water_corrected.mp4'),poster_source=str(ROOT/'Output/flat_and_centered_S3_videos_20261024_221928/videos/centered_water_corrected_preview_0107.png'),end_years=8.89348313212041),
 dict(key='warm',title='Centered body, warm initial state',file='06_centered_warm_100yr.mp4',run=str(ROOT/'Output/centered_water_S3_100yr_20261024_214605'),end_years=100),
 dict(key='cold',title='Centered body, cold bottom half',file='07_centered_cold_bottom_100yr.mp4',run=str(ROOT/'Output/centered_cold_bottom_S3_100yr_20261025_073337'),end_years=100),
]
for spec in video_specs:
    spec['path']=str(OUT/'videos'/spec['file']);spec['poster']=str(BUILD/'posters'/f"{spec['key']}.png")
    if 'source' in spec:shutil.copy2(spec['source'],spec['path'])
    if 'poster_source' in spec:shutil.copy2(spec['poster_source'],spec['poster'])

manifest=dict(root=str(ROOT),build=str(BUILD),output=str(OUT),comparison=str(comparison),assets={k:str(v) for k,v in assets.items()},videos=video_specs,
 europa=js(ROOT/'Output/Europa_permeability_comparison_20261024/comparison.json'),
 cold_warm=js(comparison/'comparison.json'),
 frozen=js(ROOT/'Output/centered_water_permeability_proof_20261024_215923/permeability_proof.json'),
 face=js(ROOT/'Output/Europa_face_flux_proof_20261024/face_flux_proof.json'),
 dilation=js(ROOT/'Output/Europa_dilation_evidence_20261024/dilation_evidence.json'),
 regularization=js(ROOT/'Output/Europa_regularization_audit_20261024/regularization_audit.json'),
 flat_center=js(ROOT/'Output/flat_and_centered_S3_videos_20261024_221928/video_comparison.json'))
with (comparison/'center_profiles_100yr.csv').open(newline='') as f:
    manifest['profiles']=[{k:float(v) for k,v in r.items()} for r in csv.DictReader(f)]
(BUILD/'materials.json').write_text(json.dumps(manifest,indent=2))
print('MATERIALS_READY',len(assets),'figures',len(video_specs),'videos',flush=True)
if '--frames' not in sys.argv:sys.exit(0)

BIN=Path('C:/Program Files/MATLAB/R2022b/bin/win64');DLL=os.add_dll_directory(str(BIN))
MAT=c.CDLL(str(BIN/'libmat.dll'));MX=c.CDLL(str(BIN/'libmx.dll'))
MAT.matOpen.argtypes=[c.c_char_p,c.c_char_p];MAT.matOpen.restype=c.c_void_p
MAT.matGetVariable.argtypes=[c.c_void_p,c.c_char_p];MAT.matGetVariable.restype=c.c_void_p
MAT.matClose.argtypes=[c.c_void_p];MAT.matClose.restype=c.c_int
MX.mxGetField.argtypes=[c.c_void_p,c.c_size_t,c.c_char_p];MX.mxGetField.restype=c.c_void_p
MX.mxGetNumberOfElements.argtypes=[c.c_void_p];MX.mxGetNumberOfElements.restype=c.c_size_t
MX.mxGetPr.argtypes=[c.c_void_p];MX.mxGetPr.restype=c.POINTER(c.c_double)
MX.mxDestroyArray.argtypes=[c.c_void_p]
def field(p,n):q=MX.mxGetField(p,0,n.encode());assert q,n;return q
def arr(p,n):
    q=field(p,n);size=MX.mxGetNumberOfElements(q);return np.ctypeslib.as_array(MX.mxGetPr(q),shape=(size,)).copy()
def read_state(path,key):
    f=MAT.matOpen(str(path).encode(),b'r');assert f,path
    p=MAT.matGetVariable(f,key.encode());assert p,key
    values={n:arr(p,n) for n in ['phi','T_dimensionless']}
    if key=='checkpoint':values.update(step=int(arr(p,'step')[0]),time=float(arr(p,'time_years')[0]))
    else:values.update(step=0,time=0.)
    MX.mxDestroyArray(p);assert MAT.matClose(f)==0
    return values
fontfile='C:/Windows/Fonts/times.ttf';boldfile='C:/Windows/Fonts/timesbd.ttf'
fonts={n:ImageFont.truetype(fontfile,n) for n in [18,21,24,26,30]};bolds={n:ImageFont.truetype(boldfile,n) for n in [24,30,34]}
navy=(23,52,74);gray=(75,87,98)
def color(values,lo,hi,a,b):
    v=np.clip((values-lo)/(hi-lo),0,1)[...,None]
    return np.round(np.asarray(a)*(1-v)+np.asarray(b)*v).astype(np.uint8)
def make_frame(spec,s):
    phi=s['phi'].reshape(120,100,order='F');T=(s['T_dimensionless']*173+100).reshape(120,100,order='F')
    im=Image.new('RGB',(1280,720),'white');draw=ImageDraw.Draw(im)
    draw.text((45,22),spec['title'],font=bolds[34],fill=navy)
    draw.text((45,70),'Corrected S3 solver, Cartesian closed box, kc = 1.85e-8 m2, k = kc phi3',font=fonts[21],fill=gray)
    draw.text((45,108),f"Actual time: {s['time']:.5f} years    Computed step: {s['step']:,}",font=bolds[24],fill=navy)
    for col,(values,title,lo,hi,a,b) in enumerate([
      (phi,'Liquid fraction',0,1,[238,243,245],[35,136,184]),
      (T,'Temperature [K]',253.15,273,[50,92,159],[239,151,63])]):
        left=85+col*625;top=215;width=460;height=276
        draw.text((left,167),title,font=bolds[24],fill=navy)
        rgb=color(values,lo,hi,a,b);image=Image.fromarray(rgb[::-1].copy()).resize((width,height),Image.Resampling.NEAREST)
        im.paste(image,(left,top));draw.rectangle((left,top,left+width,top+height),outline=navy,width=1)
        y4=top+height/2
        for xx in range(left,left+width,10):draw.line((xx,y4,min(xx+5,left+width),y4),fill=(50,50,50),width=1)
        for tick in [0,5,10,15,20]:
            xx=left+tick/20*width;draw.line((xx,top+height,xx,top+height+5),fill=navy)
            draw.text((xx,top+height+10),str(tick),font=fonts[18],anchor='mt',fill=navy)
        for tick in [-2,0,4,10]:
            yy=top+(10-tick)/12*height;draw.line((left-4,yy,left,yy),fill=navy)
            draw.text((left-12,yy),str(tick),font=fonts[18],anchor='rm',fill=navy)
        draw.text((left+width/2,top+height+36),'x [km]',font=fonts[21],anchor='mt',fill=navy)
        draw.text((left-55,top+height/2),'z [km]',font=fonts[18],anchor='mm',fill=navy)
        grad=np.tile(np.linspace(lo,hi,width),(12,1));im.paste(Image.fromarray(color(grad,lo,hi,a,b)),(left,565))
        for fraction,val in [(0,lo),(.5,(lo+hi)/2),(1,hi)]:
            draw.text((left+fraction*width,581),f'{val:g}',font=fonts[18],anchor='mt',fill=navy)
    lower=phi[:60,:].sum()*20000;total=phi.sum()*20000
    draw.text((45,625),f'Liquid below z = 4 km: {lower/1e6:.3f} million m3/m    Domain net liquid loss: {(60e6-total)/1e6:.3f} million m3/m',font=fonts[21],fill=navy)
    draw.text((45,664),'Every frame uses an actual saved state. Repeated frames hold that state. No field or time interpolation.',font=fonts[18],fill=gray)
    draw.text((45,692),'Same regularized rheology. Model melting point 273 K. Dashed line marks the initial temperature boundary.',font=fonts[18],fill=gray)
    return im

for spec in video_specs:
    if 'run' not in spec:continue
    folder=Path(spec['run']);states=sorted((folder/'states').glob('state_*.mat'))
    frames=BUILD/('frames_'+spec['key']);frames.mkdir(exist_ok=True)
    s0=read_state(folder/'initial_state.mat','initial_state');items=[dict(source=str(folder/'initial_state.mat'),**s0)]
    # Iterate one checkpoint at a time to keep memory bounded.
    manifest_rows=[]
    for j,path in enumerate([None]+states):
        s=s0 if path is None else read_state(path,'checkpoint')
        assert np.isfinite(s['phi']).all() and np.isfinite(s['T_dimensionless']).all()
        png=frames/f'frame_{j:05d}.png';make_frame(spec,s).save(png,compress_level=2)
        manifest_rows.append(dict(png=str(png),source=str(folder/'initial_state.mat') if path is None else str(path),step=s['step'],actual_time_years=s['time']))
        if j%100==0 or j==len(states):print('FRAME',spec['key'],j,'/',len(states),'t',s['time'],flush=True)
    times=np.array([r['actual_time_years'] for r in manifest_rows]);assert times[0]==0 and times[-1]==100 and np.all(np.diff(times)>0)
    anchors=np.rint(times/100*60*24).astype(int)
    repeats=np.maximum(1,np.diff(anchors)).tolist()+[72];repeats[0]+=48
    for r,reps in zip(manifest_rows,repeats):r['frame_repetitions']=reps
    with (BUILD/f"{spec['key']}_frame_manifest.csv").open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(manifest_rows[0]));w.writeheader();w.writerows(manifest_rows)
    spec['frame_manifest']=str(BUILD/f"{spec['key']}_frame_manifest.csv")
    spec['saved_states']=len(times);spec['frames']=sum(repeats);spec['fps']=24;spec['data_interpolation']=False
    poster_index=int(np.searchsorted(times,50));shutil.copy2(manifest_rows[poster_index]['png'],spec['poster'])
    shutil.copy2(BUILD/f"{spec['key']}_frame_manifest.csv",OUT/'videos'/f"{spec['key']}_frame_manifest.csv")
    (BUILD/'materials.json').write_text(json.dumps(manifest,indent=2))
print('ALL_MOVIE_FRAMES_READY',flush=True)
