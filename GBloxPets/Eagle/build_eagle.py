"""Build a recolourable G-Blox Eagle; run with Blender --background --python."""
from pathlib import Path
import bpy
import math
import json
from mathutils import Vector

OUT = Path(__file__).resolve().parent
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
    if collection.name != 'Collection' and collection.users == 0:
        bpy.data.collections.remove(collection)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
model = bpy.data.collections.new('EAGLE | Import meshes')
fx = bpy.data.collections.new('EAGLE | Optional glow meshes')
stage = bpy.data.collections.new('STUDIO | Do not export')
for c in (model, fx, stage):
    scene.collection.children.link(c)

def linear(c):
    return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4

def material(name, hexcolor, metallic=0, roughness=.3, emission=0):
    col = tuple(linear(int(hexcolor[i:i+2], 16) / 255) for i in (0,2,4))
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*col, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*col, 1)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    if emission:
        bsdf.inputs['Emission Color'].default_value = (*col, 1)
        bsdf.inputs['Emission Strength'].default_value = emission
    return m

M = {
    'Pearl': material('01 | Pearl armour', 'EBF3FF', .25, .27),
    'Cyan': material('02 | Velocity cyan', '13C7D2', .3, .25),
    'Silver': material('03 | Titanium silver', '9FAFC9', .8, .25),
    'Purple': material('04 | Gravity violet', '8750E3', .5, .28),
    'Gold': material('05 | Eagle gold', 'FFD447', .4, .25),
    'Ink': material('06 | Obsidian eyes', '09182B', .15, .16),
    'White': material('07 | Eye highlights', 'FFFFFF', 0, .18),
    'Glow': material('08 | Cyan emission - Neon in Roblox', '17F5FF', .1, .2, 3),
    'GlowInner': material('09 | Jet core - Neon in Roblox', 'C8FFFF', .0, .2, 5),
}

def put(obj, name, mat, coll=model):
    obj.name = name
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)
    obj.data.materials.clear()
    obj.data.materials.append(M[mat])
    obj['RecolourGroup'] = mat
    obj['Pet'] = 'Eagle'
    if coll == fx:
        obj['RobloxMaterial'] = 'Neon'
        obj['OptionalVFX'] = True
    return obj

def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)

