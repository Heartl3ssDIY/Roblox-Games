from assetlib import *
from math import sin, cos, pi, sqrt


BODY = [(0.125, .27), (.125, .39), (.14, .68), (.17, .98),
        (.207, 1.30), (.25, 1.65), (.292, 2.06), (.322, 2.51),
        (.323, 2.77), (.311, 2.91), (.28, 3.00), (.19, 3.06), (0, 3.08)]


def rad(z, profile=BODY):
    if z <= profile[0][1]:
        return profile[0][0]
    for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
        if z <= z1:
            return r0 + (r1-r0) * (z-z0)/(z1-z0)
    return profile[-1][0]


def ring(a, name, z, radius, height, color, segments=32):
    b = min(.022, height*.2)
    return a.lathe(name, [(radius-b, z-height/2), (radius, z-height/2+b),
                         (radius, z+height/2-b), (radius-b, z+height/2)], color, segments=segments)


def wrap(a, name, z0, z1, width, turns, color, profile=BODY, offset=.012,
         start=-pi/2, steps=None):
    steps = steps or max(32, int(abs(turns)*36))
    vs, fs = [], []
    for i in range(steps+1):
        t = i/steps
        ang = start + turns*2*pi*t
        z = z0 + (z1-z0)*t
        for dz, dr in [(-width/2, 0), (width/2, 0),
                       (-width/2, .012), (width/2, .012)]:
            zz = z+dz
            rr = rad(zz, profile)+offset+dr
            vs.append((rr*cos(ang), rr*sin(ang), zz))
    for i in range(steps):
        k = 4*i
        fs.extend([(k, k+4, k+5, k+1), (k+2, k+3, k+7, k+6),
                   (k, k+2, k+6, k+4), (k+1, k+5, k+7, k+3)])
    fs.extend([(0, 1, 3, 2), (4*steps, 4*steps+2, 4*steps+3, 4*steps+1)])
    return a.mesh(name, vs, fs, color, smooth=True)


def tape_sleeve(a, color, z0=-.265, z1=.275, turns=4.15):
    width=.124
    cross=[(-.50,.112),(-.485,.119),(-.445,.126),(-.34,.129),
           (0,.131),(.34,.129),(.445,.126),(.485,.119),(.50,.112)]
    verts=[]; faces=[]
    steps=168
    for i in range(steps+1):
        t=i/steps; theta=2*pi*turns*t; z=z0+(z1-z0)*t
        for u,r in cross:
            verts.append((r*cos(theta),r*sin(theta),z+u*width))
    n=len(cross)
    for i in range(steps):
        for j in range(n-1):
            q=i*n+j
            faces.append((q,q+n,q+n+1,q+1))
        faces.append((i*n,i*n+n-1,(i+1)*n+n-1,(i+1)*n))
    faces.extend([tuple(reversed(range(n))),tuple(range(steps*n,(steps+1)*n))])
    return a.mesh('Extruded tape sleeve with recessed bevelled seams',verts,faces,color,smooth=True)


