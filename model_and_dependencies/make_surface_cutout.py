"""Large photographic Europa surface, initial dome cutout and two data paths.

Original saved cell arrays are displayed directly. The photo/section assembly
is a contextual magnification, not a georeferenced crustal reconstruction.
"""
from pathlib import Path
import math,json,hashlib,sys,csv
import numpy as np
from PIL import Image
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.colors import Color,HexColor

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'Output/figure1_surface_cutout_20261029'
OUT.mkdir(parents=True,exist_ok=True)
ASSETS=ROOT/'Output/pdf/melt_percolation_mechanism/online_assets'
SOURCE=ROOT/'Output/Europa_paper_minimal_20261029_164901'
PREV=ROOT/'Output/figure1_big_picture_20261029'
sys.path.insert(0,str(ROOT/'model_and_dependencies'))
from preserve_Europa_paper_outputs import MatReader
reader=MatReader(Path('C:/Program Files/MATLAB/R2022b/bin/win64'))
sources=[]

def read(name):
    p=SOURCE/'selected_fields'/name
    h=reader.mat.matOpen(str(p).encode(),b'r');assert h
    v=reader.mat.matGetVariable(h,b's');assert v
    try:d={k:reader.array(reader.field(v,k)) for k in ['step','time_years','radius_km','elevation_km','phi','temperature_K']}
    finally:reader.mx.mxDestroyArray(v);reader.mat.matClose(h)
    for key in ['phi','temperature_K']:d[key]=d[key].reshape((120,100),order='F')
    assert np.isfinite(d['phi']).all() and d['phi'].min()>=0 and d['phi'].max()<=1
    sources.append(dict(file=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),step=int(d['step'][0]),time_years=float(d['time_years'][0])))
    np.savez_compressed(OUT/(p.stem+'.npz'),**d)
    return d

initial=read('e08_step_00000000.mat');initial_low=read('e16_step_00000000.mat')
assert np.array_equal(initial['phi'],initial_low['phi'])
assert np.array_equal(initial['temperature_K'],initial_low['temperature_K'])
low=[read(n) for n in ['e16_step_00002815.mat','e16_step_00007889.mat','e16_step_00011000.mat']]
high=[read(n) for n in ['e08_step_00003289.mat','e08_step_00006042.mat','e08_step_00009518.mat']]
ctl_low=np.load(PREV/'low_initial_arrays.npz');ctl_high=np.load(PREV/'high_initial_arrays.npz')
assert np.array_equal(ctl_low['phi0'],ctl_high['phi0'])
assert np.array_equal(ctl_low['H0'],ctl_high['H0'])

for name,file in [('Arial','arial.ttf'),('Arial-Bold','arialbd.ttf'),('Arial-Italic','ariali.ttf'),('Math','seguisym.ttf')]:
    pdfmetrics.registerFont(TTFont(name,'C:/Windows/Fonts/'+file))
W,H=183/25.4*72,170/25.4*72
FONT_SCALE=1.8
PHI='\u03d5'  # straight-stem phi, corresponding to TeX \\phi, not \\varphi
TEXT_BOUNDS=[]
c=canvas.Canvas(str(OUT/'compact_large_text_render.pdf'),pagesize=(W,H),initialFontName='Arial',initialFontSize=6,pageCompression=1)
c.setTitle('Europa: an initial impact-melt dome and permeability-dependent migration')
c.setAuthor('Impact-melt-migration; actual saved simulation fields and NASA imagery')
INK='#18313F';MUTED='#536D7C';RULE='#AFC1CC';BLUE='#137B9B';ORANGE='#B75B2D'

