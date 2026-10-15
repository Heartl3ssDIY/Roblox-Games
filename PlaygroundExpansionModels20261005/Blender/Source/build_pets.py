from pet_forms import Pet
from assetlib import material
from math import sin, cos, pi
from mathutils import Vector


def dragon_wings(p, frame, membrane, compact=False):
    for s,label in [(-1,'L'),(1,'R')]:
        p.joint('Wing'+label,(s*.69,.40,1.77),(s*1.46,.55,2.26))
        raw=[(.68,1.63),(.77,2.26),(1.20,2.74),(1.60,2.91),(1.91,2.49),(1.72,2.11),(1.43,2.00),(1.17,1.83),(.91,1.72)]
        if compact:raw=[(.68,1.62),(.79,2.12),(1.20,2.49),(1.60,2.65),(1.75,2.36),(1.65,2.05),(1.36,1.97),(1.10,1.78),(.9,1.69)]
        pts=[(s*x,z) for x,z in raw]
        p.plate('WingMembrane'+label,pts,.15,membrane,y=.43,bevel=.05)
        p.path('WingLeadingSpar'+label,[(s*x,.34,z) for x,z in raw[:5]],[.13,.12,.11,.105,.08],frame,14)
        p.path('WingScallopedRim'+label,[(s*x,.38,z) for x,z in raw[4:]+raw[:1]],.065,frame,12)
        for i,end in enumerate(raw[5:8]):
            p.path('WingFinger'+label+str(i),[(s*raw[2][0],.31,raw[2][1]),(s*((raw[2][0]+end[0])/2),.28,(raw[2][1]+end[1])/2),(s*end[0],.34,end[1])],[.057,.044,.025],frame,10)
        p.blob('WingElbow'+label,(s*.78,.33,2.21),(.17,.15,.17),frame)
    p.bone='Body'


def crystal_drake(spec):
    p=Pet(spec)
    p.blob('PearBody',(0,.18,1.18),(.89,1.03,.89),'blue',.82)
    p.belly('ice',(0,-.77,1.28),.55,1.02,5)
    p.paws('blue','cream',.64,-.57,.63,scale=(.34,.39,.39))
    p.joint('Tail',(0,.82,1.00),(0,1.75,1.25))
    tail=[(0,.81,1.08),(.25,1.34,.84),(.70,1.76,.94),(1.03,1.97,1.27),(1.12,1.93,1.60),(.95,1.72,1.72)]
    p.path('CurledDragonTail',tail,[.33,.29,.23,.17,.12,.022],'blue',18)
    p.path('TailUnderside',[(.05,1.1,.80),(.34,1.46,.68),(.73,1.77,.80),(1.03,1.97,1.12)],[.12,.13,.11,.055],'ice',12)
    for i,(x,y,z) in enumerate(tail[1:5]):p.leaf('TailSpine'+str(i),(x,y,z+.13),(x,y+.025,z+.34),.10,.065,'ice')
    dragon_wings(p,'1455B5','lavender')
    p.bone='Body'
    for i,(x,y,z,h) in enumerate([(-.36,.79,1.88,.57),(0,.95,1.97,.84),(.37,.80,1.88,.61)]):
        p.lathe('BackCrystalSocket'+str(i),[(.19,0),(.20,.05),(.15,.13)],'1455B5',(x,y,z),n=6)
        p.lathe('OpaqueTurquoiseCrystal'+str(i),[(.16,0),(.18,h*.22),(.145,h*.72),(0,h)],'25D8E4',(x,y,z+.06),n=6)
    p.bone='Head'
    p.blob('BroadDragonHead',(0,-.58,2.45),(.86,.72,.76),'blue',.79)
    p.blob('Chin',(0,-1.05,2.03),(.51,.31,.20),'ice',.7)
    p.blob('RoundedMuzzle',(0,-1.10,2.23),(.60,.39,.33),'246ED5',.75)
    for s,label in [(-1,'L'),(1,'R')]:
        p.eye('Eye'+label,s*.44,-1.190,2.62,.28,'cyan')
        p.brow('Brow'+label,s*.45,-1.19,2.98,'1455B5',s*-.14)
        p.nostrils('Nostril', (0,-1.474,2.32),.25,.060) if s==-1 else None
        p.path('IvoryHorn'+label,[(s*.61,-.18,2.94),(s*.74,-.10,3.14),(s*.78,.10,3.34),(s*.74,.28,3.44)],[.20,.17,.11,.020],'cream',12)
        p.ring('HornRoot'+label,(s*.62,-.17,2.97),.17,.041,'1455B5')
        for k in range(3):p.leaf('CheekScale'+label+str(k),(s*(.65+k*.045),-.88,2.29-k*.10),(s*(.78+k*.02),-.56,2.16-k*.1),.12,.055,'1455B5')
    p.smile('HappyGrin',(0,-1.473,2.10),.36,.17,True)
    p.plate('ForeheadCrest',[(-.14,3.05),(0,3.23),(.14,3.05),(0,2.87)],.08,'cyan',-1.0,.025)
    return p.finish()


def ember_wyrmling(spec):
    p=Pet(spec)
    red='BD3034'; dark='373648'
    p.blob('SquatBody',(0,.17,1.13),(.92,1.01,.81),red,.77)
    p.belly('EED2A4',(0,-.78,1.27),.55,.91,5)
    p.paws(red,dark,.67,-.57,.58,scale=(.35,.4,.37),cuffs='gold')
    p.joint('Tail',(0,.88,.90),(0,1.7,1.1))
    points=[(0,.90,.95),(.26,1.41,.73),(.70,1.71,.82),(.97,1.82,1.13),(1.09,1.79,1.38)]
    p.path('CurledTail',points,[.30,.26,.21,.15,.10],red,16)
    p.leaf('SolidFlameFin',(1.05,1.8,1.23),(1.3,1.83,2.04),.30,.11,'orange',bend=(-.15,0,0))
    p.leaf('FlameFinGoldInset',(1.07,1.674,1.34),(1.28,1.704,1.96),.17,.035,'yellow',bend=(-.11,0,0))
    p.leaf('FlameFinSideLobe',(1.06,1.8,1.37),(.8,1.8,1.78),.18,.10,'orange')
    dragon_wings(p,red,'F99237',True)
    p.bone='Body'
    for i,(y,z) in enumerate([(.65,1.98),(1.0,1.85),(1.28,1.45)]):p.leaf('BackGoldSpike'+str(i),(0,y,z),(0,y+.17,z+.34),.14,.08,'gold')
    p.bone='Head'
    p.blob('BoxyDragonHead',(0,-.56,2.38),(.88,.70,.70),red,.73)
    p.blob('WideSnout',(0,-1.13,2.18),(.64,.32,.32),'DA4840',.66)
    p.blob('LowerJaw',(0,-1.13,1.94),(.49,.29,.17),'EED2A4',.70)
    p.smile('CheekyFangedGrin',(0,-1.438,2.10),.43,.20,True,5)
    p.nostrils('Nostril',(0,-1.447,2.36),.25,.057)
    for s,label in [(-1,'L'),(1,'R')]:
        p.eye('Eye'+label,s*.45,-1.15,2.61,.255,'gold')
        p.brow('CheekyBrow'+label,s*.46,-1.19,2.91,red,s*-.19,.29)
        horn=[(s*.65,-.15,2.91),(s*.77,-.05,3.14),(s*.84,.14,3.32),(s*.83,.32,3.37)]
        p.path('CharcoalHorn'+label,horn,[.21,.18,.12,.025],dark,12)
        p.ring('HornGoldCollar'+label,(s*.65,-.15,2.95),.19,.032,'985934')
        for k in range(2):p.path('HornRaisedRing'+label+str(k),[(s*(.74+k*.06),-.15+k*.12,3.08+k*.15),(s*(.80+k*.06),-.02+k*.12,3.10+k*.15),(s*(.74+k*.06),.12+k*.12,3.08+k*.15)],.025,'525164',10)
        p.leaf('CheekFlare'+label,(s*.68,-.82,2.28),(s*.89,-.47,2.17),.19,.09,red)
    for i in range(3):p.leaf('HeadGoldSpine'+str(i),(0,-.05+i*.22,2.95-i*.04),(0,.03+i*.24,3.25-i*.06),.15,.08,'orange')
    return p.finish()


