from assetlib import *
from mathutils.geometry import tessellate_polygon


FRONT = -.28
STANDARD = [(.123,.29),(.127,.46),(.15,.72),(.185,1.02),(.235,1.4),(.29,1.85),(.33,2.32),(.345,2.77),(.335,2.94),(.30,3.045),(.20,3.11),(0,3.135)]


def radius(profile, z):
    if z <= profile[0][1]: return profile[0][0]
    for (r0,z0),(r1,z1) in zip(profile,profile[1:]):
        if z <= z1: return r0+(r1-r0)*(z-z0)/(z1-z0)
    return profile[-1][0]


def point(profile, theta, z, offset=0):
    r=radius(profile,z)+offset
    return (r*sin(theta),-r*cos(theta),z)


def rounded(points,steps=4):
    result=[];n=len(points)
    for i in range(n):
        p0=Vector(points[(i-1)%n]);p1=Vector(points[i]);p2=Vector(points[(i+1)%n]);p3=Vector(points[(i+2)%n])
        for j in range(steps):
            t=j/steps
            v=.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)
            result.append(tuple(v))
    return result


def ring(a,name,z,r,h,color,segments=40):
    b=min(.022,h*.24)
    return a.lathe(name,[(r-b,z-h/2),(r,z-h/2+b),(r,z+h/2-b),(r-b,z+h/2)],color,segments=segments)


def wrap(a,name,z0,z1,width,turns,color,r=.121):
    cross=[(-.5,-.006),(-.48,0),(-.39,.007),(0,.009),(.39,.007),(.48,0),(.5,-.006)]
    steps=max(80,int(turns*32)); verts=[]; faces=[]
    for i in range(steps+1):
        theta=2*pi*turns*i/steps; z=z0+(z1-z0)*i/steps
        for u,dr in cross: verts.append(((r+dr)*cos(theta),(r+dr)*sin(theta),z+u*width))
    n=len(cross)
    for i in range(steps):
        for j in range(n-1):
            k=i*n+j; faces.append((k,k+1,k+n+1,k+n))
        faces.append((i*n,(i+1)*n,(i+1)*n+n-1,i*n+n-1))
    faces.extend([tuple(reversed(range(n))),tuple(range(steps*n,(steps+1)*n))])
    return a.mesh(name,verts,faces,color,True)


def grip(a,color,knob,collar='navy',kind='tape',accent='cream'):
    a.lathe('Grip continuous navy seam core',[(.122,-.35),(.117,-.29),(.113,.29),(.132,.39)],'navy',segments=32)
    ring(a,'Knob navy perimeter',-.395,.183,.126,'navy')
    ring(a,'Bevelled knob',-.395,.19,.095,knob)
    ring(a,'Knob inset end',-.464,.130,.016,accent)
    if kind=='tape': wrap(a,'Broad bevelled spiral grip wrap',-.282,.283,.14,4.05,color)
    elif kind in ['rings','stripes']:
        a.lathe('Moulded grip sleeve',[(.12,-.337),(.128,-.30),(.127,.29),(.12,.33)],color,segments=32)
        for i in range(5): ring(a,'Grip accent ring %02d'%i,-.265+i*.132,.135,.078 if kind=='stripes' else .035,accent)
    elif kind=='rope':
        for i in range(4):
            z=-.252+i*.168
            ring(a,'Rope broad wrap %02d'%(i+1),z,.136,.157,color)
            wrap(a,'Shallow rope twist seam %02d'%(i+1),z-.047,z+.045,.010,.8,'#A27445',r=.135)
    elif kind=='butter':
        a.lathe('Cream moulded grip',[(.122,-.34),(.132,-.30),(.129,.29),(.12,.335)],color,segments=32)
        for i,z in enumerate([-.17,.12]): ring(a,'Caramel grip ring %d'%(i+1),z,.143,.078,accent)
    elif kind=='chevrons':
        a.lathe('Navy grip barrel',[(.12,-.34),(.127,-.30),(.124,.31),(.12,.34)],color,segments=32)
        p=[(.125,-.4),(.125,.4)]
        for i in range(4):
            z=-.23+i*.145
            relief(a,'Lavender grip chevron %d'%(i+1),[(-.95,z+.05),(0,z-.025),(.95,z+.05),(.95,z+.10),(0,z+.026),(-.95,z+.10)],p,accent,.004,.013,theta=FRONT)
    ring(a,'Grip upper seam',.327,.139,.052,'navy')
    ring(a,'Barrel collar navy shadow',.406,.172,.153,'navy')
    ring(a,'Barrel collar colour face',.413,.180,.115,collar)
    a.anchor('GripAttachment',(0,0,0)); a.anchor('Grip',(0,0,0))
    a.anchor('BarrelTip',(0,0,3.135))


