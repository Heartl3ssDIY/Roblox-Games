import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'Source'))
from build_pack import bounds
targets=sys.argv[sys.argv.index('--')+1:]if'--'in sys.argv else['B01','P01','C01','D01','M09','E02']
out=ROOT/'Previews'/'Other-Views';out.mkdir(parents=True,exist_ok=True)
for p in ROOT.glob('*/Metadata/*.json'):
    r=json.loads(p.read_text())
    if r['id']not in targets:continue
    bpy.ops.wm.open_mainfile(filepath=r['blend'])
    scene=bpy.context.scene;camera=scene.camera
    scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
    center=(Vector(r['boundsMin'])+Vector(r['boundsMax']))/2
    for name,direction in [('back',Vector((4.5,8,3.0))),('side',Vector((9,-.3,2.5)))]:
        camera.location=center+direction.normalized()*15
        camera.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
        camera.data.ortho_scale=max(r['dimensions'])*1.3
        scene.render.filepath=str(out/(r['id']+'-'+name+'.png'))
        bpy.ops.render.render(write_still=True)
    print('VIEWS_COMPLETE',r['id'],flush=True)
