"""Read-only comparison of completed Europa runs; no interpolated states."""
import csv
import ctypes as c
import hashlib
import json
import os
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'Output/Europa_permeability_comparison_20261024'
OUT.mkdir(exist_ok=True)
RUNS={
 'high':ROOT/'Output/Europa_kc_1.850e-08_until_depleted_20261023_195524',
 'low':ROOT/'Output/Europa_kc_1.850e-16_until_depleted_20261024_085440'}
YEAR=3.154e7  # exact seconds/year used by the simulation's saved time
bindir=Path(r'C:\Program Files\MATLAB\R2022b\bin\win64')
dll_dir=os.add_dll_directory(str(bindir))
h=c.CDLL(str(bindir/'hdf5.dll'));hid=c.c_longlong
h.H5open.restype=c.c_int;assert h.H5open()>=0
signatures={
 'H5Fopen':([c.c_char_p,c.c_uint,hid],hid),
 'H5Dopen2':([hid,c.c_char_p,hid],hid),
 'H5Dget_space':([hid],hid),
 'H5Sget_simple_extent_ndims':([hid],c.c_int),
 'H5Sget_simple_extent_dims':([hid,c.POINTER(c.c_ulonglong),c.POINTER(c.c_ulonglong)],c.c_int),
 'H5Dread':([hid,hid,hid,hid,hid,c.c_void_p],c.c_int),
 'H5Fclose':([hid],c.c_int),'H5Dclose':([hid],c.c_int),'H5Sclose':([hid],c.c_int)}
for name,(args,result) in signatures.items():
 fn=getattr(h,name);fn.argtypes=args;fn.restype=result
native=hid.in_dll(h,'H5T_NATIVE_DOUBLE_g').value

class State:
 def __init__(self,path):
  self.f=h.H5Fopen(str(path).encode(),0,0);assert self.f>=0
 def read(self,name):
  d=h.H5Dopen2(self.f,('/state/'+name).encode(),0);assert d>=0,name
  space=h.H5Dget_space(d);rank=h.H5Sget_simple_extent_ndims(space)
  dims=(c.c_ulonglong*rank)();h.H5Sget_simple_extent_dims(space,dims,None)
  a=np.empty(int(np.prod(list(dims))),dtype=np.float64)
  assert h.H5Dread(d,native,0,0,0,a.ctypes.data_as(c.c_void_p))>=0
  h.H5Sclose(space);h.H5Dclose(d);return a
 def close(self):h.H5Fclose(self.f)

def budget(path):
 with path.open() as f: rows=list(csv.DictReader(f))
 return {key:np.array([float(row[key]) for row in rows]) for key in rows[0]}

report={'definition':'Net downward liquid transfer across z=0; actual saved flow states only',
 'flux_decomposition':'Darcy term is integrated directly from saved qr and annular areas. Solid-carried term = exact CSV transfer increment/time minus Darcy term.',
 'seconds_per_year':YEAR,'runs':{}}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
configs=[json.loads((r/'run_configuration.json').read_text()) for r in RUNS.values()]
report['differing_options']=sorted(k for k in configs[0] if configs[0][k]!=configs[1][k])
assert report['differing_options']==['kc','output_dir']
assert len({sha(r/'source/darcy_stokes_2D_cases.m') for r in RUNS.values()})==1