def starter_barrel(a):
    profile=[(.121,.27),(.119,.42),(.122,.62),(.139,.92),(.170,1.24),
             (.204,1.55),(.245,1.92),(.279,2.27),(.302,2.56),(.31,2.79),
             (.309,2.93),(.30,3.018),(.281,3.082),(.244,3.134),
             (.186,3.172),(.102,3.198),(0,3.21)]
    zs=sorted(set([.27+i*(3.198-.27)/58 for i in range(59)]+[z for r,z in profile if r>0]))
    verts=[]; faces=[]; material_ids=[]
    centre=-2.00
    sections=[18,3,6,10,6,3,18]
    sector_for_column=[]
    for z in zs:
        outer=.74*sqrt(max(0,1-((z-1.94)/1.12)**2))
        inner=.265*sqrt(max(0,1-((z-2.25)/.46)**2))
        outer=max(.004,outer); inner=min(max(.001,inner),outer*.55)
        boundaries=[-pi,-outer,-outer*.76,-inner,inner,outer*.76,outer,pi]
        for sector,steps in enumerate(sections):
            for i in range(steps):
                t=i/steps
                angle=centre+boundaries[sector]+(boundaries[sector+1]-boundaries[sector])*t
                inset=0
                if sector in (1,5) and outer>.02: inset=.0012*sin(pi*t)**2
                if sector==3 and inner>.01: inset=.0008*sin(pi*t)**2
                rr=rad(z,profile)-inset
                verts.append((rr*cos(angle),rr*sin(angle),z))
                if z==zs[0]: sector_for_column.append(sector)
    columns=sum(sections)
    for row in range(len(zs)-1):
        zm=(zs[row]+zs[row+1])/2
        for col in range(columns):
            nxt=(col+1)%columns
            faces.append((row*columns+col,row*columns+nxt,(row+1)*columns+nxt,(row+1)*columns+col))
            sector=sector_for_column[col]
            idx=0
            if .84<zm<3.05 and sector in (1,5): idx=1
            elif 1.79<zm<2.71 and sector==3: idx=1
            elif .84<zm<3.05 and sector in (2,4): idx=2
            material_ids.append(idx)
    verts.append((0,0,zs[0])); bottom=len(verts)-1
    for col in range(columns):
        faces.append((bottom,(col+1)%columns,col)); material_ids.append(0)
    verts.append((0,0,3.21)); top=len(verts)-1
    for col in range(columns):
        faces.append(((len(zs)-1)*columns+col,(len(zs)-1)*columns+(col+1)%columns,top)); material_ids.append(0)
    obj=a.mesh('Continuous barrel with inset wood-grain topology',verts,faces,'#DF9F50',smooth=True)
    obj.data.materials.append(material('#B97632'))
    obj.data.materials.append(material('#EAB46B'))
    for poly,index in zip(obj.data.polygons,material_ids): poly.material_index=index
    obj['ModelingMethod']='Profile support loops, continuous quad surface, two shallow inset grain regions; no raised grain strips.'
    # A rounded wooden knob with concentric edge loops and recessed end-grain face.
    knob_profile=[(0,-.453),(.094,-.453),(.125,-.451),(.154,-.444),
                  (.176,-.429),(.184,-.406),(.183,-.381),(.169,-.354),
                  (.144,-.337),(.122,-.335)]
    a.lathe('Turned wooden knob with recessed end face',knob_profile,'#DF9F50',segments=48)
    a.lathe('Handle under recessed wrap',[(.105,-.338),(.11,-.31),(.110,.314),(.118,.337)],'navy',segments=32)
    tape_sleeve(a,'#263A5B')
    a.lathe('Flush bevelled tape end',[(.118,.30),(.129,.315),(.129,.335),(.119,.348)],'navy',segments=32)
    a.anchor('Grip',(0,0,0)); a.anchor('BarrelTip',(0,0,3.21))
    return obj


def grip(a, color='navy', knob='wood', collar='navy', seam='navy', body=BODY):
    a.lathe('Handle core', [(0, -.43), (.145, -.42), (.145, -.32),
                          (.112, -.29), (.112, .33), (.13, .4)], color, segments=24)
    ring(a, 'Rounded knob', -.38, .175, .115, knob, 24)
    ring(a, 'Knob underside inset', -.445, .122, .022, collar, 24)
    tape_sleeve(a,color)
    ring(a, 'Grip upper seam', .32, .133, .045, 'navy', 24)
    ring(a, 'Collar', .385, .159, .105, collar, 24)
    a.anchor('Grip', (0, 0, 0))
    a.anchor('BarrelTip', (0, 0, body[-1][1]))


def basic(a, color, grip_color='navy', knob='wood', collar='navy', profile=BODY, segments=32):
    a.lathe('Tapered rounded barrel', profile, color, segments=segments)
    grip(a, grip_color, knob, collar, body=profile)


def badge(a, name, points, color, z=2, y=None, border='navy', depth=.07):
    y = y if y is not None else -rad(z)-.01
    cx = sum(x for x, zz in points)/len(points)
    cz = sum(zz for x, zz in points)/len(points)
    if border:
        a.prism(name+' edge', [(cx+(x-cx)*1.12, cz+(zz-cz)*1.08) for x, zz in points],
                depth, border, y=y+.016, bevel=.017)
    return a.prism(name, points, depth, color, y=y-.014, bevel=.015)


