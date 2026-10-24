# Darcy-Stokes solver
# author: Mohammad Afzal Shadab
# email: mashadab@utexas.edu
# date: 04/09/2023

import sys
sys.path.insert(1, '../../HW1-Numerics/Python/')
sys.path.insert(1, '../../HW2-BC_LBVP/Python/')
sys.path.insert(1, '../../HW3-Hetero-Fluxes-NeuBC/Python/')
sys.path.insert(1, '../../HW4-1DMelt-Migration/Python/')
sys.path.insert(1, '../../HW6-2D_operators/Python/')
sys.path.insert(1, '../../HW8-2DStokes/Python/')
sys.path.insert(1, '../../HW9-Streamlines/Python/')

# import Python libraries
from scipy.sparse import bmat,csr_matrix,spdiags
import matplotlib.pyplot as plt

# import personal libraries
from classfun import *  #importing the classes and relevant functions
from build_stokes_grid_fun import build_stokes_grid
from build_stokes_ops_Darcy_Stokes_fun import build_stokes_ops_Darcy_Stokes
from build_bndfun_optimized import build_bnd
from solve_lbvpfun_optimized import solve_lbvp
from quiver_plot import quiver_plot
from comp_streamfun import comp_streamfun
from plot_streamlines import plot_streamlines

def build_Zd(G,phi,m,mu,Grid): #building zeta^*_phi at cell centers
    Zd = (G / (phi**m) - 2/3) * mu * (1-phi);
    Zd = spdiags(Zd.T,0,Grid.N,Grid.N)
    return Zd

def build_Kd(k0,n,phi,mu_f,Grid,Mp): #building Kd at cell faces
    Kd = Mp @ ( k0 * phi**n / mu_f)
    Kd = spdiags(Kd.T,0,Grid.Nf,Grid.Nf)
    return Kd 

def build_RHS(phi,Kd,Grid,Mp,Dp,rho_f,rho_s,Gamma,grav):
    #fv at cell faces
    fv =-grav*( Mp @ ((rho_f - rho_s) *(1-phi))) * np.vstack([np.zeros((Grid.Nfx,1)),np.ones((Grid.Nfy,1))])
    
    #fh at cell centers
    fh =-(rho_f - rho_s)/(rho_f * rho_s) * Gamma * np.ones((Grid.N,1))
    
    F =  np.vstack([fv,fh])
    
    return F

#problem parameter
mu_max = 1e14 #Maximum solid viscosity [Pa.s]
phi_min= 0.2; phi_max= 0.7 #Minimum and Maximum solid porosities [-]
G      = 1.0 #Coefficient in the bulk viscosity formulation [-]
k0     = 5.6e-11 #Relative permeability [m^2] {Meyer and Hewitt, 2017}
mu_f   = 1e-3#Viscosity of the fluid [Pa.s]
m      = 1   #Power law coefficient in compaction viscosity = (G/phi^m * mu_s) [-]
n      = 2   #Power law coefficient in porosity permeability relationship k = k0*phi^n [-]
rho_s  = 917 #Density of solid [kg/m^3]
rho_f  = 1e3 #Density of fluid [kg/m^3]
Gamma  = 0   #Rate of melting [kg/m^3-s]
grav   = 9.81#Acceleration due to gravity []m/s^2]
Delta_rho = rho_f - rho_s #Density difference between the two phases [kg/m^3]
vt     = 1e-3#Tangential velocity [m/s]

#building grid
Gridp.xmin = 0.0 ; Gridp.xmax = 1 ; Gridp.Nx   = 5
Gridp.ymin = 0.0 ; Gridp.ymax = 1 ; Gridp.Ny   = 5
Gridp.geom = 'cartesian'
Grid = build_stokes_grid(Gridp)
[Xc,Yc] = np.meshgrid(Gridp.xc,Gridp.yc)
Xc_col = np.reshape(Xc.T,(Gridp.N,-1)); Yc_col = np.reshape(Yc.T,(Gridp.N,-1))

#Initial condition
mu = mu_max  * np.ones_like(Yc_col)  #Constt viscosity
phi= phi_min * np.ones((Grid.p.N,1)) #+ (phi_max - phi_min)*(Yc(:)/Grid.p.ymax);  #Constt porosity or Decays with depth


#simulation name
simulation_type = 'lid_driven_cavity_flow_with_no_slip'   #lid_driven_cavity_flow_with_slip or 'no_flow' 
simulation_name = f'stokes_solver_test{simulation_type}_domain{Gridp.xmax-Gridp.xmin}by{Gridp.ymax-Gridp.ymin}_N{Gridp.Nx}by{Gridp.Ny}'

#building operators
D, Edot, Dp, Gp, I, Ms, Mp = build_stokes_ops_Darcy_Stokes(Grid)
Mud = spdiags((Ms @ (mu*(1-phi))).T,0,np.shape(Edot)[0],np.shape(Edot)[0])
Zd = build_Zd(G,phi,m,mu,Grid.p)
Kd = build_Kd(k0,n,phi,mu_f,Grid.p,Mp)

