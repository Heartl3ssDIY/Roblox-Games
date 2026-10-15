from common import *
from districts import _roof
def curbed_route(name,a,b,w):
    path_strip(name+' dark foundation',a,b,w+2.2,'stoneDark',1.14)
    path_strip(name+' paving',a,b,w,'stoneLight',1.28)
    av=Vector(a);bv=Vector(b);d=(bv-av).normalized();side=Vector((d.y,-d.x))
    for e in (-1,1):
        aa=av+side*e*(w/2+.3);bb=bv+side*e*(w/2+.3)
        path_strip(name+' raised curb',aa,bb,.62,'stone',1.48)
        path_strip(name+' narrow gold guide',av+side*e*(w/2-1),bv+side*e*(w/2-1),.12,'gold',1.39)
    L=(bv-av).length
    for j in range(int(L/4)):
        p=av+d*(j*4+2)
        ob=box('Avenue limestone joint',(p.x,p.y,1.381),(w-.8,.07,.022),'stoneDark','51_OuterRoads')
        ob.rotation_euler.z=-math.atan2(d.x,d.y)
    for j in range(int(L/16)):
        p=av+d*(j*16+6)
        ob=box('Avenue centre diamond',(p.x,p.y,1.41),(1.2,1.2,.03),'gold','51_OuterRoads');ob.rotation_euler.z=pi/4
def grand_gate(cx,cy,w=43,h=30):
    G='52_GrandArrival'
    for x in (-w*.41,w*.41):
        bx=cx+x
        box('Gate stepped granite shoe',(bx,cy,2),(5.8,6,1.5),'stoneDark',G,bevel=.22)
        box('Gate chamfered base',(bx,cy,3.2),(4.8,5.1,1),'stoneLight',G,bevel=.15)
        cylinder('Vermilion great pillar',(bx,cy,h/2+2),1.5,h-2,'red',G,vertices=24)
        for z in (4,8,h-3,h):
            ring('Gate engraved collar',(bx,cy,z),1.7,1.47,.36,'gold',G,segments=32)
        for z in (h-5,h-2):
            box('Gate bracket', (bx,cy,z),(5.2,4.3,.75),'wood',G,bevel=.14)
        for sx in (-1,1):
            box('Gate gold post inset',(bx+sx*1.45,cy-.5,h/2),( .08,.8,h-11),'gold',G)
    box('Great gate tie beam',(cx,cy,h-5),(w+4,2.1,1.4),'wood',G,bevel=.12)
    box('Great gate vermilion lintel',(cx,cy,h),(w+7,3.7,2.3),'red',G,bevel=.18)
    _roof('Great gate roof',(cx,cy,h+1.5),w+16,14,5,G,uplift=2.3)
    # Deeply recessed crest mount supports the original ACU logo.
    box('Crest sign mount',(cx,cy-2.05,h-4),(15,.65,7.4),'purple',G,bevel=.2)
    for x in (-7.8,7.8):box('Crest gold frame',(cx+x,cy-2.43,h-4),(.2,.15,8),'gold',G,bevel=.03)
    for z in (h,h-8):box('Crest gold frame',(cx,cy-2.43,z),(15.8,.15,.2),'gold',G,bevel=.03)
    # Reuse exact logo texture and UVs from the imported source.
    mat=bpy.data.materials.get('ACU_Logo_Texture')
    ob=mesh('ACU gate original brand',[ (cx-7,cy-2.5,h-8),(cx+7,cy-2.5,h-8),(cx+7,cy-2.5,h),(cx-7,cy-2.5,h)],[(0,1,2,3)],'gold',G)
    ob.data.materials[0]=mat
    for i,uv in enumerate(((0,0),(1,0),(1,1),(0,1))):ob.data.uv_layers.active.data[i].uv=uv
