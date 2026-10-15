import bpy,math,json,os
from mathutils import Vector,Matrix
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TruckModels'
assert 'To be rich - Trucks' not in bpy.data.scenes
scene=bpy.data.scenes.new('To be rich - Trucks');bpy.context.window.scene=scene
palette={'Rubber':[30,32,36],'Chassis':[45,51,58],'Metal':[154,166,178],'Glass':[51,76,91],'White':[224,227,227],'Interior':[186,192,196],'Wood':[157,122,83],'Red':[217,52,43],'Amber':[247,173,52],'Light':[242,237,203],'Dark':[68,76,85],'Stripe':[86,173,205],'Gold':[232,181,62]}
materials={}
def material(name,rgb):
    if name in materials:return materials[name]
    m=bpy.data.materials.new('Truck_'+name);m.use_nodes=True
    c=tuple(v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb)
    m.diffuse_color=(*c,1)
    n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');n.inputs['Base Color'].default_value=(*c,1);n.inputs['Roughness'].default_value=.72;n.inputs['Specular IOR Level'].default_value=.2
    materials[name]=m;return m
for k,v in palette.items():material(k,v)
models=[]
configs=[('Starter',7.6,15.4,7.8,[191,199,196],4),('Basic',8.2,18.5,9.1,[83,137,183],4),('Power',8.6,20,9.5,[74,143,91],4),('Super',9.1,23,10.1,[128,88,177],6),('Premium',9.4,25,10.4,[184,159,119],6),('Mythic',9.4,24,10.4,[230,181,65],6)]
def vec(v):return Vector((v[0],-v[2],v[1]))
mapping=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
for index,(name,w,length,height,paint,axles) in enumerate(configs):
    col=bpy.data.collections.new('Truck_'+name);scene.collection.children.link(col)
    offset=Vector(((index%3-1)*29,(index//3)*38,0))
    root=bpy.data.objects.new(name+'_Truck',None);col.objects.link(root);root.location=offset
    parts=[];objects=[];groups={};wheels=[]
    material(name+'Paint',paint)
    bodypaint=paint if name in ('Starter','Super','Premium','Mythic') else palette['White']
    material(name+'Cargo',bodypaint)
    def part(n,pos,size,color='Dark',kind='box',rot=None,group='Body',body=False):
        rgb=palette.get(color,paint if color=='Paint' else bodypaint)
        matkey=name+'Paint' if color=='Paint' else (name+'Cargo' if color=='Cargo' else color)
        r=Matrix.Identity(3)
        if rot:
            for axis,angle in zip('XYZ',rot):r=r@Matrix.Rotation(math.radians(angle),3,axis)
        if kind=='cylinder':
            vs=[];faces=[];nseg=20
            for x in (-size[0]/2,size[0]/2):
                vs.extend([(x,math.cos(i*2*math.pi/nseg)*size[1]/2,math.sin(i*2*math.pi/nseg)*size[2]/2) for i in range(nseg)])
            faces=[tuple(reversed(range(nseg))),tuple(range(nseg,nseg*2))]+[(i,(i+1)%nseg,(i+1)%nseg+nseg,i+nseg) for i in range(nseg)]
        else:
            vs=[tuple(sign[i]*size[i]/2 for i in range(3)) for sign in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
            faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        vertices=[vec(Vector(pos)+r@Vector(v))+offset for v in vs]
        mesh=bpy.data.meshes.new(name+'_'+n);mesh.from_pydata(vertices,[],faces);mesh.update()
        ob=bpy.data.objects.new(name+'_'+n,mesh);col.objects.link(ob);mesh.materials.append(materials[matkey]);ob['TruckPart']=n;ob['RigGroup']=group
        objects.append(ob)
        cf=[*pos,*[r[i][j] for i in range(3) for j in range(3)]]
        parts.append({'name':n,'cf':cf,'size':size,'rgb':rgb,'kind':kind,'group':group,'body':body,'material':'SmoothPlastic','collide':group=='Body' and kind!='cylinder'})
        return ob
    radius=1.08 if name=='Starter' else (1.18 if name=='Basic' else 1.30)
    rear=length/2-.25;front=-length/2+.2
    cablen=4.8 if name=='Starter' else 5.4
    cargofront=front+cablen+.22;cargorear=rear-.15;cargolen=cargorear-cargofront;cz=(cargofront+cargorear)/2
    floor=radius*2+.16
    cargoheight=height-floor-.25;innerw=w-.68
    part('Frame',(0,1.25,0),(w-.9,.42,length-1.2),'Chassis')
    part('CargoFloor',(0,floor-.12,cz),(w-.25,.24,cargolen),'Wood')
    part('CargoWallLeft',(-w/2+.12,floor+cargoheight/2,cz),(.24,cargoheight,cargolen),'Cargo',body=True)
    part('CargoWallRight',(w/2-.12,floor+cargoheight/2,cz),(.24,cargoheight,cargolen),'Cargo',body=True)
    part('CargoFront',(0,floor+cargoheight/2,cargofront+.12),(w-.48,cargoheight,.24),'Cargo',body=True)
    part('CargoRoof',(0,height-.12,cz),(w,.24,cargolen),'Cargo',body=True)
    for side in (-1,1):
        part('CargoRail'+str(side),(side*(w/2+.012),floor+.12,cz),(.055,.20,cargolen),'Metal')
        part('InteriorRail'+str(side),(side*(w/2-.27),floor+1.5,cz),(.06,.15,cargolen-.35),'Interior')
        part('SideStripe'+str(side),(side*(w/2+.025),floor+1.0,cz),(.025,.52,cargolen-.2),'Paint' if name in ('Basic','Power') else ('Stripe' if name=='Premium' else 'Dark'))
        for z in (cargofront+.25,cargorear-.25):part('CornerRail'+str(side)+str(z),(side*(w/2+.016),floor+cargoheight/2,z),(.045,cargoheight,.09),'Metal')
    cabincenter=front+cablen/2
    lowtop=3.9 if name=='Starter' else 4.35
    part('CabLower',(0,(1.65+lowtop)/2,cabincenter),(w-1.5,lowtop-1.65,cablen-.1),'Paint',body=True)
    wheelz=front+(2.25 if axles==4 else 2.45)
    arch=radius+.10
    for side in (-1,1):
        part('CabOverArch'+str(side),(side*(w/2-.28),(radius*2+.1+lowtop)/2,cabincenter),(.55,lowtop-radius*2-.1,cablen-.1),'Paint',body=True)
        for k,(za,zb) in enumerate([(front+.05,wheelz-arch),(wheelz+arch,cargofront-.27)]):
            if zb>za:part('CabArchEnd'+str(side)+str(k),(side*(w/2-.28),(1.65+radius*2+.1)/2,(za+zb)/2),(.55,radius*2+.1-1.65,zb-za),'Paint',body=True)
    cabtop=height-.65
    upperfront=front+(.85 if name=='Starter' else .28)
    upperback=cargofront-.25
    part('CabBack',(0,(lowtop+cabtop)/2,upperback-.13),(w-.45,cabtop-lowtop,.26),'Paint',body=True)
    part('CabRoof',(0,cabtop-.10,(upperfront+upperback)/2),(w-.25,.2,upperback-upperfront),'Paint',body=True)
    for side in (-1,1):
        x=side*(w/2-.25)
        part('CabSide'+str(side),(x,(lowtop+cabtop)/2,(upperfront+upperback)/2),(.2,cabtop-lowtop,upperback-upperfront),'Paint',body=True)
        part('SideWindow'+str(side),(x+side*.105,(lowtop+cabtop)/2+.10,(upperfront+upperback)/2-.10),(.025,cabtop-lowtop-.6,upperback-upperfront-.62),'Glass')
        part('DoorHandle'+str(side),(side*(w/2-.135),lowtop-.28,upperback-.60),(.10,.12,.62),'Dark')
        part('MirrorArm'+str(side),(side*(w/2+.18),lowtop+1.0,upperfront+.22),(.75,.11,.11),'Chassis')
        part('Mirror'+str(side),(side*(w/2+.55),lowtop+1.05,upperfront+.22),(.20,.9,.50),'Dark')
        part('MirrorGlass'+str(side),(side*(w/2+.66),lowtop+1.05,upperfront+.22),(.025,.70,.34),'Metal')
        part('CabStep'+str(side),(side*(w/2+.03),1.70,cabincenter+.20),(.45,.16,1.5),'Metal')
    part('WindshieldFrame',(0,(lowtop+cabtop)/2,upperfront+.07),(w-.45,cabtop-lowtop,.16),'Paint',body=True)
    part('Windshield',(0,(lowtop+cabtop)/2+.08,upperfront-.023),(w-.85,cabtop-lowtop-.55,.025),'Glass')
    part('WindshieldDivider',(0,(lowtop+cabtop)/2+.08,upperfront-.043),(.085,cabtop-lowtop-.5,.018),'Dark')
    for side in (-1,1):part('Wiper'+str(side),(side*w*.20,lowtop+.44,upperfront-.068),(w*.22,.065,.055),'Dark',rot=(0,0,side*9))
    part('Bumper',(0,1.9,front-.10),(w-.05,.5,.28),'Metal' if name in ('Basic','Mythic') else 'Dark')
    part('Grille',(0,2.9,front-.02),(w*.52,.77,.075),'Chassis')
    for i in (-1,0,1):part('GrilleBar'+str(i),(0,2.9+i*.23,front-.065),(w*.49,.055,.025),'Metal')
    for side in (-1,1):
        part('Headlamp'+str(side),(side*w*.36,2.9,front-.045),(w*.15,.50,.065),'Light')
        part('Indicator'+str(side),(side*w*.445,2.9,front-.085),(.15,.45,.035),'Amber')
    part('PlateFront',(0,2.05,front-.255),(1.0,.24,.025),'White')
    part('Visor',(0,cabtop-.26,upperfront-.18),(w-.35,.18,.38),'Paint',body=True)
    if name in ('Power','Super','Premium','Mythic'):
        part('RoofFairing',(0,cabtop+.10,upperback-.78),(w-.65,.40,1.35),'Paint',body=True)
        for x in (-w*.32,0,w*.32):part('RoofMarker'+str(x),(x,cabtop+.14,upperfront+.18),(.25,.09,.20),'Amber')
    if name=='Power':
        part('BullBar',(0,2.6,front-.34),(w-.55,.12,.13),'Metal')
        for x in (-w*.29,w*.29):part('BullBarPost'+str(x),(x,2.28,front-.34),(.13,.72,.13),'Metal')
    rearaxle=cargorear-2.35
    axle_z=[front+2.25,rearaxle] if axles==4 else [front+2.45,rearaxle-2.4,rearaxle]
    for ai,z in enumerate(axle_z):
        for side in (-1,1):
            key='Wheel'+('L' if side<0 else 'R')+str(ai+1)
            x=side*(w/2-.04);center=[x,radius,z]
            groups[key]={'pivot':center,'type':'wheel','radius':radius,'front':ai==0}
            wheels.append(groups[key]|{'name':key})
            part(key+'_Tyre',center,(.65,radius*2,radius*2),'Rubber','cylinder',group=key)
            outside=x+side*.345
            part(key+'_Rim',(outside,radius,z),(.065,radius*1.28,radius*1.28),'Metal','cylinder',group=key)
            part(key+'_Hub',(outside+side*.045,radius,z),(.04,radius*.35,radius*.35),'Dark','cylinder',group=key)
            for turn in (0,90):part(key+'_Spoke'+str(turn),(outside+side*.04,radius,z),(.025,radius*.97,.095),'Dark',rot=(turn,0,0),group=key)
            part('Mudflap'+key,(x,radius*.65,z+radius+.17),(.60,radius*.95,.09),'Rubber')
    doorheight=cargoheight-.10;doorz=cargorear+.02
    for side,key in [(-1,'DoorLeft'),(1,'DoorRight')]:
        hinge=[side*(w/2-.24),floor+doorheight/2,doorz]
        groups[key]={'pivot':hinge,'type':'door','openAngle':side*110}
        center=side*(w-.51)/4
        part(key,(center,floor+doorheight/2,doorz),((w-.55)/2,doorheight,.14),'Cargo',group=key,body=True)
        part(key+'_Lock',(side*.40,floor+doorheight*.53,doorz+.095),(.07,doorheight*.77,.07),'Metal',group=key)
        part(key+'_Handle',(side*.40,floor+doorheight*.48,doorz+.15),(.38,.09,.08),'Dark',group=key)
        part(key+'_Stripe',(center,floor+.35,doorz+.088),((w-.65)/2,.12,.025),'Red',group=key)
    part('RearBumper',(0,1.45,rear+.08),(w-.05,.25,.36),'Metal')
    for side in (-1,1):
        part('RearLight'+str(side),(side*w*.39,1.83,rear+.16),(.65,.33,.08),'Red')
        part('ReverseLight'+str(side),(side*w*.29,1.83,rear+.16),(.25,.33,.08),'Light')
    part('PlateRear',(0,1.83,rear+.17),(1.0,.25,.025),'White')
    bpy.context.view_layer.update()
    for ob in objects:ob.parent=root;ob.matrix_parent_inverse=root.matrix_world.inverted()
    models.append({'name':name,'width':w,'length':length,'height':height,'offset':list(offset),'parts':parts,'groups':groups,
        'cargo':{'center':[0,floor+cargoheight/2,cz],'size':[innerw,cargoheight-.22,cargolen-.45]},'rear':[0,floor+doorheight/2,doorz],
        'objects':objects,'radius':radius})
bpy.app.driver_namespace['truck_models']=models
with open(os.path.join(OUT,'truck_manifest.json'),'w') as f:json.dump([{k:v for k,v in m.items() if k!='objects'} for m in models],f,indent=2)
stage=bpy.data.collections.new('Truck Presentation');scene.collection.children.link(stage)
me=bpy.data.meshes.new('TruckGround');me.from_pydata([(-300,-300,-.02),(300,-300,-.02),(300,300,-.02),(-300,300,-.02)],[],[(0,1,2,3)])
ob=bpy.data.objects.new('TruckGround',me);stage.objects.link(ob);me.materials.append(material('Ground',[56,65,76]))
world=bpy.data.worlds.new('TruckWorld');world.use_nodes=True;n=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');n.inputs[0].default_value=(.23,.28,.36,1);n.inputs[1].default_value=.6;scene.world=world
for name,pos,power,size in [('Key',(-35,-40,65),26000,45),('Fill',(50,0,40),18000,35),('Rim',(0,65,65),28000,40)]:
    ld=bpy.data.lights.new('Truck_'+name,'AREA');ld.energy=power;ld.shape='DISK';ld.size=size;ob=bpy.data.objects.new('Truck_'+name,ld);stage.objects.link(ob);ob.location=pos;ob.rotation_euler=(Vector((0,15,3))-ob.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.cameras.new('TruckCamera');ob=bpy.data.objects.new('TruckCamera',cam);stage.objects.link(ob);ob.location=(78,110,72);ob.rotation_euler=(Vector((0,17,3))-ob.location).to_track_quat('-Z','Y').to_euler();cam.type='ORTHO';cam.ortho_scale=104;scene.camera=ob
scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=True;scene.render.resolution_x=1800;scene.render.resolution_y=1200;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
for scr in bpy.data.screens:
    for area in scr.areas:
        if area.type=='VIEW_3D':
            s=area.spaces.active;s.shading.type='MATERIAL';s.region_3d.view_location=(0,17,3);s.region_3d.view_distance=110;s.region_3d.view_rotation=ob.rotation_euler.to_quaternion();area.tag_redraw()
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print(json.dumps([{'name':m['name'],'parts':len(m['parts']),'moving_groups':len(m['groups'])} for m in models]))