def relief(a,name,polygon,profile,color,offset=.006,depth=.026,theta=FRONT,edge='navy'):
    sampled=[]
    for v,w in zip(polygon,polygon[1:]+polygon[:1]):
        count=max(1,math.ceil(abs(w[0]-v[0])/.16),math.ceil(abs(w[1]-v[1])/.20))
        for i in range(count):sampled.append((v[0]+(w[0]-v[0])*i/count,v[1]+(w[1]-v[1])*i/count))
    polygon=sampled
    cx=sum(x for x,z in polygon)/len(polygon); cz=sum(z for x,z in polygon)/len(polygon)
    loops=[(1,offset),(.993,offset+depth*.56),(.91,offset+depth)]
    verts=[]; faces=[]; mi=[]; n=len(polygon)
    for scale,d in loops:
        for x,z in polygon: verts.append(point(profile,theta+cx+(x-cx)*scale,cz+(z-cz)*scale,d))
    faces.append(tuple(reversed(range(n)))); mi.append(0)
    for row in range(2):
        for i in range(n): faces.append((row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i)); mi.append(0 if row==0 else 1)
    poly=[Vector((x,z,0)) for x,z in polygon]
    lookup={tuple(round(c,7) for c in v):i for i,v in enumerate(verts)}
    def surface_vertex(v):
        pt=point(profile,theta+cx+(v.x-cx)*.91,cz+(v.y-cz)*.91,offset+depth)
        key=tuple(round(c,7) for c in pt)
        if key not in lookup:lookup[key]=len(verts);verts.append(pt)
        return lookup[key]
    for tri in tessellate_polygon([poly]):
        ids=[v if isinstance(v,int) else min(range(n),key=lambda i:(poly[i]-v).length_squared) for v in tri]
        va,vb,vc=[poly[i] for i in ids]
        steps=max(1,math.ceil((max(va.x,vb.x,vc.x)-min(va.x,vb.x,vc.x))/.16),math.ceil((max(va.y,vb.y,vc.y)-min(va.y,vb.y,vc.y))/.20))
        grid={}
        for i in range(steps+1):
            for j in range(steps-i+1):grid[i,j]=surface_vertex(va+(vb-va)*i/steps+(vc-va)*j/steps)
        for i in range(steps):
            for j in range(steps-i):
                faces.append((grid[i,j],grid[i+1,j],grid[i,j+1]));mi.append(1)
                if i+j<steps-1:faces.append((grid[i+1,j],grid[i+1,j+1],grid[i,j+1]));mi.append(1)
    obj=a.mesh(name,verts,faces,edge,True); obj.data.materials.append(material(color))
    for f,index in zip(obj.data.polygons,mi): f.material_index=index
    obj['ModelingMethod']='Extruded curved panel, support loops, bevel rim, recessed navy seam'
    return obj


def oval(a,name,z,halfangle,halfheight,profile,color,offset=.012,depth=.035,theta=FRONT,edge='navy'):
    return relief(a,name,[(halfangle*cos(2*pi*i/32),z+halfheight*sin(2*pi*i/32)) for i in range(32)],profile,color,offset,depth,theta,edge)


def feather_lobe(a,name,p,z,theta,offset):
    verts=[];faces=[];indices=[];n=32
    for scale,off in [(1,offset),(.97,offset+.016),(.84,offset+.033),(.53,offset+.040)]:
        for i in range(n):
            t=2*pi*i/n;dz=.24*sin(t)*scale
            dt=.32*cos(t)*scale-.34*dz
            verts.append(point(p,theta+dt,z+dz,off))
    for row in range(3):
        for i in range(n):faces.append((row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i));indices.append(0 if row==0 else 1)
    centre=len(verts);verts.append(point(p,theta,z,offset+.044))
    for i in range(n):faces.append((3*n+i,3*n+(i+1)%n,centre));indices.append(1)
    faces.append(tuple(reversed(range(n))));indices.append(0)
    obj=a.mesh(name,verts,faces,'#AFCADD',True);obj.data.materials.append(material('white'))
    for f,k in zip(obj.data.polygons,indices):f.material_index=k
    obj['ModelingMethod']='Curved feather extrusion with continuous quad support loops and softly raised centre'
    return obj


