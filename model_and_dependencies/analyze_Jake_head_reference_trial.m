function metrics=analyze_Jake_head_reference_trial(r)
root=fileparts(mfilename('fullpath')); out=fullfile(root,'..','Output','Jake_head_reference_trial_10yr');
x=r.Grid.p.xc*r.length_scale_m; z=r.Grid.p.yc*r.length_scale_m;
[X,Z]=meshgrid(x,z); ny=numel(z); nx=numel(x);
t=r.time_years(:); n=numel(t); zp=zeros(n,1); amp=zeros(n,1);
for j=1:n
 P=reshape(r.full_phi(:,j),ny,nx); P(Z<1000)=-Inf;
 [amp(j),ii]=max(P(:)); [iz,ix]=ind2sub(size(P),ii);
 dz=0.5*(P(iz-1,ix)-P(iz+1,ix))/(P(iz-1,ix)-2*P(iz,ix)+P(iz+1,ix));
 zp(j)=z(iz)+dz*(z(2)-z(1));
end
c=5*5.6e-11*83*9.81*0.001/0.001*365.25*86400;
fit=polyfit(t,zp,1); speed=-fit(1);
% Reuse stopped-run data for the uncorrected comparison; no extra simulation.
b=load(fullfile(root,'..','Output','Jake_2D_minimal_800_years_actual_kappa','noflow_kc_5.600e-11.mat'),'result'); b=b.result;
bt=b.time_years(:); ids=find(bt<=t(end)); bz=zeros(size(ids));
for k=1:numel(ids)
 B=reshape(b.full_phi(:,ids(k)),ny,nx); B(Z<1000)=-Inf;
 [~,ii]=max(B(:)); [iz,ix]=ind2sub(size(B),ii);
 dz=0.5*(B(iz-1,ix)-B(iz+1,ix))/(B(iz-1,ix)-2*B(iz,ix)+B(iz+1,ix));
 bz(k)=z(iz)+dz*(z(2)-z(1));
end
bf=polyfit(bt(ids),bz,1); badspeed=-bf(1);
P0=reshape(r.full_phi(:,1),ny,nx); P=reshape(r.full_phi(:,end),ny,nx);
Q=interp2(x,z,P0,X,Z+c*t(end),'linear',0.001);
window=abs(Z-(zp(1)-c*t(end)))<750;
shape=norm(P(window)-Q(window))/norm(Q(window)-0.001);
metrics=table(t,zp,zp(1)-c*t,amp,'VariableNames',{'time_years','numerical_peak_z_m','theory_peak_z_m','peak_phi'});
writetable(metrics,fullfile(out,'agreement.csv'));
f=figure('Visible','off','Color','w','Position',[50 50 1100 750]); tiledlayout(2,2);
nexttile;plot(t,zp/1000,'ro-',t,(zp(1)-c*t)/1000,'b--',bt(ids),bz/1000,'kx-');legend('Corrected','Theory 5w0','Previous forcing');xlabel('Time [yr]');ylabel('Wave peak [km]');grid on;
nexttile;plot(r.history(:,1),r.history(:,2:3)-273);xlabel('Time [yr]');ylabel('T - 273 K');grid on;
nexttile;plot(mean(P(:,128:129),2),z/1000,'r-',mean(Q(:,128:129),2),z/1000,'b--');ylim([7 8.3]);legend('Numerical','Theory translated shape');xlabel('Melt fraction');ylabel('Elevation [km]');grid on;
nexttile;plot(r.history(:,1),r.history(:,11)/r.initial_enthalpy_total);xlabel('Time [yr]');ylabel('Relative enthalpy error');grid on;
exportgraphics(f,fullfile(out,'trial_agreement.png'),'Resolution',150);close(f);
report=sprintf(['TRIAL_COMPLETE steps=%d years=%.9g\nNumerical speed=%.9g m/yr; theory=%.9g m/yr; speed error=%.4f percent\n' ...
 'Previous forcing speed over early saved trajectory=%.9g m/yr\nTemperature=[%.12g %.12g] K; max relative enthalpy error=%.3g\nRelative translated-wave L2 error=%.9g\n'], ...
 r.completed_steps,t(end),speed,c,100*(speed/c-1),badspeed,min(r.history(:,2)),max(r.history(:,3)), ...
 max(abs(r.history(:,11)))/abs(r.initial_enthalpy_total),shape);
fid=fopen(fullfile(out,'trial_summary.txt'),'w');fprintf(fid,'%s',report);fclose(fid);fprintf('%s',report);
end
