from common import *


class PetalMesh:
    def __init__(self, name, group, detailed=False):
        self.name = name
        self.detailed = detailed
        self.group = group
        self.parts = {}

    def lens(self, center, length, width, thick, yaw, lean, material):
        verts, faces = self.parts.setdefault(material, ([], []))
        c = Vector(center)
        a = Vector((cos(yaw), sin(yaw), lean)).normalized()
        b = Vector((-sin(yaw), cos(yaw), 0))
        n = a.cross(b).normalized()
        start = len(verts)
        rim = [(-1, 0), (-.36, -.92), (.52, -.76), (1, 0), (.52, .76), (-.36, .92)] if self.detailed else [(-1, 0), (0, -1), (1, 0), (0, 1)]
        count = len(rim)
        verts.extend([tuple(c + a * (u * length) + b * (v * width)) for u, v in rim])
        verts.append(tuple(c + n * thick))
        verts.append(tuple(c - n * thick * .42))
        for i in range(count):
            j = (i + 1) % count
            faces.extend([(start + i, start + j, start + count), (start + j, start + i, start + count + 1)])

    def finish(self):
        for material, (verts, faces) in self.parts.items():
            if verts:
                mesh(self.name + '_' + material, verts, faces, material, self.group)


def ellipse_disk(name, loc, rx, ry, depth, material, group, sides=64):
    x, y, z = loc
    vertices = []
    for zz in [z - depth / 2, z + depth / 2]:
        vertices.extend([(x + rx * cos(2*pi*i/sides), y + ry * sin(2*pi*i/sides), zz) for i in range(sides)])
    faces = []
    for i in range(sides):
        j = (i+1) % sides
        faces.append((i,j,j+sides,i+sides))
    faces.extend([tuple(reversed(range(sides))), tuple(range(sides,2*sides))])
    return mesh(name, vertices, faces, material, group)


def bench(name, loc, group, yaw=0):
    center = Vector(loc)
    side = Vector((cos(yaw), sin(yaw), 0))
    back = Vector((-sin(yaw), cos(yaw), 0))
    def p(a,b,c):
        return tuple(center + side*a + back*b + Vector((0,0,c)))
    for i in range(4):
        ob = box(name+'_SeatPlank_%02d'%i, p(0,-.6+i*.4,1.2), (5.8,.32,.18), 'wood', group, bevel=.06)
        ob.rotation_euler.z = yaw
    for a in [-2.1,2.1]:
        for b in [-.55,.55]:
            box(name+'_Foot',p(a,b,.54),(.24,.24,1.1),'black',group,bevel=.06)
        tube(name+'_BackSupport',[p(a,.65,.1),p(a,.7,2.7)], [.12,.12], 'black',group,sides=6)
    for c in [1.85,2.45]:
        ob=box(name+'_BackSlat',p(0,.72,c),(5.8,.16,.43),'wood',group,bevel=.05)
        ob.rotation_euler.z = yaw


def lantern(name, loc, group, scale=1, hanger=True):
    x,y,z=loc
    cylinder(name+'_Foot',(x,y,z-.48*scale),.5*scale,.13*scale,'gold',group,vertices=8)
    cylinder(name+'_Glow',(x,y,z),.43*scale,.86*scale,'goldGlow',group,vertices=8)
    cylinder(name+'_Roof',(x,y,z+.49*scale),.6*scale,.15*scale,'black',group,vertices=8)
    for i in range(4):
        a=pi/4+i*pi/2
        tube(name+'_Frame',[(x+.36*scale*cos(a),y+.36*scale*sin(a),z-.4*scale),(x+.36*scale*cos(a),y+.36*scale*sin(a),z+.43*scale)], [.027*scale,.027*scale], 'gold',group,sides=4)
    if hanger:
        tube(name+'_Hanger',[(x,y,z+.57*scale),(x,y,z+1.08*scale)],[.04*scale,.04*scale],'black',group,sides=5)


def lantern_string(name, start, end, group, count=8):
    a,b=Vector(start),Vector(end)
    pts=[]
    for i in range(25):
        t=i/24
        p=a.lerp(b,t); p.z -= 2.5*sin(pi*t)
        pts.append(tuple(p))
    tube(name+'_Cable',pts,[.045]*len(pts),'black',group,sides=5)
    for i in range(count):
        t=(i+.5)/count
        p=a.lerp(b,t); p.z-=2.5*sin(pi*t)+1
        lantern(name+'_Lantern_%02d'%i,p,group,scale=.6)