def disc(a,name,x,y,z,r,h,color,segments=32):
    obj=a.lathe(name,[(r*.91,-h/2),(r,-h/2+.012),(r,h/2-.012),(r*.89,h/2)],color,segments=segments)
    obj.rotation_euler=(pi/2,0,0); obj.location=(x,y,z)
    return obj


def wave_ring(a,name,z,r,h,color,amount=.035,phase=0):
    verts=[];faces=[];n=48
    for dr,dz in [(-.018,-h/2),(0,-h/2+.018),(0,h/2-.018),(-.018,h/2)]:
        for i in range(n):
            t=2*pi*i/n; verts.append(((r+dr)*sin(t),-(r+dr)*cos(t),z+dz+amount*cos(3*t+phase)))
    for row in range(3):
        for i in range(n):faces.append((row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i))
    faces.extend([tuple(reversed(range(n))),tuple(range(3*n,4*n))])
    return a.mesh(name,verts,faces,color,True)


def drip_shell(a,name,profile,top,bottom,color,drips,theta=0,offset=.018):
    n=96; verts=[]; faces=[]
    def edge(t):
        drop=0
        for centre,width,depth in drips:
            d=(t-centre+pi)%(2*pi)-pi
            if abs(d)<width: drop+=depth*(.5+.5*cos(pi*d/width))
        return bottom-drop
    for row in range(5):
        for i in range(n):
            t=2*pi*i/n+theta; low=edge(t)
            if row==0: z=low+.02;off=offset-.01
            elif row==1: z=low;off=offset+.005
            elif row==2: z=low+.04;off=offset+.026
            elif row==3:z=top-.025;off=offset+.016
            else:z=top;off=offset-.006
            verts.append(point(profile,t,z,off))
    for row in range(4):
        for i in range(n): faces.append((row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i))
    obj=a.mesh(name,verts,faces,color,True)
    obj['ModelingMethod']='Continuous moulded shell with rounded attached drip lobes'
    return obj


def B16(a):
    p=[(.125,.31),(.14,.6),(.18,.92),(.235,1.3),(.29,1.73),(.326,2.1),(.34,2.72),(.329,2.95),(.298,3.055),(.20,3.12),(0,3.14)]
    a.lathe('Sculpted ivory fossil barrel',p,'#F3DAB0',segments=48)
    grip(a,'#663E30','#BCA47B','navy',accent='cream')
    for i,z in enumerate([2.04,2.46,2.85]):
        r=radius(p,z)+.047
        wave_ring(a,'Fossil rib %d navy undercut'%(i+1),z,r,.148,'#594D40',phase=i*.6)
        wave_ring(a,'Fossil rib %d bevelled tan bone'%(i+1),z+.008,r+.006,.115,'#BE9368',phase=i*.6)
    foot=[(-.40,1.12),(-.48,1.21),(-.35,1.34),(-.54,1.49),(-.48,1.59),(-.22,1.47),(-.16,1.79),(-.04,1.84),(.06,1.49),(.28,1.72),(.42,1.69),(.30,1.40),(.39,1.31),(.28,1.18),(.13,1.20),(-.02,1.04),(-.19,1.02)]
    relief(a,'Embossed three-toed dinosaur footprint',rounded(foot,3),p,'#BA8757',.002,.025,edge='#D8BB8B')
    relief(a,'Collar cream inset',[(-.38,.376),(.38,.376),(.38,.45),(-.38,.45)],[(.182,.3),(.182,.6)],'cream',.001,.012)
    a.root['DesignDetails']='Three fused fossil ribs; one sculpted three-toed footprint'


