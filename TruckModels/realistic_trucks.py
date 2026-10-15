import bpy, math, json, os, bmesh
from mathutils import Vector, Matrix
from mathutils.geometry import tessellate_polygon
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TruckModels\Realistic'
os.makedirs(OUT,exist_ok=True)
with open(os.path.join(os.path.dirname(OUT),'truck_manifest.json')) as f:specs=json.load(f)
old=bpy.data.scenes.get('To be rich - Trucks')
if old:old.name='To be rich - Trucks - Previous'
scene=bpy.data.scenes.new('To be rich - Trucks');bpy.context.window.scene=scene
materials={};models=[]
def mat(name,rgb,rough=.48,metal=0):
    if name in materials:return materials[name]
    m=bpy.data.materials.new('RealTruck_'+name);m.use_nodes=True
    c=tuple(v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb)
    m.diffuse_color=(*c,1)
    n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    n.inputs['Base Color'].default_value=(*c,1);n.inputs['Roughness'].default_value=rough;n.inputs['Metallic'].default_value=metal
    m['RGB']=rgb;m['Roughness']=rough;m['Metallic']=metal
    materials[name]=m;return m
mat('Tyre',(25,27,28),.85);mat('Rubber',(36,39,42),.72)
mat('Chassis',(47,52,55),.65,.2);mat('Grille',(16,20,23),.6)
mat('Steel',(158,166,169),.32,.78);mat('DarkSteel',(83,92,100),.42,.65)
mat('Chrome',(204,212,216),.19,.9);mat('Glass',(34,54,65),.12,.38)
mat('Mirror',(163,181,190),.08,.95);mat('Lens',(195,213,216),.17,.3)
mat('WhiteLight',(241,243,221),.2,.25);mat('Red',(167,24,21),.29,.15)
mat('Amber',(230,123,20),.26,.18);mat('Plate',(215,218,215),.55)
mat('Interior',(64,69,74),.84);mat('Seat',(40,43,46),.93)
mat('Wood',(146,114,77),.8);mat('CargoInside',(192,197,197),.65)
mat('Stripe',(86,173,205),.38,.2)
def vec(p):return Vector((p[0],-p[2],p[1]))
def emit(name,vs,fs,material,group='Body',body=False,bevel=0,smooth=False):
    me=bpy.data.meshes.new(tier+'_'+name);me.from_pydata([vec(v)+offset for v in vs],[],fs);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
    direction=None
    if name in ['PressedCabFace','CurvedWindscreen']:direction=Vector((0,1,0))
    elif name=='AerodynamicRoofDeflector' or name.startswith('RearWheelCover'):direction=Vector((0,0,1))
    elif name.startswith(('SideGlass','DeflectorSide')):direction=Vector((-1 if '-1' in name else 1,0,0))
    if direction is not None:bmesh.ops.reverse_faces(bm,faces=[f for f in bm.faces if f.normal.dot(direction)<0])
    bm.to_mesh(me);bm.free()
    ob=bpy.data.objects.new(tier+'_'+name,me);col.objects.link(ob);me.materials.append(materials[material]);ob['RigGroup']=group;ob['IsBody']=body;ob['PartName']=name
    if smooth:
        for p in me.polygons:p.use_smooth=True
    if bevel:
        mod=ob.modifiers.new('Manufactured edge','BEVEL');mod.width=bevel;mod.segments=3;mod.limit_method='ANGLE'
        mod=ob.modifiers.new('Surface normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=40
    objects.append(ob);return ob
def box(name,p,s,ma,bevel=.025,group='Body',body=False,rot=None):
    r=rot or Matrix.Identity(3)
    signs=[(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]
    vs=[Vector(p)+r@Vector(tuple(sign[i]*s[i]/2 for i in range(3))) for sign in signs]
    return emit(name,vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],ma,group,body,bevel)
def rod(name,a,b,r,ma,group='Body',sides=12):
    a,b=Vector(a),Vector(b);v=(b-a).normalized();u=v.cross(Vector((0,1,0)))
    if u.length<.01:u=v.cross(Vector((1,0,0)))
    u.normalize();t=v.cross(u);vs=[p+r*(u*math.cos(i*math.tau/sides)+t*math.sin(i*math.tau/sides)) for p in [a,b] for i in range(sides)]
    fs=[tuple(reversed(range(sides))),tuple(range(sides,sides*2))]+[(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
    return emit(name,vs,fs,ma,group,smooth=True)
def tube(name,points,r,ma,group='Body'):
    vs=[];fs=[];points=[Vector(p) for p in points];sides=8
    for j,p in enumerate(points):
        d=(points[min(j+1,len(points)-1)]-points[max(0,j-1)]).normalized();u=d.cross(Vector((0,1,0)))
        if u.length<.01:u=d.cross(Vector((1,0,0)))
        u.normalize();v=d.cross(u)
        vs.extend([p+r*(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides)) for i in range(sides)])
        if j:
            for i in range(sides):fs.append(((j-1)*sides+i,(j-1)*sides+(i+1)%sides,j*sides+(i+1)%sides,j*sides+i))
    return emit(name,vs,fs,ma,group,smooth=True)
def prism(name,poly,x0,x1,ma,bevel=.035,body=False):
    # A concave side panel with a real wheel opening.
    n=len(poly);vs=[(x,y,z) for x in [x0,x1] for y,z in poly]
    loop=[Vector((0,y,z)) for y,z in poly];tris=tessellate_polygon([loop]);fs=[]
    for tri in tris:
        ids=[p if isinstance(p,int) else min(range(n),key=lambda i:(loop[i]-p).length) for p in tri]
        fs.extend([tuple(reversed(ids)),tuple(i+n for i in ids)])
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return emit(name,vs,fs,ma,body=body,bevel=bevel)
def surface(name,rows,ma,body=False,bevel=0):
    n=len(rows[0]);vs=[p for row in rows for p in row];fs=[]
    for j in range(len(rows)-1):
        for i in range(n-1):fs.append((j*n+i,j*n+i+1,(j+1)*n+i+1,(j+1)*n+i))
    return emit(name,vs,fs,ma,body=body,bevel=bevel,smooth=True)
def lathe(name,center,profile,ma,group,segments=48):
    vs=[];fs=[]
    for x,r in profile:
        vs.extend([(center[0]+x,center[1]+r*math.cos(i*math.tau/segments),center[2]+r*math.sin(i*math.tau/segments)) for i in range(segments)])
    for j in range(len(profile)-1):
        for i in range(segments):fs.append((j*segments+i,j*segments+(i+1)%segments,(j+1)*segments+(i+1)%segments,(j+1)*segments+i))
    return emit(name,vs,fs,ma,group,smooth=True)
def label(name,text,p,size,ma,rotation,group='Body'):
    curve=bpy.data.curves.new(name,'FONT');curve.body=text;curve.size=size;curve.extrude=.001;curve.align_x='CENTER';curve.resolution_u=3
    ob=bpy.data.objects.new(tier+'_'+name,curve);col.objects.link(ob);ob.location=vec(p)+offset;ob.rotation_euler=rotation;curve.materials.append(materials[ma])
    bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.convert(target='MESH');ob.select_set(False)
    ob['RigGroup']=group;ob['IsBody']=False;ob['PartName']=name;objects.append(ob);return ob
for index,m in enumerate(specs):
    tier=m['name'];w=m['width'];length=m['length'];h=m['height'];r=m['radius'];objects=[]
    paint=next(p['rgb'] for p in m['parts'] if p['name']=='CabLower')
    cargo=next(p['rgb'] for p in m['parts'] if p['name']=='CargoRoof')
    mat(tier+'Paint',paint,.31,.2);mat(tier+'Cargo',cargo,.43,.16)
    col=bpy.data.collections.new('Realistic '+tier);scene.collection.children.link(col)
    offset=Vector(m['offset']);root=bpy.data.objects.new(tier+'_RealTruck',None);col.objects.link(root);root.location=offset
    front=-length/2+.2;rear=length/2-.4;cablen=4.8 if tier=='Starter' else 5.4
    back=front+cablen-.03;cf=front+cablen+.22;cz=(cf+rear)/2;cl=rear-cf;floor=r*2+.16
    cw=w*.90;hw=cw/2;cabtop=h*(.81 if tier=='Starter' else .78);sill=cabtop*.68
    for g in m['groups'].values():
        if g['type']=='wheel':g['pivot'][0]=(-1 if g['pivot'][0]<0 else 1)*(hw-.24 if g['front'] else w/2-.37)
    wheelz=m['groups']['WheelL1']['pivot'][2];arch=r+.105
    for side in [-1,1]:
        box('ChassisRail'+str(side),(side*(w*.29),1.40,0),(.19,.46,length-1.0),'Chassis')
    for z in [front+1,0,rear-1]:box('Crossmember'+str(z),(0,1.42,z),(w*.60,.23,.20),'Chassis')
    box('CargoDeck',(0,floor-.12,cz),(w-.25,.24,cl),'Wood',.025)
    for i in range(1,9):box('FloorSeam'+str(i),(-w/2+i*w/9,floor+.001,cz),(.014,.012,cl-.1),'DarkSteel',0)
    for side in [-1,1]:
        box('CargoWall'+str(side),(side*(w/2-.10),(h+floor)/2,cz),(.20,h-floor-.16,cl),tier+'Cargo',.045,body=True)
        box('CargoLining'+str(side),(side*(w/2-.205),(h+floor)/2,cz),(.018,h-floor-.30,cl-.10),'CargoInside',.003)
        for y in [floor+.10,h-.13]:box('BoxExtrusion'+str(side)+str(y),(side*(w/2+.01),y,cz),(.10,.16,cl+.04),'Steel',.018)
        for z in [cf+.06,rear-.04]:box('CornerExtrusion'+str(side)+str(z),(side*(w/2+.015),(h+floor)/2,z),(.07,h-floor,.10),'Steel',.015)
        box('CargoStripe'+str(side),(side*(w/2+.014),floor+.5,cz),(.025,.28,cl-.24),tier+'Paint' if tier in ['Basic','Power'] else ('Stripe' if tier=='Premium' else 'DarkSteel'),.008)
        for z in [cf+.45,cz,rear-.45]:
            box('SideMarkerBase'+str(side)+str(z),(side*(w/2+.02),floor-.07,z),(.1,.19,.38),'Rubber',.035)
            box('SideMarkerLens'+str(side)+str(z),(side*(w/2+.08),floor-.07,z),(.045,.12,.28),'Amber',.025)
        box('CargoTieRail'+str(side),(side*(w/2-.235),floor+1.6,cz),(.04,.15,cl-.5),'Steel',.009)
        for z in [cf+1,cz,rear-1]:
            box('TieRailSlot'+str(side)+str(z),(side*(w/2-.26),floor+1.6,z),(.015,.075,.27),'Grille',.014)
    box('CargoRoof',(0,h-.10,cz),(w,.20,cl),tier+'Cargo',.05,body=True)
    box('CargoFront',(0,(floor+h)/2,cf+.10),(w-.4,h-floor-.2,.20),tier+'Cargo',.035,body=True)
    box('CabFloor',(0,2.85,(front+back)/2),(cw-.12,.15,cablen-.3),'Interior',.03)
    box('CabBack',(0,(2.8+cabtop)/2,back-.10),(cw-.15,cabtop-2.8,.20),tier+'Paint',.12,body=True)
    # Rounded, slightly tapered cab face; the windscreen is a separate curved surface.
    def face(x,y):
        lean=.52*max(0,(y-sill)/(cabtop-sill))
        return (x,y,front+lean+.28*(abs(x)/hw)**4)
    rows=[]
    for y in [1.96,2.15,2.75,sill-.40,sill]:
        half=hw-(.13 if y<2.2 else 0)
        rows.append([face(half*(-1+2*i/20),y) for i in range(21)])
    surface('PressedCabFace',rows,tier+'Paint',True)
    low=sill+.12;high=cabtop-.24;whalf=hw-.24
    rows=[[face(whalf*(-1+2*i/24),low+(high-low)*j/5) for i in range(25)] for j in range(6)]
    surface('CurvedWindscreen',rows,'Glass')
    perimeter=[face(whalf*(-1+2*i/24),low) for i in range(25)]+[face(whalf,low+(high-low)*j/5) for j in range(1,6)]+[face(whalf*(1-2*i/24),high) for i in range(1,25)]+[face(-whalf,high-(high-low)*j/5) for j in range(1,6)]
    tube('WindscreenSeal',perimeter+[perimeter[0]],.045,'Rubber')
    box('CabRoof',(0,cabtop-.01,(front+.52+back)/2),(cw-.08,.19,back-front-.43),tier+'Paint',.14,body=True)
    # Actual wheel-arch openings in the lower cab panels.
    for side in [-1,1]:
        arc=[(r+arch*math.sin(t),wheelz+arch*math.cos(t)) for t in [i*math.pi/24 for i in range(25)]]
        poly=[(1.65,front+.24),(sill,front+.18),(sill,back-.04),(1.65,back-.04),(r,wheelz+arch)]+arc+[(1.65,front+.24)]
        prism('CabDoorLower'+str(side),poly,side*(hw-.10),side*(hw+.02),tier+'Paint',.045,True)
        pts=[(side*(hw+.065),r+(arch+.025)*math.sin(t),wheelz+(arch+.025)*math.cos(t)) for t in [i*math.pi/32 for i in range(33)]]
        tube('WheelArchTrim'+str(side),pts,.10,'Rubber')
        # Windscreen pillars, rear pillar, sill and shaped side glass.
        topz=front+.52+.28
        tube('APillar'+str(side),[(side*(hw-.02),sill,front+.28),(side*(hw-.07),cabtop-.04,topz)],.095,tier+'Paint')
        box('BPillar'+str(side),(side*(hw-.015),(sill+cabtop)/2,back-.22),(.16,cabtop-sill,.26),tier+'Paint',.055,body=True)
        p=[(side*(hw+.024),sill+.10,front+.27),(side*(hw+.024),sill+.10,back-.39),(side*(hw-.04),cabtop-.22,back-.39),(side*(hw-.04),cabtop-.22,topz+.17)]
        emit('SideGlass'+str(side),p,[(0,1,2,3)],'Glass')
        tube('SideGlassSeal'+str(side),p+[p[0]],.037,'Rubber')
        tube('WindowDivider'+str(side),[(side*(hw+.03),sill+.11,front+1.25),(side*(hw-.035),cabtop-.22,front+1.25)],.03,'Rubber')
        tube('CabDoorSeam'+str(side),[(side*(hw+.037),sill,back-.32),(side*(hw+.037),2.1,back-.32),(side*(hw+.037),2.1,wheelz+arch+.15)],.013,'Grille')
        box('HandlePocket'+str(side),(side*(hw+.031),sill-.27,back-.60),(.042,.23,.58),'Rubber',.07)
        box('DoorHandle'+str(side),(side*(hw+.073),sill-.245,back-.60),(.055,.075,.38),'DarkSteel',.03)
        stepz=back-.48
        for y in [1.55,2.03]:
            box('Step'+str(side)+str(y),(side*(hw+.06),y,stepz),(.46,.13,.87),'DarkSteel',.04)
            for j in range(5):box('StepGrip'+str(side)+str(y)+str(j),(side*(hw+.075),y+.076,stepz-.3+j*.15),(.34,.023,.06),'Grille',.008)
        mx=side*(hw+.63);my=(sill+cabtop)/2-.05;mz=front+.24
        tube('MirrorArm'+str(side),[(side*hw,my-.42,mz+.18),(mx,my-.48,mz+.16),(mx,my+.52,mz+.16),(side*hw,my+.58,mz+.24)],.045,'DarkSteel')
        box('MirrorHousing'+str(side),(mx,my,mz),(.33,1.18,.48),'Rubber',.14)
        box('MirrorGlass'+str(side),(mx,my+.08,mz+.249),(.24,.82,.022),'Mirror',.07)
        box('ConvexMirror'+str(side),(mx,my-.43,mz+.25),(.23,.17,.025),'Mirror',.045)
        box('SeatBase'+str(side),(side*cw*.27,3.04,back-1.05),(1.05,.28,1.1),'Seat',.12)
        box('SeatBack'+str(side),(side*cw*.27,3.75,back-.60),(1.05,1.36,.30),'Seat',.16,rot=Matrix.Rotation(math.radians(-8),3,'X'))
        box('Headrest'+str(side),(side*cw*.27,4.49,back-.63),(.61,.35,.23),'Seat',.10)
    box('Dashboard',(0,sill-.16,front+.77),(cw-.32,.36,.83),'Interior',.14)
    # UK driving position, with a visible steering wheel and column.
    rod('SteeringColumn',(cw*.26,3.2,front+1.45),(cw*.26,sill-.05,front+1.32),.07,'Rubber')
    steer=[(cw*.26+.38*math.cos(i*math.tau/32),sill+.04+.14*math.sin(i*math.tau/32),front+1.28+.32*math.sin(i*math.tau/32)) for i in range(33)]
    tube('SteeringWheel',steer,.04,'Rubber')
    for sx in [-1,1]:
        a=face(sx*hw*.56,low+.025);b=face(sx*hw*.38,low+.16);c=face(sx*hw*.19,low+.20)
        tube('WiperArm'+str(sx),[(a[0],a[1],a[2]-.06),(b[0],b[1],b[2]-.07)],.021,'Rubber')
        rod('WiperBlade'+str(sx),(c[0]-.50,c[1],c[2]-.07),(c[0]+.50,c[1],c[2]-.07),.027,'Rubber')
    grilley=3.03 if tier=='Starter' else 3.40;grillew=cw*(.58 if tier in ['Super','Premium','Mythic'] else .53)
    box('GrilleRecess',(0,grilley,front-.035),(grillew,1.34,.16),'Grille',.13)
    for j in range(6 if index>2 else 5):
        yy=grilley-.50+j*.20
        box('GrilleSlat'+str(j),(0,yy,front-.14),(grillew-.17,.06,.08),'Chrome' if tier=='Mythic' else 'DarkSteel',.025)
    box('UpperServicePanel',(0,sill-.29,front+.005),(cw*.69,.40,.10),tier+'Paint',.10,body=True)
    label('BrandBadge','ATLAS',(0,sill-.30,front-.061),.16,'Chrome',(math.pi/2,0,math.pi))
    box('MouldedBumper',(0,1.91,front-.14),(cw+.10,.58,.52),'DarkSteel' if index<3 else tier+'Paint',.18,body=index>=3)
    box('LowerAirIntake',(0,1.88,front-.408),(cw*.40,.22,.018),'Grille',.065)
    for side in [-1,1]:
        x=side*(hw-.51)
        box('LampHousing'+str(side),(x,2.65,front+.01),(.86,.77,.23),'Grille',.15)
        box('LampReflector'+str(side),(x,2.68,front-.117),(.71,.53,.04),'Chrome',.11)
        for shift in [-.18,.18]:
            rod('Projector'+str(side)+str(shift),(x+shift,2.70,front-.13),(x+shift,2.70,front-.18),.145,'Lens',sides=24)
            rod('ProjectorCore'+str(side)+str(shift),(x+shift,2.70,front-.18),(x+shift,2.70,front-.19),.092,'WhiteLight',sides=24)
        box('Indicator'+str(side),(x,2.43,front-.132),(.61,.11,.045),'Amber',.035)
        if index>=3:box('DaylightStrip'+str(side),(x,3.035,front-.105),(.65,.065,.05),'WhiteLight',.03)
        rod('FogLamp'+str(side),(side*cw*.37,1.93,front-.405),(side*cw*.37,1.93,front-.43),.13,'Lens',sides=24)
    box('FrontPlate',(0,2.28,front-.425),(1.12,.25,.035),'Plate',.026)
    label('FrontPlateText','TBR  '+str(index+1).zfill(3),(0,2.25,front-.446),.14,'Grille',(math.pi/2,0,math.pi))
    if index>=1:
        rows=[]
        for j in range(13):
            t=j/12;y=cabtop+.10+(h-.38-cabtop)*math.sin(t*math.pi/2);z=front+1.3+(back-.10-front-1.3)*t;half=hw-.30+.12*t
            rows.append([(half*(-1+2*i/20),y-.16*(abs(-1+2*i/20)**4),z+.10*(abs(-1+2*i/20)**4)) for i in range(21)])
        fairing=surface('AerodynamicRoofDeflector',rows,tier+'Paint',True)
        mod=fairing.modifiers.new('Fairing thickness','SOLIDIFY');mod.thickness=.05
        for side in [-1,1]:
            top=[row[0 if side<0 else -1] for row in rows];low=[(p[0],cabtop-.03,p[2]) for p in top]
            surface('DeflectorSide'+str(side),[low,top],tier+'Paint',True)
    if tier=='Power':
        tube('ProtectionBar',[(-hw+.18,2.12,front-.50),(-hw+.18,3.24,front-.50),(hw-.18,3.24,front-.50),(hw-.18,2.12,front-.50)],.065,'DarkSteel')
    # Chassis equipment, suspension and side guards.
    for side in [-1,1]:
        tankz=(cf+wheelz+3.0)/2
        box('FuelTank'+str(side),(side*(hw-.35),1.65,cf+1.10),(.89,.88,1.65),'Steel' if side==-1 else 'Chassis',.16)
        for z in [cf+.55,cf+1.65]:box('TankStrap'+str(side)+str(z),(side*(hw+.105),1.66,z),(.03,.77,.07),'DarkSteel',.01)
        if length>20:
            for y in [1.14,1.58]:box('SideGuard'+str(side)+str(y),(side*(w/2-.16),y,cz-.35),(.13,.15,cl*.37),'Steel',.03)
    axle_centers=sorted(set(g['pivot'][2] for g in m['groups'].values() if g['type']=='wheel'))
    for z in axle_centers:
        rod('Axle'+str(z),(-w*.42,r,z),(w*.42,r,z),.14,'Chassis')
        box('Differential'+str(z),(0,r,z),(.64,.50,.58),'Chassis',.20)
        for side in [-1,1]:
            for layer in range(3):box('LeafSpring'+str(side)+str(z)+str(layer),(side*w*.28,r+.27+layer*.045,z),(.20,.035,1.4-layer*.18),'DarkSteel',.01)
    for key,g in m['groups'].items():
        if g['type']!='wheel':continue
        c=g['pivot'];side=-1 if c[0]<0 else 1
        profile=[(-.32,.63),(-.36,.73),(-.355,.87),(-.30,.965),(-.24,.994),(-.18,1),(-.14,1),(-.125,.973),(-.11,1),(-.04,1),(-.025,.974),(-.01,1),(.06,1),(.075,.974),(.09,1),(.16,1),(.18,.987),(.24,.994),(.30,.965),(.355,.87),(.36,.73),(.32,.63)]
        lathe(key+'_Tyre',c,[(x*r,rr*r) for x,rr in profile],'Tyre',key,64)
        # The narrow transverse sipes sit within the tyre surface.
        vs=[];fs=[]
        for j in range(48):
            ang=j*math.tau/48
            for band in [-.20,-.07,.055,.19]:
                a=ang+(band*.17);base=len(vs)
                for x,theta in [(band-.026,a-.010),(band+.026,a+.012),(band+.026,a+.023),(band-.026,a+.001)]:vs.append((c[0]+x*r,c[1]+r*1.001*math.cos(theta),c[2]+r*1.001*math.sin(theta)))
                fs.append(tuple(range(base,base+4)))
        emit(key+'_TreadSipes',vs,fs,'Grille',key)
        for x in [-.345,.345]:lathe(key+'_SidewallRib'+str(x),c,[(x*r,.74*r),((x+(.006 if x>0 else -.006))*r,.76*r),(x*r,.78*r)],'Rubber',key,64)
        # Dished eight-hole commercial steel wheel, with actual open ventilation holes.
        xx=c[0]+side*r*.338
        lathe(key+'_RimLip',c,[(side*r*x,r*rr) for x,rr in [(.29,.63),(.33,.66),(.37,.665),(.39,.635),(.37,.60),(.26,.575)]],'Chrome' if tier=='Mythic' else 'Steel',key,48)
        vs=[];fs=[];segments=8;nn=24
        for k in range(segments):
            mid=k*math.tau/segments;center=Vector((.43*r*math.cos(mid),.43*r*math.sin(mid)));base=len(vs)
            outer=[];hole=[]
            for i in range(nn):
                t=i*math.tau/nn;direction=Vector((math.cos(t),math.sin(t)))
                # Intersect a ray from the hole centre with the wedge boundaries.
                candidates=[]
                for rr in [.22*r,.60*r]:
                    b=2*center.dot(direction);cc=center.length_squared-rr*rr;disc=b*b-4*cc
                    if disc>=0:
                        candidates += [v for v in [(-b+math.sqrt(disc))/2,(-b-math.sqrt(disc))/2] if v>1e-6]
                for theta in [mid-math.pi/segments,mid+math.pi/segments]:
                    normal=Vector((-math.sin(theta),math.cos(theta)));den=direction.dot(normal)
                    if abs(den)>1e-8:
                        dist=-center.dot(normal)/den
                        if dist>1e-6:candidates.append(dist)
                q=center+direction*min(candidates);hole.append(center+direction*.093*r);outer.append(q)
            for depth in [0,-side*.065*r]:
                for ring in [outer,hole]:vs.extend([(xx+depth,c[1]+p[0],c[2]+p[1]) for p in ring])
            for i in range(nn):
                a=base+i;b=base+(i+1)%nn
                fs.extend([(a,b,b+nn,a+nn),(a+2*nn,a+3*nn,b+3*nn,b+2*nn),(a+nn,b+nn,b+3*nn,a+3*nn)])
        emit(key+'_VentilatedRim',vs,fs,'Steel',key,bevel=.006)
        lathe(key+'_Hub',c,[(side*r*x,r*rr) for x,rr in [(.22,0),(.22,.23),(.37,.23),(.43,.17),(.43,0)]],'DarkSteel',key,32)
        for j in range(8):
            a=j*math.tau/8;y=c[1]+r*.265*math.cos(a);z=c[2]+r*.265*math.sin(a)
            rod(key+'_Lug'+str(j),(xx,y,z),(xx+side*.065,y,z),r*.036,'Chrome',key,6)
        rod(key+'_Valve',(xx,c[1]+r*.53,c[2]),(xx+side*.06,c[1]+r*.53,c[2]),.021,'Rubber',key,8)
        box('Mudflap'+key,(c[0],r*.69,c[2]+r+.17),(.69,r*.95,.075),'Rubber',.025)
        if not g['front']:
            pts=[(c[0],r+(r+.09)*math.sin(t),c[2]+(r+.09)*math.cos(t)) for t in [i*math.pi/24 for i in range(25)]]
            # Wide pressed wheel cover, above the tyre and below the cargo floor.
            rows=[[(p[0]+x,p[1],p[2]) for p in pts] for x in [-.38,.38]]
            surface('RearWheelCover'+key,rows,'Rubber')
    # Rear doors remain entirely in their hinge groups.
    dh=h-floor-.35;doorz=rear+.02
    for side,key in [(-1,'DoorLeft'),(1,'DoorRight')]:
        center=side*(w-.55)/4;dw=(w-.60)/2
        box(key+'_Seal',(center,floor+dh/2,doorz),(dw+.07,dh+.065,.14),'Rubber',.035,key)
        box(key+'_Panel',(center,floor+dh/2,doorz+.01),(dw,dh,.17),tier+'Cargo',.035,key,True)
        for x in [center-dw/2+.06,center+dw/2-.06]:box(key+'_Edge'+str(x),(x,floor+dh/2,doorz+.105),(.09,dh-.04,.045),'Steel',.009,key)
        for y in [floor+.07,floor+dh-.07]:box(key+'_EdgeY'+str(y),(center,y,doorz+.105),(dw,.10,.045),'Steel',.012,key)
        lockx=side*.42
        rod(key+'_LockRod',(lockx,floor+.23,doorz+.17),(lockx,floor+dh-.20,doorz+.17),.044,'Steel',key)
        for y in [floor+.30,floor+dh/2,floor+dh-.28]:box(key+'_RodBracket'+str(y),(lockx,y,doorz+.13),(.20,.12,.14),'Steel',.025,key)
        box(key+'_LatchPlate',(lockx,floor+dh*.48,doorz+.14),(.29,.31,.045),'DarkSteel',.022,key)
        box(key+'_LatchHandle',(lockx+side*.20,floor+dh*.48,doorz+.23),(.43,.065,.095),'Steel',.03,key)
        for y in [floor+.65,floor+dh*.5,floor+dh-.65]:
            hinge=side*(w/2-.23)
            box(key+'_HingeStrap'+str(y),(hinge-side*.27,y,doorz+.15),(.62,.17,.08),'Steel',.02,key)
            rod(key+'_HingeBarrel'+str(y),(hinge,y-.15,doorz+.16),(hinge,y+.15,doorz+.16),.075,'Steel',key,16)
        box(key+'_ReflectiveTape',(center,floor+.36,doorz+.109),(dw-.14,.105,.018),'Red',.008,key)
    box('RearCrossmember',(0,1.86,rear+.12),(w-.22,.61,.27),'Chassis',.07)
    box('UnderrideGuard',(0,1.19,rear+.24),(w-.10,.23,.31),'Steel',.05)
    for side in [-1,1]:
        box('GuardBracket'+str(side),(side*w*.31,1.50,rear+.05),(.13,.62,.18),'Chassis',.025)
        x=side*w*.35
        box('RearLampHousing'+str(side),(x,1.92,rear+.278),(1.27,.43,.10),'Rubber',.09)
        for i,ma in enumerate(['Amber','Red','Lens']):box('RearLamp'+str(side)+str(i),(x+side*(i-1)*.36,1.92,rear+.34),(.31,.30,.035),ma,.055)
        for y in [floor+.22,h-.3]:box('RearMarker'+str(side)+str(y),(side*(w/2-.22),y,rear+.13),(.15,.14,.06),'Red',.025)
    box('RearPlate',(0,1.92,rear+.282),(1.13,.26,.025),'Plate',.02)
    label('RearPlateText','TBR  '+str(index+1).zfill(3),(0,1.89,rear+.30),.14,'Grille',(math.pi/2,0,0))
    pivots={}
    bpy.context.view_layer.update()
    for key,g in m['groups'].items():
        pivot=bpy.data.objects.new(tier+'_'+key+'_Rig',None);col.objects.link(pivot);pivot.parent=root;pivot.location=vec(g['pivot']);pivot.empty_display_size=.25;pivots[key]=pivot
        pivot['RigType']=g['type']
    bpy.context.view_layer.update()
    for ob in objects:
        world=ob.matrix_world.copy();ob.parent=pivots.get(ob['RigGroup'],root);ob.matrix_world=world
    for key,pivot in pivots.items():
        g=m['groups'][key]
        if g['type']=='door':
            for frame,f in [(1,0),(40,1),(70,1),(95,0),(160,0)]:pivot.rotation_euler.z=math.radians(g['openAngle'])*f;pivot.keyframe_insert(data_path='rotation_euler',frame=frame)
        else:
            for frame,d in [(1,0),(95,0),(160,24)]:pivot.rotation_euler.x=-d/g['radius'];pivot.keyframe_insert(data_path='rotation_euler',frame=frame)
    for frame,d in [(1,0),(95,0),(160,24)]:root.location=offset+Vector((0,d,0));root.keyframe_insert(data_path='location',frame=frame)
    models.append({'spec':m,'objects':objects,'root':root,'pivots':pivots})
    print(tier,len(objects),flush=True)
scene.frame_end=160;scene.frame_set(1);bpy.context.view_layer.update()
bpy.app.driver_namespace['real_trucks']=models
stage=bpy.data.collections.new('Realistic Truck Presentation');scene.collection.children.link(stage)
mat('Ground',(72,78,85),.9)
me=bpy.data.meshes.new('RealTruckGround');me.from_pydata([(-300,-300,-.03),(300,-300,-.03),(300,300,-.03),(-300,300,-.03)],[],[(0,1,2,3)])
ob=bpy.data.objects.new('RealTruckGround',me);stage.objects.link(ob);me.materials.append(materials['Ground'])
world=bpy.data.worlds.new('RealTruckWorld');world.use_nodes=True;n=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');n.inputs[0].default_value=(.32,.37,.43,1);n.inputs[1].default_value=.55;scene.world=world
for name,power,pos,size in [('Key',50000,(-35,65,70),45),('Fill',24000,(55,45,50),35),('Rim',45000,(0,-35,55),40)]:
    ld=bpy.data.lights.new('RealTruck_'+name,'AREA');ld.energy=power;ld.size=size;ob=bpy.data.objects.new('RealTruck_'+name,ld);stage.objects.link(ob);ob.location=pos;ob.rotation_euler=(Vector((0,18,3))-ob.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.cameras.new('RealTruckCamera');ob=bpy.data.objects.new('RealTruckCamera',cam);stage.objects.link(ob);ob.location=(76,116,64);ob.rotation_euler=(Vector((0,17,3))-ob.location).to_track_quat('-Z','Y').to_euler();cam.type='ORTHO';cam.ortho_scale=102;scene.camera=ob
scene.render.engine='CYCLES';scene.cycles.samples=64;scene.cycles.use_denoising=True;scene.render.resolution_x=2100;scene.render.resolution_y=1400;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
for scr in bpy.data.screens:
    for area in scr.areas:
        if area.type=='VIEW_3D':
            s=area.spaces.active;s.shading.type='MATERIAL';s.region_3d.view_location=(0,17,3);s.region_3d.view_distance=108;s.region_3d.view_rotation=ob.rotation_euler.to_quaternion();area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print('Realistic trucks saved in '+bpy.data.filepath)
