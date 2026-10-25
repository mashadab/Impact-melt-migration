"""Plot an actual completed checkpoint of the cold-bottom test, without interpolation."""
from pathlib import Path
import ctypes as c
import json
import os
import sys
import time
import hashlib
import numpy as np
from PIL import Image
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import pypdfium2 as pdfium

root=Path(__file__).resolve().parents[1]
out=Path(sys.argv[1]) if len(sys.argv)>1 else Path((root/'tmp/centered_cold_bottom_output.txt').read_text().strip())
files=sorted(p for p in (out/'states').glob('state_*.mat') if p.stat().st_size>0 and time.time()-p.stat().st_mtime>2)
assert files,'No complete saved checkpoint is available yet.'
path=files[-1]
bindir=Path('C:/Program Files/MATLAB/R2022b/bin/win64')
dll_dir=os.add_dll_directory(str(bindir))
mat=c.CDLL(str(bindir/'libmat.dll'));mx=c.CDLL(str(bindir/'libmx.dll'))
mat.matOpen.argtypes=[c.c_char_p,c.c_char_p];mat.matOpen.restype=c.c_void_p
mat.matGetVariable.argtypes=[c.c_void_p,c.c_char_p];mat.matGetVariable.restype=c.c_void_p
mat.matClose.argtypes=[c.c_void_p];mat.matClose.restype=c.c_int
mx.mxGetField.argtypes=[c.c_void_p,c.c_size_t,c.c_char_p];mx.mxGetField.restype=c.c_void_p
mx.mxGetNumberOfElements.argtypes=[c.c_void_p];mx.mxGetNumberOfElements.restype=c.c_size_t
mx.mxGetPr.argtypes=[c.c_void_p];mx.mxGetPr.restype=c.POINTER(c.c_double)
mx.mxDestroyArray.argtypes=[c.c_void_p]
def field(p,name):
    value=mx.mxGetField(p,0,name.encode());assert value,name;return value
def array(p,name):
    value=field(p,name);n=mx.mxGetNumberOfElements(value)
    return np.ctypeslib.as_array(mx.mxGetPr(value),shape=(n,)).copy()
def scalar(p,name):return float(array(p,name)[0])
def open_variable(file,name):
    f=mat.matOpen(str(file).encode(),b'r');assert f,file
    p=mat.matGetVariable(f,name.encode());assert p,name
    return f,p

f,state=open_variable(path,'checkpoint')
grid=field(field(state,'Grid'),'p');nx=int(scalar(grid,'Nx'));ny=int(scalar(grid,'Ny'))
d=scalar(state,'d_m');step=int(scalar(state,'step'));years=scalar(state,'time_years')
x=array(grid,'xc')*d/1000;z=array(grid,'yc')*d/1000;V=array(grid,'V')*d*d
phi=array(state,'phi').reshape(ny,nx,order='F')
temp=(array(state,'T_dimensionless')*173+100).reshape(ny,nx,order='F')
H=array(state,'H')
diagnostic=field(state,'diagnostic');row=field(diagnostic,'row')
keys=['liquid_lower_m3_per_m_depth','lower_cumulative_net_liquid_import_m3_per_m_depth',
 'lower_effective_net_refrozen_m3_per_m_depth','domain_net_liquid_loss_m3_per_m_depth',
 'lower_bulk_heat_cumulative_J_per_m_depth','lower_Darcy_heat_cumulative_J_per_m_depth',
 'lower_conductive_heat_cumulative_J_per_m_depth','lower_enthalpy_change_J_per_m_depth',
 'lower_T_mean_K','lower_warmed_over_0p01K_cells','lower_liquid_cells','max_H_reconstruction_error',
 'cumulative_enthalpy_reconstruction_error','relative_enthalpy_error']
facts={key:scalar(row,key) for key in keys}
budget=field(field(diagnostic,'cold_bottom'),'budget')
Hreconstructed=array(budget,'initial_H')+array(budget,'cumulative_dH_bulk')+array(budget,'cumulative_dH_Darcy')+array(budget,'cumulative_dH_conduction')
assert np.max(np.abs(H-Hreconstructed))<1e-8
mx.mxDestroyArray(state);assert mat.matClose(f)==0
f,initial=open_variable(out/'initial_state.mat','initial_state')
phi0=array(initial,'phi').reshape(ny,nx,order='F');T0=array(initial,'T_K').reshape(ny,nx,order='F')
mx.mxDestroyArray(initial);assert mat.matClose(f)==0
X,Z=np.meshgrid(x,z);lower=Z<4
lower_liquid=float(np.sum(phi.ravel(order='F')[(Z<4).ravel(order='F')]*V[(Z<4).ravel(order='F')]))
assert abs(lower_liquid-facts['liquid_lower_m3_per_m_depth'])<1e-6
assert np.all(np.isfinite(phi)) and np.all(np.isfinite(temp))
assert phi.min()>=0 and phi.max()<=1
wet=lower & (phi>1e-8)
facts.update(step=step,time_years=years,source_checkpoint=str(path),source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
 deepest_liquid_cell_center_z_km=float(z[np.where(wet)[0]].min()) if wet.any() else None,
 temperature_min_K=float(temp.min()),temperature_max_K=float(temp.max()),
 interpretation='Fixed-grid heat and liquid inventories; effective net refreezing is not an independent gross physical freezing rate.',
 data_interpolation=False,font='Times New Roman')