def B17(a):
    p=[(.123,.3),(.146,.65),(.205,1.04),(.266,1.48),(.311,1.95),(.341,2.50),(.342,2.89),(.319,3.03),(.23,3.10),(0,3.13)]
    a.lathe('Emerald dragon barrel foundation',p,'#126744',segments=48)
    grip(a,'#54305E','gold','gold',accent='cream')
    n=64
    for row,(lo,hi) in enumerate([(1.02,1.61),(1.51,2.1),(2.,2.59),(2.49,2.99)]):
        verts=[]; faces=[]; colors=[]
        rows=9
        for band in range(rows):
            for i in range(n):
                t=2*pi*i/n; scallop=.078*(1+cos(4*t+row*pi))
                if band==0:z=lo-scallop;off=.003
                elif band==1:z=lo-scallop+.035;off=.027
                else:
                    trow=(band-1)/(rows-2)
                    z=(lo-scallop+.035)*(1-trow)+hi*trow
                    off=.027*(1-trow)+.004*trow
                verts.append(point(p,t,z,off))
        for band in range(rows-1):
            for i in range(n):faces.append((band*n+i,band*n+(i+1)%n,(band+1)*n+(i+1)%n,(band+1)*n+i));colors.append(0 if band==0 else 1)
        obj=a.mesh('Overlapping rounded scale band %d'%(row+1),verts,faces,'navy',True)
        obj.data.materials.append(material(['#239E68','#2BAB76','#34B781','#36C38B'][row]))
        for f,idx in zip(obj.data.polygons,colors):f.material_index=idx
    ring(a,'Golden dragon tip seam',3.005,.337,.12,'navy')
    ring(a,'Golden dragon blunt end cap',3.023,.342,.105,'gold')
    ring(a,'Golden end cream inset',3.079,.271,.018,'cream')
    oval(a,'Golden oval inset surround',2.45,.51,.37,p,'gold',.048,.026)
    oval(a,'Cream oval inset face',2.45,.40,.298,p,'cream',.071,.012,edge='#EDC976')
    for i,z in enumerate([1.51,2.05,2.61]):
        r=radius(p,z)
        pts=[(-r+.025,z-.18),(-r-.08,z-.13),(-r-.18,z+.10),(-r-.15,z+.21),(-r-.085,z+.19),(-r+.016,z+.10)]
        a.prism('Rounded gold dorsal ridge %d'%(i+1),pts,.135,'gold',y=.016,bevel=.038)
    a.root['DesignDetails']='Four overlapping scalloped scale bands; three attached blunt dorsal ridges'


def B18(a):
    p=[(.124,.3),(.148,.65),(.205,.97),(.267,1.36),(.303,1.8),(.324,2.3),(.336,2.82),(.322,3.00),(.29,3.08),(.20,3.13),(0,3.15)]
    core=[(max(0,r-.041) if z>.8 and r else r,z) for r,z in p]
    a.lathe('Toasted waffle recessed cylindrical core',core,'#BE681F',segments=48)
    grip(a,'cream','gold','#D78729',kind='butter',accent='#BD6521')
    n=12;verts=[];faces=[]
    for z in [.78,.97,1.36,1.8,2.3,2.83,3.0,3.08]:
        for i in range(n+1): verts.append(point(p,FRONT+1.37+(2*pi-2.74)*i/n,z))
    for j in range(7):
        for i in range(n):k=j*(n+1)+i;faces.append((k,k+1,k+n+2,k+n+1))
    a.mesh('Waffle smooth rounded back',verts,faces,'#E0A132',True)
    for row in range(5):
        for col in range(3):
            lo=.84+row*.389;hi=lo+.389;t0=-1.37+col*(2.74/3);t1=t0+2.74/3
            outer=[(t0,lo),(t1,lo),(t1,hi),(t0,hi)]
            inset=[(t0+.112,lo+.043),(t1-.112,lo+.043),(t1-.112,hi-.043),(t0+.112,hi-.043)]
            floor=[(t0+.165,lo+.073),(t1-.165,lo+.073),(t1-.165,hi-.073),(t0+.165,hi-.073)]
            vv=[];ff=[];inds=[]
            for poly,off in [(outer,0),(inset,.009),(floor,-.035)]:
                vv.extend(point(p,FRONT+t,z,off) for t,z in poly)
            for j in range(2):
                for i in range(4):ff.append((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i));inds.append(j)
            ff.append((8,9,10,11));inds.append(2)
            obj=a.mesh('Waffle pocket row%d column%d'%(row+1,col+1),vv,ff,'#FFD061',True)
            obj.data.materials.append(material('#D5932D'));obj.data.materials.append(material('#C07A26'))
            for f,k in zip(obj.data.polygons,inds):f.material_index=k
            obj['RecessDepthStuds']=.044
    drip_shell(a,'Glossy caramel cap with attached drips',p,3.025,2.79,'#B9671B',[(FRONT-.85,.24,.27),(FRONT+.14,.25,.36),(FRONT+1.16,.20,.19),(2.4,.28,.22)],offset=.013)
    ring(a,'Cream butter rim navy thin seam',3.043,.315,.085,'#704725')
    ring(a,'Cream butter rim',3.056,.317,.077,'cream')
    ring(a,'Caramel cap inset',3.098,.261,.022,'#E7AC3D')
    a.root['DesignDetails']='Fifteen true recessed waffle cells, 3 columns by 5 rows; two caramel grip rings'


