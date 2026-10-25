"""Plot the actual saved initial MAT fields, with Times New Roman labels."""
from pathlib import Path
import ctypes as c
import json
import os
import sys
import numpy as np
from PIL import Image
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import pypdfium2 as pdfium

root=Path(__file__).resolve().parents[1]
out=Path(sys.argv[1]) if len(sys.argv)>1 else Path((root/'tmp/centered_cold_bottom_output.txt').read_text().strip())
path=out/'initial_state.mat'
assert path.is_file(),f'Initial state has not yet been saved: {path}'
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
    value=field(p,name);size=mx.mxGetNumberOfElements(value)
    return np.ctypeslib.as_array(mx.mxGetPr(value),shape=(size,)).copy()
f=mat.matOpen(str(path).encode(),b'r');assert f
state=mat.matGetVariable(f,b'initial_state');assert state
grid=field(field(state,'Grid'),'p')
nx=int(array(grid,'Nx')[0]);ny=int(array(grid,'Ny')[0]);d=float(array(state,'d_m')[0])
x=array(grid,'xc')*d;z=array(grid,'yc')*d
phi=array(state,'phi').reshape(ny,nx,order='F')
temp=array(state,'T_K').reshape(ny,nx,order='F')
H=array(state,'H').reshape(ny,nx,order='F')
mx.mxDestroyArray(state);assert mat.matClose(f)==0
X,Z=np.meshgrid(x,z);lower=Z<4000
assert nx==100 and ny==120
assert np.array_equal(phi,((X>5000)&(X<15000)&(Z>4000)).astype(float))
assert np.max(np.abs(temp[lower]-253.15))<1e-10
assert np.all(temp[~lower]==273)
assert np.all(H[lower]<0) and np.all(phi[lower]==0)
fig=out/'figures';fig.mkdir(exist_ok=True)
pdfmetrics.registerFont(TTFont('TimesNR','C:/Windows/Fonts/times.ttf'))
pdfmetrics.registerFont(TTFont('TimesNRBold','C:/Windows/Fonts/timesbd.ttf'))
pdf=fig/'cold_bottom_initial_condition.pdf'
cv=canvas.Canvas(str(pdf),pagesize=(900,470))
cv.setTitle('Centered body: actual initial condition, cold bottom half')
def text(x,y,value,size=12,bold=False,color='#172f43',align='left'):
    cv.setFont('TimesNRBold' if bold else 'TimesNR',size);cv.setFillColor(color)
    if align=='center':cv.drawCentredString(x,y,value)
    else:cv.drawString(x,y,value)
text(42,435,'Centered water body | cold bottom half',24,True)
text(42,410,'Initial state at t = 0 years; actual saved 100 x 120 grid cells',13)
def colors(values,lo,hi,a,b):
    v=np.clip((values-lo)/(hi-lo),0,1)[...,None]
    return np.round(np.asarray(a)*(1-v)+np.asarray(b)*v).astype(np.uint8)
phi_rgb=colors(phi,0,1,[238,243,245],[35,136,184])
temp_rgb=colors(temp,253.15,273,[50,92,159],[239,151,63])
bottom=165;width=325;height=195
for k,(left,rgb,title) in enumerate([(67,phi_rgb,'Liquid fraction'),(502,temp_rgb,'Temperature [K]')]):
    text(left,bottom+height+22,title,17,True)
    image=Image.fromarray(rgb[::-1].copy())
    cv.drawImage(ImageReader(image),left,bottom,width,height,mask='auto')
    cv.setStrokeColorRGB(.15,.2,.25);cv.setLineWidth(.7);cv.rect(left,bottom,width,height,fill=0,stroke=1)
    def px(xkm):return left+xkm/20*width
    def py(zkm):return bottom+(zkm+2)/12*height
    cv.setDash(4,3);cv.setStrokeColorRGB(.1,.1,.1);cv.line(left,py(4),left+width,py(4));cv.setDash()
    for tick in [0,5,10,15,20]:
        xx=px(tick);cv.line(xx,bottom,xx,bottom-4);text(xx,bottom-19,str(tick),11,align='center')
    for tick in [-2,0,4,10]:
        yy=py(tick);cv.line(left-4,yy,left,yy);text(left-12,yy-4,str(tick),11,align='center')
    text(left+width/2,bottom-39,'x [km]',12,align='center')
    cv.saveState();cv.translate(left-39,bottom+height/2);cv.rotate(90);text(0,0,'z [km]',12,align='center');cv.restoreState()
    if k==0:
        text(px(10),py(7),'Water: phi = 1',13,True,color='#ffffff',align='center')
        text(px(10),py(1),'Ice: phi = 0',13,True,align='center')
        text(px(2.5),py(7),'Ice',11,align='center')
        text(px(17.5),py(7),'Ice',11,align='center')
    else:
        text(px(10),py(7),'273 K',16,True,align='center')
        text(px(10),py(1),'253.15 K (-20 C)',16,True,color='#ffffff',align='center')
text(42,89,'Water body: x = 5-15 km; z = 4-10 km. The entire bottom half starts as cold, dry ice.',12)
text(42,66,'Closed and insulated walls | kc = 1.85e-8 m2 | permeability exponent = 3 | target = 100 years',12)
text(42,43,'Temperature is initialized once and then evolves. Original model melting temperature: 273 K.',11)
text(42,23,'Times New Roman | each plotted pixel is an actual grid cell; no field interpolation',10)
cv.showPage();cv.save()
doc=pdfium.PdfDocument(pdf);page=doc[0];im=page.render(scale=180/72).to_pil()
png=fig/'cold_bottom_initial_condition.png';im.save(png);page.close();doc.close()
report=dict(source=str(path),png=str(png),pdf=str(pdf),mesh=[nx,ny],temperature_K=sorted(np.unique(temp).tolist()),
    phi_values=sorted(np.unique(phi).tolist()),bottom_initially_dry=True,initial_state_checks_passed=True,
    font='Times New Roman',data_interpolation=False)
(fig/'initial_figure_verification.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
