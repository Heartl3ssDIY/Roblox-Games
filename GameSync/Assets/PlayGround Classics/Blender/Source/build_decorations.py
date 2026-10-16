from assetlib import *

def clover(a,name,center,size,color='gold'):
    x,y,z=center
    heart=[(0,0),(-.2,.16),(-.29,.32),(-.27,.45),(-.15,.51),(0,.43),(.15,.51),(.27,.45),(.29,.32),(.2,.16)]
    for i in range(3):
        t=i*2*pi/3
        points=[(x+(u*cos(t)-v*sin(t))*size,z+(u*sin(t)+v*cos(t))*size)for u,v in heart]
        a.prism(name+'HeartLeaf'+str(i),points,.16*size,color,y=y,bevel=.045*size)
        points=[(x+(u*cos(t)-v*sin(t))*.76*size,z+(u*sin(t)+v*cos(t))*.76*size)for u,v in heart]
        a.prism(name+'InsetLeafFace'+str(i),points,.026*size,'yellow',y=y-.079*size,bevel=.013*size)
    a.tube(name+'Stem',[(x,y,z),(x+.03*size,y,z-.26*size),(x+.11*size,y,z-.43*size)],.066*size,color)

def sculpted_loft(a,name,rings,color,segments=48,lobes=0,amplitude=0,yscale=1):
    vertices=[];faces=[]
    for r,z in rings:
        for i in range(segments):
            t=2*pi*i/segments
            radius=r*(1+amplitude*cos(lobes*t))
            vertices.append((radius*cos(t),radius*sin(t)*yscale,z))
    faces.append(tuple(reversed(range(segments))))
    for j in range(len(rings)-1):
        for i in range(segments):
            n=(i+1)%segments
            faces.append((j*segments+i,j*segments+n,(j+1)*segments+n,(j+1)*segments+i))
    faces.append(tuple(range((len(rings)-1)*segments,len(rings)*segments)))
    return a.mesh(name,vertices,faces,color,True)

def inset_cut(a,body,name,points,back=-.62):
    cutter=a.prism(name+'CutTool',points,.75,'orange',y=back-.36,bevel=.02)
    modifier=body.modifiers.new(name+' recessed carving',checked_enum(bpy.types.Modifier,'type','BOOLEAN'))
    modifier.operation=checked_enum(modifier,'operation','DIFFERENCE')
    modifier.solver=checked_enum(modifier,'solver','EXACT');modifier.object=cutter
    cutter.hide_render=True;cutter.hide_set(True);a.objects.remove(cutter)
    cutter['ConstructionTool']=True
    a.prism(name+'DarkInterior',points,.06,'navy',y=back+.012,bevel=.012)
    cx=sum(x for x,z in points)/len(points);cz=sum(z for x,z in points)/len(points)
    a.prism(name+'WarmInterior',[(cx+(x-cx)*.84,cz+(z-cz)*.77)for x,z in points],.026,'yellow',y=back-.026,bevel=.008)

def scalloped_band(a,name,radius,z,height,waves,color,depth=.055):
    n=72;vertices=[];faces=[]
    for layer in range(4):
        for i in range(n):
            t=2*pi*i/n;r=radius if layer<2 else radius-depth
            h=z+height if layer in(1,2)else z-.05*(1+cos(waves*t))
            vertices.append((r*cos(t),r*sin(t),h))
    for layer in range(4):
        nxt=(layer+1)%4
        for i in range(n):faces.append((layer*n+i,layer*n+(i+1)%n,nxt*n+(i+1)%n,nxt*n+i))
    ob=a.mesh(name,vertices,faces,color,True);a.bevel(ob,.018,2);return ob

def snow_tier(a,name,z,r,h,start=.46):
    n=48;verts=[];faces=[]
    profile=[(.0,.91),(.14,.97),(.46,.65),(.79,.3),(1,.035/r)]
    def radius_at(t):
        for (u0,r0),(u1,r1)in zip(profile,profile[1:]):
            if t<=u1:return r*(r0+(r1-r0)*(t-u0)/(u1-u0))+.023
        return .055
    for j in range(5):
        for i in range(n):
            t=2*pi*i/n
            frac=start+(1-start)*j/4
            if j==0:frac+=.035*cos(8*t)
            radius=radius_at(frac);zz=z+h*frac
            verts.append((radius*cos(t),radius*sin(t),zz))
    for j in range(4):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    faces.append(tuple(reversed(range(n))));faces.append(tuple(range(4*n,5*n)))
    return a.mesh(name,verts,faces,'cream',True)

