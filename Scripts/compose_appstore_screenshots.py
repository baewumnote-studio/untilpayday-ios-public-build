#!/usr/bin/env python3
from __future__ import annotations
import argparse, json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
PLAN_PATH = ROOT / 'MarketingAssets/AppStoreScreenshots/ScreenshotPlan.json'
FONT_REG='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FONT_BOLD='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
W,H=1206,2622
NAVY='#0F172A'; SUB='#53677D'

def font(size,bold=False):
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)

def wrap(draw,text,fnt,width):
    words=text.split(); lines=[]; cur=''
    for word in words:
        trial=(cur+' '+word).strip()
        if draw.textbbox((0,0),trial,font=fnt)[2] <= width:
            cur=trial
        else:
            if cur: lines.append(cur)
            cur=word
    if cur: lines.append(cur)
    return lines

def centered(draw, lines, fnt, y, fill, gap=8):
    for line in lines:
        box=draw.textbbox((0,0),line,font=fnt); tw=box[2]-box[0]; th=box[3]-box[1]
        draw.text(((W-tw)/2,y),line,font=fnt,fill=fill)
        y += th+gap
    return y

def rounded_mask(size,radius):
    m=Image.new('L',size,0); d=ImageDraw.Draw(m); d.rounded_rectangle((0,0,size[0],size[1]),radius=radius,fill=255); return m

def compose(item, source: Path, output: Path):
    src=Image.open(source).convert('RGB')
    canvas=Image.new('RGB',(W,H),item['background']); d=ImageDraw.Draw(canvas)
    d.rounded_rectangle((72,70,314,132),31,fill='#FFFFFF')
    d.text((96,83),'Payday Left',font=font(30,True),fill=NAVY)
    title_lines=wrap(d,item['title'],font(72,True),1010)
    y=centered(d,title_lines,font(72,True),205,NAVY,10)
    y=centered(d,wrap(d,item['subtitle'],font(34),1000),font(34),y+24,SUB,8)
    # Device shell
    pl,pt,pr,pb=98,570,W-98,2440
    d.rounded_rectangle((pl+16,pt+26,pr+16,pb+26),88,fill='#C9D5E5')
    d.rounded_rectangle((pl,pt,pr,pb),88,fill='#0A0A0A')
    inner=(pl+26,pt+26,pr-26,pb-26)
    iw,ih=inner[2]-inner[0],inner[3]-inner[1]
    fitted=ImageOps.fit(src,(iw,ih),method=Image.Resampling.LANCZOS,centering=(0.5,0.5))
    mask=rounded_mask((iw,ih),70)
    canvas.paste(fitted,(inner[0],inner[1]),mask)
    # subtle shell border only; actual capture supplies island/status bar
    d.rounded_rectangle(inner,70,outline='#1B1B1D',width=4)
    d.text((W/2,H-92),'Payday Left',font=font(24,True),anchor='mm',fill='#7A8998')
    output.parent.mkdir(parents=True,exist_ok=True)
    canvas.save(output,quality=100)


def main():
    ap=argparse.ArgumentParser(description='Compose Payday Left App Store screenshots from actual Simulator captures.')
    ap.add_argument('--input-dir',required=True,type=Path)
    ap.add_argument('--output-dir',required=True,type=Path)
    args=ap.parse_args()
    plan=json.loads(PLAN_PATH.read_text(encoding='utf-8'))
    missing=[]
    for item in plan['items']:
        source=args.input_dir/item['source']
        if not source.is_file(): missing.append(str(source)); continue
        compose(item,source,args.output_dir/item['output'])
    if missing:
        raise SystemExit('Missing required simulator captures:\n  '+'\n  '.join(missing))
    print(f"Created {len(plan['items'])} screenshots in {args.output_dir}")

if __name__=='__main__': main()