if wet.any():facts['liquid_cell_center_penetration_below_z4_m']=(4-facts['deepest_liquid_cell_center_z_km'])*1000
net_adv=facts['lower_bulk_heat_cumulative_J_per_m_depth']+facts['lower_Darcy_heat_cumulative_J_per_m_depth']
facts['net_advected_heat_into_lower_J_per_m_depth']=net_adv
facts['conduction_fraction_of_net_heat_into_lower']=facts['lower_conductive_heat_cumulative_J_per_m_depth']/facts['lower_enthalpy_change_J_per_m_depth']

folder=out/'figures';folder.mkdir(exist_ok=True)
stem=f'cold_bottom_result_step_{step:08d}'
pdf=folder/(stem+'.pdf');png=folder/(stem+'.png')
pdfmetrics.registerFont(TTFont('TimesNR','C:/Windows/Fonts/times.ttf'))
pdfmetrics.registerFont(TTFont('TimesNRBold','C:/Windows/Fonts/timesbd.ttf'))
cv=canvas.Canvas(str(pdf),pagesize=(940,735))
cv.setTitle(f'Cold-bottom centered body: initial and {years:.6g} years')
def text(x,y,value,size=12,bold=False,color='#172f43',align='left'):
    cv.setFont('TimesNRBold' if bold else 'TimesNR',size);cv.setFillColor(color)
    if align=='center':cv.drawCentredString(x,y,value)
    else:cv.drawString(x,y,value)
def colors(values,lo,hi,a,b):
    v=np.clip((values-lo)/(hi-lo),0,1)[...,None]
    return np.round(np.asarray(a)*(1-v)+np.asarray(b)*v).astype(np.uint8)
text(42,701,'Cold-bottom centered body | initial and saved result',23,True)
text(42,678,f'kc = 1.85e-8 m2 | step {step:,} | saved state at {years:.6f} years | target 100 years',13)
width=330;height=198
for col,left in enumerate([72,527]):
    text(left,649,'Liquid fraction' if col==0 else 'Temperature [K]',17,True)
    for row_index,bottom in enumerate([423,156]):
        values=(phi0 if row_index==0 else phi) if col==0 else (T0 if row_index==0 else temp)
        if col==0:rgb=colors(values,0,1,[238,243,245],[35,136,184])
        else:rgb=colors(values,253.15,273,[50,92,159],[239,151,63])
        cv.drawImage(ImageReader(Image.fromarray(rgb[::-1].copy())),left,bottom,width,height)
        cv.setStrokeColorRGB(.12,.18,.23);cv.setLineWidth(.65);cv.rect(left,bottom,width,height,fill=0,stroke=1)
        px=lambda value:left+value/20*width
        py=lambda value:bottom+(value+2)/12*height
        cv.setDash(4,3);cv.line(left,py(4),left+width,py(4));cv.setDash()
        for tick in [0,5,10,15,20]:
            xx=px(tick);cv.line(xx,bottom,xx,bottom-4);text(xx,bottom-18,str(tick),10.5,align='center')
        for tick in [-2,0,4,10]:
            yy=py(tick);cv.line(left-4,yy,left,yy);text(left-13,yy-3.5,str(tick),10.5,align='center')
        text(left+width/2,bottom-36,'x [km]',11,align='center')
        cv.saveState();cv.translate(left-40,bottom+height/2);cv.rotate(90);text(0,0,'z [km]',11,align='center');cv.restoreState()
        text(left,bottom+height+9,'Initial: 0 years' if row_index==0 else f'Saved: {years:.4f} years',12,True)
        if row_index==1:
            cv.setStrokeColorRGB(.05,.12,.17);cv.setDash(2,2)
            cv.rect(px(5),py(4),width/2,height/2,stroke=1,fill=0);cv.setDash()
    # The color bar uses the same continuous mapping as the actual cell pixels.
    gradient=np.linspace(0,1,200).reshape(200,1)
    if col==0:bar=colors(gradient,0,1,[238,243,245],[35,136,184]);labels=['0','0.5','1']
    else:bar=colors(gradient,0,1,[50,92,159],[239,151,63]);labels=['253.15','263.08','273']
    cv.drawImage(ImageReader(Image.fromarray(bar[::-1].copy())),left+width+12,156,9,198)
    for fraction,label in zip([0,.5,1],labels):text(left+width+25,156+198*fraction-3.5,label,10)
text(42,87,f'Liquid below z = 4 km: {lower_liquid/1e6:.3f} million m3 per m depth | domain net liquid loss: {facts["domain_net_liquid_loss_m3_per_m_depth"]/1e6:.3f} million m3 per m depth',11.5)
text(42,64,'Dashed lines mark the initial temperature boundary and original water-body outline.',11)
text(42,43,'Actual saved cells, no field or time interpolation | Times New Roman | closed and insulated walls',11)
text(42,22,'Net liquid loss is consistent with effective refreezing in this discrete model; front spreading is included.',10)
cv.showPage();cv.save()
doc=pdfium.PdfDocument(pdf);page=doc[0];page.render(scale=180/72).to_pil().save(png);page.close();doc.close()
facts.update(png=str(png),pdf=str(pdf))
(folder/(stem+'.json')).write_text(json.dumps(facts,indent=2))
(folder/'latest_result.json').write_text(json.dumps(facts,indent=2))
print(json.dumps(facts,indent=2))