def feather_wings(p,outer='cream',inner='white',size=1,base=(.65,.3,1.65),navy=False):
    for s,label in [(-1,'L'),(1,'R')]:
        p.joint('Wing'+label,(s*base[0],base[1],base[2]),(s*(base[0]+.5),base[1]+.1,base[2]+.55))
        x,y,z=base
        p.blob('WingShoulder'+label,(s*x,y,z),(.25,.24,.39),outer)
        for k in range(5):
            start=(s*(x+.02+k*.045),y-.06,z+.08-k*.095)
            end=(s*(x+size*(.89-.09*k)),y+.10+size*.11*k,z+size*(.87-.26*k))
            p.leaf('FlightFeather'+label+str(k+1),start,end,.20*size,.11,outer,bend=(s*.10,-.03,.06))
            p.leaf('FeatherInset'+label+str(k+1),(start[0],start[1]-.18,start[2]+.035),(end[0]*.985,end[1]-.17,end[2]-.035),.13*size,.030,inner,bend=(s*.10,-.03,.06))
        for k in range(3):p.leaf('WingCovert'+label+str(k),(s*(x+.04),y-.20,z+.23-k*.14),(s*(x+.45),y-.16,z+.42-k*.20),.15,.07,inner)
    p.bone='Body'


def cloud_pegasus(spec):
    p=Pet(spec)
    p.blob('PonyBody',(0,.32,1.31),(.71,.98,.70),'white',.81)
    p.blob('UprightNeck',(0,-.40,1.88),(.43,.46,.65),'white',.80)
    for row,y in [('Front',-.50),('Back',.86)]:
        for s,label in [(-1,'L'),(1,'R')]:
            p.joint(row+'Leg'+label,(s*.45,y,1.15),(s*.45,y,.30))
            p.blob(row+'Leg'+label,(s*.45,y,.69),(.25,.28,.59),'white',.70)
            p.box(row+'BlueHoof'+label,(s*.45,y-.025,.22),(.55,.63,.37),'75C9F1',.13)
            p.path(row+'HoofSeam'+label,[(s*.45,y-.345,.12),(s*.45,y-.35,.28)],.016,'429BCC')
    feather_wings(p,'E6E3D2','white',.87,(.56,.35,1.70))
    p.joint('Tail',(0,1.10,1.55),(.3,1.80,1.3))
    for i in range(3):p.path('CurledLavenderTailLock'+str(i),[(-i*.12+.1,1.02,1.59),(-.35-i*.11,1.43,1.63),(-.75-i*.1,1.60,1.17),(-.77-i*.1,1.68,.69),(-.56-i*.1,1.50,.67)],[.21,.25,.23,.18,.025],'lavender' if i!=1 else '8F76C9',16)
    p.bone='Body'
    p.ring('GoldCollar',(0,-.45,1.82),.44,.07,'gold',scale=(1,1.05,1))
    p.blob('CollarMedallion',(0,-.90,1.72),(.15,.052,.17),'gold')
    p.bone='Head'
    p.blob('HorseHead',(0,-.72,2.52),(.68,.62,.70),'white',.78)
    p.blob('HorseMuzzle',(0,-1.16,2.21),(.57,.36,.30),'F5CBD8',.72)
    p.blob('MuzzleChin',(0,-1.16,2.08),(.43,.28,.14),'FFE1E3',.75)
    p.nostrils('PinkNostril',(0,-1.50,2.29),.25,.064)
    p.path('MuzzleSmile',[(-.20,-1.475,2.09),(0,-1.49,2.045),(.23,-1.47,2.11)],.022,'9C647D')
    for s,label in [(-1,'L'),(1,'R')]:
        p.eye('Eye'+label,s*.37,-1.19,2.67,.25,'cyan')
        for k in range(2):p.path('Eyelash'+label+str(k),[(s*(.48+k*.055),-1.29,2.84),(s*(.60+k*.055),-1.29,2.91+k*.03)],.025,'navy')
        p.leaf('HorseEar'+label,(s*.40,-.40,3.0),(s*.49,-.30,3.70),.22,.15,'white')
        p.leaf('EarPinkInset'+label,(s*.42,-.55,3.10),(s*.49,-.40,3.58),.12,.035,'pink')
    p.leaf('SweptForelockLarge',(-.61,-.27,3.00),(.54,-1.02,2.84),.36,.18,'lavender',bend=(-.07,-.07,.40))
    p.leaf('SweptForelockLayer',(-.40,-.05,3.03),(.51,-.70,3.05),.31,.15,'AB8EDE',bend=(-.02,-.03,.29))
    p.path('ForelockCurl',[(.31,-1.00,3.01),(.54,-1.06,2.89),(.57,-1.04,2.65),(.43,-1.05,2.62)],[.19,.18,.13,.023],'lavender',16)
    for i in range(3):p.path('NeckManeLock'+str(i),[(-.43-i*.10,-.18,2.99-i*.15),(-.68-i*.07,.0,2.68-i*.13),(-.71-i*.06,-.05,2.15-i*.15),(-.84-i*.06,.12,1.91-i*.10)],[.24,.26,.23,.05],'lavender' if i!=1 else '947ACB',16)
    return p.finish()


