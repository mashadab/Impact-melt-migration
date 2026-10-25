"""Read-only comparison of completed centered S3 runs, using actual MAT fields."""
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import ctypes as c
import csv
import hashlib
import json
import os
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
WARM=ROOT/'Output/centered_water_S3_100yr_20261024_214605'
COLD=ROOT/'Output/centered_cold_bottom_S3_100yr_20261025_073337'
STAMP=datetime.now(ZoneInfo('America/New_York')).strftime('%Y%m%d_%H%M%S')
OUT=ROOT/'Output'/('centered_warm_cold_conduction_100yr_'+STAMP)
OUT.mkdir()
YEAR=3.154e7;DT=173.;CP=185+7.037*273;ESCALE=920*CP*DT;LATENT=334e6
BIN=Path('C:/Program Files/MATLAB/R2022b/bin/win64')
DLLDIR=os.add_dll_directory(str(BIN))
MAT=c.CDLL(str(BIN/'libmat.dll'));MX=c.CDLL(str(BIN/'libmx.dll'))
MAT.matOpen.argtypes=[c.c_char_p,c.c_char_p];MAT.matOpen.restype=c.c_void_p
MAT.matGetVariable.argtypes=[c.c_void_p,c.c_char_p];MAT.matGetVariable.restype=c.c_void_p
MAT.matClose.argtypes=[c.c_void_p];MAT.matClose.restype=c.c_int
MX.mxGetField.argtypes=[c.c_void_p,c.c_size_t,c.c_char_p];MX.mxGetField.restype=c.c_void_p
MX.mxGetNumberOfElements.argtypes=[c.c_void_p];MX.mxGetNumberOfElements.restype=c.c_size_t
MX.mxGetPr.argtypes=[c.c_void_p];MX.mxGetPr.restype=c.POINTER(c.c_double)
MX.mxDestroyArray.argtypes=[c.c_void_p]
def field(p,name):
    q=MX.mxGetField(p,0,name.encode());assert q,name;return q
def arr(p,name):
    q=field(p,name);n=MX.mxGetNumberOfElements(q)
    return np.ctypeslib.as_array(MX.mxGetPr(q),shape=(n,)).copy()
def scalar(p,name):return float(arr(p,name)[0])
class Mat:
    def __init__(self,path,key):
        self.file=MAT.matOpen(str(path).encode(),b'r');assert self.file,path
        self.p=MAT.matGetVariable(self.file,key.encode());assert self.p,key
    def close(self):MX.mxDestroyArray(self.p);assert MAT.matClose(self.file)==0

def read_run(folder,cold=False):
    summary=json.loads((folder/'summary.json').read_text(encoding='utf-8-sig'))
    assert summary['status']=='completed' and summary['time_years']==100
    checkpoint=folder/'states'/f"state_{summary['step']:08d}.mat"
    m=Mat(checkpoint,'checkpoint');p=m.p;g=field(field(p,'Grid'),'p')
    d=scalar(p,'d_m');nx=int(scalar(g,'Nx'));ny=int(scalar(g,'Ny'))
    x=arr(g,'xc')*d;z=arr(g,'yc')*d;V=arr(g,'V')*d*d
    values={n:arr(p,n) for n in ['H','phi','T_dimensionless']}
    values.update(x=x,z=z,V=V,nx=nx,ny=ny,d=d,step=int(scalar(p,'step')),years=scalar(p,'time_years'))
    diag=field(p,'diagnostic')
    for n in ['dH_bulk','dH_Darcy','dH_conduction','H_before','phi_before','T_before_K','solid_velocity_m_s','darcy_flux_m_s']:
        values[n]=arr(diag,n)
    values['L']=scalar(diag,'latent_dimensionless')
    if cold:
        b=field(field(diag,'cold_bottom'),'budget')
        for n in ['initial_H','initial_phi','initial_T_K','cumulative_dH_bulk','cumulative_dH_Darcy','cumulative_dH_conduction','cumulative_effective_phase_delta_phi']:
            values[n]=arr(b,n)
        for n in ['T_conduction_only_this_step_K','phi_conduction_only_this_step','T_advection_only_this_step_K','phi_advection_only_this_step']:
            values[n]=arr(field(diag,'cold_bottom'),n)
    m.close()
    initial=Mat(folder/'initial_state.mat','initial_state')
    for n in ['H','phi','T_dimensionless']:values['initial_'+n]=arr(initial.p,n)
    initial.close()
    values['T_K']=values['T_dimensionless']*DT+100
    values['initial_T_K']=values['initial_T_dimensionless']*DT+100
    values['checkpoint']=str(checkpoint)
    return values

