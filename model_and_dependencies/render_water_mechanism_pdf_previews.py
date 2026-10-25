"""Render the canonical vector PDFs to PNG, avoiding MATLAB raster clipping."""
from pathlib import Path
import json
import sys
import xml.etree.ElementTree as ET
import pypdfium2 as pdfium

root=Path(__file__).resolve().parents[1]
folder=Path(sys.argv[1]) if len(sys.argv)>1 else Path(
    (root/'tmp/flat_centered_video_output.txt').read_text().strip())/'mechanism_figures_times'
report={'font':'Times New Roman','raster_source':'canonical vector PDF','dpi':200,'figures':{}}
for stem in ['01_flat_layer_mechanism','02_centered_body_mechanism']:
    tree=ET.parse(folder/(stem+'.svg'))
    parents={child:parent for parent in tree.iter() for child in parent}
    text_count=0
    for element in tree.iter():
        if not element.tag.endswith('text') or not ''.join(element.itertext()).strip():
            continue
        node=element
        while node is not None and 'font-family:' not in node.attrib.get('style',''):
            node=parents.get(node)
        assert node is not None and 'Times New Roman' in node.attrib['style'], stem
        text_count+=1
    doc=pdfium.PdfDocument(folder/(stem+'.pdf'))
    assert len(doc)==1
    page=doc[0]
    image=page.render(scale=200/72).to_pil()
    image.save(folder/(stem+'.png'))
    report['figures'][stem]={'text_labels_verified':text_count,'page_size_points':page.get_size(),
                             'png_size_pixels':image.size,'all_svg_text_times_new_roman':True}
    page.close();doc.close()
(folder/'rendering_verification.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