def B19(a):
    p=[(.125,.3),(.142,.65),(.193,1.02),(.25,1.43),(.31,1.95),(.343,2.5),(.34,2.89),(.30,3.055),(.21,3.13),(0,3.155)]
    body=a.lathe('Pearl white barrel with sky-blue lower taper',p,'#F2F5EE',segments=48)
    body.data.materials.append(material('#59BCE8'))
    for f in body.data.polygons:
        if sum(body.data.vertices[v].co.z for v in f.vertices)/len(f.vertices)<1.43:f.material_index=1
    grip(a,'lavender','cream','lavender',accent='ice')
    ring(a,'Lavender collar gold lower trim',.356,.174,.031,'gold')
    ring(a,'Lavender collar gold upper trim',.47,.173,.026,'gold')
    centre=[(-.25,.95),(-.42,1.38),(-.46,2.3),(-.40,2.82),(-.18,3.08),(.18,3.08),(.40,2.82),(.46,2.3),(.42,1.38),(.25,.95)]
    relief(a,'Pearl white central inset',rounded(centre,3),p,'white',.003,.010,edge='ice')
    for side in [-1,1]:
        th=FRONT+side*.80
        silhouette=[(-.29,1.32),(-.46,1.62),(-.43,2.28),(-.28,2.7),(0,3.04),(.19,2.76),(.32,2.29),(.30,1.78),(.15,1.41),(0,1.24)]
        relief(a,('Left' if side<0 else 'Right')+' feather panel gold surround',rounded(silhouette,3),p,'gold',.010,.021,theta=th,edge='#A18B51')
        for j in range(5):
            z=1.46+j*.275
            feather_lobe(a,'Feather %s rounded lobe %d'%(side,j+1),p,z+.115,th,.038+j*.015)
        pts=[point(p,th+.015,z,.085+.048*(z-1.36)) for z in [1.36,1.67,1.99,2.30,2.61,2.89]]
        a.tube('Feather raised quill %s'%side,pts,.013,'cream',sides=8)
    a.torus('Attached thick gold tip ring',(0,0,3.079),.289,.037,'gold',segments=40,sides=12)
    relief(a,'Lavender collar diamond',[(-.25,.415),(0,.465),(.25,.415),(0,.367)],[(.175,.3),(.175,.55)],'cream',.004,.015,edge='gold')
    a.root['DesignDetails']='Two integrated feather panels with five broad layered lobes each; attached gold tip ring'


def B20(a):
    p=[(.126,.30),(.137,.65),(.185,1.03),(.235,1.40),(.276,1.75),(.307,2.17),(.324,2.64),(.32,2.94),(.298,3.055),(.235,3.11),(0,3.13)]
    obj=a.lathe('Jade bamboo tapered stalk',p,'#28A878',segments=40)
    obj.data.materials.append(material('#218E66'));obj.data.materials.append(material('#51BB89'))
    for f in obj.data.polygons:
        if len(f.vertices)==4:
            x=sum(obj.data.vertices[i].co.x for i in f.vertices)/4
            y=sum(obj.data.vertices[i].co.y for i in f.vertices)/4
            theta=math.atan2(x,-y)
            f.material_index=1 if theta>.8 else (2 if -1.5<theta<-.5 else 0)
    grip(a,'#D4A469','#218C66','navy',kind='rope',accent='#5CCA90')
    for i,z in enumerate([1.29,2.04,2.79]):
        r=radius(p,z)
        wave_ring(a,'Bamboo node %d undercut'%(i+1),z,r+.024,.109,'#196444',amount=.014,phase=i)
        wave_ring(a,'Cream bamboo node %d'%(i+1),z+.006,r+.031,.077,'#E9DAA8',amount=.014,phase=i)
    for i,(th,z,sgn) in enumerate([(-.13,2.48,1),(.33,2.63,-1)]):
        leaf=[(-.04,z-.14),(-.24*sgn,z-.05),(-.30*sgn,z+.14),(-.20*sgn,z+.30),(.015,z+.23),(.12*sgn,z+.06)]
        relief(a,'Cream leaf engraving %d'%(i+1),leaf,p,'cream',.002,.015,theta=FRONT+th,edge='#176749')
        a.tube('Leaf engraved midrib %d'%(i+1),[point(p,FRONT+th-.08*sgn,z-.06,.020),point(p,FRONT+th-.11*sgn,z+.18,.020)],.008,'#66A875',sides=6)
    ring(a,'Bamboo cream inset cut end',3.081,.244,.034,'#E1D5A7')
    ring(a,'Bamboo jade inner end',3.10,.191,.015,'#71C995')
    a.root['DesignDetails']='Three pale bamboo nodes; four broad rope wraps; two engraved cream leaves'


