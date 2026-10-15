import bpy, math, os
from mathutils import Vector

OUT = os.path.dirname(os.path.abspath(__file__))
# Keep the existing assets in their original scene; add the lobby set in a new scene.
scene = bpy.data.scenes.new('G-Blox Lobby Decor')
bpy.context.window.scene = scene
scene.unit_settings.system = 'NONE'
root = bpy.data.collections.new('G-Blox Lobby Decor - Recolourable')
scene.collection.children.link(root)
materials = {}
for name, color in {'Graphite':(.075,.10,.13,1), 'Grey':(.42,.48,.52,1), 'LightGrey':(.76,.83,.85,1), 'Teal':(.02,.80,.86,1), 'GravityPurple':(.53,.25,.90,1), 'SpeedYellow':(1,.73,.08,1), 'White':(.93,.98,1,1)}.items():
    m = bpy.data.materials.new('Lobby_'+name)
    m.diffuse_color = color
    m.use_nodes = True
    m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = color
    m.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = .55
    materials[name] = m
assets = {}
active = None

def asset(name):
    global active
    active = bpy.data.collections.new(name)
    root.children.link(active)
    assets[name] = active

def finish(obj, name, material, bevel=0):
    obj.name = active.name+'_'+name
    for c in list(obj.users_collection): c.objects.unlink(obj)
    active.objects.link(obj)
    obj.data.materials.append(materials[material])
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new('Small clean edge bevel', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj['Recolourable'] = True
    obj['RobloxMaterialHint'] = 'SmoothPlastic'
    obj.select_set(False)
    return obj

def box(name, pos, size, mat='Grey', bevel=.05):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    o=bpy.context.object
    o.dimensions=size
    return finish(o,name,mat,bevel)

def cylinder(name,pos,radius,depth,mat='Grey',vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos)
    return finish(bpy.context.object,name,mat,.035)

def ring(name,pos,major,minor,mat,rotation=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=6, location=pos, rotation=rotation, major_radius=major, minor_radius=minor)
    return finish(bpy.context.object,name,mat)

def text(name,value,pos,size,mat='White'):
    bpy.ops.object.text_add(location=pos,rotation=(math.pi/2,0,0))
    o=bpy.context.object
    o.data.body=value; o.data.align_x='CENTER'; o.data.align_y='CENTER'
    o.data.size=size; o.data.extrude=.014; o.data.resolution_u=2
    bpy.ops.object.convert(target='MESH')
    return finish(bpy.context.object,name,mat)

def bolt(name,pos,scale=1,mat='SpeedYellow'):
    # Extruded lightning silhouette, one independent mesh.
    poly=[(-.10,1.4),(-.85,-.1),(-.12,-.1),(-.50,-1.4),(.90,.35),(.15,.35),(.55,1.4)]
    verts=[(pos[0]+x*scale,pos[1]+d,pos[2]+z*scale) for d in [-.12*scale,.12*scale] for x,z in poly]
    n=len(poly); faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); active.objects.link(o)
    finish(o,name,mat,.03)
    bpy.context.view_layer.objects.active=o; o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(); bpy.ops.object.mode_set(mode='OBJECT'); o.select_set(False)
    return o

asset('Abilities_Shop')
x=-11
box('Foundation',(x,2,.25),(12,7,.5),'Graphite')
box('Floor',(x,2,.6),(11.6,6.6,.2),'LightGrey')
box('BackWall',(x,5,3.8),(11.5,.4,6.2),'Grey')
for side in [-1,1]:
    box('Pillar_'+str(side),(x+side*5.4,0,3.7),(.65,.65,6.2),'Grey')
    box('PillarTrim_'+str(side),(x+side*5.4,-.35,3.7),(.2,.12,5.4),'Teal')
box('Canopy',(x,1.6,7),(12.4,7,.55),'Graphite')
box('CanopyStripe',(x,-1.94,7),(12.2,.12,.16),'Teal')
box('SignBoard',(x,-1.7,8.15),(10,.45,1.8),'Grey')
text('SignText','ABILITIES',(x,-1.96,8.15),1.05)
box('CounterBody',(x,.1,1.6),(9.8,1.5,1.9),'Grey')
box('CounterTop',(x,.1,2.65),(10.2,1.9,.25),'LightGrey')
box('CounterStripe',(x,-.68,1.6),(9,.12,.22),'Teal')
box('DisplayStand',(x,4.35,3.2),(7,.65,.35),'LightGrey')
bolt('DisplayBolt',(x-2,3.94,4.35),.8,'SpeedYellow')
ring('DisplayGravityRing',(x+2,4.08,4.35),.9,.1,'GravityPurple',(math.pi/2,0,0))
box('Terminal',(x+3.7,.1,3.2),(1.5,.25,1.1),'Graphite')
box('TerminalScreen',(x+3.7,-.04,3.2),(1.25,.04,.83),'Teal',.015)

