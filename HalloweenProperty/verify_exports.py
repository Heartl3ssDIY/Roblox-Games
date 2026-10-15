import bpy,json,struct,math
from pathlib import Path
from mathutils import Vector

out=Path(__file__).resolve().parent
expected=json.loads((out/'Model_Report.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(out/'Halloween_Property.blend'))
root=bpy.data.collections['HALLOWEEN PROPERTY - editable exterior']
source=[o for o in root.all_objects if o.type=='MESH']
def stats(objects):
    vv=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
    return {'meshes':len(objects),'triangles':sum(len(o.data.polygons) for o in objects),'bounds':[round(max(v[i] for v in vv)-min(v[i] for v in vv),5) for i in range(3)]}
before=stats(source)
packed=[i.name for i in bpy.data.images if i.packed_file]
assert len(packed)==3,packed
assert before['meshes']==expected['meshCount']
assert before['triangles']==expected['triangles']
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(out/'Halloween_Property.fbx'),use_anim=False)
imported=[o for o in bpy.data.objects if o.type=='MESH']
after=stats(imported)
assert after['meshes']==before['meshes'],(before,after)
assert after['triangles']==before['triangles'],(before,after)
assert all(abs(a-b)<.001 for a,b in zip(before['bounds'],after['bounds'])),(before,after)
textures=[{'name':i.name,'size':list(i.size),'loaded':i.has_data} for i in bpy.data.images]
assert len(textures)>=3,textures
assert all(i['loaded'] and i['size']==[2048,2048] for i in textures),textures
blob=(out/'Halloween_Property.glb').read_bytes()
magic,version,length=struct.unpack_from('<4sII',blob)
assert magic==b'glTF' and version==2 and length==len(blob)
chunklen,kind=struct.unpack_from('<I4s',blob,12)
gltf=json.loads(blob[20:20+chunklen])
assert len(gltf['meshes'])==before['meshes']
report={'blend':before,'packedTextures':packed,'FBX_roundtrip':after,'FBX_textures':textures,'GLB_meshes':len(gltf['meshes']),'studioImport':'Not tested: no connected Roblox Studio instance.'}
(out/'Export_Check.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('EXPORT_VERIFIED '+json.dumps(report),flush=True)