def cherry_tree(name, base, scale, group, rng, hero=False):
    x,y,z=base
    def p(a,b,c): return (x+a*scale,y+b*scale,z+c*scale)
    trunk=[p(0,0,0),p(-1.3,.5,5),p(-.9,.1,10),p(1.2,-.2,15),p(2.4,1,19),p(1.5,2,23),p(3.7,1.1,27)]
    tube(name+'_SculptedTrunk',trunk,[v*scale for v in [2.65,2,1.7,1.37,1.04,.72,.15]],'wood',group,sides=10 if hero else 8)
    for k in range(9 if hero else 6):
        a=2*pi*k/(9 if hero else 6)+rng.uniform(-.12,.12)
        tube(name+'_FlaredRoot_%02d'%k,[p(0,0,2.4),p(2.7*cos(a),2.7*sin(a),.55),p(5.4*cos(a+.18),5.4*sin(a+.18),.06)], [1.15*scale,.7*scale,.03*scale],'wood',group,sides=7)
    petals=PetalMesh(name+'_BlossomSprays',group,detailed=hero)
    cluster_centers=[]
    for i in range(8 if hero else 5):
        a=2*pi*i/(8 if hero else 5)+.2
        reach=(15.4 if hero else 13.4)+rng.uniform(-1.3,1.8)
        root=Vector(p(.8,0,14.5+(i%3)*2))
        elbow=Vector(p(reach*.47*cos(a)+1,reach*.4*sin(a),23+rng.uniform(-2,1)))
        tip=Vector(p(reach*cos(a)+1,reach*.72*sin(a),27+rng.uniform(-2.5,2.8)))
        tube(name+'_Bough_%02d'%i,[root,elbow,tip],[1.12*scale,.63*scale,.085*scale],'wood',group,sides=8)
        for j in [-1,1]:
            twig_tip=tip+Vector((cos(a+j*.66)*3.8*scale,sin(a+j*.66)*3.8*scale,rng.uniform(1.7,3.4)*scale))
            twig_mid=tip.lerp(elbow,.42)+Vector((0,0,.5*scale))
            tube(name+'_FineBranch_%02d_%s'%(i,j),[twig_mid,tip,twig_tip],[.29*scale,.14*scale,.025*scale],'wood',group,sides=6)
            cluster_centers.append((twig_tip,3.65*scale,1.65*scale))
        cluster_centers.append((elbow.lerp(tip,.58)+Vector((0,0,1.5*scale)),4.15*scale,1.9*scale))
    cluster_centers.extend([(Vector(p(1,1,30)),4.8*scale,2.3*scale),(Vector(p(5,3,32)),3.5*scale,2.0*scale)])
    for n,(center,spread,height) in enumerate(cluster_centers):
        count=68 if hero else 22
        for k in range(count):
            a=rng.random()*2*pi
            rr=spread*(rng.random()**.55)
            zz=height*rng.uniform(-.65,.92)*(1-.25*rr/spread)
            c=center+Vector((rr*cos(a),rr*.82*sin(a),zz))
            material='blossomLight' if rng.random()<.43 else 'blossom'
            petals.lens(c,rng.uniform(.54,.9)*scale,rng.uniform(.3,.49)*scale,.16*scale,rng.random()*2*pi,rng.uniform(-.65,.65),material)
        if hero or n%3==0:
            for k in range(3 if hero else 1):
                a=rng.random()*2*pi
                q=center+Vector((spread*.78*cos(a),spread*.64*sin(a),-.2*scale))
                length=rng.uniform(2.4,4.7)*scale
                tube(name+'_HangingFlowerStem',[q,q+Vector((.15*scale,.1*scale,-length))],[.022*scale,.01*scale],'wood',group,sides=4)
                for j in range(7 if hero else 5):
                    t=j/(7 if hero else 5)
                    c=q+Vector((.15*scale,.1*scale,-length*t))
                    for side in [-1,1]:
                        petals.lens(c+Vector((side*.16*scale,0,0)),(.38-.17*t)*scale,.19*scale,.08*scale,a+side*.7,.7,'blossomLight' if j%3==0 else 'blossom')
    petals.finish()
    if hero:
        ring(name+'_RootGardenCurb',(x,y,z+.02),7.1,6.5,.22,'stoneDark',group,segments=48)
        lantern_string(name+'_FestivalGarland',p(-12,-4,12),p(13,-2,13),group,count=8)
        marker('NPC_SakuraLore',(x-6,y-7,z+.15),'npc_story_lore')


