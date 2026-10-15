from pathlib import Path
import argparse
import json
from edit_trailer import ROOT, MUSIC, run

parser = argparse.ArgumentParser()
parser.add_argument('--pace',type=float,default=1.0)
parser.add_argument('--label',default='Archie')
args = parser.parse_args()
assert .8 <= args.pace <= 1.3
assert args.label.replace('_','').isalnum()

VOICE = ROOT/'Archie_narration.wav'
WINDOWS = [
    (0.00, 2.38, 0.10, 1.0, 'This is G Blox.'),
    (2.65, 5.70, 2.80, 1.0, 'Your next race starts here.'),
    (5.89, 12.00, 6.60, 1.0, 'Flip gravity, dodge deadly spikes, and race your friends through five rounds of chaos.'),
    (12.45, 14.14, 14.10, 1.0, 'Take on sky-high courses.'),
    (18.73, 20.55, 17.25, 1.0, 'Think you can go all the way?'),
    (14.20, 15.80, 20.20, 1.0, 'Fight for first place.'),
    (15.85, 18.22, 23.10, 1.0, 'Then celebrate with your favourite emotes.'),
    (20.65, 26.087, 26.10, 1.45, 'Search G Blox on Roblox. Flip. Race. Win.'),
]

filters = ['[2:a]asplit=8'+''.join(f'[raw{i}]' for i in range(8))]
for i,(start,end,at,speed,text) in enumerate(WINDOWS):
    speed *= args.pace
    duration=(end-start)/speed
    filters.append(f'[raw{i}]atrim=start={start}:end={end},asetpts=PTS-STARTPTS,atempo={speed},afade=t=in:st=0:d=0.015,afade=t=out:st={duration-.015}:d=0.015,adelay={round(at*1000)}:all=1[part{i}]')
filters.append(''.join(f'[part{i}]' for i in range(8))+'amix=inputs=8:normalize=0:duration=longest,apad=whole_dur=30,atrim=0:30,loudnorm=I=-16:TP=-2:LRA=11,asplit=2[voice][duck]')
filters.append('[1:a]atrim=0:30,asetpts=PTS-STARTPTS,loudnorm=I=-19:TP=-3:LRA=9,volume=0.8,afade=t=in:st=0:d=0.35,afade=t=out:st=28.7:d=1.3[music]')
filters.append('[music][duck]sidechaincompress=threshold=0.018:ratio=5:attack=12:release=260[bed]')
filters.append('[voice][bed]amix=inputs=2:normalize=0:duration=longest,loudnorm=I=-16:TP=-1.5:LRA=11[audio]')
output=ROOT/f'G-Blox_Trailer_30s_{args.label}.mp4'
run(['-i',ROOT/'picture_edit.mp4','-i',MUSIC,'-i',VOICE,'-filter_complex',';'.join(filters),'-map','0:v:0','-map','[audio]','-t','30','-c:v','copy','-c:a','aac','-b:a','192k','-ar','48000','-movflags','+faststart',output],ROOT/f'voice_mix_{args.label}.log')
(ROOT/f'narration_timing_{args.label}.json').write_text(json.dumps({'pace':args.pace,'windows':WINDOWS},indent=2),encoding='utf-8')
print('DONE: '+str(output))
