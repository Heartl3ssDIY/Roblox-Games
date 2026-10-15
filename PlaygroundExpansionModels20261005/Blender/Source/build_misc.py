from assetlib import *
from math import sin, cos, pi, sqrt, exp, atan2
from mathutils import Vector, Matrix


def rounded(points, amount=.18, steps=5):
    result=[]
    for i,p in enumerate(points):
        p=Vector(p); lo=p.lerp(Vector(points[i-1]),amount); hi=p.lerp(Vector(points[(i+1)%len(points)]),amount)
        for j in range(steps):
            t=j/steps
            result.append(tuple(lo*(1-t)**2+p*2*t*(1-t)+hi*t*t))
    return result


def octagon(w,h,z=0,chamfer=.18):
    x=w/2; y=h/2; c=min(w,h)*chamfer
    return [(-x+c,z-y),(x-c,z-y),(x,z-y+c),(x,z+y-c),(x-c,z+y),(-x+c,z+y),(-x,z+y-c),(-x,z-y+c)]


def inset(a,name,pts,y,color='cream',depth=.065):
    center=Vector((sum(p[0] for p in pts)/len(pts),sum(p[1] for p in pts)/len(pts)))
    outline=[tuple(center+(Vector(p)-center)*1.075) for p in pts]
    a.prism(name+' Navy Bezel',outline,depth+.035,'navy',y=y+.01,bevel=.028)
    return a.prism(name,pts,depth,color,y=y-.022,bevel=.021)


def side_panel(a,name,points,x,color='cream'):
    old=len(a.objects)
    inset(a,name,points,0,color)
    for obj in a.objects[old:]:
        obj.rotation_euler.z=pi/2 if x>=0 else -pi/2
        obj.location.x=x


def axis_lathe(a,name,profile,color,loc,axis='Z',segments=32):
    obj=a.lathe(name,profile,color,loc,segments)
    if axis=='Y': obj.rotation_euler.x=pi/2
    elif axis=='X': obj.rotation_euler.y=pi/2
    return obj


def disc(a,name,loc,r,depth,color,axis='Z',segments=32):
    e=min(.025,depth*.22)
    return axis_lathe(a,name,[(r*.90,-depth/2),(r,-depth/2+e),(r,depth/2-e),(r*.90,depth/2)],color,loc,axis,segments)


def hollow(a,name,loc,outer,inner,depth,color,axis='Y',segments=32):
    profile=[(outer*.94,-depth/2),(outer,-depth/2+.025),(outer,depth/2-.025),(outer*.94,depth/2),(inner,depth/2),(inner,-depth/2)]
    verts=[(r*cos(2*pi*i/segments),r*sin(2*pi*i/segments),z) for r,z in profile for i in range(segments)]
    faces=[]
    for row in range(len(profile)):
        for i in range(segments):faces.append((row*segments+i,row*segments+(i+1)%segments,((row+1)%len(profile))*segments+(i+1)%segments,((row+1)%len(profile))*segments+i))
    obj=a.mesh(name,verts,faces,color,True);obj.location=loc
    if axis=='Y':obj.rotation_euler.x=pi/2
    elif axis=='X':obj.rotation_euler.y=pi/2
    return obj


def superloft(a,name,rows,color,segments=32,power=3.2):
    verts=[]; faces=[]
    for z,rx,ry,cx,cy in rows:
        for j in range(segments):
            angle=2*pi*j/segments
            c,s=cos(angle),sin(angle)
            verts.append((cx+rx*(1 if c>=0 else -1)*abs(c)**(2/power),cy+ry*(1 if s>=0 else -1)*abs(s)**(2/power),z))
    for k in range(len(rows)-1):
        for j in range(segments):
            n=(j+1)%segments
            faces.append((k*segments+j,k*segments+n,(k+1)*segments+n,(k+1)*segments+j))
    faces.extend([tuple(reversed(range(segments))),tuple(range((len(rows)-1)*segments,len(rows)*segments))])
    return a.mesh(name,verts,faces,color,True)


def helix(a,name,base,radius,height,turns=3,thickness=.08):
    steps=turns*36
    points=[(base[0]+radius*cos(2*pi*turns*i/steps),base[1]+radius*sin(2*pi*turns*i/steps),base[2]+height*i/steps) for i in range(steps+1)]
    obj=a.tube(name,points,thickness,'navy',sides=10)
    obj['Turns']=turns
    return obj


