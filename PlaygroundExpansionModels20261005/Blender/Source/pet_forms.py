from assetlib import Asset
from math import sin, cos, pi, sqrt
from mathutils import Vector


def signpow(v, power):
    return (1 if v >= 0 else -1) * abs(v) ** power


class Pet:
    def __init__(self, spec):
        self.a = Asset(spec)
        self.bone = 'Body'
        self.a.rig_bones = {
            'Root': {'head': (0, 0, 0), 'tail': (0, 0, .3), 'parent': None},
            'Body': {'head': (0, 0, .7), 'tail': (0, 0, 1.6), 'parent': 'Root'},
            'Head': {'head': (0, -.45, 1.7), 'tail': (0, -.45, 2.6), 'parent': 'Body'},
        }

    def joint(self, name, head, tail, parent='Body'):
        self.a.rig_bones[name] = {'head': head, 'tail': tail, 'parent': parent}
        self.bone = name

    def tag(self, obj):
        obj['RigBone'] = self.bone
        return obj

    def blob(self, name, loc, scale, color, power=.9, n=28, rings=18):
        vertices = [(0, 0, -scale[2])]
        for j in range(1, rings):
            z = -pi/2 + pi*j/rings
            c = signpow(cos(z), power)
            for i in range(n):
                t = 2*pi*i/n
                vertices.append((scale[0]*c*signpow(cos(t), power), scale[1]*c*signpow(sin(t), power), scale[2]*signpow(sin(z), power)))
        vertices.append((0, 0, scale[2]))
        top = len(vertices)-1
        faces = [(0, 1+(i+1)%n, 1+i) for i in range(n)]
        for j in range(rings-2):
            for i in range(n):
                a=1+j*n+i; b=1+j*n+(i+1)%n
                faces.append((a,b,b+n,a+n))
        faces += [(1+(rings-2)*n+i, 1+(rings-2)*n+(i+1)%n, top) for i in range(n)]
        obj=self.a.mesh(name,vertices,faces,color,True)
        obj.location=loc
        return self.tag(obj)

    def box(self,name,loc,size,color,bevel=.07,rotation=None):
        obj=self.a.box(name,loc,size,color,bevel,rotation)
        for m in obj.modifiers: m.segments=4
        for poly in obj.data.polygons: poly.use_smooth=True
        try:
            m=obj.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');m.keep_sharp=True
        except Exception: pass
        return self.tag(obj)

    def ring(self,name,loc,major,minor,color,rotation=None,scale=None):
        obj=self.a.torus(name,loc,major,minor,color,rotation,40,12)
        if scale: obj.scale=scale
        return self.tag(obj)

    def lathe(self,name,profile,color,loc=(0,0,0),scale=None,n=40):
        obj=self.a.lathe(name,profile,color,loc,n)
        if scale:obj.scale=scale
        return self.tag(obj)

    def path(self,name,points,radii,color,n=12,steps=4):
        pts=[Vector(v) for v in points]
        rr=radii if isinstance(radii,(tuple,list)) else [radii]*len(pts)
        if len(pts)>2:
            pp=[]; rad=[]
            for i in range(len(pts)-1):
                p0=pts[max(0,i-1)];p1=pts[i];p2=pts[i+1];p3=pts[min(len(pts)-1,i+2)]
                for j in range(steps):
                    t=j/steps
                    p=.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)
                    pp.append(tuple(p));rad.append(rr[i]*(1-t)+rr[i+1]*t)
            pp.append(tuple(pts[-1]));rad.append(rr[-1])
        else:pp=[tuple(p) for p in pts];rad=rr
        return self.tag(self.a.tube(name,pp,rad,color,n))

    def plate(self,name,points,depth,color,y=0,bevel=.03):
        obj=self.a.prism(name,points,depth,color,y,bevel)
        for m in obj.modifiers:m.segments=3
        return self.tag(obj)

    def leaf(self,name,start,end,width,thickness,color,bend=(0,0,0),normal=(0,-1,0)):
        s=Vector(start);e=Vector(end);d=(e-s).normalized();nn=Vector(normal)
        nn=(nn-d*nn.dot(d)).normalized()
        if nn.length<.1:nn=Vector((1,0,0))
        side=d.cross(nn).normalized()
        verts=[];rows=[]
        for t,w in [(0,.34),(.10,.65),(.28,.97),(.49,1),(.70,.82),(.86,.49),(.96,.19),(1,.025)]:
            mid=s.lerp(e,t)+Vector(bend)*sin(pi*t)
            rows.append(len(verts))
            for j in range(12):
                theta=2*pi*j/12
                ridge=1.2 if j in (2,3,4) else 1
                p=mid+side*(cos(theta)*width*w)+nn*(sin(theta)*thickness*w*ridge)
                verts.append(tuple(p))
        faces=[tuple(reversed(range(12)))]
        for i in range(len(rows)-1):
            a=rows[i];b=rows[i+1]
            for j in range(12):faces.append((a+j,a+(j+1)%12,b+(j+1)%12,b+j))
        faces.append(tuple(range(rows[-1],rows[-1]+12)))
        return self.tag(self.a.mesh(name,verts,faces,color,True))

    def eye(self,name,x,y,z,size=.28,iris='cyan',simple=False):
        self.blob(name+'_socket',(x,y+.045,z),(size*1.1,.115,size*1.23),'navy',.88,24,16)
        if simple:
            self.blob(name+'_gloss',(x,y-.012,z),(size,.12,size*1.12),'navy',.9,24,16)
            self.blob(name+'_highlight',(x-size*.27,y-.132,z+size*.4),(size*.29,.028,size*.32),'white',1,16,10)
            self.blob(name+'_spark',(x+size*.29,y-.12,z-size*.27),(size*.12,.022,size*.13),'white',1,12,8)
            return
        self.blob(name+'_sclera',(x,y-.016,z),(size,.115,size*1.12),'white',.88,24,16)
        self.blob(name+'_iris',(x,y-.108,z-.012),(size*.65,.055,size*.83),iris,1,24,16)
        self.blob(name+'_pupil',(x,y-.145,z+.006),(size*.40,.041,size*.66),'navy',1,24,16)
        self.blob(name+'_catchlight',(x-size*.18,y-.183,z+size*.37),(size*.23,.018,size*.28),'white',1,16,10)
        self.blob(name+'_spark',(x+size*.25,y-.18,z-size*.25),(size*.09,.017,size*.10),'white',1,12,8)

    def smile(self,name,loc,width=.38,height=.19,tongue=True,teeth=0):
        x,y,z=loc
        points=[(x-width,z+height*.5),(x-width*.72,z-height*.45),(x-width*.3,z-height),(x+width*.3,z-height),(x+width*.72,z-height*.45),(x+width,z+height*.5),(x+width*.4,z+height*.13),(x-width*.4,z+height*.13)]
        self.plate(name+'_mouth',points,.055,'navy',y,.014)
        if tongue:self.blob(name+'_tongue',(x,y-.044,z-height*.63),(width*.45,.038,height*.29),'coral',.78,20,12)
        for i in range(teeth):
            tx=x+width*.9*((i+.5)/teeth*2-1)
            self.box(name+'_tooth_'+str(i+1),(tx,y-.044,z+height*.12),(width*1.3/max(1,teeth),.09,height*.62),'cream',.026)

    def nostrils(self,name,center,width=.2,size=.055):
        x,y,z=center
        for s in [-1,1]:
            self.blob(name+str(s),(x+s*width,y,z),(size,.026,size*.7),'navy',1,16,10)

    def brow(self,name,x,y,z,color,ang=0,width=.28):
        obj=self.blob(name,(x,y,z),(width,.10,.075),color,.8,20,12)
        obj.rotation_euler.y=ang

    def paws(self,color,claw='cream',width=.62,front=-.5,rear=.58,z=.36,scale=(.32,.4,.38),cuffs=None):
        for row,y in [('Front',front),('Back',rear)]:
            for s,label in [(-1,'L'),(1,'R')]:
                self.joint(row+'Leg'+label,(s*width,y,.95),(s*width,y,z))
                self.blob(row+'Leg'+label,(s*width,y,z+.15),scale,color,.72)
                if cuffs:self.ring(row+'AnkleCuff'+label,(s*width,y,z+.17),.35,.045,cuffs,scale=(1,1.08,1))
                for k in range(3):
                    self.blob(row+'Toe'+label+str(k),(s*width+(k-1)*.17,y-scale[1]*.88,z-.10),(.087,.14,.10),claw,.78,18,12)
        self.bone='Body'

    def belly(self,color='cream',center=(0,-.63,1.30),width=.53,height=.80,segments=4):
        for i in range(segments):
            t=i/(segments-1) if segments>1 else .5
            z=center[2]+height*(.5-t)
            w=width*(.82+.18*sin(pi*t))
            self.blob('BellyShield_'+str(i+1),(0,center[1]-.045*sin(pi*t),z),(w,.13,height/segments*.60),color,.66,28,12)

    def cheek(self,x,y,z,color='pink',size=.16):
        self.blob('Cheek'+str(x),(x,y,z),(size,.035,size*.55),color,.9,20,12)

    def finish(self):
        self.a.root['EditableDesign']='Named mesh forms, bevel modifiers, palette materials and rigid skeletal parts'
        self.a.root['SourceReferenceCount']=1
        return self.a