def build():
    random.seed(9226)
    G='50_ExpandedLand'
    n=160;rr=[]
    for i in range(n):
        a=2*pi*i/n;rr.append(274+12*sin(3*a)+8*sin(7*a)+random.uniform(-3,3))
    verts=[]
    for layer,(scale,z) in enumerate(((1,1), (1.005,-5),(.98,-19),(.89,-43),(.62,-74),(.12,-115))):
        for i in range(n):
            a=2*pi*i/n;r=rr[i]*scale;verts.append((r*cos(a),r*sin(a),z+random.uniform(-2,2)*(layer>0)))
    faces=[]
    for j in range(5):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n;faces.extend([(a,b,b+n),(a,b+n,a+n)])
    ob=mesh('Expanded citadel | ancient island cliffs',verts,faces,'rock',G)
    for k in ('stoneDark','stone','moss'):ob.data.materials.append(MATS[k])
    for p in ob.data.polygons:p.material_index=random.choices([0,1,2,3],[.44,.3,.22,.04])[0]
    mesh('Expanded island top',[(rr[i]*cos(2*pi*i/n),rr[i]*sin(2*pi*i/n),1.0) for i in range(n)],[tuple(range(n))],'moss',G)
    # The original compact hub is now the civic centre of a larger town.
    for ob in list(collection('15_Rim').objects):
        p=ob.location
        if ob.type=='MESH':
            center=ob.matrix_world@sum((Vector(v) for v in ob.bound_box),Vector())/8
            a=math.atan2(center.y,center.x)
            if min(abs(math.atan2(sin(a-k*pi/4),cos(a-k*pi/4))) for k in range(8))<.11:
                bpy.data.objects.remove(ob,do_unlink=True)
    ring('Town inner circular boulevard',(0,0,1.16),135,124,.26,'stone','51_OuterRoads',segments=192)
    for r in (124,135):ring('Boulevard chamfered curb',(0,0,1.4),r+.3,r-.3,.32,'stoneLight','51_OuterRoads',segments=192)
    for a in range(0,360,3):
        t=math.radians(a);ob=box('Boulevard cut stones',(129.5*cos(t),129.5*sin(t),1.315),(10.8,.09,.018),'stoneDark','51_OuterRoads');ob.rotation_euler.z=t
    routes=[('Arrival boulevard',(0,-280),(0,-110),24),
            ('Citadel north road',(0,104),(0,244),20),
            ('Academy road',(-98,31),(-197,70),16),
            ('Water garden walk',(-81,-79),(-185,-125),14),
            ('Market avenue',(76,-76),(190,-157),18),
            ('Pagoda boulevard',(80,81),(170,169),17),
            ('Eastern forest trail',(108,10),(243,10),12)]
    for name,a,b,w in routes:curbed_route(name,a,b,w)
    grand_gate(0,-236,43,30)
    # Arcaded garden walls lead visitors into the main civic centre.
    for s in (-1,1):
        for i in range(5):
            x=s*(24+i*15);y=-197+3*sin(i)
            box('Avenue boundary wall',(x,y,4.7),(15,1.4,7),'ivory','53_OuterWalls',bevel=.13)
            box('Avenue wall stone footing',(x,y,1.5),(15,2.1,.8),'stoneDark','53_OuterWalls',bevel=.08)
            _roof('Boundary wall tile cap',(x,y,8.1),16,3.1,.9,'53_OuterWalls',uplift=.18)
            for edge in (-7.5,7.5):
                box('Boundary red pilaster',(x+edge,y,4.9),(.9,2,7.5),'red','53_OuterWalls',bevel=.07)
            # Latticed ornamental windows.
            box('Recessed wall window',(x,y-.75,5),(6,.16,3),'wood','53_OuterWalls')
            for dx in (-2,-1,0,1,2):box('Window gold lattice',(x+dx,y-.86,5),(.1,.08,2.9),'gold','53_OuterWalls')
            for z in (4,5,6):box('Window lattice rail',(x,y-.86,z),(5.9,.08,.1),'gold','53_OuterWalls')
    # Approach terraces and commemorative water basins.
    for s in (-1,1):
        x=s*35;y=-163
        cylinder('Arrival reflecting basin',(x,y,1.7),10,.9,'stoneDark','54_OuterFurnishings',vertices=64)
        cylinder('Still reflection water',(x,y,2.17),9.2,.05,'water','54_OuterFurnishings',vertices=64)
        ring('Reflecting basin stone coping',(x,y,2.15),10.1,9.15,.4,'stoneLight','54_OuterFurnishings',segments=64)
        cylinder('Arrival obelisk base',(x,y,2.7),2.6,1.1,'gold','54_OuterFurnishings',vertices=8)
        ico('Arrival hovering crystal',(x,y,7.8),(1.6,1.6,4.3),'purple','54_OuterFurnishings',1)
        ring('Crystal energy orbit',(x,y,6.5),3.6,3.5,.11,'purpleGlow','54_OuterFurnishings',segments=64)
    # Sculpted cliff teeth prevent a clean cylindrical toy edge.
    for i in range(95):
        a=2*pi*i/95;r=274+12*sin(3*a)+8*sin(7*a);z=random.uniform(-20,2)
        ob=ico('Stratified outer cliff mass',(r*cos(a),r*sin(a),z),(random.uniform(7,15),random.uniform(6,12),random.uniform(7,22)),'rock' if i%3 else 'stoneDark',G,2)
        ob.rotation_euler.z=a
        if i%3==0:
            ob=ico('Cliff grassy cap',(r*cos(a),r*sin(a),z+9),(8,6,1.2),'moss',G,2);ob.rotation_euler.z=a
    # Frequent landmarks and bench pockets make long streets readable.
    for s in (-1,1):
        for y in range(-217,-114,17):
            x=s*16.4;g='54_OuterFurnishings'
            box('Avenue lamp granite pedestal',(x,y,1.8),(2.3,2.3,1.4),'stoneDark',g,bevel=.18)
            cylinder('Avenue lamp fluted post',(x,y,5.9),.4,7,'red',g,vertices=12)
            ring('Avenue lamp gold shoulder',(x,y,8.4),.7,.35,.35,'gold',g,segments=16)
            box('Avenue lamp luminous paper',(x,y,9.4),(1.5,1.5,2),'goldGlow',g,bevel=.15)
            _roof('Avenue lantern canopy',(x,y,10.6),3.1,3.1,1,g,uplift=.25)
            for dx in (-.82,.82):
                for dy in (-.82,.82):box('Lamp corner frame',(x+dx,y+dy,9.5),(.12,.12,2.1),'wood',g)
            if y%2:point_light('Avenue warm lamp',(x,y,9.4),(1,.45,.18),65,1.3)
    marker('NewPlayerArrival',(0,-260,2.8),'PlayerSpawn')
    marker('TownFastTravel',(0,-141,2),'LobbyWayfinder')
    marker('AcademyFastTravel',(-142,50,2),'TrainingDistrict')
    marker('OuterGardenFastTravel',(-144,-106,2),'GardenDistrict')
    marker('MarketFastTravel',(126,-112,2),'MarketDistrict')
    marker('NorthernSanctumFastTravel',(0,201,2),'SanctumDistrict')
    marker('CharacterDisplay_Main',(0,0,6.5),'ReservedRobloxCharacter')

