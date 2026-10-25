"""Copy the existing closed-box test with one physical change: initial phi."""
from pathlib import Path
import difflib
import hashlib
import json

root = Path(__file__).resolve().parents[1]
parent = root / 'model_and_dependencies/simple_test_1D_noflow_base.m'
target = root / 'model_and_dependencies/simple_test_1D_half_water_closed.m'
source = parent.read_text(encoding='utf-8')
old_name = 'simple_test_1D_noflow_base'
new_name = 'simple_test_1D_half_water_closed'
old_ic = '    phiGr = 0.5*ones(size(phiGr));  %make porosity 50% everywhere'
new_ic = ('    phiGr = double(Y > (Grid.p.ymin+Grid.p.ymax)/2); '
          '% HALF TEST: 0 below midpoint, 1 above')
assert source.count(old_ic) == 1
assert source.count('function result = '+old_name+'(') == 1
text = source.replace('function result = '+old_name+'(',
                      'function result = '+new_name+'(',1)
text = text.replace(old_ic,new_ic,1)
# Separate default output folder prevents overwriting the homogeneous test.
old_out = "'..','Output','closed_lid'));"
new_out = "'..','Output','half_water_closed'));"
assert text.count(old_out) == 1
text = text.replace(old_out,new_out,1)
# Reverting these three substitutions must reproduce the parent exactly.
reverted=text.replace('function result = '+new_name+'(',
                      'function result = '+old_name+'(',1)
reverted=reverted.replace(new_ic,old_ic,1).replace(new_out,old_out,1)
assert reverted == source
target.write_text(text,encoding='utf-8',newline='\n')
diff=''.join(difflib.unified_diff(source.splitlines(True),text.splitlines(True),
  fromfile=parent.name,tofile=target.name))
(root/'docs/HALF_WATER_CLOSED_TEST.diff').write_text(diff,encoding='utf-8')
provenance={'parent':str(parent),'target':str(target),
 'parent_sha256':hashlib.sha256(parent.read_bytes()).hexdigest(),
 'target_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
 'only_physical_change':'initial phi: 0 below domain midpoint, 1 above',
 'other_changes':['function name','isolated default output folder'],
 'reverse_substitution_matches_parent':True}
(root/'docs/HALF_WATER_CLOSED_TEST_PROVENANCE.json').write_text(
 json.dumps(provenance,indent=2),encoding='utf-8')
print(diff)
