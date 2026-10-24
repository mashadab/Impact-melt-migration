function plot_porosity_wave_2D_Jake_step1()
root=fileparts(mfilename('fullpath')); out=fullfile(root,'..','Output','s3_minimal_1_steps');
d=load(fullfile(out,'noflow_kc_5.600e-11.mat'),'result'); r=d.result;
x=r.Grid.p.xc*r.length_scale_m/1000; z=r.Grid.p.yc*r.length_scale_m/1000;
f=figure('Visible','off','Color','w','Position',[100 100 1100 650]); tiledlayout(1,3);
nexttile; imagesc(x,z,reshape(r.full_phi(:,1),r.Grid.p.Ny,r.Grid.p.Nx));
axis xy equal tight; caxis([min(r.full_phi(:,1)),max(r.full_phi(:,1))]); colorbar;
title('Initial melt fraction'); xlabel('x [km]'); ylabel('Elevation [km]');
nexttile; imagesc(x,z,reshape(r.full_phi(:,end),r.Grid.p.Ny,r.Grid.p.Nx));
axis xy equal tight; caxis([min(r.full_phi(:,1)),max(r.full_phi(:,1))]); colorbar;
title(sprintf('Step 1: %.7g years',r.time_years(end))); xlabel('x [km]'); ylabel('Elevation [km]');
nexttile; imagesc(x,z,reshape(r.full_T_K(:,end)-273,r.Grid.p.Ny,r.Grid.p.Nx));
axis xy equal tight; caxis([-1e-10 1e-10]); colorbar;
title('Recovered T - 273 K'); xlabel('x [km]'); ylabel('Elevation [km]');
exportgraphics(f,fullfile(out,'Jake_2D_step1.png'),'Resolution',150); close(f);
f=figure('Visible','off','Color','w','Position',[100 100 1000 650]); tiledlayout(1,2);
nexttile; imagesc(x,z,reshape(r.full_phi(:,end)-r.full_phi(:,1),r.Grid.p.Ny,r.Grid.p.Nx));
axis xy equal tight; colorbar; title('Step 1 minus initial melt fraction'); xlabel('x [km]'); ylabel('Elevation [km]');
nexttile; P0=reshape(r.full_phi(:,1),r.Grid.p.Ny,r.Grid.p.Nx); P1=reshape(r.full_phi(:,end),r.Grid.p.Ny,r.Grid.p.Nx);
plot(mean(P0(:,128:129),2),z,mean(P1(:,128:129),2),z,'--'); ylim([7.2 8.2]);
xlabel('Melt fraction'); ylabel('Elevation [km]'); legend('Initial','Step 1'); grid on;
exportgraphics(f,fullfile(out,'Jake_2D_step1_difference.png'),'Resolution',150);close(f);
fprintf('STEP1 t=%.12g yr phi=[%.12g %.12g] T=[%.12g %.12g] max_delta_phi=%.9g\n', ...
r.time_years(end),min(r.full_phi(:,end)),max(r.full_phi(:,end)),min(r.full_T_K(:,end)),max(r.full_T_K(:,end)),max(abs(r.full_phi(:,end)-r.full_phi(:,1))));
end
