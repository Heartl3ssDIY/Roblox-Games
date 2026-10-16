from assetlib import *
from math import sin, cos, pi, sqrt, atan2, exp
from mathutils import Vector
import itertools


def disc(a, name, z, radius, height, color, segments=32):
    edge=min(.035,height*.28)
    return a.lathe(name, [(0, z-height/2), (radius*.93, z-height/2),
        (radius, z-height/2+edge), (radius, z+height/2-edge),
        (radius*.93, z+height/2), (0, z+height/2)], color, segments=segments)


def helix(a, name, center, radius, height, turns, thickness, color, steps=72):
    x, y, z = center
    pts = [(x+radius*cos(2*pi*turns*i/steps), y+radius*sin(2*pi*turns*i/steps),
            z+height*i/steps) for i in range(steps+1)]
    return a.tube(name, pts, thickness, color, sides=8)


def profile_mesh(a, name, profile, color, center=(0, 0, 0), axis='z', n=32):
    verts, faces = [], []
    cx, cy, cz = center
    for r, t in profile:
        for j in range(n):
            x, y = r*cos(j*2*pi/n), r*sin(j*2*pi/n)
            verts.append((cx+x, cy+y, cz+t) if axis == 'z' else (cx+x, cy-t, cz+y))
    for k in range(len(profile)):
        kk = (k+1) % len(profile)
        for j in range(n):
            jj = (j+1) % n
            faces.append((k*n+j, k*n+jj, kk*n+jj, kk*n+j))
    return a.mesh(name, verts, faces, color, smooth=False)


def ring_shape(a, name, outer, inner, depth, color, y=0):
    n = len(outer)
    verts = [(x, y+d, z) for d in [-depth/2, depth/2] for pts in [outer, inner] for x, z in pts]
    faces = []
    for i in range(n):
        j = (i+1) % n
        faces += [(i,j,n+j,n+i), (2*n+i,3*n+i,3*n+j,2*n+j),
                  (i,2*n+i,2*n+j,j), (n+i,n+j,3*n+j,3*n+i)]
    return a.bevel(a.mesh(name, verts, faces, color, smooth=False), .025, segments=2)


def emblem(a, name, pts, y, color, depth=.045, border=.045):
    center = Vector((sum(x for x,z in pts)/len(pts), sum(z for x,z in pts)/len(pts)))
    expanded = [tuple(center+(Vector(p)-center)*1.10) for p in pts]
    a.prism(name+' Navy Seam', expanded, depth+.02, 'navy', y=y+.005, bevel=border)
    return a.prism(name, pts, depth, color, y=y-.03, bevel=border*.7)


def soft_outline(points, radius=.20, samples=4):
    result=[]
    for i,p in enumerate(points):
        p=Vector(p); previous=Vector(points[i-1]); nxt=Vector(points[(i+1)%len(points)])
        start=p.lerp(previous,radius); end=p.lerp(nxt,radius)
        for j in range(samples):
            t=j/(samples-1); u=1-t
            q=start*u*u+p*2*u*t+end*t*t
            result.append(tuple(q))
    return result


def flame_outline():
    curves=[((0,.43),(-.25,.43),(-.38,.58),(-.29,.81)),
            ((-.29,.81),(-.25,.94),(-.21,1.02),(-.19,1.05)),
            ((-.19,1.05),(-.17,.98),(-.18,.86),(-.13,.83)),
            ((-.13,.83),(-.02,.93),(.05,1.08),(0,1.23)),
            ((0,1.23),(.22,1.17),(.31,.98),(.24,.83)),
            ((.24,.83),(.30,.85),(.32,.90),(.32,.95)),
            ((.32,.95),(.41,.76),(.30,.50),(.12,.45)),
            ((.12,.45),(.08,.44),(.04,.43),(0,.43))]
    result=[]
    for curve in curves:
        p0,p1,p2,p3=[Vector(p) for p in curve]
        for j in range(6):
            t=j/6; u=1-t
            result.append(tuple(p0*u**3+p1*3*u*u*t+p2*3*u*t*t+p3*t**3))
    return result