def fern(name, loc, scale, group, rng):
    x,y,z=loc
    batch=PetalMesh(name,group)
    for k in range(7):
        a=k*2*pi/7+rng.uniform(-.14,.14)
        tip=Vector((x+2.15*scale*cos(a),y+2.15*scale*sin(a),z+.45*scale))
        start=Vector((x,y,z+.18*scale))
        mid=start.lerp(tip,.46)+Vector((0,0,1.0*scale))
        tube(name+'_Stem', [start,mid,tip],[.055*scale,.035*scale,.006*scale],'leaf',group,sides=4)
        for j in range(1,6):
            t=j/6
            center=start.lerp(tip,t)+Vector((0,0,sin(pi*t)*.8*scale))
            for sign in [-1,1]:
                batch.lens(center,.5*scale*(1-t*.6),.16*scale,.04*scale,a+sign*.65,.15,'leafLight' if j%2 else 'leaf')
    batch.finish()


def bamboo_cluster(name, loc, group, rng, count=5):
    x,y,z=loc
    batch=PetalMesh(name+'_Leaves',group)
    for k in range(count):
        a=k*2.4
        xx=x+cos(a)*rng.uniform(.2,1.8); yy=y+sin(a)*rng.uniform(.2,1.8)
        h=rng.uniform(7,12)
        tilt=Vector((rng.uniform(-.8,.8),rng.uniform(-.8,.8),h))
        start=Vector((xx,yy,z))
        tube(name+'_Culm_%02d'%k,[start,start+tilt*.5,start+tilt],[.16,.13,.08],'leaf',group,sides=7)
        for level in range(1,6):
            point=start+tilt*(level/6)
            cylinder(name+'_Node',point,.18,.09,'leafLight',group,vertices=8)
            direction=rng.random()*2*pi
            end=point+Vector((cos(direction)*2.1,sin(direction)*2.1,.55))
            tube(name+'_Twig',[point,end],[.055,.012],'leaf',group,sides=4)
            for j in range(5):
                center=point.lerp(end,(j+1)/6)
                batch.lens(center,.7,.15,.035,direction+(-.65 if j%2 else .65),.2,'leafLight' if j%2 else 'leaf')
    batch.finish()