def suncrest_griffin(spec):
    p=Pet(spec)
    p.blob('LionBody',(0,.33,1.23),(.79,.99,.72),'C78A43',.83)
    p.paws('C78A43','cream',.58,-.56,.76,scale=(.31,.39,.34))
    for obj in p.a.objects:
        if obj.get('Part','').startswith(('FrontLeg','FrontToe')):obj.data.materials[0]=material('gold')
    for s,label in [(-1,'L'),(1,'R')]:
        p.bone='FrontLeg'+label
        p.blob('EagleAnkle'+label,(s*.58,-.59,.51),(.25,.27,.38),'gold',.73)
        for k in range(3):
            x=s*.58+(k-1)*.18
            p.path('EagleToe'+label+str(k),[(x,-.55,.34),(x,-.81,.27),(x,-1.01,.26)],[.095,.11,.07],'gold',12)
            p.leaf('Talon'+label+str(k),(x,-.93,.30),(x,-1.10,.17),.07,.06,'navy',normal=(0,0,1))
        for i in range(2):p.ring('AnkleBand'+label+str(i),(s*.58,-.59,.48+i*.15),.235,.028,'B37620',scale=(1,1.08,1))
    feather_wings(p,'navy','gold',1.0,(.65,.43,1.55))
    p.joint('Tail',(0,1.12,1.18),(.6,1.65,1.50))
    p.path('LionTail',[(0,1.03,1.12),(.29,1.57,1.05),(.71,1.77,1.30),(.84,1.72,1.72),(.72,1.57,1.86)],[.15,.14,.13,.12,.10],'C78A43',14)
    p.leaf('TailTuft',(.72,1.58,1.71),(.65,1.53,2.10),.22,.16,'9B612D')
    p.bone='Head'
    p.blob('EagleHead',(0,-.55,2.38),(.77,.65,.75),'cream',.82)
    for s,label in [(-1,'L'),(1,'R')]:
        p.eye('Eye'+label,s*.37,-1.08,2.54,.27,'gold')
        p.brow('Brow'+label,s*.38,-1.13,2.88,'white',s*-.16,.30)
        for k in range(3):p.leaf('CheekFeather'+label+str(k),(s*.56,-.84,2.22-k*.08),(s*(.73-k*.09),-.55,1.93-k*.10),.15,.085,'cream' if k%2 else 'white')
    p.blob('BeakRoot',(0,-1.03,2.34),(.33,.32,.24),'gold',.75)
    p.path('HookedGoldenBeak',[(0,-1.15,2.39),(0,-1.40,2.30),(0,-1.53,2.13)],[.26,.23,.055],'gold',18)
    p.blob('BeakSmileInterior',(0,-1.35,2.09),(.25,.12,.10),'navy',.7)
    p.blob('LowerBeak',(0,-1.28,2.00),(.26,.23,.10),'EFA935',.8)
    p.blob('Tongue',(0,-1.433,2.061),(.13,.04,.047),'coral')
    for i in range(4):p.leaf('SweptGoldCrest'+str(i),(-.28+i*.18,-.14,2.91),(-.28+i*.18,.44,3.20+(.12 if i in(1,2) else 0)),.17,.10,'gold',bend=(0,-.02,.13))
    p.bone='Body'
    for row in range(3):
        for i in range(3-row):
            x=(i-(2-row)/2)*.28
            p.leaf('ChestFeather'+str(row)+str(i),(x,-.75,1.98-row*.20),(x,-.90,1.58-row*.20),.19,.07,'cream' if row%2==0 else 'white')
    return p.finish()


def halo_cherub(spec):
    p=Pet(spec)
    p.lathe('BellRobe',[(.64,.36),(.74,.45),(.74,.56),(.59,1.33),(.42,1.65),(.30,1.72)],'95CCE6',scale=(1,.75,1))
    p.ring('RobeHemGold',(0,0,.47),.70,.067,'gold',scale=(1,.78,1))
    p.ring('RobeHemCream',(0,0,.59),.69,.072,'cream',scale=(1,.78,1))
    for x in [-.26,0,.26]:p.leaf('RobeCreamPanel'+str(x),(x,-.36,1.54),(x*1.58,-.52,.62),.13,.045,'D9F0EC')
    for s,label in [(-1,'L'),(1,'R')]:
        p.joint('Arm'+label,(s*.40,0,1.48),(s*.78,-.05,1.11))
        p.blob('RobeSleeve'+label,(s*.58,-.015,1.30),(.31,.30,.26),'95CCE6',.75)
        p.ring('SleeveCuff'+label,(s*.74,-.02,1.20),.21,.038,'gold',rotation=(0,pi/2,0))
        p.blob('SmallHand'+label,(s*.84,-.05,1.12),(.21,.21,.19),'cream',.72)
        p.joint('Leg'+label,(s*.29,0,.51),(s*.29,-.10,.21))
        p.blob('Foot'+label,(s*.29,-.13,.24),(.25,.34,.19),'cream',.73)
        p.blob('GoldSole'+label,(s*.29,-.12,.11),(.25,.34,.065),'gold',.72)
    feather_wings(p,'E1DDC4','white',.79,(.51,.27,1.49))
    p.bone='Body'
    for s in [-1,1]:p.leaf('CollarLobe'+str(s),(s*.31,-.25,1.72),(s*.17,-.47,1.49),.20,.065,'cream')
    p.blob('CollarBrooch',(0,-.48,1.55),(.115,.062,.13),'gold')
    p.bone='Head'
    p.blob('RoundCherubFace',(0,-.06,2.34),(.74,.62,.71),'cream',.86)
    for s,label in [(-1,'L'),(1,'R')]:
        p.eye('Eye'+label,s*.31,-.65,2.36,.20,simple=True)
        p.cheek(s*.47,-.624,2.15,'pink',.16)
        p.leaf('SideHairLock'+label,(s*.58,-.05,2.82),(s*.66,-.18,2.22),.19,.13,'F2DCA5',bend=(s*.13,-.03,0))
    p.path('LittleSmile',[(-.12,-.68,2.17),(0,-.70,2.08),(.12,-.68,2.17)],.025,'navy')
    for i in range(3):p.leaf('SweptForelock'+str(i),(-.56+i*.32,-.28,2.85),(-.30+i*.30,-.67,2.69),.25,.13,'F2DCA5',bend=(-.08,-.06,.15))
    p.path('HairTuftHaloSupport',[(.12,.01,2.92),(.16,.04,3.12),(.20,.34,3.26)],[.20,.15,.10],'F2DCA5',14)
    p.ring('ConnectedGoldHalo',(.20,.045,3.24),.49,.09,'gold',rotation=(.12,.12,0))
    p.path('HaloGoldPhysicalBridge',[(.20,.30,3.22),(.20,.46,3.26),(.20,.54,3.27)],[.08,.09,.08],'gold',12)
    return p.finish()


def pebble_triceratops(spec):
    p=Pet(spec)
    p.blob('TurquoiseBody',(0,.35,1.19),(.84,1.02,.78),'24ADAB',.8)
    p.belly('cream',(0,-.72,1.1),.53,.68,4)
    p.paws('24ADAB','navy',.62,-.52,.78,scale=(.33,.40,.36))
    p.joint('Tail',(0,1.13,.96),(0,1.95,1.04))
    p.path('ShortDinosaurTail',[(0,1.06,1.06),(.14,1.54,.97),(.26,1.93,1.05),(.31,2.08,1.23)],[.30,.24,.14,.024],'24ADAB',16)
    for i in range(3):p.leaf('TailDorsalBump'+str(i),(.05+i*.08,1.30+i*.23,1.18),(.05+i*.08,1.37+i*.23,1.42-i*.04),.085,.065,'cream')
    p.bone='Head'
    p.blob('FrillDeepRim',(0,-.12,2.53),(1.09,.21,1.10),'187D8B',.8,36,24)
    p.blob('FrillTealFace',(0,-.285,2.53),(.98,.08,1.00),'31B7B1',.82,36,24)
    for i in range(9):
        angle=(-15+i*26.25)*pi/180
        x=.83*cos(angle);z=2.47+.89*sin(angle)
        p.leaf('CoralFrillFanPanel'+str(i+1),(x*.26,-.382,2.29+(z-2.47)*.18),(x,-.38,z),.205,.045,'ED8D9F')
        p.blob('CreamFrillKnob'+str(i+1),(1.025*cos(angle),-.22,2.53+1.065*sin(angle)),(.13,.18,.145),'cream',.74,20,14)
    p.blob('HugeHead',(0,-.65,2.20),(.87,.70,.69),'24ADAB',.74)
    p.blob('BroadMuzzle',(0,-1.18,1.99),(.61,.38,.32),'4BBFB4',.69)
    p.blob('CreamChin',(0,-1.16,1.80),(.48,.30,.16),'cream',.73)
    p.smile('HappySmile',(0,-1.543,1.91),.36,.18,True)
    p.nostrils('Nostril',(0,-1.542,2.15),.27,.057)
    for s,label in [(-1,'L'),(1,'R')]:
        p.eye('Eye'+label,s*.43,-1.20,2.34,.245,'cyan')
        p.brow('Brow'+label,s*.45,-1.16,2.64,'187D8B',s*-.13,.27)
        p.blob('HornCollar'+label,(s*.41,-.76,2.76),(.20,.19,.14),'navy',.8)
        p.path('BrowHorn'+label,[(s*.42,-.79,2.75),(s*.45,-.97,2.99),(s*.45,-1.18,3.17)],[.16,.12,.022],'cream',14)
    p.blob('NoseHornCollar',(0,-1.25,2.27),(.17,.15,.075),'navy',.8)
    p.path('SmallNoseHorn',[(0,-1.24,2.27),(0,-1.35,2.49),(0,-1.42,2.58)],[.135,.08,.018],'cream',14)
    return p.finish()