def snowball(a,name,loc,r):
    obj=a.sphere(name,loc,(r,r,r*.94),'white',segments=16,rings=10,smooth=False)
    for v in obj.data.vertices:
        n=v.co.normalized(); v.co*=1+.025*sin(n.x*17+n.z*9)*cos(n.y*13)
    return obj


def bolt(a,name,loc,r=.047,color='gold',axis='Y'):
    return disc(a,name,loc,r,.05,color,axis,segments=12)


def star_points(cx,cz,r):
    return [(cx+sin(i*pi/5)*r*(1 if i%2==0 else .46),cz+cos(i*pi/5)*r*(1 if i%2==0 else .46)) for i in range(10)]


def m16(a):
    rows=[(.08,.42,.32,0,0),(.13,.58,.43,0,0),(.30,.62,.46,0,0),(.74,.68,.48,0,0),(1.06,.61,.44,0,0),(1.24,.46,.34,0,0),(1.30,.31,.27,0,0),(1.43,.31,.27,0,0)]
    superloft(a,'Opaque Ceramic Bottle',rows,'cyan',40,3.25)
    superloft(a,'Pale Blue Protective Foot',[(.06,.48,.37,0,0),(.08,.60,.46,0,0),(.14,.65,.49,0,0),(.25,.63,.48,0,0),(.28,.57,.43,0,0)],'ice',32,3.15)
    superloft(a,'Foot Navy Seam',[(.05,.51,.39,0,0),(.065,.59,.45,0,0),(.1,.62,.47,0,0)],'navy',32,3.1)
    for xsign in [-1,1]:
        edge=2**(-1/3.25)
        a.tube('Ceramic Side Seam '+str(xsign),[(xsign*rx*edge,-ry*edge,z) for z,rx,ry,cx,cy in rows[2:]],.022,'blue',8)
    disc(a,'Navy Screw Collar',(0,0,1.46),.37,.20,'navy')
    for i in range(8):
        angle=2*pi*i/8
        obj=a.box('Collar Segment %02d'%i,(.32*cos(angle),.32*sin(angle),1.46),(.18,.11,.15),'blue',.025)
        obj.rotation_euler.z=angle+pi/2
    a.box('Cream Collar Label',(0,-.375,1.46),(.35,.055,.075),'cream',.018)
    snowball(a,'Snowball Shaped Cap',(0,0,1.76),.36)
    inset(a,'Cream Snowflake Panel',octagon(.83,.76,.73,.22),-.484)
    flake=[]
    for arm in range(6):
        angle=arm*pi/3
        for x,z in [(-.027,.12),(-.102,.205),(-.102,.235),(-.079,.249),(-.027,.193),(-.027,.298),(0,.317),(.027,.298),(.027,.193),(.079,.249),(.102,.235),(.102,.205),(.027,.12)]:
            flake.append((x*cos(angle)+z*sin(angle),.73+z*cos(angle)-x*sin(angle)))
    inset(a,'Single Extruded White Snowflake',flake,-.562,'white',.040)
    a.anchor('Grip',(0,0,.68)); a.anchor('Spout',(0,0,1.55))


def hopper(a):
    n=8; verts=[]
    for rx,ry,z in [(.43,.37,1.87),(.62,.51,2.21),(.535,.425,2.21),(.35,.29,1.94)]:
        for i in range(n):
            ang=2*pi*(i+.5)/n
            verts.append((rx*cos(ang),.07+ry*sin(ang),z))
    faces=[]
    for row in range(3):
        for i in range(n): faces.append((row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i))
    faces+=[tuple(reversed(range(n))),tuple(range(3*n,4*n))]
    a.bevel(a.mesh('Open Cyan Snowball Hopper',verts,faces,'cyan'),.035,2)
    for k in range(n):
        i=k; j=(k+1)%n
        a.tube('Hopper Reinforced Rim %02d'%k,[verts[n+i],verts[n+j]],.026,'navy',8)
    a.box('Internal Snowball Cradle',(0,.07,1.99),(.62,.47,.08),'cyan',.03)
    for i,(x,y,z) in enumerate([(-.215,-.055,2.27),(.215,-.055,2.27),(0,.22,2.35)],1): snowball(a,'Attached Snowball %d'%i,(x,y,z),.25)


