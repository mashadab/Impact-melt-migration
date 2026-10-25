"""Check saved launch provenance and actual HDF5 state arrays, without MATLAB."""
import ctypes as c
import hashlib
import json
import os
from pathlib import Path
import numpy as np

root=Path(__file__).resolve().parents[1]
run=root/'Output/Europa_kc_1.850e-16_until_depleted_20261024_085440'
reference=root/'Output/Europa_kc_1.850e-08_until_depleted_20261023_195524'
new=json.loads((run/'run_configuration.json').read_text())
old=json.loads((reference/'run_configuration.json').read_text())
different=sorted(k for k in new.keys() | old.keys() if new.get(k)!=old.get(k))
assert different==['kc','output_dir'],different
assert new['kc']==1.85e-16
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
core='darcy_stokes_2D_cases.m'
assert sha(run/'source'/core)==sha(reference/'source'/core)==sha(root/'model_and_dependencies'/core)
assert sha(run/'ic03321_100.mat')==sha(reference/'ic03321_100.mat')

bindir=Path(r'C:\Program Files\MATLAB\R2022b\bin\win64')
with os.add_dll_directory(str(bindir)):
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
 def read(path,name):
  f=h.H5Fopen(str(path).encode(),0,0);assert f>=0
  d=h.H5Dopen2(f,('/state/'+name).encode(),0);assert d>=0
  sp=h.H5Dget_space(d);rank=h.H5Sget_simple_extent_ndims(sp)
  dims=(c.c_ulonglong*rank)();h.H5Sget_simple_extent_dims(sp,dims,None)
  a=np.empty(int(np.prod(list(dims))),dtype=np.float64)
  assert h.H5Dread(d,native,0,0,0,a.ctypes.data_as(c.c_void_p))>=0
  h.H5Sclose(sp);h.H5Dclose(d);h.H5Fclose(f)
  return a
 initial='states/state_00000000.mat';first=run/'states/state_00000001.mat'
 initial_fields=['temperature_K','phi','enthalpy_dimensionless','radius_m','elevation_m']
 for name in initial_fields:
  assert np.array_equal(read(run/initial,name),read(reference/initial,name),equal_nan=True),name
 kc=float(read(first,'kc_m2')[0]);nn=float(read(first,'permeability_exponent')[0])
 assert kc==1.85e-16 and nn==3
 for name in ['temperature_K','phi','solid_velocity_m_s','darcy_flux_m_s','pressure_head_Pa']:
  assert np.isfinite(read(first,name)).all(),name
 phi=read(first,'phi');assert phi.min()>=-1e-12 and phi.max()<=1+1e-12
 nx=read(first,'radius_m').size;ny=read(first,'elevation_m').size
 base=(nx+1)*ny+np.arange(nx)*(ny+1)
 vs=float(np.max(np.abs(read(first,'solid_velocity_m_s')[base])))
 qr=float(np.max(np.abs(read(first,'darcy_flux_m_s')[base])))
 assert vs<1e-15 and qr<1e-15,(vs,qr)
 report={'status':'passed','options_differ_only_in':different,'actual_saved_kc_m2':kc,
  'actual_saved_permeability_exponent':nn,'verified_iteration':int(read(first,'step')[0]),
  'initial_fields_identical_to_reference':initial_fields,
  'base_solid_velocity_absmax_m_s':vs,'base_darcy_flux_absmax_m_s':qr,
  'solver_sha256':sha(run/'source'/core),'output_dir':str(run)}
 (run/'launch_verification.json').write_text(json.dumps(report,indent=2))
 print(json.dumps(report))
