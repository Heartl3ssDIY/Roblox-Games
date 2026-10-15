exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TenkaichiArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
scene=bpy.context.scene
bpy.data.objects['Camera_Hero'].data.lens=40
bpy.data.objects['Camera_Hero'].data.shift_y=-.065
bg=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.30,.57,.9,1);bg.inputs['Strength'].default_value=.65
sun=bpy.data.lights['Afternoon sun'];sun.color=(1,.96,.88);sun.energy=3.1
ld=bpy.data.lights.get('Soft frontal daylight') or bpy.data.lights.new('Soft frontal daylight','AREA');ld.energy=23000;ld.shape='DISK';ld.size=85;ld.color=(.86,.94,1)
lo=bpy.data.objects.get('Soft frontal daylight')
if lo is None:
 lo=bpy.data.objects.new('Soft frontal daylight',ld);collection('90_Presentation').objects.link(lo)
lo.location=(-15,-42,75);lo.rotation_euler=(Vector((0,25,8))-lo.location).to_track_quat('-Z','Y').to_euler()
# Keep broad plaster and paving surfaces quiet; reserve strong relief for thatch and wood.
im=bpy.data.images['Arena_NormalAtlas'];arr=np.array(im.pixels[:],dtype=np.float32).reshape((2048,2048,4));rng=np.random.default_rng(5)
for k in range(16):
 if k in [2,6]:continue
 ys=slice((k//4)*512,(k//4+1)*512);xs=slice((k%4)*512,(k%4+1)*512)
 arr[ys,xs,0]=.5+rng.normal(0,.0015,(512,512));arr[ys,xs,1]=.5+rng.normal(0,.0015,(512,512));arr[ys,xs,2]=1
im.pixels.foreach_set(arr.ravel());im.filepath_raw=os.path.join(ROOT,'textures','Arena_NormalAtlas.png');im.file_format='PNG';im.save();im.pack()
visuals=[o for o in scene.objects if o.type=='MESH' and o.get('export_role')=='visual']
sign=bpy.data.objects['06_Sign_Part01'];bm=bmesh.new();bm.from_mesh(sign.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.000001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(sign.data);bm.free()
bpy.ops.object.select_all(action='DESELECT')
for ob in visuals:ob.select_set(True)
bpy.context.view_layer.objects.active=visuals[0]
bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT,'exports','Tenkaichi_Arena_Roblox.fbx'),use_selection=True,object_types={'MESH'},apply_scale_options='FBX_SCALE_UNITS',global_scale=1,axis_forward='Z',axis_up='Y',use_mesh_modifiers=True,mesh_smooth_type='FACE',add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True)
bpy.ops.object.select_all(action='DESELECT')
scene.camera=bpy.data.objects['Camera_Hero'];scene.render.filepath=os.path.join(ROOT,'previews','Arena_Hero.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Tenkaichi_Arena.blend'))
print('FINAL_SCENE_SAVED')