def text(x,y,s,size=6,bold=False,color=INK,align='left',italic=False):
    s=s.replace('\u03c6',PHI)
    size*=FONT_SCALE
    f='Arial-Bold' if bold else 'Arial-Italic' if italic else 'Arial'
    if any(ord(ch) not in pdfmetrics.getFont(f).face.charToGlyph for ch in s):f='Math'
    c.setFillColor(HexColor(color));c.setFont(f,size)
    if align=='center':c.drawCentredString(x,H-y,s)
    elif align=='right':c.drawRightString(x,H-y,s)
    else:c.drawString(x,H-y,s)
    width=pdfmetrics.stringWidth(s,f,size)
    left=x-width/2 if align=='center' else x-width if align=='right' else x
    TEXT_BOUNDS.append(dict(text=s,x0=left,x1=left+width,y0=y-.82*size,y1=y+.22*size,size_pt=size,font=f))

def rich(x,y,runs,size=6,align='left',color=INK):
    widths=[]
    for s,it,sc,dy in runs:
        s=s.replace('\u03c6',PHI)
        f='Arial-Italic' if it else 'Arial'
        if any(ord(ch) not in pdfmetrics.getFont(f).face.charToGlyph for ch in s):f='Math'
        widths.append(pdfmetrics.stringWidth(s,f,size*sc*FONT_SCALE))
    if align=='center':x-=sum(widths)/2
    if align=='right':x-=sum(widths)
    for (s,it,sc,dy),w in zip(runs,widths):text(x,y+dy*FONT_SCALE,s,size*sc,color=color,italic=it);x+=w

def line(x,y,xx,yy,color=RULE,lw=.5,dash=None):
    c.saveState();c.setStrokeColor(HexColor(color));c.setLineWidth(lw)
    if dash:c.setDash(dash)
    c.line(x,H-y,xx,H-yy);c.restoreState()

def rect(x,y,w,h,col,stroke=None,lw=.5):
    c.setFillColor(HexColor(col) if isinstance(col,str) else Color(*col))
    if stroke:c.setStrokeColor(HexColor(stroke));c.setLineWidth(lw)
    c.rect(x,H-y-h,w,h,fill=1,stroke=int(bool(stroke)))

def path(cmds,fill=None,stroke=None,lw=.5,dash=None):
    p=c.beginPath()
    for cmd in cmds:
        a=cmd[1:]
        if cmd[0]=='M':p.moveTo(a[0],H-a[1])
        elif cmd[0]=='L':p.lineTo(a[0],H-a[1])
        elif cmd[0]=='C':p.curveTo(a[0],H-a[1],a[2],H-a[3],a[4],H-a[5])
        else:p.close()
    c.saveState()
    if fill:c.setFillColor(HexColor(fill))
    if stroke:c.setStrokeColor(HexColor(stroke));c.setLineWidth(lw)
    if dash:c.setDash(dash)
    c.drawPath(p,fill=int(bool(fill)),stroke=int(bool(stroke)));c.restoreState();return p

def arrow(x,y,u,v,color=INK,lw=.55,head=2.7):
    length=math.hypot(u,v)
    if length<.45:return
    head=min(head,length*.45);a=math.atan2(v,u);xx=x+u-head*math.cos(a);yy=y+v-head*math.sin(a)
    line(x,y,xx,yy,color,lw)
    path([('M',x+u,y+v),('L',xx-head*.4*math.sin(a),yy+head*.4*math.cos(a)),
          ('L',xx+head*.4*math.sin(a),yy-head*.4*math.cos(a)),('Z',)],fill=color)

def curved_arrow(points,color=RULE,lw=.65,head=2.8):
    x,y,a,b,cc,d,e,f=points
    path([('M',x,y),('C',a,b,cc,d,e,f)],stroke=color,lw=lw)
    angle=math.atan2(f-d,e-cc)
    arrow(e-head*math.cos(angle),f-head*math.sin(angle),head*math.cos(angle),head*math.sin(angle),color,lw,head)

def gradient(cmds,colors,x1,y1,x2,y2):
    c.saveState();p=path(cmds);c.clipPath(p,stroke=0,fill=0)
    c.linearGradient(x1,H-y1,x2,H-y2,[HexColor(v) for v in colors]);c.restoreState()

