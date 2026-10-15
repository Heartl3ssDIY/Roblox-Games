"""G-Blox Gravity Hall. Procedural original architecture; 1 unit = 1 stud."""
import bpy, math, os, json
from mathutils import Vector
OUT = os.path.dirname(os.path.abspath(__file__))
W, D, H = 288.3426818847656, 200.13206481933594, 62.0
scene = bpy.data.scenes.new("G-Blox - Gravity Hall")
bpy.context.window.scene = scene
scene.unit_settings.system = 'NONE'
scene["Studs_per_Blender_unit"] = 1.0
scene["Floor_width_studs"] = W
scene["Floor_depth_studs"] = D
scene["Design_note"] = "2x measured original width and length. No existing gameplay furniture recreated."
collections = {}
for key in ["01 Floor", "02 Enclosed shell", "03 Roof - hide for placement", "04 Gallery and stairs", "05 Gravity monument", "06 Practice obby", "07 Architectural decor", "08 Lighting", "09 Cameras"]:
    c = bpy.data.collections.new(key)
    scene.collection.children.link(c)
    collections[key[:2]] = c
active = collections["01"]
mats = {}
def material(key, color, metallic=0, rough=.5, emission=0):
    m = bpy.data.materials.new("GH_" + key)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = rough
    if emission:
        p.inputs["Emission Color"].default_value = (*color, 1)
        p.inputs["Emission Strength"].default_value = emission
    mats[key] = m
material("Graphite", (.035,.055,.082), .45)
material("Slate", (.13,.19,.245), .35)
material("Floor", (.24,.30,.35), .22,.48)
material("Panel", (.51,.62,.68), .4,.4)
material("Ivory", (.80,.87,.87), .25,.37)
material("Dark", (.013,.025,.04), .2)
material("Cyan", (.015,.67,.8), .5,.3)
material("Amber", (.94,.43,.07), .45,.34)
material("Purple", (.34,.15,.65), .4,.35)
material("Leaf", (.08,.29,.22), .05)
material("EMIT_Cyan", (.02,.75,1), .0,.35,3)
material("EMIT_White", (.75,.9,1), 0,.35,4)
material("EMIT_Amber", (1,.48,.1), 0,.35,2)
def link(o,name,mat):
    o.name=name
    for c in list(o.users_collection):
        c.objects.unlink(o)
    active.objects.link(o)
    if mat: o.data.materials.append(mats[mat])
    return o
def bevel(o, amount=.2):
    if amount:
        mod=o.modifiers.new("Soft machined edges","BEVEL")
        mod.width=amount
        mod.segments=2
    return o
def box(name, loc, size, mat="Graphite", b=.18):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o=link(bpy.context.object,name,mat)
    o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return bevel(o,b)
def cyl(name,loc,r,depth,mat,verts=48,b=.15):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth,location=loc)
    return bevel(link(bpy.context.object,name,mat),b)
def beam(name,a,b,width,mat="Graphite"):
    a,b=Vector(a),Vector(b)
    o=box(name,(a+b)/2,(width,width,(b-a).length),mat,width*.12)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return o
def ring(name,loc,r,tube,mat,rotation=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=64,minor_segments=8,location=loc,major_radius=r,minor_radius=tube)
    o=link(bpy.context.object,name,mat)
    o.rotation_euler=rotation
    return o
def text(name,body,loc,size,mat="Ivory",rotation=(math.pi/2,0,0)):
    curve=bpy.data.curves.new(name,"FONT")
    curve.body=body
    curve.align_x='CENTER'
    curve.size=size
    curve.extrude=.035
    curve.bevel_depth=.015
    o=bpy.data.objects.new(name,curve)
    active.objects.link(o)
    curve.materials.append(mats[mat])
    o.location=loc
    o.rotation_euler=rotation
    return o
def area(name,loc,target,power,size,color=(.75,.9,1)):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=power
    data.shape='DISK'
    data.size=size
    data.color=color
    o=bpy.data.objects.new(name,data)
    collections["08"].objects.link(o)
    o.location=loc
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    return o
# Continuous safe floor. Insets are decorative, not obstacles.
box("FLOOR_Main_288.343x200.132", (0,0,-1.5),(W,D,3),"Floor",.35)
for x in [-W/2+5,W/2-5]:
    box("FLOOR_Perimeter_inlay",(x,0,.025),(.35,D-8,.05),"Cyan",.015)
for y in [-D/2+5,D/2-5]:
    box("FLOOR_Perimeter_inlay",(0,y,.025),(W-10,.35,.05),"Cyan",.015)
for x in [-48,48]:
    box("FLOOR_Avenue_border",(x,0,.035),(.42,D-12,.07),"EMIT_Cyan",.02)
