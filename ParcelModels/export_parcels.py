import bpy,math,json,os
from mathutils import Matrix,Vector
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ParcelModels'
scene=bpy.data.scenes['To be rich - Parcels'];bpy.context.window.scene=scene
manifest={'models':[]}
for m in bpy.app.driver_namespace['parcel_models']:
    root=bpy.data.objects.get('Parcel_'+m['name'])
    if root is None:
        root=bpy.data.objects.new('Parcel_'+m['name'],None);m['objects'][0].users_collection[0].objects.link(root)
    root.location=(m['offset'],m['yoffset'],0);bpy.context.view_layer.update()
    for ob in m['objects']:ob.parent=root;ob.matrix_parent_inverse=root.matrix_world.inverted()
    bpy.context.view_layer.update()
    for ob in scene.objects:ob.select_set(False)
    temp=bpy.data.collections.new('ParcelExportTemporary');scene.collection.children.link(temp)
    entries=[];copies=[];total=0
    for ob in m['objects']:
        if not ob.get('Export'):continue
        me=ob.data.copy()
        for v in me.vertices:v.co=Matrix.Rotation(math.pi,4,'Z')@(ob.matrix_world@v.co-Vector((m['offset'],m['yoffset'],0)))
        center=sum((v.co for v in me.vertices),Vector())/len(me.vertices)
        for v in me.vertices:v.co-=center
        original=ob.name;ob.name+='_authoring'
        copy=bpy.data.objects.new(original,me);temp.objects.link(copy);copy.location=center;copy.select_set(True);copies.append((copy,original))
        me.calc_loop_triangles();total+=len(me.loop_triangles)
        part=ob['ParcelPart'];material='SmoothPlastic'
        if part=='GlowBorder':material='Neon'
        elif m['name'] in ('Gold','Rainbow') and part in ('Body','TopFlaps'):material='Metal'
        entries.append({'name':original,'part':part,'rgb':list(ob['RGB']),'material':material,'triangles':len(me.loop_triangles),
            'texture':'Textures/'+ob['TextureFile'] if ob.get('TextureFile') else None,'normal':'Textures/'+ob['NormalFile'] if ob.get('NormalFile') else None})
    bpy.context.view_layer.objects.active=copies[0][0];bpy.context.view_layer.update()
    path=os.path.join(OUT,'Parcel_'+m['name']+'.fbx')
    bpy.ops.export_scene.fbx(filepath=path,use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',
        apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',global_scale=1,use_custom_props=False,
        mesh_smooth_type='FACE',add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True)
    for copy,name in copies:
        me=copy.data;bpy.data.objects.remove(copy,do_unlink=True);bpy.data.meshes.remove(me);bpy.data.objects[name+'_authoring'].name=name
    bpy.data.collections.remove(temp)
    manifest['models'].append({'name':m['name'],'file':os.path.basename(path),'dimensions_xyz_blender':m['dim'],
        'triangles':total,'parts':entries,'rarity':'Gold' if m['name']=='Gold' else ('Rainbow' if m['name']=='Rainbow' else 'Regular'),'fragile':m['name']=='Fragile'})
with open(os.path.join(OUT,'parcel_manifest.json'),'w') as f:json.dump(manifest,f,indent=2)
rows=[]
for m in manifest['models']:
    for p in m['parts']:rows.append(' ["'+p['name']+'"]={'+','.join(map(str,p['rgb']))+',"'+p['material']+'","'+p['part']+'",'+str(bool(p['texture'])).lower()+'},')
setup='''local selected=game:GetService("Selection"):Get()
local settings={
'''+ '\n'.join(rows)+'''
}
for _,model in selected do
 if not model:IsA("Model") then continue end
 local body
 for _,p in model:GetDescendants() do
  local s=settings[p.Name]
  if p:IsA("MeshPart") and s and s[5]=="Body" then body=p break end
 end
 if not body then continue end
 game:GetService("ChangeHistoryService"):SetWaypoint("Before parcel setup")
 model.PrimaryPart=body
 for _,p in model:GetDescendants() do
  local s=settings[p.Name]
  if not (p:IsA("MeshPart") and s) then continue end
  local textured=s[6] and (p.TextureID~="" or p:FindFirstChildOfClass("SurfaceAppearance"))
  p.Color=textured and Color3.new(1,1,1) or Color3.fromRGB(s[1],s[2],s[3]);p.Material=Enum.Material[s[4]]
  p.Reflectance=s[4]=="Metal" and 0.035 or 0
  if not s[6] then p.TextureID="" end
  p.CanCollide=p==body;p.CanQuery=p==body;p.CanTouch=p==body
  p.Massless=p~=body;p.Anchored=p==body
  if p==body then
   p.CollisionFidelity=Enum.CollisionFidelity.Box
   p.CustomPhysicalProperties=PhysicalProperties.new(0.55,0.65,0.12,100,100)
  else
   local motor=p:FindFirstChild("ParcelJoint") or Instance.new("Motor6D")
   motor.Name="ParcelJoint";motor.Part0=body;motor.Part1=p
   motor.C0=body.CFrame:ToObjectSpace(p.CFrame);motor.Parent=p
  end
 end
 model:SetAttribute("PhysicsReady",true)
 game:GetService("ChangeHistoryService"):SetWaypoint("Parcel setup complete")
end
print("Parcel assemblies prepared. Unanchor the Body when releasing a box into physics.")
'''
with open(os.path.join(OUT,'ApplyParcelSettings.luau'),'w') as f:f.write(setup)
for ob in scene.objects:ob.select_set(False)
scene.render.filepath=os.path.join(OUT,'Parcel_Lineup.png')
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print(json.dumps([{k:v for k,v in m.items() if k!='parts'}|{'parts':len(m['parts'])} for m in manifest['models']]))