def disc(x,y,r,fill=None,stroke=INK,lw=.5):
    if fill:c.setFillColor(HexColor(fill))
    c.setStrokeColor(HexColor(stroke));c.setLineWidth(lw)
    c.circle(x,H-y,r,fill=int(bool(fill)),stroke=1)

def phi_color(v):
    stops=np.array([0,.03,.25,.6,1.])
    cols=np.array([[250,252,253],[201,232,238],[112,194,212],[33,142,173],[3,77,107]])/255
    return tuple(np.interp(v,stops,cols[:,k]) for k in range(3))

def temp_color(v):
    a=np.clip((v-100)/173,0,1)
    return tuple(np.array([.55,.64,.70])*(1-a)+np.array([.98,.985,.99])*a)

def div_color(v):
    a=np.clip(float(v),-30,30)/30
    mid=np.array([.99,.99,.99]);end=np.array([.12,.40,.67]) if a<0 else np.array([.76,.29,.1])
    return tuple(mid+(end-mid)*abs(a))

def field(d,x,y,w,h,extent=(-8,8,-2,10),temperature=False,outline=True,base=True):
    rmin,rmax,zmin,zmax=extent
    X=lambda a:x+(a-rmin)/(rmax-rmin)*w
    Z=lambda a:y+(zmax-a)/(zmax-zmin)*h
    rr=d['radius_km'];zz=d['elevation_km'];phi=d['phi'];T=d['temperature_K']
    ix=np.flatnonzero(rr<rmax);iz=np.flatnonzero((zz>zmin)&(zz<zmax))
    # Original native cells, reflected only about the axis.
    for j in iz:
        for i in ix:
            v=float(phi[j,i]);col=phi_color(v)
            if v<1e-4:
                if not temperature:continue
                col=temp_color(float(T[j,i]))
            for sign in [-1,1]:rect(X(sign*rr[i]-.1),Z(zz[j]+.05),.2/(rmax-rmin)*w,.1/(zmax-zmin)*h,col)
    if outline:
        mask=phi>=1e-3
        for j in iz:
            for i in ix:
                if not mask[j,i]:continue
                for sign in [-1,1]:
                    xa,xb=X(sign*rr[i]-.1),X(sign*rr[i]+.1);ya,yb=Z(zz[j]+.05),Z(zz[j]-.05)
                    if i>0 and not mask[j,i-1]:line(xa if sign>0 else xb,ya,xa if sign>0 else xb,yb,'#87B4C6',.25)
                    if i==len(rr)-1 or not mask[j,i+1]:line(xb if sign>0 else xa,ya,xb if sign>0 else xa,yb,'#87B4C6',.25)
                    if j==0 or not mask[j-1,i]:line(xa,yb,xb,yb,'#87B4C6',.25)
                    if j==len(zz)-1 or not mask[j+1,i]:line(xa,ya,xb,ya,'#87B4C6',.25)
    if base and zmin<=0<=zmax:line(x,Z(0),x+w,Z(0),'#91A8B7',.45,dash=[2,1.5])
    return X,Z

# A broad real Europa surface. A display clip traces the observed illuminated
# limb, leaving the black space outside the photograph off the white page.
# This reads source pixels to define a clip; the image itself stays unchanged.
scale=284/1040
image_x=259-1148*scale;image_top=310-1170*scale
pixels=np.asarray(Image.open(ASSETS/'PIA19048_Europa.jpg').convert('RGB'))
limb=[]
for col in range(0,pixels.shape[1],6):
    bright=np.flatnonzero(np.max(pixels[:1100,col,:],axis=1)>42)
    if not len(bright):continue
    row=int(bright[0])+4
    xx=image_x+col*scale;yy=image_top+row*scale
    front_y=118+18*((xx-259)/237)**2
    if yy<front_y:limb.append((xx,yy))