def fern_stegosaurus(spec):
    p=Pet(spec)
    p.blob('LowPearBody',(0,.30,1.09),(.83,1.18,.75),'83B837',.85)
    p.blob('CreamUnderside',(0,.04,.85),(.67,1.10,.40),'cream',.83)
    p.paws('83B837','cream',.64,-.45,.89,scale=(.33,.39,.36))
    p.bone='Body'
    for s,label in [(-1,'L'),(1,'R')]:
        for i in range(5):
            y=-.42+i*.35;h=[.48,.70,.86,.76,.51][i]
            z=1.61+.15*sin((i+1)*pi/6)
            p.leaf('DorsalPlate'+label+str(i+1),(s*.36,y,z),(s*.43,y+.07,z+h),.23,.11,'C56523',normal=(s,0,0))
            p.leaf('PlateOrangeInset'+label+str(i+1),(s*.476,y,z+.09),(s*.525,y+.07,z+h-.045),.16,.026,'orange',normal=(s,0,0))
        for i,(y,z,size) in enumerate([(-.13,1.30,.17),(.25,1.45,.16),(.68,1.31,.19),(.98,1.10,.13)]):
            p.blob('BodySpot'+label+str(i),(s*.804,y,z),(.038,size,size*.8),'4C8B35',.83,20,12)
    p.joint('Tail',(0,1.25,1.05),(0,2.17,1.60))
    tail=[(0,1.11,1.13),(.14,1.65,1.12),(.28,2.12,1.38),(.31,2.46,1.78),(.29,2.55,2.02)]
    p.path('UpcurvedTail',tail,[.35,.29,.22,.14,.07],'83B837',18)
    p.path('CreamTailUnderside',[(0,1.26,.84),(.17,1.69,.90),(.30,2.09,1.17),(.34,2.38,1.61)],[.16,.14,.10,.04],'cream',12)
    for s,label in [(-1,'L'),(1,'R')]:
        for i in range(2):p.path('TailSpike'+label+str(i+1),[(.29+s*.07,2.31+i*.16,1.70+i*.16),(.29+s*.25,2.38+i*.20,1.83+i*.18),(.29+s*.39,2.43+i*.20,1.92+i*.19)],[.10,.075,.014],'cream',12)
    p.bone='Head'
    p.blob('SmallDinosaurHead',(0,-1.0,1.52),(.60,.67,.58),'83B837',.83)
    p.blob('CreamMuzzle',(0,-1.49,1.31),(.49,.32,.25),'cream',.75)
    p.smile('CheerfulSmile',(0,-1.799,1.25),.31,.17,True)
    p.nostrils('Nostril',(0,-1.782,1.48),.22,.043)
    for s,label in [(-1,'L'),(1,'R')]:
        p.eye('Eye'+label,s*.30,-1.53,1.72,.22,'lime')
        p.brow('Brow'+label,s*.32,-1.47,1.98,'4C8B35',s*-.10,.23)
        p.blob('HeadSpot'+label,(s*.52,-1.17,1.76),(.048,.13,.12),'4C8B35')
    return p.finish()


def sky_pterodactyl(spec):
    p=Pet(spec)
    p.blob('UprightPterosaurBody',(0,.12,1.24),(.59,.56,.85),'lavender',.82)
    p.blob('CreamChest',(0,-.37,1.27),(.42,.13,.61),'cream',.83)
    for s,label in [(-1,'L'),(1,'R')]:
        p.joint('Leg'+label,(s*.31,.11,.82),(s*.36,-.13,.20))
        p.blob('HindLeg'+label,(s*.34,.08,.45),(.24,.27,.37),'lavender',.77)
        for k in range(3):p.path('HindToe'+label+str(k),[(s*.35+(k-1)*.15,-.03,.24),(s*.35+(k-1)*.16,-.29,.16),(s*.35+(k-1)*.18,-.46,.17)],[.10,.105,.045],'cream',12)
        p.joint('Wing'+label,(s*.42,.04,1.60),(s*1.40,.14,1.94))
        pts=[(s*.43,1.52),(s*.76,2.06),(s*1.26,2.25),(s*1.83,2.12),(s*1.70,1.76),(s*1.36,1.48),(s*1.10,1.07),(s*.81,1.20)]
        p.plate('PinkWingMembrane'+label,pts,.13,'EEA4C4',.17,.04)
        spar=[(s*.43,.02,1.55),(s*.76,.01,2.04),(s*1.25,.01,2.24),(s*1.82,.04,2.11)]
        p.path('ForelimbWingSpar'+label,spar,[.15,.14,.11,.055],'9274C9',14)
        p.path('ScallopedWingEdge'+label,[(x,.13,z) for x,z in pts[3:]+pts[:1]],.060,'9274C9',10)
        for i,end in enumerate(pts[4:7]):p.path('WingFinger'+label+str(i),[(s*1.23,.015,2.22),(s*(abs(end[0])+.12),.02,(2.22+end[1])*.5),(end[0],.08,end[1])],[.055,.042,.022],'9274C9',10)
        p.blob('WingThumbPad'+label,(s*.81,-.08,2.06),(.16,.13,.15),'cream',.78)
    p.joint('Tail',(0,.55,1.07),(0,1.10,.98))
    p.path('SmallTail',[(0,.51,1.08),(0,.89,.98),(0,1.17,1.13)],[.18,.12,.025],'lavender',12)
    p.bone='Head'
    p.blob('PterosaurHead',(0,-.23,2.48),(.73,.64,.73),'lavender',.80)
    p.path('SweptBackCrest',[(0,.12,2.99),(0,.48,3.32),(0,.90,3.38),(0,1.14,3.27)],[.27,.23,.14,.019],'9274C9',16)
    p.leaf('CrestPinkInset',(-.21,.14,3.12),(-.12,.94,3.34),.11,.036,'pink',normal=(-1,0,0),bend=(-.02,0,.04))
    for s,label in [(-1,'L'),(1,'R')]:
        p.eye('Eye'+label,s*.35,-.80,2.65,.285,'cyan')
        p.brow('Brow'+label,s*.37,-.74,2.99,'9274C9',s*-.10,.28)
    p.leaf('LongPeachBeak',(0,-.64,2.45),(0,-1.98,2.20),.45,.22,'F7BD93',normal=(0,0,1),bend=(0,0,.07))
    p.leaf('OpenBeakInterior',(0,-.80,2.18),(0,-1.86,2.15),.37,.05,'navy',normal=(0,0,1))
    p.leaf('CreamLowerJaw',(0,-.76,2.12),(0,-1.93,2.105),.36,.11,'cream',normal=(0,0,1),bend=(0,0,-.02))
    p.blob('SmallTongue',(0,-1.50,2.197),(.13,.24,.033),'coral')
    for s in [-1,1]:p.blob('BeakNostril'+str(s),(s*.24,-1.02,2.568),(.054,.067,.025),'B58273')
    return p.finish()