warm=read_run(WARM);cold=read_run(COLD,True)
for k in ['x','z','V','initial_phi']:assert np.array_equal(warm[k],cold[k]),k
assert warm['nx']==cold['nx']==100 and warm['ny']==cold['ny']==120
X,Z=np.meshgrid(warm['x'],warm['z']);zf=Z.ravel(order='F');lower=zf<4000;V=warm['V']
assert np.all(warm['initial_T_K']==273)
assert np.max(abs(cold['initial_T_K'][lower]-253.15))<1e-10
assert np.array_equal(warm['initial_H'][~lower],cold['initial_H'][~lower])
col=int(np.argmin(abs(warm['x']-10100)));assert abs(warm['x'][col]-10100)<1e-8
profile={}
def volume(a):return float(np.sum(a*V))
def profile_metrics(r):
    phi=r['phi'].reshape(r['ny'],r['nx'],order='F')[:,col]
    data={}
    for threshold in [1e-8,.01,.1,.5]:
        ids=np.flatnonzero(phi>=threshold)
        data[f'lowest_center_cell_z_m_phi_ge_{threshold:g}']=float(r['z'][ids[0]]) if ids.size else None
    return data
report={'time_years':100,'kc_m2':1.85e-8,'permeability_exponent':3,
 'profile_x_m':float(warm['x'][col]),'profile_column_zero_based':col,
 'warm_initial_temperature_K':273,'cold_lower_initial_temperature_K':253.15,
 'model_melting_temperature_K':273,'both_cases_identical_initial_liquid_and_grid':True,
 'profile_representation':'Exact x=10.1 km cell column; piecewise constant over actual cells; no field/time interpolation.',
 'cases':{}}
for key,r in [('warm',warm),('cold',cold)]:
    initial=volume(r['initial_phi']);total=volume(r['phi']);below=volume(r['phi']*lower)
    report['cases'][key]=dict(step=r['step'],initial_liquid_m3_per_m_depth=initial,
      final_liquid_m3_per_m_depth=total,liquid_below_z4_m3_per_m_depth=below,
      domain_net_liquid_loss_m3_per_m_depth=initial-total,
      domain_net_liquid_loss_fraction=(initial-total)/initial,
      fraction_of_initial_liquid_below_z4=below/initial,
      liquid_centroid_z_m=volume(r['phi']*zf)/total,
      lower_mean_temperature_K=float(np.sum(r['T_K'][lower]*V[lower])/np.sum(V[lower])),
      temperature_min_K=float(r['T_K'].min()),temperature_max_K=float(r['T_K'].max()),
      center_profile=profile_metrics(r),checkpoint=r['checkpoint'])
    profile[key+'_phi']=r['phi'].reshape(r['ny'],r['nx'],order='F')[:,col]
    profile[key+'_T_K']=r['T_K'].reshape(r['ny'],r['nx'],order='F')[:,col]
profile['initial_phi']=warm['initial_phi'].reshape(warm['ny'],warm['nx'],order='F')[:,col]
profile['cold_initial_T_K']=cold['initial_T_K'].reshape(cold['ny'],cold['nx'],order='F')[:,col]

with (COLD/'diagnostics.csv').open(newline='') as f:rows=list(csv.DictReader(f))
with (WARM/'diagnostics.csv').open(newline='') as f:wrows=list(csv.DictReader(f))
assert len(rows)==cold['step'] and len(wrows)==warm['step']
H0=cold['initial_H'];cond=cold['cumulative_dH_conduction'];adv=cold['cumulative_dH_bulk']+cold['cumulative_dH_Darcy']
energy_residual=cold['H']-H0-adv-cond
assert np.max(abs(energy_residual))<1e-8
qheat=volume(cond*lower)*ESCALE;dheat=volume((cold['H']-H0)*lower)*ESCALE
audit={
 'net_conductive_heat_into_lower_J_per_m_depth':qheat,
 'net_advected_heat_into_lower_J_per_m_depth':volume(adv*lower)*ESCALE,
 'total_lower_enthalpy_gain_J_per_m_depth':dheat,
 'conduction_fraction_of_net_lower_enthalpy_gain':qheat/dheat,
 'net_conduction_entire_closed_domain_J_per_m_depth':volume(cond)*ESCALE,
 'positive_cumulative_cell_conduction_J_per_m_depth':volume(np.maximum(cond,0))*ESCALE,
 'negative_cumulative_cell_conduction_J_per_m_depth':volume(np.minimum(cond,0))*ESCALE,
 'lower_positive_cumulative_cell_conduction_J_per_m_depth':volume(np.maximum(cond,0)*lower)*ESCALE,
 'lower_negative_cumulative_cell_conduction_J_per_m_depth':volume(np.minimum(cond,0)*lower)*ESCALE,
 'max_cell_cumulative_conduction_dimensionless_H':float(cond.max()),
 'min_cell_cumulative_conduction_dimensionless_H':float(cond.min()),
 'maximum_equivalent_ice_warming_K_from_cumulative_conduction':float(cond.max()*DT),
 'maximum_equivalent_ice_cooling_K_from_cumulative_conduction':float(cond.min()*DT),
 'cold_dry_lower_cell_steps_with_liquid_from_conduction_only':sum(int(float(r['lower_dry_cells_wet_with_conduction_only_this_step'])) for r in rows),
 'cold_dry_lower_cell_steps_with_liquid_from_advection_only':sum(int(float(r['lower_dry_cells_wet_with_advection_only_this_step'])) for r in rows),
 'warm_all_steps_isothermal_273K':all(float(r['T_min_K'])==273 and float(r['T_max_K'])==273 for r in wrows),
 'warm_all_steps_max_abs_temperature_difference_from_273K':max(max(abs(float(r['T_min_K'])-273),abs(float(r['T_max_K'])-273)) for r in wrows),
 'warm_final_max_abs_dH_conduction':float(np.max(abs(warm['dH_conduction']))),
 'cumulative_H_reconstruction_max_abs':float(np.max(abs(energy_residual))),
 'interpretation':'Positive/negative cell sums are signs of time-integrated Eulerian cell contributions, not gross time integrals of positive/negative flux. Whole-domain conductive gain cancels at insulated walls; net lower-half input does not measure internal redistribution.'}
