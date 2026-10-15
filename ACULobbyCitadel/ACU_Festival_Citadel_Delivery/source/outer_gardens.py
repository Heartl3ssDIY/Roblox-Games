from common import *
from gardens import PetalMesh, ellipse_disk, bench, lantern, lantern_string, fern, bamboo_cluster
from garden_polish import blossom_mass


def strata_rock(name, center, size, group, rng, moss=True):
    x,y,z=center;rx,ry,h=size
    n=9
    verts=[]
    phase=rng.random()*pi
    for level,(height,rs) in enumerate([(-.5,.79),(-.29,1.02),(.13,.92),(.36,1),(.5,.82)]):
        for i in range(n):
            a=2*pi*i/n+phase
            mod=1+rng.uniform(-.13,.13)
            verts.append((x+rx*rs*mod*cos(a),y+ry*rs*mod*sin(a),z+h*height+rng.uniform(-.035,.035)*h))
    faces=[tuple(reversed(range(n)))]
    for level in range(4):
        for i in range(n):
            j=(i+1)%n
            faces.append((level*n+i,level*n+j,(level+1)*n+j,(level+1)*n+i))
    faces.append(tuple(range(4*n,5*n)))
    mesh(name,verts,faces,'rock',group)
    if moss:
        topverts=[(a,b,c+.09) for a,b,c in verts[4*n:]]
        mesh(name+'_MossCrown',topverts,[tuple(range(n))],'moss',group)
    # Separate long fine ledges read as sedimentary strata at player height.
    for band in [-.26,.15]:
        points=[]
        for i in range(n+1):
            a=2*pi*i/n+phase
            points.append((x+rx*.97*cos(a),y+ry*.97*sin(a),z+h*band+.12*sin(i*2.4)))
        tube(name+'_Stratum',points,[.1]*len(points),'stoneDark',group,sides=4)


def mature_sakura(name, center, height, spread, group, rng, green=False):
    x,y,z=center
    trunk=[(x,y,z),(x-.05*height,y+.02*height,z+height*.25),(x+.015*height,y-.025*height,z+height*.5),(x+.035*height,y,z+height*.75)]
    tube(name+'_OldTwistedTrunk',trunk,[height*.07,height*.047,height*.035,.18],'wood',group,sides=10)
    for i in range(7):
        a=i*2*pi/7+.3
        tube(name+'_ButtressRoot',[(x,y,z+2.2),(x+cos(a)*2.3,y+sin(a)*2.3,z+.6),(x+cos(a)*4.5,y+sin(a)*4.5,z+.1)],[.72,.5,.03],'wood',group,sides=6)
    masses=[]
    for i in range(7):
        a=i*2*pi/7+rng.uniform(-.19,.19)
        r=spread*rng.uniform(.48,.76)
        tip=Vector((x+cos(a)*r,y+sin(a)*r,z+height*rng.uniform(.68,.92)))
        mid=Vector((x+cos(a)*r*.4,y+sin(a)*r*.4,z+height*.57))
        tube(name+'_ArticulatedBough_%02d'%i,[(x,y,z+height*.4),mid,tip],[height*.034,height*.022,.045],'wood',group,sides=8)
        for side in [-1,1]:
            c=tip+Vector((cos(a+side*.7)*spread*.16,sin(a+side*.7)*spread*.16,height*.04))
            tube(name+'_CanopyTwig',[mid,tip,c],[.2,.12,.015],'wood',group,sides=5)
            masses.append((c,(spread*.34,spread*.3,height*.09)))
        masses.append((tip-Vector((cos(a)*spread*.1,sin(a)*spread*.1,-height*.035)),(spread*.32,spread*.27,height*.095)))
    masses.append((Vector((x,y,z+height*.89)),(spread*.39,spread*.33,height*.105)))
    petals=PetalMesh(name+'_BlossomEdges',group)
    for i,(c,s) in enumerate(masses):
        blossom_mass(name+'_SculptedCrown_%02d'%i,c,s,group,rng,hero=False,foliage=green)
        for j in range(10):
            a=rng.random()*2*pi
            p=c+Vector((s[0]*cos(a),s[1]*sin(a),rng.uniform(-.4,.7)*s[2]))
            petals.lens(p,.65,.35,.13,a,.2,('leafLight' if j%3 else 'leaf') if green else ('blossomLight' if j%3 else 'blossom'))
    petals.finish()