def B21(a):
    p=[(.126,.3),(.15,.64),(.215,.98),(.278,1.34),(.323,1.81),(.347,2.35),(.348,2.92),(.325,3.06),(.23,3.12),(0,3.15)]
    a.lathe('Dark violet arcade barrel',p,'#4930A9',segments=40)
    grip(a,'#253556','magenta','magenta',kind='rings',accent='cyan')
    for side in [-1,1]:
        rail=[(-.105,.86),(-.14,1.03),(-.14,2.78),(-.075,2.94),(.10,2.94),(.145,2.8),(.13,1.07),(.06,.85)]
        relief(a,'Cyan broad edge rail %s'%side,rail,p,'cyan',.006,.045,theta=FRONT+side*.98)
    poly=[(-.43,1.09),(-.60,1.22),(-.60,2.67),(-.42,2.84),(.42,2.84),(.60,2.67),(.60,1.22),(.43,1.09)]
    relief(a,'Arcade inset cream control panel',poly,p,'cream',.003,.033)
    for i,(z,color) in enumerate([(2.53,'red'),(1.99,'yellow'),(1.45,'#28E5A0')]):
        pos=Vector(point(p,FRONT,z,.052))
        base=disc(a,'Button %d navy octagonal socket'%(i+1),*pos,.196,.054,'navy',16)
        cap=disc(a,'Button %d glossy %s'%(i+1,color),*point(p,FRONT,z,.090),.164,.083,color,32)
        for o in [base,cap]:o.rotation_euler=(pi/2,0,FRONT)
    ring(a,'Cyan arcade top band seam',3.0,.353,.107,'navy')
    ring(a,'Cyan arcade top band',3.013,.355,.08,'cyan')
    for th in [-.7,.7]:relief(a,'Collar cream plate %s'%th,[(-.29,.38),(.29,.38),(.29,.45),(-.29,.45)],[(.182,.3),(.182,.6)],'cream',.002,.010,theta=FRONT+th)
    a.root['DesignDetails']='Exactly three buttons, top red, centre yellow, lower mint; two broad cyan rails'


def B22(a):
    p=[(.125,.3),(.155,.68),(.206,1.02),(.264,1.41),(.305,1.85),(.334,2.34),(.34,2.90),(.316,3.055),(.23,3.12),(0,3.14)]
    a.lathe('Amber moulded honey barrel',p,'#CC8021',segments=40)
    grip(a,'#24242A','#DD8C20','navy',kind='stripes',accent='yellow')
    positions=[(-.05,1.06),(.47,1.55),(-.40,1.92),(.57,2.30),(-.15,2.69)]
    for i,(th,z) in enumerate(positions):
        poly=[(.64*cos(pi/6+j*pi/3),z+.258*sin(pi/6+j*pi/3)) for j in range(6)]
        relief(a,'Honeycomb hexagonal panel %d'%(i+1),poly,p,'#FFC937',.012,.039,theta=FRONT+th,edge='#8B571F')
    drip_shell(a,'Upper honey drips',p,2.96,2.82,'#F2B126',[(FRONT-.96,.23,.35),(FRONT+.99,.21,.52),(2.1,.20,.27)],offset=.02)
    for k,(th,z) in enumerate([(FRONT-.84,1.54),(FRONT+.93,1.05)]):
        poly=[(-.17,z+.38),(.15,z+.31),(.12,z+.05),(.07,z-.06),(-.03,z-.09),(-.12,z-.03),(-.12,z+.13)]
        relief(a,'Moulded attached lower honey drop %d'%(k+1),poly,p,'#EDAA1F',.008,.041,theta=th,edge='#C18422')
    ring(a,'Honey tip navy collar',3.005,.344,.11,'navy')
    ring(a,'Cream honey blunt tip',3.084,.315,.094,'cream')
    a.root['DesignDetails']='Five distinct large hexagonal honeycomb panels; opaque attached honey drips'


