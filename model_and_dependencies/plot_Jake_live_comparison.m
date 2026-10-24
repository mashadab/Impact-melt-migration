function stats=plot_Jake_live_comparison()
% Read saved data only. The live solver and its files are not modified.
root=fileparts(mfilename('fullpath'));
source=fullfile(root,'..','Output','Jake_2D_minimal_800_years_actual_kappa_head_reference');
out=fullfile(source,'live_comparison'); if ~isfolder(out),mkdir(out);end
file=fullfile(source,'noflow_kc_5.600e-11.mat');
for attempt=1:3
 try
  s=load(file,'result'); break;
 catch err
  if attempt==3,rethrow(err);end
  pause(2);
 end
end
r=s.result; step=r.steps(end); h=r.history(1:step,:);
x=r.Grid.p.xc*r.length_scale_m; z=r.Grid.p.yc*r.length_scale_m;
[X,Z]=meshgrid(x,z); ny=numel(z); nx=numel(x);
P0=reshape(r.full_phi(:,1),ny,nx);
phi0=0.001; kc=r.kc; c=5*kc*83*9.81*phi0/0.001*365.25*86400;
t=r.time_years(:); n=numel(t); zp=zeros(n,1); amp=zeros(n,1); err=zeros(n,1);
[~,ii]=max(P0(:)); [iz,ix]=ind2sub(size(P0),ii);
z0=subcell_peak(P0,iz,ix,z);
for j=1:n
 P=reshape(r.full_phi(:,j),ny,nx);
 win=abs(Z-(z0-c*t(j)))<1000;
 search=P;search(~win)=-Inf;
 [amp(j),ii]=max(search(:));[iz,ix]=ind2sub(size(P),ii);
 zp(j)=subcell_peak(P,iz,ix,z);
 Q=interp2(x,z,P0,X,Z+c*t(j),'linear',phi0);
 err(j)=norm(P(win)-Q(win))/norm(Q(win)-phi0);
end
fit=polyfit(t,zp,1); speed=-fit(1);
wave=abs(Z-(z0-c*t(end)))<1000;
D=P-Q; cols=[floor((nx+1)/2) ceil((nx+1)/2)];
metrics=table(r.steps(:),t,zp,z0-c*t,zp-(z0-c*t),amp,err, ...
 'VariableNames',{'step','time_years','numerical_peak_z_m','theory_peak_z_m','peak_position_error_m','wave_peak_phi','wave_relative_L2'});
writetable(metrics,fullfile(out,'trajectory.csv'));
% Full-domain 2D panels retain boundary accumulation in both fields and error.
f=figure('Visible','off','Color','w','Position',[40 40 1200 850]); tiledlayout(1,3);
nexttile; imagesc(x/1000,z/1000,P);axis xy equal tight;caxis([phi0 max(P0(:))]);colorbar;
xlabel('x [km]');ylabel('Elevation [km]');title(sprintf('Numerical: %.3f years',t(end)));
nexttile;imagesc(x/1000,z/1000,Q);axis xy equal tight;caxis([phi0 max(P0(:))]);colorbar;
xlabel('x [km]');ylabel('Elevation [km]');title('Analytic traveling-wave reference');
nexttile;imagesc(x/1000,z/1000,D);axis xy equal tight;v=max(abs(D(:)));if v==0,v=eps;end;caxis([-v v]);colorbar;
xlabel('x [km]');ylabel('Elevation [km]');title('Numerical minus reference');
exportgraphics(f,fullfile(out,'comparison_2D.png'),'Resolution',150);close(f);
% Wave-region 2D plots show small profile discrepancies without masking data.
f=figure('Visible','off','Color','w','Position',[40 40 1200 650]);tiledlayout(1,3);
fields={P,Q,D}; titles={'Numerical wave','Analytic traveling-wave reference','Numerical minus reference'};
for j=1:3
 nexttile;imagesc(x/1000,z/1000,fields{j});axis xy equal tight;
 ylim([(z0-c*t(end)-800)/1000 (z0-c*t(end)+800)/1000]);colorbar;
 if j<3,caxis([phi0 max(P0(:))]);else,v=max(abs(D(wave)));caxis([-v v]);end
 title(titles{j});xlabel('x [km]');ylabel('Elevation [km]');