def gun_body(a,bubble=False):
    color='magenta' if bubble else 'blue'
    shell=a.box('Navy Housing Seal',(0,.03,1.45),(.84,1.22,.73),'navy',.14)
    a.box('Rounded Main Toy Housing',(0,-.035,1.47),(.91,1.19,.81),color,.13)
    a.box('Rear Navy Service Seam',(0,.56,1.47),(.85,.08,.74),'navy',.035)
    a.box('Rear Service Cap',(0,.58,1.47),(.76,.13,.66),'cream' if not bubble else 'magenta',.10)
    profile=[(-.17,1.11),(.2,1.14),(.43,.28),(.35,.19),(-.02,.22),(-.12,.37),(-.09,.46)]
    grip=a.prism('Connected Toy Handgrip',profile,.48,'navy' if bubble else 'blue',bevel=.075)
    grip.rotation_euler.z=pi/2; grip.location.y=.29
    side_panel(a,'Grip Inlay',[(-.13,.83),(.13,.82),(.31,.34),(.24,.29),(.02,.32),(-.055,.48)],.257,'navy' if bubble else 'cream')
    for obj in a.objects[-2:]: obj.location.y+=.29
    if bubble:
        for z in [.42,.55,.68]:
            a.tube('Grip Raised Rubber Tread %.2f'%z,[(.317,.3,z),(.317,.49,z+.07)],.021,'blue',8)
    a.box('Trigger Surround',(0,.06,.94),(.31,.34,.35),'navy',.08)
    a.box('Rounded Toy Trigger',(0,-.065,.95),(.26,.13,.25),'magenta' if bubble else 'orange',.055)
    side_panel(a,'Inset Side Display',octagon(.79,.48,1.48,.18),.466)
    side_panel(a,'Reverse Side Display',octagon(.74,.44,1.48,.18),-.456)
    a.anchor('Grip',(0,.37,.56))


def m17(a):
    gun_body(a)
    axis_lathe(a,'Navy Barrel Socket',[(.34,0),(.37,.08),(.37,.22),(.30,.27)],'navy',(0,-.50,1.47),'Y',16)
    axis_lathe(a,'Ivory Hollow Barrel',[(.285,0),(.31,.055),(.31,.55),(.23,.57),(.215,.50),(.215,.20)],'cream',(0,-.66,1.47),'Y',24)
    hollow(a,'Orange Safety Muzzle',(0,-1.24,1.47),.36,.225,.16,'orange','Y',16)
    hollow(a,'Deep Navy Barrel Interior',(0,-1.13,1.47),.226,.20,.16,'navy','Y',24)
    disc(a,'Back Barrel Recess',(0,-.87,1.47),.20,.025,'navy','Y')
    a.box('Hopper Feed Neck',(0,.07,1.90),(.41,.45,.22),'navy',.055)
    hopper(a)
    disc(a,'Safety Side Switch',(.50,.46,1.47),.12,.09,'orange','X',12)
    side=a.sphere('Embossed Snowball Emblem',(.515,-.1,1.47),(.035,.13,.13),'white',16,10,False)
    for i in [-1,0,1]:
        obj=a.prism('Snowball Speed Chevron '+str(i),[(.15,1.44+i*.07),(.28,1.46+i*.07),(.25,1.41+i*.07)],.04,'cyan',bevel=.01)
        obj.rotation_euler.z=pi/2; obj.location.x=.512
    for obj in list(a.objects):
        if obj['Part']=='Embossed Snowball Emblem' or obj['Part'].startswith('Snowball Speed Chevron'):
            duplicate=obj.copy();duplicate.data=obj.data.copy();a.collection.objects.link(duplicate);duplicate.parent=a.root
            duplicate.name=obj.name+' Reverse';duplicate.location.x=-obj.location.x
            if obj['Part'].startswith('Snowball Speed Chevron'):duplicate.rotation_euler.z=-pi/2
            a.objects.append(duplicate)
    bolt(a,'Barrel Side Pin',(.375,-.54,1.52),.07,'cream','X')
    a.anchor('Muzzle',(0,-1.34,1.47)); a.anchor('Hopper',(0,.07,2.05))