def barrel_badge(a, name, points, color, profile=BODY, border='navy', offset=.017):
    from mathutils.geometry import tessellate_polygon
    def layer(label,polygon,col,lift):
        triangles=tessellate_polygon([[Vector((x,z,0)) for x,z in polygon]])
        triangles=[[(polygon[v] if isinstance(v,int) else (v.x,v.y)) for v in tri] for tri in triangles]
        cuts=3 if max(z for x,z in polygon)-min(z for x,z in polygon)>.65 else 2
        splits=2**cuts
        for _ in range(cuts):
            subdiv=[]
            for p,q,r in triangles:
                pq=((p[0]+q[0])/2,(p[1]+q[1])/2)
                qr=((q[0]+r[0])/2,(q[1]+r[1])/2)
                rp=((r[0]+p[0])/2,(r[1]+p[1])/2)
                subdiv.extend([(p,pq,rp),(pq,q,qr),(rp,qr,r),(pq,qr,rp)])
            triangles=subdiv
        coords=[]; index={}; tris=[]
        def add(p):
            key=tuple(round(v,7) for v in p)
            if key not in index: index[key]=len(coords); coords.append(p)
            return index[key]
        for tri in triangles: tris.append(tuple(add(p) for p in tri))
        boundary=[]
        for p,q in zip(polygon,polygon[1:]+polygon[:1]):
            for i in range(splits):
                t=i/splits; boundary.append(add((p[0]+(q[0]-p[0])*t,p[1]+(q[1]-p[1])*t)))
        verts=[]
        for depth in [lift,-.020]:
            for x,z in coords:
                rr=rad(z,profile)
                yy=-sqrt(max(.001,rr*rr-x*x))-depth
                verts.append((x,yy,z))
        n=len(coords)
        faces=tris+[tuple(i+n for i in reversed(tri)) for tri in tris]
        for p,q in zip(boundary,boundary[1:]+boundary[:1]): faces.append((p,q,q+n,p+n))
        return a.mesh(label,verts,faces,col,smooth=True)
    if border:
        cx=sum(x for x,z in points)/len(points); cz=sum(z for x,z in points)/len(points)
        edge=[(cx+(x-cx)*1.085,cz+(z-cz)*1.038) for x,z in points]
        layer(name+' recessed outline',edge,border,offset-.008)
    return layer(name+' surface inlay',points,color,offset)


def wave_band(a, name, z, width, amplitude, color, profile=BODY, phase=.7):
    verts=[]; faces=[]; segments=72
    cross=[(-.5,-.005),(-.46,.008),(-.36,.016),(.36,.016),(.46,.008),(.5,-.005)]
    for i in range(segments):
        th=2*pi*i/segments
        mid=z+amplitude*sin(th*2+phase)
        for u,lift in cross:
            zz=mid+u*width; rr=rad(zz,profile)+lift
            verts.append((rr*cos(th),rr*sin(th),zz))
    n=len(cross)
    for i in range(segments):
        for j in range(n): faces.append((i*n+j,((i+1)%segments)*n+j,((i+1)%segments)*n+(j+1)%n,i*n+(j+1)%n))
    return a.mesh(name,verts,faces,color,smooth=True)


def surface_curve(a, name, xzs, color, radius=.012, profile=BODY, lift=.012):
    sampled=[]
    for (x0,z0),(x1,z1) in zip(xzs,xzs[1:]):
        for j in range(6):
            t=j/6
            sampled.append((x0+(x1-x0)*t,z0+(z1-z0)*t))
    sampled.append(xzs[-1])
    pts = [(x, -sqrt(max(.002, rad(z, profile)**2-x*x))-lift, z) for x, z in sampled]
    return a.tube(name, pts, radius, color, sides=6)


def leaf(a, name, x, y, z, width=.13, height=.27, color='green', tilt=0):
    verts=[]; faces=[]; n=24
    for sc,yy in [(1,y),(.87,y-.024),(.40,y-.055)]:
        for i in range(n):
            th=2*pi*i/n
            xx=width*.5*sin(th)*sc; zz=height*.5*cos(th)*sc
            verts.append((x+xx*cos(tilt)+zz*sin(tilt),yy,z-xx*sin(tilt)+zz*cos(tilt)))
    verts.extend([(x,y-.062,z),(x,y+.025,z)])
    for j in range(2):
        for i in range(n): faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    for i in range(n):
        faces.append((2*n+i,2*n+(i+1)%n,3*n))
        faces.append(((i+1)%n,i,3*n+1))
    obj=a.mesh(name+' sculpted leaf',verts,faces,color,smooth=True)
    vein=[]
    for d in [-.34,0,.33]: vein.append((x+height*d*sin(tilt),y-.057,z+height*d*cos(tilt)))
    a.tube(name+' inset vein',vein,.006,'#245B32',sides=6)
    return obj


def pumpkin_barrel(a):
    zs=sorted(set([.27+i*(3.06-.27)/40 for i in range(41)]+[z for r,z in BODY if r>0]))
    verts=[]; faces=[]; indices=[]; n=96
    for z in zs:
        for i in range(n):
            th=2*pi*i/n
            groove=(.5+.5*cos(8*th))**7
            rr=rad(z)*(1-.055*groove)
            verts.append((rr*cos(th),rr*sin(th),z))
    for j in range(len(zs)-1):
        for i in range(n):
            faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
            indices.append(1 if i%12 in (0,11) else 0)
    faces.append(tuple(reversed(range(n)))); indices.append(0)
    verts.append((0,0,3.08)); top=len(verts)-1
    for i in range(n): faces.append(((len(zs)-1)*n+i,(len(zs)-1)*n+(i+1)%n,top)); indices.append(0)
    obj=a.mesh('Continuous pumpkin barrel with inset segment grooves',verts,faces,'orange',smooth=True)
    obj.data.materials.append(material('#C85C1D'))
    for face,idx in zip(obj.data.polygons,indices): face.material_index=idx
    grip(a,'purple','orange','green')
    return obj


