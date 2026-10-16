import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'Source'))
from assetlib import checked_enum,material
bpy.ops.wm.read_factory_settings(use_empty=True)
records=sorted([json.loads(p.read_text())for p in ROOT.glob('*/Metadata/*.json')],key=lambda r:r['id'])
for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
for c in list(bpy.data.collections):bpy.data.collections.remove(c)
start_scene=bpy.context.scene
audits=[]
categories=['Bats','Event-Bats','Pets','Miscellaneous','Event-Decorations']
for ci,category in enumerate(categories):
    scene=start_scene if ci==0 else bpy.data.scenes.new(category)
    scene.name=category
    models=bpy.data.collections.new(category+' editable models');scene.collection.children.link(models)
    labels=bpy.data.collections.new('Library labels - not exported');scene.collection.children.link(labels)
    entries=[r for r in records if r['category']==category]
    for i,r in enumerate(entries):
        collection_name=r['id']+'_'+r['name'].replace(' ','_')
        with bpy.data.libraries.load(r['blend'],link=False)as(source,dest):
            assert collection_name in source.collections,collection_name
            dest.collections=[collection_name]
        collection=dest.collections[0];models.children.link(collection)
        root=next(o for o in collection.objects if o.type=='EMPTY'and o.get('id')==r['id'])
        x=(i%4)*4.3;y=(i//4)*4.5
        root.location=Vector((x,y,-r['boundsMin'][2]+.06))
        for o in collection.objects:
            if o.get('ConstructionTool'):o.hide_render=True
        data=bpy.data.curves.new(r['id']+' caption','FONT');data.body=r['id']+'  '+r['name'];data.size=.19
        data.align_x=checked_enum(data,'align_x','CENTER');data.extrude=0
        data.materials.append(material('navy'))
        label=bpy.data.objects.new(data.name,data);labels.objects.link(label);label.location=(x,y-1.75,.025)
        label.rotation_euler=(0,0,0)
        audits.append({'id':r['id'],'collection':collection.name,'sourceMeshes':sum(o.type=='MESH'and not o.get('ConstructionTool')for o in collection.objects),'sourceFile':r['blend']})
    scene['LibraryInstructions']='Each named collection is one editable asset. Individual Blend files include the packed reference and export mesh. Models in this overview are arranged for browsing only.'
    camdata=bpy.data.cameras.new(category+' overview');camdata.type=checked_enum(camdata,'type','ORTHO')
    camera=bpy.data.objects.new(camdata.name,camdata);scene.collection.objects.link(camera)
    rows=math.ceil(len(entries)/4);center=Vector((6.45,(rows-1)*2.25,1))
    direction=Vector((.6,-1,1.45)).normalized();camera.location=center+direction*35
    camera.rotation_euler=direction.to_track_quat('Z','Y').to_euler();camdata.ortho_scale=max(20,rows*5.0)
    scene.camera=camera
    try:scene.render.engine='BLENDER_EEVEE'
    except TypeError:pass
    scene.render.resolution_x=1600;scene.render.resolution_y=1000
    scene.view_settings.view_transform='Standard';scene.view_settings.exposure=-.2
shared_materials={}
for mat in list(bpy.data.materials):
    if 'palette_srgb' not in mat:continue
    shader=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
    if not shader:continue
    key=(tuple(mat['palette_srgb']),round(shader.inputs['Roughness'].default_value,4),round(shader.inputs['Metallic'].default_value,4),round(shader.inputs['Coat Weight'].default_value,4))
    if key in shared_materials:mat.user_remap(shared_materials[key])
    else:shared_materials[key]=mat
bpy.context.window.scene=bpy.data.scenes['Miscellaneous']
for scene in bpy.data.scenes:
    for layer in scene.view_layers:
        for ob in scene.objects:
            if ob.get('ConstructionTool'):ob.hide_set(True,view_layer=layer)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type=checked_enum(area.spaces.active.shading,'type','MATERIAL')
            area.spaces.active.overlay.show_extras=False
            area.spaces.active.region_3d.view_location=(6.45,6.75,1)
            area.spaces.active.region_3d.view_rotation=Vector((.6,-1,1.45)).to_track_quat('Z','Y')
            area.spaces.active.region_3d.view_distance=24
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Playground-Classics-Model-Library.blend'),compress=True,check_existing=False)
(ROOT/'Source'/'Library-validation.json').write_text(json.dumps(audits,indent=2))
print('LIBRARY_COMPLETE',len(audits),flush=True)