def m18(a):
    gun_body(a,True)
    a.box('Top Pink Inspection Cover',(0,-.02,1.90),(.64,.80,.12),'magenta',.06)
    axis_lathe(a,'Navy Nozzle Connector',[(.25,0),(.29,.07),(.29,.35)],'navy',(0,-.5,1.46),'Y')
    hollow(a,'Turquoise Connector Collar',(0,-.77,1.46),.31,.245,.18,'teal')
    for i in range(12):
        t=2*pi*i/12
        a.tube('Nozzle Collar Grip %02d'%i,[(.302*cos(t),-.69,1.46+.302*sin(t)),(.302*cos(t),-.84,1.46+.302*sin(t))],.014,'cyan',6)
    hollow(a,'Wide Bubble Ring Nozzle',(0,-1.10,1.46),.56,.425,.19,'cyan',segments=40)
    hollow(a,'Ring Inner Teal Bevel',(0,-1.115,1.46),.431,.391,.09,'teal',segments=40)
    hollow(a,'Central Bubble Aperture',(0,-1.11,1.46),.177,.108,.16,'cyan')
    hollow(a,'Connected Hollow Nozzle Feed',(0,-.95,1.46),.16,.105,.35,'navy')
    for i in range(6):
        t=2*pi*i/6
        a.tube('Attached Nozzle Spoke %02d'%i,[(.15*cos(t),-1.09,1.46+.15*sin(t)),(.43*cos(t),-1.09,1.46+.43*sin(t))],.043,'cyan',8)
    disc(a,'Soap Reservoir Thread',(0,-.37,.99),.30,.18,'navy')
    a.lathe('Squat Yellow Soap Reservoir',[(.23,.27),(.31,.31),(.34,.41),(.34,.76),(.31,.86),(.24,.91)],'yellow',(0,-.37,0),24)
    for i in range(6):
        t=2*pi*i/6
        obj=a.box('Reservoir Cream Inlay %02d'%i,(.348*cos(t),-.37+.348*sin(t),.59),(.14,.045,.30),'cream',.035)
        obj.rotation_euler.z=t+pi/2
    for i,(y,z,r) in enumerate([(-.12,1.5,.13),(.17,1.55,.071),(.19,1.36,.05)]):
        a.sphere('Bubble Badge %d'%i,(.512,y,z),(.025,r,r),'cyan',20,12)
        a.sphere('Bubble Badge Reverse %d'%i,(-.505,-y,z),(.025,r,r),'cyan',20,12)
    a.anchor('Muzzle',(0,-1.22,1.46)); a.anchor('Reservoir',(0,-.37,.57))


def curved_strip(a,name,centers,widths,thickness,color,angle=0,zoffset=0,outline=False):
    verts=[]; sides=24
    for i,(r,z) in enumerate(centers):
        for j in range(sides):
            t=2*pi*j/sides
            radial=r+thickness*sin(t)*.4
            lateral=widths[i]*cos(t)
            verts.append((radial*cos(angle)-lateral*sin(angle),radial*sin(angle)+lateral*cos(angle),z+zoffset+thickness*sin(t)))
    faces=[]
    for i in range(len(centers)-1):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    faces.extend([tuple(reversed(range(sides))),tuple(range((len(centers)-1)*sides,len(centers)*sides))])
    obj=a.mesh(name,verts,faces,color,True)
    return obj


def m19(a):
    a.lathe('Connected Yellow Peel Core',[(.18,.78),(.20,1.08),(.12,1.25),(.12,1.33)],'yellow',segments=16)
    a.lathe('Short Cream Central Stump',[(.12,1.25),(.12,1.46)],'cream',segments=16)
    a.lathe('Rounded Brown Stem Tip',[(.12,1.41),(.15,1.48),(.15,1.53),(.12,1.57),(.055,1.59)],'brown',segments=12)
    for k in range(3):
        angle=-pi/2+k*2*pi/3
        centers=[]; widths=[]
        for i in range(20):
            t=i/19
            centers.append((.10+1.08*t,1.10*(1-t)**2+.23+.12*t**6))
            widths.append(.105+.17*sin(pi*t)**.8)
        obj=curved_strip(a,'Peel %d Thick Sculpted Flesh'%(k+1),centers,widths,.095,'yellow',angle,.008)
        obj.data.materials.append(material('cream'));obj.data.materials.append(material('brown'));obj.data.materials.append(material('navy'))
        for p in obj.data.polygons:
            if len(p.vertices)==4:
                j=p.index%24
                if j>=12:p.material_index=1
                if j in (0,11,12,23):p.material_index=3
            if p.index>=18*24:p.material_index=2
        obj['PeelCount']=3
    a.anchor('Grip',(0,0,1.29)); a.anchor('Ground',(0,0,.13))


