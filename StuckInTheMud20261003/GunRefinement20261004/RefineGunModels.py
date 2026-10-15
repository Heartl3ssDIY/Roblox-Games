import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

OUTPUT = Path(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\StuckInTheMud20261003\GunRefinement20261004')
SCENE = bpy.data.scenes['StuckInTheMud_Guns20261003']
assert SCENE.get('ManagedGunAssets') and SCENE.get('AssetVersion') == 1
assert bpy.context.mode == 'OBJECT'
OUTPUT.mkdir(parents=True, exist_ok=True)
(OUTPUT / 'Before').mkdir(exist_ok=True)
(OUTPUT / 'Temp').mkdir(exist_ok=True)
before = OUTPUT / 'Before' / 'MudHeatGuns_Before.blend'
assert not before.exists(), 'A prior refinement backup already exists'
bpy.data.libraries.write(str(before), {SCENE}, path_remap='ABSOLUTE', fake_user=True, compress=True)

root_path = r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets'
old_root = r'C:\Users\sandt\OneDrive\Roblox UI Assets'
if SCENE.render.filepath.startswith(old_root):
    SCENE.render.filepath = SCENE.render.filepath.replace(old_root, root_path, 1)
for image in bpy.data.images:
    if image.filepath.startswith(old_root):
        image.filepath = image.filepath.replace(old_root, root_path, 1)

materials = {m.name.removeprefix('SITM_'): m for m in bpy.data.materials if m.name.startswith('SITM_')}

def new_material(name, rgb, roughness=.5):
    m = bpy.data.materials.new('SITM_' + name)
    m.use_nodes = True
    def linear(v):
        v /= 255
        return v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4
    rgba = tuple(linear(v) for v in rgb) + (1,)
    shader = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    shader.inputs['Base Color'].default_value = rgba
    shader.inputs['Roughness'].default_value = roughness
    m.diffuse_color = rgba
    materials[name] = m

new_material('MudBore', (61, 37, 25))
new_material('HeatBore', (103, 42, 20))
new_material('Rubber', (39, 51, 70), .68)

def mesh(name, vertices, faces, root, color, bevel=0, smooth=False, existing=None):
    obj = existing or SCENE.objects.get('SITM_' + name)
    data = bpy.data.meshes.new('SITM_' + name + '_RefinedMesh')
    data.from_pydata(vertices, [], faces)
    data.update()
    if obj:
        obj.data = data
        obj.modifiers.clear()
    else:
        obj = bpy.data.objects.new('SITM_' + name, data)
        next(c for c in root.users_collection if c in SCENE.collection.children[:]).objects.link(obj)
        obj.parent = root
    obj.location = (0, 0, 0)
    obj.rotation_euler = (0, 0, 0)
    obj.scale = (1, 1, 1)
    data.materials.append(materials[color])
    if bevel:
        data.materials.append(materials['Ink'])
        m = obj.modifiers.new('CartoonEdge', 'BEVEL')
        m.width = bevel
        m.segments = 3
        m.material = 1
        m.harden_normals = True
        w = obj.modifiers.new('FaceNormals', 'WEIGHTED_NORMAL')
        w.keep_sharp = True
        w.weight = 40
    for face in data.polygons:
        face.use_smooth = smooth
    obj['GunKind'] = 'Mud' if root.name == 'MudGun' else 'Heat'
    obj['RefinementVersion'] = 2
    return obj

def prism(name, profile, x0, x1, root, color, bevel=.02):
    n = len(profile)
    verts = [(x, y, z) for x in (x0, x1) for y, z in profile]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    return mesh(name, verts, faces, root, color, bevel, True)

def clipped(cy, cz, width, height, clip):
    y0, y1, z0, z1 = cy - width / 2, cy + width / 2, cz - height / 2, cz + height / 2
    return [(y0 + clip, z0), (y1 - clip, z0), (y1, z0 + clip), (y1, z1 - clip),
            (y1 - clip, z1), (y0 + clip, z1), (y0, z1 - clip), (y0, z0 + clip)]

def box(name, center, size, root, color, bevel=.015, angle=0):
    x, y, z = (v / 2 for v in size)
    vertices = [(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    obj = mesh(name, vertices, faces, root, color, bevel, True)
    obj.location = center
    obj.rotation_euler.z = angle
    return obj

def lathe(name, profile, root, color, inner=None, segments=48, bevel=0):
    vertices = [(r * math.cos(2 * math.pi * i / segments), y, 1 + r * math.sin(2 * math.pi * i / segments))
                for y, r in profile for i in range(segments)]
    rows = len(profile)
    faces = [(row * segments + i, row * segments + (i + 1) % segments,
              ((row + 1) % rows) * segments + (i + 1) % segments, ((row + 1) % rows) * segments + i)
             for row in range(rows) for i in range(segments)]
    obj = mesh(name, vertices, faces, root, color, bevel, True)
    if inner:
        obj.data.materials.append(materials[inner])
        index = len(obj.data.materials) - 1
        for poly in obj.data.polygons:
            if poly.index // segments in (4, 5):
                poly.material_index = index
    return obj

def transform_geometry(obj, transform):
    matrix = obj.matrix_local.copy()
    inverse = matrix.inverted()
    for vertex in obj.data.vertices:
        vertex.co = inverse @ Vector(transform(matrix @ vertex.co))
    obj.data.update()

for gun_name, primary, accent in [('MudGun','Green','Mud'), ('HeatGun','Orange','Yellow')]:
    root = SCENE.objects[gun_name]
    profile = [(-1.47,.69),(-1.27,.50),(.42,.50),(.60,.69),(.60,1.34),(.43,1.52),(-1.18,1.52),(-1.47,1.30)]
    n = len(profile)
    widths = [.57,.69,.69,.63,.63,.69,.69,.57]
    vertices = [(sign * widths[i], y, z) for sign in (-1,1) for i,(y,z) in enumerate(profile)]
    faces = [tuple(reversed(range(n))),tuple(range(n,2*n))] + [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh(gun_name+'_Body', vertices, faces, root, primary, .06, True)
    box(gun_name+'_Belly', (0,-.36,.48), (1.22,1.39,.14), root, 'Cream', .032)
    box(gun_name+'_BackBumper', (0,.625,1.01), (1.23,.17,.69), root, 'Cream', .045)
    box(gun_name+'_GripFoot', (0,.08,-.76), (.68,.80,.14), root, 'Cream', .035)
    for side in (-1,1):
        prism(gun_name+'_SideFrame'+str(side), clipped(-.31,1.04,1.28,.72,.13), side*.686, side*.719, root, 'Ink', .008)
        prism(gun_name+'_SidePlaque'+str(side), clipped(-.31,1.04,1.19,.63,.11), side*.715, side*.760, root, 'Cream', .012)
        for old_y, new_y in [(-.82,-.83),(.18,.20)]:
            bolt = SCENE.objects[gun_name+'_ToyBolt'+str(side)+'_'+str(old_y)] if gun_name+'_ToyBolt'+str(side)+'_'+str(old_y) in SCENE.objects else SCENE.objects['SITM_'+gun_name+'_ToyBolt'+str(side)+'_'+str(old_y)]
            bolt.location = (side*.781,new_y,1.19)
            bolt.scale *= .75
        for i in range(3):
            vent = box(gun_name+'_Vent'+str(side)+'_'+str(i), (side*.776,-.02+i*.105,1.02), (.025,.031,.20), root, 'Ink', .009)
            vent.rotation_euler.x = math.radians(-18)
        prism(gun_name+'_GripInset'+str(side), clipped(.04,-.18,.43,.91,.075), side*.293,side*.317,root,'Rubber',.012)
        for i in range(3):
            box(gun_name+'_GripDetail'+str(side)+'_'+str(i), (side*.331,.04,-.48+i*.23), (.025,.27,.025),root,primary,.006)
    neck = SCENE.objects['SITM_'+gun_name+'_Neck']
    neck.scale.x = neck.scale.y = .91
    lathe(gun_name+'_SplatNozzle', [(-1.71,.40),(-2.23,.55),(-2.50,.61),(-2.59,.61),(-2.59,.445),(-2.10,.285),(-1.71,.285)], root, accent, 'MudBore' if gun_name=='MudGun' else 'HeatBore')
    lathe(gun_name+'_SplatNozzle_Rim', [(-2.49,.635),(-2.615,.650),(-2.615,.444),(-2.49,.444)],root,'Ink',bevel=.009)
    lathe(gun_name+'_SplatNozzle_Front', [(-2.608,.604),(-2.640,.604),(-2.640,.444),(-2.608,.444)],root,'Clay' if gun_name=='MudGun' else 'Yellow',bevel=.008)
    mouth = SCENE.objects['SITM_'+gun_name+'_SplatNozzle_Mouth']
    mouth.location.y = -1.94
    mouth.scale.x = mouth.scale.y = .62
    mouth.data.materials.clear()
    mouth.data.materials.append(materials['Ink'])
    top_prefixes = ('Tank','TankFoot','TankCap','TankKnob','TankWindow') if gun_name=='MudGun' else ('WarmCore','CoilFoot','WarmCoil','CoilStart','CoilEnd','CoilCap','WarmKnob')
    for suffix in top_prefixes:
        obj = SCENE.objects['SITM_'+gun_name+'_'+suffix]
        transform_geometry(obj, lambda p: (p.x*.94,.13+(p.y-.13)*.94,1.55+(p.z-1.55)*.86))
    hose = SCENE.objects['SITM_'+gun_name+'_FeedHose']
    transform_geometry(hose, lambda p:(p.x*.94,.13+(p.y-.13)*.94,1.55+(p.z-1.55)*(.86 if p.z>1.55 else 1)))

mud = SCENE.objects['MudGun']
for i in range(3):
    drip = SCENE.objects['SITM_MudGun_MudDrip'+str(i)]
    drip.location.x *= .88
    drip.location.z = 1+(drip.location.z-1)*.90
    drip.location.y = -2.602
    drip.scale *= .84
for i in (3,4):
    drip = SCENE.objects['SITM_MudGun_MudDrip'+str(i)]
    transform_geometry(drip, lambda p:(p.x*.94,.13+(p.y-.13)*.94,1.55+(p.z-1.55)*.86))
knob = SCENE.objects['SITM_MudGun_TankKnob']
transform_geometry(knob, lambda p: (.72*p.x,.13+.72*(p.y-.13),2.62+.72*(p.z-2.6508)))
prism('MudGun_TankWindow', clipped(.13,2.01,.24,.59,.05), .52,.557,mud,'Ink',.013)
prism('MudGun_LevelFill', clipped(.13,1.96,.155,.40,.027), .558,.574,mud,'Mint',.006)
for i in range(3):
    box('MudGun_LevelTick'+str(i), (.582,.13,1.87+i*.14), (.018,.12,.016),mud,'Cream',.004)
for i in range(8):
    angle = 2*math.pi*i/8
    box('MudGun_CapRib'+str(i), (.570*math.cos(angle),.13+.570*math.sin(angle),2.523),(.038,.105,.085),mud,'Mint',.009,angle)
for side in (-1,1):
    badge = SCENE.objects['SITM_MudGun_SplatBadge'+str(side)]
    badge.location = (side*.779,-.49,1.03)
    badge.scale *= .91
    for i in range(3):
        drop = SCENE.objects['SITM_MudGun_BadgeDrop'+str(side)+'_'+str(i)]
        drop.location.x = side*.783
        drop.location.y = -.49 + (drop.location.y+.30)*.91
        drop.location.z = 1.03+(drop.location.z-1)*.91
        drop.scale *= .91
    box('MudGun_MintAccent'+str(side), (side*.708,-.36,.646),(.045,.80,.050),mud,'Mint',.012)

heat = SCENE.objects['HeatGun']
knob = SCENE.objects['SITM_HeatGun_WarmKnob']
transform_geometry(knob,lambda p:(.75*p.x,.13+.75*(p.y-.13),2.60+.75*(p.z-2.6336)))
for side in (-1,1):
    badge = SCENE.objects['SITM_HeatGun_SunBadge'+str(side)]
    badge.location = (side*.783,-.49,1.035)
    badge.scale *= .88
    for i in range(8):
        angle = 2*math.pi*i/8
        ray = box('HeatGun_SunRay'+str(side)+'_'+str(i),(side*.781,-.49+.277*math.cos(angle),1.035+.277*math.sin(angle)),(.035,.083,.050),heat,'Orange',.010)
        ray.rotation_euler.x = angle
    box('HeatGun_LemonAccent'+str(side),(side*.708,-.36,.646),(.045,.80,.050),heat,'Lemon',.012)

SCENE['AssetVersion'] = 2
SCENE['RefinementBrief'] = 'Cleaner tapered body, shaped badge panels, open recessed nozzle, shorter tank and coil, rubber grips. Original identity retained.'
SCENE.view_layers[0].update()
SCENE.render.filepath = str(OUTPUT / 'MudHeatGun_Preview.png')
print(json.dumps({'scene':SCENE.name,'version':SCENE['AssetVersion'],'backup':str(before),'objects':len(SCENE.objects),'filepathPreserved':bpy.data.filepath,'muzzleUnchanged':[0,-2.65,1]}))
