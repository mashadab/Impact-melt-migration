function verify_Europa_S3_pressure
root=fileparts(mfilename('fullpath'));
addpath(root);
f=fullfile(root,'darcy_stokes_2D_cases.m');
m=checkcode(f,'-id');
for j=1:numel(m)
 if strcmp(m(j).id,'PARSE'),error('%s',m(j).message);end
end
out=fullfile(root,'..','Output',['Europa_S3_pressure_' datestr(now,'yyyymmdd_HHMMSS')]);
% With beta=(rho_f-rho_i)/rho_i, corrected forcing must be:
% -Pi5*beta*(1-phi) + Ra*(1-Tprime), for Tprime<=1.
Pi5=2.5; Ra=0.2; beta=80/920;
for Tprime=[0 0.4 1]
 for phi=[0 0.3 1]
  assembled=-Ra*Tprime+Pi5*beta*phi-Pi5*(1+beta)+Pi5+Ra;
  expected=-Pi5*beta*(1-phi)+Ra*(1-Tprime);
  assert(abs(assembled-expected)<1e-14);
 end
end
assert(contains(fileread(f),'fsVec=fsVec+(Pi_5+Ra)*ones(size(fsVec));'));
o=struct('max_steps',3,'snapshot_steps',[0 1 3],'output_dir',out);
r=Europa_wrapper_noflow(o);
assert(strcmp(r.status,'completed') && r.completed_steps==3);
assert(isequal(r.mesh,[100 120]));
assert(strcmp(r.Grid.p.geom,'cylindrical_rz'));
assert(r.length_scale_m==10000);
assert(r.Grid.p.xmin==0 && r.Grid.p.xmax==2 && r.Grid.p.ymin==-0.2 && r.Grid.p.ymax==1);
s=load(fullfile(root,'..','initial_conditions','ic03321_100.mat'),'T','phi');
P=[zeros(20,100);reshape(s.phi,100,100)];
[X,Y]=meshgrid(r.Grid.p.xc,r.Grid.p.yc); %#ok<ASGLU>
P(Y>=0 & Y<0.25)=0;
T=[273*ones(20,100);reshape(s.T,100,100)];
assert(max(abs(P(:)-r.full_phi(:,1)))==0);
assert(max(abs(T(:)-r.full_T_K(:,1)))<1e-10);
assert(r.max_base_solid_flux<1e-10);
assert(r.max_base_darcy_flux==0 && r.max_base_advective_heat_flux==0);
assert(r.max_base_conductive_heat_flux==0);
assert(all(isfinite(r.final_state.H)));
assert(max(abs(r.history(:,11)))/max(1,abs(r.initial_enthalpy_total))<1e-10);
fprintf('EUROPA_S3_PRESSURE_VERIFIED: three full-grid steps, exact original initialization, cylindrical geometry, sealed base, heat budget.\n%s\n',r.output_file);
end
