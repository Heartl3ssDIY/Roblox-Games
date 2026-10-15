import bpy,bmesh,math,json,os
from mathutils import Matrix,Vector
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\GiftParcelModels'
scene=bpy.data.scenes['To be rich - Gift Parcels'];bpy.context.window.scene=scene
manifest={'models':[],'units':'Roblox studs at import scale 1','eventIntegration':'Import first; reward and carry integration remains in Studio.'}
for m in bpy.app.driver_namespace['gift_models']:
    col=m['objects'][0].users_collection[0]
    root=bpy.data.objects.new(m['model'],None);col.objects.link(root);root.location=m['offset'];bpy.context.view_layer.update()
    for ob in m['objects']:
        ob.parent=root;ob.matrix_parent_inverse=root.matrix_world.inverted()
    bpy.context.view_layer.update()
    for ob in scene.objects:ob.select_set(False)
    temp=bpy.data.collections.new('GiftExportTemporary');scene.collection.children.link(temp)
    entries=[];copies=[];bounds=[]
    try:
        for ob in m['objects']:
            me=ob.data.copy()
            for v in me.vertices:v.co=Matrix.Rotation(math.pi,4,'Z')@(ob.matrix_world@v.co-Vector(m['offset']))
            bounds.extend([v.co.copy() for v in me.vertices])
            center=sum((v.co for v in me.vertices),Vector())/len(me.vertices)
            for v in me.vertices:v.co-=center
            bm=bmesh.new();bm.from_mesh(me)
            assert all(e.is_manifold for e in bm.edges),ob.name+' has open edges'
            bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
            me.calc_loop_triangles()
            assert all(t.area>1e-10 for t in me.loop_triangles),ob.name+' has degenerate triangles'
            original=ob.name;ob.name=original+'_authoring'
            copy=bpy.data.objects.new(original,me);temp.objects.link(copy);copy.location=center;copy.select_set(True);copies.append((copy,ob,original))
            entries.append({'name':original,'part':ob['GiftPart'],'rgb':list(ob['RGB']),'material':'SmoothPlastic','triangles':len(me.loop_triangles)})
        bpy.context.view_layer.objects.active=copies[0][0];bpy.context.view_layer.update()
        path=os.path.join(OUT,m['model']+'.fbx')
        bpy.ops.export_scene.fbx(filepath=path,use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',global_scale=1,use_custom_props=False,mesh_smooth_type='FACE',add_leaf_bones=False,bake_anim=False,path_mode='AUTO')
    finally:
        for copy,original,name in copies:
            me=copy.data;bpy.data.objects.remove(copy,do_unlink=True);bpy.data.meshes.remove(me);original.name=name
        bpy.data.collections.remove(temp)
    lo=[min(v[i] for v in bounds) for i in range(3)];hi=[max(v[i] for v in bounds) for i in range(3)]
    assert abs(lo[2])<.001
    manifest['models'].append({'name':m['name'],'model':m['model'],'file':os.path.basename(path),'bodySizeRoblox':m['size'],'boundsRoblox':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],'triangles':sum(p['triangles'] for p in entries),'parts':entries})
with open(os.path.join(OUT,'gift_manifest.json'),'w') as f:json.dump(manifest,f,indent=2)
for ob in scene.objects:ob.select_set(False)
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print(json.dumps([{k:v for k,v in m.items() if k!='parts'}|{'parts':len(m['parts'])} for m in manifest['models']]))