def tundra_mammoth(spec):
    p=Pet(spec)
    fur='B97E4B';dark='935C38';light='CC9661'
    p.blob('ShaggyBody',(0,.35,1.22),(.85,1.0,.77),fur,.78)
    p.paws(fur,'cream',.62,-.46,.80,scale=(.34,.40,.37))
    for s,label in [(-1,'L'),(1,'R')]:
        p.bone='Body'
        for row in range(2):
            for k in range(4):
                y=-.20+k*.36
                p.leaf('ShaggyBodyTuft'+label+str(row)+str(k),(s*(.67+row*.06),y,1.72-row*.29),(s*.86,y+.12,1.20-row*.31),.21,.11,light if (row+k)%3==0 else fur,normal=(s,0,0))
        for row,y in [('Front',-.46),('Back',.80)]:
            p.bone=row+'Leg'+label
            for k in range(3):p.leaf(row+'LegTuft'+label+str(k),(s*.62+(k-1)*.15,y-.30,.80),(s*.62+(k-1)*.18,y-.36,.45),.105,.055,light)
    p.joint('Tail',(0,1.24,1.35),(0,1.56,1.13))
    p.path('TinyTail',[(0,1.19,1.38),(.08,1.52,1.29),(.14,1.61,1.08)],[.10,.085,.05],dark)
    p.leaf('TailTuft',(.12,1.57,1.20),(.15,1.67,.91),.15,.12,fur)
    p.bone='Body'
    for i in range(3):p.ring('KnittedScarfWrap'+str(i),(0,-.17,1.53+i*.115),.81,.13,'teal' if i!=1 else '31BABC',scale=(1,1.04,1))
    p.box('ScarfHangingEnd',(-.42,-.99,1.24),(.42,.21,.72),'27B4B7',.08,rotation=(0,-.12,-.08))
    p.box('ScarfShortEnd',(.41,-.995,1.35),(.38,.22,.53),'27B4B7',.07,rotation=(0,.09,.08))
    for i in range(7):p.path('ScarfRaisedKnit'+str(i),[(-.58,-1.12,.96+i*.084),(-.43,-1.147,1.003+i*.084),(-.24,-1.12,.97+i*.084)],.022,'81D9D3',10,3)
    for i in range(4):p.path('ShortScarfRib'+str(i),[(.26,-1.126,1.16+i*.10),(.42,-1.15,1.19+i*.10),(.57,-1.125,1.17+i*.10)],.022,'81D9D3',10,3)
    for i in range(5):p.path('ShortScarfFringe'+str(i),[(-.57+i*.079,-1.02,.94),(-.56+i*.079,-1.03,.84)],.031,'teal')
    p.bone='Head'
    p.blob('HugeMammothHead',(0,-.53,2.31),(.88,.72,.83),fur,.79)
    for s,label in [(-1,'L'),(1,'R')]:
        p.blob('CaramelEar'+label,(s*.83,-.23,2.35),(.36,.21,.49),dark,.79)
        p.blob('EarInset'+label,(s*.85,-.418,2.37),(.25,.055,.36),'D9AA7C',.78)
        p.eye('KindEye'+label,s*.43,-1.11,2.42,.25,'teal')
        p.brow('Brow'+label,s*.45,-1.10,2.74,light,s*-.10,.29)
        p.path('CurvedIvoryTusk'+label,[(s*.48,-1.00,1.96),(s*.64,-1.26,1.75),(s*.66,-1.52,1.75),(s*.59,-1.68,1.99)],[.15,.12,.087,.018],'cream',16)
        for k in range(3):p.leaf('CheekFur'+label+str(k),(s*(.67-k*.04),-.81,2.26-k*.08),(s*(.78-k*.07),-.78,1.95-k*.10),.17,.095,light if k==0 else fur)
    p.path('LiftedTrunk',[(0,-1.05,2.30),(0,-1.30,2.01),(0,-1.40,1.62),(0,-1.63,1.44),(0,-1.87,1.57),(0,-1.95,1.86)],[.29,.28,.24,.22,.19,.16],fur,20,6)
    for i in range(4):
        z=2.06-i*.13;y=-1.525-i*.03
        p.path('BroadTrunkCrease'+str(i),[(-.19+i*.012,y+.055,z),(-.10,y-.018,z-.020),(0,y-.04,z-.025),(.10,y-.018,z-.020),(.19-i*.012,y+.055,z)],.018,dark,10,3)
    p.blob('TrunkEndPad',(0,-1.95,1.88),(.163,.16,.07),light,.78)
    for s in [-1,1]:p.blob('TrunkNostril'+str(s),(s*.069,-1.976,1.942),(.035,.05,.022),dark,1,16,10)
    for i in range(5):p.leaf('ForeheadHairTuft'+str(i),(-.56+i*.25,-.29,2.96),(-.44+i*.23,-.96,2.79+(i%2)*.12),.23,.14,light if i in(1,3) else fur,bend=(-.10,0,.16))
    return p.finish()


def crowned_pig(spec):
    p=Pet(spec)
    p.blob('PlumpPigBody',(0,.36,1.16),(.88,.99,.72),'ECA4B9',.75)
    for row,y in [('Front',-.42),('Back',.83)]:
        for s,label in [(-1,'L'),(1,'R')]:
            p.joint(row+'Leg'+label,(s*.61,y,.95),(s*.61,y,.24))
            p.blob(row+'PinkLeg'+label,(s*.61,y,.55),(.27,.31,.40),'ECA4B9',.69)
            for k in [-1,1]:p.box(row+'SplitHoof'+label+str(k),(s*.61+k*.134,y-.03,.19),(.26,.61,.30),'5D3B40',.09)
    p.joint('Tail',(0,1.10,1.15),(.25,1.6,1.44))
    pts=[]
    for i in range(25):
        t=2*pi*i/20
        pts.append((.18*cos(t),1.14+i*.025,1.25+.18*sin(t)))
    p.path('CurlyPigTail',pts,[.08-i*.0015 for i in range(25)],'ECA4B9',12,1)
    p.bone='Body'
    for s,label in [(-1,'L'),(1,'R')]:
        pts=[(s*.55,-.14,1.84),(s*.89,.30,1.82),(s*1.02,1.04,1.43),(s*1.03,1.08,.76),(s*1.01,.34,.77),(s*.92,-.08,1.14)]
        verts=pts+[(x,y+.08,z) for x,y,z in pts]
        faces=[(0,1,2,3,4,5),(11,10,9,8,7,6)]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
        cape=p.tag(p.a.mesh('RoyalCapeSide'+label,verts,faces,'B52D43',True));p.a.bevel(cape,.065,3)
        p.path('CapeCreamTrim'+label,[pts[2],pts[3],pts[4],pts[5]],[.08,.08,.08,.07],'cream',12)
        p.path('CapeFold'+label,[(s*.88,.10,1.71),(s*1.046,.61,1.27),(s*1.045,.84,.86)],[.029,.035,.022],'8A2038',10)
        p.blob('GoldShoulderClasp'+label,(s*.61,-.28,1.66),(.14,.09,.15),'gold')
    p.path('CreamCapeCollar',[(-.67,-.15,1.70),(-.37,-.61,1.61),(0,-.73,1.62),(.37,-.61,1.61),(.67,-.15,1.70)],.10,'cream',14)
    p.bone='Head'
    p.blob('SquareRoundedPigHead',(0,-.59,2.26),(.84,.66,.70),'F1B1C3',.52)
    p.box('BroadBoxySnout',(0,-1.26,2.12),(1.05,.40,.50),'E792AC',.17)
    p.box('SnoutFaceInset',(0,-1.469,2.135),(.83,.045,.34),'F6B5C4',.12)
    for s,label in [(-1,'L'),(1,'R')]:
        p.blob('DeepOvalNostril'+label,(s*.23,-1.496,2.14),(.10,.035,.13),'90455C',.8,20,14)
        p.eye('Eye'+label,s*.44,-1.204,2.51,.218,simple=True)
        p.brow('Brow'+label,s*.45,-1.18,2.81,'C47C99',s*-.1,.24)
        p.leaf('FloppyPigEar'+label,(s*.64,-.30,2.78),(s*.93,-.67,2.88),.32,.13,'ECA4B9',bend=(s*.09,0,.17))
        p.leaf('RoseEarInset'+label,(s*.70,-.423,2.82),(s*.89,-.762,2.89),.19,.026,'CB7D98',bend=(s*.07,0,.10))
        p.path('ConfidentSmile'+label,[(s*.48,-1.34,1.97),(s*.57,-1.26,1.98),(s*.63,-1.21,2.05)],.023,'90455C')
    p.lathe('CrownBand',[(.51,2.90),(.56,2.94),(.56,3.13),(.52,3.16)],'gold',scale=(1,.80,1),n=40)
    crown=[(-.51,3.07),(-.55,3.59),(-.24,3.34),(0,3.78),(.24,3.34),(.55,3.59),(.51,3.07)]
    p.plate('ThreePointGoldCrown',crown,.14,'gold',-.32,.055)
    p.plate('CrownInnerGoldFace',[(-.44,3.14),(-.46,3.43),(-.22,3.25),(0,3.58),(.22,3.25),(.46,3.43),(.44,3.14)],.038,'FFE37B',-.412,.028)
    p.box('RedSquareCrownJewel',(0,-.453,3.20),(.24,.08,.24),'red',.04)
    return p.finish()