def cedar(name, center, height, width, group, rng):
    x,y,z=center
    leanx=rng.uniform(-1.4,1.4);leany=rng.uniform(-1,1)
    tube(name+'_Trunk',[(x,y,z),(x+leanx*.4,y+leany*.4,z+height*.5),(x+leanx,y+leany,z+height)],[width*.085,width*.055,.055],'wood',group,sides=8)
    for i in range(5):
        a=i*2*pi/5
        tube(name+'_Root',[(x,y,z+1),(x+cos(a)*width*.28,y+sin(a)*width*.28,z+.1)],[.65,.055],'wood',group,sides=5)
    allverts=[];darkfaces=[];lightfaces=[]
    for level in range(8):
        t=level/8
        zz=z+height*(.24+t*.72)
        radius=width*(1-t*.82)*rng.uniform(.9,1.1)
        arms=9 if level<5 else 7
        for arm in range(arms):
            a=arm*2*pi/arms+level*.65
            root=Vector((x+leanx*t,y+leany*t,zz+height*.047))
            direction=Vector((cos(a),sin(a),0));side=Vector((-sin(a),cos(a),0))
            end=root+direction*radius+Vector((0,0,-height*.045))
            if level%2==0:
                tube(name+'_Branch', [root,end],[.1,.025],'wood',group,sides=4)
            base=len(allverts)
            # A layered fan has a serrated hanging edge and an upper central ridge.
            outline=[(0,-.08,.3),(.37,-.32,.08),(.68,-.27,-.05),(.83,-.38,-.08),(1,-.04,.06),(.8,.35,-.1),(.64,.27,-.03),(.34,.33,.11),(0,.09,.3)]
            for u,v,w in outline:
                q=root+direction*(u*radius)+side*(v*radius)+Vector((0,0,w*radius*.45))
                allverts.append(tuple(q))
            ridge=root+direction*(radius*.45)+Vector((0,0,radius*.19))
            allverts.append(tuple(ridge))
            allverts.append(tuple(root+direction*(radius*.45)-Vector((0,0,radius*.13))))
            for k in range(9):
                (lightfaces if (k+arm+level)%4==0 else darkfaces).append((base+k,base+(k+1)%9,base+9))
                darkfaces.append((base+(k+1)%9,base+k,base+10))
    mesh(name+'_LayeredNeedleFans',allverts,darkfaces,'leaf',group)
    mesh(name+'_SunlitNeedleFans',allverts,lightfaces,'leafLight',group)


def curving_walk(name, points, width, group, material='stoneLight'):
    vertices=[]
    for i,p in enumerate(points):
        q=Vector(p)
        prev=Vector(points[max(0,i-1)]);nxt=Vector(points[min(len(points)-1,i+1)])
        d=(nxt-prev).normalized();side=Vector((-d.y,d.x,0))*width/2
        vertices.extend([tuple(q+side),tuple(q-side)])
    faces=[]
    for i in range(len(points)-1):faces.append((i*2,i*2+1,i*2+3,i*2+2))
    mesh(name+'_Paving',vertices,faces,material,group)
    for side in [0,1]:
        tube(name+'_Curb',[vertices[2*i+side] for i in range(len(points))],[.18]*len(points),'stoneDark',group,sides=5)
    for i in range(1,len(points)-1,2):
        tube(name+'_PaverJoint',[vertices[2*i],vertices[2*i+1]],[.035,.035],'stoneDark',group,sides=4)


