import bpy,math,json,os,bmesh
from mathutils import Vector,Matrix
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TownCentreModels'
scene_name='To be rich - Town Centre'
assert scene_name not in bpy.data.scenes
scene=bpy.data.scenes.new(scene_name);bpy.context.window.scene=scene
M={};records=[]
def v(p):return Vector((p[0],-p[2],p[1]))
def material(name,rgb,rough=.78,metal=0,alpha=1):
    ma=bpy.data.materials.new('Town_'+name);ma.use_nodes=True
    c=tuple(x/255/12.92 if x/255<=.04045 else ((x/255+.055)/1.055)**2.4 for x in rgb)
    ma.diffuse_color=(*c,alpha);node=next(n for n in ma.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value=(*c,1);node.inputs['Roughness'].default_value=rough;node.inputs['Metallic'].default_value=metal;node.inputs['Alpha'].default_value=alpha
    ma['RGB']=rgb;ma['Transparency']=1-alpha;M[name]=ma;return ma
for name,rgb in {'Stone':(222,218,205),'Floor':(198,195,182),'Roof':(180,184,181),'Brick':(156,92,71),'BrickLight':(176,110,83),'Mortar':(193,176,150),'Trim':(238,233,215),'Teal':(46,84,85),'Wood':(161,125,86),'Seat':(69,104,103),'Metal':(82,91,92),'Paper':(228,220,195),'Gold':(215,179,92),'Ground':(82,91,93),'Lamp':(246,240,210),'Green':(74,111,76)}.items():material(name,rgb)
material('Glass',(104,151,157),.30,.1,.30)
material('GiftPaint',(51,113,121),.35,.16);material('GiftCargo',(110,80,148),.48,.13);material('GiftGold',(220,178,76),.45,.22)
def emit(name,vs,fs,ma,group='Shell',collide=True):
    me=bpy.data.meshes.new(name);me.from_pydata([v(p)+offset for p in vs],[],fs);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
    ob=bpy.data.objects.new(tag+'__'+name,me);col.objects.link(ob);me.materials.append(M[ma] if isinstance(ma,str) else ma)
    ob['PartName']=name;ob['RigGroup']=group;ob['Solid']=collide;objects.append(ob);return ob
def box(name,p,s,ma,group='Shell',collide=True,rot=None):
    R=rot or Matrix.Identity(3);signs=[(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]
    vs=[Vector(p)+R@Vector(tuple(sign[i]*s[i]/2 for i in range(3))) for sign in signs]
    return emit(name,vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],ma,group,collide)
def cylinder(name,p,r,depth,ma,group='Interior',segments=16):
    vs=[(p[0]+r*math.cos(i*math.tau/segments),p[1]+dy,p[2]+r*math.sin(i*math.tau/segments)) for dy in [-depth/2,depth/2] for i in range(segments)]
    fs=[tuple(reversed(range(segments))),tuple(range(segments,2*segments))]+[(i,(i+1)%segments,(i+1)%segments+segments,i+segments) for i in range(segments)]
    return emit(name,vs,fs,ma,group,False)
def text(name,body,p,size,ma,normal=(0,0,1),group='Signs'):
    curve=bpy.data.curves.new(name,'FONT');curve.body=body;curve.size=size;curve.align_x='CENTER';curve.align_y='CENTER';curve.extrude=.006;curve.resolution_u=3
    ob=bpy.data.objects.new(tag+'__'+name,curve);col.objects.link(ob);ob.location=v(p)+offset
    n=v(normal).normalized();up=Vector((0,0,1));right=up.cross(n).normalized();ob.rotation_euler=Matrix((right,up,n)).transposed().to_euler();curve.materials.append(M[ma])
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH');ob.select_set(False)
    ob['PartName']=name;ob['RigGroup']=group;ob['Solid']=False;objects.append(ob);return ob
def marker(name,p):
    ob=bpy.data.objects.new(tag+'__'+name,None);col.objects.link(ob);ob.location=v(p)+offset;ob.empty_display_size=.5;ob['Marker']=name;markers[name]=list(p);return ob
def begin(name,off):
    global tag,col,offset,root,objects,markers
    tag=name;col=bpy.data.collections.new(name);scene.collection.children.link(col);offset=Vector(off);objects=[];markers={}
    root=bpy.data.objects.new(name,None);col.objects.link(root);root.location=offset
def finish(extra=None):
    bpy.context.view_layer.update()
    for ob in list(col.objects):
        if ob==root or ob.parent is not None:continue
        world=ob.matrix_world.copy();ob.parent=root;ob.matrix_world=world
    rec={'name':tag,'root':root,'objects':list(objects),'markers':dict(markers),'offset':list(offset)}
    if extra:rec.update(extra)
    records.append(rec);return rec
f=.8;walltop=13.1;front=12.7;wallth=.6
for damaged,off in [(False,(-36,0,0)),(True,(36,0,0))]:
    begin('TownCentre_Crashed' if damaged else 'TownCentre_Normal',off)
    box('Foundation',(0,.30,0),(38,.60,26),'Stone')
    box('Floor',(0,.70,0),(38,.20,26),'Floor','Floor')
    box('WallLeft',(-18.7,(f+walltop)/2,0),(.6,walltop-f,26),'Stone')
    box('WallRight',(18.7,(f+walltop)/2,0),(.6,walltop-f,26),'Stone')
    box('WallBack',(0,(f+walltop)/2,-12.7),(36.8,walltop-f,.6),'Stone')
    # Front wall is built around real openings, with no wall hidden behind the glass.
    for side in [-1,1]:
        if side==1 and damaged:continue
        ma='Stone' if side<0 else 'Brick'
        for a,b,label in [(4,7.5,'InnerPier'),(15.5,18.4,'OuterPier')]:box(label+str(side),(side*(a+b)/2,(f+walltop)/2,front),(b-a,walltop-f,.6),ma)
        box('WindowSillWall'+str(side),(side*11.5,(f+3.4)/2,front),(8,3.4-f,.6),ma)
        box('WindowHeader'+str(side),(side*11.5,(9.8+walltop)/2,front),(8,walltop-9.8,.6),ma)
        box('WindowGlass'+str(side),(side*11.5,6.6,front),(7.72,6.12,.055),'Glass','Glass',True)
        for x in [side*7.57,side*15.43]:box('WindowJamb'+str(x),(x,6.6,13.035),(.14,6.4,.13),'Teal','Trim')
        for y in [3.47,9.73]:box('WindowRail'+str(side)+str(y),(side*11.5,y,13.035),(7.72,.14,.13),'Teal','Trim')
        box('WindowMullion'+str(side),(side*11.5,6.6,13.035),(.11,6.1,.13),'Teal','Trim')
    box('EntryHeader',(0,11.70,front),(8,2.8,.6),'Stone')
    for side in [-1,1]:
        box('EntryJamb'+str(side),(side*4.0,5.55,13.05),(.16,9.5,.14),'Teal','Trim')
        hinge=Vector((side*3.87,f,13.10));rotation=Matrix.Rotation(math.radians(side*98),3,'Y')
        # Outward-open entrance doors, leaving a clear eight-stud route.
        center=hinge+rotation@Vector((-side*1.90,4.55,0))
        box('EntranceGlass'+str(side),center,(3.64,8.94,.055),'Glass','EntryDoors',True,rotation)
        for x in [-1.87,1.87]:box('EntranceDoorStile'+str(side)+str(x),center+rotation@Vector((x,0,0)),(.11,9.1,.10),'Teal','EntryDoors',True,rotation)
        for y in [-4.50,4.50]:box('EntranceDoorRail'+str(side)+str(y),center+rotation@Vector((0,y,0)),(3.64,.10,.10),'Teal','EntryDoors',True,rotation)
        box('EntrancePull'+str(side),center+rotation@Vector((-side*1.38,-.10,.15)),(.07,1.05,.09),'Metal','EntryDoors',False,rotation)
    box('EntryCanopy',(0,10.65,14.25),(10.3,.32,3.2),'Teal','Roof')
    box('TownNameFascia',(0,11.43,15.77),(10.3,1.23,.16),'Teal','Signs')
    text('TownCentreSign','TOWN CENTRE',(0,11.44,15.865),.92,'Trim')
    box('EntranceLanding',(0,.40,14.55),(8.2,.80,3.1),'Stone','Ground')
    # Gentle, uninterrupted ramp from the plaza to the interior floor.
    vs=[(-4.1,.8,16.1),(4.1,.8,16.1),(4.1,0,22.1),(-4.1,0,22.1),(-4.1,.64,16.1),(4.1,.64,16.1),(4.1,-.16,22.1),(-4.1,-.16,22.1)]
    emit('EntranceRamp',vs,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'Stone','Ground')
    # Roof panels leave a real opening beneath the raised daylight box.
    for x in [-13,13]:box('RoofWing'+str(x),(x,13.35,0),(14,.5,28),'Roof','Roof')
    box('RoofFront',(0,13.35,7),(12,.5,14),'Roof','Roof')
    box('RoofBack',(0,13.35,-12),(12,.5,4),'Roof','Roof')
    for z in [-14,14]:box('RoofFasciaZ'+str(z),(0,13.27,z),(40.24,.55,.16),'Teal','Roof')
    for x in [-20.04,20.04]:box('RoofFasciaX'+str(x),(x,13.27,0),(.16,.55,27.84),'Teal','Roof')
    for x in [-6,6]:box('ClerestorySide'+str(x),(x,14.67,-5),(.18,2.14,10),'Glass','Roof',True)
    for z in [-10,0]:box('ClerestoryEnd'+str(z),(0,14.67,z),(11.82,2.14,.18),'Glass','Roof',True)
    for x in [-6,0,6]:
        for z in [-10,0]:box('ClerestoryFrame'+str(x)+str(z),(x,14.67,z),(.16,2.20,.22),'Teal','Roof')
    box('RaisedRoof',(0,15.94,-5),(12.65,.40,10.65),'Stone','Roof')
    box('RaisedRoofEdge',(0,16.18,-5),(12.85,.08,10.85),'Teal','Roof')
    # Interior: a short reception desk, one bench and two future travel stations.
    box('ReceptionBase',(-12,2.17,-3.5),(6.8,2.74,2.6),'Teal','Interior')
    box('ReceptionTop',(-12,3.66,-3.5),(7.2,.24,3.0),'Wood','Interior')
    text('ReceptionSign','INFORMATION',(-12,2.42,-2.185),.47,'Trim')
    box('DeskLeaflet',(-13.5,3.805,-3.3),(1.1,.05,.78),'Paper','Interior',False)
    box('ReceptionChairSeat',(-12,2.32,-6.1),(2,.22,1.9),'Seat','Interior')
    box('ReceptionChairBack',(-12,3.38,-6.98),(2,1.90,.18),'Seat','Interior')
    cylinder('ReceptionChairStem',(-12,1.55,-6.1),.14,1.30,'Metal')
    cylinder('ReceptionChairBase',(-12,.88,-6.1),.85,.15,'Metal')
    box('WaitingBenchSeat',(15,2.28,1),(2.4,.25,7),'Wood','Interior')
    box('WaitingBenchBack',(16.1,3.31,1),(.20,1.81,7),'Seat','Interior')
    for z in [-1.3,3.3]:box('BenchSupport'+str(z),(15,1.50,z),(1.90,1.30,.24),'Teal','Interior')
    box('Noticeboard',(-18.30,6.8,4),(.15,3.7,5),'Teal','Interior',False)
    for z,y in [(2.8,7.1),(4.4,7.1),(4.0,5.85)]:box('Notice'+str(z),(-18.20,y,z),(.035,.82,1.12),'Paper','Interior',False)
    for x,label,colorkey in [(-5,'WAREHOUSE','Teal'),(5,'DEALERSHIP','Gold')]:
        box(label+'Pad',(x,.83,-9),(4.3,.06,4.3),colorkey,'TravelPads',False)
        box(label+'PadInset',(x,.866,-9),(3.85,.012,3.85),'Floor','TravelPads',False)
        box(label+'Board',(x,6.2,-12.355),(6,1.35,.08),colorkey,'Signs',False)
        text(label+'Label',label,(x,6.2,-12.30),.59,'Trim')
        marker(label.title()+'Teleport',(x,.90,-9))
    text('TravelHeading','TRAVEL',(0,9.3,-12.32),1.0,'Teal')
    for x in [-11.5,11.5]:
        for z in [-4.5,5.5]:box('CeilingLight'+str(x)+str(z),(x,13.04,z),(3,.08,1.4),'Lamp','Roof',False)
    box('EntryPlanter',(-14.5,.92,16.7),(3.8,1.44,2.2),'Teal','Exterior')
    box('EntryShrub',(-14.5,2.05,16.7),(3.35,1.05,1.76),'Green','Exterior',False)
    if damaged:
        # Small localised break beside the doorway, with the upper wall and roof intact.
        for a,b,name in [(4,6.2,'ImpactLeftPier'),(16.8,18.4,'ImpactRightPier')]:box(name,((a+b)/2,(f+walltop)/2,front),(b-a,walltop-f,.6),'Brick','Damage')
        box('ImpactUpperWall',(11.5,(9.8+walltop)/2,front),(10.6,walltop-9.8,.6),'Brick','Damage')
        for x in [6.85,16.15]:box('ImpactWindowShoulder'+str(x),(x,9.2,front),(1.3,1.2,.6),'Brick','Damage')
        box('RemainingWindowPane',(11.5,9.12,13.035),(7.6,1.02,.04),'Glass','Damage',False)
        box('RemainingWindowTop',(11.5,9.73,13.075),(7.75,.14,.13),'Teal','Damage',False)
        for i,(x,y,z,angle) in enumerate([(6.40,1.20,12.73,0),(6.39,3.1,12.75,-8),(6.50,6.7,12.78,7),(16.58,1.85,12.72,4),(16.57,5.25,12.77,-9),(7.3,8.45,12.78,-5),(15.45,8.41,12.8,8)]):
            box('LooseBrickEdge'+str(i),(x,y,z),(.78,.38,.56),'BrickLight' if i%2 else 'Brick','Damage',False,Matrix.Rotation(math.radians(angle),3,'Z'))
        for i,(x,z,angle) in enumerate([(6.2,15.1,22),(17.6,14.8,-18),(18.0,16.5,7),(6.5,17.2,-34)]):box('FallenBrick'+str(i),(x,.18,z),(.83,.36,.49),'BrickLight','Damage',False,Matrix.Rotation(math.radians(angle),3,'Y'))
        box('BentWindowRail',(16.65,7.7,13.17),(.13,2.02,.13),'Teal','Damage',False,Matrix.Rotation(math.radians(-12),3,'Z'))
    marker('MainEntrance',(0,f,13.6));marker('PlayerArrival',(0,f,6));marker('TruckImpact',(11.5,3.2,12.7))
    marker('GiftTruckRoot',(10.8,0,21.65));marker('GiftSpillOrigin',(9.83,2.52,30.84));marker('GiftScatterGround',(9.6,.06,33.0))
    finish({'kind':'building','floorTop':f,'sharedPivot':[0,0,0],'truckYaw':-6,'damage':damaged})
# Reuse the new truck's editable meshes, preserving the unrelated truck scene.
source_scene=bpy.data.scenes['To be rich - Trucks'];source_scene.frame_set(1)
bpy.context.window.scene=source_scene;bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
source_objects=[o for o in bpy.data.collections['Realistic Basic'].all_objects if o.type=='MESH' and 'PartName' in o]
source_data=[]
for ob in source_objects:
    mesh=bpy.data.meshes.new_from_object(ob.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps);mesh.transform(ob.matrix_world)
    source_data.append((ob.get('PartName'),ob.get('RigGroup','Body'),mesh,ob.data.materials[0]))
bpy.context.window.scene=scene
begin('GiftTruck_Crashed',(0,0,0))
with open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TruckModels\Realistic\realistic_manifest.json') as handle:truck_spec=next(m for m in json.load(handle) if m['name']=='Basic')
for name,group,mesh,ma in source_data:
    for vert in mesh.vertices:
        x,y,z=vert.co.x,vert.co.z,-vert.co.y
        if group=='Body' and z<-7.55 and 1.65<y<5.4 and abs(x)<3.85:
            crush=min(1,max(0,(-7.55-z)/1.5))*(.32+.18*math.sin(x*1.3))
            vert.co.y-=crush;vert.co.z+=crush*.15*math.sin(x)
    old=ma.name.split('RealTruck_')[-1].split('.')[0]
    replacement=M['GiftPaint'] if old=='BasicPaint' else M['GiftCargo'] if old=='BasicCargo' else ma
    mesh.materials.clear();mesh.materials.append(replacement)
    ob=bpy.data.objects.new(tag+'__'+name,mesh);col.objects.link(ob);ob['PartName']=name;ob['RigGroup']=group;ob['Solid']=False;objects.append(ob)
    if name=='MouldedBumper':
        pivot=v((0,1.91,-9.19));mesh.transform(Matrix.Translation(pivot)@Matrix.Rotation(math.radians(6),4,'Y')@Matrix.Translation(-pivot))
    if name=='UpperServicePanel':
        pivot=v((0,4.8,-8.95));mesh.transform(Matrix.Translation(pivot)@Matrix.Rotation(math.radians(-17),4,'X')@Matrix.Translation(-pivot))
    if name=='BrandBadge':ob.hide_render=True;ob.hide_viewport=True
# Restrained gift livery, no collectible parcel models included.
for side in [-1,1]:
    box('GiftRibbonSide'+str(side),(side*4.113,5.72,2.6),(.028,6.10,.52),'GiftGold','Body',False)
    text('GiftLivery'+str(side),'GIFT EXPRESS',(side*4.137,6.38,5.25),.64,'Trim',normal=(side,0,0),group='Body')
box('GiftRoofRibbon',(0,9.12,2.6),(8.2,.025,.52),'GiftGold','Body',False)
pivots={};bpy.context.view_layer.update()
for key,g in truck_spec['groups'].items():
    pivot=bpy.data.objects.new('GiftTruck__'+key+'_Pivot',None);col.objects.link(pivot);pivot.parent=root;pivot.location=v(g['pivot']);pivots[key]=pivot;pivot['RigType']=g['type']
bpy.context.view_layer.update()
for ob in objects:
    world=ob.matrix_world.copy();ob.parent=pivots.get(ob['RigGroup'],root);ob.matrix_world=world
for key,pivot in pivots.items():
    g=truck_spec['groups'][key]
    if g['type']=='door':pivot.rotation_euler.z=math.radians(g['openAngle'])
    elif g['front']:pivot.rotation_euler.z=math.radians(-10)
marker('GiftSpillOrigin',(0,2.52,9.35));marker('FrontImpact',(0,3,-8.5))
gift=finish({'kind':'truck','groups':truck_spec['groups'],'cargo':truck_spec['cargo'],'rear':truck_spec['rear'],'openDoors':True})
root.location=Vector((36,0,0))+v((10.8,0,21.65));root.rotation_euler.z=math.radians(-6)
gift['offset']=list(root.location);gift['placement']={'position':[10.8,0,21.65],'yaw':-6}
bpy.context.view_layer.update();bpy.app.driver_namespace['town_models']=records
stage=bpy.data.collections.new('Town Centre Presentation');scene.collection.children.link(stage)
me=bpy.data.meshes.new('TownDisplayGround');me.from_pydata([(-300,-300,-.19),(300,-300,-.19),(300,300,-.19),(-300,300,-.19)],[],[(0,1,2,3)])
ob=bpy.data.objects.new('TownDisplayGround',me);stage.objects.link(ob);me.materials.append(M['Ground'])
world=bpy.data.worlds.new('TownWorld');world.use_nodes=True;node=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');node.inputs[0].default_value=(.40,.46,.52,1);node.inputs[1].default_value=.65;scene.world=world
for name,power,pos,size in [('Key',60000,(-45,-55,70),45),('Fill',32000,(70,-20,50),40),('Rim',38000,(10,40,55),35)]:
    light=bpy.data.lights.new('Town_'+name,'AREA');light.energy=power;light.size=size;ob=bpy.data.objects.new('Town_'+name,light);stage.objects.link(ob);ob.location=pos;ob.rotation_euler=(Vector((0,-3,5))-ob.location).to_track_quat('-Z','Y').to_euler()
camera=bpy.data.cameras.new('TownComparisonCamera');ob=bpy.data.objects.new('TownComparisonCamera',camera);stage.objects.link(ob);ob.location=(88,-135,75);ob.rotation_euler=(Vector((0,-5,5))-ob.location).to_track_quat('-Z','Y').to_euler();camera.type='ORTHO';camera.ortho_scale=133;scene.camera=ob
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True;scene.render.resolution_x=2200;scene.render.resolution_y=1300;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
for scr in bpy.data.screens:
    for area in scr.areas:
        if area.type=='VIEW_3D':
            s=area.spaces.active;s.shading.type='MATERIAL';s.region_3d.view_location=(0,-5,5);s.region_3d.view_distance=145;s.region_3d.view_rotation=ob.rotation_euler.to_quaternion();s.region_3d.view_perspective='PERSP';area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print(json.dumps([{'name':m['name'],'parts':len(m['objects']),'markers':m['markers']} for m in records]))