def waffle_tortoise(spec):
    p=Pet(spec)
    p.blob('CreamTortoiseBody',(0,.08,.82),(.81,.90,.41),'cream',.77)
    p.paws('DFAE49','cream',.70,-.53,.66,z=.29,scale=(.29,.36,.29))
    p.bone='Body'
    p.blob('DarkShellSeam',(0,.18,1.13),(1.035,.95,.25),'9C6227',.58,40,20)
    p.blob('RoundedWaffleShellBase',(0,.18,1.30),(1.04,.96,.39),'E4AB35',.61,40,22)
    def shell_point(x,y,z_offset=0):
        z=1.23+.83*max(.01,1-(x*x+y*y)*.43)**.70+z_offset
        return (x*(1-.18*y*y)**.5,y*(1-.18*x*x)**.5+.18,z)
    p.a.root['WafflePocketCount']=9
    for row in range(3):
        for col in range(3):
            cx=(col-1)*2/3;cy=(row-1)*2/3
            outline=[]
            for q in range(4):
                angle=q*pi/2
                ox=.178*(1 if cos(angle+pi/4)>0 else -1)
                oy=.178*(1 if sin(angle+pi/4)>0 else -1)
                for j in range(7):
                    t=angle+j*pi/12
                    outline.append((ox+.053*cos(t),oy+.053*sin(t)))
            n=len(outline);verts=[]
            for layer in range(5):
                for dx,dy in outline:
                    if layer in(0,4):
                        f=(1/3)/max(abs(dx),abs(dy));x=cx+dx*f;y=cy+dy*f
                        point=shell_point(x,y,.012)
                        if layer==4:point=(point[0],point[1],1.20)
                    else:
                        f=[0,1,.92,.89][layer]
                        point=shell_point(cx+dx*f,cy+dy*f,[0,.012,-.043,-.19][layer])
                    verts.append(point)
            faces=[]
            for a,b in [(0,1),(1,2),(2,3),(4,0)]:
                for i in range(n):faces.append((a*n+i,a*n+(i+1)%n,b*n+(i+1)%n,b*n+i))
            faces.append(tuple(range(3*n,4*n)))
            faces.append(tuple(reversed(range(4*n,5*n))))
            cell=p.tag(p.a.mesh('DomedRecessedWaffleCell_'+str(row+1)+'_'+str(col+1),verts,faces,'F3BF56',True))
            cell.data.materials.append(material('C2832F'))
            for face in cell.data.polygons:
                if 2*n<=face.index<3*n or face.index==4*n:face.material_index=1
            p.a.bevel(cell,.012,3)
    syrup=[(-.91,.28),(-.77,.05),(-.45,.09),(-.31,.35),(-.28,.70),(-.46,.91),(-.75,.91),(-.93,.70)]
    center=(-.63,.48)
    verts=[shell_point(*center,.055)]+[shell_point(x,y,.055) for x,y in syrup]+[shell_point(x,y,.008) for x,y in syrup]
    faces=[(0,1+i,1+(i+1)%8) for i in range(8)]+[(1+i,1+(i+1)%8,9+(i+1)%8,9+i) for i in range(8)]+[tuple(reversed(range(9,17)))]
    obj=p.tag(p.a.mesh('ConformingCaramelSyrupPatch',verts,faces,'A35A24',True));p.a.bevel(obj,.025,3)
    p.path('RoundedSyrupSideDrip',[shell_point(-.91,.36,.06),(-.997,.54,1.64),(-1.03,.54,1.38)],[.115,.115,.08],'A35A24',14,5)
    p.blob('SyrupDripRoundTip',(-1.03,.54,1.38),(.08,.09,.09),'A35A24')
    bp=shell_point(-.61,.50,.17)
    p.box('ButterSquare',bp,(.45,.45,.25),'FFE7A0',.07,rotation=(.13,.16,-.17))
    p.joint('Tail',(0,.93,.81),(0,1.49,.86))
    p.path('TinyPointedTail',[(0,.91,.78),(0,1.28,.76),(0,1.54,.89)],[.15,.11,.018],'DFAE49',14)
    p.bone='Head'
    p.blob('CreamNeck',(0,-.80,1.03),(.44,.39,.37),'cream',.78)
    p.blob('HappyGoldenHead',(0,-1.19,1.29),(.61,.55,.56),'E5B552',.78)
    p.blob('CreamMuzzle',(0,-1.58,1.12),(.47,.28,.22),'cream',.73)
    for s,label in [(-1,'L'),(1,'R')]:
        p.eye('Eye'+label,s*.32,-1.626,1.43,.223,'gold')
        p.brow('Brow'+label,s*.33,-1.60,1.68,'D99C36',s*-.12,.23)
    p.smile('HappySmile',(0,-1.854,1.08),.28,.15,True)
    p.nostrils('Nostril',(0,-1.84,1.25),.17,.035)
    return p.finish()