def arch_bridge(name, start, end, width, rise, group):
    a,b=Vector(start),Vector(end);direction=b-a;side=Vector((-direction.y,direction.x,0)).normalized()
    length=direction.length
    def pos(t,offset=0):
        p=a.lerp(b,t)+side*offset;p.z+=sin(pi*t)*rise;return p
    segments=max(20,int(length/.9))
    for i in range(segments):
        t=(i+.5)/segments;p=pos(t)
        ob=box(name+'_Deck_%02d'%i,p,(width,length/segments-.035,.24),'wood',group,bevel=.035)
        ob.rotation_euler.z=-math.atan2(direction.x,direction.y)
    for sign in [-1,1]:
        rail=[pos(i/40,sign*(width/2+.12))+Vector((0,0,2.8)) for i in range(41)]
        tube(name+'_RedCurvedRailing',rail,[.2]*len(rail),'red',group,sides=8)
        tube(name+'_GoldenRailing',[p+Vector((0,0,.2)) for p in rail],[.055]*len(rail),'gold',group,sides=5)
        lower=[pos(i/40,sign*(width/2-.15))-Vector((0,0,.3)) for i in range(41)]
        tube(name+'_LoadBearingArch',lower,[.37]*len(lower),'red',group,sides=8)
        for i in range(12):
            p=pos(i/11,sign*(width/2+.12))
            cylinder(name+'_Baluster',p+Vector((0,0,1.32)),.17,2.9,'red',group,vertices=8)
            cylinder(name+'_PostCap',p+Vector((0,0,2.85)),.3,.18,'gold',group,vertices=8)
    marker(name+'_WalkSurface',tuple(pos(.5)+Vector((0,0,.3))),'scenic_bridge')


def tea_pavilion(center, group):
    x,y,z=center
    cylinder('TeaShrine_IslandPlinth',(x,y,z),10.7,.65,'stoneDark',group,vertices=48)
    cylinder('TeaShrine_TatamiFloor',(x,y,z+.48),9.7,.32,'wood',group,vertices=48)
    for i in range(6):
        a=i*pi/3+pi/6;xx=x+8.1*cos(a);yy=y+8.1*sin(a)
        cylinder('TeaShrine_CarvedRedColumn',(xx,yy,z+6.4),.47,11.8,'red',group,vertices=12)
        cylinder('TeaShrine_ColumnBase',(xx,yy,z+1.1),.7,.75,'stoneLight',group,vertices=12)
        cylinder('TeaShrine_ColumnCapital',(xx,yy,z+11.5),.85,.8,'gold',group,vertices=12)
        q=(x+8.1*cos(a+pi/3),y+8.1*sin(a+pi/3),z+11.4)
        tube('TeaShrine_ConnectingBeam',[(xx,yy,z+11.4),q],[.4,.4],'wood',group,sides=4)
        for side in [-1,1]:
            d=Vector((cos(a+side*pi/2),sin(a+side*pi/2),0))
            tube('TeaShrine_CurvedBracket',[(xx,yy,z+9.7),Vector((xx,yy,z+10.5))+d*1.4,Vector((xx,yy,z+11.3))+d*2.1],[.22,.18,.08],'gold',group,sides=6)
        if i in [0,1,2]:
            for k in range(9):
                t=(k+.5)/9
                px=xx+(q[0]-xx)*t;py=yy+(q[1]-yy)*t
                cylinder('TeaShrine_RearWoodScreen',(px,py,z+4.3),.075,6.4,'wood',group,vertices=5)
        lantern('TeaShrine_HangingLantern',(xx*.98+x*.02,yy*.98+y*.02,z+9.1),group,scale=.9)
    vertices=[];n=72
    for radius,height in [(1.1,16.5),(4.2,15.3),(9.2,12.2),(11.4,12.8)]:
        for i in range(n):
            a=2*pi*i/n
            radial=radius*(.935+.065*cos(6*(a-pi/6)))
            zz=height+(max(0,radius-8.5)*.18*cos(6*(a-pi/6)))
            vertices.append((x+radial*cos(a),y+radial*sin(a),z+zz))
    faces=[]
    for level in range(3):
        for i in range(n):
            j=(i+1)%n;faces.append((level*n+i,level*n+j,(level+1)*n+j,(level+1)*n+i))
    faces.append(tuple(reversed(range(n))))
    mesh('TeaShrine_SculptedHexagonalRoof',vertices,faces,'roof',group)
    for i in range(6):
        a=i*pi/3+pi/6
        pts=[(x+r*cos(a),y+r*sin(a),z+h) for r,h in [(1.1,16.52),(4.2,15.33),(9.2,12.35),(11.4,13.3)]]
        tube('TeaShrine_GoldHipRidge',pts,[.15]*4,'gold',group,sides=7)
    tube('TeaShrine_EaveTrim',vertices[-n:]+[vertices[-n]],[.15]*(n+1),'gold',group,sides=6)
    for i in range(36):
        a=2*pi*i/36
        tube('TeaShrine_RoofTileSeam',[(x+4.3*cos(a),y+4.3*sin(a),z+15.28),(x+8.8*cos(a),y+8.8*sin(a),z+12.47),(x+10.9*cos(a),y+10.9*sin(a),z+12.83)],[.045]*3,'stoneDark',group,sides=4)
    cylinder('TeaShrine_FinialStem',(x,y,z+17.1),.26,1.8,'gold',group,vertices=12)
    ico('TeaShrine_LotusFinial',(x,y,z+18.1),(.7,.7,1),'gold',group,subdivisions=2)
    box('TeaShrine_TeaTable',(x,y,z+2.0),(4.4,3.2,.3),'wood',group,bevel=.15)
    for xx in [-1.7,1.7]:
        for yy in [-1.1,1.1]:box('TeaShrine_TableLeg',(x+xx,y+yy,z+1.25),(.22,.22,1.2),'wood',group,bevel=.04)
    cylinder('TeaShrine_Teapot',(x,y,z+2.55),.38,.6,'ivory',group,vertices=12)
    cylinder('TeaShrine_TeapotLid',(x,y,z+2.91),.4,.1,'gold',group,vertices=12)
    tube('TeaShrine_TeapotSpout',[(x+.25,y,z+2.6),(x+.65,y,z+2.8),(x+.82,y,z+2.82)],[.13,.1,.065],'ivory',group,sides=7)
    for dx,dy in [(-1,-.7),(1,.7),(-1,.7),(1,-.7)]:
        cylinder('TeaShrine_Teacup',(x+dx,y+dy,z+2.35),.2,.25,'ivory',group,vertices=10)
        cylinder('TeaShrine_Tea',(x+dx,y+dy,z+2.49),.16,.015,'wood',group,vertices=10)
    for dx,dy in [(-3.1,0),(3.1,0),(0,-3),(0,3)]:
        cylinder('TeaShrine_SittingCushion',(x+dx,y+dy,z+.91),.95,.38,'purple',group,vertices=24)
    marker('NPC_TeaMaster',(x+4,y+1,z+.95),'npc_tea_master')
    marker('HOBBY_TeaCeremony',(x,y-3,z+1),'hobby_tea_ceremony')