for y in range(-80,81,16):
    box("FLOOR_Avenue_joint",(0,y,.021),(94,.13,.04),"Dark",.01)
for x in [-113,-81,81,113]:
    for y in [-72,-40,-8,24]:
        box("FLOOR_Bay_tile",(x,y,.012),(31.8,31.8,.025),"Slate",.01)
for x in [-61,61]:
    for y in [-66,-49,-32,-15,2,19,36]:
        o=box("FLOOR_Wayfinding_dash",(x,y,.04),(3,7,.06),"Cyan",.03)
        o.rotation_euler.z=math.radians(-25 if x<0 else 25)
# Fully enclosed walls, structural piers and inset panels.
active=collections["02"]
for x in [-W/2+1.5,W/2-1.5]:
    box("SHELL_Sidewall",(x,0,H/2),(3,D,H),"Graphite",.35)
for y in [-D/2+1.5,D/2-1.5]:
    box("SHELL_Endwall",(0,y,H/2),(W-6,3,H),"Graphite",.35)
for sign in [-1,1]:
    x=sign*(W/2-4)
    for y in [-78,-39,0,39,78]:
        box("WALL_Rib",(x,y,30),(5,3,60),"Panel",.6)
        box("EMIT_Wall_rib",(x-sign*2.6,y,29),(.18,.8,44),"EMIT_Cyan",.06)
    for y in [-58.5,-19.5,19.5,58.5]:
        box("WALL_Recess",(x-sign*1.2,y,25),(1,32,36),"Dark",.7)
        box("WALL_Upper_panel",(x-sign*1.9,y,43),(.7,31,5),"Slate",.2)
        box("WALL_Kick_panel",(x-sign*1.9,y,6),(.7,31,9),"Slate",.2)
        for z in [12,15,18]:
            box("WALL_Vent",(x-sign*2.3,y,z),(.6,24,.55),"Panel",.1)
# Back wall centerpiece behind gallery.
for x in [-112,-72,0,72,112]:
    box("WALL_Back_pier",(x,D/2-4,30),(3,4,60),"Panel",.4)
box("WALL_Rear_sign_back",(0,D/2-6.7,43),(82,1.3,18),"Dark",1)
text("SIGN_GBLOX","G - B L O X",(0,D/2-7.5,43.5),8,"Ivory")
text("SIGN_GravityHall","G R A V I T Y   H A L L",(0,D/2-7.6,38),2,"Cyan")
for x in [-58,58]:
    box("EMIT_Back_accent",(x,D/2-5,40),(1,1,24),"EMIT_Cyan",.2)
# Entrance is a closed architectural portal, not an invented teleport.
box("WALL_Entrance_surround",(0,-D/2+4,19),(42,3,38),"Panel",1)
box("WALL_Entrance_closed",(0,-D/2+6,17),(35,1,31),"Slate",.5)
box("EMIT_Entrance_seam",(0,-D/2+6.7,17),(.5,.25,28),"EMIT_Cyan",.1)
# Roof remains complete and visible in the saved scene.
active=collections["03"]
box("ROOF_Continuous_closed",(0,0,H+1),(W,D,2),"Graphite",.4)
for x in [-120,-72,-24,24,72,120]:
    box("ROOF_Longitudinal_beam",(x,0,H-1),(2.2,D-5,3),"Panel",.4)
for y in [-75,-25,25,75]:
    box("ROOF_Crossbeam",(0,y,H-2),(W-5,2.5,5),"Panel",.4)
for x in [-96,-48,0,48,96]:
    for y in [-50,0,50]:
        box("ROOF_Coffer",(x,y,H-.6),(39,39,1),"Slate",.8)
        box("ROOF_Lamp_housing",(x,y,H-1.5),(3,27,1.2),"Dark",.4)
        box("EMIT_Ceiling_strip",(x,y,H-2.15),(1.4,25,.2),"EMIT_White",.15)
for x in [-135,135]:
    box("EMIT_Roof_cove",(x,0,H-3),(.7,D-12,.7),"EMIT_Cyan",.2)
# Rear gallery. Stair rise 1.125 studs, tread 2.4 studs.
active=collections["04"]
box("GALLERY_Deck",(0,83,16.75),(W-12,30,2.5),"Slate",.4)
box("EMIT_Gallery_lip",(0,67.8,17),(W-16,.3,.6),"EMIT_Cyan",.1)
for x in [-125,-80,-40,40,80,125]:
    box("GALLERY_Support",(x,87,8),(3.4,9,16),"Graphite",.4)