for label,run in RUNS.items():
 b=budget(run/'melt_budget.csv');summary=json.loads((run/'summary.json').read_text())
 t=b['time_years'];D=b['delivered_net_m3'];V=b['melt_shell_m3'];F=b['refrozen_net_shell_m3']
 peak=int(np.argmax(D));milestones={}
 for fraction in [.01,.1,.5,.9]:
  ix=int(np.flatnonzero(D>=fraction*D[peak])[0])
  milestones[f'delivery_{100*fraction:g}pct_of_peak']={'step':ix,'time_years':float(t[ix])}
 for fraction in [.1,.5,.8]:
  ix=int(np.flatnonzero(D>=fraction*V[0])[0])
  milestones[f'delivery_{100*fraction:g}pct_of_initial']={'step':ix,'time_years':float(t[ix])}
 for fraction in [.5,.1,.01,.005]:
  ix=int(np.flatnonzero(V<=fraction*V[0])[0])
  milestones[f'shell_remaining_{100*fraction:g}pct']={'step':ix,'time_years':float(t[ix])}
 with (run/'research_video/frame_manifest.csv').open() as f: manifest=list(csv.DictReader(f))
 saved_steps=np.array([int(x['iteration']) for x in manifest])
 saved_times=np.array([float(x['time_years']) for x in manifest])
 sample_indices={int(np.argmin(abs(saved_times-target))) for target in [0,.0033,30,70,80,100,300,500,600,1000,3000]}
 sample_indices.update(int(np.argmin(abs(saved_times-x['time_years']))) for x in milestones.values())
 flows=[];samples=[]
 for j,(step,stamp) in enumerate(zip(saved_steps,saved_times)):
  if step==0:continue
  state=State(run/'states'/f'state_{step:08d}.mat')
  assert int(state.read('permeability_exponent')[0])==3
  assert float(state.read('kc_m2')[0])==summary['kc_m2']
  flowtime=float(state.read('flow_time_years')[0])
  assert abs(flowtime-t[step-1])<1e-7
  if not flows:
   r=state.read('radius_m');z=state.read('elevation_m');nx=len(r);ny=len(z)
   dr=float(r[1]-r[0]);dz=float(z[1]-z[0]);nfx=(nx+1)*ny
   vertical=(np.arange(nx)*(ny+1)+nfx)[:,None]+np.arange(ny+1)[None,:]
   interface_offset=int(round(-(z[0]-dz/2)/dz));interface=vertical[:,interface_offset]
   areas=2*np.pi*r*dr
   radii=np.repeat(r,ny);heights=np.tile(z,nx)
   volumes=2*np.pi*radii*dr*dz;shell=heights>=0
  qr=state.read('darcy_flux_m_s')
  darcy=-float(np.dot(qr[interface],areas))*YEAR/1e9
  total=float((D[step]-D[step-1])/(t[step]-t[step-1])/1e9)
  flow={'step':int(step),'time_years':float(stamp),'flow_time_years':flowtime,
   'total_down_km3_per_year':total,'Darcy_down_km3_per_year':darcy,
   'solid_carried_down_km3_per_year':total-darcy}
  flows.append(flow)
  if j in sample_indices:
   phi=state.read('phi');temp=state.read('temperature_K');vs=state.read('solid_velocity_m_s')
   vz=.5*(vs[vertical[:,:-1]]+vs[vertical[:,1:]])
   qz=.5*(qr[vertical[:,:-1]]+qr[vertical[:,1:]])
   vz=vz.reshape(-1);qz=qz.reshape(-1)
   weight=phi*volumes;active=shell&(phi>=.01)
   mushy=shell&(phi>=.01)&(phi<=.5)
   eta=1e14*np.maximum(np.exp(50000/8.314/273*(273/temp-1))*np.exp(-45*phi),1e-5)
   bulk=((1-phi)/(phi+1e-5)-2/3*(1-phi))*eta
   delta=np.sqrt(np.maximum(summary['kc_m2']*phi**3*(bulk+4*eta/3)/.001,0))
   pressure=state.read('pressure_head_Pa').reshape(nx,ny)
   gradient=(pressure[:,1:]-pressure[:,:-1])/dz
   flow['melt_weighted_solid_vertical_m_per_year']=float(np.sum(weight[shell]*vz[shell])/np.sum(weight[shell])*YEAR)
   flow['mushy_melt_weighted_solid_vertical_m_per_year']=float(np.sum(weight[mushy]*vz[mushy])/np.sum(weight[mushy])*YEAR) if mushy.any() else None
   flow['mushy_melt_weighted_relative_vertical_m_per_year']=float(np.sum(volumes[mushy]*qz[mushy])/np.sum(weight[mushy])*YEAR) if mushy.any() else None
   solid_volume_down=-float(np.dot(vs[interface],areas))*YEAR/1e9
   flow['matrix_volume_down_km3_per_year']=solid_volume_down
   flow['mixture_volume_down_residual_km3_per_year']=solid_volume_down+darcy
   flow['shell_integrated_relative_vertical_flux_m4_per_year']=float(np.sum(qz[shell]*volumes[shell])*YEAR)
   flow['median_phi_melt_cells']=float(np.median(phi[active])) if active.any() else None
   flow['median_eta_melt_cells_Pa_s']=float(np.median(eta[active])) if active.any() else None
   flow['median_compaction_length_m']=float(np.median(delta[active])) if active.any() else None
   flow['max_pressure_head_gradient_Pa_per_m']=float(np.max(abs(gradient)))
   flow['active_radial_extent_km']=float(radii[active].max()/1000) if active.any() else None
   samples.append(flow.copy())
  state.close()
 with (OUT/f'{label}_saved_flow_decomposition.csv').open('w',newline='') as f:
  names=['step','time_years','flow_time_years','total_down_km3_per_year','Darcy_down_km3_per_year','solid_carried_down_km3_per_year']
  writer=csv.DictWriter(f,fieldnames=names,extrasaction='ignore');writer.writeheader();writer.writerows(flows)
 # Pick actual saved states near the half-delivery event and the maximum delivery rate.
 half=int(np.argmin(abs(np.array([x['time_years'] for x in flows])-milestones['delivery_50pct_of_peak']['time_years'])))
 maxflux=int(np.argmax([x['total_down_km3_per_year'] for x in flows]))
 report['runs'][label]={'directory':str(run),'summary':summary,'milestones':milestones,
  'peak_net_delivery_km3':float(D[peak]/1e9),'peak_net_delivery_time_years':float(t[peak]),
  'final_delivery_pct_initial':float(D[-1]/V[0]*100),
  'final_net_refrozen_pct_initial':float(F[-1]/V[0]*100),
  'net_refrozen_minus_initial_adjustment_km3':float(F[-1]/1e9-.3672852028284378),
  'half_delivery_saved_flow':flows[half], 'peak_saved_delivery_flow':flows[maxflux],
  'selected_saved_state_diagnostics':samples,'saved_states_analyzed':len(flows)}
 print(label,json.dumps({k:report['runs'][label][k] for k in ['milestones','half_delivery_saved_flow','peak_saved_delivery_flow']}),flush=True)

report['termination_time_ratio_low_over_high']=report['runs']['low']['summary']['time_years']/report['runs']['high']['summary']['time_years']
(OUT/'comparison.json').write_text(json.dumps(report,indent=2))
print('COMPARISON_SAVED',str(OUT/'comparison.json'))