end
exportgraphics(f,fullfile(out,'comparison_2D_wave_zoom.png'),'Resolution',150);close(f);
f=figure('Visible','off','Color','w','Position',[40 40 1200 850]);tiledlayout(2,2);
nexttile;plot(mean(P(:,cols),2),z/1000,'r-',mean(Q(:,cols),2),z/1000,'b--','LineWidth',1.4);
xlabel('Melt volume fraction');ylabel('Elevation [km]');title('Vertical centerline, full domain');legend('Numerical','Analytic reference');grid on;
nexttile;plot(mean(P(:,cols),2),z/1000,'r-',mean(Q(:,cols),2),z/1000,'b--','LineWidth',1.4);
ylim([(z0-c*t(end)-800)/1000 (z0-c*t(end)+800)/1000]);xlabel('Melt volume fraction');ylabel('Elevation [km]');title('Vertical centerline, wave region');legend('Numerical','Analytic reference');grid on;
nexttile;plot(t,zp/1000,'ro-',t,(z0-c*t)/1000,'b--','LineWidth',1.3);
xlabel('Time [years]');ylabel('Wave peak elevation [km]');legend('Numerical subcell peak','Theory 5w0');grid on;
nexttile;plot(t,zp-(z0-c*t),'o-');xlabel('Time [years]');ylabel('Numerical minus theoretical peak [m]');grid on;
exportgraphics(f,fullfile(out,'comparison_1D.png'),'Resolution',150);close(f);
f=figure('Visible','off','Color','w','Position',[40 40 1050 650]);tiledlayout(1,2);
nexttile;plot(h(:,1),h(:,2:3)-273);xlabel('Time [years]');ylabel('Recovered T - 273 K');legend('Minimum','Maximum');grid on;
nexttile;plot(h(:,1),h(:,11)/r.initial_enthalpy_total);xlabel('Time [years]');ylabel('Relative enthalpy error');grid on;
exportgraphics(f,fullfile(out,'thermal_diagnostics.png'),'Resolution',150);close(f);
stats=struct('step',step,'time_years',t(end),'numerical_speed_m_yr',speed,'theory_speed_m_yr',c, ...
 'speed_error_percent',100*(speed/c-1),'peak_error_m',zp(end)-(z0-c*t(end)), ...
 'wave_relative_L2',err(end),'amplitude_change_percent',100*(amp(end)/amp(1)-1), ...
 'T_min_K',min(h(:,2)),'T_max_K',max(h(:,3)), ...
 'max_relative_enthalpy_error',max(abs(h(:,11)))/abs(r.initial_enthalpy_total));
save(fullfile(out,'comparison_metrics.mat'),'stats','metrics');
report=sprintf(['SNAPSHOT step=%d t=%.9g years\nNumerical speed=%.9g m/yr; theory=%.9g m/yr; error=%.5g percent\n' ...
 'Peak position error=%.9g m; wave L2 error=%.9g; amplitude change=%.6g percent\n' ...
 'Recovered T=[%.12g %.12g] K; max relative enthalpy error=%.3g\n'], ...
 step,t(end),speed,c,stats.speed_error_percent,stats.peak_error_m,err(end),stats.amplitude_change_percent, ...
 stats.T_min_K,stats.T_max_K,stats.max_relative_enthalpy_error);
fid=fopen(fullfile(out,'summary.txt'),'w');fprintf(fid,'%s',report);fclose(fid);fprintf('%s',report);
end
function zz=subcell_peak(P,iz,ix,z)
zz=z(iz);
if iz>1 && iz<size(P,1)
 den=P(iz-1,ix)-2*P(iz,ix)+P(iz+1,ix);
 if den<0
  dz=0.5*(P(iz-1,ix)-P(iz+1,ix))/den;
  if abs(dz)<=1,zz=zz+dz*(z(2)-z(1));end
 end
end
end