assert len(limb)>100
front_points=[(xx,118+18*((xx-259)/237)**2) for xx,_ in limb]
surface=[('M',*limb[0])]+[('L',*p) for p in limb[1:]]+[('L',*p) for p in reversed(front_points)]+[('Z',)]
c.saveState();p=path(surface);c.clipPath(p,stroke=0,fill=0)
c.drawImage(str(ASSETS/'PIA19048_Europa.jpg'),image_x,H-image_top-1700*scale,2300*scale,1700*scale)
c.restoreState()
path([('M',*limb[0])]+[('L',*p) for p in limb[1:]],stroke='#9DAFB9',lw=.4)

# A thin global-context shell with the actual initial phase distribution.
# The shell/ocean geometry is conceptual; the original field is enlarged below.
ICE_THICKNESS_PT=12.0
OCEAN_THICKNESS_PT=9.0
shell=[('M',*front_points[0])]+[('L',*p) for p in front_points[1:]]+[
    ('L',xx,yy+ICE_THICKNESS_PT) for xx,yy in reversed(front_points)]+[('Z',)]
gradient(shell,['#EDF4F7','#C8DBE5'],155,125,370,158)
path(shell,stroke='#A4BAC6',lw=.45)
ocean=[('M',front_points[0][0],front_points[0][1]+ICE_THICKNESS_PT)]+[
    ('L',xx,yy+ICE_THICKNESS_PT) for xx,yy in front_points[1:]]+[
    ('L',xx,yy+ICE_THICKNESS_PT+OCEAN_THICKNESS_PT) for xx,yy in reversed(front_points)]+[('Z',)]
gradient(ocean,['#317D97','#0E4D6A'],90,136,430,158)
path([('M',front_points[0][0],front_points[0][1]+ICE_THICKNESS_PT)]+[
    ('L',xx,yy+ICE_THICKNESS_PT) for xx,yy in front_points[1:]],stroke='#6394AC',lw=.4)
field(initial,248,118,22,11,extent=(-4,4,6,10),temperature=False,outline=False,base=False)
text(259,105,'Initial melt pool',6.3,bold=True,color=INK,align='center')
line(259,108,259,116.5,INK,.45)
text(177,156,'Thin ice shell',5.7,color=MUTED,align='right')
line(181,153,187,126,RULE,.45)
text(347,160,'Ocean',5.7,bold=True,color='#12546F')
line(343,153,331,134,RULE,.45)

text(10,15,'a',8,bold=True)
text(25,15,'Impact melt beneath Europa’s surface',7,bold=True)
text(95,108,'Europa',7.2,bold=True,color='#FFFFFF')

# Observed crater strip: separate context, with no geographic location pin.
text(15,34,'Mannann’an crater',6.5,bold=True,color=INK)
c.saveState();pp=c.beginPath();pp.rect(15,H-61,124,21);c.clipPath(pp,stroke=0,fill=0)
c.translate(12,H-54);c.rotate(14.4);ss=124/785
c.drawImage(str(ASSETS/'PIA01402_Mannannan.jpg'),-125*ss,-430*ss,1042*ss,643*ss)
c.restoreState()
line(15,61,139,61,'#B7C7D0',.45)
# Approximate footprint calibration. NASA describes the observed strip as
# ~18 km along its long axis. Use its native long-edge endpoints, then the
# exact uniform display scale; neither canvas width nor black margins enter.
CRATER_SOURCE_LONG_EDGE=((154,95),(975,307))
CRATER_FOOTPRINT_LENGTH_KM=18.0
CRATER_BAR_KM=5.0
crater_long_px=math.hypot(CRATER_SOURCE_LONG_EDGE[1][0]-CRATER_SOURCE_LONG_EDGE[0][0],
                         CRATER_SOURCE_LONG_EDGE[1][1]-CRATER_SOURCE_LONG_EDGE[0][1])
crater_bar_pt=CRATER_BAR_KM/CRATER_FOOTPRINT_LENGTH_KM*crater_long_px*ss
line(17,70,17+crater_bar_pt,70,INK,1.1)
line(17,68.5,17,71.5,INK,.7);line(17+crater_bar_pt,68.5,17+crater_bar_pt,71.5,INK,.7)
text(23+crater_bar_pt,72,'~5 km',5.8,color=INK)

