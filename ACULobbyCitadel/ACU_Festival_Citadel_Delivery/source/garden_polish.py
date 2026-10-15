from common import *
from gardens import PetalMesh, ellipse_disk


def tip_center(ob, sides):
    points=[ob.matrix_world @ v.co for v in list(ob.data.vertices)[-sides:]]
    return sum(points,Vector((0,0,0)))/len(points)


def blossom_mass(name, center, scale, group, rng, hero=False, foliage=False):
    x,y,z=center
    sx,sy,sz=scale
    sides=24 if hero else 16
    levels=6 if hero else 5
    phase=rng.uniform(0,2*pi)
    verts=[(x,y,z-sz*.78)]
    for j in range(1,levels):
        lat=-pi/2+j*pi/levels
        for i in range(sides):
            a=i*2*pi/sides
            lobe=1+.115*sin(5*a+phase)+.065*sin(9*a-phase)+rng.uniform(-.065,.065)
            rr=cos(lat)*lobe
            # Flattened layered bough masses, with scalloped tips and raised floral ridges.
            zz=sin(lat)*sz + .12*sz*sin(4*a+phase)+rng.uniform(-.085,.085)*sz
            verts.append((x+sx*rr*cos(a),y+sy*rr*sin(a),z+zz))
    verts.append((x+sx*.06*sin(phase),y+sy*.04*cos(phase),z+sz*1.02))
    lower=[];upper=[]
    for i in range(sides): lower.append((0,1+(i+1)%sides,1+i))
    for j in range(levels-2):
        target=lower if j<1 else upper
        for i in range(sides):
            a=1+j*sides+i;b=1+j*sides+(i+1)%sides
            target.extend([(a,b,b+sides),(a,b+sides,a+sides)])
    cap=len(verts)-1;last=1+(levels-2)*sides
    for i in range(sides): upper.append((last+i,last+(i+1)%sides,cap))
    mesh(name+'_Shadow',verts,lower,'leaf' if foliage else 'blossom',group)
    mesh(name+'_Crown',verts,upper,'leafLight' if foliage else 'blossomLight',group)


def enhance_tree(prefix, scale, hero=False):
    group='46_CanopyPolish'
    rng=random.Random(8100+sum(ord(c) for c in prefix))
    branch_tips=[]; bough_tips=[]
    for ob in list(bpy.data.objects):
        if ob.type!='MESH': continue
        if ob.name.startswith(prefix+'_FineBranch_'): branch_tips.append(tip_center(ob,6))
        elif ob.name.startswith(prefix+'_Bough_'): bough_tips.append(tip_center(ob,8))
    assert branch_tips, 'Missing source branches for '+prefix
    petals=PetalMesh(prefix+'_CanopyEdgePetals',group)
    masses=[]
    for i,c in enumerate(branch_tips):
        masses.append((c+Vector((0,0,.55*scale)),(4.75*scale,3.85*scale,2.0*scale)))
        if hero:
            a=i*2.31
            masses.append((c+Vector((cos(a)*2.9*scale,sin(a)*2.2*scale,-.45*scale)),(3.2*scale,2.9*scale,1.35*scale)))
            masses.append((c+Vector((-cos(a)*2.3*scale,-sin(a)*2.3*scale,1.08*scale)),(3.3*scale,2.65*scale,1.4*scale)))
    for i,c in enumerate(bough_tips):
        masses.append((c+Vector((0,0,.28*scale)),(4.1*scale,3.55*scale,1.55*scale)))
        if hero:
            masses.append((c+Vector((1.1*scale,1.5*scale,2.7*scale)),(3.6*scale,3.1*scale,1.45*scale)))
    if hero:
        masses.extend([(Vector((45.1,73.1,34.9)),(5.3,4.4,2.3)),(Vector((49.6,75.4,37.1)),(4.2,3.55,1.8)),(Vector((40.8,75.3,33.3)),(4.7,4.0,1.9))])
    for i,(c,s) in enumerate(masses):
        blossom_mass(prefix+'_DenseBough_%03d'%i,c,s,group,rng,hero=hero)
        # Sharp individual petals break the silhouette and keep the volumes botanical.
        for k in range(28 if hero else 18):
            a=rng.random()*2*pi
            radial=rng.uniform(.8,1.08)
            p=c+Vector((cos(a)*s[0]*radial,sin(a)*s[1]*radial,rng.uniform(-.28,.64)*s[2]))
            petals.lens(p,.62*scale,.34*scale,.12*scale,a+rng.uniform(-.8,.8),rng.uniform(-.5,.7),'blossomLight' if k%3 else 'blossom')
    petals.finish()