def football(a):
    phi = (1+sqrt(5))/2
    vs = []
    for s in [-1,1]:
        for t in [-1,1]:
            vs += [Vector((0,s,t*phi)),Vector((s,t*phi,0)),Vector((t*phi,0,s))]
    vs = [v.normalized() for v in vs]
    d = min((v-w).length for i,v in enumerate(vs) for j,w in enumerate(vs) if i != j)
    adjacent = {i:[j for j in range(12) if abs((vs[i]-vs[j]).length-d)<1e-5] for i in range(12)}
    trunc = {(i,j):(vs[i]*2+vs[j])/3 for i in range(12) for j in adjacent[i]}
    polys = []
    for i in range(12):
        normal = vs[i]
        tangent = normal.cross(Vector((0,0,1)))
        if tangent.length < .1:
            tangent = normal.cross(Vector((0,1,0)))
        tangent.normalize()
        bitangent = normal.cross(tangent)
        points = [trunc[i,j] for j in adjacent[i]]
        points.sort(key=lambda p:atan2(p.dot(bitangent),p.dot(tangent)))
        polys.append((points,'#182F61'))
    for i,j,k in itertools.combinations(range(12),3):
        if j in adjacent[i] and k in adjacent[i] and k in adjacent[j]:
            points = [trunc[i,j],trunc[j,i],trunc[j,k],trunc[k,j],trunc[k,i],trunc[i,k]]
            normal = (points[1]-points[0]).cross(points[2]-points[1])
            if normal.dot(sum(points,Vector())) < 0:
                points.reverse()
            polys.append((points,'cream'))
    a.sphere('Inflated Seam Foundation', (0,0,.96), (.934,.934,.934), 'navy', segments=32, rings=20)
    for idx,(corners,color) in enumerate(polys):
        mid = sum(corners,Vector())/len(corners)
        perimeter=[]
        for i,v in enumerate(corners):
            nxt=corners[(i+1)%len(corners)]
            for sub in range(3):
                p=v.lerp(nxt,sub/3)
                perimeter.append(mid.lerp(p,.956))
        verts=[tuple(mid.normalized()*.954+Vector((0,0,.96)))]
        count=len(perimeter)
        for ring in range(1,4):
            for p in perimeter:
                v=mid.lerp(p,ring/3).normalized()*(.954-.010*(ring/3)**5)
                verts.append(tuple(v+Vector((0,0,.96))))
        faces=[]
        for j in range(count):
            faces.append((0,1+j,1+(j+1)%count))
        for k in range(2):
            for j in range(count):
                jj=(j+1)%count
                faces.append((1+k*count+j,1+k*count+jj,1+(k+1)*count+jj,1+(k+1)*count+j))
        back_start=len(verts)
        for p in perimeter:
            verts.append(tuple(p.normalized()*.928+Vector((0,0,.96))))
        outer_start=1+2*count
        for j in range(count):
            jj=(j+1)%count
            faces.append((outer_start+j,back_start+j,back_start+jj,outer_start+jj))
        faces.append(tuple(back_start+j for j in reversed(range(count))))
        a.mesh(('Pentagonal' if len(corners)==5 else 'Hexagonal')+' Inflated Panel %02d'%idx,verts,faces,color,smooth=True)
    a.root['Topology note']='Truncated icosahedron: 12 navy pentagons, 20 ivory hexagons, curved inflated panel surfaces.'


def basketball(a):
    a.sphere('Orange Inflated Ball',(0,0,.94),(.94,.94,.94),'orange',segments=40,rings=24)
    for axis in range(2):
        pts=[]
        for j in range(81):
            t=2*pi*j/80
            if axis==0: p=(.926*cos(t),.926*sin(t),.94)
            else: p=(.926*cos(t),0,.94+.926*sin(t))
            pts.append(p)
        a.tube('Rubber Great Circle Seam %d'%axis,pts,.037,'navy',sides=8)
    for sign in [-1,1]:
        pts=[]
        for j in range(65):
            t=2*pi*j/64
            z=.926*sin(t)
            az=sign*(.64+.34*sin(t)**2)
            rad=.926*cos(t)
            pts.append((rad*cos(az),rad*sin(az),.94+z))
        a.tube('Sweeping Court Panel Seam '+str(sign),pts,.035,'navy',sides=8)


def foam(a):
    a.lathe('Lavender Grip',[(0,0),(.19,0),(.21,.07),(.18,.14),(.11,.20),(.12,.70),(.18,.77),(.17,.84),(0,.84)],'lavender',segments=24)
    for z in [.25,.38,.51,.64]:
        a.torus('Soft Grip Band', (0,0,z), .119,.025,'purple',segments=24,sides=6)
    disc(a,'Cream Knob Underside',.005,.132,.025,'cream',20)
    a.lathe('Pink Foam Barrel',[(0,.76),(.15,.76),(.18,.93),(.29,1.30),(.36,1.78),(.36,2.30),(.33,2.45),(.22,2.56),(0,2.60)],'magenta',segments=32)
    profile_mesh(a,'Cyan Soft Band',[(.352,1.96),(.384,1.96),(.384,2.14),(.352,2.14)],'cyan',n=32)
    for z in [1.95,2.15]: a.torus('Band Navy Seam',(0,0,z),.366,.016,'navy',segments=32,sides=6)
    a.anchor('GripAttachment',(0,0,.43))