def m20(a):
    a.box('Cobalt Spring Base',(0,0,.36),(1.02,.87,.69),'blue',.12)
    inset(a,'Base Cream Front Panel',octagon(.75,.48,.36,.15),-.457)
    side_panel(a,'Base Cream Side Panel',octagon(.61,.48,.36,.15),.53)
    a.box('Cream Spring Deck',(0,0,.71),(.88,.73,.12),'cream',.07)
    for x in [-.30,.30]:
        for z in [.20,.51]:bolt(a,'Blue Face Fastener %.2f %.2f'%(x,z),(x,-.507,z),.038,'blue')
    disc(a,'Spring Lower Socket',(0,0,.80),.35,.14,'blue')
    helix(a,'Exactly Three Compression Loops',(0,0,.84),.27,.66,3,.078)
    disc(a,'Spring Upper Socket',(0,0,1.49),.26,.10,'navy')
    glove=a.sphere('Sculpted Padded Glove Knuckles',(.17,0,1.99),(.62,.42,.56),'red',40,26)
    for vertex in glove.data.vertices:
        v=vertex.co
        front=max(0,-v.y/.42)
        crease=exp(-((v.x+.20)/.095)**2-((v.z+.08)/.23)**2)
        v.y+=.037*front*crease
        if v.z<-.25:v.x-=.09*((-v.z-.25)/.31)
    a.sphere('Cupped Glove Palm',(-.15,-.20,1.85),(.38,.24,.34),'red',24,16)
    a.sphere('Thumb Navy Piping',(-.23,-.32,1.92),(.285,.19,.315),'navy',32,20)
    a.sphere('Curled Padded Thumb',(-.235,-.335,1.94),(.28,.24,.31),'red',32,20)
    axis_lathe(a,'Cream Wrist Cuff',[(.27,-.17),(.32,-.12),(.32,.12),(.27,.17)],'cream',(-.43,.02,1.87),'X')
    disc(a,'Red Wrist Binding',(-.62,.02,1.87),.31,.09,'red','X')
    a.tube('Glove Knuckle Seam',[(.06,-.28,2.44),(.20,-.40,2.34),(.30,-.42,2.17),(.31,-.38,1.99)],.016,'navy',8)
    disc(a,'Side Button Bezel',(.54,0,.38),.19,.10,'navy','X')
    disc(a,'Big Orange Punch Button',(.625,0,.38),.15,.15,'orange','X')
    a.anchor('Grip',(0,0,.34));a.anchor('SpringTop',(0,0,1.52))


def m21(a):
    a.lathe('Opaque Amber Honey Pot',[(.47,.11),(.61,.18),(.69,.35),(.73,.68),(.68,1.02),(.57,1.19),(.54,1.28)],'gold',segments=32)
    a.lathe('Reinforced Navy Base',[(.50,.06),(.60,.07),(.65,.13),(.65,.23),(.60,.28)],'navy',segments=24)
    disc(a,'Wide Navy Pot Rim',(0,0,1.25),.665,.19,'navy',segments=24)
    a.lathe('Fitted Cream Lid',[(.55,1.32),(.59,1.35),(.56,1.44),(.44,1.49),(.21,1.50)],'cream',segments=24)
    disc(a,'Knob Navy Socket',(0,0,1.51),.22,.10,'navy',segments=16)
    a.lathe('Chunky Yellow Lid Knob',[(.13,1.55),(.15,1.63),(.24,1.67),(.25,1.74),(.21,1.80),(.08,1.81)],'yellow',segments=12)
    a.tube('Honey Overflow Across Front Lip',[(.645*cos(-2.65+2.4*i/60),.645*sin(-2.65+2.4*i/60),1.33) for i in range(61)],.074,'yellow',12)
    for i,(angle,bottom,width) in enumerate([(-2.4,1.02,.078),(-1.80,.83,.088),(-1.02,1.0,.075),(-.5,1.13,.069)]):
        radius=width
        contour=[(-width*1.65,1.36),(-width*1.3,1.29),(-width,bottom+radius)]
        contour += [(radius*cos(pi+j*pi/12),bottom+radius+radius*sin(pi+j*pi/12)) for j in range(1,13)]
        contour += [(width*1.3,1.29),(width*1.65,1.36)]
        drip=a.prism('Rounded Sculpted Honey Drip %d'%(i+1),contour,.105,'yellow',bevel=.023)
        drip.rotation_euler.z=angle+pi/2
        drip.location=(.658*cos(angle),.658*sin(angle),0)
    for i,(x,z) in enumerate([(0,.81),(-.145,.55),(.145,.55)]):
        pts=[(x+sin(k*pi/3)*.16,z+cos(k*pi/3)*.16) for k in range(6)]
        inset(a,'Honeycomb Cell %d'%i,pts,-.723,depth=.048)
    pts=[(.60,.10,1.18),(.83,.10,1.18),(1.0,.10,1.03),(1.01,.10,.82),(.90,.10,.75),(.72,.10,.89),(.66,.10,1.10)]
    a.tube('Cream Attached Carrying Loop',pts,.078,'cream',10)
    bolt(a,'Handle Pivot',(.71,.025,1.17),.085,'yellow','Y')
    a.anchor('Grip',(.85,.1,1.02));a.anchor('Spout',(0,0,1.33))


