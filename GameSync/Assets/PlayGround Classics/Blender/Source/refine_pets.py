from assetlib import *
from math import sin, cos, pi, exp
from mathutils import Vector


def remove_parts(a, names=(), prefixes=()):
    for obj in list(a.objects):
        part=obj.get('Part','')
        if part in names or any(part.startswith(prefix) for prefix in prefixes):
            a.objects.remove(obj)
            bpy.data.objects.remove(obj,do_unlink=True)


def cubic_outline(curves, samples=7):
    points=[]
    for segment in curves:
        p0,p1,p2,p3=[Vector(p) for p in segment]
        for j in range(samples):
            t=j/samples;u=1-t
            p=p0*u**3+p1*3*u*u*t+p2*3*u*t*t+p3*t**3
            points.append(tuple(p))
    return points


def rounded_polygon(points, amount=.22, samples=4):
    result=[]
    for i,p in enumerate(points):
        p=Vector(p)
        start=p.lerp(Vector(points[i-1]),amount)
        end=p.lerp(Vector(points[(i+1)%len(points)]),amount)
        for j in range(samples):
            t=j/(samples-1);u=1-t
            result.append(tuple(start*u*u+p*2*u*t+end*t*t))
    return result


def traffic_claws(a):
    remove_parts(a,prefixes=('ClawPalm_','ClawOuterFinger_','ClawInnerFinger_'))
    curves=[[(.90,1.80),(1.10,1.91),(1.39,1.77),(1.36,1.48)],
            [(1.36,1.48),(1.35,1.19),(1.25,1.045),(1.06,1.08)],
            [(1.06,1.08),(.85,1.09),(.77,1.29),(.805,1.545)]]
    radii=[(0,.025),(.06,.095),(.19,.16),(.38,.215),(.61,.235),(.78,.18),(.92,.10),(1,.025)]
    def surface(t,theta,side,offset=0):
        scaled=min(2.999999,t*3);section=int(scaled);tt=scaled-section;u=1-tt
        p0,p1,p2,p3=[Vector(p) for p in curves[section]]
        p=p0*u**3+p1*3*u*u*tt+p2*3*u*tt*tt+p3*tt**3
        tangent=((p1-p0)*3*u*u+(p2-p1)*6*u*tt+(p3-p2)*3*tt*tt).normalized()
        normal=Vector((-tangent.y,tangent.x))
        radius=smooth_profile(radii,t)
        q=p+normal*(radius+offset)*cos(theta)
        return (q.x*side,-.075+(radius*.80+.025+offset)*sin(theta),q.y)
    def inset(name,start,end,side,color,offset,theta0,theta1):
        rows=11;cols=9;vertices=[];faces=[]
        for shell_offset in [offset,offset-.015]:
            for i in range(rows):
                t=start+(end-start)*i/(rows-1)
                for j in range(cols):
                    vertices.append(surface(t,theta0+(theta1-theta0)*j/(cols-1),side,shell_offset))
        shell=rows*cols
        for i in range(rows-1):
            for j in range(cols-1):
                p=i*cols+j
                faces.extend([(p,p+1,p+cols+1,p+cols),
                              (p+shell,p+cols+shell,p+cols+1+shell,p+1+shell)])
        border=list(range(cols))+[i*cols+cols-1 for i in range(1,rows)]+list(range(shell-2,shell-cols-1,-1))+[i*cols for i in range(rows-2,0,-1)]
        for j,p in enumerate(border):
            q=border[(j+1)%len(border)]
            faces.append((p,p+shell,q+shell,q))
        return a.mesh(name,vertices,faces,color,smooth=True)
    for side in [-1,1]:
        label='Left' if side<0 else 'Right'
        rows=65;cols=20;vertices=[];faces=[]
        for i in range(rows):
            for j in range(cols):vertices.append(surface(i/(rows-1),2*pi*j/cols,side))
        for i in range(rows-1):
            for j in range(cols):
                nxt=(j+1)%cols
                faces.append((i*cols+j,i*cols+nxt,(i+1)*cols+nxt,(i+1)*cols+j))
        faces.append(tuple(range(cols-1,-1,-1)))
        faces.append(tuple((rows-1)*cols+j for j in range(cols)))
        a.mesh(label+' Volumetric Moulded Open Pincer',vertices,faces,'blue',smooth=True)
        for name,start,end in [('Upper',.045,.285),('Lower',.83,.98)]:
            inset(label+' '+name+' Curved Pincer Inset Seam',start-.006,end+.006,side,'navy',.006,-2.91,-1.65)
            inset(label+' '+name+' Cream Biting Surface',start,end,side,'cream',.013,-2.85,-1.72)
    a.root['Claw construction']='Each pincer is a continuous variable-section curved loft with full moulded volume, an open pinch gap, and cream insets following the curved jaw surface.'