def B23(a):
    p=[(.13,.3),(.154,.67),(.20,.99),(.25,1.4),(.302,1.92),(.34,2.40),(.345,2.91),(.324,3.04),(.23,3.11),(0,3.14)]
    a.lathe('Copper clockwork taper',p,'#BA7043',segments=40)
    grip(a,'teal','#BA7043','#BA7043',accent='cream')
    for i,z in enumerate([.64,2.89]):
        r=radius(p,z)+.025
        ring(a,'Broad navy clockwork collar %d'%(i+1),z,r,.18,'navy')
        for th in [FRONT-.75,FRONT+.75,FRONT+pi]:
            pos=point([(r,z-.2),(r,z+.2)],th,z,.009)
            obj=disc(a,'Brass collar rivet %d %.2f'%(i,th),*pos,.039,.03,'gold',16);obj.rotation_euler=(pi/2,0,th)
    for th in [-.78,.73]:
        poly=[(-.15,.82),(-.26,1.16),(-.28,2.54),(-.15,2.72),(.18,2.64),(.25,1.34),(.10,.90)]
        relief(a,'Cream clockwork inlay %s'%th,poly,p,'cream',.005,.018,theta=FRONT+th,edge='#915332')
    z=2.28; pos=point(p,FRONT,z,.020)
    backing=disc(a,'Large inset gear navy bezel',*pos,.269,.04,'navy',40);backing.rotation_euler=(pi/2,0,FRONT)
    teeth=[]
    for i in range(8):
        for dt,r in [(-.42,.18),(-.32,.238),(.32,.238),(.42,.18)]:
            ang=(i+dt)*2*pi/8;teeth.append((r*cos(ang),z+r*sin(ang)))
    gear=a.prism('Eight-tooth brass toy gear',teeth,.054,'gold',y=-(radius(p,z)+.070),bevel=.010)
    gear.rotation_euler[2]=FRONT
    for name,r,h,col,off in [('Gear inset navy centre',.109,.028,'navy',.112),('Gear brass axle',.050,.043,'gold',.135)]:
        obj=disc(a,name,*point(p,FRONT,z,off),r,h,col,24);obj.rotation_euler=(pi/2,0,FRONT)
    a.box('Key navy attachment shoe',(-.315,.035,2.64),(.16,.16,.20),'navy',.035)
    a.box('Wind-up key brass stem',(-.406,.035,2.69),(.22,.09,.085),'gold',.02)
    for j,z in enumerate([2.60,2.81]):
        a.torus('Wind-up key rounded finger hole %d'%(j+1),(-.51,.035,z),.082,.027,'gold',rotation=(pi/2,0,0),segments=24,sides=8)
    a.box('Wind-up key joined bridge',(-.51,.035,2.706),(.087,.059,.147),'gold',.023)
    ring(a,'Copper tip chamfer',3.064,.315,.09,'#C88A58')
    ring(a,'Cream clockwork end insert',3.114,.248,.025,'cream')
    a.root['DesignDetails']='Two broad navy collars; one eight-tooth brass gear; small attached twin-hole wind-up key'