def barrel(a):
    a.lathe('Stave Seam Core',[(0,0),(.54,0),(.66,.16),(.735,.70),(.69,1.35),(.59,1.60),(0,1.60)],'brown',segments=36)
    profile=[(.565,.02),(.62,.10),(.72,.40),(.76,.82),(.72,1.29),(.62,1.65),(.56,1.74)]
    colors=['#C38436','#D99C4B','#BC772F','#D49542','#C98638','#DF9F4A']
    for k in range(6):
        verts=[]
        for r,z in profile:
            for j in range(7):
                th=2*pi*k/6+(.022+(2*pi/6-.044)*j/6)
                verts.append((r*cos(th),r*sin(th),z))
        faces=[]
        for row in range(len(profile)-1):
            for j in range(6): faces.append((row*7+j,row*7+j+1,(row+1)*7+j+1,(row+1)*7+j))
        faces += [tuple(range(6,-1,-1)),tuple((len(profile)-1)*7+j for j in range(7))]
        for edge in [0,6]:
            inds=[i*7+edge for i in range(len(profile))]
            faces.append(tuple(inds if edge==0 else reversed(inds)))
        faces.append((0,6,(len(profile)-1)*7+6,(len(profile)-1)*7))
        a.mesh('Broad Curved Wood Stave '+str(k+1),verts,faces,colors[k])
    for z in [.29,1.41]:
        rad=.726 if z<1 else .716
        profile_mesh(a,'Thick Navy Hoop',[(rad-.025,z-.125),(rad+.038,z-.125),(rad+.053,z-.083),(rad+.053,z+.083),(rad+.038,z+.125),(rad-.025,z+.125)],'navy',n=36)
        for k in range(8):
            th=2*pi*k/8
            a.sphere('Silver Hoop Rivet',( (rad+.060)*cos(th),(rad+.060)*sin(th),z),(.055,.055,.055),'silver',segments=8,rings=4,smooth=False)
    # The lid has an actual rectangular hand recess rather than a painted mark.
    n=32; outer=[]; inner=[]
    for i in range(n):
        th=2*pi*i/n; dx,dy=cos(th),sin(th)
        scale=1/max(abs(dx)/.22,abs(dy)/.085)
        outer.append((.552*dx,.552*dy)); inner.append((scale*dx,scale*dy))
    verts=[(x,y,z) for z in [1.64,1.73] for pts in [outer,inner] for x,y in pts]
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces += [(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)]
    a.mesh('Wood Lid with Recessed Handgrip',verts,faces,'wood')
    a.box('Hand Recess Bottom',(0,0,1.63),(.45,.18,.04),'brown',bevel=.02)
    for y in [-.24,.24]:
        half=sqrt(.54**2-y*y)
        a.box('Lid Plank Seam',(0,y,1.735),(half*2,.015,.008),'brown',bevel=.003)
    a.anchor('ThrowAttachment',(0,0,.86))


def potion_cap(a, z, neck_color='cyan'):
    disc(a,'Opaque Neck Chamber',z-.25,.235,.48,neck_color,24)
    disc(a,'Cream Stopper Rim',z-.04,.31,.13,'cream',12)
    disc(a,'Navy Chunky Stopper',z+.14,.35,.26,'navy',10)
    disc(a,'Stopper Crown Inset',z+.28,.27,.055,'#304B7E',10)


def zoom(a):
    a.sphere('Opaque Turquoise Potion Chamber',(0,0,.89),(.67,.40,.69),'cyan',segments=32,rings=20)
    face=[(.57*cos(2*pi*j/24),.89+.59*sin(2*pi*j/24)) for j in range(24)]
    a.prism('Flattened Front Liquid Chamber',face,.19,'cyan',y=-.31,bevel=.055)
    outer=[(.748*cos(2*pi*j/32),.89+.768*sin(2*pi*j/32)) for j in range(32)]
    inner=[(.613*cos(2*pi*j/32),.89+.633*sin(2*pi*j/32)) for j in range(32)]
    ring_shape(a,'Navy Protective Flask Frame',outer,inner,.49,'navy')
    outer=[(.757*cos(2*pi*j/32),.89+.777*sin(2*pi*j/32)) for j in range(32)]
    inner=[(.625*cos(2*pi*j/32),.89+.645*sin(2*pi*j/32)) for j in range(32)]
    ring_shape(a,'Solid Cream Flask Frame',outer,inner,.53,'cream')
    disc(a,'Navy Heel',.19,.43,.19,'navy',12)
    disc(a,'Cream Heel Plate',.30,.41,.12,'cream',12)
    disc(a,'Shoulder Collar',1.46,.28,.13,'navy',12)
    potion_cap(a,1.98)
    loop=a.torus('Solid Side Handle',( .64,0,1.53),.23,.074,'blue',rotation=(pi/2,0,0),segments=24,sides=8)
    a.box('Handle Attachment',(.48,0,1.41),(.20,.20,.24),'cream',bevel=.05,rotation=(0,-.5,0))
    bolt=[(-.04,1.30),(.29,1.30),(.08,.98),(.30,.98),(-.23,.50),(-.10,.88),(-.34,.88)]
    emblem(a,'Raised Lightning Badge',bolt,-.405,'yellow',.06,.028)
    for x,z in [(-.43,.80),(.39,.67),(.40,1.10),(-.29,.53)]:
        a.sphere('Embedded Potion Bubble',(x,-.429,z),(.042,.018,.042),'mint',segments=12,rings=6)


def spring_sip(a):
    disc(a,'Navy Protective Base',.15,.61,.29,'navy',12)
    a.lathe('Opaque Pear Potion Chamber',[(0,.21),(.42,.21),(.62,.40),(.64,.66),(.52,.91),(.27,1.22),(.22,1.32),(.22,1.76),(0,1.76)],'lime',segments=28)
    for k in range(6):
        th=2*pi*k/6
        a.box('Cream Base Inset',( .619*cos(th),.619*sin(th),.16),(.27,.06,.13),'cream',bevel=.025,rotation=(0,0,th-pi/2))
    helix(a,'Yellow Neck Spring',(0,0,1.19),.295,.58,2.8,.062,'yellow',84)
    potion_cap(a,1.87,'green')
    chevron=[(-.33,.39),(-.33,.64),(0,.93),(.33,.64),(.33,.39),(0,.67)]
    emblem(a,'Upward Chevron',chevron,-.548,'cream',.16,.033)
    a.anchor('UseAttachment',(0,0,1.98))