def finish(obj, bevel=0, smooth=False):
    if bevel:
        mod = obj.modifiers.new('Soft game-ready edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        mod.affect = 'EDGES'
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    if bevel:
        mod = obj.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL')
        mod.keep_sharp = True
    apply_modifiers(obj)
    return obj

def box(name, loc, size, mat, bevel=.06, coll=model, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rotation:
        obj.rotation_euler = rotation
    put(obj, name, mat, coll)
    return finish(obj, bevel, True)

def ellipsoid(name, loc, size, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1, location=loc)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    put(obj, name, mat)
    return finish(obj, 0, True)

def prism_xy(name, points, z, depth, mat, bevel=.04, coll=model):
    n = len(points)
    verts = [(x,y,z-depth/2) for x,y in points] + [(x,y,z+depth/2) for x,y in points]
    faces = [tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name,mesh)
    model.objects.link(obj)
    put(obj,name,mat,coll)
    return finish(obj,bevel,True)

def prism_xz(name, points, y, depth, mat, bevel=.03, coll=model):
    obj = prism_xy(name,points,0,depth,mat,bevel,coll)
    obj.rotation_euler.x = math.pi/2
    obj.location.y = y
    return obj

def rod(name, start, end, radius, mat, coll=model, tip_radius=None):
    a,b = Vector(start),Vector(end)
    direction = b-a
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=radius,
        radius2=radius if tip_radius is None else tip_radius,
        depth=direction.length, location=(a+b)/2)
    obj = bpy.context.object
    obj.rotation_euler = direction.to_track_quat('Z','Y').to_euler()
    put(obj,name,mat,coll)
    return finish(obj,.025 if tip_radius is None else .008,True)

# Single head volume: no torso, neck, feet or legs.
box('Head_Pearl_Cube',(0,0,0),(3.0,2.55,2.65),'Pearl',.23)
box('Face_Cyan_Visor',(0,-1.29,-.02),(2.62,.20,1.46),'Cyan',.22)
box('Helmet_Pearl_Crown',(0,.0,1.08),(3.03,2.59,.73),'Pearl',.18)
box('Helmet_Cyan_CenterStripe',(0,-.015,1.455),(.62,2.18,.055),'Cyan',.025)
box('Helmet_Cyan_Forehead',(0,-1.317,.99),(.74,.065,.65),'Cyan',.055)

# Continuous bevelled goggle frame with an actual open centre (no texture).
outer=[(-1.40,.57),(-.88,.64),(-.40,.49),(0,.42),(.40,.49),(.88,.64),(1.40,.57),
       (1.40,-.46),(1.18,-.69),(.39,-.69),(0,-.43),(-.39,-.69),(-1.18,-.69),(-1.40,-.46)]
inner=[(x*.925,z*.79-.01) for x,z in outer]
verts=[]
for y in (-1.47,-1.59):
    verts += [(x,y,z) for x,z in outer] + [(x,y,z) for x,z in inner]
n=len(outer)
faces=[]
for i in range(n):
    j=(i+1)%n
    faces += [(i,j,2*n+j,2*n+i),(n+j,n+i,3*n+i,3*n+j),
              (2*n+i,2*n+j,3*n+j,3*n+i),(j,i,n+i,n+j)]
mesh=bpy.data.meshes.new('Goggles ring topology')
mesh.from_pydata(verts,[],faces)
mesh.update()
obj=bpy.data.objects.new('Goggles_Silver_Frame',mesh)
model.objects.link(obj)
put(obj,obj.name,'Silver')
finish(obj,.035,True)

for side in (-1,1):
    s='L' if side<0 else 'R'
    box(f'Helmet_{s}_Cyan_SideBand',(side*1.505,.04,.19),(.08,2.30,.36),'Cyan',.03)
    box(f'Goggles_{s}_Violet_Temple',(side*1.43,-1.03,.02),(.16,.78,.46),'Purple',.07)
    ellipsoid(f'Eye_{s}_Ink',(side*.63,-1.435,-.045),(.365,.155,.455),'Ink')
    ellipsoid(f'Eye_{s}_Highlight',(side*.63-.10,-1.582,.125),(.105,.025,.14),'White')
    # Angled brows differentiate the eagle from the rounded falcon reference.
    pts=[(side*.20,.40),(side*.38,.59),(side*1.16,.70),(side*1.18,.51)]
    prism_xz(f'Brow_{s}_Pearl',pts,-1.615,.13,'Pearl',.035)

# Raised geometric lightning insignia, no letters or decals.
prism_xz('Forehead_Gold_Lightning',[(.065,1.27),(-.18,.96),(-.035,.96),(-.08,.77),(.20,1.08),(.035,1.08)],-1.375,.045,'Gold',.008)

# Hooked eagle beak, with a tapered downward point.
verts=[(-.25,-1.48,-.38),(.25,-1.48,-.38),(-.22,-1.53,-.72),(.22,-1.53,-.72),
       (-.17,-1.96,-.54),(.17,-1.96,-.54),(0,-2.10,-.87),(0,-1.76,-1.01)]
faces=[(0,1,5,4),(0,4,6,7,2),(1,3,7,6,5),(2,7,3),(4,5,6),(0,2,3,1)]
mesh=bpy.data.meshes.new('Hooked beak')
mesh.from_pydata(verts,[],faces)
mesh.update()
obj=bpy.data.objects.new('Beak_Gold_Hook',mesh)
model.objects.link(obj)
put(obj,obj.name,'Gold')
finish(obj,.045,True)

for side in (-1,1):
    s='L' if side<0 else 'R'
    # Feather roots intersect the HEAD sides, never a separate body.
    ellipsoid(f'Wing_{s}_Silver_Root',(side*1.49,.23,-.17),(.22,.44,.43),'Silver')
    wing=[(1.43,-.13),(1.77,-.28),(2.63,.90),(2.73,1.59),(2.11,1.40),(1.48,.60)]
    prism_xy(f'Wing_{s}_Silver_Armour',[(side*x,y) for x,y in wing],-.21,.24,'Silver',.085)
    for i in range(3):
        x=1.70+i*.24
        y=.03+i*.30
        pts=[(x,y),(x+.30,y+.02),(x+.80,y+1.12),(x+.68,y+1.44),(x+.40,y+1.24)]
        prism_xy(f'Wing_{s}_Feather_{i+1}_'+('Pearl' if i==0 else 'Purple'),
                 [(side*a,b) for a,b in pts],-.09+i*.025,.14,'Pearl' if i==0 else 'Purple',.045)
    pts=[(1.64,-.14),(1.79,-.17),(2.68,1.27),(2.60,1.43)]
    prism_xy(f'Wing_{s}_Cyan_LeadingEdge',[(side*x,y) for x,y in pts],-.055,.07,'Cyan',.025)
    # Compact wing-mounted jets. Emission meshes can be omitted at import.
    x=side*2.02
    rod(f'Thruster_{s}_Silver_Housing',(x,.68,-.50),(x,1.24,-.50),.22,'Silver')
    rod(f'Thruster_{s}_Ink_Nozzle',(x,1.225,-.50),(x,1.30,-.50),.173,'Ink')
    rod(f'VFX_{s}_Cyan_Jet',(x,1.31,-.50),(x,2.06,-.50),.137,'Glow',fx,.012)
    rod(f'VFX_{s}_White_Core',(x,1.32,-.50),(x,1.83,-.50),.077,'GlowInner',fx,.005)
    # Helmet speed vents, individually recolourable.
    for i in range(3):
        box(f'Helmet_{s}_Silver_Vent_{i+1}',(side*1.51,.35+i*.22,.81),(.045,.095,.24),'Silver',.015)

for i in (-1,0,1):
    x=i*.35
    pts=[(x-.15,1.17),(x+.15,1.17),(x+i*.14+.18,2.03),(x+i*.14,2.29),(x+i*.14-.18,2.03)]
    prism_xy(f'Tail_{i+2}_Pearl_Feather',pts,-.50,.17,'Pearl',.05)
    pts=[(x-.06,1.27),(x+.06,1.27),(x+i*.14+.065,2.01),(x+i*.14,2.16),(x+i*.14-.065,2.01)]
    prism_xy(f'Tail_{i+2}_Cyan_Inlay',pts,-.399,.035,'Cyan',.014)

box('VFX_Cyan_Underlight',(0,0,-1.32),(2.32,1.91,.065),'Glow',.03,fx)

# Fix face winding on mirrored hand-built meshes; apply transforms for import.
all_meshes=list(model.objects)+list(fx.objects)
for obj in all_meshes:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')

root=bpy.data.objects.new('Eagle_ROOT',None)
model.objects.link(root)
root.empty_display_type='PLAIN_AXES'
root['ImportNotes']='Front is -Y; up is Z. No rig. Named separate parts, one material per mesh.'
for obj in all_meshes:
    obj.parent=root

# Studio setup is kept in its own non-exported collection.
floor_mat=material('STUDIO | Navy','101D36',.15,.47)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-1.94))
floor=bpy.context.object
floor.name='STUDIO_Floor'
for c in list(floor.users_collection): c.objects.unlink(floor)
stage.objects.link(floor)
floor.data.materials.append(floor_mat)