def closed_loft(a,name,rings,color,segments=72):
    vertices=[]
    for ring in rings:
        for i in range(segments):
            vertices.append(ring(2*pi*i/segments))
    faces=[]
    for k in range(len(rings)-1):
        for i in range(segments):
            j=(i+1)%segments
            faces.append((k*segments+i,k*segments+j,(k+1)*segments+j,(k+1)*segments+i))
    bottom=len(vertices)
    vertices.append(tuple(sum(v[d] for v in vertices[:segments])/segments for d in range(3)))
    top=len(vertices)
    vertices.append(tuple(sum(v[d] for v in vertices[(len(rings)-1)*segments:len(rings)*segments])/segments for d in range(3)))
    for i in range(segments):
        j=(i+1)%segments
        faces.append((bottom,j,i))
        offset=(len(rings)-1)*segments
        faces.append((top,offset+i,offset+j))
    return a.mesh(name,vertices,faces,color,smooth=True)


def ghost_hem(a):
    remove_parts(a,names=('WavyGhostBody',))
    shape=[(.52,.083,.034,.026),(.61,.096,.045,.045),(.663,.145,.040,.047),
           (.672,.195,.031,.039),(.628,.257,.024,.024),(.565,.322,.013,.010),
           (.510,.405,.005,0),(.47,.50,0,0),(.421,.64,0,0),(.34,.80,0,0),(.20,.90,0,0)]
    rings=[]
    for radius,z,radial_wave,vertical_wave in shape:
        def ring(t,radius=radius,z=z,radial_wave=radial_wave,vertical_wave=vertical_wave):
            wave=cos(6*t+.30)
            r=radius+radial_wave*wave
            return (r*cos(t),r*.82*sin(t),z+vertical_wave*wave)
        rings.append(ring)
    closed_loft(a,'Continuous White Waving Ghost Hem',rings,'white',72)
    a.root['Ghost construction']='Single closed flowing bell mesh with six soft draped hem lobes. No separate legs or boot shapes.'


def smooth_profile(points,z):
    for i in range(len(points)-1):
        if points[i][0]<=z<=points[i+1][0]:
            z0,r0=points[i];z1,r1=points[i+1]
            pz,pr=points[max(0,i-1)];nz,nr=points[min(len(points)-1,i+2)]
            m0=(r1-pr)/(z1-pz) if z1!=pz else 0
            m1=(nr-r0)/(nz-z0) if nz!=z0 else 0
            t=(z-z0)/(z1-z0)
            return max(0,(2*t**3-3*t*t+1)*r0+(t**3-2*t*t+t)*(z1-z0)*m0+(-2*t**3+3*t*t)*r1+(t**3-t*t)*(z1-z0)*m1)
    return points[0][1] if z<points[0][0] else points[-1][1]