def ember(a):
    a.sphere('Opaque Ember Chamber',(0,0,.81),(.65,.46,.62),'orange',segments=32,rings=20)
    disc(a,'Navy Flask Heel',.17,.43,.19,'navy',16)
    disc(a,'Cream Lower Cradle',.26,.45,.13,'cream',16)
    a.lathe('Cream Shoulder Rim',[(0,1.21),(.33,1.21),(.38,1.27),(.31,1.37),(.22,1.43),(0,1.43)],'cream',segments=16)
    potion_cap(a,1.88,'red')
    helix(a,'Attached Red Heat Coil',(0,0,1.44),.275,.27,1.7,.047,'red',44)
    a.sphere('Coil Fastener',(-.27,-.08,1.48),(.085,.08,.085),'navy',segments=12,rings=6)
    emblem(a,'Yellow Flame Emblem',flame_outline(),-.427,'yellow',.16,.02)
    inner=[(-.06,.48),(-.13,.64),(-.04,.86),(.03,.72),(.09,.83),(.15,.67),(.08,.48)]
    a.prism('Flame Emblem Orange Heart',soft_outline(inner,.17),.025,'orange',y=-.545,bevel=.015)


def gift(a):
    a.box('Navy Box Edge',(0,0,.65),(1.35,1.24,1.25),'navy',bevel=.13)
    a.box('Turquoise Gift Body',(0,0,.66),(1.37,1.26,1.17),'teal',bevel=.11)
    for x in [-1,1]:
        a.box('Cream Side Panel',(x*.697,0,.66),(.035,.92,.80),'cream',bevel=.07)
    for y in [-1,1]:
        a.box('Cream Front Panel',(0,y*.643,.66),(1.02,.035,.80),'cream',bevel=.07)
    a.box('Magenta Ribbon Across X',(0,0,.67),(1.47,.25,1.20),'magenta',bevel=.025)
    a.box('Magenta Ribbon Across Y',(0,0,.67),(.27,1.38,1.20),'magenta',bevel=.025)
    a.box('Navy Lid Seam',(0,0,1.22),(1.45,1.34,.19),'navy',bevel=.08)
    a.box('Turquoise Gift Lid',(0,0,1.32),(1.46,1.35,.24),'cyan',bevel=.085)
    a.box('Top Ribbon X',(0,0,1.455),(1.38,.28,.025),'magenta',bevel=.01)
    a.box('Top Ribbon Y',(0,0,1.457),(.29,1.29,.025),'magenta',bevel=.01)
    right=soft_outline([(.06,1.49),(.25,1.78),(.51,2.00),(.69,1.93),(.79,1.72),(.68,1.52),(.45,1.47)],.26)
    ctr=Vector((.46,1.70))
    for side in [-1,1]:
        outer=[(x*side,z) for x,z in right]
        inner=[tuple(ctr+(Vector(p)-ctr)*.59) for p in right]
        inner=[(x*side,z) for x,z in inner]
        ring_shape(a,'Broad Cream Bow Loop',outer,inner,.30,'cream',y=0)
        a.tube('Bow Navy Lower Seam',[(x,-.16,z) for x,z in outer+[outer[0]]],.014,'navy',sides=5)
    a.box('Magenta Bow Knot',(0,-.02,1.56),(.33,.42,.26),'magenta',bevel=.065)


def gun_body(a, frost=False):
    color='cyan' if frost else 'teal'
    a.box('Chamfered Navy Receiver',(0,.02,1.18),(.75,1.22,.79),'navy',bevel=.16)
    a.box('Chunky Toy Body',(0,-.01,1.23),(.79,1.28,.76),color,bevel=.145)
    grip=[(.15,.95),(.50,.99),(.56,.81),(.71,.20),(.66,.09),(.19,.07),(.12,.18),(.18,.48)]
    grip_core=a.prism('Contoured Navy Handgrip',soft_outline(grip,.16),.45,'navy',bevel=.035)
    grip_core.rotation_euler.z=pi/2
    inset=[(.18,.90),(.47,.93),(.51,.78),(.64,.24),(.60,.17),(.24,.15),(.20,.24),(.25,.48)]
    grip_panel=a.prism('Inset Contoured Rubber Grip',soft_outline(inset,.17),.478,'teal' if frost else 'orange',bevel=.035)
    grip_panel.rotation_euler.z=pi/2
    for side in [-1,1]:
        for z in [.30,.48,.66]:
            a.box('Grip Palm Panel',(side*.249,.405+(z-.50)*.15,z),(.027,.27,.125),'cyan' if frost else 'cream',bevel=.024)
        a.box('Side Panel Seam',(side*.365,.0,1.23),(.065,.82,.52),'navy',bevel=.080)
        a.box('Cream Side Inset',(side*.405,.0,1.23),(.045,.71,.41),'cream',bevel=.065)
        for y in [-.28,.28]:
            for z in [1.10,1.37]:
                a.sphere('Panel Bolt',(side*.435,y,z),(.016,.029,.029),'navy',segments=8,rings=4,smooth=False)
    a.tube('Open Toy Finger Guard',[(0,.32,.96),(0,-.18,.94),(0,-.30,.80),(0,-.24,.58),(0,.20,.56)],.063,'navy',sides=8)
    a.tube('Toy Trigger',[(0,.10,.96),(0,-.005,.80),(0,.06,.72)],.055,'cream' if frost else 'red',sides=8)
    a.anchor('GripAttachment',(0,.40,.51))


