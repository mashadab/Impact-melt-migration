"""Separate, minimal initialization change from the preserved flat-layer test."""
from pathlib import Path
import difflib
import hashlib
import json

root=Path(__file__).resolve().parents[1]
parent=root/'model_and_dependencies/simple_test_1D_half_water_closed.m'
target=root/'model_and_dependencies/simple_test_1D_centered_blob_closed.m'
source=parent.read_text(encoding='utf-8')
old='    phiGr = double(Y > (Grid.p.ymin+Grid.p.ymax)/2); % HALF TEST: 0 below midpoint, 1 above'
new="""    phiGr = double(Y > (Grid.p.ymin+Grid.p.ymax)/2 & ...
        X > Grid.p.xmin+0.25*(Grid.p.xmax-Grid.p.xmin) & ...
        X < Grid.p.xmin+0.75*(Grid.p.xmax-Grid.p.xmin)); % centered upper-half water"""
assert source.count(old)==1
text=source.replace('function result = simple_test_1D_half_water_closed(',
                    'function result = simple_test_1D_centered_blob_closed(',1)
text=text.replace(old,new,1)
text=text.replace("'..','Output','half_water_closed'));","'..','Output','centered_blob_closed'));",1)
needle='    H = porNonH_fun(phi,T); %Dimensionless enthalpy array'
assert text.count(needle)==1
save_initial="""
    % Save the actual initialized fields; this does not affect evolution.
    initial_state=struct('H',H,'T_dimensionless',T,'phi',phi,'Grid',Grid, ...
        'd_m',d,'temperature_scale_K',DT,'temperature_offset_K',T_t);
    save(fullfile(options.output_dir,'initial_state.mat'),'initial_state');"""
text=text.replace(needle,needle+save_initial,1)
# Verify the complete source identity after reversing the documented changes.
reverse=text.replace('function result = simple_test_1D_centered_blob_closed(',
                     'function result = simple_test_1D_half_water_closed(',1)
reverse=reverse.replace(new,old,1).replace(save_initial,'',1)
reverse=reverse.replace("'..','Output','centered_blob_closed'));","'..','Output','half_water_closed'));",1)
assert reverse==source
target.write_text(text,encoding='utf-8',newline='\n')
diff=''.join(difflib.unified_diff(source.splitlines(True),text.splitlines(True),
 fromfile=parent.name,tofile=target.name))
(root/'docs/CENTERED_BLOB_CLOSED_TEST.diff').write_text(diff,encoding='utf-8')
(root/'docs/CENTERED_BLOB_CLOSED_TEST_PROVENANCE.json').write_text(json.dumps({
 'parent':str(parent),'target':str(target),
 'parent_sha256':hashlib.sha256(parent.read_bytes()).hexdigest(),
 'target_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
 'only_physical_change':'water initially restricted to x in central half, z in upper half',
 'other_changes':['function name','output directory','save actual full initialization'],
 'reverse_substitution_matches_parent':True},indent=2),encoding='utf-8')
print(diff)