def syrup_cap(p,name,z,radius,color):
    n=80;vertices=[];faces=[]
    for row in range(4):
        for i in range(n):
            t=2*pi*i/n
            drop=0
            for center,depth,width in [(-pi/2,.36,.20),(-pi/2-.82,.22,.18),(-pi/2+.73,.25,.16),(.44,.17,.18),(2.7,.16,.2)]:
                delta=(t-center+pi)%(2*pi)-pi
                drop+=depth*max(0,1-(delta/width)**2)**.6 if abs(delta)<width else 0
            rad=[radius*.91,radius,radius,radius*.92][row]
            zz=[z+.025,z,z-.075-drop,z-.098-drop][row]
            vertices.append((rad*cos(t),rad*sin(t),zz))
    faces.append(tuple(reversed(range(n))))
    for row in range(3):
        for i in range(n):faces.append((row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i))
    faces.append(tuple(range(3*n,4*n)))
    return p.tag(p.a.mesh(name,vertices,faces,color,True))


def pancake_pal(spec):
    p=Pet(spec)
    for i in range(3):
        z=.40+i*.47
        p.lathe('Pancake'+str(i+1)+'_FluffyBody',[(.73,z),(.92,z+.025),(1.0,z+.12),(1.015,z+.22),(.99,z+.34),(.91,z+.43),(.76,z+.46)],'F2CF84')
        p.lathe('Pancake'+str(i+1)+'_ToastedTop',[(0,z+.474),(.78,z+.474),(.93,z+.44),(.98,z+.375)],'DEA343')
        p.ring('Pancake'+str(i+1)+'_SoftCreamSeam',(0,0,z+.15),.987,.031,'FBE5AC')
    syrup_cap(p,'GlossyCaramelCapWithRoundedDrips',1.86,1.019,'A85D27')
    p.box('AttachedButterCube',(0,.04,2.035),(.57,.52,.30),'FFE6A0',.08,rotation=(.035,.06,-.25))
    for s,label in [(-1,'L'),(1,'R')]:
        p.bone='Body'
        p.eye('Eye'+label,s*.36,-.94,1.13,.18,simple=True)
        p.cheek(s*.63,-.802,.94,'F2A0A3',.13)
        p.joint('Arm'+label,(s*.87,.04,1.10),(s*1.28,-.1,.87))
        p.path('CreamArm'+label,[(s*.88,.04,1.14),(s*1.17,-.06,1.03),(s*1.29,-.14,.83)],[.13,.14,.13],'cream',14)
        p.blob('CreamMitten'+label,(s*1.29,-.15,.81),(.19,.17,.19),'cream',.72)
        p.blob('Thumb'+label,(s*1.18,-.29,.88),(.075,.10,.10),'cream',.83)
        p.joint('Leg'+label,(s*.42,0,.53),(s*.42,-.17,.19))
        p.blob('CaramelBoot'+label,(s*.42,-.22,.235),(.30,.43,.23),'A66A32',.63)
        p.box('BootSole'+label,(s*.42,-.22,.088),(.57,.77,.13),'875228',.06)
    p.bone='Body'
    p.path('TinyHappySmile',[(-.16,-1.005,.96),(0,-1.035,.86),(.16,-1.005,.96)],.025,'navy')
    return p.finish()


def velvet_jumper(spec):
    p=Pet(spec)
    p.blob('SinglePlushAbdomen',(0,.48,1.29),(.88,.99,.83),'774D93',.84)
    p.bone='Head'
    p.blob('AttachedSpiderHead',(0,-.70,1.05),(.77,.61,.60),'956CA8',.79)
    for s,label in [(-1,'L'),(1,'R')]:
        p.blob('CreamEyeSocket'+label,(s*.34,-1.185,1.24),(.315,.15,.35),'cream',.87)
        p.eye('HugeEye'+label,s*.34,-1.296,1.24,.257,simple=True)
        p.eye('TinyEye'+label,s*.19,-1.07,1.61,.088,simple=True)
        p.cheek(s*.58,-1.123,.96,'pink',.12)
    p.smile('TinyMouth',(0,-1.304,.87),.16,.11,True)
    for s,label in [(-1,'L'),(1,'R')]:
        for i in range(4):
            y=-.63+i*.48
            x0=.59 if i==0 else .69
            out=1.22+(.12 if i in(1,2) else 0)
            bendy=y+(-.28 if i<2 else .30)
            footy=y+(-.48 if i<2 else .52)
            p.joint('Leg'+label+str(i+1),(s*x0,y,1.02),(s*(out+.18),footy,.30))
            p.path('Leg'+label+str(i+1)+'_Upper',[(s*x0,y,1.00),(s*(out-.22),bendy,1.02),(s*out,bendy,.80)],[.17,.17,.16],'774D93',16)
            p.blob('Leg'+label+str(i+1)+'_NavyJoint',(s*out,bendy,.80),(.18,.18,.18),'navy',.85,20,14)
            p.path('Leg'+label+str(i+1)+'_Lower',[(s*out,bendy,.79),(s*(out+.14),footy,.48),(s*(out+.12),footy,.30)],[.15,.15,.14],'956CA8',16)
            p.blob('Leg'+label+str(i+1)+'_CreamTip',(s*(out+.12),footy,.255),(.18,.20,.13),'cream',.79,20,14)
    p.bone='Body'
    def heart_surface(x,y,offset):
        e=abs(x/.88)**(2/.84)+abs((y-.48)/.99)**(2/.84)
        return(x,y,1.29+.83*max(0,1-e)**(.84/2)+offset)
    outline=[]
    for i in range(48):
        t=2*pi*i/48
        x=.022*16*sin(t)**3;y=.15+.021*(13*cos(t)-5*cos(2*t)-2*cos(3*t)-cos(4*t))
        outline.append((x,y))
    verts=[heart_surface(0,.15,.023)]+[heart_surface(x,y,.023) for x,y in outline]+[heart_surface(x,y,.003) for x,y in outline]
    faces=[(0,1+i,1+(i+1)%48) for i in range(48)]+[(1+i,1+(i+1)%48,49+(i+1)%48,49+i) for i in range(48)]+[tuple(reversed(range(49,97)))]
    p.tag(p.a.mesh('ConformingPeachHeartMark',verts,faces,'F6B6B2',True))
    p.a.root['RequiredLegCount']=8
    return p.finish()


