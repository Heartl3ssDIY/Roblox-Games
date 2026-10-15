import bpy, os, json, math, bmesh
from mathutils import Vector
OUT=os.path.dirname(bpy.data.filepath)
scene=bpy.context.scene
root=bpy.data.collections['CAT IN THE HAT - editable base']
models=[o for o in root.all_objects if o.type=='MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in models:o.select_set(True)
bpy.context.view_layer.objects.active=models[0]
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
scene.cursor.location=(0,0,0)
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

# One non-overlapping normal atlas; all visible colours remain solid and editable.
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.004,area_weight=.1)
bpy.ops.object.mode_set(mode='OBJECT')
normal=bpy.data.images.new('Cat_SurfaceNormal',width=2048,height=2048,alpha=False)
normal.colorspace_settings.name='Non-Color'
mats=set(m for o in models for m in o.data.materials)
for mat in mats:
    nt=mat.node_tree
    node=nt.nodes.new('ShaderNodeTexImage');node.name='Cat normal atlas';node.image=normal
    nt.nodes.active=node
    for n in nt.nodes:n.select=(n==node)
scene.render.engine='CYCLES';scene.cycles.samples=4
scene.render.bake.margin=8
scene.render.bake.use_clear=True
bpy.ops.object.bake(type='NORMAL')
normal.filepath_raw=os.path.join(OUT,'Cat_SurfaceNormal.png');normal.file_format='PNG';normal.save()
for mat in mats:
    nt=mat.node_tree
    p=nt.nodes.get('Principled BSDF');node=nt.nodes.get('Cat normal atlas')
    for link in list(p.inputs['Normal'].links):nt.links.remove(link)
    norm=nt.nodes.new('ShaderNodeNormalMap');norm.name='Exported surface detail'
    nt.links.new(node.outputs['Color'],norm.inputs['Color']);nt.links.new(norm.outputs['Normal'],p.inputs['Normal'])
normal.pack()

# Freeze a clean triangulated export topology after UVs and bake.
report=[]
def linear_to_srgb(c):return c*12.92 if c<=.0031308 else 1.055*c**(1/2.4)-.055
for o in models:
    bpy.context.view_layer.objects.active=o
    m=o.modifiers.new('Export triangles','TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=m.name)
    bm=bmesh.new();bm.from_mesh(o.data)
    nonmanifold=sum(not e.is_manifold for e in bm.edges)
    degenerate=sum(f.calc_area()<1e-10 for f in bm.faces)
    bm.free()
    rgb=o.data.materials[0].diffuse_color[:3]
    rgb8=[round(max(0,min(1,linear_to_srgb(c)))*255) for c in rgb]
    o['ColorRGB']=','.join(map(str,rgb8))
    report.append({'name':o.name,'collection':o.users_collection[0].name,'triangles':len(o.data.polygons),'vertices':len(o.data.vertices),'material':o.data.materials[0].name,'colorRGB':rgb8,'nonmanifoldEdges':nonmanifold,'degenerateFaces':degenerate})
assert max(x['triangles'] for x in report)<=20000
assert all(x['nonmanifoldEdges']==0 for x in report),[x for x in report if x['nonmanifoldEdges']]
assert all(x['degenerateFaces']==0 for x in report),[x for x in report if x['degenerateFaces']]
summary={'name':'Cat In The Hat - recolourable visual base','meshObjects':len(models),'triangles':sum(x['triangles'] for x in report),'maxMeshTriangles':max(x['triangles'] for x in report),'heightBlenderUnits':max((o.matrix_world@v.co).z for o in models for v in o.data.vertices),'units':'1 Blender unit = 1 intended Roblox stud; .blend unit scale = 0.28 m','rigged':False,'normalMap':'Cat_SurfaceNormal.png','colorTextures':False,'parts':report}
with open(os.path.join(OUT,'Model_Parts.json'),'w',encoding='utf-8') as f:json.dump(summary,f,indent=2)

# Material colours only: no coloured image texture that could lock in a palette.
bpy.ops.object.select_all(action='DESELECT')
for o in models:o.select_set(True)
bpy.context.view_layer.objects.active=models[0]
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT,'CatInTheHat_Base.fbx'),use_selection=True,object_types={'MESH'},apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',use_mesh_modifiers=True,add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True,use_custom_props=True)
for o in models:o.scale=(.28,.28,.28)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'CatInTheHat_Base.glb'),export_format='GLB',use_selection=True,export_yup=True,export_extras=True)
for o in models:o.scale=(1,1,1)

# Convenience palette helper for the user's later Studio import.
lines=['-- Select the imported Cat model, then run this in the Studio Command Bar.',
       '-- Restores the default solid colours. Edit the RGB values to recolour it.',
       'local selected = game:GetService("Selection"):Get()',
       'assert(#selected == 1 and selected[1]:IsA("Model"), "Select the imported Cat model first")',
       'local model = selected[1]',
       'local colors = {']
for r in report:
    lines.append('    ["'+r['name']+'"] = Color3.fromRGB('+', '.join(map(str,r['colorRGB']))+'),')
lines += ['}',
          'for _, part in model:GetDescendants() do',
          '    if part:IsA("MeshPart") and colors[part.Name] then',
          '        part.Color = colors[part.Name]',
          '        part.TextureID = ""',
          '        local surface = part:FindFirstChildOfClass("SurfaceAppearance")',
          '        if surface then surface.ColorMap = ""; surface.Color = Color3.new(1, 1, 1) end',
          '    end',
          'end',
          'print("Applied Cat palette to", model:GetFullName())']
with open(os.path.join(OUT,'Apply_Default_Colours.luau'),'w',encoding='utf-8') as f:f.write('\n'.join(lines)+'\n')

scene.cycles.samples=48
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'CatInTheHat_Base.blend'))
cam=scene.camera
def aim(point):cam.rotation_euler=(Vector(point)-cam.location).to_track_quat('-Z','Y').to_euler()
views=[('CatInTheHat_ThreeQuarter.png',(7,-23,9),(0,0,3.97)),('CatInTheHat_Front.png',(0,-24,4.1),(0,0,4.1)),('CatInTheHat_Back.png',(-8,23,8),(0,0,3.97))]
for filename,pos,target in views:
    cam.location=pos;aim(target)
    scene.render.filepath=os.path.join(OUT,filename)
    bpy.ops.render.render(write_still=True)
print('CAT_EXPORT_DONE '+json.dumps({k:v for k,v in summary.items() if k!='parts'}))
