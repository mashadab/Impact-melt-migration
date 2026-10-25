from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
B=Path(__file__).resolve().parent
files=sorted((B/'renders').glob('slide_*.png'))
im=Image.new('RGB',(1600,6*203),'#e5e5e5');draw=ImageDraw.Draw(im)
font=ImageFont.truetype('C:/Windows/Fonts/times.ttf',16)
for i,p in enumerate(files):
    src=Image.open(p).convert('RGB');src.thumbnail((310,175))
    x=(i%5)*320+5;y=(i//5)*203+5
    im.paste(src,(x,y));draw.text((x,y+176),str(i+1),font=font,fill='black')
im.save(B/'contact_sheet.png')