def drip_shell(a, name, color, profile, ztop, zbase, drips, segments=64):
    # Sculpt a single connected cap with a gently rounded, hanging lower edge.
    vs, fs = [], []
    layers=sorted(set([i/32 for i in range(33)]+[.015,.035,.065]))
    rows=len(layers)
    for j in range(segments):
        ang = 2*pi*j/segments
        zlow = zbase
        for centre, depth, spread in drips:
            d = abs((ang-centre+pi)%(2*pi)-pi)
            if d < spread:
                zlow -= depth * sqrt(max(0,cos(d/spread*pi/2)))
        for t in layers:
            extra=.023*min(1,t/.035)+.012*sin(pi*t)
            z = zlow+(ztop-zlow)*t
            r = rad(z, profile)+extra
            vs.append((r*cos(ang), r*sin(ang), z))
    for j in range(segments):
        for k in range(rows-1):
            q=rows*j+k; n=rows*((j+1)%segments)+k
            fs.append((q,n,n+1,q+1))
    fs.append(tuple(rows*j+rows-1 for j in reversed(range(segments))))
    fs.append(tuple(rows*j for j in range(segments)))
    shell=a.mesh(name, vs, fs, color, smooth=True)
    cap_start=min(zbase+.10,profile[-3][1]-.10)
    cap=[(rad(cap_start,profile)+.040,cap_start)]
    cap.extend((r+.040,z) for r,z in profile if z>cap_start)
    cap.append((0,ztop+.032))
    a.lathe(name+' rounded end-cap support loops',cap,color,segments=64)
    return shell


