import json
import subprocess
import sys
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent
sys.path.insert(0, str(root / 'Tools'))
import imageio_ffmpeg

video = Path(r'C:\Users\sandt\OneDrive\Videos\Captures\Roblox 2026-10-03 16-21-22.mp4')
out = root / 'ReferenceFrames'
out.mkdir(exist_ok=True)
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
probe = subprocess.run([ffmpeg,'-hide_banner','-i',str(video)],capture_output=True,text=True)
(out/'ClipMetadata.txt').write_text(probe.stderr,encoding='utf-8')
subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-i',str(video),'-vf','fps=1,scale=480:-2','-q:v','3','-y',str(out/'overview_%03d.jpg')],check=True)
frames = sorted(out.glob('overview_*.jpg'))
for page in range((len(frames)+15)//16):
    group = frames[page*16:page*16+16]
    sheet = Image.new('RGB',(1920,4*294),(24,30,40))
    draw = ImageDraw.Draw(sheet)
    for index,path in enumerate(group):
        im = Image.open(path)
        x,y=(index%4)*480,(index//4)*294
        sheet.paste(im,(x,y))
        draw.text((x+8,y+im.height+4),f'{page*16+index:02d}s',fill='white')
    sheet.save(out/f'Overview_{page+1}.jpg',quality=92)
print(json.dumps({'frames':len(frames),'sheets':[str(p) for p in out.glob('Overview_*.jpg')],'metadata':probe.stderr}))
