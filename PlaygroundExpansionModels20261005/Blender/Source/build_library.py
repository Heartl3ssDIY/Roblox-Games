import bpy,json,sys,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'Source'))
from assetlib import checked_enum
records=sorted([json.loads(p.read_text()) for p in ROOT.glob('*/Metadata/*.json')],key=lambda r:(r['category'],r['id']))
assert len(records)==35,f'Expected 35 completed models, found {len(records)}'
for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
for collection in list(bpy.data.collections):bpy.data.collections.remove(collection)
scene=bpy.context.scene;scene.name='Playground Classics - Expansion Library'
scene.render.filepath=str(ROOT/'Previews'/'Library.png')
scene.frame_start=1;scene.frame_end=25;scene.render.fps=24
groups={}
offset=0
for category in ('Bats','Miscellaneous','Pets'):
    group=bpy.data.collections.new(category);scene.collection.children.link(group);groups[category]=group
    subset=[r for r in records if r['category']==category]
    for i,record in enumerate(subset):
        with bpy.data.libraries.load(record['blend'],link=False) as (source,target):
            target.collections=[name for name in source.collections if name.startswith(record['id']+'_') and not name.endswith('_RobloxExport')]
        assert len(target.collections)==1,(record['id'],target.collections)
        collection=target.collections[0];group.children.link(collection)
        roots=[o for o in collection.objects if not o.parent and o.type=='EMPTY']
        assert len(roots)==1,(record['id'],[r.name for r in roots])
        roots[0].location=((i%5-2)*5.5,offset+(i//5)*5.5,0)
        roots[0]['IndividualSource']=record['blend']
    offset+=(math.ceil(len(subset)/5)+.6)*5.5
scene.frame_set(1)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.shading.type=checked_enum(space.shading,'type','MATERIAL')
            space.region_3d.view_location=(0,offset/2,1)
            space.region_3d.view_distance=offset*1.4
            space.region_3d.view_rotation=Vector((-.6,-1,1.5)).to_track_quat('Z','Y')
text=bpy.data.texts.new('START HERE')
text.write('35 editable expansion models. Collections are grouped into Bats, Miscellaneous and Pets. Each item also has its own Blend source and FBX export in the matching category folder. Pets have pose bones and a 25-frame JollyIdle loop. Source bevels and named parts stay editable. Packed original references are in each individual Blend file. Runtime collision and item abilities are not authored in this file. Use local source files listed in each root object custom property.\n')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Playground-Classics-Expansion-Library.blend'),compress=True,check_existing=False)
(ROOT/'Asset-Manifest.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
print('LIBRARY_COMPLETE',len(records),flush=True)
