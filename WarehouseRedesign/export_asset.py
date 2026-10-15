import bpy, json, os
from mathutils import Vector
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\WarehouseRedesign'
scene=bpy.data.scenes['To be rich - Warehouse']
bpy.context.window.scene=scene
roof_hidden=bpy.data.collections['Roof'].hide_viewport
bpy.data.collections['Roof'].hide_viewport=False
bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get()
for ob in list(scene.objects):
    if ob.type=='FONT' and ob.get('Export'):
        me=bpy.data.meshes.new_from_object(ob.evaluated_get(deps))
        name=ob.name
        replacement=bpy.data.objects.new(name+'_mesh',me)
        replacement.matrix_world=ob.matrix_world.copy()
        for k,v in ob.items():replacement[k]=v
        for collection in ob.users_collection:collection.objects.link(replacement)
        bpy.data.objects.remove(ob,do_unlink=True)
        replacement.name=name
        ob=replacement
    if ob.type=='MESH' and ob.get('Export'):
        center=sum((Vector(v) for v in ob.bound_box),Vector())/8
        if center.length>.00001:
            for v in ob.data.vertices: v.co-=center
            ob.location+=ob.matrix_world.to_3x3() @ center
        ob.data.update()
bpy.context.view_layer.update()
os.makedirs(os.path.join(OUT,'FBX_Parts'),exist_ok=True)
objects=[o for o in scene.objects if o.type=='MESH' and o.get('Export')]
for o in scene.objects: o.select_set(False)
for o in objects: o.select_set(True)
bpy.context.view_layer.objects.active=objects[0]

def export(path):
    bpy.ops.export_scene.fbx(filepath=path,use_selection=True,object_types={'MESH'},
        apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',global_scale=1,
        axis_forward='-Z',axis_up='Y',use_mesh_modifiers=True,mesh_smooth_type='FACE',
        use_custom_props=True,add_leaf_bones=False,bake_anim=False)

export(os.path.join(OUT,'To_be_rich_Warehouse.fbx'))
for collection in scene.collection.children:
    selected=[o for o in collection.objects if o in objects]
    if not selected: continue
    for ob in objects: ob.select_set(False)
    for ob in selected: ob.select_set(True)
    bpy.context.view_layer.objects.active=selected[0]
    export(os.path.join(OUT,'FBX_Parts',collection.name+'.fbx'))

def srgb(v): return 12.92*v if v<=.0031308 else 1.055*v**(1/2.4)-.055
material_map={'Wall':'SmoothPlastic','Roof':'Metal','OfficeWall':'SmoothPlastic','Pillar':'Metal','Trim':'Metal','Neon':'Neon','Concrete':'Concrete','Floor':'Concrete','Asphalt':'Asphalt','Rubber':'SmoothPlastic','Metal':'Metal','White':'SmoothPlastic','Glass':'Glass','Wood':'Wood','Cardboard':'Cardboard','Tape':'SmoothPlastic','Label':'SmoothPlastic','Red':'SmoothPlastic','Green':'SmoothPlastic','Screen':'SmoothPlastic','Fabric':'Fabric','Warm':'Neon'}
material_map.update({k:'SmoothPlastic' for k in ('Roof','Pillar','Trim','Metal','Wood','Cardboard','Fabric')})
manifest={'coordinate_map':'Roblox (x,y,z) = Blender (x,z,-y)','stud_scale':1,'legacy_plot_origin':[20.5,8.375,0], 'objects':[], 'triangles':0,'max_object_triangles':0,'groups':{}}
for ob in sorted(objects,key=lambda o:o.name):
    mat=ob.data.materials[0]
    color=[max(0,min(255,round(srgb(c)*255))) for c in mat.diffuse_color[:3]]
    evaluated=ob.evaluated_get(deps); me=evaluated.to_mesh();me.calc_loop_triangles();count=len(me.loop_triangles);evaluated.to_mesh_clear()
    group=ob.get('CustomGroup')
    manifest['triangles']+=count;manifest['max_object_triangles']=max(manifest['max_object_triangles'],count)
    if group:manifest['groups'][group]=manifest['groups'].get(group,0)+1
    manifest['objects'].append({'name':ob.name,'collection':ob.users_collection[0].name,'group':group,'color':color,'material':material_map.get(ob.get('Paint'),'SmoothPlastic'),'collide':bool(ob.get('CanCollide')),'triangles':count,'position':[round(ob.location.x,6),round(ob.location.z,6),round(-ob.location.y,6)],'size':[round(ob.dimensions.x,6),round(ob.dimensions.z,6),round(ob.dimensions.y,6)]})
with open(os.path.join(OUT,'parts_manifest.json'),'w',encoding='utf-8') as f: json.dump(manifest,f,indent=2)

rows=[]
for p in manifest['objects']:
    name=json.dumps(p['name']);g=json.dumps(p['group']) if p['group'] else 'false'
    r,gc,b=p['color'];rows.append(f'\t[{name}]={{{g},{r},{gc},{b},"{p["material"]}",{str(p["collide"]).lower()}}},')
luau='''local Selection=game:GetService("Selection")
local ChangeHistory=game:GetService("ChangeHistoryService")
local model=Selection:Get()[1]
assert(model and model:IsA("Model"), "Select the imported warehouse model first")
local parts={
'''+ '\n'.join(rows)+'''
}
local matches=0
for _,part in model:GetDescendants() do
 if part:IsA("MeshPart") and parts[part.Name] then matches+=1 end
end
assert(matches>0, "No warehouse part names matched; select the imported model")
ChangeHistory:SetWaypoint("Before warehouse colours")
for _,part in model:GetDescendants() do
 local p=parts[part.Name]
 if part:IsA("MeshPart") and p then
  part:SetAttribute("CustomGroup",p[1] or nil)
  part.Color=Color3.fromRGB(p[2],p[3],p[4])
  part.Material=Enum.Material[p[5]]
  part.Anchored=true
  part.CanCollide=p[6]
  part.Transparency=p[5]=="Glass" and .3 or 0
 end
end
ChangeHistory:SetWaypoint("Warehouse colours applied")
print("Applied warehouse settings to "..matches.." parts")
'''
with open(os.path.join(OUT,'ApplyColours.luau'),'w',encoding='utf-8') as f:f.write(luau)
for ob in objects:ob.select_set(False)
bpy.data.collections['Roof'].hide_viewport=roof_hidden
scene.camera=bpy.data.objects['Office Detail']
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active
   space.camera=scene.camera
   space.use_local_camera=True
   space.region_3d.view_perspective='CAMERA'
   space.region_3d.update()
   area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'To_be_rich_Warehouse.blend'))
print(json.dumps({'exported_meshes':len(objects),'triangles':manifest['triangles'],'largest_mesh':manifest['max_object_triangles'],'groups':manifest['groups']}))
