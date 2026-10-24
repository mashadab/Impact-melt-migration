function check_Jake_wave_agreement()
root=fileparts(mfilename('fullpath')); source=fullfile(root,'..','Output','Jake_2D_minimal_800_years_actual_kappa');
out=fullfile(source,'agreement_check'); if ~isfolder(out),mkdir(out);end
s=load(fullfile(source,'noflow_kc_5.600e-11.mat'),'result');r=s.result;
x=r.Grid.p.xc*r.length_scale_m; z=r.Grid.p.yc*r.length_scale_m;
[X,Z]=meshgrid(x,z); ny=numel(z); nx=numel(x);
P0=reshape(r.full_phi(:,1),ny,nx); [~,i0]=max(P0(:)); z0=Z(i0);
[iz0,ix0]=ind2sub(size(P0),i0);
den0=P0(iz0-1,ix0)-2*P0(iz0,ix0)+P0(iz0+1,ix0);
z0=z0+0.5*(P0(iz0-1,ix0)-P0(iz0+1,ix0))/den0*(z(2)-z(1));
c=5*5.6e-11*(1000-917)*9.81*0.001/0.001*(365.25*86400);
delta=sqrt(5.6e-11*0.001^2*1e14/(0.001*0.001));
t=r.time_years(:); n=numel(t); zp=zeros(n,1); amp=zeros(n,1); shape=zeros(n,1); shiftfit=zeros(n,1);
for j=1:n
 P=reshape(r.full_phi(:,j),ny,nx);
 % Search local wave only, excluding boundary accumulation.
 window=abs(Z-(z0-c*t(j)))<10*delta;
 % Locate the wave in the full upper domain; exclude the basal accumulation.
 Q=P; Q(Z<1000)=-Inf; [amp(j),ii]=max(Q(:));
 [iz,ix]=ind2sub(size(Q),ii); zp(j)=z(iz);
 % Quadratic subcell peak in z at the detected wave x-column.
 if iz>1 && iz<ny
  den=P(iz-1,ix)-2*P(iz,ix)+P(iz+1,ix);
  if den<0
   shift=0.5*(P(iz-1,ix)-P(iz+1,ix))/den;
   if abs(shift)<=1,zp(j)=zp(j)+shift*(z(2)-z(1));end
  end
 end
 pred=interp2(x,z,P0,X,Z+c*t(j),'linear',0.001);
 shape(j)=norm(P(window)-pred(window))/norm(pred(window)-0.001);
 % Best translated initial shape: use a broad local window and no amplitude fit.
 shiftfit(j)=fminbnd(@(a) shift_error(a,P,P0,x,z,X,Z,window), ...
      0,min(z0-1000,max(5*delta,20*c*t(j))));
 if z(iz)<1000+2*(z(2)-z(1)) || amp(j)<2*0.001
  zp(j)=NaN; amp(j)=NaN; shiftfit(j)=NaN;
 end
end
valid=t>0 & t<=60 & isfinite(zp); fit=polyfit(t(valid),zp(valid),1); numerical_speed=-fit(1);
metrics=table(t,zp,z0-c*t,amp,shape,shiftfit, ...
 'VariableNames',{'time_years','local_peak_z_m','theory_peak_z_m','local_peak_phi','translation_relative_L2','best_fit_downshift_m'});
writetable(metrics,fullfile(out,'agreement_metrics.csv'));
P=reshape(r.full_phi(:,end),ny,nx); theory=interp2(x,z,P0,X,Z+c*t(end),'linear',0.001);
f=figure('Visible','off','Color','w','Position',[50 50 1150 850]);tiledlayout(2,2);
nexttile;plot(t,zp/1000,'ro-',t,(z0-c*t)/1000,'b--'); xlabel('Time [years]');ylabel('Wave peak above 1 km [km]');legend('Numerical subcell peak','Theory 5w0');grid on;
nexttile;plot(t,amp,'o-');yline(max(P0(:)),'--');xlabel('Time [years]');ylabel('Local wave peak melt fraction');grid on;
nexttile;cols=[128 129];plot(mean(P(:,cols),2),z/1000,'r-',mean(theory(:,cols),2),z/1000,'b--');ylim([(z0-c*t(end)-8*delta)/1000,(z0-c*t(end)+8*delta)/1000]);xlabel('Central melt fraction');ylabel('Elevation [km]');legend('Numerical','Translated initial shape');grid on;
nexttile;imagesc(x/1000,z/1000,P);axis xy equal tight;colorbar;title(sprintf('Full field at %.3f years',t(end)));xlabel('x [km]');ylabel('Elevation [km]');
exportgraphics(f,fullfile(out,'agreement.png'),'Resolution',150);close(f);
fid=fopen(fullfile(out,'summary.txt'),'w');
lines={sprintf('Latest saved field: step %d, time %.9g years',r.steps(end),t(end)), ...
 sprintf('Theory speed %.9g m/yr; expected downward shift %.9g m',c,c*t(end)), ...
 sprintf('Upper-domain wave speed fit through 60 years %.9g m/yr, theory ratio %.9g',numerical_speed,numerical_speed/c), ...
 sprintf('Numerical local-peak downward shift %.9g m; displacement error %.4f percent',zp(1)-zp(end),100*((zp(1)-zp(end))/(c*t(end))-1)), ...
 sprintf('Best-fit translated-profile downward shift %.9g m',shiftfit(end)), ...
 sprintf('Wave peak phi initial %.12g latest %.12g; amplitude change %.4f percent',amp(1),amp(end),100*(amp(end)/amp(1)-1)), ...
 sprintf('Relative L2 difference from theoretical translated initial wave %.9g',shape(end)), ...
 sprintf('Global peak phi %.9g; bottom row phi range [%.9g %.9g]',max(P(:)),min(P(1,:)),max(P(1,:))), ...
 sprintf('Saved temperature range [%.12g %.12g] K',min(r.full_T_K(:,end)),max(r.full_T_K(:,end))), ...
 sprintf('Relative enthalpy conservation error %.9g',r.history(r.steps(end),11)/r.initial_enthalpy_total)};
for j=1:numel(lines),fprintf('%s\n',lines{j});fprintf(fid,'%s\n',lines{j});end
fclose(fid);
end
function e=shift_error(a,P,P0,x,z,X,Z,window)
q=interp2(x,z,P0,X,Z+a,'linear',0.001); e=sum((P(window)-q(window)).^2);
end