# Direct, actual first update: distinguish initial wetting from conductive heating.
first=Mat(COLD/'states/state_00000001.mat','checkpoint');p=first.p;di=field(p,'diagnostic');co=field(di,'cold_bottom')
oldphi=arr(di,'phi_before');newphi=arr(di,'phi_after');oldH=arr(di,'H_before');newH=arr(di,'H_after')
born=lower&(oldphi==0)&(newphi>1e-8)
ids=np.flatnonzero(born);samples=[]
for i in ids:
    iz=i%cold['ny'];ix=i//cold['ny']
    samples.append(dict(x_m=float(cold['x'][ix]),z_m=float(cold['z'][iz]),H_before=float(oldH[i]),
      H_after=float(newH[i]),phi_after=float(newphi[i]),
      dH_bulk=float(arr(di,'dH_bulk')[i]),dH_Darcy=float(arr(di,'dH_Darcy')[i]),dH_conduction=float(arr(di,'dH_conduction')[i]),
      phi_conduction_only=float(arr(co,'phi_conduction_only_this_step')[i]),phi_advection_only=float(arr(co,'phi_advection_only_this_step')[i])))
audit['first_update']=dict(time_years=scalar(p,'time_years'),newly_wet_cold_cells=int(born.sum()),samples=samples)
first.close()
center_sample=min(samples,key=lambda v:abs(v['x_m']-10100))
audit['first_update']['center_sample']=center_sample
audit['first_update']['center_phi_increment_from_conduction']=center_sample['phi_after']-center_sample['phi_advection_only']
audit['first_update']['center_phi_conduction_fraction']=(center_sample['phi_after']-center_sample['phi_advection_only'])/center_sample['phi_after']
audit['first_update']['center_conduction_only_temperature_K']=253.15+center_sample['dH_conduction']*DT
audit['lower_max_cumulative_conduction_H']=float(cond[lower].max())
audit['lower_min_cumulative_conduction_H']=float(cond[lower].min())
audit['positive_cumulative_cell_conduction_as_latent_volume_m3_per_m_depth']=audit['positive_cumulative_cell_conduction_J_per_m_depth']/LATENT
audit['conductive_cooling_energy_divided_by_domain_net_liquid_loss_latent_energy']=abs(audit['negative_cumulative_cell_conduction_J_per_m_depth'])/(report['cases']['cold']['domain_net_liquid_loss_m3_per_m_depth']*LATENT)
# Identify exact locations and retained material choices that affect interpretation.
for label,idx in [('largest_net_conductive_heating',int(np.argmax(cond))),('largest_net_conductive_cooling',int(np.argmin(cond)))]:
    iz=idx%cold['ny'];ix=idx//cold['ny']
    audit[label]=dict(x_m=float(cold['x'][ix]),z_m=float(cold['z'][iz]),
      cumulative_dH_conduction=float(cond[idx]),initial_T_K=float(cold['initial_T_K'][idx]),
      final_T_K=float(cold['T_K'][idx]),final_phi=float(cold['phi'][idx]))
