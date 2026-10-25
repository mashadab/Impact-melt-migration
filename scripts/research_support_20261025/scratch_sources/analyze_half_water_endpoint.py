from pathlib import Path
import json
import numpy as np
import ctypes as c
import os

root=Path(__file__).resolve().parents[1]
out=root/'Output/half_water_closed_20261024_172613'
# Read the existing MAT v5 file with MATLAB's read-only MAT-file library.
# No scipy installation or additional solver run is needed.
bindir=Path(r'C:\Program Files\MATLAB\R2022b\bin\win64')
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
    v=mx.mxGetField(p,0,name.encode());assert v,name;return v
def array(p,name):
    v=field(p,name);n=mx.mxGetNumberOfElements(v)
    return np.ctypeslib.as_array(mx.mxGetPr(v),shape=(n,)).copy()
f=mat.matOpen(str(out/'noflow_kc_1.850e-08.mat').encode(),b'r');assert f
r=mat.matGetVariable(f,b'result');assert r
state=field(r,'final_state');grid=field(field(state,'Grid'),'p')
s={name:array(state,name) for name in ['phi','v_s_dimensionless','q_r_dimensionless']}
g={name:array(grid,name) for name in ['Nx','Ny','Nfx','xf','xc','yf','yc']}
mx.mxDestroyArray(r);assert mat.matClose(f)==0
d=10000.;yr=3.154e7
scale=3.3/(920*(185+7.037*273))/d
v=np.asarray(s['v_s_dimensionless'])*scale*yr
q=np.asarray(s['q_r_dimensionless'])*scale*yr
nx,ny=int(g['Nx'][0]),int(g['Ny'][0]);nfx=int(g['Nfx'][0])
phi=np.asarray(s['phi']).reshape(ny,nx,order='F')
fx=np.zeros((ny,nx+1),bool);fy=np.zeros((ny+1,nx),bool)
fx[:,1:-1]=(phi[:,:-1]>1-1e-12)&(phi[:,1:]>1-1e-12)
fy[1:-1,:]=(phi[:-1,:]>1-1e-12)&(phi[1:,:]>1-1e-12)
water_faces=np.r_[fx.ravel(order='F'),fy.ravel(order='F')]
def location(i):
    if i<nfx:
        iz,ix=i%ny,i//ny
        return {'component':'x','x_km':float(g['xf'][ix]*10),
                'z_km':float(g['yc'][iz]*10)}
    j=i-nfx;iz,ix=j%(ny+1),j//(ny+1)
    return {'component':'z','x_km':float(g['xc'][ix]*10),
            'z_km':float(g['yf'][iz]*10)}
i=int(np.argmax(abs(v)));j=int(np.argmax(abs(q)))
report={
 'max_vs_location':location(i),'max_vs_m_per_year':float(v[i]),
 'q_at_max_vs_m_per_year':float(q[i]),
 'mixture_flux_at_max_vs_m_per_year':float(v[i]+q[i]),
 'max_q_location':location(j),'max_q_m_per_year':float(q[j]),
 'max_abs_vs_on_internal_pure_water_faces_m_per_year':float(max(abs(v[water_faces]))),
 'max_abs_q_on_internal_pure_water_faces_m_per_year':float(max(abs(q[water_faces]))),
 'max_abs_mixture_flux_on_internal_pure_water_faces_m_per_year':float(max(abs((v+q)[water_faces]))),
 'max_abs_mixture_flux_everywhere_m_per_year':float(max(abs(v+q))),
 'scope':'Endpoint phi labels identify pure-water faces within 1e-12. Archived flow precedes the final thermodynamic update. No altered forcing or solver rerun.'}
(out/'endpoint_flow_check.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
