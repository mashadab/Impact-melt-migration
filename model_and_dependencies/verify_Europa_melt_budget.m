function verify_Europa_melt_budget
root=fileparts(mfilename('fullpath'));addpath(root);
% Synthetic transport must not be counted as refreezing, including return flow.
G=struct('xmin',0,'xmax',2,'Nx',2,'ymin',-1,'ymax',1,'Ny',4,'geom','cylindrical_rz');
G=build_grid(G);[D,~,~]=build_ops(G);
P=.4*ones(G.N,1);b=europa_melt_budget([],P,G,1,0,0,[]);
assert(abs(sum(G.V)-8*pi)<1e-12);
q=zeros(G.Nf,1);q(b.interface_faces)=-.1;dt=.02;
Pn=P-dt*D*q;c=europa_melt_budget(b,Pn,G,1,1,dt,q);
expected=-dt*sum(q(b.interface_faces).*G.A(b.interface_faces));
assert(abs(c.delivered_net_m3(end)-expected)<1e-12);
assert(max(abs(c.refrozen_net_m3(end,:)))<1e-12);
back=europa_melt_budget(c,P,G,1,2,dt,-q);
assert(abs(back.delivered_net_m3(end))<1e-12 && max(abs(back.refrozen_net_m3(end,:)))<1e-12);
f=europa_melt_budget(b,P-.1,G,1,1,dt,zeros(G.Nf,1));
assert(abs(f.refrozen_net_m3(end,1)-.1*sum(G.V))<1e-12);
m=europa_melt_budget(b,P+.1,G,1,1,dt,zeros(G.Nf,1));
assert(abs(m.refrozen_net_m3(end,1)+.1*sum(G.V))<1e-12);
fprintf('PASS synthetic annular volumes, transport/return flow, freezing, and new melting.\n');
% Full-grid diagnostics must not change the corrected S3-derived solution.
out=fullfile(root,'..','Output',['Europa_budget_check_' datestr(now,'yyyymmdd_HHMMSS')]);
r=run_darcy_stokes_case('impact_melt_europa',struct('max_steps',3,'snapshot_steps',[0 1 3],'output_dir',out));
s=load(fullfile(root,'..','Output','Europa_S3_pressure_20261023_185230','noflow_kc_1.850e-08.mat'),'result');a=s.result;
assert(strcmp(r.status,'completed') && r.completed_steps==3);
assert(isequaln(r.final_state,a.final_state) && isequaln(r.full_H,a.full_H));
assert(isequaln(r.full_phi,a.full_phi) && isequaln(r.full_T_K,a.full_T_K));
assert(isequaln(r.history,a.history));
assert(r.max_base_solid_flux==0 && r.max_base_darcy_flux==0);
b=r.melt_budget;assert(b.interface_z_m==0 && b.initial_volume_m3(3)==0);
assert(all(isfinite(b.history{:,:}),'all'));
assert(max(abs(sum(b.liquid_volume_m3(:,2:3),2)-b.liquid_volume_m3(:,1)))<1e-3);
fprintf('PASS full-grid solution bit-for-bit identical to corrected pre-diagnostic Europa run.\n');
disp(b.history);
fprintf('BUDGET_CHECK_COMPLETE %s\n',out);
show_Europa_initial_state;
end