def leaf(a,name,points,color='green',depth=.14):
    return a.prism(name,points,depth,color,bevel=.04)

def star(a,name,x,y,z,r,color='gold',depth=.16):
    points=[]
    for i in range(10):
        angle=pi/2+pi*i/5; rad=r if i%2==0 else r*.46
        points.append((x+cos(angle)*rad,z+sin(angle)*rad))
    return a.prism(name,points,depth,color,y=y,bevel=.045)

def eyes(a,y,z,spread=.37,r=.12):
    for x in (-spread,spread):
        a.sphere('EyeRim',(x,y,z),(r*1.22,.07,r*1.35),'cream',16,12)
        a.sphere('Eye',(x,y-.055,z),(r,.06,r*1.17),'navy',16,12)
        a.sphere('EyeGlint',(x-r*.3,y-.105,z+r*.35),(r*.3,.025,r*.32),'white',12,8)

def build(spec):
    a=Asset(spec); id=spec['id']
    if id=='D01':
        body=sculpted_loft(a,'SculptedSixLobePumpkin',[(.25,.04),(.53,.1),(.78,.25),(.94,.48),(1.01,.76),(.97,1.05),(.86,1.31),(.65,1.48),(.38,1.53),(.17,1.48)],'orange',72,6,.085,.91)
        a.bevel(body,.012,2)
        a.lathe('StemSocket',[(.21,1.47),(.3,1.49),(.27,1.54),(.17,1.61)],'#287D2D',segments=12)
        a.tube('BentStem',[(0,0,1.5),(0,0,1.7),(.045,0,1.91),(.18,0,2.025),(.32,0,2.01)],[.17,.16,.15,.125,.08],'green',10)
        for x in(-.35,.35):
            inset_cut(a,body,'Eye'+str(x),[(x-.21,.92),(x+.21,.92),(x,1.25)],-.63)
        mouth=[(-.64,.8),(-.49,.46),(-.2,.35),(.19,.35),(.48,.46),(.64,.8),(.31,.72),(.31,.64),(.13,.64),(.13,.69),(-.12,.69),(-.12,.76),(-.31,.76),(-.31,.69)]
        inset_cut(a,body,'SmilingMouth',mouth,-.59)
    elif id=='D02':
        a.box('DarkCrateCore',(0,0,.98),(1.84,1.64,1.84),'navy',.12)
        for y in(-.86,.86):
            for i in range(4):
                a.box('Plank',(0,y,.31+i*.43),(1.8,.14,.37),'purple' if i%2 else '#874CCD',.035)
            for angle in(-.69,.69): a.box('DiagonalBrace',(0,y*1.085,.98),(.22,.13,2.03),'#9B65DB',.035,(0,angle,0))
        for x in(-.89,.89):
            for i in range(4):a.box('SidePlank',(x,0,.3+i*.43),(.15,1.7,.37),'purple',.03)
        for i in range(4):a.box('LidPlank',(-.67+i*.44,0,1.94),(.4,1.72,.13),'#9B65DB',.03)
        for x in(-.79,.79):
            for y in(-.75,.75):
                for z in(.22,1.75):
                    a.box('CornerGuard',(x,y,z),(.39,.4,.4),'navy',.075)
                    a.sphere('Rivet',(x,y+(.22 if y>0 else-.22),z),(.085,.025,.085),'silver',12,8)
        a.box('PeekingSlit',(0,-.99,1.17),(1.0,.07,.2),'navy',.035)
        for x in(-.19,.19):a.sphere('MischiefEye',(x,-1.04,1.17),(.062,.026,.085),'lime',16,10)
        a.box('LockPlate',(0,-1.025,.75),(.35,.12,.53),'navy',.04)
        a.torus('LockShackle',(0,-1.13,.87),.15,.045,'silver',(pi/2,0,0),24,8)
        a.box('CreamPadlock',(0,-1.15,.65),(.4,.22,.37),'cream',.085)
        a.sphere('Keyhole',(0,-1.278,.68),(.046,.025,.05),'navy',12,8)
        a.prism('KeyholeStem',[(-.025,.665),(.025,.665),(.04,.565),(-.04,.565)],.03,'navy',y=-1.28,bevel=.009)
    elif id=='D03':
        a.lathe('Cauldron',[(.49,0),(.62,.08),(.8,.35),(.9,.73),(.82,1.12),(.68,1.26)],'#075E48',segments=32)
        a.torus('FootRing',(0,0,.11),.57,.085,'gold')
        a.torus('UpperGoldRim',(0,0,1.29),.7,.105,'gold')
        a.cone('DarkOpening',(0,0,1.24),.65,.65,.06,'navy')
        for side in(-1,1): a.torus('Handle',(.88*side,0,.91),.25,.09,'gold',(pi/2,0,0),24,10)
        for i in range(9):
            t=2*pi*i/9; rad=.46 if i<6 else .22
            loc=(rad*cos(t),rad*sin(t),1.3+(.18 if i>5 else .015)*(i%3))
            o=a.lathe('NestledCoin',[(.18,-.038),(.22,-.015),(.22,.025),(.18,.043)],'gold',loc,16)
            o.rotation_euler=(.3*(i%3),.55*(i%2),t)
            ring=a.torus('CoinInsetRing',(0,0,0),.15,.018,'yellow',segments=16,sides=6)
            ring.location=Vector(loc)+o.rotation_euler.to_matrix()@Vector((0,0,.044));ring.rotation_euler=o.rotation_euler.copy()
        clover(a,'FrontClover',(0,-.86,.76),1.05)
    elif id=='D04':
        for x in(-1.18,1.18):
            a.box('WeightedFoot',(x,0,.16),(.88,.84,.3),'green',.1)
            a.box('GoldPlinth',(x,0,.33),(.7,.66,.16),'gold',.065)
            a.box('CreamFoot',(x,0,.48),(.55,.5,.19),'cream',.06)
        pts=[(-1.18,0,.55),(-1.17,0,1.2),(-.98,0,1.88),(-.62,0,2.4),(0,0,2.65),(.62,0,2.4),(.98,0,1.88),(1.17,0,1.2),(1.18,0,.55)]
        a.tube('ArchNavyEdge',pts,.258,'navy',8)
        a.tube('ArchGreenFace',[(x,-.028,z)for x,y,z in pts],.253,'green',8)
        a.tube('GoldInlayBevel',[(x,-.259,z)for x,y,z in pts],.087,'gold',6)
        a.tube('CreamInlay',[(x,-.278,z)for x,y,z in pts],.066,'cream',6)
        for x,z,s in [(-.77,2.22,.73),(0,2.73,1.1),(.77,2.22,.73)]:clover(a,'ArchClover',(x,-.22,z),s)
    elif id=='D05':
        sculpted_loft(a,'EightPanelLantern',[(.33,.74),(.55,.85),(.77,1.08),(.86,1.38),(.86,1.66),(.77,1.97),(.55,2.22),(.33,2.37)],'red',64,8,.024,.9)
        for i in range(8):
            t=2*pi*i/8
            pts=[]
            for radius,z in[(.33,.74),(.55,.85),(.77,1.08),(.86,1.38),(.86,1.66),(.77,1.97),(.55,2.22),(.33,2.37)]:
                rad=radius*1.024;pts.append((rad*cos(t),rad*.9*sin(t),z))
            a.tube('InsetPanelSeam',pts,.023,'#A8172C',8)
        for z in(.74,2.37):
            a.cone('Collar',(0,0,z),.4,.4,.16,'gold',16)
            a.torus('CollarLip',(0,0,z+.07),.36,.05,'yellow',segments=24)
        a.torus('HangingLoop',(0,0,2.65),.18,.055,'navy',(pi/2,0,0),24)
        a.sphere('TasselJoint',(0,0,.57),(.12,.12,.12),'gold',16,10)
        for x in(-.16,0,.16):
            o=a.cone('Tassel',(x,0,.29),.09,.055,.47,'gold',8)
            o.rotation_euler.y=-x*.7
    elif id=='D06':
        a.lathe('RedPedestal',[(.75,0),(.83,.13),(.77,.35),(.67,.5),(.61,.54)],'red',segments=8)
        a.torus('PedestalGoldRim',(0,0,.48),.66,.06,'gold',segments=8)
        a.box('PedestalPlaque',(0,-.715,.27),(.55,.08,.22),'gold',.055)
        sculpted_loft(a,'ShapedLionMaskShell',[(.34,.79),(.59,.9),(.77,1.16),(.84,1.55),(.82,1.82),(.69,2.11),(.46,2.29),(.18,2.32)],'red',40,0,0,.71)
        for side in(-1,1):
            a.sphere('Ear',(side*.72,0,2.04),(.31,.18,.34),'cream',20,14)
            a.sphere('EarInset',(side*.72,-.14,2.04),(.19,.09,.21),'gold',16,10)
            a.sphere('EyeDisc',(side*.4,-.47,1.83),(.38,.18,.39),'gold',20,14)
            a.sphere('EyeWhite',(side*.4,-.60,1.83),(.30,.11,.30),'cream',20,14)
            a.sphere('Eye',(side*.4,-.69,1.83),(.17,.075,.22),'navy',20,14)
            a.sphere('EyeGlint',(side*.4-.06,-.754,1.93),(.06,.025,.07),'white',12,8)
            a.sphere('FluffyCheek',(side*.59,-.43,1.28),(.43,.22,.25),'cream',20,12)
            a.tube('GoldEyebrow',[(side*.72,-.58,2.02),(side*.55,-.6,2.23),(side*.25,-.6,2.17)],.1,'gold',8)
            brow=[(side*x,z)for x,z in[(.05,2.06),(.17,2.27),(.4,2.3),(.56,2.23),(.75,2.14),(.88,2.02),(.78,2.02),(.7,2.1),(.56,2.13),(.48,2.06),(.34,2.17),(.21,2.14),(.16,2.02)]]
            a.prism('SculptedCloudBrow',brow,.19,'cream',y=-.61,bevel=.047)
            cheek=[(side*x,z)for x,z in[(.40,1.44),(.64,1.49),(.87,1.38),(.95,1.23),(.91,1.15),(.78,1.18),(.71,1.09),(.56,1.13),(.43,1.1),(.3,1.22)]]
            a.prism('MouldedCheekFur',cheek,.19,'cream',y=-.48,bevel=.042)
            a.torus('CheekMedallion',(side*.79,-.45,1.64),.14,.055,'gold',(pi/2,0,0),24,8)
            a.sphere('CheekRedInset',(side*.79,-.485,1.64),(.108,.035,.11),'red',16,12)
        a.sphere('Nose',(0,-.72,1.57),(.2,.19,.15),'green',20,12)
        a.sphere('MouthShadow',(0,-.56,1.19),(.49,.16,.3),'navy',24,14)
        a.sphere('MouthRed',(0,-.685,1.12),(.36,.045,.12),'red',20,10)
        a.tube('GoldSmileFrame',[(-.45,-.51,1.28),(-.37,-.61,1.05),(-.18,-.65,.98),(0,-.66,.965),(.18,-.65,.98),(.37,-.61,1.05),(.45,-.51,1.28)],.065,'gold',10)
        a.box('FriendlyTeeth',(0,-.71,1.28),(.57,.10,.12),'cream',.045)
        a.cone('CrownBase',(0,0,2.38),.34,.26,.18,'gold',12)
        a.cone('CrownTop',(0,0,2.55),.23,.08,.23,'red',12)
        a.sphere('CrownTip',(0,0,2.7),(.075,.075,.075),'gold',12,8)
    elif id=='D07':
        a.lathe('RedPot',[(.38,0),(.55,.4),(.55,.52)],'red',segments=12)
        a.torus('PotRim',(0,0,.49),.53,.055,'cream',segments=12)
        a.cone('Trunk',(0,0,.6),.13,.13,.5,'wood',12)
        for i,(z,r,h) in enumerate([(.47,.92,1.03),(1.03,.69,.95),(1.60,.46,.88)]):
            tier=sculpted_loft(a,'SculptedEvergreenTier',[(r*.91,z),(r,z+.07),(r*.97,z+.14),(r*.65,z+h*.46),(r*.3,z+h*.79),(.035,z+h)],'green',32,8,.026)
            a.bevel(tier,.018,2)
            a.torus('NavyTierEdge',(0,0,z+.07),r,.025,'navy',segments=32)
            snow_tier(a,'BroadScallopedSnowCap',z,r,h,.78 if i==2 else .46)
        for i,(x,y,z)in enumerate([(-.55,-.73,.68),(.56,-.55,.88),(-.38,-.45,1.4),(.4,-.45,1.4),(0,-.34,1.99)]):
            a.sphere('RoundOrnament',(x,y,z),(.16,.16,.17),'gold' if i%2 else'red',20,12)
            a.sphere('OrnamentTop',(x,y,z+.15),(.055,.055,.06),'gold',12,8)
        star(a,'TreeStar',0,0,2.61,.29)
    elif id=='D08':
        a.sphere('SnowBody',(0,0,.71),(.76,.65,.72),'cream',28,18)
        a.sphere('SnowHead',(0,0,1.64),(.59,.54,.57),'white',24,16)
        a.cone('HatBrim',(0,0,2.11),.67,.67,.14,'navy',20)
        a.cone('HatCrown',(0,0,2.36),.45,.42,.5,'navy',16)
        a.cone('HatBand',(0,0,2.2),.457,.447,.13,'red',16)
        eyes(a,-.495,1.77,.25,.085)
        nose=a.cone('CarrotNose',(0,-.69,1.6),.105,.01,.43,'orange',12,(pi/2,0,0))
        a.tube('Smile',[(-.21,-.507,1.44),(-.12,-.55,1.38),(0,-.56,1.36),(.16,-.53,1.41)],.028,'navy',8)
        a.torus('ScarfWrap',(0,0,1.25),.48,.13,'red',segments=32)
        a.box('ScarfTail',(.29,-.59,.99),(.28,.16,.65),'red',.055,(0,-.2,0))
        for z in(.8,.96):a.box('ScarfStripe',(.32,-.688,z),(.24,.025,.055),'cream',.015)
        for z in(.51,.84):a.sphere('CoalButton',(0,-.638,z),(.087,.035,.092),'navy',12,8)
        for side in(-1,1):
            a.tube('Arm',[(side*.58,0,1.06),(side*.88,-.02,1.15),(side*1.03,-.03,1.3)],.085,'navy',8)
            mitten=[(side*x,z)for x,z in[(.91,1.2),(.88,1.38),(.89,1.54),(1.00,1.60),(1.13,1.57),(1.20,1.46),(1.17,1.29),(1.04,1.2)]]
            a.prism('ShapedMitten',mitten,.25,'navy',y=-.03,bevel=.064)
            a.sphere('MittenThumb',(side*.9,-.08,1.31),(.10,.13,.13),'navy',16,10)
            a.torus('MittenCuff',(side*.91,-.025,1.17),.105,.035,'cream',(0,side*.5,0),16,8)
    elif id=='D09':
        a.lathe('BasketBody',[(.54,.06),(.63,.2),(.82,.83)],'tan',segments=24)
        for row in range(4):
            z=.15+row*.19;r=.59+row*.055
            for i in range(12):
                t=2*pi*(i+(row%2)*.5)/12
                o=a.box('WovenBlock',(r*cos(t),r*sin(t),z),(.34,.12,.16),'cream'if(i+row)%3 else'tan',.035,(0,0,t+pi/2))
        a.torus('BasketRim',(0,0,.88),.82,.105,'cream',segments=24)
        pts=[(.82*cos(pi-i*pi/20),0,.86+1.1*sin(i*pi/20))for i in range(21)]
        a.tube('HandleDarkEdge',pts,.115,'navy',8)
        a.tube('PinkHandle',[(x,-.025,z)for x,y,z in pts],.095,'pink',8)
        for i,(x,y,z,col) in enumerate([(-.36,.08,1.05,'mint'),(.36,.1,1.06,'pink'),(0,-.3,.96,'lavender')]):
            a.sphere('PastelEgg',(x,y,z),(.34,.28,.47),col,24,16)
            for j in range(3):
                a.sphere('EggSpot',(x-.14+j*.14,y-.267,z+.08*(j%2)),(.054,.018,.073),'cream',12,8)
    elif id=='D10':
        a.lathe('LavenderBase',[(.59,0),(.67,.11),(.61,.28),(.4,.36)],'lavender',segments=8)
        a.torus('BaseCreamTrim',(0,0,.16),.61,.043,'cream',segments=8)
        a.lathe('CarrotBody',[(.12,.33),(.31,.65),(.5,1.35),(.51,1.7),(.35,1.82)],'orange',segments=16)
        for z,w,r in[(.7,.19,.324),(1.06,.32,.421),(1.4,.37,.502)]:
            pts=[(-w+i*w/8,-sqrt(max(.005,r*r-(-w+i*w/8)**2))-.006,z+.012*sin(i*pi/8))for i in range(9)]
            a.tube('InsetCarrotGrowthLine',pts,.016,'#C35A19',8)
        for i,(x,angle)in enumerate([(-.32,-.4),(0,0),(.32,.4)]):
            o=a.prism('CarrotLeaf',[(x-.1,1.73),(x-.18,2.05),(x-.1,2.36),(x+.05,2.43),(x+.16,2.27),(x+.13,1.74)],.17,'green',bevel=.045)
        a.sphere('RabbitEmblem',(0,-.51,1.16),(.2,.045,.18),'cream',20,12)
        for x in(-.1,.1):a.sphere('RabbitEar',(x,-.51,1.45),(.066,.045,.2),'cream',16,12)
        a.box('BaseInsetPanel',(0,-.612,.17),(.47,.038,.13),'cream',.025)
    elif id=='D11':
        base=star(a,'WeightedStarBase',0,0,0,.76,'purple',depth=.32)
        base.rotation_euler.x=pi/2
        base.location.z=.17
        inset=star(a,'InsetCreamStar',0,0,0,.58,'cream',depth=.035)
        inset.rotation_euler.x=pi/2;inset.location.z=.331
        a.cone('StemCollar',(0,0,.24),.25,.25,.2,'purple',16)
        for i,(x,z,col)in enumerate([(-.67,1.58,'magenta'),(0,2.15,'cyan'),(.67,1.7,'yellow')]):
            pts=[(0,0,.29),(x*.35,0,.65),(x*.8,0,z-.5),(x,0,z-.3)]
            a.tube('RigidBalloonStem',pts,.065,col,8)
            balloon=sculpted_loft(a,'ShapedBalloon',[(.045,-.49),(.2,-.4),(.36,-.2),(.42,.02),(.38,.23),(.26,.41),(.12,.49),(.065,.49)],col,24,0,0,.88)
            balloon.location=(x,0,z)
            a.cone('BalloonNeck',(x,0,z-.47),.11,.055,.13,'cream',12)
    elif id=='D12':
        a.lathe('CyanStand',[(.48,0),(.54,.12),(.26,.3),(.16,.42),(.16,.74),(.87,.79),(.89,.94)],'cyan',segments=16)
        a.torus('StandCreamRim',(0,0,.9),.84,.05,'cream',segments=24)
        for z,r,h in[(1.22,.72,.55),(1.73,.52,.47)]:
            a.lathe('CakeTier',[(r*.93,z-h/2),(r,z-h/2+.06),(r,z+h/2-.06),(r*.96,z+h/2)],'pink',segments=32)
            a.cone('CreamIcing',(0,0,z+h/2),r*.98,r*.93,.1,'cream',32)
            scalloped_band(a,'ContinuousScallopedFrosting',r+.015,z+h*.15,.14,12,'cream')
            for i in range(12):
                t=2*pi*i/12
                a.sphere('IcingPearl',(r*cos(t),r*sin(t),z+.01),(.065,.065,.065),'cream',12,8)
        for x,z in[(-.26,2.18),(0,2.3),(.26,2.18)]:
            a.cone('Candle',(x,0,z),.06,.06,.32,'gold',12)
            a.sphere('CandleFlame',(x,0,z+.23),(.065,.04,.12),'orange',16,10)
            a.sphere('FlameCore',(x,-.035,z+.22),(.025,.016,.062),'yellow',12,8)
    else: raise ValueError(id)
    a.anchor('PlacementOrigin',(0,0,0))
    return a
