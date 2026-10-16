"""Run in Blender's Text Editor after editing an individual source .blend."""
import bpy,sys,json
from pathlib import Path
from types import SimpleNamespace
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'Source'))
from build_pack import export_meshes,bounds
from assetlib import checked_enum
roots=[o for o in bpy.context.scene.objects if o.type=='EMPTY'and o.get('id')and o.get('category')]
if len(roots)!=1:
    raise RuntimeError('Open one individual asset .blend before exporting. The overview library has multiple assets.')
root=roots[0]
spec={k:root.get(k,'')for k in('id','name','category','tier','brief','reference')}
spec['slug']=root.name
asset_collection=next(c for c in root.users_collection if c.name.startswith(spec['id']+'_'))
objects=[o for o in asset_collection.all_objects if o.type=='MESH'and not o.get('ConstructionTool')and not o.get('IsRobloxExport')]
anchors=[o for o in asset_collection.all_objects if o.get('Attachment')]
assert objects,'No editable source meshes found'
base=ROOT/spec['category']
old=bpy.data.collections.get(spec['id']+'_RobloxExport')
if old:
    for ob in list(old.objects):bpy.data.objects.remove(ob,do_unlink=True)
    bpy.data.collections.remove(old)
asset=SimpleNamespace(spec=spec,objects=objects,anchors=anchors)
texture=base/'Textures'/(spec['slug']+'-palette.png')
exports,collection,colors=export_meshes(asset,texture)
bpy.ops.object.select_all(action=checked_enum(bpy.ops.object.select_all.get_rna_type(),'action','DESELECT'))
for ob in exports+anchors:ob.select_set(True)
bpy.context.view_layer.objects.active=exports[0]
fbx=base/'FBX'/(spec['slug']+'.fbx')
bpy.ops.export_scene.fbx(filepath=str(fbx),use_selection=True,object_types={'MESH','EMPTY'},use_mesh_modifiers=True,bake_anim=False,add_leaf_bones=False,axis_forward='-Z',axis_up='Y',apply_unit_scale=False,global_scale=1.0,mesh_smooth_type='FACE',use_triangles=True,path_mode='COPY',embed_textures=True,use_custom_props=True)
collection.hide_render=True;collection.hide_viewport=True
bpy.ops.object.select_all(action=checked_enum(bpy.ops.object.select_all.get_rna_type(),'action','DESELECT'))
root.select_set(True);bpy.context.view_layer.objects.active=root
blend=base/'Blend'/(spec['slug']+'.blend')
bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True,check_existing=False)
meta=base/'Metadata'/(spec['slug']+'.json')
record=json.loads(meta.read_text())if meta.exists()else{}
lo,hi=bounds(objects)
export_lo,export_hi=bounds(exports)
record.update(parts=len(objects),triangles=sum(len(o.data.polygons)for o in exports),meshes=len(exports),maxMeshTriangles=max(len(o.data.polygons)for o in exports),dimensions=list(hi-lo),boundsMin=list(lo),boundsMax=list(hi),exportDimensions=list(export_hi-export_lo),paletteColors=colors,exportedFromEditableSource=True)
meta.write_text(json.dumps(record,indent=2))
print('Updated FBX and saved editable source:',fbx)