def west_garden(rng):
    group='60_OuterMoonGardens'
    x,y=-172,-112
    ellipse_disk('WestMoonLake_StoneBasin',(x,y,1.47),35,26.5,.6,'stoneDark',group,sides=96)
    ellipse_disk('WestMoonLake_ReflectiveWater',(x,y,1.83),33.8,25.2,.06,'water',group,sides=96)
    rim=[];path=[]
    for i in range(81):
        a=2*pi*i/80
        wobble=1+.025*sin(5*a)
        rim.append((x+34.6*wobble*cos(a),y+26*wobble*sin(a),2.05))
        path.append((x+40*cos(a),y+31.2*sin(a),1.45))
    tube('WestMoonLake_CarvedShoreRim',rim,[.45]*len(rim),'stoneLight',group,sides=7)
    curving_walk('WestMoonLake_GardenPromenade',path,5.1,group)
    ellipse_disk('TeaIsland_RockBase',(-166,-111,2.42),11.7,10.7,1.8,'rock',group,sides=40)
    ellipse_disk('TeaIsland_MossTerrace',(-166,-111,3.4),11.1,10.1,.24,'moss',group,sides=40)
    tea_pavilion((-166,-111,3.5),group)
    arch_bridge('WestMoonLake_WestBridge',(-205,-111,2.0),(-177,-111,3.45),6,3.4,group)
    arch_bridge('WestMoonLake_EastBridge',(-155,-115,3.45),(-137,-125,2.0),6,2.7,group)
    for i in range(29):
        a=i*2*pi/29+.12
        if abs(sin(a))<.12:continue
        p=(x+35.5*cos(a),y+27*sin(a),2.1)
        strata_rock('WestMoonLake_ShoreStone_%02d'%i,p,(rng.uniform(1.2,3),rng.uniform(.9,2.4),rng.uniform(1,2.4)),group,rng)
    lotus=PetalMesh('WestMoonLake_LotusFlowers',group)
    for i in range(55):
        a=rng.uniform(0,2*pi);r=rng.uniform(.6,.9)
        xx=x+cos(a)*31*r;yy=y+sin(a)*24*r
        if abs(yy+111)<3:continue
        ellipse_disk('WestMoonLake_LilyPad',(xx,yy,1.89),rng.uniform(.6,1.25),rng.uniform(.5,.95),.055,'leaf',group,sides=12)
        if i%4==0:
            for k in range(8):
                b=k*pi/4
                lotus.lens((xx+cos(b)*.22,yy+sin(b)*.22,2.16),.47,.2,.15,b,.4,'blossomLight')
            lotus.lens((xx,yy,2.28),.15,.15,.1,0,0,'goldLight')
    lotus.finish()
    for i,(xx,yy,h,s) in enumerate([(-210,-92,30,15),(-189,-76,27,14),(-157,-80,34,16),(-137,-97,27,12),(-144,-145,28,13),(-174,-151,32,15),(-202,-140,25,13),(-220,-116,29,13)]):
        mature_sakura('WestMoonLake_Grove_%02d'%i,(xx,yy,1.4),h,s,group,rng)
    for i,(xx,yy) in enumerate([(-210,-78),(-139,-86),(-209,-149),(-161,-153)]):
        bamboo_cluster('WestMoonLake_Bamboo_%02d'%i,(xx,yy,1.4),group,rng,count=8)
    for i,(xx,yy) in enumerate([(-197,-86),(-181,-148),(-132,-105),(-217,-121),(-153,-145),(-215,-96)]):
        fern('WestMoonLake_Fern_%02d'%i,(xx,yy,1.5),rng.uniform(1.1,1.8),group,rng)
        lantern('WestMoonLake_Lantern_%02d'%i,(xx+2,yy,3.2),group,scale=1.2,hanger=False)
    bench('WestMoonLake_PondBench',(-182,-80,1.35),group,yaw=pi)
    bench('WestMoonLake_PondBenchSouth',(-188,-144,1.35),group)
    for i in range(9):
        xx=-200+i*4.3;yy=-134+sin(i*.72)*3.5
        ellipse_disk('WestMoonLake_SteppingStone_%02d'%i,(xx,yy,2.07),1.45,1.2,.28,'stoneLight',group,sides=9)
    box('WestMoonLake_FishingPier',(-198,-131,2.2),(12,7,.7),'wood',group,bevel=.15)
    for i in range(13):box('WestMoonLake_PierPlank',(-204+i,-131,2.65),(.92,7,.18),'wood',group,bevel=.03)
    for xx in [-203,-193]:
        for yy in [-134,-128]:cylinder('WestMoonLake_PierPost',(xx,yy,2.8),.23,3.5,'wood',group,vertices=9)
    for i in range(3):
        xx=-201+i*3
        tube('WestMoonLake_FishingRod_%02d'%i,[(xx,-130,2.9),(xx+.7,-127,4.5),(xx+.9,-123,5.4)],[.09,.06,.02],'wood',group,sides=6)
        tube('WestMoonLake_FishingLine_%02d'%i,[(xx+.9,-123,5.4),(xx+1,-122.7,1.92)],[.012,.012],'ivory',group,sides=4)
        ico('WestMoonLake_FishingFloat_%02d'%i,(xx+1,-122.7,2.02),(.15,.15,.24),'red',group)
    cylinder('WestMoonLake_FishingBasket',(-202,-133,3.35),.62,1.05,'wood',group,vertices=14)
    for zz in [2.95,3.25,3.6,3.9]:ring('WestMoonLake_BasketWeave',(-202,-133,zz),.65,.59,.065,'goldLight',group,segments=14)
    marker('HOBBY_OuterGardenFishing',(-197,-130,2.9),'hobby_fishing')
    marker('SECRET_LotusTrail',(-165,-133,2.5),'exploration_lotus_trail')
    lantern_string('WestMoonLake_FestivalLights',(-200,-84,12),(-144,-91,13),group,count=14)