for x in [-108,108]:
    for i in range(16):
        z=(i+1)*1.125
        box("STAIR_Tread",(x,29+i*2.4,z/2),(16,2.4,z),"Panel",.09)
        box("STAIR_Nosing",(x,28+i*2.4,z+.035),(15.5,.3,.07),"Cyan",.025)
    for sx in [-9,9]:
        for i in [0,4,8,12,15]:
            z=(i+1)*1.125
            box("STAIR_Rail_post",(x+sx,29+i*2.4,z+2.7),(.4,.4,5.4),"Graphite",.08)
        beam("STAIR_Handrail",(x+sx,29,6.525),(x+sx,65,23.4),.55,"Cyan")
for a,b in [(-135,-118),(-98,98),(118,135)]:
    box("GALLERY_Handrail",((a+b)/2,68,23.5),(b-a,.7,.7),"Panel",.16)
    box("GALLERY_Lower_rail",((a+b)/2,68,20),(b-a,.35,.35),"Cyan",.08)
    for x in range(math.ceil(a),math.floor(b)+1,10):
        box("GALLERY_Post",(x,68,20.8),(.6,.6,5.4),"Graphite",.12)
# Gravity monument: original, faceted block-figure, ring and suspended cubes.
active=collections["05"]
cx,cy=0,28
cyl("STATUE_Base",(cx,cy,.8),15,1.6,"Graphite",64,.35)
cyl("STATUE_Inlay",(cx,cy,1.7),13.6,.3,"EMIT_Cyan",64,.12)
cyl("STATUE_Plinth",(cx,cy,3.2),12.8,2.8,"Slate",12,.3)
cyl("STATUE_Top",(cx,cy,4.75),11.3,.3,"Ivory",12,.1)
ring("STATUE_Gravity_orbit",(0,30,23),17,.65,"Cyan",(math.pi/2,0,math.radians(-12)))
ring("EMIT_Gravity_orbit",(0,29.8,23),16.1,.14,"EMIT_Cyan",(math.pi/2,0,math.radians(-12)))
# Pose in X/Z, facing entrance (-Y).
beam("STATUE_Left_shin",(-5,26,6),(-3,27,13),3.6,"Ivory")
beam("STATUE_Left_thigh",(-3,27,13),(0,28,19),4.3,"Slate")
box("STATUE_Left_boot",(-5,24.9,6),(4.4,6,2.6),"Graphite",.45)
beam("STATUE_Right_thigh",(1,28,19),(6,27,16),4.3,"Ivory")
beam("STATUE_Right_shin",(6,27,16),(9,30,20),3.6,"Slate")
box("STATUE_Right_boot",(9,29,20),(4.4,5.5,2.6),"Graphite",.45)
torso=box("STATUE_Torso",(0,28,23),(9,5.4,9),"Ivory",.7)
torso.rotation_euler.y=math.radians(-12)
box("STATUE_Chest_panel",(0,25.1,23),(5.5,.45,5.8),"Slate",.4)
box("EMIT_Statue_core",(0,24.8,23),(1.7,.3,3),"EMIT_Cyan",.25)
beam("STATUE_Arm_left",(-5,28,26),(-9,26,30),3,"Slate")
beam("STATUE_Forearm_left",(-9,26,30),(-7,22,33),2.8,"Ivory")
box("STATUE_Hand_left",(-7,22,33),(3.1,3.1,3.1),"Cyan",.5)
beam("STATUE_Arm_right",(5,28,26),(9,28,22),3,"Slate")
beam("STATUE_Forearm_right",(9,28,22),(12,25,25),2.8,"Ivory")
box("STATUE_Hand_right",(12,25,25),(3.1,3.1,3.1),"Cyan",.5)
box("STATUE_Helmet",(0,27,32.2),(7,6.4,6.8),"Graphite",1)
box("EMIT_Statue_visor",(0,23.65,32.3),(5.6,.35,2.1),"EMIT_Cyan",.45)
for p,s in [((-14,29,16),2.5),((13,31,34),3),((-10,30,39),1.8)]:
    o=box("STATUE_Orbit_cube",p,(s,s,s),"Ivory",.25)
    o.rotation_euler=(.4,.3,.6)
text("STATUE_Plaque","DEFY GRAVITY",(0,15.1,2.8),1.35,"Ivory")
# Safe optional practice circuit; empty floor catches falls.
active=collections["06"]
pads=[(85,-75,1.2,11),(101,-67,2.4,9),(115,-56,4,9),(124,-41,5.7,8),
      (124,-27,7.5,8),(115,-13,9.1,9),(126,1,10.8,9),(126,17,12.5,10)]
