import bpy,bmesh,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
audit=json.loads((ROOT/'Source'/'FBX-validation.json').read_text())
ids=[r['id']for r in audit if not r['pass']]
for p in ROOT.glob('*/Metadata/*.json'):
    r=json.loads(p.read_text())
    if r['id']not in ids:continue
    bpy.ops.wm.open_mainfile(filepath=r['blend'])
    dg=bpy.context.evaluated_depsgraph_get()
    for ob in bpy.context.scene.objects:
        if ob.type!='MESH'or ob.get('IsRobloxExport'):continue
        ev=ob.evaluated_get(dg);me=ev.to_mesh();me.calc_loop_triangles()
        bm=bmesh.new();bm.from_mesh(me)
        non=sum(not e.is_manifold for e in bm.edges)
        tiny=sum(t.area<1e-10 for t in me.loop_triangles)
        if non or tiny:print('PART_ISSUE',r['id'],ob.name,'nonmanifold',non,'tiny triangles',tiny,flush=True)
        bm.free();ev.to_mesh_clear()