def flower_bed(name, center, radii, rng):
    group='47_GardenBeds'
    x,y=center;rx,ry=radii
    ellipse_disk(name+'_Foundation',(x,y,1.4),rx+.65,ry+.65,.37,'stoneDark',group,sides=48)
    ellipse_disk(name+'_Soil',(x,y,1.64),rx,ry,.26,'moss',group,sides=48)
    points=[]
    for i in range(49):
        a=2*pi*i/48
        points.append((x+(rx+.35)*cos(a),y+(ry+.35)*sin(a),1.74))
    tube(name+'_RaisedStoneCurb',points,[.29]*len(points),'stoneLight',group,sides=6)
    tube(name+'_FineGoldInlay',[(a,b,c+.17) for a,b,c in points],[.045]*len(points),'gold',group,sides=5)
    for i in range(5):
        a=i*2*pi/5
        c=(x+rx*.46*cos(a),y+ry*.32*sin(a),2.08+rng.uniform(-.2,.3))
        blossom_mass(name+'_LowShrub_%02d'%i,c,(rx*.28,ry*.39,.85),'47_GardenBeds',rng,foliage=True)
    flower=PetalMesh(name+'_GroundFlowers',group)
    grassverts=[];grassfaces=[]
    for i in range(55):
        a=rng.random()*2*pi
        radial=rng.uniform(.48,.89)
        xx=x+cos(a)*rx*radial;yy=y+sin(a)*ry*radial
        zz=1.79+rng.uniform(.15,.65)
        stemlen=zz-1.72
        if i%3==0:
            for k in range(5):
                ang=k*2*pi/5
                flower.lens((xx+.19*cos(ang),yy+.19*sin(ang),zz),.31,.16,.055,ang,.18,'blossomLight' if i%2 else 'ivory')
            flower.lens((xx,yy,zz+.03),.105,.105,.08,0,0,'goldLight')
        else:
            flower.lens((xx,yy,zz),.42,.22,.08,a,.6,'blossom' if i%2 else 'blossomLight')
            flower.lens((xx,yy,zz-.17),.32,.16,.07,a+1.8,.5,'leafLight')
        start=len(grassverts)
        grassverts.extend([(xx-.035,yy,1.74),(xx+.035,yy,1.74),(xx+.02,yy,zz)])
        grassfaces.append((start,start+1,start+2))
    for i in range(38):
        a=rng.random()*2*pi
        radial=rng.uniform(.35,.95)
        xx=x+cos(a)*rx*radial;yy=y+sin(a)*ry*radial
        for k in range(3):
            ang=a+k*2.1; h=rng.uniform(.45,1.2)
            offset=len(grassverts)
            grassverts.extend([(xx-.085*cos(ang),yy-.085*sin(ang),1.8),(xx+.085*cos(ang),yy+.085*sin(ang),1.8),(xx+.22*cos(ang),yy+.22*sin(ang),1.8+h*.72),(xx+.4*cos(ang),yy+.4*sin(ang),1.8+h)])
            grassfaces.extend([(offset,offset+1,offset+2),(offset+1,offset+3,offset+2)])
    mesh(name+'_FineGrasses',grassverts,grassfaces,'leaf',group)
    flower.finish()
    for j in range(3):
        a=(j+.35)*2*pi/3
        c=(x+(rx+.05)*cos(a),y+(ry+.05)*sin(a),2.03)
        cylinder(name+'_GardenGlow',c,.18,.26,'goldGlow',group,vertices=8)


def build():
    enhance_tree('Hero_Sakura',1.12,hero=True)
    tree_sites=[(-97,18,.48),(-79,62,.5),(-25,96,.48),(25,98,.44),(96,27,.47),(92,-27,.42),(73,-70,.44),(-91,-52,.42),(-43,-85,.47)]
    for i,(_,_,scale) in enumerate(tree_sites):
        enhance_tree('Garden_Sakura_%02d'%i,scale)
    rng=random.Random(422619)
    for i,(center,radii) in enumerate([((-22,-67),(7,4.2)),((28,-68),(7.4,4.3)),((-30,44.5),(5.5,3.5)),((29,44),(6.2,4)),((78,-23),(6,4.2))]):
        flower_bed('ComposedGarden_%02d'%i,center,radii,rng)