# A separate magnification of the initial pool. Leaders explain the change
# in scale; no giant cross-section is physically attached to the thin shell.
c.saveState();c.setStrokeColor(HexColor('#7897A9'));c.setLineWidth(.5)
c.ellipse(241,H-132,277,H-113,stroke=1,fill=0);c.restoreState()
line(245,129,174,176,'#8AA3B3',.55,dash=[2,1.7])
line(273,129,344,176,'#8AA3B3',.55,dash=[2,1.7])
rect(171,176,176,94,'#EDF4F8',stroke='#9EB6C4',lw=.5)
text(259,167,'Initial condition · t = 0',6.7,bold=True,align='center')

# The magnified initial condition retains the actual temperature background.
Xi,Zi=field(initial,174,179,170,85,extent=(-4,4,6,10),temperature=True,outline=True,base=False)
line(184,260,226.5,260,INK,.8);line(184,258.5,184,261.5,INK,.6);line(226.5,258.5,226.5,261.5,INK,.6)
text(205.25,255,'2 km',5,color=INK,align='center')

# Two branches follow exactly the same starting phase distribution.
curved_arrow((171,223,144,223,132,226,110,226),RULE,.7)
curved_arrow((347,223,374,223,386,226,408,226),RULE,.7)
text(8,170,'b',8,bold=True);text(26,170,'Low permeability',6.7,bold=True)
text(386,170,'c',8,bold=True);text(404,170,'High permeability',6.7,bold=True)
for x,exp in [(68,'−16'),(450,'−8')]:
    rich(x,184,[('k',True,1,0),('c',True,.72,1.3),(' = 1.85 × 10',False,1,0),
              (exp,False,.72,-2),(' m²',False,1,0)],5.8,align='center')

snapshot_boxes=[]
for case,x,seq in [('low',36,low),('high',418,high)]:
    for n,(y,zmin,d) in enumerate(zip([207,280,380],[3.5,0,-2],seq)):
        t=float(d['time_years'][0])
        h=(10-zmin)*8
        text(x+32,y-8,f'{t:.1f} yr',6.1,bold=True,align='center')
        X,Z=field(d,x,y,64,h,extent=(-4,4,zmin,10),temperature=False,outline=True)
        snapshot_boxes.append(dict(case=case,time_years=t,box_pt=[x,y,64,h],extent_km=[-4,4,zmin,10]))
        if n==2:line(x,y+h,x+64,y+h,'#91A8B7',.45)
        if n==1:
            if case=='low':
                text(120,Z(0)-4,'Shell base',5.1,color=MUTED)
                line(x+64,Z(0),120,Z(0),RULE,.4)
            else:
                text(398,Z(0)-4,'Shell base',5.1,color=MUTED,align='right')
                line(398,Z(0),x,Z(0),RULE,.4)

# Depth ruler and shared scale for the evolution windows.
for x in [27,492]:
    line(x,380,x,460,INK,.4)
    for depth in [0,5,10]:
        yy=380+depth*8
        line(x-1.5,yy,x+1.5,yy,INK,.4)
        text(x-3 if x<100 else x+3,yy+1.6,str(depth),5.1,color=MUTED,align='right' if x<100 else 'left')
for x,angle in [(10,90),(508,-90)]:
    c.saveState();c.translate(x,H-428);c.rotate(angle)
    c.setFont('Arial',5.1*FONT_SCALE);c.setFillColor(HexColor(MUTED));c.drawCentredString(0,0,'Depth (km)');c.restoreState()
line(123,250,155,250,INK,.75);line(123,248.5,123,251.5,INK,.5);line(155,248.5,155,251.5,INK,.5)
text(139,246,'4 km',5,color=MUTED,align='center')