def aim(obj, target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

def light(name, location, color, power, size):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=power
    data.shape='DISK'
    data.size=size
    data.color=color
    obj=bpy.data.objects.new(name,data)
    stage.objects.link(obj)
    obj.location=location
    aim(obj,(0,0,0))

light('Key_Softbox',(1,-5,7),(1,.91,.80),1000,5)
light('Fill_Cyan',(-5,-2,2),(.25,.85,1),700,4)
light('Rim_Violet',(4,4,5),(.65,.35,1),1200,3)
light('Front_Soft',(-1,-6,0),(1,1,1),150,3)
data=bpy.data.cameras.new('Reference camera')
cam=bpy.data.objects.new('STUDIO_Camera',data)
stage.objects.link(cam)
cam.location=(6.2,-10.5,5.5)
aim(cam,(0,.1,.1))
data.type='ORTHO'
data.ortho_scale=7.7
scene.camera=cam
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x=1100
scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.world.color=(.18,.18,.18)
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False

# Save clean named geometry in FBX. Blender glow nodes are not Roblox VFX.
def export_fbx(filename, objects):
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.fbx(filepath=str(OUT/filename),use_selection=True,
        object_types={'MESH','EMPTY'},apply_unit_scale=True,axis_forward='-Z',axis_up='Y',
        use_mesh_modifiers=True,mesh_smooth_type='FACE',add_leaf_bones=False,bake_anim=False,
        use_custom_props=True,path_mode='AUTO')

export_fbx('GBlox_Eagle_Parts.fbx',list(model.objects))
export_fbx('GBlox_Eagle_WithGlow.fbx',all_meshes)

report={'pet':'Eagle','mesh_count':len(all_meshes),'base_mesh_count':len(model.objects)-1,
        'vfx_mesh_count':len(fx.objects),'triangles':0,'parts':[]}
for obj in all_meshes:
    obj.data.calc_loop_triangles()
    count=len(obj.data.loop_triangles)
    report['triangles']+=count
    report['parts'].append({'name':obj.name,'material':obj.data.materials[0].name,'triangles':count})
(OUT/'parts_manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.ops.object.select_all(action='DESELECT')
for obj in all_meshes: obj.select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['Head_Pearl_Cube']
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=10
            area.spaces.active.region_3d.view_location=(0,0,0)
            area.spaces.active.shading.color_type='MATERIAL'
scene.render.filepath=str(OUT/'GBlox_Eagle_Preview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'GBlox_Eagle.blend'))
bpy.ops.render.render(write_still=True)
print('EAGLE_COMPLETE '+json.dumps({k:v for k,v in report.items() if k!='parts'}))