def patchwork_zombie(spec):
    p=Pet(spec)
    p.blob('SquatHoodie',(0,.04,1.19),(.62,.42,.60),'695079',.62)
    p.ring('HoodieHem',(0,.04,.76),.53,.072,'483B5F',scale=(1,.72,1))
    p.box('KangarooPocketInset',(0,-.39,1.11),(.68,.09,.29),'574366',.06)
    p.path('PocketTopSeam',[(-.32,-.449,1.18),(0,-.46,1.17),(.32,-.449,1.18)],.022,'92739F')
    p.path('HoodRim',[(-.53,-.10,1.53),(-.41,-.35,1.71),(0,-.43,1.63),(.41,-.35,1.71),(.53,-.10,1.53)],.115,'82618E',14)
    for s,label in [(-1,'L'),(1,'R')]:
        p.bone='Body'
        p.path('CreamDrawstring'+label,[(s*.15,-.42,1.64),(s*.18,-.47,1.43),(s*.15,-.47,1.30)],.023,'cream',10)
        p.box('DrawstringTip'+label,(s*.15,-.477,1.29),(.045,.045,.10),'gold',.014)
        p.joint('Arm'+label,(s*.46,0,1.43),(s*.87,-.05,1.02))
        p.blob('ShortHoodieSleeve'+label,(s*.65,.01,1.29),(.30,.32,.30),'695079',.66)
        p.ring('SleeveCuff'+label,(s*.80,-.01,1.11),.22,.055,'483B5F',rotation=(0,pi/2,0),scale=(1,1,.9))
        p.blob('MintHand'+label,(s*.91,-.06,1.03),(.21,.23,.23),'9BCEB5',.66)
        for k in range(2):p.path('HandFingerSeam'+label+str(k),[(s*.95,-.275,1.04+k*.065),(s*1.055,-.26,1.05+k*.065)],.012,'548F84',8)
        p.joint('Leg'+label,(s*.30,.015,.76),(s*.31,-.09,.25))
        p.box('TealShortsLeg'+label,(s*.30,.015,.67),(.54,.66,.40),'315C66',.105)
        p.box('ShortsCuff'+label,(s*.30,-.01,.51),(.55,.69,.13),'23454E',.055)
        p.blob('MintLeg'+label,(s*.31,-.01,.36),(.19,.22,.27),'9BCEB5',.69)
        p.blob('BareFoot'+label,(s*.31,-.21,.18),(.27,.36,.16),'9BCEB5',.65)
        for k in range(2):p.path('ToeSeam'+label+str(k),[(s*.31+(k-.5)*.16,-.557,.16),(s*.31+(k-.5)*.16,-.56,.22)],.012,'548F84',8)
    p.bone='Head'
    p.blob('SquareRoundedMintHead',(0,-.04,2.31),(.84,.62,.75),'A4D7BD',.43)
    for s,label in [(-1,'L'),(1,'R')]:p.box('RectangularEar'+label,(s*.86,-.06,2.25),(.25,.28,.34),'9BCEB5',.08)
    p.eye('GlossyEye',.37,-.657,2.48,.238,simple=True)
    p.blob('CreamButtonEye',(-.36,-.654,2.46),(.26,.075,.275),'cream',.80)
    p.ring('ButtonRaisedRim',(-.36,-.71,2.46),.217,.025,'D4C6A5',rotation=(pi/2,0,0))
    for s in [-1,1]:p.path('CrossedButtonStitch'+str(s),[(-.36-.105,-.745,2.46+s*.11),(-.36+.105,-.745,2.46-s*.11)],.027,'navy',10)
    p.smile('GoofyTwoToothSmile',(0,-.663,2.08),.40,.25,True,2)
    p.box('CreamForeheadClothPatch',(-.31,-.627,2.86),(.48,.077,.29),'EDE0BC',.045,rotation=(0,0,-.10))
    for i in range(4):
        x=-.48+i*.115
        for z in [2.745,2.98]:p.path('PatchHorizontalStitch'+str(i)+str(z),[(x-.016,-.68,z-.027),(x+.016,-.68,z+.027)],.012,'6B7C76',8)
    for x in [-.548,-.078]:
        for i in range(2):p.path('PatchSideStitch'+str(x)+str(i),[(x-.026,-.68,2.805+i*.085),(x+.026,-.68,2.805+i*.085)],.012,'6B7C76',8)
    p.brow('FriendlyBrow',.37,-.635,2.81,'6BA38F',-.10,.25)
    return p.finish()


def sunfeather_phoenix(spec):
    p=Pet(spec)
    p.blob('RoundOrangeBird',(0,.07,1.39),(.77,.71,.86),'EB8032',.84)
    for s,label in [(-1,'L'),(1,'R')]:
        p.joint('Leg'+label,(s*.33,0,.74),(s*.33,-.18,.28))
        p.blob('GoldAnkle'+label,(s*.33,-.02,.43),(.16,.18,.27),'gold',.8)
        for k in range(3):p.path('GoldenToe'+label+str(k),[(s*.33+(k-1)*.08,-.07,.27),(s*.33+(k-1)*.15,-.37,.16),(s*.33+(k-1)*.20,-.52,.16)],[.095,.105,.049],'gold',12)
        p.joint('Wing'+label,(s*.61,.15,1.83),(s*1.10,.34,1.21))
        p.blob('WingShoulder'+label,(s*.66,.18,1.68),(.30,.26,.43),'CD3938',.82)
        for k in range(4):
            start=(s*(.62+k*.04),.02,1.91-k*.12)
            end=(s*(1.20-k*.055),.34+k*.055,1.49-k*.24)
            p.leaf('RedWingFeather'+label+str(k),start,end,.21,.12,'CD3938',bend=(s*.09,-.05,.025))
            p.leaf('GoldWingInset'+label+str(k),(start[0],start[1]-.185,start[2]-.025),(end[0]*.982,end[1]-.18,end[2]+.04),.13,.032,'gold',bend=(s*.09,-.05,.025))
    p.joint('Tail',(0,.60,.98),(0,1.62,1.54))
    for i,(x,y,z) in enumerate([(-1.04,1.52,2.74),(0,1.99,3.03),(1.04,1.52,2.74)]):
        start=(0,.55,.95);end=(x,y,z)
        p.leaf('SolidTailFlame'+str(i+1),start,end,.34,.15,'C9363C',bend=(x*.18,.18,-.10))
        p.leaf('TailOrangeLayer'+str(i+1),(0,.53,1.10),(x*.95,y-.10,z-.04),.26,.095,'orange',bend=(x*.15,.15,-.07))
        p.leaf('TailYellowLayer'+str(i+1),(x*.30,1.03,1.59),(x*.92,y-.19,z-.07),.16,.045,'yellow',bend=(x*.09,.07,-.02))
    p.bone='Body'
    for row in range(3):
        for i in range(3-row):
            x=(i-(2-row)/2)*.29
            p.leaf('CreamChestFeather'+str(row)+str(i),(x,-.58,1.90-row*.23),(x,-.70,1.44-row*.23),.21,.082,'cream')
    p.bone='Head'
    p.blob('OversizedBirdHead',(0,-.32,2.28),(.74,.64,.67),'ED8B38',.82)
    for s,label in [(-1,'L'),(1,'R')]:
        p.eye('ExpressiveEye'+label,s*.36,-.855,2.43,.282,'cyan')
        p.brow('RedBrow'+label,s*.37,-.84,2.79,'CD3938',s*-.12,.29)
        for k in range(2):p.leaf('CheekFeather'+label+str(k),(s*.55,-.67,2.14-k*.10),(s*.78,-.42,1.99-k*.13),.16,.09,'orange')
    p.blob('GoldenBeak',(0,-.98,2.13),(.30,.31,.19),'gold',.72)
    p.smile('BeakSmile',(0,-1.272,2.058),.22,.12,True)
    p.blob('LowerGoldenBeak',(0,-.99,1.96),(.23,.23,.078),'gold',.75)
    for i in range(3):
        x=(i-1)*.25
        start=(x,-.18,2.79);end=(x+(.11 if i==2 else -.08),.78,3.38+(.20 if i==1 else 0))
        p.leaf('ThreePartCrest'+str(i+1),start,end,.29,.13,'orange',bend=(-.06,-.09,.19))
        p.leaf('YellowCrestInset'+str(i+1),(x,-.37,2.82),(end[0],end[1]-.19,end[2]-.045),.19,.035,'yellow',bend=(-.06,-.09,.19))
    return p.finish()


def build(spec):
    builders={'P21':crystal_drake,'P22':ember_wyrmling,'P23':cloud_pegasus,'P24':suncrest_griffin,'P25':halo_cherub,'P26':pebble_triceratops,'P27':fern_stegosaurus,'P28':sky_pterodactyl,'P29':tundra_mammoth,'P30':crowned_pig,'P31':waffle_tortoise,'P32':pancake_pal,'P33':velvet_jumper,'P34':patchwork_zombie,'P35':sunfeather_phoenix}
    return builders[spec['id']](spec)
