import bpy,json,os,math,struct
from mathutils import Vector
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TownCentreModels'
with open(os.path.join(OUT,'town_manifest.json')) as f:models=json.load(f)
report=[];signatures={}
for m in models:
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=os.path.join(OUT,m['name']+'.fbx'))
    objects={ob.name:ob for ob in bpy.context.scene.objects if ob.type=='MESH'}
    assert set(objects)=={p['name'] for p in m['parts']},m['name']+' mesh names differ'
    sig={}
    for p in m['parts']:
        ob=objects[p['name']];coords=[ob.matrix_world@vert.co for vert in ob.data.vertices]
        assert all(math.isfinite(x) for v in coords for x in v)
        assert ob.data.materials
        lo=Vector([min(v[i] for v in coords) for i in range(3)]);hi=Vector([max(v[i] for v in coords) for i in range(3)])
        target=Vector((-p['center'][0],p['center'][2],p['center'][1]));size=Vector((p['size'][0],p['size'][2],p['size'][1]))
        assert ((lo+hi)/2-target).length<.003,(p['name'],'centre')
        assert (hi-lo-size).length<.003,(p['name'],'dimensions')
        assert sum(len(poly.vertices)-2 for poly in ob.data.polygons)<8000
        sig[p['part']]=sorted(tuple(round(x,4) for x in v) for v in coords)
    if m['kind']=='building':signatures[m['name']]=sig
    with open(os.path.join(OUT,m['name']+'.glb'),'rb') as f:
        f.read(12);n,kind=struct.unpack('<II',f.read(8));gltf=json.loads(f.read(n))
    assert {n['name'] for n in gltf['nodes'] if 'mesh' in n}==set(objects),'Unexpected GLB content'
    report.append({'name':m['name'],'meshParts':len(objects),'triangles':m['triangles'],'exports':'passed'})
common=set(signatures['TownCentre_Normal'])&set(signatures['TownCentre_Crashed'])
for name in common:assert signatures['TownCentre_Normal'][name]==signatures['TownCentre_Crashed'][name],name+' differs between variants'
routes=[(0,23-i*.5) for i in range(65)]+[(-i*.5,-9) for i in range(11)]+[(i*.5,-9) for i in range(11)]
for m in models:
    if m['kind']!='building':continue
    for x,z in routes:
        floor=.8 if z<=16.1 else max(0,.8*(22.1-z)/6)
        low=[x-1.1,floor+.08,z-1.1];high=[x+1.1,floor+5.7,z+1.1]
        for p in m['parts']:
            if not p['solid'] or p['group'] in ['Floor','Ground'] or p['part']=='Foundation':continue
            pl=[p['center'][i]-p['size'][i]/2 for i in range(3)];ph=[p['center'][i]+p['size'][i]/2 for i in range(3)]
            assert not all(low[i]<ph[i]-.01 and high[i]>pl[i]+.01 for i in range(3)),(m['name'],p['name'],x,z)
result={'assets':report,'matching_parts_between_buildings':len(common),'clear_route_samples_per_building':len(routes),'no_gameplay_scripts_executed':True}
with open(os.path.join(OUT,'validation.json'),'w') as f:json.dump(result,f,indent=2)
print(json.dumps(result))
