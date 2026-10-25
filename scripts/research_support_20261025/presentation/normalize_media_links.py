"""Remove optional empty relationship IDs from native PowerPoint media actions."""
from pathlib import Path
import re
import zipfile
import json
B=Path(__file__).resolve().parent
source=B/'candidate_media.pptx';target=B/'candidate_media_clean.pptx'
changes=[]
with zipfile.ZipFile(source) as zin,zipfile.ZipFile(target,'w',compression=zipfile.ZIP_DEFLATED) as zout:
    for info in zin.infolist():
        data=zin.read(info.filename)
        if re.fullmatch(r'ppt/slides/slide\d+\.xml',info.filename):
            xml=data.decode('utf-8');count=[0]
            def fix(match):
                text=match.group(0)
                if 'action="ppaction://media"' in text and 'r:id=""' in text:
                    count[0]+=1;return text.replace(' r:id=""','')
                return text
            xml=re.sub(r'<a:hlinkClick\b[^>]*>',fix,xml)
            if count[0]:changes.append({'part':info.filename,'optional_empty_relationship_ids_removed':count[0]})
            data=xml.encode('utf-8')
        zout.writestr(info,data)
assert sum(x['optional_empty_relationship_ids_removed'] for x in changes)==7
(B/'media_link_normalization.json').write_text(json.dumps(changes,indent=2))
print('MEDIA_LINKS_NORMALIZED',7)