def royal_blob(a):
    remove_parts(a,names=('SlimeBody',),prefixes=('BaseScallop_','HandNub_'))
    profile=[(.06,.40),(.10,.58),(.18,.67),(.31,.68),(.49,.64),(.76,.64),
             (1.02,.61),(1.22,.55),(1.38,.43),(1.48,.255),(1.525,.09)]
    rings=[]
    for j in range(41):
        z=.06+(1.525-.06)*j/40
        radius=smooth_profile(profile,z)
        def ring(t,z=z,radius=radius):
            phase=6*t+pi/2
            scallop=.093*exp(-((z-.155)/.145)**2)*cos(phase)
            hand=0
            for angle in [-.18,pi+.18]:
                delta=(t-angle+pi)%(2*pi)-pi
                hand+=.19*exp(-(delta/.265)**2-((z-.66)/.185)**2)
            r=radius+scallop+hand
            return (r*cos(t),.035+r*.82*sin(t),z)
        rings.append(ring)
    closed_loft(a,'Unified Cobalt Slime with Integrated Scallops',rings,'blue',72)
    a.root['Slime construction']='One continuous lofted blob mesh; side nubs and six lower lobes are deformations of the same surface, not attached spheres.'


def ufo_jelly(a):
    remove_parts(a,names=('JellyBell',),prefixes=('Tentacle_','TentacleTip_','BellScallop_'))
    for obj in a.objects:
        part=obj.get('Part','')
        if part.startswith('Saucer') or part in ('DomeCollar','OpaqueIceDome'):
            obj.location.z+=.30
    profile=[(.635,.27),(.69,.47),(.78,.60),(.93,.665),(1.12,.645),
             (1.30,.545),(1.43,.385),(1.51,.17),(1.54,.07)]
    rings=[]
    for j in range(25):
        z=.635+(1.54-.635)*j/24
        radius=smooth_profile(profile,z)
        def ring(t,z=z,radius=radius):
            r=radius+.025*cos(6*t)*exp(-((z-.70)/.14)**2)
            return (r*cos(t),.02+r*.75*sin(t),z)
        rings.append(ring)
    closed_loft(a,'Sculpted Lilac Jelly Bell',rings,'lavender',64)
    for k,x in enumerate([-.49,-.165,.165,.49]):
        curve=[Vector((x*.71,.035,.795)),Vector((x*.82,.015,.58)),
               Vector((x*1.40,-.15,.22)),Vector((x*1.22,-.14,.090))]
        vertices=[];faces=[];side_count=16;row_count=25
        radii=[(0,.135),(.25,.157),(.55,.174),(.76,.164),(.89,.126),(1,.016)]
        for j in range(row_count):
            t=j/(row_count-1);u=1-t
            p=curve[0]*u**3+curve[1]*3*u*u*t+curve[2]*3*u*t*t+curve[3]*t**3
            tangent=((curve[1]-curve[0])*3*u*u+(curve[2]-curve[1])*6*u*t+(curve[3]-curve[2])*3*t*t).normalized()
            horizontal=Vector((1,0,0))
            horizontal=(horizontal-tangent*horizontal.dot(tangent)).normalized()
            depth=tangent.cross(horizontal).normalized()
            radius=smooth_profile(radii,t)
            for i in range(side_count):
                angle=2*pi*i/side_count
                p2=p+horizontal*radius*cos(angle)+depth*radius*.76*sin(angle)
                vertices.append(tuple(p2))
        for j in range(row_count-1):
            for i in range(side_count):
                nxt=(i+1)%side_count
                faces.append((j*side_count+i,j*side_count+nxt,(j+1)*side_count+nxt,(j+1)*side_count+i))
        faces.append(tuple(range(side_count-1,-1,-1)))
        tip=len(vertices);vertices.append(tuple(curve[3]+Vector((0,0,-.007))))
        for i in range(side_count):
            faces.append((tip,(row_count-1)*side_count+i,(row_count-1)*side_count+(i+1)%side_count))
        a.mesh('Continuous Tapered Jelly Tentacle '+str(k+1),vertices,faces,'lavender',smooth=True)
    a.root['Jelly construction']='Raised saucer reveals full face; one lofted bell and four broad curved variable-section tentacles with integrated rounded tips.'


def build_overrides(a, asset_id):
    refinements={'P06':traffic_claws,'P12':ufo_jelly,'P14':ghost_hem,'P20':royal_blob}
    fn=refinements.get(asset_id.upper())
    if fn:fn(a)
    return a