def plunger(a):
    gun_body(a)
    profile_mesh(a,'Navy Muzzle Collar',[(.21,.51),(.30,.51),(.30,.72),(.24,.75)],'navy',center=(0,0,1.20),axis='y',n=12)
    profile_mesh(a,'Orange Trumpet Muzzle',[(.22,.63),(.27,.66),(.37,.95),(.57,1.21),(.58,1.32),(.47,1.34),(.40,1.17),(.21,.83)],'orange',center=(0,0,1.20),axis='y',n=16)
    profile_mesh(a,'Flared Muzzle Highlight Rim',[(.50,1.27),(.59,1.27),(.59,1.34),(.50,1.34)],'gold',center=(0,0,1.20),axis='y',n=16)
    profile_mesh(a,'Red Rubber Suction Cup',[(.10,1.06),(.24,1.13),(.42,1.34),(.47,1.43),(.46,1.49),(.39,1.49),(.35,1.34),(.18,1.17)],'red',center=(0,0,1.20),axis='y',n=32)
    a.sphere('Suction Cup Dish Back',(0,-1.19,1.20),(.19,.035,.19),'#AC1B35',segments=20,rings=10)
    for side in [-1,1]:
        a.sphere('Rear Toy Pressure Dial',(side*.398,.48,1.27),(.080,.14,.14),'orange',segments=16,rings=8)
        a.sphere('Dial Cream Centre',(side*.463,.48,1.27),(.023,.092,.092),'cream',segments=16,rings=8)
    tank=disc(a,'Cream Pressure Tank',0,.245,.69,'cream',24)
    tank.rotation_euler=(pi/2,0,0); tank.location=(0,.20,1.84)
    for y in [-.17,.56]:
        a.torus('Pressure Tank Navy Collar',(0,y,1.84),.238,.050,'navy',rotation=(pi/2,0,0),segments=24,sides=8)
        a.sphere('Teal Pressure Tank End',(0,y,1.84),(.238,.08,.238),'teal',segments=20,rings=10)
    a.tube('Pressure Hose',[(0,-.17,1.84),(0,-.31,1.84),(0,-.38,1.76),(0,-.38,1.57)],.073,'navy',sides=8)
    a.cone('Orange Tank Cap',(0,.22,2.10),.14,.13,.14,'orange',vertices=12)
    a.anchor('MuzzleAttachment',(0,-1.51,1.20))


def snowflake_side(a, side):
    x=side*.449
    for i in range(3):
        ang=pi*i/3
        dz,dy=.18*cos(ang),.18*sin(ang)
        a.tube('Raised Snowflake Arm',[(x,-dy,1.23-dz),(x,dy,1.23+dz)],.026,'cyan',sides=6)
        for sign in [-1,1]:
            ey,ez=sign*dy,1.23+sign*dz
            for branch in [-1,1]:
                ay=ey-sign*.07*sin(ang)+branch*.055*cos(ang)
                az=ez-sign*.07*cos(ang)-branch*.055*sin(ang)
                a.tube('Snowflake Tip Branch',[(x,ey,ez),(x,ay,az)],.023,'cyan',sides=6)


def frost(a):
    gun_body(a,True)
    profile_mesh(a,'Cream Barrel Collar',[(.19,.52),(.31,.52),(.34,.58),(.34,.71),(.27,.77),(.19,.77)],'cream',center=(0,0,1.20),axis='y',n=12)
    profile_mesh(a,'Navy Barrel Ring',[(.19,.76),(.27,.76),(.27,.90),(.19,.90)],'navy',center=(0,0,1.20),axis='y',n=12)
    profile_mesh(a,'Faceted Frost Trumpet',[(.20,.86),(.28,.91),(.43,1.17),(.54,1.32),(.54,1.51),(.39,1.54),(.32,1.33),(.15,1.07)],'#81DBF6',center=(0,0,1.20),axis='y',n=10)
    profile_mesh(a,'Opaque Blue Muzzle Throat',[(.08,.99),(.18,1.03),(.26,1.20),(.33,1.37),(.34,1.48),(.30,1.49),(.10,1.05)],'#147CAB',center=(0,0,1.20),axis='y',n=10)
    a.sphere('Throat Recess',(0,-1.035,1.20),(.14,.035,.14),'navy',segments=16,rings=8)
    a.box('Navy Tank Mount',(0,.15,1.61),(.38,.61,.16),'navy',bevel=.05)
    a.box('Opaque Ice Tank',(0,.13,1.91),(.52,.92,.49),'#80DFF7',bevel=.115)
    for y in [-.34,.58]:
        collar=disc(a,'Navy Ice Tank Band',0,.32,.115,'navy',10)
        collar.rotation_euler=(pi/2,0,0); collar.location=(0,y,1.91)
        sign=-1 if y<0 else 1
        cap=disc(a,'Cream Ice Tank End Ring',0,.263,.052,'cream',10)
        cap.rotation_euler=(pi/2,0,0); cap.location=(0,y+sign*.073,1.91)
        lens=disc(a,'Opaque Faceted Ice End Cap',0,.211,.069,'#81DBF6',10)
        lens.rotation_euler=(pi/2,0,0); lens.location=(0,y+sign*.114,1.91)
    for side in [-1,1]:
        for j,(y,z) in enumerate([(-.12,1.83),(.12,1.91),(.30,1.84)]):
            # Crystal chunks are opaque low-poly forms embedded into the tank surface.
            a.cone('Embedded Ice Crystal',(side*.27,y,z),.12,.025,.30,'#BAF6FF' if j%2 else 'cyan',vertices=5,rotation=(0,side*.40,.2))
        snowflake_side(a,side)
    a.anchor('MuzzleAttachment',(0,-1.56,1.20))


