"""Render canonical scientific PDFs and check Times New Roman SVG labels."""
from pathlib import Path
import json
import shutil
import xml.etree.ElementTree as ET
import pypdfium2 as pdfium

root=Path(__file__).resolve().parents[1]
folder=Path((root/'tmp/centered_warm_cold_audit_output.txt').read_text().strip())
report={'font':'Times New Roman','dpi':180,'figures':{}}
for stem in ['01_centered_warm_cold_profiles_100yr','02_conduction_role_centered_cold']:
    tree=ET.parse(folder/(stem+'.svg'));parents={child:parent for parent in tree.iter() for child in parent}
    count=0
    for element in tree.iter():
        if not element.tag.endswith('text') or not ''.join(element.itertext()).strip():continue
        node=element
        while node is not None and 'font-family:' not in node.attrib.get('style',''):
            node=parents.get(node)
        assert node is not None and 'Times New Roman' in node.attrib['style'],stem
        count+=1
    doc=pdfium.PdfDocument(folder/(stem+'.pdf'));assert len(doc)==1
    page=doc[0];pil=page.render(scale=180/72).to_pil();pil.save(folder/(stem+'.png'))
    report['figures'][stem]={'visible_svg_text_labels':count,'all_labels_times_new_roman':True,'size_pixels':pil.size,'page_size_points':page.get_size()}
    page.close();doc.close()
for name in ['audit_centered_warm_cold_conduction.py','plot_centered_warm_cold_conduction.m','render_centered_conduction_figures.py']:
    shutil.copy2(root/'model_and_dependencies'/name,folder/(name+'.txt'))
(folder/'rendering_verification.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