def moon_garden(rng):
    g='42_MoonGarden'; x,y=-60,-54
    ellipse_disk('MoonPond_DarkStoneBasin',(x,y,1.42),23.1,16.2,.65,'stoneDark',g)
    ellipse_disk('MoonPond_JadeWater',(x,y,1.8),21.9,15.0,.07,'water',g)
    verts=[]; faces=[]
    for i in range(80):
        a=i*2*pi/80
        verts.extend([(x+rx*cos(a),y+ry*sin(a),2.01) for rx,ry in [(23.1,16.2),(21.9,15)]])
    for i in range(80):
        j=(i+1)%80; faces.append((2*i,2*j,2*j+1,2*i+1))
    mesh('MoonPond_PolishedRim',verts,faces,'stoneLight',g)
    for i in range(15):
        a=i*2*pi/15+.2
        if abs(sin(a))<.27: continue
        q=(x+23*cos(a),y+16*sin(a),1.65)
        ico('MoonPond_ShoreRock_%02d'%i,q,(rng.uniform(1.2,2.4),rng.uniform(.9,1.7),rng.uniform(.6,1.35)),'rock',g,subdivisions=1)
    for i in range(13):
        xx=x+rng.uniform(-15,15); yy=y+rng.choice([-1,1])*rng.uniform(5,11)
        radius=rng.uniform(.48,.98)
        ellipse_disk('MoonPond_LilyPad',(xx,yy,1.85),radius,radius*.84,.05,'leaf',g,sides=10)
        if i%3==0:
            b=PetalMesh('MoonPond_Lotus_%02d'%i,g)
            for n in range(7):
                a=n*2*pi/7
                b.lens((xx+cos(a)*.18,yy+sin(a)*.18,2.00),.36,.18,.12,a,.3,'blossomLight')
            b.finish()
            cylinder('MoonPond_LotusHeart',(xx,yy,2.12),.13,.11,'gold',g,vertices=8)
    def bridge_z(xx): return 2.17+3.3*sin(pi*xx)
    for i in range(31):
        t=(i+.5)/31
        xx=x-23+t*46
        box('MoonBridge_DeckPlank_%02d'%i,(xx,y,bridge_z(t)),(46/31-.055,5.5,.22),'wood',g,bevel=.04)
    for side in [-1,1]:
        rail=[]; beam=[]
        for i in range(45):
            t=i/44
            rail.append((x-23+t*46,y+side*2.8,bridge_z(t)+2.65))
            beam.append((x-23+t*46,y+side*2.64,bridge_z(t)-.28))
        tube('MoonBridge_ArchedRedHandrail',rail,[.16]*len(rail),'red',g,sides=8)
        tube('MoonBridge_GoldTopline',[(a,b,c+.17) for a,b,c in rail],[.065]*len(rail),'gold',g,sides=6)
        tube('MoonBridge_CurvedSupport',beam,[.32]*len(beam),'red',g,sides=8)
        for i in range(9):
            t=i/8; xx=x-23+t*46; zz=bridge_z(t)
            cylinder('MoonBridge_RedPost',(xx,y+side*2.8,zz+1.28),.2,2.8,'red',g,vertices=8)
            cylinder('MoonBridge_GoldPostCap',(xx,y+side*2.8,zz+2.75),.3,.19,'gold',g,vertices=8)
    for side in [-1,1]:
        for step in range(2):
            box('MoonBridge_ApproachStep', (x+side*(24.5-step*.75),y,1.42+step*.3),(1.5,6.4,.34),'stoneLight',g,bevel=.05)
    box('FishingDock_Substructure',(-65,-70,1.72),(12,8,.5),'wood',g,bevel=.12)
    for i in range(12):
        box('FishingDock_Plank_%02d'%i,(-70.5+i,-70,2.02),(.92,8,.2),'wood',g,bevel=.045)
    for xx in [-70.5,-59.5]:
        for yy in [-66.6,-73.4]:
            cylinder('FishingDock_MooringPost',(xx,yy,2.25),.26,2.6,'wood',g,vertices=9)
            cylinder('FishingDock_RopeBand',(xx,yy,3.2),.31,.21,'ivory',g,vertices=9)
    for i in range(2):
        px=-67+i*4
        tube('Fishing_Rod_%d'%i,[(px,-72,2.1),(px+.5,-68,3.5),(px+.7,-63.5,4.8)],[.075,.05,.016],'wood',g,sides=5)
        tube('Fishing_Line_%d'%i,[(px+.7,-63.5,4.8),(px+.8,-63.0,1.91)],[.01,.01],'ivory',g,sides=4)
        ico('Fishing_Float_%d'%i,(px+.8,-63.0,1.99),(.12,.12,.2),'red',g)
    box('Fishing_TackleChest',(-60,-72,2.53),(1.5,1.1,.9),'wood',g,bevel=.1)
    cylinder('Fishing_BaitBucket',(-62,-73,2.47),.43,.72,'stoneDark',g,vertices=12)
    bench('MoonGarden_ConversationBench',(-60,-33,1.25),g,yaw=pi)
    bench('MoonGarden_WaterBench',(-80,-67,1.25),g,yaw=-pi/4)
    marker('HOBBY_Fishing',(-64,-71,2.16),'hobby_fishing')
    marker('NPC_MoonGardener',(-43,-69,1.3),'npc_hobby_guide')
    for i,p in enumerate([(-82,-48),(-40,-48),(-72,-74),(-50,-74)]):
        cylinder('MoonGarden_LanternBase',(p[0],p[1],1.5),.85,.6,'stoneDark',g,vertices=8)
        lantern('MoonGarden_StoneLantern_%02d'%i,(p[0],p[1],2.5),g,scale=.95,hanger=False)
    text('MoonGarden_Sign','MOON GARDEN',(-59,-32.8,3.65),1.15,'goldLight',g)