def water_ribbon(name, points, widths, group, rng, waterfall=False):
    verts=[];sidevec=[]
    for i,p in enumerate(points):
        q=Vector(p);prev=Vector(points[max(0,i-1)]);nxt=Vector(points[min(len(points)-1,i+1)])
        d=nxt-prev;side=Vector((-d.y,d.x,0)).normalized()
        sidevec.append(side)
        for j in range(7):
            t=j/6-.5
            v=q+side*(widths[i]*t)
            v.z+=.08*sin(i*1.7+j*2.3)
            verts.append(tuple(v))
    faces=[]
    for i in range(len(points)-1):
        for j in range(6):faces.append((i*7+j,i*7+j+1,(i+1)*7+j+1,(i+1)*7+j))
    mesh(name+'_WaterSurface',verts,faces,'cyan' if waterfall else 'water',group)
    for stripe in range(7 if waterfall else 3):
        t=(stripe+1)/(8 if waterfall else 4)-.5
        stream=[]
        for i,p in enumerate(points):
            q=Vector(p)+sidevec[i]*(widths[i]*t+rng.uniform(-.2,.2))+Vector((0,0,.14))
            stream.append(tuple(q))
        tube(name+'_WhitewaterRibbon',stream,[rng.uniform(.06,.15)]*len(stream),'ivory' if stripe%2 else 'cyanGlow',group,sides=4)
    if not waterfall:
        for side in [-1,1]:
            bank=[tuple(Vector(p)+sidevec[i]*(widths[i]*.53*side)-Vector((0,0,.2))) for i,p in enumerate(points)]
            tube(name+'_RiverBank',bank,[.7]*len(bank),'stoneDark',group,sides=7)


