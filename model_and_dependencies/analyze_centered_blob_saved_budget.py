"""Read actual saved step diagnostics using MATLAB's MAT-file library."""
from pathlib import Path
import ctypes as c
import csv
import json
import os
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=Path((ROOT/'tmp/centered_continuation_output.txt').read_text(encoding='utf-8-sig').strip())
bindir=Path(r'C:\Program Files\MATLAB\R2022b\bin\win64')
dll_dir=os.add_dll_directory(str(bindir))
mat=c.CDLL(str(bindir/'libmat.dll'));mx=c.CDLL(str(bindir/'libmx.dll'))
mat.matOpen.argtypes=[c.c_char_p,c.c_char_p];mat.matOpen.restype=c.c_void_p
mat.matGetVariable.argtypes=[c.c_void_p,c.c_char_p];mat.matGetVariable.restype=c.c_void_p
mat.matClose.argtypes=[c.c_void_p];mat.matClose.restype=c.c_int
mx.mxGetField.argtypes=[c.c_void_p,c.c_size_t,c.c_char_p];mx.mxGetField.restype=c.c_void_p
mx.mxGetNumberOfElements.argtypes=[c.c_void_p];mx.mxGetNumberOfElements.restype=c.c_size_t
mx.mxGetPr.argtypes=[c.c_void_p];mx.mxGetPr.restype=c.POINTER(c.c_double)
mx.mxGetNumberOfFields.argtypes=[c.c_void_p];mx.mxGetNumberOfFields.restype=c.c_int
mx.mxGetFieldNameByNumber.argtypes=[c.c_void_p,c.c_int];mx.mxGetFieldNameByNumber.restype=c.c_char_p
mx.mxDestroyArray.argtypes=[c.c_void_p]
YEAR=3.154e7
def field(p,name):
    v=mx.mxGetField(p,0,name.encode());assert v,name;return v
def array(p,name):
    v=field(p,name);n=mx.mxGetNumberOfElements(v)
    return np.ctypeslib.as_array(mx.mxGetPr(v),shape=(n,)).copy()
def scalar_struct(p):
    return {mx.mxGetFieldNameByNumber(p,j).decode():float(array(p,mx.mxGetFieldNameByNumber(p,j).decode())[0])
            for j in range(mx.mxGetNumberOfFields(p))}
def read(path):
    f=mat.matOpen(str(path).encode(),b'r');assert f
    cp=mat.matGetVariable(f,b'checkpoint');assert cp
    g=field(field(cp,'Grid'),'p');a=field(cp,'diagnostic')
    grid={key:array(g,key) for key in ['Nx','Ny','Nfx','xc','yc','dx','dy']}
    data={key:array(a,key) for key in ['phi_before','phi_after','solid_velocity_m_s','darcy_flux_m_s',
      'carried_liquid_flux_m_s','solid_divergence_per_s','permeability_m2',
      'dH_bulk','dH_Darcy','dH_conduction','T_before_K','T_after_K']}
    data['row']=scalar_struct(field(a,'row'));data['sample']=scalar_struct(field(a,'newly_wet_sample'))
    data['d']=float(array(cp,'d_m')[0]);data['step']=int(array(cp,'step')[0]);
    data['time_years']=float(array(cp,'time_years')[0]);data['dt_years']=float(array(cp,'dt_years')[0])
    mx.mxDestroyArray(cp);assert mat.matClose(f)==0
    return grid,data

report={'definition':'Actual saved fields only. Flux volumes are per unit out-of-plane depth.',
 'scope':'Eulerian flux decomposition; bulk transport includes upwind numerical diffusion. Budget closure is not physical validation.'}
targets={'first':OUT/'verification_direct/states/state_00000001.mat'}
available=sorted((OUT/'states').glob('state_*.mat'))
if available:targets['latest']=available[-1]
proof=OUT/'analysis';proof.mkdir(exist_ok=True)
for label,path in targets.items():
    grid,a=read(path);nx,ny=int(grid['Nx'][0]),int(grid['Ny'][0]);nfx=int(grid['Nfx'][0]);d=a['d']
    phi0=a['phi_before'];phi1=a['phi_after'];X,Z=np.meshgrid(grid['xc']*d,grid['yc']*d)
    lower=Z.ravel(order='F')<4000
    candidates=np.flatnonzero(lower&(phi0==0)&(phi1>1e-8))
    if len(candidates):id=int(candidates[np.argmax(phi1[candidates])])
    else:id=int(np.flatnonzero(lower)[np.argmax(phi1[lower])])
    iz,ix=id%ny,id//ny
    faces=np.array([ix*ny+iz,(ix+1)*ny+iz,nfx+ix*(ny+1)+iz,nfx+ix*(ny+1)+iz+1])
    sign=np.array([1,-1,1,-1]);areas=np.array([grid['dy'][0],grid['dy'][0],grid['dx'][0],grid['dx'][0]])*d
    volume=float(grid['dx'][0]*grid['dy'][0]*d*d)
    rows=[]
    for j,name in enumerate(['left','right','bottom','top']):
        face=faces[j];v=a['solid_velocity_m_s'][face];adv=a['carried_liquid_flux_m_s'][face];q=a['darcy_flux_m_s'][face]
        rows.append({'face':name,'face_id':int(face+1),'permeability_m2':a['permeability_m2'][face],
          'solid_velocity_m_per_year':v*YEAR,'Darcy_flux_m_per_year':q*YEAR,
          'upwind_phi':adv/v if v!=0 else None,
          'Q_carried_into_m3_per_year_per_m_depth':sign[j]*adv*areas[j]*YEAR,
          'Q_Darcy_into_m3_per_year_per_m_depth':sign[j]*q*areas[j]*YEAR,
          'Q_mixture_into_m3_per_year_per_m_depth':sign[j]*(v+q)*areas[j]*YEAR,
          'Q_solid_into_m3_per_year_per_m_depth':sign[j]*(v-adv)*areas[j]*YEAR})
    sample={'cell_id':id+1,'x_m':float(X[iz,ix]),'z_m':float(Z[iz,ix]),
      'phi_before':float(phi0[id]),'phi_after':float(phi1[id]),'cell_volume_m3_per_m_depth':volume,
      'solid_dilation_per_year':float(a['solid_divergence_per_s'][id]*YEAR),
      'H_gain_bulk':float(a['dH_bulk'][id]),'H_gain_Darcy':float(a['dH_Darcy'][id]),
      'H_gain_conduction':float(a['dH_conduction'][id]),'faces':rows}
    sample['carried_prediction_delta_phi']=sum(r['Q_carried_into_m3_per_year_per_m_depth'] for r in rows)*a['dt_years']/volume
    sample['Darcy_prediction_delta_phi']=sum(r['Q_Darcy_into_m3_per_year_per_m_depth'] for r in rows)*a['dt_years']/volume
    report[label]={'source':str(path),'step':a['step'],'time_years':a['time_years'],
      'dt_years':a['dt_years'],'global':a['row'],'sample':sample}
    with (proof/f'{label}_sample_faces.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
(proof/'saved_flux_budget.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