def practice_dummy(name, loc, group, yaw=0):
    x,y,z=loc
    tube(name+'_Pole',[(x,y,z),(x,y,z+5.2)],[.26,.22],'wood',group,sides=8)
    cylinder(name+'_WeightedBase',(x,y,z+.2),1.1,.35,'stoneDark',group,vertices=12)
    cylinder(name+'_Body',(x,y,z+3.45),.74,1.8,'ivory',group,vertices=10)
    ico(name+'_Head',(x,y,z+5.06),(.59,.54,.66),'wood',group,subdivisions=1)
    for zz in [2.85,3.15,3.8,4.08]:
        ring(name+'_RopeWrap',(x,y,z+zz),.78,.7,.13,'red',group,segments=12)
    vec=Vector((cos(yaw)*1.9,sin(yaw)*1.9,0))
    tube(name+'_PracticeArms',[Vector((x,y,z+3.65))-vec,Vector((x,y,z+3.65))+vec],[.18,.18],'wood',group,sides=8)
    cylinder(name+'_TopKnot',(x,y,z+5.77),.24,.35,'red',group,vertices=8)


def training_court():
    g='43_Training'
    box('TrainingCourt_StoneFoundation',(-82,-21,1.42),(22,22,.44),'stoneDark',g,bevel=.4)
    for i in range(15):
        box('TrainingCourt_Deck_%02d'%i,(-92.2+i*1.46,-21,1.7),(1.38,21.5,.18),'wood',g,bevel=.045)
    for i,(xx,yy) in enumerate([(-88,-16),(-80,-16),(-88,-25)]):
        ring('Training_Pad_%02d'%i,(xx,yy,1.82),3.25,3.13,.05,'goldLight',g,segments=40)
        practice_dummy('Training_Dummy_%02d'%i,(xx,yy,1.82),g,yaw=.2+i*.8)
    for xx in [-93,-71]:
        cylinder('TrainingCourt_SignPost',(xx,-10.5,5.0),.36,6.5,'red',g,vertices=10)
        cylinder('TrainingCourt_PostCrown',(xx,-10.5,8.3),.52,.28,'gold',g,vertices=10)
    box('TrainingCourt_Header',(-82,-10.5,8.1),(23,1.1,.9),'wood',g,bevel=.1)
    box('TrainingCourt_Plaque',(-82,-11.2,8.05),(14,.25,2.3),'purple',g,bevel=.12)
    text('TrainingCourt_Title','TRAINING',(-82,-11.38,7.47),1.48,'goldLight',g)
    marker('HOBBY_Training',(-77,-26,1.9),'hobby_training')
    marker('NPC_CombatMentor',(-75,-17,1.9),'npc_combat_mentor')
    box('Training_WeaponRack',(-90,-30,2.62),(6.1,.8,1.7),'wood',g,bevel=.1)
    for i in range(4):
        tube('Training_WoodenSword_%02d'%i,[(-92+i*1.3,-30,1.9),(-91.7+i*1.3,-30,5.05)],[.105,.06],'wood',g,sides=5)
        tube('Training_SwordGuard_%02d'%i,[(-92.38+i*1.3,-30,2.7),(-91.5+i*1.3,-30,2.7)],[.08,.08],'gold',g,sides=5)