A  = 2.0 * D @ Mud @ Edot
L  = bmat([[A + Gp @ Zd @ Dp, -(Delta_rho * grav)* Gp], [Dp, -(Delta_rho * grav)* Dp @ Kd @ Gp]],format="csr")
#fs = csr_matrix((Grid.N, 1), dtype=np.float64)
fs = build_RHS(phi,Kd,Grid.p,Mp,Dp,rho_f,rho_s,Gamma,grav)



#Boundary conditions
if 'lid_driven_cavity_flow_with_slip' in simulation_type:
    BC.dof_dir =  np.concatenate((Grid.dof_pene, \
                                  Grid.dof_ymax_vt,\
                                  Grid.dof_pc))
    BC.g = np.transpose([np.concatenate((np.zeros(Grid.N_pene), \
                                         vt*np.ones(len(Grid.dof_ymax_vt)),\
                                        [0.0]))])
    
elif 'lid_driven_cavity_flow_with_no_slip' in simulation_type: #did not work
    BC.dof_dir =  np.concatenate((Grid.dof_pene, \
                                  Grid.dof_ymax_vt[1:-1],\
                                  Grid.dof_ymin_vt[1:-1],\
                                  Grid.dof_xmax_vt[1:-1],\
                                  Grid.dof_xmin_vt[1:-1],\
                                  Grid.dof_pc-1))
    BC.g = np.transpose([np.concatenate((np.zeros(Grid.N_pene), \
                                         vt*np.ones(len(Grid.dof_ymax_vt[1:-1])),\
                                         np.zeros(len(Grid.dof_ymin_vt[1:-1])),\
                                         np.zeros(len(Grid.dof_xmax_vt[1:-1])),\
                                         np.zeros(len(Grid.dof_xmin_vt[1:-1])),\
                                        [0.0]))])

else:#no flow
    BC.dof_dir =  np.concatenate((Grid.dof_solid_bnd, \
                                  Grid.dof_pc))
    BC.g        = np.concatenate((np.zeros(Grid.N_solid_bnd), \
                                  [0.0]))  

BC.dof_neu = np.array([])
[B,N,fn] = build_bnd(BC,Grid,I)

#Solving for Stokes flow
u = solve_lbvp(L,fs+fn,B,BC.g,N)
v = u[:Grid.p.Nf,:]; h = u[Grid.p.Nf:,:]       #Extracting solid velocity and fluid pressure
[PSI,psi_min,psi_max] = comp_streamfun(v,Gridp)#Solid velocity stream function

p = Delta_rho * grav * (h - Yc_col)           #Overpressure [Pa] 
pf= p - rho_s * grav * Yc_col                 #Fluid pressure [Pa]
ps= pf- G * mu/ phi**m * (Dp @ v)             #Solid pressure [Pa]

#Fluid velocity
vf = v - spdiags((1./(Mp @ phi)).T,0,Grid.p.Nf,Grid.p.Nf) @ Kd @ (Gp @ p + rho_f * grav * np.vstack([np.zeros((Grid.p.Nfx,1)),np.ones((Grid.p.Nfy,1))]))
[PSIf,psif_min,psif_max] = comp_streamfun(vf,Gridp) #Fluid velocity stream function

#Plotting
#quiver_plot(simulation_name,Grid,v)
plot_streamlines(simulation_name,Grid,v,PSI,psi_min,psi_max,'label_no')


plt.figure()
plt.contourf(Xc,Yc,np.transpose((mu).reshape(Gridp.Nx,Gridp.Ny)))
plt.colorbar()

#plt.figure(figsize=(20,10),sharex=True,sharey=True)
plt.subplots(1, 4, figsize=(20,4), sharex=True,sharey=True)
ax1 = plt.subplot(1, 4, 1)
plt.contourf(Xc,Yc,np.transpose((mu).reshape(Gridp.Nx,Gridp.Ny)),100)
plt.title('Porosity')
plt.colorbar()
plt.axis('scaled')

ax2 = plt.subplot(1, 4, 2)
plt.contourf(Xc,Yc,np.transpose((pf).reshape(Gridp.Nx,Gridp.Ny)),100)
plt.colorbar()
plt.contour(Xc,Yc,np.transpose((pf).reshape(Gridp.Nx,Gridp.Ny)),50,colors='k')
plt.title('Fluid Pressure [Pa]')
plt.axis('scaled')

ax3 = plt.subplot(1, 4, 3)
plt.contourf(Xc,Yc,np.transpose((p).reshape(Gridp.Nx,Gridp.Ny)),100)
plt.colorbar()
plt.contour(Xc,Yc,np.transpose((p).reshape(Gridp.Nx,Gridp.Ny)),50,colors='k')
plt.title('Overpressure [Pa]')
plt.axis('scaled')

ax4 = plt.subplot(1, 4, 4)
Xp,Yp = np.meshgrid(Grid.Vx.xc,Grid.Vy.yc)
plt.contour(Xp, Yp, PSI,50,colors='k',linestyle='-')
plt.contour(Xp, Yp, PSIf,50,colors='b',linestyle='--')
plt.title('Streamlines')
plt.axis('scaled')