def paint(a):
    a.lathe('Magenta Pail',[(0,.05),(.46,.05),(.51,.13),(.61,1.12),(.60,1.23),(.53,1.23),(.45,.22),(0,.22)],'magenta',segments=32)
    disc(a,'Navy Pail Foot',.12,.53,.18,'navy',16)
    profile_mesh(a,'Thick Navy Pail Rim',[(.51,1.17),(.64,1.17),(.66,1.23),(.66,1.32),(.61,1.36),(.51,1.34)],'navy',n=20)
    disc(a,'Opaque Cyan Paint Surface',1.27,.565,.09,'cyan',32)
    for x,z in [(-.33,.99),(.35,.87)]:
        a.lathe('Thick Attached Paint Drip',[(0,z-.045),(.051,z-.018),(.081,z+.035),(.071,z+.115),(.064,1.20),(.09,1.29),(.075,1.34),(0,1.35)],'cyan',loc=(x,-.585,0),segments=20)
        a.sphere('Attached Rim Paint Spill',(x,-.50,1.31),(.115,.16,.055),'cyan',segments=20,rings=10)
    for s in [-1,1]:
        a.sphere('Navy Handle Hinge',(s*.64,0,1.04),(.095,.11,.11),'navy',segments=12,rings=8)
        a.sphere('Cream Hinge Pin',(s*.715,0,1.04),(.035,.075,.075),'cream',segments=12,rings=6)
    pts=[]
    for i in range(25):
        t=pi*i/24
        pts.append((.70*cos(t),-.12-.58*sin(t),1.03-.71*sin(t)))
    a.tube('Sturdy Cream Swing Handle',pts,.062,'cream',sides=8)
    shield=[(-.28,.51),(-.28,.83),(0,.98),(.28,.83),(.28,.51),(0,.36)]
    emblem(a,'Cream Label Shield',shield,-.576,'cream',.032,.018)
    splat=[]
    for i in range(96):
        t=2*pi*i/96
        r=.128
        for j,amplitude in enumerate([.093,.084,.105,.080,.099,.087]):
            delta=(t-2*pi*j/6+pi)%(2*pi)-pi
            r+=amplitude*exp(-(delta/.25)**2)
        splat.append((r*cos(t),.67+r*sin(t)))
    a.prism('Raised Cyan Splat',splat,.037,'cyan',y=-.626,bevel=.012)
    a.anchor('ThrowAttachment',(0,0,.68))


def egg(a):
    egg_profile=[(0,0),(.26,.03),(.48,.14),(.62,.40),(.64,.65),(.60,.96),(.48,1.31),(.30,1.62),(.13,1.79),(0,1.83)]
    a.lathe('Intact Cream Egg',egg_profile,'cream',segments=40)
    a.lathe('Warm Golden Egg Heel',[(0,0),(.26,.03),(.48,.14),(.62,.40),(.642,.50),(.631,.51),(.606,.39),(.47,.16),(.24,.045),(0,.025)],'#E9B75A',segments=40)
    def surface(x,z):
        for (r0,z0),(r1,z1) in zip(egg_profile,egg_profile[1:]):
            if z0<=z<=z1:
                r=r0+(r1-r0)*(z-z0)/(z1-z0)
                return -sqrt(max(.0001,r*r-x*x))
        return 0
    for name,scale,offset,col in [('Protective Sticker Navy Edge',1,.012,'navy'),('Blue Protective Oval Sticker',.87,.025,'blue')]:
        vertices=[]
        for ring in range(1,5):
            for j in range(24):
                t=2*pi*j/24
                x=.24+.14*scale*ring/4*cos(t)
                z=1.12+.225*scale*ring/4*sin(t)
                vertices.append((x,surface(x,z)-offset,z))
        vertices.append((.24,surface(.24,1.12)-offset,1.12))
        faces=[]
        for j in range(24): faces.append((96,j,(j+1)%24))
        for row in range(3):
            for j in range(24):
                k=(j+1)%24
                faces.append((24*row+j,24*row+k,24*(row+1)+k,24*(row+1)+j))
        back=len(vertices)
        vertices += [(x,y+.035,z) for x,y,z in vertices[72:96]]
        for j in range(24):
            k=(j+1)%24
            faces.append((72+j,back+j,back+k,72+k))
        faces.append(tuple(back+j for j in range(24)))
        a.mesh(name,vertices,faces,col,smooth=True)
    a.anchor('ThrowAttachment',(0,0,.83))