def exploration(rng):
    g='44_Exploration'
    steps=[(68,69,2.1,3.0),(73,73,3.7,2.4),(76,77,5.7,2.7),(73,83,7.8,2.3),(67,88,10.1,3.0),(61,91,12.4,2.3),(55,94,14.0,3.6)]
    for i,(x,y,z,r) in enumerate(steps):
        ico('Exploration_FloatingStone_%02d'%i,(x,y,z-.75),(r,r*.78,1.8),'rock',g,subdivisions=1)
        ellipse_disk('Exploration_StoneTop_%02d'%i,(x,y,z+.14),r*.81,r*.65,.14,'moss',g,sides=9)
        if i in [1,3,5]:
            ring('Exploration_GuideGlow_%02d'%i,(x,y,z+.27),.61,.51,.05,'cyanGlow',g,segments=20)
    marker('HOBBY_ParkourStart',(66,65,1.3),'hobby_parkour_start')
    marker('SECRET_SakuraVistaReward',(55,94,14.8),'exploration_reward')
    ring('Exploration_RewardHalo',(55,94,17.2),1.35,1.22,.13,'goldGlow',g,segments=32)
    ico('Exploration_RewardStar',(55,94,17.2),(.7,.7,1.05),'gold',g,subdivisions=1)
    # A compact roadside shrine is the visual destination beneath the aerial trail.
    x,y=83,49
    box('HiddenShrine_Platform',(x,y,1.65),(9,9,.9),'stoneDark',g,bevel=.35)
    for xx in [x-3.7,x+3.7]:
        cylinder('HiddenShrine_RedPillar',(xx,y,5.4),.35,7.0,'red',g,vertices=10)
        cylinder('HiddenShrine_PillarFoot',(xx,y,2.4),.51,.35,'gold',g,vertices=10)
    tube('HiddenShrine_SweptTop',[(x-5.7,y,9.4),(x-3.7,y,8.95),(x,y,8.65),(x+3.7,y,8.95),(x+5.7,y,9.4)],[.31,.31,.31,.31,.31],'red',g,sides=8)
    box('HiddenShrine_LowerLintel',(x,y,7.9),(9.3,.56,.52),'red',g,bevel=.07)
    box('HiddenShrine_Altar',(x,y+2,2.6),(4,2.1,1.2),'wood',g,bevel=.1)
    ico('HiddenShrine_Crystal',(x,y+2,4.25),(.68,.55,1.12),'purpleGlow',g,subdivisions=1)
    lantern('HiddenShrine_LanternL',(x-2.6,y+1.5,3.2),g,scale=.6,hanger=False)
    lantern('HiddenShrine_LanternR',(x+2.6,y+1.5,3.2),g,scale=.6,hanger=False)
    marker('SECRET_HiddenShrine',(83,47,2.2),'exploration_discovery')
    marker('NPC_ShrineKeeper',(86,45,1.35),'npc_secret_lore')
    for i in range(4):
        xx=80-i*1.4; yy=43-i*3.0
        ellipse_disk('HiddenShrine_ApproachStone_%02d'%i,(xx,yy,1.32),1.4,.8,.12,'stoneLight',g,sides=8)


def build():
    rng=random.Random(81425)
    cherry_tree('Hero_Sakura',(44,72,1.3),1.12,'40_HeroTree',rng,hero=True)
    # Trees reinforce the edge and frame destinations, keeping the radial paths open.
    tree_sites=[(-97,18,.48),(-79,62,.5),(-25,96,.48),(25,98,.44),(96,27,.47),(92,-27,.42),(73,-70,.44),(-91,-52,.42),(-43,-85,.47)]
    for i,(x,y,s) in enumerate(tree_sites):
        cherry_tree('Garden_Sakura_%02d'%i,(x,y,1.3),s,'41_GardenTrees',rng)
    moon_garden(rng)
    training_court()
    exploration(rng)
    g='45_Planting'
    for i,(x,y) in enumerate([(-84,-76),(-38,-68),(-82,-37),(-96,-32),(83,43),(84,64),(38,91),(-84,46)]):
        bamboo_cluster('Bamboo_%02d'%i,(x,y,1.3),g,rng,count=4 if i%2 else 5)
    for i,(x,y,s) in enumerate([(-85,-46,1.1),(-77,-72,1.0),(-43,-62,.9),(-46,-42,1.1),(-66,-76,.8),(-94,-35,1.0),(-87,-6,.95),(78,57,1.15),(89,47,1.1),(56,81,1.2),(38,89,.8),(76,-65,.9),(-75,74,.9),(94,36,1.05)]):
        fern('Fern_%02d'%i,(x,y,1.4),s,g,rng)
    for i,(x,y) in enumerate([(83,61),(91,42),(54,88),(-85,44),(-37,-69),(79,-65),(-45,-82),(-91,8)]):
        ico('Garden_Rock_%02d'%i,(x,y,2.0),(2.7,2,1.65),'rock',g,subdivisions=1)
        ico('Garden_MossCap_%02d'%i,(x-.2,y,3.03),(2.25,1.64,.48),'moss',g,subdivisions=1)
    for i,(x,y,ang) in enumerate([(-26,-59,pi/2),(31,-63,-pi/2),(41,47,pi),(6,96,pi),(84,-8,-pi/2)]):
        bench('Garden_Bench_%02d'%i,(x,y,1.3),g,yaw=ang)
    for i,(start,end) in enumerate([((-80,-35,9),(-40,-35,9)),((28,49,12),(56,50,12)),((-93,-8,10),(-72,-8,10))]):
        for p in [start,end]:
            cylinder('Festival_GarlandPost',(p[0],p[1],(p[2]+1.3)/2),.16,p[2]-1.3,'wood',g,vertices=8)
        lantern_string('Festival_Garland_%02d'%i,start,end,g,count=7)
