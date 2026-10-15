import bpy, os, json, math
from mathutils import Vector, Matrix
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\LaptopModels'
models=bpy.app.driver_namespace['laptop_models']
scene=bpy.data.scenes['To be rich - Laptops']
bpy.context.window.scene=scene
manifest={'models':[],'existing_slot_scales':{'Laptop1':1,'Laptop2':1.4,'Laptop3':.5}}
for m in models:
    root=bpy.data.objects.get(m['brand']+'_Laptop')
    if root is None:
        root=bpy.data.objects.new(m['brand']+'_Laptop',None)
        m['objects'][0].users_collection[0].objects.link(root)
    root.location=(m['offset'],0,0)
    root['RobloxSlot']=m['tier'];root['ExistingScaleFactor']=m['factor']
    bpy.context.view_layer.update()
    for ob in m['objects']:
        ob.parent=root;ob.matrix_parent_inverse=root.matrix_world.inverted()
    bpy.context.view_layer.update()
    for ob in scene.objects:ob.select_set(False)
    temp=bpy.data.collections.new('LaptopExportTemporary');scene.collection.children.link(temp)
    entries=[];total=0;copies=[]
    for ob in m['objects']:
        me=ob.data.copy()
        # Roblox's FBX import applies a half-turn relative to Blender's Y axis.
        rotation=Matrix.Rotation(math.pi,4,'Z')
        for v in me.vertices:
            v.co=(rotation@(ob.matrix_world@v.co-Vector((m['offset'],0,0))))/m['factor']
        center=sum((v.co for v in me.vertices),Vector())/len(me.vertices)
        for v in me.vertices:v.co-=center
        copy=bpy.data.objects.new(ob.name+'_export',me);temp.objects.link(copy);copy.location=center
        copy['LaptopPart']=ob['LaptopPart'];copy.select_set(True);copies.append((copy,ob.name))
        # Swap names during export so Roblox receives stable, unambiguous names.
        ob.name=ob.name+'_authoring';copy.name=copies[-1][1]
        me.calc_loop_triangles();total+=len(me.loop_triangles)
        entries.append({'name':copy.name,'rgb':list(ob['RGB']),'triangles':len(me.loop_triangles)})
    bpy.context.view_layer.objects.active=copies[0][0]
    bpy.context.view_layer.update()
    path=os.path.join(OUT,m['tier']+'_'+m['brand']+'.fbx')
    bpy.ops.export_scene.fbx(filepath=path,use_selection=True,object_types={'MESH'},apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_UNITS',global_scale=1,axis_forward='-Z',axis_up='Y',
        use_mesh_modifiers=True,mesh_smooth_type='FACE',use_custom_props=False,add_leaf_bones=False,bake_anim=False)
    for copy,name in copies:
        me=copy.data;bpy.data.objects.remove(copy,do_unlink=True);bpy.data.meshes.remove(me)
        bpy.data.objects[name+'_authoring'].name=name
    bpy.data.collections.remove(temp)
    manifest['models'].append({'brand':m['brand'],'slot':m['tier'],'file':os.path.basename(path),'parts':entries,
        'triangles':total,'runtime_width':m['width'],'export_width':m['width']/m['factor'],'slot_scale':m['factor']})
with open(os.path.join(OUT,'laptop_manifest.json'),'w') as f:json.dump(manifest,f,indent=2)
rows=[]
for m in manifest['models']:
    for p in m['parts']:rows.append(' ["'+p['name']+'"]={'+','.join(map(str,p['rgb']))+'},')
script='''local selection=game:GetService("Selection"):Get()
local colours={
'''+ '\n'.join(rows)+'''
}
local parts={}
for _,model in selection do
 for _,part in model:GetDescendants() do
  if part:IsA("MeshPart") and colours[part.Name] then parts[part]=colours[part.Name] end
 end
end
assert(next(parts),"Select an imported Dell, HP or MacBook model")
game:GetService("ChangeHistoryService"):SetWaypoint("Before laptop colours")
local count=0
for part,rgb in parts do
 part.Color=Color3.fromRGB(table.unpack(rgb))
 part.Material=Enum.Material.SmoothPlastic
 part.Reflectance=0
 part.TextureID=""
 part.Anchored=true
 part.CanCollide=false
 part.CanQuery=false
 count+=1
end
game:GetService("ChangeHistoryService"):SetWaypoint("Laptop colours applied")
print("Recoloured "..count.." laptop parts")
'''
with open(os.path.join(OUT,'ApplyLaptopColours.luau'),'w') as f:f.write(script)
cam=scene.camera
cam.location=(6.2,-14,10);cam.rotation_euler=(Vector((0,.16,.7))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.ortho_scale=12.7
for ob in scene.objects:ob.select_set(False)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            sp=area.spaces.active;sp.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            sp.region_3d.view_location=(0,.16,.7);sp.region_3d.view_distance=13
            area.tag_redraw()
scene.render.filepath=os.path.join(OUT,'Laptop_Lineup.png')
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print(json.dumps({'saved':bpy.data.filepath,'exports':[{k:v for k,v in m.items() if k!='parts'} for m in manifest['models']]}))