def icing_layer(a, name, z, radius, thickness):
    n=48; verts=[]
    for ring in range(4):
        for j in range(n):
            t=2*pi*j/n
            ripple=.035*cos(9*t)+.020*sin(5*t)
            rad=[radius*.95,radius,radius,radius*.90][ring]
            h=[z-thickness/2+ripple,z-thickness/2+.03+ripple,z+thickness/2-.025,z+thickness/2][ring]
            verts.append((rad*cos(t),rad*sin(t),h))
    faces=[]
    for k in range(3):
        for j in range(n):
            jj=(j+1)%n; faces.append((k*n+j,k*n+jj,(k+1)*n+jj,(k+1)*n+j))
    faces += [tuple(range(n-1,-1,-1)),tuple(3*n+j for j in range(n))]
    a.mesh(name,verts,faces,'cream')


def cake(a):
    disc(a,'Lower Chocolate Cake',.27,.71,.50,'brown',40)
    icing_layer(a,'Broad Middle Vanilla Frosting',.56,.735,.19)
    disc(a,'Upper Chocolate Cake',.90,.72,.56,'brown',40)
    icing_layer(a,'Sculpted Vanilla Top Frosting',1.19,.756,.22)
    for j,th in enumerate([-pi/2,-pi/2-1.05,-pi/2+1.05]):
        r=.72
        bottom=.92-j*.045
        a.lathe('Sculpted Chocolate Drip '+str(j+1),[(0,bottom-.045),(.058,bottom-.022),(.088,bottom+.036),(.079,bottom+.12),(.062,1.12),(.10,1.25),(.081,1.29),(0,1.31)],'#59271F',loc=(r*cos(th),r*sin(th),0),segments=20)
    a.torus('Cream Strawberry Nest',(0,0,1.34),.22,.080,'cream',segments=24,sides=8)
    berry=a.lathe('Fat Strawberry',[(0,1.30),(.14,1.32),(.25,1.44),(.28,1.62),(.22,1.78),(.12,1.84),(0,1.84)],'red',segments=20)
    for row in range(3):
        z=1.42+row*.125
        rr=[.235,.277,.248][row]
        for j in range(7):
            th=2*pi*(j+.45*(row%2))/7
            a.sphere('Strawberry Golden Seed',(rr*cos(th),rr*sin(th),z),(.020,.020,.036),'yellow',segments=8,rings=4)
    for j in range(5):
        t=2*pi*j/5
        leaf=a.sphere('Attached Strawberry Leaf',(.12*cos(t),.12*sin(t),1.84),(.18,.07,.035),'green',segments=12,rings=6)
        leaf.rotation_euler=(0,.15,t)
    a.cone('Short Strawberry Stem',(0,0,1.91),.045,.035,.17,'green',vertices=8,rotation=(.1,.3,0))


def torch(a):
    a.lathe('Dark Wooden Handgrip',[(0,0),(.16,0),(.18,.10),(.13,.20),(.15,.95),(.20,1.18),(.20,1.26),(0,1.26)],'brown',segments=12)
    disc(a,'Navy Grip Heel',.09,.19,.17,'navy',10)
    for z in [.31,.53,.75]:
        band=disc(a,'Broad Cream Handle Wrap',z,.168,.13,'cream',12)
        for v in band.data.vertices: v.co.z-=z
        band.location.z=z
        band.rotation_euler=(.10,-.14,0)
    a.lathe('Navy Flame Bowl',[(0,1.06),(.20,1.06),(.38,1.22),(.44,1.42),(.44,1.53),(.37,1.56),(.25,1.34),(0,1.30)],'navy',segments=12)
    for j in range(8):
        t=2*pi*j/8
        a.box('Cream Collar Inlay',(.432*cos(t),.432*sin(t),1.39),(.18,.046,.13),'cream',bevel=.025,rotation=(0,0,t-pi/2))
    flame=[(x*1.12,1.46+(z-.43)*1.20) for x,z in flame_outline()]
    a.prism('Solid Three Lobed Orange Flame',flame,.38,'orange',y=0,bevel=.055)
    inner=[(-.13,1.48),(-.24,1.69),(-.12,1.94),(-.09,1.80),(.03,1.99),(.09,2.24),(.22,1.92),(.19,1.67),(.06,1.50)]
    for y in [-.22,.22]:
        a.prism('Golden Flame Inset',soft_outline(inner,.18),.055,'yellow',y=y,bevel=.037)
    a.anchor('GripAttachment',(0,0,.57))