def crystal(a):
    rings = [(.13, .40), (.205, 1.08), (.295, 1.87), (.35, 2.65), (.31, 2.92), (.18, 3.08)]
    vs, fs = [], []
    for j,(r,z) in enumerate(rings):
        for i in range(8):
            angle = i*pi/4 + (.11 if j%2 else 0)
            vs.append((r*cos(angle), r*sin(angle), z))
    for j in range(len(rings)-1):
        for i in range(8):
            a0=j*8+i; b=j*8+(i+1)%8; c=(j+1)*8+(i+1)%8; d=(j+1)*8+i
            fs.extend([(a0,b,d),(b,c,d)])
    vs.extend([(0,0,.39),(0,0,3.13)])
    for i in range(8):
        fs.append((48,(i+1)%8,i)); fs.append((49,40+i,40+(i+1)%8))
    obj=a.mesh('Solid faceted ice barrel',vs,fs,'cyan',smooth=False)
    # Explicit large facets, not invisible glass or a single recoloured cylinder.
    facet_colors=['cyan','#68E7FF','#BAF6FF','#209FDD','#DFFBFF']
    for col in facet_colors[1:]:
        obj.data.materials.append(material(col))
    for p in obj.data.polygons:
        p.material_index=(p.index*7+p.index//8)%len(facet_colors)
    return obj


def crown(a, z):
    ring(a,'Crown navy mounting band',z-.06,.305,.14,'navy')
    ring(a,'Crown gold base',z+.02,.32,.10,'gold')
    verts=[]; faces=[]; segments=80
    for i in range(segments):
        th=2*pi*i/segments-pi/2
        top=z+.135+.235*(.5+.5*cos(5*(th+pi/2)))**2
        for rr,zz in [(.303,z+.05),(.318,z+.07),(.318,top-.018),(.306,top),
                      (.279,top),(.268,top-.015),(.268,z+.075),(.283,z+.05)]:
            verts.append((rr*cos(th),rr*sin(th),zz))
    for i in range(segments):
        for j in range(8): faces.append((i*8+j,((i+1)%segments)*8+j,((i+1)%segments)*8+(j+1)%8,i*8+(j+1)%8))
    a.mesh('Extruded annular crown with bevelled points',verts,faces,'gold',smooth=True)
    for i in range(5):
        th=2*pi*i/5-pi/2
        a.sphere('Blunt crown bead',(.292*cos(th),.292*sin(th),z+.371),(.048,.048,.048),'gold',segments=12,rings=8)
    badge(a,'Crown ruby',[(0,z+.28),(.061,z+.22),(.05,z+.13),(-.05,z+.13),(-.061,z+.22)],
          'red',y=-.31,z=z+.2,border='cream',depth=.03)


def cloud(a, name, z, size, profile=BODY):
    y=-rad(z)-.032
    pts=[(-.9,-.13),(-.78,.17),(-.42,.21),(-.43,.46),(-.17,.66),
         (.1,.58),(.2,.30),(.62,.31),(.88,.12),(.87,-.16),
         (.6,-.29),(.35,-.16),(.0,-.29),(-.5,-.33)]
    barrel_badge(a,name,[(x*size,z+zz*size) for x,zz in pts],'gold',profile=profile,offset=.03)
    arc=[]
    for i in range(18):
        t=i/17; an=.1+t*1.72*pi; r=.22*size*(1-t*.80)
        xx=-.19*size+r*cos(an); zz=z+.28*size+r*sin(an)
        arc.append((xx,-sqrt(max(.003,rad(zz,profile)**2-xx*xx))-.034,zz))
    a.tube(name+' scroll engraving',arc,.009,'#805222',sides=6)


def dragon(a):
    a.sphere('Friendly dragon cap',(0,0,2.94),(.34,.30,.32),'red',segments=20,rings=12)
    a.sphere('Gold dragon muzzle',(0,-.285,2.86),(.26,.185,.145),'gold',segments=20,rings=12)
    a.sphere('Muzzle lower jaw',(0,-.255,2.785),(.212,.13,.068),'cream',segments=16,rings=8)
    for x in [-.17,.17]:
        a.sphere('Dragon eye rim',(x,-.247,3.018),(.090,.070,.112),'cream',segments=16,rings=10)
        a.sphere('Dragon eye',(x,-.302,3.015),(.062,.038,.074),'navy',segments=16,rings=10)
        a.sphere('Dragon eye shine',(x-.015,-.335,3.045),(.023,.015,.026),'white',segments=10,rings=6)
        a.sphere('Nostril',(x*.65,-.446,2.89),(.035,.018,.041),'navy',segments=12,rings=8)
        horn=a.lathe('Short rounded gold horn',[(.075,0),(.080,.07),(.058,.18),(.022,.28),(0,.30)],'gold',loc=(x,.0,3.16),segments=16)
        horn.rotation_euler[1]=-.3 if x<0 else .3
        leaf(a,'Rounded dragon ear',x*1.6,-.02,3.08,.16,.28,'red',-.6 if x<0 else .6)
        for j in range(2):
            a.sphere('Gold cheek plate',(x*1.7,-.08,2.85+j*.13),(.105,.145,.083),'gold',segments=12,rings=8)
    a.tube('Friendly muzzle smile',[(-.16,-.431,2.81),(-.08,-.452,2.779),(0,-.46,2.773),(.08,-.452,2.779),(.16,-.431,2.81)],.011,'navy',sides=6)


def build(spec):
    a=Asset(spec)
    ident=spec['id']
    if ident=='B01':
        starter_barrel(a)
    elif ident=='B02':
        basic(a,'silver','blue','navy','blue')
        ring(a,'Dark barrel end cap',3.024,.225,.062,'navy')
        ring(a,'Silver end inset',3.076,.155,.034,'silver')
        ring(a,'Blue shoulder stripe',.61,.155,.100,'blue')
    elif ident=='B03':
        basic(a,'red','cream','navy','navy')
        wrap(a,'Ivory varsity diagonal',1.00,2.76,.27,1.25,'cream',offset=.006)
        barrel_badge(a,'Varsity shield',[(-.112,2.59),(.112,2.59),(.096,2.37),(0,2.30),(-.096,2.37)],'blue',border='cream',offset=.038)
    elif ident=='B04':
        basic(a,'orange','navy','orange','orange')
        for z in [1.88,2.57]:
            profile=[(rad(z-.15)+.013,z-.15),(rad(z-.13)+.018,z-.13),
                     (rad(z+.13)+.018,z+.13),(rad(z+.15)+.013,z+.15)]
            a.lathe('Ivory reflective band',profile,'cream',segments=32)
    elif ident=='B05':
        basic(a,'magenta','lavender','magenta','mint')
        wrap(a,'Raised lilac grip ribbon',-.26,.28,.070,3.8,'lavender',profile=[(.114,-.3),(.114,.32)],offset=.001,steps=84)
        for x,z,s in [(.17,1.18,.14),(.20,1.40,.195)]:
            a.sphere('Attached bubblegum globule',(x,-rad(z)*.75,z),(s,s*.85,s),'magenta',segments=20,rings=12)
        ring(a,'Mint knob inset',-.45,.12,.022,'mint')
    elif ident=='B06':
        basic(a,'#859D3E','navy','#617D39','navy')
        drip_shell(a,'Sculpted attached mud coating','#79482D',BODY,3.10,2.59,
                   [(-pi/2,.68,.36),(-.40,.45,.34),(-2.58,.33,.36)])
        barrel_badge(a,'Cream mud-blaster inset',[(-.095,1.29),(-.145,1.42),(-.13,2.08),
                   (-.035,2.21),(.11,2.21),(.15,2.08),(.12,1.46),(.035,1.29)],'cream',border='#46602C')
        ring(a,'Cream handle accent',.39,.13,.044,'cream')
    elif ident=='B07':
        basic(a,'orange','navy','orange','orange')
        for z in [1.62,2.13,2.64]:
            ring(a,'Coil navy separator',z,rad(z)+.045,.18,'navy')
            ring(a,'Broad yellow heat coil',z,rad(z)+.058,.124,'yellow')
        ring(a,'Dark tip housing',3.0,.269,.12,'navy')
        ring(a,'Cream blunt tip',3.065,.211,.035,'cream')
        wrap(a,'Orange grip spirals',-.25,.27,.055,3.6,'orange',profile=[(.113,-.3),(.113,.3)],offset=.001,steps=80)
    elif ident=='B08':
        crystal(a)
        grip(a,'blue','silver','silver')
        ring(a,'Ice knob inset',-.45,.12,.02,'cyan')
    elif ident=='B09':
        basic(a,'blue','navy','cyan','gold')
        ring(a,'Gold top rim',3.0,.285,.11,'gold')
        points=[(.17,2.87),(-.20,2.20),(-.025,2.20),(-.17,1.53),(.22,2.38),(.055,2.38)]
        barrel_badge(a,'Raised thunder bolt',points,'yellow',border='navy',offset=.028)
        ring(a,'Secondary gold collar',.54,.153,.07,'gold')
    elif ident=='B10':
        a.lathe('Pixel tapered shaft',[(.12,.27),(.12,.50),(.13,.81),(.14,1.18)],'navy',segments=8)
        grip(a,'lime','navy','magenta')
        for i,(z,w,h,col) in enumerate([(1.20,.40,.66,'cyan'),(1.91,.53,.74,'magenta'),(2.66,.64,.75,'cyan')]):
            a.box('Pixel block navy seam',(0,0,z),(w-.028,w*.88-.028,h+.025),'navy',bevel=.055)
            a.box('Stepped arcade colour block',(0,-.010,z),(w,w*.88,h-.035),col,bevel=.062)
            a.box('Pixel cream inset',(0,-w*.44-.013,z),(w*.56,.04,h*.51),'cream',bevel=.018)
        ring(a,'Magenta knob inset',-.447,.118,.021,'magenta',16)
    elif ident=='B11':
        basic(a,'purple','purple','navy','silver')
        ring(a,'Attached silver orbit band',2.47,.366,.125,'silver')
        pts=[]
        for i in range(19):
            angle=(65+i*230/18)*pi/180
            pts.append((.055+.175*cos(angle),1.98+.30*sin(angle)))
        for i in range(19):
            angle=(285-i*210/18)*pi/180
            pts.append((.143+.15*cos(angle),1.98+.26*sin(angle)))
        barrel_badge(a,'Cyan crescent inlay',pts,'cyan',border='navy',offset=.022)
        for x,z in [(-.13,1.45),(.12,1.64),(-.08,2.71),(.13,2.81),(.05,1.16)]:
            a.sphere('Silver star dot',(x,-sqrt(max(.005,rad(z)**2-x*x))-.021,z),(.037,.025,.037),'silver',segments=12,rings=8)
    elif ident=='B12':
        profile=[(r,z*.91 if z>.4 else z) for r,z in BODY]
        basic(a,'gold','navy','gold','gold',profile=profile)
        a.lathe('Lower ivory barrel inset',[(rad(z,profile)+.008,z) for z in [.62,.84,1.1,1.3,1.40]],'cream',segments=32)
        a.lathe('Upper ivory barrel inset',[(rad(z,profile)+.008,z) for z in [1.92,2.10,2.35,2.50,2.57]],'cream',segments=32)
        ring(a,'Bold navy prestige belt',1.70,rad(1.70,profile)+.028,.36,'navy')
        badge(a,'Gold gem bezel',[(0,1.96),(.18,1.74),(0,1.48),(-.18,1.74)],'gold',z=1.70,y=-.286,border=None,depth=.095)
        badge(a,'Ruby prestige gem',[(0,1.875),(.10,1.745),(.065,1.62),(-.065,1.62),(-.10,1.745)],'red',z=1.74,y=-.35,border=None,depth=.045)
        for z in [-.16,.085,.28]: ring(a,'Gold grip quilting band',z,.126,.035,'gold',24)
        crown(a,2.70)
    elif ident=='B13':
        basic(a,'blue','cream','#FF7C7E','navy')
        wrap(a,'Mint skatepark spiral',.64,2.69,.20,1.8,'mint',offset=.006)
        wrap(a,'Coral skatepark spiral',.86,2.91,.19,1.8,'#FF7C7E',offset=.006)
    elif ident=='B14':
        basic(a,'navy','teal','navy','cream')
        for k,z in enumerate([1.54,2.09,2.61]):
            wave_band(a,'Bevelled inset ocean wave band',z,.20,.115,'cyan')
        ring(a,'Cream blunt end rim',3.003,.264,.092,'cream')
        ring(a,'Turquoise tip',3.081,.187,.025,'teal')
        for x in [-.082,.082]:
            a.sphere('Collar turquoise rivet',(x,-.141,.385),(.031,.021,.031),'teal',segments=10,rings=6)
    elif ident=='B15':
        basic(a,'cream','#E5611D','gold','navy')
        for j in range(6):
            theta=j*pi/3
            verts=[]; faces=[]
            for k in range(17):
                t=k/16; zz=.82+2.06*t
                half=.015+.295*t
                for ang,extra in [(theta-half,.009),(theta+half,.009),
                                   (theta-half,.021),(theta+half,.021)]:
                    rr=rad(zz)+extra
                    verts.append((rr*cos(ang),rr*sin(ang),zz))
            for k in range(16):
                q=4*k
                faces.extend([(q,q+4,q+5,q+1),(q+2,q+3,q+7,q+6),
                              (q,q+2,q+6,q+4),(q+1,q+5,q+7,q+3)])
            faces.extend([(0,1,3,2),(64,66,67,65)])
            a.mesh('Golden sun-ray panel',verts,faces,'gold' if j%2 else 'orange',smooth=True)
        ring(a,'Navy sunburst tip band',3.015,.265,.1,'navy')
        ring(a,'Golden blunt cap',3.079,.184,.036,'gold')
        ring(a,'Golden shoulder band',.505,.144,.075,'gold')
    elif ident=='E01':
        pumpkin_barrel(a)
        for x in [-.135,.135]:
            barrel_badge(a,'Friendly pumpkin triangle eye',[(x-.078,2.44),(x+.077,2.44),(x+.012,2.58)],'gold',border='navy',offset=.025)
        mouth=[(-.23,2.32),(-.13,2.20),(.01,2.17),(.16,2.21),(.23,2.31),(.12,2.29),(.10,2.24),(.035,2.24),(.035,2.30),(-.07,2.29),(-.08,2.25),(-.14,2.29)]
        barrel_badge(a,'Friendly jack-o-lantern grin',mouth,'gold',border='navy',offset=.026)
        leaf(a,'Left pumpkin leaf',-.18,-.02,.49,.17,.3,'green',-.90)
        leaf(a,'Right pumpkin leaf',.18,-.02,.46,.17,.3,'green',.90)
    elif ident=='E02':
        basic(a,'green','#08766A','gold','cream')
        ring(a,'Cream festive tip ring',3.0,.267,.10,'cream')
        ring(a,'Gold festive tip cap',3.06,.19,.04,'gold')
        petal=[(0,0),(-.07,.08),(-.105,.18),(-.084,.245),(-.035,.257),(0,.225),
               (.035,.257),(.084,.245),(.105,.18),(.07,.08)]
        for j in range(4):
            th=j*pi/2
            pts=[(x*cos(th)+z*sin(th),2.30-x*sin(th)+z*cos(th)) for x,z in petal]
            barrel_badge(a,'Gold heart-shaped clover leaf',pts,'gold',border='#835825',offset=.028)
        a.tube('Attached clover stem',[(0,-.333,2.22),(.015,-.32,2.07),(-.046,-.289,1.95)],.033,'gold',sides=8)
        ring(a,'Lower clover belt',.74,.177,.16,'#08604C')
        a.box('Gold belt buckle',(0,-.171,.74),(.22,.072,.23),'gold',bevel=.026)
        a.box('Buckle dark inset',(0,-.216,.74),(.125,.019,.13),'#08604C',bevel=.017)
    elif ident=='E03':
        profile=[(r,z*.91 if z>.4 else z) for r,z in BODY]
        basic(a,'red','cream','red','gold',profile=profile)
        for z,sz in [(.90,.16),(1.51,.225),(2.20,.30)]:
            wave_band(a,'Gold cloud band wrapping barrel',z,.095,.048,'gold',profile=profile)
            cloud(a,'Gold cloud scroll',z,sz,profile=profile)
        ring(a,'Dragon gold cap mount',2.67,.32,.13,'gold')
        dragon(a)
    elif ident=='E04':
        basic(a,'red','navy','red','#16753E')
        wrap(a,'Ivory candy-cane spiral',.62,2.94,.24,2.8,'cream',offset=.007,steps=120)
        leaf(a,'Left holly leaf',-.18,-.085,.59,.22,.35,'green',-.85)
        leaf(a,'Right holly leaf',.18,-.085,.55,.22,.35,'green',.85)
        for x,z in [(-.064,.52),(.060,.53),(0,.65)]:
            a.sphere('Attached red holly berry',(x,-.177,z),(.078,.070,.078),'red',segments=16,rings=10)
    elif ident=='E05':
        basic(a,'lavender','pink','mint','cream')
        for z in [1.15,2.62]:
            a.lathe('Broad Easter mint band',[(rad(zz)+.012,zz) for zz in [z-.11,z+.11]],'mint',segments=32)
            pts=[]
            for j in range(33):
                th=j*2*pi/32; zz=z+.11*sin(th*4)
                rr=rad(zz)+.025
                pts.append((rr*cos(th),rr*sin(th),zz))
            a.tube('Pale yellow egg zigzag',pts,.022,'cream',sides=6)
        barrel_badge(a,'Raised carrot',[(-.098,1.80),(.12,2.12),(.15,2.24),(.02,2.28),(-.08,2.18)],'orange',border='navy',offset=.025)
        for x,tilt in [(-.02,-.5),(.08,.05),(.16,.55)]:
            leaf(a,'Carrot leaves',x,-.3,2.35,.075,.20,'lime',tilt)
        for x,z in [(-.12,1.48),(.14,1.60),(-.15,2.42),(.14,2.85)]:
            a.sphere('Ivory egg-pattern oval',(x,-sqrt(max(.008,rad(z)**2-x*x))-.02,z),(.038,.022,.071),'cream',segments=12,rings=8)
        ring(a,'Cream Easter blunt tip',3.077,.215,.052,'cream')
    elif ident=='E06':
        profile=[(r,z*.87 if z>.4 else z) for r,z in BODY]
        basic(a,'cream','#EF62A7','gold','lavender',profile=profile)
        drip_shell(a,'Broad attached pink frosting','#FF6DB4',profile,2.703,2.31,
                   [(-pi/2,.61,.41),(-.42,.40,.38),(-2.6,.34,.35),(pi/2,.48,.43)])
        for x,z,ang in [(-.095,.83,-.4),(.10,1.04,.3),(-.12,1.28,.5),(.12,1.52,-.3),
                        (-.09,1.76,-.3),(.13,1.95,.5),(-.13,2.11,.1),(.11,2.36,-.3)]:
            rr=rad(z,profile)
            ob=a.box('Chunky cyan sprinkle',(x,-sqrt(max(.004,rr*rr-x*x))-.008,z),(.055,.050,.14),'cyan',bevel=.024)
            ob.rotation_euler[1]=ang
        for i,(x,y,col) in enumerate([(-.17,-.035,'cyan'),(.15,-.08,'pink'),(0,.16,'lavender')]):
            a.sphere('Candle frosting mount',(x,y,2.665),(.122,.12,.055),'cream',segments=16,rings=8)
            a.lathe('Attached pastel candle',[(.075,2.66),(.083,2.70),(.083,2.93),(.071,2.95)],col,loc=(x,y,0),segments=16)
            a.lathe('Solid yellow candle flame',[(.018,2.96),(.067,3.00),(.06,3.07),(.029,3.14),(0,3.20)],'yellow',loc=(x,y,0),segments=12)
            a.box('Candle cream stripe',(x,y-.084,2.80),(.058,.018,.22),'cream',bevel=.012,rotation=(0,.35,0))
    else:
        raise ValueError('Unknown bat reference '+ident)
    a.root['asset_role']='Bulldog cosmetic bat'
    a.root['grip_pivot']='Origin is centred in the wrapped hand grip; barrel points +Z.'
    a.root['collision_note']='Use one simple non-colliding cosmetic mesh; gameplay reach is not defined by this model.'
    if ident=='E06':
        a.root['event_note']='Player birthday claim concept, not a game anniversary reward.'
    return a