def cascade_district(rng):
    group='61_WaterfallRavine'
    # Big stepped geology supports the upper grove and makes the vertical route legible.
    for i,(center,size) in enumerate([((-181,151,14),(31,25,26)),((-180,153,30),(25,21,24)),((-177,154,41),(21,18,10)),((-201,125,11),(24,17,20)),((-203,124,22),(18,14,9)),((-212,101,7),(18,20,11)),((-217,99,14),(13,15,5))]):
        strata_rock('Waterfall_CliffMass_%02d'%i,center,size,group,rng)
    for i in range(21):
        a=rng.uniform(0,2*pi)
        xx=-184+cos(a)*rng.uniform(24,33);yy=147+sin(a)*rng.uniform(15,24)
        zz=rng.uniform(6,19)
        strata_rock('Waterfall_Buttress_%02d'%i,(xx,yy,zz),(rng.uniform(3,6),rng.uniform(3,5),zz*1.85),group,rng)
    ellipse_disk('Waterfall_SourcePool',(-175,152,45.25),12.9,10,.24,'water',group,sides=48)
    ellipse_disk('Waterfall_MiddlePool',(-199,125,26.65),12,10,.15,'water',group,sides=48)
    ellipse_disk('Waterfall_LowerPool',(-213,102,17.3),10.5,12,.13,'water',group,sides=48)
    paths=[([(-175,145,45.3),(-179,140,45.1),(-183,134,41),(-188,130,29),(-194,127,26.9)],[12,12,11,10,12]),([(-202,119,26.8),(-205,115,25.8),(-208,111,18.5),(-211,108,17.4)],[11,11,10,12]),([(-216,95,17.4),(-218,90,16),(-220,87,6.5),(-221,84,2.25)],[12,11,10,13])]
    for i,(p,w) in enumerate(paths):water_ribbon('Waterfall_Cascade_%02d'%i,p,w,group,rng,waterfall=True)
    ellipse_disk('Waterfall_FinalLake',(-222,73,1.85),19,18,.2,'water',group,sides=64)
    water_ribbon('Waterfall_GardenRiver',[(-221,84,2.25),(-224,78,1.94),(-222,70,1.9),(-216,59,1.9),(-210,51,1.9)],[13,15,13,11,10],group,rng)
    arch_bridge('Waterfall_RiverBridge',(-235,79,2.0),(-209,79,2.0),6.8,3.6,group)
    for i,(xx,yy,zz) in enumerate([(-192,149,45),(-168,162,46),(-180,168,46),(-204,133,28),(-220,109,18),(-230,75,2),(-233,62,2)]):
        cedar('Waterfall_AncientPine_%02d'%i,(xx,yy,zz),rng.uniform(23,35),rng.uniform(7,10),group,rng)
    mature_sakura('Waterfall_HangingSakura',(-161,145,44.5),27,13,group,rng)
    for i,(xx,yy,zz) in enumerate([(-217,91,17.3),(-225,69,2),(-206,118,27.2),(-185,160,45.6),(-216,53,1.4)]):
        fern('Waterfall_TerraceFern_%02d'%i,(xx,yy,zz),1.6,group,rng)
    # A traversable stair zigzags up the far side, not through the waterfall.
    segments=[((-156,119,1.3),(-156,141,14)),((-156,141,14),(-171,146,26)),((-171,146,26),(-169,164,45))]
    for j,(start,end) in enumerate(segments):
        a,b=Vector(start),Vector(end);count=28
        d=b-a;ang=-math.atan2(d.x,d.y)
        for i in range(count):
            p=a.lerp(b,(i+.5)/count)
            step=box('Waterfall_Stair_%d_%02d'%(j,i),p,(5,d.xy.length/count+.1,.55),'stoneLight',group,bevel=.04)
            step.rotation_euler.z=ang
        side=Vector((-d.y,d.x,0)).normalized()*2.7
        for sign in [-1,1]:
            tube('Waterfall_StairStringer',[a+side*sign-Vector((0,0,.55)),b+side*sign-Vector((0,0,.55))],[.42,.42],'wood',group,sides=6)
            tube('Waterfall_StairRail',[a+side*sign+Vector((0,0,2.4)),b+side*sign+Vector((0,0,2.4))],[.16,.16],'wood',group,sides=6)
    for i,p in enumerate([(-156,141,14),(-171,146,26),(-169,164,45)]):
        cylinder('Waterfall_SwitchbackLanding_%02d'%i,p,3.6,.55,'stoneLight',group,vertices=20)
    cylinder('Waterfall_VistaDeck',(-169,164,45.3),7,.7,'wood',group,vertices=48)
    bench('Waterfall_VistaBench',(-166,165,45.7),group,yaw=-pi/3)
    marker('SECRET_WaterfallVista',(-169,163,46),'exploration_vista')
    marker('NPC_WaterfallWanderer',(-229,60,2),'npc_exploration_guide')
    # Fine spray at each impact is geometric, so it travels with the export.
    foam=PetalMesh('Waterfall_FoamAndSpray',group)
    for xx,yy,zz in [(-194,127,26.95),(-211,107,17.5),(-221,83,2.4)]:
        for i in range(80):
            a=rng.random()*2*pi;r=rng.uniform(.3,5.5)
            foam.lens((xx+cos(a)*r,yy+sin(a)*r*.6,zz+rng.uniform(0,2.2)),rng.uniform(.15,.4),.11,.06,a,.4,'ivory')
    foam.finish()


