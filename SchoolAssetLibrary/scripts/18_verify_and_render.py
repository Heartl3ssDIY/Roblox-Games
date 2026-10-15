import bpy,os,json,struct,math
from mathutils import Vector
BASE=os.path.dirname(os.path.dirname(os.path.abspath(__file__)));OUT=os.path.join(BASE,'RobloxImport')
records=[json.load(open(os.path.join(OUT,'SA%02d_metadata.json'%i),encoding='utf-8')) for i in range(1,39)]
report={'assets':len(records),'bodies':sum(len(r['bodies']) for r in records),'pickup_bodies':sum(b['kind']=='pickup' for r in records for b in r['bodies']),'hinges':sum(b['kind']=='hinge' for r in records for b in r['bodies']),'meshes':0,'triangles':0,'max_triangles_per_mesh':0,'textures':set(),'errors':[]}
for r in records:
    d=json.load(open(os.path.join(OUT,r['file'])));bb=open(os.path.join(OUT,d['buffers'][0]['uri']),'rb').read();assert len(bb)==d['buffers'][0]['byteLength']
    names=[n['name'] for n in d['nodes']];assert len(names)==len(set(names))
    for b in r['bodies']:assert any(n.startswith(b['id']+'_M') for n in names),b['id']
    for m in d['meshes']:
        assert len(m['primitives'])==1
        p=m['primitives'][0];tri=d['accessors'][p['indices']]['count']//3
        assert tri<=18000,(r['id'],tri);report['max_triangles_per_mesh']=max(report['max_triangles_per_mesh'],tri)
        if '_REF_' not in m['name']:report['meshes']+=1;report['triangles']+=tri
        uv=d['accessors'][p['attributes']['TEXCOORD_0']];view=d['bufferViews'][uv['bufferView']]
        vals=struct.unpack_from('<'+'f'*(uv['count']*2),bb,view.get('byteOffset',0));assert all(math.isfinite(x) and -.00001<=x<=1.00001 for x in vals)
    for im in d['images']:assert os.path.isfile(os.path.join(OUT,im['uri']));report['textures'].add(im['uri'])
report['textures']=len(report['textures']);open(os.path.join(OUT,'manifest.json'),'w',encoding='utf-8').write(json.dumps(records,indent=2))
print('STRUCTURE VERIFIED',report,flush=True)
scene=next(s for s in bpy.data.scenes if s.name.startswith('School Asset Library'));bpy.context.window.scene=scene
assets=json.load(open(os.path.join(BASE,'asset-manifest.json'),encoding='utf-8'))
for a in assets:
    for o in list(bpy.data.collections[a['collection']].all_objects):o.hide_render=True
groups=[('stationery',[9,10,11,12,13],(.66,-.04,.83),1.68,(1300,900),'02-stationery'),('boards',[29,30],(1.65,16,1.2),6.1,(1500,900),'07-boards'),('staff-seating',[6,7,8],(10,4,.6),5.3,(1500,950),'10-staff-seating')]
imported=[]
for title,ids,target,scale,res,camname in groups:
    for o in imported:o.hide_render=True
    for ai in ids:
        before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=os.path.join(OUT,records[ai-1]['file']))
        new=set(bpy.data.objects)-before;tr=bpy.data.objects[assets[ai-1]['root']].matrix_world.copy()
        for o in new:
            if o.parent is None:o.matrix_world=tr@o.matrix_world
            if '_REF_' in o.name:o.hide_render=True
        imported.extend(new)
    for o in list(scene.objects):
        if 'pedestal' in o.name.lower():o.hide_render=not ('Stationery' in o.name and title=='stationery')
    target=Vector(target);distance=max(scale*.60,1)
    for lname,offset,power in [('Key | large softbox',(-.45,-.8,1.2),170),('Fill | cool softbox',(1,.2,.9),100),('Rim | daylight',(-.3,1,1.1),190)]:
        light=bpy.data.objects[lname];light.location=target+Vector(offset)*distance;light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler();light.data.energy=power*distance**2;light.data.size=distance*.85
    scene.camera=bpy.data.objects['CAM | '+camname];scene.render.resolution_x=res[0];scene.render.resolution_y=res[1];scene.render.resolution_percentage=100;scene.render.filepath=os.path.join(BASE,'renders','portable-'+title+'.png')
    bpy.ops.render.render(write_still=True)
    print('ROUNDTRIP RENDER',title,flush=True)
report['roundtrip_rendered']=[g[0] for g in groups];report['roblox_studio_play_tested']=False
open(os.path.join(OUT,'verification.json'),'w').write(json.dumps(report,indent=2))
