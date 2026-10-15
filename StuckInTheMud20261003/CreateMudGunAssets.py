import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

OUTPUT = Path(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\StuckInTheMud20261003')
SCENE_NAME = 'StuckInTheMud_Guns20261003'
assert bpy.context.mode == 'OBJECT', 'Preserve user edit mode; run this only in Object mode'
assert SCENE_NAME not in bpy.data.scenes, 'Existing gun asset scene is preserved; inspect it before changes'
OUTPUT.mkdir(parents=True, exist_ok=True)
(OUTPUT / 'Temp').mkdir(exist_ok=True)
original_scene = bpy.context.scene
original_filepath = bpy.data.filepath
original_objects = {object.name: tuple(object.matrix_world) for object in original_scene.objects}
scene = bpy.data.scenes.new(SCENE_NAME)
scene['ManagedGunAssets'] = True
scene['AssetVersion'] = 1
scene['OriginalUserScene'] = original_scene.name
scene['OriginalUserFilepath'] = original_filepath
scene.render.engine = original_scene.render.engine
scene.view_settings.view_transform = original_scene.view_settings.view_transform
scene.render.resolution_x = 1600
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.filepath = str(OUTPUT / 'MudHeatGun_Preview.png')
scene.render.film_transparent = False

palette = {
    'Ink': (24, 35, 62), 'Cream': (255, 246, 216), 'White': (255, 255, 245),
    'Mud': (158, 101, 56), 'DarkMud': (106, 64, 38), 'Clay': (201, 146, 89),
    'Green': (109, 174, 82), 'Mint': (157, 212, 104),
    'Orange': (255, 125, 43), 'DarkOrange': (203, 74, 30),
    'Yellow': (255, 208, 61), 'Lemon': (255, 232, 122),
    'Backdrop': (240, 237, 225),
}
materials = {}
def linear(value):
    value = value / 255
    return value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4
for name, color in palette.items():
    material = bpy.data.materials.new('SITM_' + name)
    material.use_nodes = True
    shader = next(node for node in material.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
    rgba = tuple(linear(value) for value in color) + (1,)
    shader.inputs['Base Color'].default_value = rgba
    shader.inputs['Roughness'].default_value = .47 if name != 'Ink' else .62
    shader.inputs['Metallic'].default_value = 0
    material.diffuse_color = rgba
    materials[name] = material

def collection(name):
    value = bpy.data.collections.new('SITM_' + name)
    scene.collection.children.link(value)
    return value
mud_collection = collection('MudGun')
heat_collection = collection('HeatGun')
studio_collection = collection('PreviewStudio')

def empty(name, target):
    value = bpy.data.objects.new(name, None)
    target.objects.link(value)
    value['GunAssetRoot'] = True
    value['GripOrigin'] = [0, 0, 0]
    value['MuzzleBlender'] = [0, -2.65, 1]
    value['MuzzleRoblox'] = [0, 1, -2.65]
    return value
mud_root = empty('MudGun', mud_collection)
heat_root = empty('HeatGun', heat_collection)

def mesh(name, vertices, faces, target, root, color, smooth=False, bevel=0):
    data = bpy.data.meshes.new('SITM_' + name + '_Mesh')
    data.from_pydata(vertices, [], faces)
    data.update()
    object = bpy.data.objects.new('SITM_' + name, data)
    target.objects.link(object)
    object.parent = root
    data.materials.append(materials[color])
    if bevel:
        data.materials.append(materials['Ink'])
        modifier = object.modifiers.new('CartoonEdge', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 3
        modifier.material = 1
        modifier.harden_normals = True
        weighted = object.modifiers.new('FaceNormals', 'WEIGHTED_NORMAL')
        weighted.keep_sharp = True
        weighted.weight = 40
    for polygon in data.polygons:
        polygon.use_smooth = smooth
    object['GunKind'] = 'Mud' if root == mud_root else 'Heat' if root == heat_root else 'Preview'
    return object

def box(name, center, size, target, root, color, bevel=.055, rotation=None):
    x, y, z = (value / 2 for value in size)
    vertices = [(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    object = mesh(name, vertices, faces, target, root, color, True, bevel)
    object.location = center
    if rotation:
        object.rotation_euler = rotation
    return object

def cylinder(name, center, radius, length, target, root, color, rotation=None, bevel=.025, vertices=32):
    points = [(radius*math.cos(2*math.pi*i/vertices), radius*math.sin(2*math.pi*i/vertices), z)
              for z in (-length/2, length/2) for i in range(vertices)]
    faces = [(i,(i+1)%vertices,(i+1)%vertices+vertices,i+vertices) for i in range(vertices)]
    faces += [tuple(reversed(range(vertices))),tuple(range(vertices,vertices*2))]
    object = mesh(name, points, faces, target, root, color, True, bevel)
    object.location = center
    if rotation:
        object.rotation_euler = rotation
    return object

def sphere(name, center, scale, target, root, color, segments=16, rings=8):
    vertices = [(0,0,-1)]
    for row in range(1,rings):
        angle = -math.pi/2 + math.pi*row/rings
        for column in range(segments):
            azimuth = 2*math.pi*column/segments
            vertices.append((math.cos(angle)*math.cos(azimuth), math.cos(angle)*math.sin(azimuth), math.sin(angle)))
    top = len(vertices)
    vertices.append((0,0,1))
    faces = [(0,1+(i+1)%segments,1+i) for i in range(segments)]
    for row in range(rings-2):
        for i in range(segments):
            a = 1+row*segments+i
            b = 1+row*segments+(i+1)%segments
            faces.append((a,b,b+segments,a+segments))
    faces += [(top,1+(rings-2)*segments+i,1+(rings-2)*segments+(i+1)%segments) for i in range(segments)]
    object = mesh(name, vertices, faces, target, root, color, True)
    object.location = center
    object.scale = scale
    return object

def tube(name, centers, radius, target, root, color, sides=8):
    centers = [Vector(point) for point in centers]
    vertices = []
    for index, point in enumerate(centers):
        tangent = (centers[min(index+1,len(centers)-1)] - centers[max(0,index-1)]).normalized()
        normal = tangent.cross(Vector((0,0,1)))
        if normal.length < .01:
            normal = tangent.cross(Vector((1,0,0)))
        normal.normalize()
        binormal = tangent.cross(normal).normalized()
        for side in range(sides):
            angle = 2*math.pi*side/sides
            vertices.append(tuple(point + radius*(math.cos(angle)*normal + math.sin(angle)*binormal)))
    faces = []
    for row in range(len(centers)-1):
        for side in range(sides):
            a = row*sides+side
            b = row*sides+(side+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces += [tuple(reversed(range(sides))),tuple(range((len(centers)-1)*sides,len(centers)*sides))]
    return mesh(name, vertices, faces, target, root, color, True)

def nozzle(name, target, root, shell_color, inside_color):
    count = 32
    profile = [( .33,.44),(-.34,.71),(-.34,.50),( .33,.34)]
    vertices = [(radius*math.cos(2*math.pi*i/count), depth, radius*math.sin(2*math.pi*i/count)) for depth,radius in profile for i in range(count)]
    faces = [(row*count+i,row*count+(i+1)%count,((row+1)%4)*count+(i+1)%count,((row+1)%4)*count+i) for row in range(4) for i in range(count)]
    object = mesh(name,vertices,faces,target,root,shell_color,True,.025)
    object.location = (0,-2.10,1)
    object.data.materials.append(materials[inside_color])
    for polygon in object.data.polygons:
        if polygon.index >= 2*count:
            polygon.material_index = 2
    cylinder(name+'_Rim',(0,-2.46,1),.76,.12,target,root,'Ink',(math.pi/2,0,0),.015)
    cylinder(name+'_Front',(0,-2.535,1),.66,.08,target,root,shell_color,(math.pi/2,0,0),.015)
    cylinder(name+'_Mouth',(0,-2.585,1),.46,.015,target,root,inside_color,(math.pi/2,0,0),0)

for root, target, primary, accent in [(mud_root,mud_collection,'Green','Mud'),(heat_root,heat_collection,'Orange','Yellow')]:
    prefix = root.name
    box(prefix+'_Body',(0,-.43,1),(1.5,2.05,1.18),target,root,primary,.08)
    box(prefix+'_Belly',(0,-.40,.48),(1.38,1.55,.22),target,root,'Cream',.055)
    box(prefix+'_BackBumper',(0,.64,1),(1.4,.25,.88),target,root,'Cream',.07)
    box(prefix+'_Grip',(0,0,-.02),(.6,.75,1.44),target,root,primary,.09,(math.radians(-9),0,0))
    box(prefix+'_GripFoot',(0,.10,-.77),(.72,.88,.18),target,root,'Cream',.055)
    for row,z in enumerate((-.52,-.28,-.03,.22)):
        box(prefix+'_GripRib'+str(row),(0,-.38,z),(.54,.075,.06),target,root,'Ink',.018)
    sphere(prefix+'_PressButton',(0,-.77,.39),(.24,.21,.18),target,root,accent)
    cylinder(prefix+'_Neck',(0,-1.58,1),.48,.31,target,root,'Ink',(math.pi/2,0,0),.02)
    nozzle(prefix+'_SplatNozzle',target,root,accent,'DarkMud' if root==mud_root else 'DarkOrange')
    for side in (-1,1):
        box(prefix+'_SidePlaque'+str(side),(side*.766,-.32,1.02),(.085,1.25,.73),target,root,'Cream',.04)
        for y in (-.82,.18):
            cylinder(prefix+'_ToyBolt'+str(side)+'_'+str(y),(side*.833,y,1.25),.06,.045,target,root,'Ink',(0,math.pi/2,0),.009,16)
    tube(prefix+'_FeedHose',[(0,.68,1.3),(.13,.92,1.5),(.28,.88,1.82),(.19,.65,2.03)],.085,target,root,'Ink')

cylinder('MudGun_Tank',(0,.13,2.09),.57,1.12,mud_collection,mud_root,'Mud',bevel=.045)
cylinder('MudGun_TankFoot',(0,.13,1.56),.64,.16,mud_collection,mud_root,'Ink',bevel=.025)
cylinder('MudGun_TankCap',(0,.13,2.68),.63,.17,mud_collection,mud_root,'Green',bevel=.028)
sphere('MudGun_TankKnob',(0,.13,2.83),(.25,.25,.16),mud_collection,mud_root,'Cream')
box('MudGun_TankWindow',(.57,.12,2.08),(.06,.55,.65),mud_collection,mud_root,'Clay',.035)
for index,(x,y,z,sx,sz) in enumerate([(-.48,-2.52,.58,.10,.22),(.25,-2.53,.50,.13,.26),(.55,-2.50,.80,.11,.17),(.18,-.1,2.70,.12,.08),(-.32,.14,2.70,.11,.08)]):
    sphere('MudGun_MudDrip'+str(index),(x,y,z),(sx,.10,sz),mud_collection,mud_root,'DarkMud')
for side in (-1,1):
    sphere('MudGun_SplatBadge'+str(side),(side*.837,-.30,1.00),(.05,.30,.21),mud_collection,mud_root,'Mud')
    for index,(y,z,radius) in enumerate([(-.55,1.16,.08),(-.05,.97,.07),(-.3,.77,.06)]):
        sphere('MudGun_BadgeDrop'+str(side)+'_'+str(index),(side*.84,y,z),(.045,radius,radius),mud_collection,mud_root,'Mud')
    box('MudGun_MintAccent'+str(side),(side*.782,-.3,.62),(.07,.68,.095),mud_collection,mud_root,'Mint',.02)

cylinder('HeatGun_WarmCore',(0,.13,2.08),.37,1.05,heat_collection,heat_root,'DarkOrange',bevel=.04)
cylinder('HeatGun_CoilFoot',(0,.13,1.59),.60,.16,heat_collection,heat_root,'Ink',bevel=.025)
helix = []
for index in range(121):
    fraction=index/120
    angle=math.pi/6 + 2*math.pi*3.5*fraction
    helix.append((.52*math.cos(angle),.13+.52*math.sin(angle),1.67+.83*fraction))
tube('HeatGun_WarmCoil',helix,.105,heat_collection,heat_root,'Yellow',10)
for name,point in [('CoilStart',helix[0]),('CoilEnd',helix[-1])]:
    sphere('HeatGun_'+name,point,(.11,.11,.11),heat_collection,heat_root,'Lemon')
cylinder('HeatGun_CoilCap',(0,.13,2.63),.60,.17,heat_collection,heat_root,'Cream',bevel=.028)
sphere('HeatGun_WarmKnob',(0,.13,2.81),(.24,.24,.17),heat_collection,heat_root,'Yellow')
for side in (-1,1):
    cylinder('HeatGun_SunBadge'+str(side),(side*.84,-.30,1.02),.21,.035,heat_collection,heat_root,'Yellow',(0,math.pi/2,0),.009,24)
    for ray in range(8):
        angle=2*math.pi*ray/8
        y=-.30+.30*math.cos(angle)
        z=1.02+.30*math.sin(angle)
        box('HeatGun_SunRay'+str(side)+'_'+str(ray),(side*.84,y,z),(.045,.085,.085),heat_collection,heat_root,'Orange',.015)

mud_root.location=(-2.15,0,0)
heat_root.location=(2.15,0,0)
floor=box('PreviewFloor',(0,0,-1.00),(18,16,.18),studio_collection,None,'Backdrop',.04)
world=bpy.data.worlds.new('SITM_PreviewWorld')
world.use_nodes=True
background=next(node for node in world.node_tree.nodes if node.type=='BACKGROUND')
background.inputs['Color'].default_value=(.8,.82,.86,1)
background.inputs['Strength'].default_value=.8
scene.world=world
def aim(object,target):
    object.rotation_euler=(Vector(target)-object.location).to_track_quat('-Z','Y').to_euler()
def light(name,position,power,size,target):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=power
    data.size=size
    object=bpy.data.objects.new(name,data)
    studio_collection.objects.link(object)
    object.location=position
    aim(object,target)
light('SITM_Key',(2,-5,8),1100,7,(0,0,1))
light('SITM_Fill',(-6,-1,4),850,6,(0,0,1))
light('SITM_Rim',(3,5,6),1250,5,(0,0,1))
camera_data=bpy.data.cameras.new('SITM_PreviewCamera')
camera_data.type='ORTHO'
camera_data.ortho_scale=8.2
camera=bpy.data.objects.new('SITM_PreviewCamera',camera_data)
studio_collection.objects.link(camera)
camera.location=(8,-12,7)
aim(camera,(0,-.35,1.05))
scene.camera=camera

scene.view_layers[0].update()
def stats(root):
    meshes=[object for object in root.children_recursive if object.type=='MESH']
    corners=[object.matrix_world@Vector(corner) for object in meshes for corner in object.bound_box]
    minimum=[min(point[index] for point in corners) for index in range(3)]
    maximum=[max(point[index] for point in corners) for index in range(3)]
    return {'meshObjects':len(meshes),'boundsBlender':[minimum,maximum],'dimensionsBlender':[maximum[i]-minimum[i] for i in range(3)]}
manifest={'scene':scene.name,'userScenePreserved':original_scene.name,'userFilepathPreserved':bpy.data.filepath==original_filepath,'coordinateConvention':'Blender X right, -Y muzzle forward, Z up; Roblox X right, -Z muzzle forward, Y up','MudGun':stats(mud_root),'HeatGun':stats(heat_root),'muzzleBlender':[0,-2.65,1],'muzzleRoblox':[0,1,-2.65],'output':str(OUTPUT)}
assert set(original_objects)==set(object.name for object in original_scene.objects), 'Original scene membership changed'
assert bpy.context.scene==original_scene and bpy.data.filepath==original_filepath, 'Original context changed'
(OUTPUT/'blender-asset-build.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(manifest))