def forest_understory(name, center, rng, group):
    x,y,z=center
    for j in range(4):
        a=j*pi/2+.4
        c=(x+cos(a)*2.1,y+sin(a)*2.1,z+.8)
        blossom_mass(name+'_Shrub_%02d'%j,c,(2.9,2.2,1.1),group,rng,foliage=True)
    fern(name+'_Fern',(x-1.7,y+2.1,z+.1),1.3,group,rng)


def eastern_forest(rng):
    group='62_EasternForest'
    # Paths bend through deliberately grouped woodland rather than uniform tree scatter.
    route=[(177,-9,1.5),(190,0,1.5),(196,18,1.5),(201,35,1.5),(215,44,1.5),(219,60,1.5),(216,79,1.5),(204,95,1.5),(192,103,1.5)]
    curving_walk('EasternForest_WindingTrail',route,6.5,group,material='stone')
    tree_sites=[(188,1),(210,6),(231,5),(248,16),(183,24),(212,23),(239,30),(256,42),(185,48),(203,57),(235,50),(246,66),(186,76),(203,81),(231,83),(244,98),(186,98),(213,110),(228,114)]
    for i,(xx,yy) in enumerate(tree_sites):
        if (xx*xx+yy*yy)**.5>267:continue
        cedar('EasternForest_Cedar_%02d'%i,(xx,yy,1.35),rng.uniform(28,45),rng.uniform(7.4,11),group,rng)
        if i%2==0:forest_understory('EasternForest_Understory_%02d'%i,(xx+2.8,yy-4,1.4),rng,group)
    for i,(xx,yy) in enumerate([(194,-11),(225,15),(236,67),(195,89),(222,105),(183,60)]):
        mature_sakura('EasternForest_FloweringTree_%02d'%i,(xx,yy,1.4),rng.uniform(22,31),rng.uniform(11,15),group,rng,green=i in [2,4])
    for i,(xx,yy) in enumerate([(201,12),(223,36),(209,73),(196,103),(241,20)]):
        strata_rock('EasternForest_MossBoulder_%02d'%i,(xx,yy,2.8),(rng.uniform(3.2,4.8),rng.uniform(2.4,4),3.6),group,rng)
        fern('EasternForest_BoulderFern_%02d'%i,(xx+2.9,yy-1,1.5),1.4,group,rng)
    for i,p in enumerate([(189,9),(201,31),(216,51),(214,86)]):
        lantern('EasternForest_TrailLamp_%02d'%i,(p[0],p[1],3.1),group,scale=1.0,hanger=False)
    bench('EasternForest_RestBench',(209,45,1.4),group,yaw=-pi/2)
    bench('EasternForest_NorthBench',(204,91,1.4),group,yaw=pi/4)
    # A shrine behind the trees gives the forest a discoverable destination.
    x,y=235,62
    cylinder('ForestSecret_ShrinePlinth',(x,y,1.9),5.9,.9,'stoneDark',group,vertices=24)
    for xx in [x-4.3,x+4.3]:
        cylinder('ForestSecret_RedToriiPillar',(xx,y,6.25),.48,8.8,'red',group,vertices=12)
        cylinder('ForestSecret_PillarBand',(xx,y,4.6),.51,.4,'black',group,vertices=12)
    tube('ForestSecret_UpturnedToriiLintel',[(x-7,y,11.7),(x-4.5,y,11.1),(x,y,10.8),(x+4.5,y,11.1),(x+7,y,11.7)],[.4]*5,'black',group,sides=8)
    tube('ForestSecret_RedLintel',[(x-7,y,11.32),(x-4.5,y,10.7),(x,y,10.4),(x+4.5,y,10.7),(x+7,y,11.32)],[.31]*5,'red',group,sides=8)
    box('ForestSecret_CrossBeam',(x,y,9.7),(11.5,.7,.7),'red',group,bevel=.08)
    box('ForestSecret_OfferingStone',(x,y+2.9,2.7),(3.8,2.2,1),'stoneLight',group,bevel=.2)
    ico('ForestSecret_SpiritCrystal',(x,y+2.9,4.45),(.65,.6,1.45),'purpleGlow',group,subdivisions=1)
    for i in range(5):ellipse_disk('ForestSecret_ApproachStone',(221+i*2.5,60.5+i*.3,1.6),1.1,.8,.22,'stoneLight',group,sides=9)
    marker('SECRET_EasternSpiritShrine',(234,60,2.6),'exploration_forest_shrine')
    marker('NPC_ForestWarden',(218,56,1.7),'npc_forest_warden')