for i,(title,mat) in enumerate([('GRAVITY','GravityPurple'),('VELOCITY','Teal'),('ORBIT','SpeedYellow')]):
    asset('Pet_Podium_'+title.title())
    x=1+i*6
    cylinder('Base',(x,3,.3),2.4,.6,'Graphite')
    cylinder('Plinth',(x,3,1),2.05,.8,'Grey')
    cylinder('Trim',(x,3,1.47),2.1,.14,mat)
    cylinder('Top',(x,3,1.62),1.93,.16,'LightGrey')
    # Egg profile, broad bottom and tapered crown. Low-poly quad mesh.
    verts=[]; faces=[]; segments=20; rows=12
    for j in range(rows+1):
        theta=math.pi*j/rows
        radius=math.sin(theta)*(1.04-.20*math.cos(theta))
        for k in range(segments):
            ang=2*math.pi*k/segments
            verts.append((x+radius*math.cos(ang),3+radius*math.sin(ang),3.25+1.45*math.cos(theta)))
    for j in range(rows):
        for k in range(segments):
            a=j*segments+k; b=j*segments+(k+1)%segments
            faces.append((a,b,b+segments,a+segments))
    mesh=bpy.data.meshes.new('EggShell');mesh.from_pydata(verts,[],faces);mesh.update()
    egg=bpy.data.objects.new('EggShell',mesh);active.objects.link(egg);finish(egg,'EggShell','LightGrey')
    bpy.context.view_layer.objects.active=egg;egg.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project();bpy.ops.object.mode_set(mode='OBJECT');egg.select_set(False)
    ring('EquatorBand',(x,3,3.1),1.09,.075,mat)
    if i==0:
        ring('GravityOrbit',(x,3,3.3),1.66,.06,mat,(.4,.65,0))
    elif i==1:
        bolt('EggBolt',(x,1.97,3.35),.48,mat)
    else:
        ring('OrbitOne',(x,3,3.2),1.65,.06,mat,(.8,.3,0))
        ring('OrbitTwo',(x,3,3.2),1.82,.045,'Teal',(-.7,.5,0))
    box('LabelPlate',(x,.78,1.02),(3.3,.15,.65),'Graphite')
    text('Label',title,(x,.69,1.02),.43)

for i,(title,mat) in enumerate([('SPEED','Teal'),('GRAVITY','GravityPurple')]):
    asset('Treadmill_'+title.title())
    x=-7+i*9; y=-7
    box('Base',(x,y,.4),(4.4,6.8,.65),'Grey')
    box('Belt',(x,y,.78),(3.1,6.1,.18),'Graphite',.025)
    for side in [-1,1]:
        box('SideRail_'+str(side),(x+side*1.91,y,.85),(.24,6.25,.35),mat)
        box('Upright_'+str(side),(x+side*1.85,y+2.4,2.2),(.20,.25,3),'Grey')
        box('Handrail_'+str(side),(x+side*1.85,y+1.2,2.95),(.25,2.6,.22),'LightGrey')
    for j in range(6):
        box('BeltSeam_'+str(j),(x,y-2.5+j, .882),(2.95,.025,.015),'Grey',0)
    box('Console',(x,y+2.4,3.5),(3.8,.35,1),'Graphite')
    text('ConsoleLabel',title,(x,y+2.21,3.55),.48,mat)
    for j in [-1,0,1]:
        box('Control_'+str(j),(x+j*.6,y+2.19,3.2),(.30,.035,.08),mat,.01)
    if i==1:
        ring('GravityHoop',(x,y,3.2),2.75,.09,mat,(math.pi/2,0,0))

asset('Lightning_Decor')
for i,(x,y,s) in enumerate([(-20,0,1.5),(18,2,1.4),(17,-6,.9)]):
    cylinder('Foot_'+str(i),(x,y,.15),.85,.3,'Graphite')
    box('Stem_'+str(i),(x,y,1),(.18,.18,1.7),'Grey')
    bolt('Bolt_'+str(i),(x,y,2.3*s),s,'SpeedYellow' if i!=1 else 'Teal')

# Export each asset as separate meshes in its own FBX. No materials are joined.
for name,col in assets.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in col.objects:o.select_set(True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT,name+'.fbx'),use_selection=True,object_types={'MESH'},apply_unit_scale=True,bake_anim=False,add_leaf_bones=False,axis_forward='-Z',axis_up='Y')
bpy.ops.object.select_all(action='DESELECT')

# A separate presentation collection is not included in any export.
active=bpy.data.collections.new('Preview Studio - do not export');scene.collection.children.link(active)
box('Ground',(0,0,-.13),(70,45,.15),'Graphite',0)
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1600;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Lobby preview world');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.18,.23,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
for pos,power,size in [((-12,-12,23),5000,16),((15,5,19),4200,12),((0,12,18),3500,10)]:
    bpy.ops.object.light_add(type='AREA',location=pos)
    o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size
    o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(28,-43,30))
camera=bpy.context.object;camera.rotation_euler=(Vector((-1,0,2))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=48;scene.camera=camera
scene.render.filepath=os.path.join(OUT,'Lobby_Decor_Preview.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'G-Blox_Lobby_Assets.blend'))
bpy.ops.render.render(write_still=True)
print('LOBBY_ASSETS_COMPLETE',len(assets),'collections')