def m22(a):
    obj=a.sphere('Inflated Coral Cushion',(0,0,.89),(.77,.275,.81),'coral',48,28)
    for v in obj.data.vertices:
        angle=atan2(v.co.z/.81,v.co.x/.77)
        edge=max(0,1-abs(v.co.y)/.16)
        v.co*=1-.018*edge*(1+cos(angle*12))
    a.torus('Dark Red Broad Rubber Seam',(0,.0,.89),.765,.041,'B1283C',rotation=(pi/2,0,0),segments=64,sides=10).scale.z=1.055
    cloud=[(-.44,.79),(-.12,.91),(-.15,1.01),(-.10,1.12),(.01,1.13),(.03,1.29),(.15,1.35),(.27,1.30),(.29,1.19),(.41,1.19),(.49,1.09),(.47,.96),(.39,.91),(.44,.78),(.40,.66),(.28,.61),(.16,.64),(.1,.73),(.0,.7),(-.06,.76),(-.41,.68),(-.28,.76),(-.45,.73)]
    a.prism('Embossed Puff Dark Red Recess',rounded(cloud,.42,8),.055,'B1283C',y=-.26,bevel=.018)
    center=Vector((.10,.97)); inner=[tuple(center+(Vector(p)-center)*.91) for p in cloud]
    a.prism('Cream Comic Puff Emblem',rounded(inner,.42,8),.065,'cream',y=-.292,bevel=.018)
    valve=axis_lathe(a,'Attached Neck Valve',[(.14,0),(.14,.07),(.105,.10),(.11,.30),(.16,.32),(.17,.39),(.12,.40),(.09,.35),(.085,.13)],'red',(-.23,0,1.60),'Z',24)
    valve.rotation_euler.y=-.18
    disc(a,'Valve Reinforcing Seat',(-.23,0,1.62),.18,.075,'B1283C')
    a.anchor('Grip',(0,0,.80));a.anchor('Valve',(-.30,0,1.98))


def magnet_outline(outer=.80,inner=.36):
    z=1.53; top=2.25
    pts=[(-outer,top),(-outer,z)]
    pts += [(outer*cos(pi+i*pi/18),z+outer*sin(pi+i*pi/18)) for i in range(1,19)]
    pts += [(outer,top),(inner,top),(inner,z)]
    pts += [(inner*cos(2*pi-i*pi/18),z+inner*sin(2*pi-i*pi/18)) for i in range(1,19)]
    pts += [(-inner,top)]
    return pts


def m23(a):
    a.prism('Continuous Red Horseshoe Body',magnet_outline(),.43,'red',bevel=.055)
    for sign in [-1,1]:
        a.prism('Horseshoe Navy Face Bezel '+str(sign),magnet_outline(),.045,'navy',y=sign*.217,bevel=.012)
        a.prism('Glossy Red Horseshoe Face '+str(sign),magnet_outline(.767,.393),.045,'red',y=sign*.243,bevel=.012)
    for x in [-.58,.58]:
        a.box('Pole Navy Collar '+str(x),(x,0,2.21),(.52,.54,.14),'navy',.055)
        a.box('Pale Cyan Squared Pole '+str(x),(x,0,2.40),(.53,.55,.31),'ice',.065)
    a.box('Lower Navy Saddle',(0,0,.91),(.57,.56,.34),'navy',.10)
    a.box('Cream Saddle Inset',(0,-.297,.94),(.39,.06,.23),'cream',.045)
    superloft(a,'Tapered Cream Handgrip',[(.10,.24,.23,0,0),(.18,.23,.22,0,0),(.52,.17,.18,0,0),(.76,.21,.21,0,0),(.89,.23,.22,0,0)],'cream',24,3.4)
    disc(a,'Navy Handgrip Foot',(0,0,.13),.285,.14,'navy',segments=20)
    a.box('Switch Navy Bezel',(0,-.207,.58),(.26,.095,.37),'navy',.045)
    a.box('Large Orange Thumb Switch',(0,-.263,.59),(.195,.09,.29),'orange',.04)
    for z in [.26,.38,.50]:a.tube('Grip Finger Tread '+str(z),[(.18,-.02,z),(.19,.13,z+.025),(.12,.21,z+.03)],.028,'navy',8)
    a.anchor('Grip',(0,0,.44));a.anchor('MagnetPoleLeft',(-.58,0,2.55));a.anchor('MagnetPoleRight',(.58,0,2.55))