def bounce(a):
    disc(a,'Octagonal Navy Bumper Base',.16,1.04,.31,'navy',8)
    disc(a,'Cyan Octagonal Platform',.34,1.01,.22,'cyan',8)
    for j in range(8):
        th=2*pi*(j+.5)/8
        a.box('Cream Base Reflector',(.951*cos(th),.951*sin(th),.19),(.40,.038,.115),'cream',bevel=.022,rotation=(0,0,th-pi/2))
    for j in range(3):
        th=2*pi*j/3-pi/2
        x,y=.54*cos(th),.54*sin(th)
        for z in [.49,.96]:
            a.cone('Spring Navy Anchor',(x,y,z),.235,.235,.10,'navy',vertices=16)
            a.cone('Spring Cream Seat',(x,y,z+.047),.205,.205,.035,'cream',vertices=16)
        a.cone('Compression Spring Inner Guide',(x,y,.74),.075,.075,.50,'navy',vertices=12)
        helix(a,'Attached Orange Compression Spring '+str(j+1),(x,y,.52),.15,.43,2.3,.059,'orange',64)
    disc(a,'Raised Disc Navy Bumper',1.09,.89,.21,'navy',16)
    disc(a,'Yellow Raised Bounce Disc',1.22,.87,.21,'yellow',16)
    a.torus('Cream Top Disc Ring',(0,0,1.327),.64,.022,'cream',segments=40,sides=6)
    a.anchor('PlacementAttachment',(0,0,0))


def coin(a):
    def coin_disc(name, y, radius, depth, color):
        obj=disc(a,name,0,radius,depth,color,48)
        obj.rotation_euler=(pi/2,0,0)
        obj.location.y=y
        return obj
    coin_disc('Rounded Thick Gold Coin',0,1.015,.30,'#ECAE28')
    for side,label in [(1,'Front'),(-1,'Back')]:
        coin_disc(label+' Satin Gold Face',-side*.145,.97,.05,'#FFD64B')
        profile=[(.880,.155),(.985,.151),(.995,.177),(.976,.195),(.905,.195),(.878,.177)]
        profile_mesh(a,label+' Single Subtle Rim',[(r,t*side) for r,t in profile],'#F8C539',axis='y',n=48)
        segments=[((.31,.38),(.13,.55),(-.29,.57),(-.34,.31)),
                  ((-.34,.31),(-.40,.04),(-.09,.06),(.13,-.04)),
                  ((.13,-.04),(.48,-.15),(.36,-.51),(.01,-.51)),
                  ((.01,-.51),(-.13,-.53),(-.29,-.45),(-.34,-.37))]
        path=[]
        for s in segments:
            p0,p1,p2,p3=[Vector(p) for p in s]
            for j in range(12):
                t=j/12; u=1-t
                path.append(p0*u**3+p1*3*u*u*t+p2*3*u*t*t+p3*t**3)
        path.append(Vector(segments[-1][-1]))
        left=[]; right=[]
        for i,p in enumerate(path):
            d=(path[min(i+1,len(path)-1)]-path[max(i-1,0)]).normalized()
            normal=Vector((-d.y,d.x))
            l=p+normal*.108; r=p-normal*.108
            left.append((l.x*side,l.y)); right.append((r.x*side,r.y))
        symbol=a.prism(label+' Integrated Raised Dollar',left+list(reversed(right)),.07,'#EAAA21',y=-side*.204,bevel=0)
        stem=a.box(label+' Dollar Stem',(side*.022,-side*.204,-.002),(.157,.07,1.32),'#EAAA21',bevel=0)
        union=symbol.modifiers.new('Unified Dollar Relief','BOOLEAN')
        union.operation='UNION'; union.solver='EXACT'; union.object=stem
        bpy.context.view_layer.objects.active=symbol
        bpy.ops.object.modifier_apply(modifier=union.name)
        a.objects.remove(stem)
        bpy.data.objects.remove(stem,do_unlink=True)
        a.bevel(symbol,.019,segments=3)
    for obj in a.objects:
        for mat in obj.data.materials:
            shader=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
            shader.inputs['Roughness'].default_value=.56
            shader.inputs['Metallic'].default_value=.03
            if 'Coat Weight' in shader.inputs: shader.inputs['Coat Weight'].default_value=0
    a.anchor('SpinPivot',(0,0,0))
    a.root['Pivot purpose']='Geometric center: coin geometry spans approximately -1.02 to +1.02 Z; SpinPivot at origin.'
    a.root['Reference interpretation']='Simplified per user correction: thick satin gold coin, one subtle rim and one unified raised dollar on each face. No glints, reeds or decorative rings.'
    a.root['IsPickupCoin']=True


BUILDERS={'M01':football,'M02':basketball,'M03':foam,'M04':barrel,'M05':zoom,
          'M06':spring_sip,'M07':ember,'M08':gift,'M09':plunger,'M10':frost,
          'M11':paint,'M12':egg,'M13':cake,'M14':torch,'M15':bounce,'C01':coin}


def build(spec):
    a=Asset(spec)
    BUILDERS[spec['id'].upper()](a)
    if spec['id'].upper()!='C01':
        a.root['Reference interpretation']='Opaque chunky toy construction; attached details; no particles, gameplay, labels or prices.'
        a.root['Pivot purpose']='Ground contact; named functional attachment provides grip/throw/use point where applicable.'
    return a