enhanced=(zf<200)&(cold['phi_before']>.5)
audit['inherited_enhanced_conductivity']=dict(condition='z < 200 m and phi > 0.5',
 physical_cell_conductivity_W_m_K=330,active_cells_in_final_flow=int(enhanced.sum()),
 note='Existing ocean-style kappaPrime=100 rule retained in both solvers. Ordinary conductivity is phi*0.56+(1-phi)*3.3 W/(m K).')
diffusivity=3.3/(920*CP)
audit['dry_ice_thermal_diffusivity_m2_s']=diffusivity
audit['sqrt_diffusivity_times_100yr_m']=float(np.sqrt(diffusivity*100*YEAR))
audit['cell_dx_m']=float(cold['x'][1]-cold['x'][0]);audit['cell_dz_m']=float(cold['z'][1]-cold['z'][0])
audit['initial_dry_ice_cold_to_warm_viscosity_ratio']=float(np.exp(50e3/8.314/273*(273/253.15-1)))
report['conduction']=audit
report['cold_to_warm_below_z4_liquid_ratio']=report['cases']['cold']['liquid_below_z4_m3_per_m_depth']/report['cases']['warm']['liquid_below_z4_m3_per_m_depth']

warm_cfg=json.loads((WARM/'configuration.json').read_text());cold_cfg=json.loads((COLD/'configuration.json').read_text())
wp=Path(warm_cfg['frozen_source_dir'])/'darcy_stokes_2D_cases.m';cp=Path(cold_cfg['frozen_source_dir'])/'darcy_stokes_2D_centered_cold_bottom_S3.m'
wt=wp.read_text();ct=cp.read_text()
start='        %% Bouyancy force as the body force to Stokes flow';end='        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5'
block=lambda s:s[s.index(start):s.index(end)+len(end)]
assert block(wt)==block(ct)
common=['build_stokes_grid_cyl.m','build_grid.m','build_ops.m','build_bnd.m','solve_lbvp.m','comp_mean.m','comp_mean_corners.m','barrViscPhase.m','enthMelt.m','flux_upwind.m','build_adv_op.m','smoothness.m','comp_limiter.m']
same_helpers=all((wp.parent/n).read_bytes()==(cp.parent/n).read_bytes() for n in common)
assert same_helpers
report['verification']=dict(flow_heat_phase_block_identical=True,common_helpers_bitwise_identical=True,
 exact_endpoint_times_both_100_years=True,identical_grid_and_initial_phi=True,
 profile_uses_single_actual_column=True,
 warm_solver_sha256=hashlib.sha256(wp.read_bytes()).hexdigest(),cold_solver_sha256=hashlib.sha256(cp.read_bytes()).hexdigest())
fields=['z_m']+list(profile)
with (OUT/'center_profiles_100yr.csv').open('w',newline='') as f:
    w=csv.writer(f);w.writerow(fields)
    w.writerows(zip(cold['z'],*[profile[k] for k in profile]))
with (OUT/'center_cold_enthalpy_budget_100yr.csv').open('w',newline='') as f:
    w=csv.writer(f);w.writerow(['z_m','initial_H','final_H','cumulative_bulk','cumulative_Darcy','cumulative_conduction','cumulative_net_advection'])
    select=lambda a:a.reshape(cold['ny'],cold['nx'],order='F')[:,col]
    w.writerows(zip(cold['z'],select(H0),select(cold['H']),select(cold['cumulative_dH_bulk']),select(cold['cumulative_dH_Darcy']),select(cond),select(adv)))
with (OUT/'cold_heat_history.csv').open('w',newline='') as f:
    names=['step','time_years','lower_bulk_heat_cumulative_J_per_m_depth','lower_Darcy_heat_cumulative_J_per_m_depth','lower_conductive_heat_cumulative_J_per_m_depth','lower_enthalpy_change_J_per_m_depth','liquid_lower_m3_per_m_depth','domain_net_liquid_loss_m3_per_m_depth']
    w=csv.DictWriter(f,fieldnames=names,extrasaction='ignore');w.writeheader();w.writerows(rows)
# Export all actual cells for the optional map comparison.
np.savez_compressed(OUT/'actual_fields.npz',x_m=cold['x'],z_m=cold['z'],warm_phi=warm['phi'].reshape(120,100,order='F'),
 cold_phi=cold['phi'].reshape(120,100,order='F'),cold_T_K=cold['T_K'].reshape(120,100,order='F'),
 cumulative_conduction_H=cond.reshape(120,100,order='F'))
(OUT/'comparison.json').write_text(json.dumps(report,indent=2))
(ROOT/'tmp/centered_warm_cold_audit_output.txt').write_text(str(OUT))
print(json.dumps(dict(output_dir=str(OUT),**report),indent=2))
