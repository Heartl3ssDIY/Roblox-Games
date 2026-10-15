# Continued in the build_cat namespace.
def hatrow(t):
    x=-.27*t*t+.04*sin(pi*t*1.5)
    y=.045*t
    z=6.12+1.85*t
    rx=.515+.105*sin(pi*t*.90)+.045*t
    return x,y,z,rx,rx*.88

for j in range(5):
    a=j/5;b=(j+1)/5
    rows=[]
    for k in range(7):
        t=a+(b-a)*k/6
        rows.append(hatrow(t))
    o=loft('Hat_Band_'+str(j+1)+('_Red' if j%2==0 else '_White'),rows,red if j%2==0 else hatwhite,'03 Hat','Head',n=48)
    # Uneven horizontal ring edges give a softly worn cloth crown.
    for v in o.data.vertices:
        a=math.atan2(v.co.y,v.co.x+.1)
        v.co.z+=.026*sin(a*2+.2)+.012*sin(a*5)

# A broad and slightly upturned white brim, with visible thickness.
vs=[];fs=[];n=64
for ring in range(5):
    for i in range(n):
        a=2*pi*i/n
        radii=[(.29,.25),(.57,.50),(.84,.68),(.91,.735),(.89,.715)]
        rx,ry=radii[ring]
        z=[6.105,6.092,6.11,6.15,6.087][ring]+.035*cos(a*2+.2)+.012*sin(a*3)
        vs.append((rx*cos(a),ry*sin(a),z))
for r in range(4):
    for k in range(n):
        a=r*n+k;b=r*n+(k+1)%n
        fs.append((a,b,b+n,a+n))
fs += [tuple(range(n-1,-1,-1)),tuple(4*n+k for k in range(n))]
mesh('Hat_Brim_White',vs,fs,hatwhite,'03 Hat','Head')
rim=[]
for i in range(33):
    a=2*pi*i/32
    rim.append((.903*cos(a),.727*sin(a),6.125+.035*cos(a*2+.2)+.012*sin(a*3)))
tube('Hat_Brim_RolledEdge',rim,[.022]*33,hatwhite,'03 Hat','Head',n=8,steps=2)

# Broad, pinched fabric loops: separate loops, knot and hanging ribbons.
for s,side in [(1,'Left'),(-1,'Right')]:
    outline=[(s*.12,-.465,4.56),(s*.35,-.435,4.66),(s*.63,-.385,4.78),(s*.70,-.375,4.72),(s*.68,-.43,4.49),(s*.63,-.44,4.27),(s*.55,-.45,4.245),(s*.33,-.485,4.34),(s*.12,-.51,4.44)]
    loop=solid_panel('Bow_'+side+'Loop',outline,bowred,'04 Bow tie','UpperTorso',depth=.065,bulge=.10)
    bpy.context.view_layer.objects.active=loop
    mod=loop.modifiers.new('Soft cloth','SUBSURF');mod.levels=2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    folds=[]
    for j in [-1,1]:
        folds.append(tube('Bow fold',[(s*.15,-.574,4.49),(s*.34,-.546,4.50+j*.043),(s*.54,-.487,4.50+j*.12)],[.013,.018,.002],bowred,'04 Bow tie','UpperTorso',n=8,steps=4,aspect=.65))
    join_group([loop]+folds,'Bow_'+side+'Loop')
uvball('Bow_CenterKnot',(0,-.515,4.51),(.165,.12,.14),bowred,'04 Bow tie','UpperTorso',seg=24,rings=16)
for s,side in [(1,'Left'),(-1,'Right')]:
    o=solid_panel('Bow_'+side+'Ribbon',[(s*.035,-.46,4.48),(s*.145,-.47,4.40),(s*.19,-.48,4.12),(s*.30,-.47,3.91),(s*.18,-.49,3.84),(s*.065,-.50,3.92),(s*.02,-.50,4.14)],bowred,'04 Bow tie','UpperTorso',depth=.045,bulge=.035)
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Ribbon softness','SUBSURF');mod.levels=2
    bpy.ops.object.modifier_apply(modifier=mod.name)

# Neutral presentation setup; excluded from all mesh exports.
studio=bpy.data.collections.new('Presentation - excluded from exports')
scene.collection.children.link(studio)
def studio_object(o):
    for c in list(o.users_collection):c.objects.unlink(o)
    studio.objects.link(o)
    return o
groundmat=mat('Preview - warm grey',(.16,.175,.19),.86)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.022))
floor=studio_object(bpy.context.object);floor.name='Preview ground';floor.data.materials.append(groundmat)

def aim(o,point):o.rotation_euler=(Vector(point)-o.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,energy,size,color):
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size;data.color=color
    o=bpy.data.objects.new(name,data);studio.objects.link(o);o.location=loc;aim(o,(0,0,4))
    return o
area('Key softbox',(-4,-6,10),1500,5,(1,.92,.84))
area('Fill softbox',(5,-4,6),1150,4,(.79,.88,1))
area('Fur rim',(2,4,8),1800,3,(1,.90,.77))
area('Face lift',(0,-6,4.8),160,2,(1,1,1))
camdata=bpy.data.cameras.new('Cat preview camera')
camera=bpy.data.objects.new('Cat preview camera',camdata);studio.objects.link(camera)
camera.location=(9,-22,9.5);aim(camera,(0,0,4.0));camdata.type='ORTHO';camdata.ortho_scale=9.15
scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x=1200;scene.render.resolution_y=1300;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.world.use_nodes=True
scene.world.node_tree.nodes.get('Background').inputs[0].default_value=(.22,.25,.30,1)
scene.world.node_tree.nodes.get('Background').inputs[1].default_value=.45
scene.view_settings.view_transform='AgX'
scene.render.film_transparent=False
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=.28

# Clean useful view when opening the .blend.
for area_ in bpy.context.screen.areas:
    if area_.type=='VIEW_3D':
        area_.spaces.active.region_3d.view_rotation=camera.rotation_euler.to_quaternion()
        area_.spaces.active.region_3d.view_distance=12
        area_.spaces.active.region_3d.view_location=(0,0,4)
        area_.spaces.active.shading.type='MATERIAL'
        area_.spaces.active.overlay.show_floor=False
        area_.spaces.active.overlay.show_extras=False
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'CatInTheHat_Base.blend'))
scene.render.filepath=os.path.join(OUT,'CatInTheHat_ThreeQuarter.png')
print('CAT_STAGE_ACCESSORIES complete: '+str(len(list(root.all_objects)))+' meshes; saved .blend')