# Compact shared legends fit in the central space beneath the initial dome.
text(174,284,'Melt fraction φ',5.3,color=INK)
for i in range(256):rect(269+i*73/256,277,73/256+.002,6,phi_color(i/255))
for a,s in [(0,'0'),(.5,'0.5'),(1,'1')]:text(269+a*73,294,s,5,color=MUTED,align='center')
text(174,307,'Ice temperature (K)',5.3,color=INK)
for i in range(256):rect(269+i*73/256,300,73/256+.002,6,temp_color(100+i/255*173))
text(269,317,'100',5,color=MUTED,align='center');text(342,317,'273',5,color=MUTED,align='center')

# The mechanism remains tied to actual saved flow/dilation fields.
text(168,339,'d',8,bold=True)
text(259,339,'Convergent liquid flow',6.2,bold=True,align='center')
text(259,353,'dilates ice',6.2,bold=True,align='center')

def mechanism(x,y,w,h):
    X=lambda r:x+(r+4)/8*w;Z=lambda z:y+(10-z)/4*h
    YEAR=3.154e7
    for d,sign in [(ctl_low,-1),(ctl_high,1)]:
        phi=d['phi0'].reshape((120,100),order='F');C=d['C'].reshape((120,100),order='F')*YEAR
        rr=d['cell_r_m'].reshape((120,100),order='F')[0]/1000
        zz=d['cell_z_m'].reshape((120,100),order='F')[:,0]/1000
        qx=d['q'][:12120].reshape((120,101),order='F')*YEAR
        qz=d['q'][12120:].reshape((121,100),order='F')*YEAR
        rf=d['face_r_m'][:12120].reshape((120,101),order='F')[0]/1000
        zf=d['face_z_m'][12120:].reshape((121,100),order='F')[:,0]/1000
        wet=(phi>=1e-4)&(phi<=.9);wetx=wet[:,:-1]&wet[:,1:];wetz=wet[:-1]&wet[1:]
        for j,z in enumerate(zz):
            if not 6<z<10:continue
            for i,r in enumerate(rr):
                if r>=4:continue
                col=div_color(C[j,i]) if wet[j,i] else '#E5EDF1' if phi[j,i]>.9 else '#FFFFFF'
                rect(X(sign*r-.1),Z(z+.05),.2/8*w,.1/4*h,col)
        for j,z in enumerate(zz):
            if not 6<z<10:continue
            for i,r in enumerate(rf[1:-1],start=1):
                if r<4 and wetx[j,i-1]:arrow(X(sign*r),Z(z),sign*qx[j,i]*.003,0,INK,.4,1.5)
        for j,z in enumerate(zf[1:-1],start=1):
            if not 6<z<10:continue
            for i,r in enumerate(rr):
                if r<4 and wetz[j-1,i]:arrow(X(sign*r),Z(z),0,-qz[j,i]*.003,INK,.4,1.5)
    line(X(0),y,X(0),y+h,RULE,.35,dash=[1.2,1.5])
    return X,Z

Xm,Zm=mechanism(182,371,154,77)
text(346,436,'φ ↑ → k ↑',5.7,bold=True,color=ORANGE,align='right')
line(309,426,Xm(1.3),Zm(7.15),ORANGE,.4)
rich(220,366,[('Low ',False,1,0),('k',True,1,0),('c',True,.72,1.1)],5.8,align='center')
rich(298,366,[('High ',False,1,0),('k',True,1,0),('c',True,.72,1.1)],5.8,align='center')
text(234,451,'Compaction',5.1,bold=True,color='#2167AB',align='center')
text(292,451,'Dilation',5.1,bold=True,color=ORANGE,align='center')
for i in range(256):rect(205+i*116/256,455,116/256+.002,4,div_color(-30+i/255*60))
rich(190,459,[('∇·',False,1,0),('v',True,1,0),('i',True,.72,1.1)],5.4,align='right')
for a,s in [(0,'−30'),(.5,'0'),(1,'30')]:text(205+a*116,467,s,5,color=MUTED,align='center')
rich(328,457,[('(yr',False,1,0),('−1',False,.72,-2),(')',False,1,0)],5.1)
arrow(214,476,6,0,INK,.4,1.5)
rich(225,478,[('q',True,1,0),(': 2,000 m yr',False,1,0),('−1',False,.72,-2)],5.2)