for i,(x,y,z,s) in enumerate(pads):
    box("OBBY_Landing_%02d"%(i+1),(x,y,z-.6),(s,s,1.2),"Slate",.45)
    box("EMIT_Obby_edge_%02d"%(i+1),(x,y,z+.035),(s-.8,s-.8,.07),"Cyan",.15)
    box("OBBY_Grip_%02d"%(i+1),(x,y,z+.08),(s-1.7,s-1.7,.08),"Graphite",.15)
    text("OBBY_Number_%02d"%(i+1),str(i+1).zfill(2),(x,y-1,z+.16),2,"Ivory",(0,0,0))
    if z>2:
        box("OBBY_Support",(x,y,(z-1.2)/2),(2.3,2.3,z-1.2),"Graphite",.2)
text("SIGN_Practice","P R A C T I C E",(111,-84,.13),2.7,"Cyan",(0,0,0))
# Benches / plants kept to edges, leaving furnishing bays empty.
active=collections["07"]
for x,y in [(-126,-74),(-126,-30),(-126,20),(126,49),(-65,87),(65,87)]:
    base=18 if y==87 else 0
    box("DECOR_Planter",(x,y,base+2.4),(7,7,4.8),"Slate",.6)
    box("DECOR_Planter_rim",(x,y,base+4.7),(7.5,7.5,.6),"Panel",.25)
    box("DECOR_Soil",(x,y,base+5),(6,6,.2),"Dark",.1)
    for j,(dx,dy,ht) in enumerate([(-1.3,-1,6),(1.5,1,8),(0,0,10)]):
        beam("DECOR_Stem",(x+dx,y+dy,base+5),(x+dx,y+dy,base+5+ht),.3,"Leaf")
        for k in [0,1]:
            o=box("DECOR_Leaf",(x+dx+(-1 if k else 1),y+dy,base+5+ht-k*2),(3.4,1.3,.45),"Leaf",.3)
            o.rotation_euler.y=math.radians(35 if k else -35)
for x,y,z in [(-126,-53,0),(-126,-8,0),(-33,88,18),(33,88,18)]:
    box("DECOR_Bench_seat",(x,y,z+3),(13,4.5,.85),"Panel",.35)
    for dx in [-4.5,4.5]:
        box("DECOR_Bench_leg",(x+dx,y,z+1.35),(1,3,2.7),"Graphite",.2)
    box("DECOR_Bench_inlay",(x,y-2.3,z+3),(11,.13,.25),"EMIT_Cyan",.05)
# Decorative rear alcove fins, no shop furniture.
for sign in [-1,1]:
    for j in range(6):
        box("DECOR_Back_fins",(sign*(77+j*5),94,33),(1.6,2,22),"Slate",.3)
# Motivated ceiling fixtures and photographic fill; Roblox light helper supplied separately.
for x in [-96,-48,0,48,96]:
    for y in [-50,0,50]:
        area("LIGHT_Ceiling",(x,y,58),(x,y,0),30000,28)
area("LIGHT_Statue_key",(-24,-5,43),(0,28,22),60000,22,(.7,.88,1))
area("LIGHT_Statue_rim",(15,57,38),(0,28,22),42000,18,(.08,.65,1))
area("LIGHT_Entrance_fill",(0,-87,39),(0,18,14),70000,45,(1,.83,.65))
world=bpy.data.worlds.new("GH_Interior_world")
world.use_nodes=True
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
bg.inputs["Color"].default_value=(.17,.23,.32,1)
bg.inputs["Strength"].default_value=.35
scene.world=world
active=collections["09"]
def camera(name,loc,target,lens):
    data=bpy.data.cameras.new(name)
    data.lens=lens
    data.clip_end=1200
    o=bpy.data.objects.new(name,data)
    active.objects.link(o)
    o.location=loc
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    return o
hero=camera("CAM_01_Interior",(108,-85,30),(-9,28,24),20)
camera("CAM_02_Entrance",(0,-86,20),(0,34,25),19)
camera("CAM_03_Obby",(71,-85,14),(120,-8,13),24)
camera("CAM_04_Layout",(265,-290,300),(0,0,0),45)
scene.camera=hero
scene.render.engine='BLENDER_EEVEE'
scene.eevee.shadow_pool_size='512'
scene.eevee.shadow_resolution_scale=.5
scene.render.resolution_x=1600
scene.render.resolution_y=1000
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False
# Select statue and frame camera in live viewport, not the untouched default scene.
bpy.ops.object.select_all(action='DESELECT')
for obj in collections["05"].objects: obj.select_set(True)
bpy.context.view_layer.objects.active=torso
for screen in bpy.data.screens:
    for ar in screen.areas:
        if ar.type=='VIEW_3D':
            ar.spaces.active.region_3d.view_perspective='CAMERA'
scene.render.filepath=os.path.join(OUT,"01_Gravity_Hall_Interior.png")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,"G-Blox_Gravity_Hall.blend"))
print(json.dumps({"scene":scene.name,"objects":len(scene.objects),"floor_studs":[W,D],"file":bpy.data.filepath}))
