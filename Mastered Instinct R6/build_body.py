import bpy, math, random
from mathutils import Vector

PREFIX = 'MI_'

def material(name, color, rough=.48, metallic=0.0, emission=0.0):
    m=bpy.data.materials.new(PREFIX+name)
    m.diffuse_color=(*color,1)
    m.use_nodes=True
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough
    p.inputs['Metallic'].default_value=metallic
    if emission:
        p.inputs['Emission Color'].default_value=(*color,1)
        p.inputs['Emission Strength'].default_value=emission
    return m

def build_body(collection):
    mats={
        'skin':material('Warm battle skin',(.62,.32,.16)),
        'skin_light':material('Muscle planes',(.76,.43,.24)),
        'skin_shadow':material('Skin crease',(.26,.09,.055)),
        'scar':material('Healed battle scratches',(.24,.048,.042)),
        'orange':material('Gi burnt orange',(.75,.145,.015),.77),
        'orange_light':material('Gi raised folds',(.97,.29,.035),.74),
        'orange_dark':material('Gi fold shadows',(.27,.044,.008),.83),
        'blue':material('Indigo torn undershirt',(.018,.04,.145),.74),
        'blue_light':material('Worn fabric ridges',(.035,.10,.30),.65),
        'blue_dark':material('Fabric deep seams',(.006,.012,.036),.8),
        'red':material('Crimson boot piping',(.46,.02,.035)),
        'rope':material('Boot ties',(.68,.42,.13),.8),
        'ink':material('Anime charcoal',(.008,.01,.023),.65),
        'white':material('Eye whites',(.9,.94,1),.3),
        'iris':material('Instinct silver eyes',(.18,.36,.46),.28,.25),
        'silver':material('Silver eyebrows',(.72,.78,.85),.36,.22),
    }
    objects=[]
    def record(o,part):
        o['r6_part']=part
        objects.append(o)
        return o
    def mesh(name,verts,faces,mat,part,smooth=False):
        d=bpy.data.meshes.new(PREFIX+name)
        d.from_pydata(verts,[],faces);d.update()
        o=bpy.data.objects.new(PREFIX+name,d);collection.objects.link(o)
        d.materials.append(mats[mat] if isinstance(mat,str) else mat)
        for p in d.polygons:p.use_smooth=smooth
        return record(o,part)
    def box(name,loc,size,mat,part,bevel=.07):
        x,y,z=[v/2 for v in size]
        verts=[(a*x,b*y,c*z) for a,b,c in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]]
        faces=[(0,4,5,1),(2,3,7,6),(0,1,3,2),(4,6,7,5),(0,2,6,4),(1,5,7,3)]
        o=mesh(name,verts,faces,mat,part);o.location=loc
        if bevel:
            b=o.modifiers.new('Soft sculpted edges','BEVEL');b.width=bevel;b.segments=3
            n=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');n.keep_sharp=True;n.weight=35
        return o
    def patch(name,poly,y,depth,mat,part):
        # Rounded anatomical mound, raised from the block body rather than separate spheres.
        cx=sum(p[0] for p in poly)/len(poly);cz=sum(p[1] for p in poly)/len(poly)
        n=len(poly);v=[]
        for scale,d in [(1,0),(.91,.55),(.70,.9),(.22,1)]:
            v += [(cx+(x-cx)*scale,y-depth*d,cz+(z-cz)*scale) for x,z in poly]
        f=[]
        for k in range(3):
            for i in range(n):f.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
        f.append(tuple(range(3*n,4*n)))
        return mesh(name,v,f,mat,part,True)
    def sheet(name,poly,y,mat,part,thickness=.028):
        n=len(poly);v=[(x,y,z) for x,z in poly]+[(x,y+thickness,z) for x,z in poly]
        f=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
        f.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
        return mesh(name,v,f,mat,part)
    def line(name,points,radius,mat,part):
        # Polygonal tubes keep scratches, seams and boot trim exportable as ordinary mesh.
        v=[];f=[];sides=5
        points=[Vector(p) for p in points]
        for j,p in enumerate(points):
            tangent=points[min(j+1,len(points)-1)]-points[max(j-1,0)]
            tangent.normalize();u=tangent.cross(Vector((0,1,0)))
            if u.length<.01:u=tangent.cross(Vector((1,0,0)))
            u.normalize();w=tangent.cross(u).normalized()
            r=radius*(.4 if j in (0,len(points)-1) else 1)
            for k in range(sides):v.append(tuple(p+r*(u*math.cos(k*math.tau/sides)+w*math.sin(k*math.tau/sides))))
        for j in range(len(points)-1):
            for k in range(sides):f.append((j*sides+k,j*sides+(k+1)%sides,(j+1)*sides+(k+1)%sides,(j+1)*sides+k))
        f+=[tuple(range(sides-1,-1,-1)),tuple(range((len(points)-1)*sides,len(points)*sides))]
        return mesh(name,v,f,mat,part,True)

    # Core R6 proportions; no elbows, knees or finger bones.
    box('Torso core',(0,0,3.025),(2,1,2.05),'skin','Torso',.105)
    box('Neck',(0,0,4.09),(.65,.69,.32),'skin','Head',.095)
    box('Head',(0,-.015,4.68),(1.5,1.10,1.12),'skin','Head',.16)
    for s,side in [(-1,'Right'),(1,'Left')]:
        part=side+' Arm';x=s*1.565
        box(side+' arm core',(x,0,3.02),(1.07,1.02,2.03),'skin',part,.12)
        poly=[(x-.42,3.56),(x-.38,3.87),(x-.13,4.035),(x+.20,4.04),(x+.44,3.85),(x+.44,3.51),(x+.18,3.38),(x-.14,3.39)]
        patch(side+' deltoid',poly,-.455,.22,'skin_light',part)
        poly=[(x-.32,2.96),(x-.37,3.20),(x-.23,3.48),(x+.16,3.46),(x+.33,3.20),(x+.28,2.95),(x,2.87)]
        patch(side+' bicep',poly,-.48,.195,'skin',part)
        patch(side+' forearm',[(x-.31,2.57),(x-.36,2.86),(x-.15,3.01),(x+.26,2.91),(x+.35,2.58),(x+.17,2.42),(x-.13,2.44)],-.47,.10,'skin_light',part)
        box(side+' wrist wrap',(x,-.005,2.39),(1.10,1.06,.31),'blue',part,.075)
        for dz in [-.10,.015,.11]:
            line(side+' wrist wrap fold',[(x-.44,-.556,2.39+dz),(x-.11,-.576,2.40+dz),(x+.42,-.555,2.385+dz)],.015,'blue_light',part)
        # Sturdy R6 fists; shallow knuckle creases preserve the block silhouette.
        for dx in [-.23,0,.23]:line(side+' fist crease',[(x+dx,-.516,2.21),(x+dx+.015,-.527,2.09)],.012,'skin_shadow',part)
        # Ears retain the compact avatar head proportions.
        box(side+' ear',(s*.774,-.015,4.60),(.17,.36,.37),'skin','Head',.09)
        box(side+' ear inset',(s*.79,-.198,4.61),(.09,.018,.18),'skin_shadow','Head',.025)

    # Pectoral masses and six abdominal planes.
    for s,side in [(-1,'R'),(1,'L')]:
        p=[(.045,3.32),(.085,3.74),(.22,3.90),(.66,3.91),(.93,3.70),(.91,3.33),(.54,3.20),(.22,3.22)]
        patch(side+' pectoral',[(s*x,z) for x,z in p],-.47,.24,'skin_light','Torso')
        for j,(z,w,h) in enumerate([(3.03,.34,.26),(2.72,.32,.26),(2.43,.28,.23)]):
            x=s*.235
            p=[(x-w/2,z-h/2),(x-w/2-.055,z+.025),(x-w*.4,z+h/2),(x+w*.43,z+h/2),(x+w/2+.025,z+.025),(x+w*.42,z-h/2)]
            patch(side+' abdominal '+str(j),p,-.511,.105,'skin_light','Torso')
        patch(side+' oblique',[(s*.50,2.27),(s*.78,2.47),(s*.83,2.97),(s*.54,3.17),(s*.46,2.77)],-.485,.09,'skin','Torso')
        line(side+' collarbone',[(s*.09,-.532,3.94),(s*.40,-.62,3.99),(s*.77,-.50,3.95)],.027,'skin_light','Torso')

    # The undershirt has actual torn boundaries and an open chest.
    box('Undershirt back',(0,.515,3.07),(1.96,.065,1.85),'blue','Torso',.08)
    sheet('Torn shirt right front',[(-1.01,2.16),(-1.04,3.91),(-.73,4.035),(-.57,3.94),(-.71,3.77),(-.69,3.58),(-.84,3.66),(-.79,3.34),(-.68,3.18),(-.78,3.20),(-.60,2.98),(-.67,2.96),(-.54,2.79),(-.64,2.80),(-.50,2.46),(-.25,2.22),(-.60,2.34),(-.65,2.14),(-.82,2.30)],-.69,'blue','Torso')
    sheet('Torn shirt left front',[(1.01,2.13),(1.015,3.95),(.74,4.05),(.57,3.99),(.73,3.77),(.69,3.62),(.83,3.70),(.81,3.40),(.72,3.33),(.83,3.25),(.76,3.12),(.64,2.94),(.76,2.96),(.60,2.71),(.69,2.67),(.38,2.27),(.53,2.32),(.71,2.12),(.83,2.29)],-.687,'blue','Torso')
    for s in [-1,1]:
        box('Undershirt side',(s*.995,.01,3.12),(.06,.96,1.73),'blue','Torso',.02)
        sheet('Frayed shoulder tab',[(s*.64,4.045),(s*1.01,4.05),(s*1.04,3.82),(s*.95,3.91),(s*.9,3.79),(s*.84,3.94),(s*.75,3.88)],-.39,'blue_light','Torso')
        for i in range(3):
            x=s*(.77+i*.065)
            line('Cloth lifted edge',[(x,-.708,2.49+i*.24),(x+s*.045,-.712,2.8+i*.23)],.018,'blue_light','Torso')

    # Sash has a separate knot and two ragged tails attached rigidly to Torso.
    box('Dark blue sash',(0,-.015,2.12),(2.085,1.09,.27),'blue','Torso',.075)
    for z in [2.05,2.14,2.21]:line('Sash fold',[(-.94,-.559,z),(0,-.59,z-.02),(.95,-.55,z+.015)],.023,'blue_light','Torso')
    box('Sash knot',(.62,-.62,2.13),(.36,.22,.32),'blue_light','Torso',.10)
    sheet('Sash tail lower',[(.67,2.15),(.93,2.03),(1.05,1.72),(1.30,1.43),(1.18,1.45),(1.30,1.27),(.99,1.36),(.73,1.74),(.55,2.04)],-.60,'blue','Torso')
    sheet('Sash tail outer',[(.79,2.16),(1.12,2.13),(1.32,1.98),(1.76,1.90),(1.60,1.80),(1.74,1.69),(1.30,1.80),(1.05,1.94),(.74,2.02)],-.53,'blue_light','Torso')

    # Pants constructed as cloth surfaces around a hidden skin leg, with open jagged knee tears.
    for s,side in [(-1,'Right'),(1,'Left')]:
        x=s*.53;part=side+' Leg'
        box(side+' leg core',(x,0,1.02),(.94,.94,2.04),'skin',part,.065)
        lo=x-.52;hi=x+.52;kz=1.10 if s<0 else .95
        box(side+' pants back',(x,.485,1.32),(1.055,.08,1.39),'orange',part,.06)
        for edge in [-1,1]:box(side+' pants side',(x+edge*.498,.01,1.34),(.09,.94,1.39),'orange',part,.04)
        topedge=[(lo,2.03),(hi,2.03),(hi,kz+.15),(x+.41,kz+.12),(x+.34,kz+.23),(x+.18,kz+.08),(x+.10,kz+.18),(x-.03,kz+.11),(x-.17,kz+.23),(x-.26,kz+.13),(x-.4,kz+.27),(lo,kz+.17)]
        sheet(side+' torn upper pant',topedge,-.553,'orange',part)
        lower=[(lo,kz-.15),(x-.38,kz-.09),(x-.28,kz-.19),(x-.17,kz-.10),(x-.05,kz-.19),(x+.06,kz-.07),(x+.20,kz-.16),(x+.33,kz-.08),(hi,kz-.17),(hi,.58),(x+.33,.64),(x+.23,.54),(x+.13,.66),(x-.02,.57),(x-.13,.65),(x-.27,.54),(x-.40,.67),(lo,.60)]
        sheet(side+' torn lower pant',lower,-.554,'orange',part)
        # Raised broad folds, not thin drawn fabric lines.
        sheet(side+' thigh light fold',[(x-.38,1.94),(x-.07,1.86),(x+.32,kz+.27),(x+.08,kz+.35)],-.577,'orange_light',part)
        sheet(side+' thigh shadow',[(x+.28,2.02),(x+.42,1.82),(x+.31,kz+.31),(x+.13,kz+.23),(x+.25,1.67)],-.58,'orange_dark',part)
        sheet(side+' shin light fold',[(x-.36,kz-.20),(x+.26,.74),(x+.32,.65),(x-.14,.71)],-.58,'orange_light',part)
        sheet(side+' shin shadow',[(x-.36,kz-.17),(x-.41,.63),(x-.23,.65),(x-.18,.81)],-.583,'orange_dark',part)
        patch(side+' exposed knee',[(x-.38,kz-.13),(x-.31,kz+.14),(x+.20,kz+.17),(x+.38,kz-.12),(x+.05,kz-.20)],-.48,.05,'skin_light',part)
        # Ragged small torn fibers at boundaries.
        for i in range(7):
            xx=lo+.11+i*.14;zz=kz+.13+.05*math.sin(i*2)
            sheet(side+' knee fray '+str(i),[(xx-.045,zz+.10),(xx+.055,zz+.07),(xx+.014,zz-.045)],-.59,'orange_light',part)
        box(side+' boot',(x,-.07,.31),(1.015,1.18,.65),'blue',part,.105)
        box(side+' boot sole',(x,-.08,.065),(1.06,1.215,.125),'blue_dark',part,.045)
        sheet(side+' boot red stripe',[(x-.037,.12),(x+.037,.12),(x+.044,.61),(x-.034,.61)],-.679,'red',part)
        line(side+' toe red trim',[(x-.43,-.62,.10),(x-.40,-.677,.13),(x+.40,-.677,.13),(x+.43,-.62,.10)],.025,'red',part)
        line(side+' boot binding',[(x-.49,-.05,.53),(x-.48,-.55,.53),(x-.36,-.646,.525),(x+.36,-.646,.525),(x+.49,-.55,.53),(x+.49,.30,.53)],.037,'rope',part)
        for k in range(12):
            xx=x-.39+k*.071
            line(side+' rope braid',[(xx-.025,-.673,.50),(xx+.021,-.68,.553)],.014,'orange_light',part)

    # Anime eyes lie on the face, not a floating billboard.
    y=-.586
    for s,side in [(-1,'R'),(1,'L')]:
        def mirror(p):return [(s*x,z) for x,z in p]
        sheet(side+' eye ink',mirror([(.075,4.665),(.60,4.85),(.57,4.55),(.18,4.55)]),y-.022,'ink','Head')
        sheet(side+' eye white',mirror([(.15,4.669),(.552,4.80),(.53,4.591),(.215,4.588)]),y-.026,'white','Head')
        # Silver iris as clipped hexagonal motif with black pupil.
        ix=s*.345
        sheet(side+' silver iris',[(ix-.081,4.728),(ix+.077,4.747),(ix+.074,4.635),(ix+.036,4.601),(ix-.038,4.605),(ix-.080,4.641)],y-.032,'iris','Head')
        sheet(side+' pupil',[(ix-.027,4.731),(ix+.028,4.73),(ix+.025,4.628),(ix-.025,4.628)],y-.038,'ink','Head')
        sheet(side+' eye catchlight',[(ix-.035,4.705),(ix-.004,4.71),(ix-.004,4.742),(ix-.035,4.736)],y-.04,'white','Head')
        sheet(side+' angry silver brow',mirror([(.075,4.74),(.59,4.938),(.62,4.866),(.13,4.68)]),y-.057,'silver','Head')
        line(side+' under eye crease',[(s*.16,-.62,4.52),(s*.41,-.616,4.49),(s*.58,-.60,4.52)],.014,'skin_shadow','Head')
        line(side+' brow tension',[(s*.055,-.623,4.79),(s*.085,-.617,4.88)],.012,'skin_shadow','Head')
    mesh('Angular nose',[(-.075,-.594,4.65),(.075,-.594,4.65),(0,-.739,4.44),(-.06,-.62,4.43),(.06,-.62,4.43)],[(0,1,2),(0,2,3),(1,4,2),(2,4,3)],'skin_light','Head')
    line('Stern mouth',[(-.16,-.61,4.315),(-.065,-.629,4.331),(.07,-.629,4.333),(.155,-.607,4.315)],.016,'ink','Head')
    line('Lower lip',[(-.08,-.62,4.254),(0,-.63,4.249),(.075,-.62,4.255)],.012,'skin_shadow','Head')

    rng=random.Random(36)
    # Short non-gory abrasions sit on exposed planes.
    for name,cx,cy,cz,part in [('Cheek R',-.48,-.621,4.40,'Head'),('Cheek L',.52,-.615,4.41,'Head'),('Pectoral L',.46,-.716,3.56,'Torso'),('Pectoral R',-.31,-.718,3.74,'Torso'),('Arm R',-1.55,-.69,3.70,'Right Arm'),('Arm L',1.55,-.677,3.10,'Left Arm'),('Fist L',1.55,-.53,2.18,'Left Arm')]:
        for i in range(3):
            x=cx+(i-1)*.041;z=cz+(i-1)*.008;length=.11+rng.random()*.075
            line(name+' scratch'+str(i),[(x-.03,cy,z+length/2),(x+.025,cy-.005,z-length/2)],.009,'scar',part)
    return objects,mats