c.showPage();c.save()

provenance=dict(output='Europa_compact_large_text.png',page_mm=[183,170],dpi=600,
    context=dict(ice_thickness_pt=ICE_THICKNESS_PT,ocean_thickness_pt=OCEAN_THICKNESS_PT,
        small_initial_pool='Actual saved initial melt-fraction cells, reflected about axis; 22 pt wide by 11 pt high crop, no temperature shading; separated from ocean by ice',
        magnification='Selection ellipse and paired dashed leaders connect the small context pool to the saved initial-condition field',
        initial_plot_box_pt=[174,179,170,85],initial_temperature_retained=True,geometry_is_schematic=True),
    typography=dict(font_scale=FONT_SCALE,minimum_main_type_pt=5*FONT_SCALE,
                    phi_unicode='U+03D5',phi_form='TeX phi (straight-stem form), not varphi'),
    crater_scale=dict(approximate=True,bar_km=CRATER_BAR_KM,bar_length_pt=crater_bar_pt,
         footprint_length_km=CRATER_FOOTPRINT_LENGTH_KM,source_long_edge_pixels=CRATER_SOURCE_LONG_EDGE,
         source_long_edge_length_px=crater_long_px,uniform_display_scale_pt_per_source_px=ss,
         source='https://science.nasa.gov/missions/europa-clipper/europa-clipper-resources/mannannan-crater/',
         calibration='NASA approximate 18 km long footprint, native long-edge pixel length and exact uniform display scale. Display rotation preserves lengths.'),
    data_sources=sources,initial_phi_and_T_identical=True,
    snapshot_boxes=snapshot_boxes,evolution_extent_km=dict(horizontal=[-4,4],elevation_by_row=[[3.5,10],[0,10],[-2,10]],points_per_km=8),
    initial_extent_km=dict(horizontal=[-4,4],elevation=[6,10]),
    scale_bars=dict(initial_km=2,initial_length_pt=42.5,evolution_km=4,evolution_length_pt=32),
    temperature_range_K=[100,273],phi_range=[0,1],native_cell_size_m=[200,100],
    rendering='Native cells. Reflection about the axis only. No field interpolation or smoothing.',
    outline='Cell-edge contour at phi >= 1e-3; cells with phi < 1e-4 omitted from evolution windows.',
    mechanism=dict(sources=[str(PREV/f'{k}_initial_arrays.npz') for k in ['low','high']],
        extent_km=dict(horizontal=[-4,4],elevation=[6,10]),C_range_per_year=[-30,30],
        colour_bar_labels=dict(negative='Compaction',positive='Dilation'),
        arrow_scale_pt_per_m_year=.003,case_comparison='Low solution reflected on left, high solution on right; not an asymmetric calculation.'),
    photos=[dict(file=str(ASSETS/'PIA19048_Europa.jpg'),sha256=hashlib.sha256((ASSETS/'PIA19048_Europa.jpg').read_bytes()).hexdigest(),credit='NASA/JPL-Caltech/SETI Institute'),
       dict(file=str(ASSETS/'PIA01402_Mannannan.jpg'),sha256=hashlib.sha256((ASSETS/'PIA01402_Mannannan.jpg').read_bytes()).hexdigest(),credit='NASA/JPL/University of Arizona')],
    geometry='Photographic setting, thin schematic ice shell and ocean, with the saved initial melt blob linked to its magnified field including temperature. Not georeferenced or to planetary scale. Individual evolution windows are separate snapshots, not simultaneous melt bodies.',
    AI_art=False,research_solver_modified=False,new_research_solve=False)
(OUT/'figure_provenance_compact_large_text.json').write_text(json.dumps(provenance,indent=2),encoding='utf-8')
(OUT/'text_bounds_compact_large_text.json').write_text(json.dumps(TEXT_BOUNDS,indent=2),encoding='utf-8')
print(OUT/'compact_large_text_render.pdf')
