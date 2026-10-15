from pathlib import Path
import concurrent.futures
import json
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
FFMPEG = Path(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\PackOpeningRework20260926\tools\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe')
MAIN = Path(r'C:\Users\sandt\Downloads\G-Blox ad + video trailer (preedit).mp4')
GAME = Path(r'C:\Users\sandt\Downloads\2026-09-13 00-44-14.mp4')
MUSIC = Path(r'C:\Users\sandt\Downloads\alex-morgan-gaming-stream-arcade-session-578484.mp3')
LOGO = Path(r'C:\Users\sandt\Downloads\Game name.png')
ICON = Path(r'C:\Users\sandt\AppData\Local\Temp\codex-clipboard-372256f5-5a5b-454f-8913-3b2b0dec0441.webp')
FONT = Path(r'C:\Users\sandt\AppData\Local\Roblox\Versions\version-2366ba214ec740ca\content\fonts\PressStart2P-Regular.ttf')
SHOTS = [
    dict(name='Logo and gravity hook', source='gameplay', start=25.5, duration=2.5, speed=1, text='FLIP. RACE. WIN.', position='intro'),
    dict(name='Lobby tour at 2x', source='main', start=16, duration=4, speed=2, text='YOUR NEXT RACE STARTS HERE', position='bottom'),
    dict(name='Gravity switch', source='gameplay', start=109, duration=2.5, speed=1, text='MASTER GRAVITY', position='top'),
    dict(name='Spike wall run', source='gameplay', start=131.75, duration=2.5, speed=1, text='DODGE THE DANGER', position='top'),
    dict(name='Saw close call', source='gameplay', start=161.75, duration=2.5, speed=1, text='KEEP MOVING.', position='top'),
    dict(name='Course flythrough', source='main', start=80, duration=3, speed=1.5, text='FIVE ROUNDS. ONE WINNER.', position='bottom'),
    dict(name='Full course reveal', source='main', start=93, duration=3, speed=1.5, text='CAN YOU GO ALL THE WAY?', position='bottom'),
    dict(name='Podium reveal', source='main', start=146.5, duration=3, speed=1, text='TAKE THE TOP SPOT', position='top'),
    dict(name='Victory emote', source='main', start=155, duration=3, speed=1, text='CELEBRATE YOUR WAY', position='bottom'),
    dict(name='Play call to action', source='main', start=93, duration=4, speed=1, text='', position='end'),
]

def run(args, log):
    result = subprocess.run([str(FFMPEG), '-hide_banner', '-loglevel', 'error', '-nostdin', '-y', *map(str, args)], capture_output=True, text=True)
    log.write_text(result.stderr, encoding='utf-8')
    if result.returncode:
        raise RuntimeError(result.stderr[-4000:])

def font(size):
    return ImageFont.truetype(str(FONT), size)

def centered(draw, text, y, size, fill='white', stroke=3, center=960):
    f = font(size)
    box = draw.textbbox((0, 0), text, font=f, stroke_width=stroke)
    x = center - (box[2] - box[0]) / 2 - box[0]
    draw.text((x, y-box[1]), text, font=f, fill=fill, stroke_width=stroke, stroke_fill='#00141f')

def overlay(shot, index):
    img = Image.new('RGBA', (1920, 1080))
    draw = ImageDraw.Draw(img)
    if shot['position'] == 'end':
        draw.rectangle((0, 0, 1920, 1080), fill=(0, 15, 33, 223))
        draw.rounded_rectangle((126, 186, 774, 834), radius=8, fill='#00dce3')
        icon = Image.open(ICON).convert('RGBA').resize((632, 632), Image.Resampling.LANCZOS)
        img.alpha_composite(icon, (134, 194))
        logo = Image.open(LOGO).convert('RGBA')
        logo = logo.resize((900, round(900*logo.height/logo.width)), Image.Resampling.LANCZOS)
        img.alpha_composite(logo, (885, 182))
        centered(draw, 'SEARCH G-BLOX', 659, 72, stroke=3, center=1335)
        centered(draw, 'ON ROBLOX', 758, 56, fill='#5deaf0', stroke=2, center=1335)
        centered(draw, 'FLIP. RACE. WIN.', 932, 48, fill='#5deaf0', stroke=2)
    elif shot['position'] == 'intro':
        draw.rectangle((0, 0, 1920, 1080), fill=(0, 15, 33, 95))
        logo = Image.open(LOGO).convert('RGBA')
        logo = logo.resize((1050, round(1050*logo.height/logo.width)), Image.Resampling.LANCZOS)
        img.alpha_composite(logo, ((1920-logo.width)//2, 106))
        centered(draw, shot['text'], 900, 64, stroke=4)
    else:
        text = shot['text']
        size = 64 if len(text) < 23 else 58
        f = font(size)
        width = draw.textlength(text, font=f) + 72
        y = 84 if shot['position'] == 'top' else 864
        left = (1920-width)/2
        draw.rounded_rectangle((left, y, left+width, y+140), radius=8, fill=(0, 22, 37, 222), outline='#01d8e3', width=3)
        centered(draw, text, y+47, size, stroke=2)
    path = ROOT/f'title_{index:02}.png'
    img.save(path)
    return path

def render_shot(pair):
    index, shot = pair
    title = overlay(shot, index)
    src = MAIN if shot['source']=='main' else GAME
    crop = 'crop=1888:1062:16:9' if shot['source']=='main' else 'crop=1230:692:20:28'
    out = ROOT/f'shot_{index:02}.mp4'
    vf = f'[0:v]setpts=(PTS-STARTPTS)/{shot["speed"]},{crop},scale=1920:1080:flags=lanczos,setsar=1,fps=30,tpad=stop_mode=clone:stop_duration=1,format=yuv420p[v];[v][1:v]overlay=0:0:shortest=1,format=yuv420p[out]'
    run(['-ss',shot['start'],'-t',shot['duration']*shot['speed'],'-i',src,'-loop','1','-i',title,'-filter_complex_threads','1','-filter_complex',vf,'-map','[out]','-an','-frames:v',round(shot['duration']*30),'-c:v','libx264','-preset','fast','-crf','18','-threads','3','-pix_fmt','yuv420p','-movflags','+faststart',out],ROOT/f'shot_{index:02}.log')
    print(f'Finished shot {index+1}: {shot["name"]}', flush=True)
    return out

def main():
    assert abs(sum(s['duration'] for s in SHOTS)-30)<.001
    timeline = 0
    for shot in SHOTS:
        shot['timeline_start']=timeline
        timeline+=shot['duration']
    (ROOT/'edit_decisions.json').write_text(json.dumps({'duration':30,'size':[1920,1080],'fps':30,'original_audio':'muted','music':str(MUSIC),'shots':SHOTS},indent=2),encoding='utf-8')
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        outputs=list(pool.map(render_shot,enumerate(SHOTS)))
    concat=ROOT/'shots.txt'
    concat.write_text(''.join("file '"+p.as_posix()+"'\n" for p in outputs),encoding='utf-8')
    run(['-f','concat','-safe','0','-i',concat,'-c','copy','-movflags','+faststart',ROOT/'picture_edit.mp4'],ROOT/'picture_edit.log')
    run(['-i',ROOT/'picture_edit.mp4','-i',MUSIC,'-map','0:v:0','-map','1:a:0','-t','30','-c:v','copy','-af','loudnorm=I=-16:TP=-1.5:LRA=9,afade=t=in:st=0:d=0.35,afade=t=out:st=28.5:d=1.5','-c:a','aac','-b:a','192k','-ar','48000','-movflags','+faststart',ROOT/'G-Blox_Trailer_30s_Music_Only.mp4'],ROOT/'music_render.log')
    print('DONE: '+str(ROOT/'G-Blox_Trailer_30s_Music_Only.mp4'),flush=True)
    if (ROOT/'Archie_narration.wav').exists():
        subprocess.run([sys.executable,str(ROOT/'mix_narration.py')],check=True)

if __name__=='__main__':
    main()