def blade(a,name,angle,start,end,color,width_bonus=0,depth=.105):
    n=16; sides=12; verts=[]; faces=[]
    for i in range(n):
        t=start+(end-start)*i/(n-1)
        x=.19+1.12*t; z=.16*sin(t*pi)+.18*t
        tangent=Vector((1.12,.16*pi*cos(pi*t)+.18)).normalized(); side=Vector((-tangent.y,tangent.x))
        width=.17+.072*sin(pi*t)+width_bonus
        for j in range(sides):
            p=Vector((x,z))+side*cos(2*pi*j/sides)*width
            xx=p.x*cos(angle)-p.y*sin(angle); zz=p.x*sin(angle)+p.y*cos(angle)
            verts.append((xx,depth*sin(2*pi*j/sides),1.4+zz))
    for i in range(n-1):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    faces.extend([tuple(reversed(range(sides))),tuple(range((n-1)*sides,n*sides))])
    obj=a.mesh(name,verts,faces,color,True)
    return obj


def m24(a):
    for i in range(3):
        angle=pi/2+i*2*pi/3
        verts=[];faces=[];sides=24;n=34
        for k in range(n):
            t=1.10*k/(n-1);x=.18+1.10*t;z=.20*sin(t*pi)+.18*t
            tangent=Vector((1.10,.20*pi*cos(pi*t)+.18)).normalized();side=Vector((-tangent.y,tangent.x))
            width=.22+.075*sin(pi*min(t,1))
            end_factor=sqrt(max(.0005,1-((t-.91)/.19)**2)) if t>.91 else 1
            width*=end_factor
            for j in range(sides):
                p=Vector((x,z))+side*cos(2*pi*j/sides)*width
                verts.append((p.x*cos(angle)-p.y*sin(angle),.145*end_factor*sin(2*pi*j/sides),1.4+p.x*sin(angle)+p.y*cos(angle)))
        for k in range(n-1):
            for j in range(sides):faces.append((k*sides+j,k*sides+(j+1)%sides,(k+1)*sides+(j+1)%sides,(k+1)*sides+j))
        faces.extend([tuple(reversed(range(sides))),tuple(range((n-1)*sides,n*sides))])
        obj=a.mesh('Blade %d Connected Curved Volume'%(i+1),verts,faces,'cyan',True)
        for col in ['navy','orange','cream']:obj.data.materials.append(material(col))
        for p in obj.data.polygons:
            row=p.index//sides;t=1.10*row/(n-1)
            if t>.83:p.material_index=2
            if .77<t<=.83 or t<.22:p.material_index=1
            if .08<t<.17:p.material_index=3
            if p.index%sides in (0,11,12,23):p.material_index=1
    disc(a,'Central Navy Hub',(0,0,1.4),.395,.38,'navy','Y',40)
    disc(a,'Cream Circular Center',(0,-.20,1.4),.323,.13,'cream','Y',40)
    disc(a,'Rear Cream Hub',(0,.20,1.4),.29,.06,'cream','Y',32)
    a.anchor('Grip',(0,0,1.4));a.anchor('SpinAxis',(0,-.24,1.4))