def rim_forest(rng):
    group='63_OuterRimForest'
    angles=[4,16,27,41,56,117,143,155,168,180,194,209,222,236,244,300,314,326,340,352]
    for i,degrees in enumerate(angles):
        a=degrees*pi/180;r=250+rng.uniform(-3,6)
        x,y=r*cos(a),r*sin(a)
        if i%4==1:
            mature_sakura('RimForest_FloweringSilhouette_%02d'%i,(x,y,1.35),rng.uniform(25,38),rng.uniform(12,16),group,rng,green=i%3==0)
        else:
            cedar('RimForest_HighCedar_%02d'%i,(x,y,1.35),rng.uniform(35,52),rng.uniform(9,13),group,rng)
        for j in [-1,1]:
            aa=a+j*.043;rr=r-rng.uniform(3,8)
            cedar('RimForest_Companion_%02d_%d'%(i,j),(rr*cos(aa),rr*sin(aa),1.35),rng.uniform(21,34),rng.uniform(6,9),group,rng)
        if i%2==0:forest_understory('RimForest_FernBed_%02d'%i,(x-2*cos(a),y-2*sin(a),1.4),rng,group)


def build():
    rng=random.Random(269121)
    west_garden(rng)
    cascade_district(rng)
    eastern_forest(rng)
    rim_forest(rng)
