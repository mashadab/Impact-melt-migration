function verify_Europa_depletion_stop
root=fileparts(mfilename('fullpath'));addpath(root);
out=fullfile(root,'..','Output',['Europa_stop_verification_' datestr(now,'yyyymmdd_HHMMSS')]);
o=struct('max_steps',3,'stop_on_melt_loss',true,'remaining_melt_fraction',0.99,'output_dir',fullfile(out,'reached'));
r=run_darcy_stokes_case('impact_melt_europa',o);
assert(strcmp(r.status,'melt_depleted') && r.depletion_reached && r.completed_steps==1);
assert(r.remaining_shell_melt_fraction<=0.99);
o_compare=o;o_compare.stop_on_melt_loss=false;o_compare.max_steps=1;
o_compare.save_state_snapshots=true;o_compare.output_dir=fullfile(out,'reference_no_stop');
a=run_darcy_stokes_case('impact_melt_europa',o_compare);
assert(isequal(r.final_state,a.final_state));
assert(r.permeability_exponent==3);
q=load(fullfile(o_compare.output_dir,'states','state_00000001.mat'),'state');
assert(isequal(q.state.phi,a.final_state.phi) && q.state.permeability_exponent==3);
assert(q.state.flow_time_years<q.state.time_years && all(isfinite(q.state.fluid_pressure_Pa)));
o.max_steps=1;o.remaining_melt_fraction=0.005;o.output_dir=fullfile(out,'not_reached');
r=run_darcy_stokes_case('impact_melt_europa',o);
assert(strcmp(r.status,'step_limit') && ~r.depletion_reached);
assert(r.remaining_shell_melt_fraction>0.005);
assert(abs(r.initial_shell_melt_m3-31780351283.7143)<0.01);
fprintf('DEPLETION_STOP_VERIFIED: actual threshold completion and safety-limit noncompletion; stop rule does not change evolution; cubic Europa law and state export verified.\n');
end
