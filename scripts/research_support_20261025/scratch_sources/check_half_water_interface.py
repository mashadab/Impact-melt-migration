"""Read-only interface and volume-flux check of the newest saved state."""
from pathlib import Path
import ctypes as c
import json
import os
import numpy as np

root=Path(__file__).resolve().parents[1]
out=Path((root/'tmp/half_water_1yr_output.txt').read_text(encoding='utf-8-sig').strip())
path=sorted((out/'states').glob('state_*.mat'))[-1]
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
f=mat.matOpen(str(path).encode(),b'r');assert f
r=mat.matGetVariable(f,b'checkpoint');assert r
gptr=field(field(r,'Grid'),'p')
g={key:array(gptr,key) for key in ['Nx','Ny','Nfx','xf','xc','yf','yc','dx','dy']}
a={key:array(r,key) for key in ['phi','T_dimensionless','solid_velocity_m_s',
 'darcy_flux_m_s','time_years','flow_time_years','completed_steps','d_m']}
mx.mxDestroyArray(r);assert mat.matClose(f)==0
nx,ny=int(g['Nx'][0]),int(g['Ny'][0]);nfx=int(g['Nfx'][0]);d=float(a['d_m'][0]);yr=3.154e7
v=a['solid_velocity_m_s']*yr;q=a['darcy_flux_m_s']*yr
vx=v[:nfx].reshape(ny,nx+1,order='F');vz=v[nfx:].reshape(ny+1,nx,order='F')
qx=q[:nfx].reshape(ny,nx+1,order='F');qz=q[nfx:].reshape(ny+1,nx,order='F')
phi=a['phi'].reshape(ny,nx,order='F');z=g['yc']*d
iz=int(np.argmin(abs(g['yf']*d-4000)))
dx=float(g['dx'][0]*d);dz=float(g['dy'][0]*d)
divv=np.diff(vx,axis=1)/dx+np.diff(vz,axis=0)/dz
divq=np.diff(qx,axis=1)/dx+np.diff(qz,axis=0)/dz
below=z<4000;upper=z>4000
report={
 'checkpoint':path.name,'step':int(a['completed_steps'][0]),
 'endpoint_years':float(a['time_years'][0]),'flow_time_years':float(a['flow_time_years'][0]),
 'interface_max_abs_vs_m_per_year':float(max(abs(vz[iz]))),
 'interface_max_abs_q_m_per_year':float(max(abs(qz[iz]))),
 'interface_net_down_q_m3_per_year_per_m_depth':float(-sum(qz[iz])*dx),
 'max_abs_vs_interior_lower_half_m_per_year':float(max(np.max(abs(vx[below])),np.max(abs(vz[:iz+1])))),
 'max_abs_solid_divergence_lower_half_per_year':float(np.max(abs(divv[below]))),
 'max_abs_mixture_divergence_per_year':float(np.max(abs(divv+divq))),
 'max_phi_lower_half':float(np.max(phi[below])),
 'max_horizontal_phi_range':float(np.max(np.ptp(phi,axis=1))),
 'max_upper_vs_plus_q_m_per_year':float(np.max(abs((vz+qz)[iz+1:]))),
 'max_abs_T_change_K':float(np.max(abs(a['T_dimensionless']*173+100-273))),
 'note':'Actual archived flow precedes endpoint phi. No modified solve or interpolated data.'}
target=out/'figures';target.mkdir(exist_ok=True)
(target/f'interface_check_step_{report["step"]:08d}.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
