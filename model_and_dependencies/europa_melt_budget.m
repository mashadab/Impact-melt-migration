function b = europa_melt_budget(b,phi,G,d,time_years,dt,liquid_flux)
% Diagnostic only. Volumes are liquid-water-equivalent m^3; fluxes/time are nondimensional.
% Positive delivery is NET DOWNWARD across the existing grid face at z=0.
% Net refreezing = initial liquid - remaining liquid - cumulative net export.
% Negative net refreezing means net melt production, not negative gross freezing.
[~,Z]=meshgrid(G.xc,G.yc);shell=Z(:)>=0;ocean=~shell;
V=phi(:).*G.V(:)*d^3;
volumes=[sum(V),sum(V(shell)),sum(V(ocean))];
if isempty(b)
    k=find(abs(G.yf)<100*eps(max(1,max(abs(G.yf)))));
    assert(isscalar(k) && k>1 && k<G.Ny+1,'z=0 must be an interior grid face.');
    b.regions={'domain','shell','ocean_region'};
    b.initial_volume_m3=volumes;
    b.interface_z_m=0;
    b.interface_faces=G.Nfx+k+(0:G.Nx-1)'*(G.Ny+1);
    b.melt_front_phi_threshold=1e-3;
    b.front_elevation_km=[];b.penetration_depth_km=[];
    b.definition='Net phase change by liquid-volume balance; includes melting/freezing throughout each region, not impact-origin tagging.';
    b.time_years=[];b.liquid_volume_m3=zeros(0,3);
    b.delivered_net_m3=[];b.refrozen_net_m3=zeros(0,3);
    delivered=0;
else
    ff=b.interface_faces;
    delivered=b.delivered_net_m3(end)-dt*d^3*sum(liquid_flux(ff).*G.A(ff));
end
refrozen=b.initial_volume_m3-volumes+[0,-delivered,delivered];
b.time_years(end+1,1)=time_years;
b.liquid_volume_m3(end+1,:)=volumes;
b.delivered_net_m3(end+1,1)=delivered;
b.refrozen_net_m3(end+1,:)=refrozen;
active=shell & phi(:)>=b.melt_front_phi_threshold;
if any(active)
    front=min(Z(active))*d/1000;
    depth=G.ymax*d/1000-front;
else
    front=NaN;depth=NaN;
end
b.front_elevation_km(end+1,1)=front;
b.penetration_depth_km(end+1,1)=depth;
b.history=table(b.time_years,b.liquid_volume_m3(:,1),b.liquid_volume_m3(:,2),b.liquid_volume_m3(:,3), ...
    b.delivered_net_m3,b.refrozen_net_m3(:,1),b.refrozen_net_m3(:,2),b.refrozen_net_m3(:,3), ...
    'VariableNames',{'time_years','melt_domain_m3','melt_shell_m3','melt_ocean_region_m3', ...
    'delivered_net_m3','refrozen_net_domain_m3','refrozen_net_shell_m3','refrozen_net_ocean_region_m3'});
b.history.front_elevation_km=b.front_elevation_km;
b.history.penetration_depth_km=b.penetration_depth_km;
end