def B24(a):
    p=[(.125,.3),(.15,.68),(.207,1.07),(.263,1.49),(.31,1.98),(.339,2.43),(.336,2.87),(.31,3.03),(.23,3.10),(0,3.13)]
    a.lathe('Rounded purple cloth-toy barrel',p,'#9956CB',segments=40)
    grip(a,'orange','mint','navy',kind='rings',accent='purple')
    for index,(low,high,th) in enumerate([(.57,1.17,-.15),(2.0,2.96,.15)]):
        poly=[(-1.23,low+.11),(-.56,low),(.55,low+.12),(1.25,low+.24),(1.25,high-.04),(.48,high),(-.55,high+.05),(-1.23,high-.05)]
        relief(a,'Mint sewn broad panel %d'%(index+1),poly,p,'mint',.005,.019,theta=FRONT+th)
        for edge in [low+.12,high-.015]:
            for j,t in enumerate([-.81,-.10,.63]):
                for direction in [-1,1]:
                    pts=[point(p,FRONT+th+t-.10,edge-.052*direction,.046),point(p,FRONT+th+t+.10,edge+.052*direction,.046)]
                    a.tube('Cream crossed stitch %d %.2f %d %d'%(index,edge,j,direction),pts,.014,'cream',sides=8)
    z=2.57
    for name,r,h,col,off in [('Button navy surround',.190,.048,'navy',.034),('Large orange button rim',.174,.064,'orange',.066),('Orange button inset face',.127,.02,'#DF721F',.105)]:
        obj=disc(a,name,*point(p,FRONT,z,off),r,h,col,32);obj.rotation_euler=(pi/2,0,FRONT)
    for dx,dz in [(-.052,-.052),(-.052,.052),(.052,-.052),(.052,.052)]:
        pp=Vector(point(p,FRONT,z,.122));pp.x+=dx;pp.z+=dz
        o=disc(a,'Button recessed thread hole %.2f %.2f'%(dx,dz),*pp,.021,.01,'navy',12);o.rotation_euler=(pi/2,0,FRONT)
    for sign in [-1,1]:
        pts=[Vector(point(p,FRONT,z,.137))+Vector((-.060,0,-.060*sign)),Vector(point(p,FRONT,z,.14))+Vector((0,0,0)),Vector(point(p,FRONT,z,.137))+Vector((.060,0,.060*sign))]
        a.tube('Button navy cross-thread %d'%sign,pts,.017,'navy',sides=10)
    a.root['DesignDetails']='Broad mint and purple panels; cream cross stitches; one orange four-hole button'


def B25(a):
    p=[(.14,.34),(.173,.67),(.246,1.08),(.322,1.57),(.365,2.1),(.38,2.88),(.355,3.08),(.29,3.15),(.15,3.17)]
    vv=[(r*cos(i*pi/3),r*sin(i*pi/3),z) for r,z in p for i in range(6)]
    ff=[tuple(reversed(range(6)))];mi=[0]
    for row in range(len(p)-1):
        for i in range(6):
            b=row*6+i;c=row*6+(i+1)%6;t=c+6;d=b+6
            base=[1,0,2,0,1,0][i]
            if row in [2,3,4]:
                if (row+i)%2:ff.extend([(b,c,d),(c,t,d)])
                else:ff.extend([(b,c,t),(b,t,d)])
                mi.extend([base,2 if base==0 else (3 if base==1 else 0)])
            else:ff.append((b,c,t,d));mi.append(base)
    ff.append(tuple(range((len(p)-1)*6,len(p)*6)));mi.append(0)
    obj=a.mesh('Six broad opaque crystal facets',vv,ff,'#6025C7')
    obj.data.materials.append(material('#15CEEF'));obj.data.materials.append(material('#9254E4'));obj.data.materials.append(material('#2588C8'))
    for f,k in zip(obj.data.polygons,mi):f.material_index=k
    a.bevel(obj,.008,1)
    grip(a,'navy','gold','gold',kind='chevrons',accent='lavender')
    for i,z in enumerate([.64,2.92]):
        rr=radius(p,z)+.024
        ring(a,'Crystal collar %d navy seam'%(i+1),z,rr+.012,.215,'navy',segments=6)
        ring(a,'Crystal collar %d gold frame'%(i+1),z,rr+.015,.191,'gold',segments=6)
        ring(a,'Crystal collar %d cream inset'%(i+1),z,rr+.017,.121,'cream',segments=6)
        for th in [-pi/3,pi/3,pi]:
            pos=(rr*.90*sin(th),-rr*.90*cos(th),z)
            stud=disc(a,'Gold crystal fastener %d %.2f'%(i,th),*pos,.033,.027,'gold',6);stud.rotation_euler=(pi/2,0,th)
    a.root['DesignDetails']='Six broad opaque facets; blunt chamfered tip; two cream-and-gold reinforcing collars'


def build(spec):
    a=Asset(spec)
    globals()[spec['id']](a)
    for obj in a.objects:
        for mat in obj.data.materials:
            shader=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
            shader.inputs['Roughness'].default_value=.29
            if 'Coat Weight' in shader.inputs:shader.inputs['Coat Weight'].default_value=.22
    a.root['asset_role']='Bulldog cosmetic bat'
    a.root['grip_pivot']='Origin in hand grip; barrel along +Z; GripAttachment authored at origin'
    a.root['collision_note']='Visual cosmetic only. Use a simple noncolliding mesh and server-defined reach.'
    a.root['EditableConstruction']='Separate named mesh parts, support loops, curved extrusions, bevels, reusable material zones'
    return a
