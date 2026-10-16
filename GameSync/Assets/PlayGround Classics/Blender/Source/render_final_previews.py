import bpy,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
args=sys.argv[sys.argv.index('--')+1:]if'--'in sys.argv else[]
for p in sorted(ROOT.glob('*/Metadata/*.json')):
    r=json.loads(p.read_text())
    if args and r['id']not in args:continue
    bpy.ops.wm.open_mainfile(filepath=r['blend'])
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
    scene.render.resolution_x=768;scene.render.resolution_y=768
    scene.render.filepath=r['preview']
    bpy.ops.render.render(write_still=True)
    print('CLEAN_PREVIEW_COMPLETE',r['id'],flush=True)