def m25(a):
    a.box('Red Box Floor',(0,0,.12),(1.13,1.04,.20),'red',.09)
    for x in [-.50,.50]:a.box('Red Box Side '+str(x),(x,0,.62),(.17,1.03,.98),'red',.08)
    for y in [-.44,.44]:a.box('Red Box Front Back '+str(y),(0,y,.62),(1.08,.17,.98),'red',.08)
    a.box('Dark Recessed Spring Well',(0,0,.27),(.88,.80,.11),'navy',.04)
    inset(a,'Front Cream Star Panel',octagon(.77,.71,.61,.17),-.545)
    inset(a,'Raised Gold Star',star_points(0,.63,.275),-.619,'yellow',.075)
    side_panel(a,'Crank Cream Side Panel',octagon(.67,.70,.61,.18),.597)
    for x in [-.44,.44]:
        for z in [.20,1.0]:bolt(a,'Gold Corner Rivet %.2f %.2f'%(x,z),(x,-.542,z),.06,'yellow')
    hinge=(0,.43,1.1)
    for x in [-.34,.34]:disc(a,'Attached Gold Lid Hinge '+str(x),(x,.47,1.1),.105,.25,'gold','X')
    lid=a.box('Open Cobalt Hinged Lid',(0,.59,1.64),(1.14,.17,1.14),'blue',.095,rotation=(-.19,0,0))
    a.box('Lid Navy Inset Bezel',(0,.483,1.62),(.96,.065,.94),'navy',.09,rotation=(-.19,0,0))
    a.box('Lid Cream Interior',(0,.437,1.61),(.84,.045,.82),'cream',.075,rotation=(-.19,0,0))
    disc(a,'Spring Floor Mount',(0,-.05,.40),.285,.13,'navy')
    helix(a,'Connected Surprise Spring',(0,-.05,.44),.245,1.0,3,.078)
    disc(a,'Head Spring Collar',(0,-.05,1.46),.22,.12,'navy')
    a.sphere('Mint Monster Head',(0,-.09,1.93),(.50,.39,.46),'mint',32,22)
    for i,(x,z) in enumerate([(-.20,2.06),(.20,2.15)]):
        a.sphere('Eye %d Navy Socket'%i,(x,-.413,z),(.14,.042,.15),'navy',24,16)
        a.sphere('Eye %d Cream Sclera'%i,(x,-.447,z),(.125,.04,.135),'cream',24,16)
        a.sphere('Eye %d Dark Pupil'%i,(x+.014,-.481,z-.015),(.071,.027,.082),'navy',20,14)
        a.sphere('Eye %d Cream Catchlight'%i,(x-.008,-.505,z+.015),(.023,.009,.023),'white',12,8)
    smile=[(-.32,1.94),(-.22,1.90),(0,1.87),(.25,1.95),(.31,2.0),(.26,1.79),(.12,1.70),(-.05,1.69),(-.21,1.77)]
    a.prism('Friendly Smile Navy Rim',rounded(smile,.15,4),.075,'navy',y=-.425,bevel=.018)
    center=Vector((0,1.83));inside=[tuple(center+(Vector(p)-center)*.90) for p in smile]
    a.prism('Friendly Smile Interior',rounded(inside,.15,4),.067,'5B2330',y=-.473,bevel=.015)
    a.sphere('Rounded Red Tongue',(.065,-.516,1.753),(.115,.026,.055),'red',20,12)
    for x,z in [(-.18,1.862),(.19,1.911)]:
        a.prism('Cream Smile Tooth '+str(x),rounded([(x-.038,z+.027),(x+.043,z+.036),(x+.027,z-.070),(x-.006,z-.087)],.22,4),.055,'cream',y=-.517,bevel=.01)
    for x in [-.30,.30]:
        horn=axis_lathe(a,'Tiny Cream Horn '+str(x),[(.105,0),(.098,.06),(.055,.18),(.014,.27)],'cream',(x,-.035,2.29),segments=20)
        horn.rotation_euler.y=(-1 if x<0 else 1)*.30
        disc(a,'Horn Navy Root '+str(x),(x,-.035,2.305),.112,.04,'navy')
    disc(a,'Crank Navy Bearing',(.62,0,.65),.20,.12,'navy','X')
    disc(a,'Crank Gold Axle',(.70,0,.65),.12,.14,'gold','X')
    a.tube('Connected Gold Winding Crank',[(.70,0,.65),(.86,0,.65),(.90,0,.69),(.90,0,.85),(1.04,0,.85)],.066,'gold',10)
    axis_lathe(a,'Rounded Gold Crank Handle',[(.09,-.08),(.12,-.045),(.12,.18),(.09,.22)],'yellow',(1.10,0,.85),'X',24)
    a.anchor('Grip',(0,0,.58));a.anchor('LidHinge',hinge);a.anchor('Head',(0,-.09,1.93));a.anchor('WindUp',(.70,0,.65))


def build(spec):
    a=Asset(spec)
    globals()[spec['id'].lower()](a)
    a.root['ModelingMethod']='Editable volume meshes; custom extruded profiles, lofts, curved strips and bevel modifiers'
    a.root['Collision']='Use separate simplified convex hulls; visible art is not a gameplay collider'
    return a
