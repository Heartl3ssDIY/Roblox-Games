from assetlib import *
from math import sin, cos, pi, radians, sqrt


def puff(a, name, loc, scale, color, detail=False):
    return a.sphere(name, loc, scale, color, segments=16 if detail else 24,
                    rings=10 if detail else 14)


def eye(a, name, x, y, z, size=.19, iris="navy", white=True):
    puff(a, name + "_Socket", (x, y, z), (size*1.07, .043, size*1.24), "navy", True)
    if white:
        puff(a, name + "_Sclera", (x, y-.018, z), (size*.94, .036, size*1.11), "cream", True)
        puff(a, name + "_Iris", (x, y-.050, z-.013), (size*.69, .022, size*.95), iris, True)
        puff(a, name + "_Pupil", (x, y-.066, z-.015), (size*.43, .014, size*.72), "navy", True)
    else:
        puff(a, name + "_Iris", (x, y-.024, z), (size*.89, .024, size*1.13), "navy", True)
        if iris != "navy":
            puff(a, name + "_IrisTint", (x, y-.047, z-size*.63), (size*.59,.009,size*.25), iris, True)
    puff(a, name + "_Highlight", (x-size*.24, y-.086 if white else y-.065, z+size*.44),
         (size*.24, .010, size*.30), "white", True)
    puff(a, name + "_Glint", (x+size*.27, y-.083 if white else y-.064, z-size*.32),
         (size*.10, .009, size*.12), "white", True)


def eyes(a, x, y, z, size=.19, iris="navy", white=True):
    eye(a, "Eye_L", -x, y, z, size, iris, white)
    eye(a, "Eye_R", x, y, z, size, iris, white)


def smile(a, y, z, width=.23, depth=.1, color="navy"):
    points = [(width*(-1+2*i/12), y, z-depth*sin(pi*i/12)) for i in range(13)]
    a.tube("Smile", points, .022, color, sides=8)


def mouth(a, y, z, width=.2, height=.12, teeth=0):
    points=[(-width,z+height*.47),(-width*.67,z+height*.10),(0,z+height*.025),
            (width*.67,z+height*.10),(width,z+height*.47),(width*.87,z-height*.46),
            (width*.51,z-height*.88),(0,z-height),(-width*.51,z-height*.88),(-width*.87,z-height*.46)]
    a.prism("Mouth_Interior",points,.075,"navy",y=y,bevel=.022)
    puff(a, "Tongue", (0,y-.04,z-height*.61), (width*.51,.019,height*.34), "pink", True)
    for i in range(teeth):
        x = (i-(teeth-1)/2)*width*.57
        if teeth<4:
            a.prism("Tooth_%02d"%i,[(x-width*.22,z+height*.16),(x+width*.22,z+height*.16),
                    (x+width*.13,z-height*.26),(x,z-height*.39),(x-width*.13,z-height*.26)],
                    .06,"cream",y=y-.040,bevel=.022)
        else:
            a.box("Tooth_%02d" % i, (x,y-.044,z-height*.05),
                  (width*.43,.045,height*.49), "cream", bevel=.025)


def cheeks(a, x, y, z, size=.09):
    for s in [-1,1]:
        puff(a, "Cheek_L" if s<0 else "Cheek_R", (s*x,y,z), (size,.025,size*.67), "pink", True)


def foot(a, name, loc, color, size=(.23,.3,.16), toes=False):
    puff(a, name, loc, size, color, True)
    if toes:
        for k in [-1,1]:
            x,y,z = loc
            a.tube(name+"_ToeSeam"+str(k), [(x+k*size[0]*.3,y-size[1]*.78,z-.025),
                   (x+k*size[0]*.3,y-size[1]*.84,z+.065)], .012, "tan", sides=6)


def leaf(a, name, x, y, z, w, h, color, lean=0):
    pts = [(x,z),(x-w*.43,z+h*.24),(x-w*.52+lean*.3,z+h*.64),
           (x+lean,z+h),(x+w*.52+lean*.6,z+h*.64),(x+w*.40,z+h*.20)]
    a.prism(name, pts, .19, color, y=y, bevel=.055)


def crescent(a, name, x, y, z, radius, color, mirror=False):
    # Outer arc and a displaced inner arc form one solid crescent silhouette.
    outer = [(x+radius*cos(radians(65+230*i/16)),z+radius*sin(radians(65+230*i/16))) for i in range(17)]
    inner = [(x+radius*.39+radius*.79*cos(radians(263-166*i/12)),
              z+radius*.79*sin(radians(263-166*i/12))) for i in range(13)]
    points=outer+inner
    if mirror:
        points=[(2*x-px,pz) for px,pz in points]
    a.prism(name, points, .065, color, y=y, bevel=.018)


def four_feet(a, x, yfront, yback, z, color, size=(.21,.28,.17), toes=False, legs=False, legcolor=None):
    for s in [-1,1]:
        foot(a, "ForePaw_"+str(s),(s*x,yfront,z),color,size,toes)
        foot(a, "HindPaw_"+str(s),(s*x,yback,z),color,size,toes)
        if legs:
            for part,y in [("ForeLeg",yfront),("HindLeg",yback)]:
                puff(a,part+"_"+str(s),(s*x*.92,.18+(y-.18)*.83,z+.22),
                     (size[0]*.82,size[1]*.78,.24),legcolor or color,True)


def surface_band(a,name,center,radii,longitude,width,color):
    verts=[]; faces=[]; rows=21;cols=5
    for shell in [1.020,.992]:
        for row in range(rows):
            lat=radians(-67+134*row/(rows-1))
            for column in range(cols):
                side=-1+2*column/(cols-1)
                lon=radians(longitude+side*width/2)
                verts.append((center[0]+radii[0]*cos(lat)*cos(lon)*shell,
                              center[1]+radii[1]*cos(lat)*sin(lon)*shell,
                              center[2]+radii[2]*sin(lat)*shell))
    n=rows*cols
    for row in range(rows-1):
        for column in range(cols-1):
            q=row*cols+column
            faces.extend([(q,q+1,q+cols+1,q+cols),(q+n+cols,q+n+cols+1,q+n+1,q+n)])
    boundary=list(range(cols))+[j*cols+cols-1 for j in range(1,rows)]+list(range(n-2,n-cols-1,-1))+[j*cols for j in range(rows-2,0,-1)]
    for i,q in enumerate(boundary):
        v=boundary[(i+1)%len(boundary)]
        faces.append((q,v,v+n,q+n))
    return a.mesh(name,verts,faces,color,smooth=True)


def pocket_bulldog(a):
    from mathutils.bvhtree import BVHTree
    def unite(parts,name,voxel=.03):
        retained=[o for o in a.objects if o not in parts]
        bpy.ops.object.select_all(action="DESELECT")
        for ob in parts:ob.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        bpy.ops.object.convert(target="MESH")
        bpy.ops.object.join()
        result=bpy.context.object
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        result.name=a.spec["id"]+"_"+name;result["Part"]=name
        a.objects=retained+[result]
        remesh=result.modifiers.new("Unified sculpt topology","REMESH")
        remesh.mode="VOXEL";remesh.voxel_size=voxel;remesh.use_smooth_shade=True
        bpy.ops.object.modifier_apply(modifier=remesh.name)
        smooth=result.modifiers.new("Sculpt surface relaxation","SMOOTH")
        smooth.factor=.52;smooth.iterations=5
        bpy.ops.object.modifier_apply(modifier=smooth.name)
        dec=result.modifiers.new("Even game topology","DECIMATE")
        dec.ratio=.66
        bpy.ops.object.modifier_apply(modifier=dec.name)
        for face in result.data.polygons:face.use_smooth=True
        return result
    skull=a.box("HeadVolume",(0,-.20,1.48),(1.36,1.04,.99),"cream",bevel=.34)
    skull.modifiers[0].segments=5
    parts=[skull,puff(a,"JawVolume",(0,-.60,1.045),(.49,.35,.23),"cream"),
           puff(a,"ChinVolume",(0,-.64,.99),(.36,.28,.17),"cream")]
    for side in [-1,1]:
        parts.append(puff(a,"CheekVolume_"+str(side),(side*.46,-.50,1.205),(.285,.31,.33),"cream"))
        parts.append(puff(a,"MuzzleVolume_"+str(side),(side*.205,-.72,1.305),(.30,.28,.215),"cream"))
    head=unite(parts,"UnifiedSkull_Cheeks_Muzzle_Jowls",.028)
    grin=[(-.24,1.17),(-.11,1.125),(0,1.12),(.11,1.125),(.24,1.17),
          (.21,1.00),(.12,.925),(0,.90),(-.12,.925),(-.21,1.00)]
    cutter=a.prism("MouthCavityCutter",grin,.56,"cream",y=-.80,bevel=.035)
    bpy.context.view_layer.objects.active=head
    boolean=head.modifiers.new("Carved smiling mouth","BOOLEAN")
    boolean.operation="DIFFERENCE";boolean.solver="EXACT";boolean.object=cutter
    bpy.ops.object.modifier_apply(modifier=boolean.name)
    a.objects.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
    edge=head.modifiers.new("Soft lip edges","BEVEL");edge.width=.011;edge.segments=2
    bpy.ops.object.modifier_apply(modifier=edge.name)
    bm=bmesh.new();bm.from_mesh(head.data)
    for point,normal in [((0,0,1.39),(0,0,1)),((0,-.82,0),(0,1,0))]:
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                              dist=.00001,plane_co=Vector(point),plane_no=Vector(normal),
                              clear_inner=False,clear_outer=False)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(head.data);bm.free();head.data.update()
    head.data.materials.append(material("tan"))
    tan_index=len(head.data.materials)-1
    for face in head.data.polygons:
        z=face.center.z;x=face.center.x;y=face.center.y
        face.material_index=tan_index if z>1.39 and y>-.82 else 0
        face.use_smooth=True
    bpy.context.view_layer.update()
    bvh=BVHTree.FromObject(head,bpy.context.evaluated_depsgraph_get())
    def skin(x,z):
        hit=bvh.ray_cast(Vector((x,-3,z)),Vector((0,1,0)),6)[0]
        return hit.y if hit is not None else -.70
    # One connected surface strip flows over the crown and down the forehead.
    sections=[("top",y,.109) for y in [.06,-.02,-.10,-.18,-.26,-.34,-.40,-.46]]
    for z in [1.945,1.93,1.91,1.88,1.85,1.82,1.79,1.76,1.73,1.70,1.67,1.64,
              1.61,1.58,1.55,1.52,1.49,1.46,1.43,1.40,1.375,1.355]:
        width=.11+.012*sin((1.94-z)*5)
        if z<1.50:width=.126+(1.50-z)*.27
        sections.append(("front",z,width))
    vv=[];ff=[];inside=[];cols=13
    for mode,value,width in sections:
        for i in range(cols):
            x=width*(-1+2*i/(cols-1))
            if mode=="top":
                y=value
                hit=bvh.ray_cast(Vector((x,y,3)),Vector((0,0,-1)),4)[0]
                z=hit.z if hit is not None else 1.94
                vv.append((x,y,z+.012));inside.append((x,y,z-.018))
            else:
                z=value;y=skin(x,z)
                vv.append((x,y-.012,z));inside.append((x,y+.018,z))
    rows=len(sections);nn=len(vv);vv.extend(inside)
    for j in range(rows-1):
        for i in range(cols-1):
            q=j*cols+i
            ff.extend([(q,q+1,q+cols+1,q+cols),(q+nn+cols,q+nn+cols+1,q+nn+1,q+nn)])
    boundary=list(range(cols))+[j*cols+cols-1 for j in range(1,rows)]+list(range(nn-2,nn-cols-1,-1))+[j*cols for j in range(rows-2,0,-1)]
    for i,q in enumerate(boundary):
        r=boundary[(i+1)%len(boundary)];ff.append((q,r,r+nn,q+nn))
    a.mesh("ContinuousCreamBlaze_CrownToForehead",vv,ff,"cream",smooth=True)
    bodyparts=[puff(a,"BodyVolume",(0,.21,.69),(.58,.74,.48),"tan"),
               puff(a,"ShoulderVolume",(0,-.23,.72),(.48,.36,.47),"tan")]
    for side in [-1,1]:bodyparts.append(puff(a,"HaunchVolume_"+str(side),(side*.35,.60,.46),(.29,.35,.31),"tan"))
    body=unite(bodyparts,"SculptedTorsoAndHaunches",.037)
    # The breast is a broad inset, fitted into the shoulder volume.
    puff(a,"CreamBreast",(0,-.462,.64),(.38,.095,.36),"cream")
    outline=[(-.15,.17),(-.22,.10),(-.235,-.08),(-.20,-.20),(-.145,-.255),(-.087,-.255),
             (-.062,-.215),(-.038,-.268),(.038,-.268),(.062,-.215),(.087,-.255),(.145,-.255),
             (.20,-.20),(.235,-.08),(.22,.10),(.15,.17)]
    for side in [-1,1]:
        for label,cy in [("Fore",-.37),("Hind",.61)]:
            vv=[];ff=[];indices=[];nn=len(outline)
            for ring,z in enumerate([.035,.09,.185,.255,.34,.50,.70]):
                for i,(x,y) in enumerate(outline):
                    if ring<4:
                        scale=[.82,1.0,.98,.80][ring]
                        xx=x*scale;yy=y*scale
                    else:
                        # Ankle rings are circular: toe clefts end at the paw, not up the leg.
                        from math import atan2
                        t=atan2(y,x)
                        xx=.18*cos(t);yy=.205*sin(t)+.02
                        if ring==6:xx*=1.18;yy*=1.10
                    inward=.085*max(0,(ring-3)/3)
                    shift_y=(.20 if label=="Fore" else -.105)*max(0,(ring-3)/3)
                    vv.append((side*(.40-inward)+xx,cy+yy+shift_y,z+(.10 if ring==6 else 0)))
            for ring in range(6):
                for i in range(nn):
                    ff.append((ring*nn+i,ring*nn+(i+1)%nn,(ring+1)*nn+(i+1)%nn,(ring+1)*nn+i))
                    indices.append(0 if ring<4 else 1)
            ff.extend([tuple(range(nn-1,-1,-1)),tuple(6*nn+i for i in range(nn))]);indices.extend([0,1])
            obj=a.mesh(label+"Paw_AnkleAndToeLoops_"+str(side),vv,ff,"cream",smooth=True)
            obj.data.materials.append(material("tan"))
            for poly,index in zip(obj.data.polygons,indices):poly.material_index=index
            sub=obj.modifiers.new("Rounded paw supporting loops","SUBSURF");sub.levels=1;sub.render_levels=1
    a.tube("CurledTail",[(0,.81,.68),(.03,1.0,.77),(.15,1.10,.89),(.28,1.05,.96),(.31,.94,.89),(.24,.93,.85)],
           [.14,.13,.12,.10,.07,.035],"tan",sides=14)
    # A thick ribbon bends over the skull, rolls forward and droops at its rounded tip.
    for side in [-1,1]:
        stations=[(.46,-.11,1.80,.16),(.60,-.14,1.985,.19),(.78,-.26,1.94,.205),
                  (.87,-.40,1.79,.205),(.855,-.515,1.635,.165),(.795,-.55,1.54,.075),(.775,-.545,1.535,.018)]
        vv=[];ff=[];indices=[];nn=16
        for x,y,z,w in stations:
            for i in range(nn):
                t=2*pi*i/nn
                vv.append((side*(x+w*cos(t)),y+.07*sin(t),z+.035*cos(t)))
        for ring in range(len(stations)-1):
            for i in range(nn):
                ff.append((ring*nn+i,ring*nn+(i+1)%nn,(ring+1)*nn+(i+1)%nn,(ring+1)*nn+i))
                indices.append(1 if ring>2 and sin(2*pi*(i+.5)/nn)<-.7 else 0)
        ff.extend([tuple(range(nn-1,-1,-1)),tuple((len(stations)-1)*nn+i for i in range(nn))]);indices.extend([0,0])
        ear=a.mesh("FoldedEar_SweptThicknessLoops_"+str(side),vv,ff,"tan",smooth=True)
        ear.data.materials.append(material("brown"))
        for poly,index in zip(ear.data.polygons,indices):poly.material_index=index
        # True inset trim across the curled flap edge.
        a.tube("EarFold_"+str(side),[(side*.78,-.34,1.905),(side*.89,-.465,1.755),(side*.83,-.58,1.60)],.016,"brown",sides=8)
    for side in [-1,1]:
        ex=side*.31;ez=1.59;vv=[];ff=[];indices=[];nn=48
        cutter=puff(a,"OrbitCutter_"+str(side),(ex,-.715,ez),(.165,.19,.211),"cream")
        bpy.context.view_layer.objects.active=head
        cut=head.modifiers.new("Inset eye socket "+str(side),"BOOLEAN");cut.operation="DIFFERENCE";cut.solver="EXACT";cut.object=cutter
        bpy.ops.object.modifier_apply(modifier=cut.name)
        a.objects.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
        rings=[.0,.49,.72,.94,1.0]
        for r in rings:
            for i in range(nn):
                t=2*pi*i/nn
                x=ex+.177*r*cos(t);z=ez+.222*r*sin(t)
                vv.append((x,-.748-.052*sqrt(max(0,1-r*r)),z))
        for ring in range(4):
            for i in range(nn):
                ff.append((ring*nn+i,ring*nn+(i+1)%nn,(ring+1)*nn+(i+1)%nn,(ring+1)*nn+i))
                indices.append([0,1,2,0][ring])
        back=len(vv)
        for x,y,z in vv[4*nn:5*nn]:vv.append((x,y+.10,z))
        for i in range(nn):ff.append((4*nn+i,4*nn+(i+1)%nn,back+(i+1)%nn,back+i));indices.append(0)
        ff.append(tuple(back+i for i in reversed(range(nn))));indices.append(0)
        obj=a.mesh("Eye_SingleInsetSurface_"+str(side),vv,ff,"navy",smooth=True)
        obj.data.materials.append(material("brown"));obj.data.materials.append(material("cream"))
        for poly,index in zip(obj.data.polygons,indices):poly.material_index=index
        for name,dx,dz,scale in [("Catchlight",-.045,.078,(.044,.006,.052)),("Glint",.049,-.067,(.018,.005,.022))]:
            x=ex+dx;z=ez+dz
            rr=(dx/.177)**2+(dz/.222)**2
            puff(a,name+"_"+str(side),(x,-.748-.052*sqrt(max(0,1-rr))-.009,z),scale,"white",True)
        brow=[]
        for i in range(9):
            x=ex-.145+.29*i/8;z=1.812+.035*sin(pi*i/8)
            brow.append((x,skin(x,z)-.022,z))
        a.tube("SoftBrow_"+str(side),brow,.038,"brown",sides=10)
    nose_outline=[(-.17,1.38),(-.09,1.408),(.09,1.408),(.17,1.38),(.135,1.292),(0,1.226),(-.135,1.292)]
    a.prism("RoundedNose",nose_outline,.13,"navy",y=-.967,bevel=.042)
    for side in [-1,1]:
        puff(a,"Nostril_"+str(side),(side*.077,-1.035,1.346),(.034,.010,.022),"black",True)
    puff(a,"NoseSheen",(-.045,-1.036,1.381),(.06,.006,.009),"silver",True)
    a.prism("MouthInterior",grin,.10,"brown",y=-.66,bevel=.025)
    puff(a,"Tongue",(0,-.78,.990),(.136,.112,.084),"pink",True)
    a.tube("TongueCrease",[(0,-.887,1.035),(0,-.895,1.008)],.008,"#D77586",sides=6)
    # Shallow folds emphasize the integrated cream muzzle rather than adding loose cheek balls.
    for side in [-1,1]:
        fold=[]
        for x,z in [(side*.05,1.24),(side*.17,1.18),(side*.29,1.20),(side*.39,1.25)]:
            fold.append((x,skin(x,z)-.003,z))
        a.tube("MuzzleFold_"+str(side),fold,.008,"#C8A881",sides=6)
    collar=a.torus("WideCollar",(0,-.12,.942),.483,.088,"navy",segments=40,sides=10);collar.scale.y=1.12
    for side in [-1,1]:
        a.box("CollarInset_"+str(side),(side*.275,-.636,.938),(.23,.028,.105),"#283B66",bevel=.025,rotation=(0,0,-side*.25))
    a.torus("TagLoop",(0,-.690,.871),.050,.022,"gold",rotation=(pi/2,0,0),segments=20,sides=8)
    a.cone("GoldTagRim",(0,-.721,.750),.126,.126,.05,"gold",rotation=(pi/2,0,0),vertices=32)
    a.cone("GoldTagInset",(0,-.753,.750),.096,.096,.018,"yellow",rotation=(pi/2,0,0),vertices=32)


def toast_capybara(a):
    a.box("ToastBody",(0,.2,.82),(1.35,1.67,1.18),"tan",bevel=.43)
    a.box("CrustBand",(0,.29,1.16),(1.39,1.43,.6),"brown",bevel=.26)
    a.box("GoldenToastTop",(0,.23,1.35),(1.25,1.3,.30),"tan",bevel=.20)
    puff(a,"Head",(0,-.64,.90),(.64,.46,.55),"tan")
    puff(a,"CreamMuzzle",(0,-1.03,.73),(.37,.10,.29),"cream")
    four_feet(a,.47,-.47,.73,.17,"brown",(.21,.23,.17),legs=True,legcolor="tan")
    for s in [-1,1]:
        puff(a,"Ear_"+str(s),(s*.43,-.43,1.39),(.15,.11,.20),"brown",True)
        puff(a,"EarInset_"+str(s),(s*.43,-.534,1.40),(.082,.026,.12),"pink",True)
        a.tube("SleepyEye_"+str(s),[(s*.38-.11,-1.026,1.022),(s*.38,-1.052,.997),
                 (s*.38+.105,-1.025,1.015)],.034,"navy",sides=8)
    puff(a,"Nose",(0,-1.142,.84),(.12,.04,.064),"brown",True)
    a.tube("MuzzleLine",[(0,-1.155,.83),(0,-1.157,.69)],.014,"brown",sides=6)
    smile(a,-1.139,.67,.115,.047,"brown")
    cheeks(a,.38,-1.00,.86,.075)
    a.box("ButterPat",(.0,.22,1.594),(.60,.54,.23),"yellow",bevel=.075,rotation=(0,0,radians(-10)))
    a.box("ButterHighlight",(-.03,.20,1.718),(.46,.41,.02),"cream",bevel=.05,rotation=(0,0,radians(-10)))


def pancake_penguin(a):
    puff(a,"Body",(0,.06,.80),(.57,.46,.65),"navy")
    puff(a,"Belly",(0,-.387,.72),(.40,.09,.47),"cream")
    puff(a,"Head",(0,-.02,1.45),(.68,.51,.56),"navy")
    for s in [-1,1]:
        puff(a,"FacePatch_"+str(s),(s*.245,-.477,1.47),(.32,.095,.36),"cream",True)
        wing=puff(a,"Flipper_"+str(s),(s*.57,.02,.86),(.16,.24,.39),"navy",True)
        wing.rotation_euler[1]=s*radians(-36)
        foot(a,"WebbedFoot_"+str(s),(s*.31,-.15,.14),"orange",(.26,.32,.13))
        for k in [-1,0,1]:
            puff(a,"Toe_%s_%s"%(s,k),(s*.31+k*.105,-.37,.14),(.078,.12,.09),"orange",True)
    eyes(a,.25,-.548,1.49,.16,"navy",False)
    cheeks(a,.41,-.528,1.25,.09)
    puff(a,"BeakOutline",(0,-.597,1.285),(.175,.14,.13),"brown",True)
    puff(a,"Beak",(0,-.646,1.309),(.15,.13,.095),"orange",True)
    a.tube("BeakSmile",[(-.11,-.751,1.28),(0,-.78,1.23),(.11,-.751,1.28)],.016,"navy",sides=6)
    for i in range(2):
        a.lathe("Pancake_%s"%i,[(0,0),(.48,0),(.56,.055),(.565,.12),(.5,.17),(0,.17)],"tan",loc=(0,0,1.91+i*.19),segments=32)
        a.torus("PancakeCreamEdge_%s"%i,(0,0,2.004+i*.19),.53,.038,"cream",segments=32,sides=6)
    a.lathe("SyrupTop",[(0,0),(.43,0),(.52,.018),(.45,.054),(0,.06)],"brown",loc=(0,0,2.248),segments=32)
    for i,(x,y,l) in enumerate([(-.27,-.44,.17),(.30,-.4,.26),(.45,.11,.12)]):
        a.tube("SyrupDrip_%s"%i,[(x,y,2.28),(x,y-.025,2.19),(x,y-.02,2.28-l)],.07,"brown",sides=8)
    a.box("ButterCube",(0,-.02,2.39),(.29,.28,.17),"yellow",bevel=.04,rotation=(0,0,radians(12)))


def jelly_axolotl(a):
    puff(a,"Body",(0,.21,.51),(.53,.64,.39),"cyan")
    puff(a,"CreamBelly",(0,-.22,.41),(.38,.17,.25),"cream",True)
    four_feet(a,.43,-.25,.63,.16,"cyan",(.22,.29,.16),legs=True)
    a.tube("TailCore",[(0,.69,.48),(.21,.91,.57),(.51,1.11,.77),(.65,1.08,1.06)],.18,"cyan",sides=12)
    a.prism("TailFin",[(.04,.5),(.52,.59),(.86,.97),(.8,1.28),(.61,1.24),(.48,.97),(.16,.77)],.23,"cyan",y=.91,bevel=.09)
    a.prism("TailFinCreamInset",[(.25,.61),(.58,.73),(.74,.99),(.72,1.16),(.60,1.01),(.47,.87)],.025,"cream",y=.777,bevel=.04)
    puff(a,"WideHead",(0,-.30,1.02),(.75,.49,.50),"cyan")
    for s in [-1,1]:
        for i,(z,dx,dz) in enumerate([(1.24,.17,.3),(1.04,.31,.1),(.86,.28,-.03)]):
            start=(s*.61,-.20,z)
            end=(s*(.77+dx),-.15,z+dz)
            a.tube("GillStem_%s_%s"%(s,i),[start,end],.072,"magenta",sides=8)
            branch=puff(a,"GillLobe_%s_%s"%(s,i),end,(.135,.14,.215 if i==0 else .125),"pink",True)
            branch.rotation_euler[1]=s*radians(-26 if i==0 else -65)
    eyes(a,.31,-.749,1.11,.146,"navy",False)
    smile(a,-.802,.94,.21,.07)
    cheeks(a,.50,-.659,.91,.10)
    a.tube("LowerSmileRim",[(-.48,-.666,.77),(0,-.721,.68),(.48,-.666,.77)],.045,"cream",sides=8)


def rocket_snail(a):
    puff(a,"SnailFoot",(0,.26,.21),(.67,.85,.21),"mint")
    puff(a,"RaisedBody",(0,-.33,.69),(.52,.44,.63),"mint")
    for z,w in [(.39,.38),(.65,.41),(.88,.37)]:
        puff(a,"BellySegment_"+str(z),(0,-.713,z),(w,.095,.18),"cream",True)
    puff(a,"Head",(0,-.41,1.10),(.50,.39,.35),"mint")
    for s in [-1,1]:
        a.tube("EyeStalk_"+str(s),[(s*.23,-.35,1.22),(s*.30,-.36,1.58),(s*.37,-.37,1.83)],.115,"mint",sides=12)
        puff(a,"EyeBulb_"+str(s),(s*.37,-.40,1.84),(.265,.22,.285),"mint",True)
        eye(a,"Eye_"+str(s),s*.37,-.611,1.85,.19,"navy")
        foot(a,"SideFin_"+str(s),(s*.48,-.21,.28),"mint",(.23,.32,.24))
    mouth(a,-.795,1.034,.18,.092)
    # Rocket shell leans backwards while staying solidly nested into the snail's back.
    shell=a.lathe("RocketShell",[(0,0),(.38,0),(.48,.14),(.49,1.10),(.40,1.25),(0,1.25)],"cream",loc=(0,.40,.53),segments=24)
    shell.rotation_euler[0]=radians(-15)
    a.torus("RocketLowerCollar",(0,.41,.63),.442,.095,"navy",rotation=(radians(-15),0,0),segments=24,sides=8)
    a.cone("RocketNose",(0,.79,1.98),.44,.045,.59,"orange",rotation=(radians(-15),0,0),vertices=24)
    a.torus("RocketUpperCollar",(0,.705,1.72),.433,.065,"navy",rotation=(radians(-15),0,0),segments=24,sides=8)
    # Portholes are mounted to both shell sides, not floating behind the head.
    for s in [-1,1]:
        a.cone("PortholeRim_"+str(s),(s*.49,.53,1.27),.244,.244,.066,"navy",rotation=(0,pi/2,0),vertices=12)
        a.cone("PortholeCream_"+str(s),(s*.532,.53,1.27),.208,.208,.048,"cream",rotation=(0,pi/2,0),vertices=12)
        puff(a,"PortholeGlass_"+str(s),(s*.567,.53,1.27),(.055,.154,.154),"blue",True)
        a.prism("RocketFin_"+str(s),[(s*.39,.91),(s*.70,.70),(s*.79,1.03),(s*.43,1.35)],.22,"blue",y=.56,bevel=.06)


def traffic_crab(a):
    puff(a,"Carapace",(0,.07,.64),(.68,.45,.38),"blue")
    puff(a,"CreamLowerShell",(0,-.32,.56),(.59,.105,.22),"cream",True)
    for s in [-1,1]:
        for i,y in enumerate([-.15,.27]):
            a.tube("Leg_%s_%s"%(s,i),[(s*.49,y,.58),(s*.76,y-.03,.43),(s*.84,y-.17,.16)],.095,"blue",sides=8)
            puff(a,"LegJoint_%s_%s"%(s,i),(s*.76,y-.03,.43),(.12,.12,.12),"cyan",True)
        a.tube("ClawArm_"+str(s),[(s*.54,.03,.70),(s*.79,-.11,.79),(s*.96,-.08,1.06)],.13,"blue",sides=10)
        puff(a,"ClawPalm_"+str(s),(s*1.04,-.09,1.17),(.285,.225,.34),"blue",True)
        a.prism("ClawOuterFinger_"+str(s),[(s*.97,1.2),(s*1.20,1.17),(s*1.27,1.45),
                  (s*1.13,1.70),(s*.98,1.72),(s*1.08,1.44)],.24,"cyan",y=-.10,bevel=.07)
        a.prism("ClawInnerFinger_"+str(s),[(s*.92,1.19),(s*.78,1.31),(s*.76,1.49),
                  (s*.89,1.56),(s*.96,1.43),(s*1.08,1.37)],.20,"cream",y=-.14,bevel=.055)
        puff(a,"EyeStalk_"+str(s),(s*.255,-.29,.96),(.155,.13,.25),"blue",True)
        eye(a,"Eye_"+str(s),s*.255,-.401,1.032,.192,"blue")
    smile(a,-.452,.65,.17,.055)
    a.box("ConeHatBase",(0,.04,1.13),(.82,.63,.12),"orange",bevel=.08)
    a.lathe("TrafficCone",[(0,0),(.36,0),(.32,.22),(.28,.32),(.225,.49),(.16,.70),(.105,.74),(0,.74)],"orange",loc=(0,.04,1.18),segments=24)
    a.lathe("ConeCreamStripe",[(.265,0),(.291,.03),(.252,.16),(.212,.18)],"cream",loc=(0,.04,1.50),segments=24)


def teapot_frog(a):
    a.lathe("TeapotBody",[(0,0),(.34,0),(.57,.10),(.69,.42),(.64,.76),(.49,.92),(0,.92)],"cream",loc=(0,.07,.22),segments=32)
    a.torus("TeapotTopRim",(0,.07,1.075),.47,.065,"green",segments=32,sides=8)
    a.torus("TeapotBottomRim",(0,.07,.37),.49,.035,"tan",segments=32,sides=6)
    # Left spout has a physical dark inset opening and a chunky green lip.
    a.tube("Spout",[(-.48,.06,.60),(-.77,.04,.77),(-.9,.03,1.09)],.19,"cream",sides=12)
    a.torus("SpoutGreenLip",(-.90,.03,1.10),.152,.046,"green",segments=24,sides=8)
    a.cone("SpoutOpening",(-.90,.03,1.103),.13,.13,.025,"navy",vertices=24)
    a.tube("Handle",[(.53,.13,.90),(.87,.13,1.02),(1.05,.13,.84),(1.00,.13,.56),(.73,.13,.40),(.57,.13,.43)],.094,"green",sides=10)
    four_feet(a,.46,-.32,.39,.16,"lime",(.20,.25,.15),legs=True)
    puff(a,"FrogHead",(0,.01,1.24),(.57,.43,.27),"lime")
    for s in [-1,1]:
        puff(a,"EyeBump_"+str(s),(s*.34,-.14,1.49),(.238,.20,.248),"lime",True)
        eye(a,"Eye_"+str(s),s*.34,-.324,1.50,.182,"navy")
        puff(a,"Nostril_"+str(s),(s*.13,-.432,1.279),(.027,.019,.027),"green",True)
    smile(a,-.433,1.20,.23,.059,"green")
    cheeks(a,.40,-.327,1.21,.095)
    # Broad leaf medallions form the cream pot's illustrated green pattern.
    for i,x in enumerate([-.43,-.22,0,.22,.43]):
        y=-.561+abs(x)*.20
        leaf(a,"PotLeaf_%s"%i,x,y,.69,.095,.17,"green",lean=.05 if i%2 else -.05)


def skater_shark(a):
    a.box("SkateDeckDarkEdge",(0,.04,.26),(1.42,.83,.14),"navy",bevel=.14)
    a.box("SkateDeck",(0,.02,.34),(1.47,.85,.11),"orange",bevel=.16)
    a.box("DeckGrip",(0,.02,.403),(1.02,.48,.018),"cream",bevel=.13)
    for s in [-1,1]:
        a.tube("TruckAxle_"+str(s),[(s*.46,-.40,.16),(s*.46,.40,.16)],.055,"silver",sides=8)
        for y in [-.43,.43]:
            a.cone("Wheel_%s_%s"%(s,y),(s*.46,y,.17),.165,.165,.14,"navy",rotation=(pi/2,0,0),vertices=20)
            a.cone("WheelHub_%s_%s"%(s,y),(s*.46,y+(.075 if y>0 else -.075),.17),.084,.084,.025,"gold",rotation=(pi/2,0,0),vertices=16)
    puff(a,"SharkBody",(0,.08,1.0),(.45,.40,.61),"cyan")
    puff(a,"CreamBelly",(0,-.303,.91),(.34,.07,.41),"cream",True)
    puff(a,"Head",(0,-.03,1.61),(.60,.49,.44),"cyan")
    puff(a,"JawPatch",(0,-.405,1.45),(.51,.12,.26),"cream",True)
    mouth(a,-.52,1.456,.335,.185,3)
    eyes(a,.33,-.437,1.775,.165,"blue")
    for s in [-1,1]:
        a.prism("SideFin_"+str(s),[(s*.35,1.11),(s*.68,.91),(s*.67,.78),(s*.41,.88)],.21,"cyan",y=.01,bevel=.075)
        foot(a,"Foot_"+str(s),(s*.28,-.05,.51),"cyan",(.24,.28,.14))
        puff(a,"ToePatch_"+str(s),(s*.28,-.25,.523),(.16,.08,.065),"cream",True)
        for k in range(3):
            x=s*(.43+k*.045)
            a.tube("Gill_%s_%s"%(s,k),[(x,-.277,1.51),(x+s*.01,-.29,1.62)],.015,"blue",sides=6)
        puff(a,"Nostril_"+str(s),(s*.15,-.512,1.69),(.025,.018,.02),"blue",True)
    a.prism("DorsalFin",[(-.16,1.70),(-.38,2.19),(-.26,2.26),(.15,1.95),(.23,1.71)],.22,"cyan",y=.23,bevel=.065)
    a.tube("TailBase",[(0,.35,.92),(.05,.58,1.02),(.08,.77,1.09)],.15,"cyan",sides=10)
    a.prism("TailFin",[(-.05,.95),(-.37,1.22),(-.31,1.39),(.04,1.23),(.34,1.42),(.36,1.19),(.16,.96)],.15,"cyan",y=.77,bevel=.06)


def disco_duck(a):
    puff(a,"Body",(0,.17,.75),(.63,.57,.60),"yellow")
    puff(a,"CreamBelly",(0,-.36,.70),(.44,.10,.35),"cream",True)
    puff(a,"Head",(0,-.11,1.45),(.53,.46,.51),"yellow")
    for s in [-1,1]:
        wing=puff(a,"Wing_"+str(s),(s*.56,.02,.84),(.21,.32,.35),"yellow",True)
        wing.rotation_euler[1]=s*radians(24)
        a.tube("WingFeatherLine_"+str(s),[(s*.69,-.11,.87),(s*.67,-.15,.75),(s*.57,-.17,.69)],.016,"orange",sides=6)
        foot(a,"WebbedFoot_"+str(s),(s*.33,-.07,.14),"orange",(.29,.31,.12))
        for k in [-1,0,1]:
            puff(a,"FootToe_%s_%s"%(s,k),(s*.33+k*.12,-.30,.12),(.105,.12,.08),"orange",True)
    eyes(a,.245,-.53,1.48,.147,"blue")
    puff(a,"BeakLower",(0,-.617,1.22),(.29,.27,.105),"orange",True)
    puff(a,"BeakMouth",(0,-.695,1.295),(.27,.17,.04),"brown",True)
    puff(a,"BeakUpper",(0,-.663,1.335),(.31,.25,.092),"orange",True)
    for s in [-1,1]:
        puff(a,"Nostril_"+str(s),(s*.08,-.836,1.384),(.022,.018,.015),"brown",True)
    a.tube("HeadphoneBand",[(-.53,.0,1.45),(-.50,.0,1.75),(-.3,.0,1.93),(0,.0,1.99),(.3,.0,1.93),(.5,.0,1.75),(.53,.0,1.45)],.087,"navy",sides=10)
    for s in [-1,1]:
        a.cone("EarCup_"+str(s),(s*.55,.0,1.47),.255,.255,.19,"navy",vertices=16,rotation=(0,pi/2,0))
        a.cone("EarCupInset_"+str(s),(s*.66,.0,1.47),.185,.185,.047,"cream",vertices=12,rotation=(0,pi/2,0))
        a.cone("EarCupCenter_"+str(s),(s*.698,.0,1.47),.125,.125,.025,"cyan",vertices=10,rotation=(0,pi/2,0))
    for x in [-.09,.08]:
        tuft=puff(a,"HeadTuft_"+str(x),(x,-.035,1.93),(.085,.10,.22),"yellow",True)
        tuft.rotation_euler[1]=radians(-30)
    # Large tiles make the attached disco backpack legible at game scale.
    puff(a,"DiscoBackpack",(-.40,.50,1.12),(.40,.38,.40),"silver",True)
    for row,z in enumerate([.87,1.09,1.29]):
        for col,t in enumerate([-.70,0,.70]):
            x=-.40-.34*cos(t); y=.50+.32*sin(t)
            tile=a.box("DiscoTile_%s_%s"%(row,col),(x,y,z+.06),(.035,.17,.16),"cyan" if (row+col)%2 else "lavender",bevel=.02)
            tile.rotation_euler[2]=-t


def cloud_sheep(a):
    puff(a,"WoolCore",(0,.20,.83),(.64,.58,.56),"#C8EBFA")
    for i,(x,y,z,s) in enumerate([(-.42,.10,.87,.39),(.42,.10,.87,.39),(-.30,.48,1.03,.36),
              (.30,.48,1.03,.36),(-.24,-.03,1.37,.37),(.25,-.03,1.38,.36)]):
        puff(a,"CloudLobe_%02d"%i,(x,y,z),(s,s*.9,s),"#BBE4FA",True)
    four_feet(a,.40,-.27,.60,.18,"navy",(.17,.23,.19),legs=True)
    puff(a,"Face",(0,-.36,.99),(.41,.25,.40),"cream")
    for s in [-1,1]:
        puff(a,"Ear_"+str(s),(s*.49,-.29,1.11),(.22,.12,.11),"cream",True)
        pts=[]
        for k in range(24):
            t=k/23*pi*1.72
            r=.23*(1-.55*k/23)
            pts.append((s*(.51+r*cos(t)), -.075-.024*k/23,1.29+r*sin(t)))
        a.tube("CurledHorn_"+str(s),pts,.11,"navy",sides=8)
    eyes(a,.19,-.596,1.04,.125,"blue",False)
    puff(a,"Nose",(0,-.630,.914),(.049,.025,.036),"navy",True)
    a.tube("Muzzle_L",[(0,-.636,.9),(-.03,-.634,.85),(-.09,-.618,.86)],.014,"navy",sides=6)
    a.tube("Muzzle_R",[(0,-.636,.9),(.03,-.634,.85),(.09,-.618,.86)],.014,"navy",sides=6)
    cheeks(a,.27,-.573,.894,.068)
    a.torus("Collar",(0,-.22,.70),.30,.045,"navy",segments=24,sides=6)
    crescent(a,"CrescentCharm",0,-.569,.57,.153,"gold")


def cactus_cat(a):
    puff(a,"Body",(0,.24,.67),(.52,.57,.53),"green")
    puff(a,"Head",(0,-.17,1.23),(.67,.45,.60),"green")
    four_feet(a,.38,-.23,.61,.17,"green",(.215,.27,.16),True,legs=True)
    for s in [-1,1]:
        a.prism("Ear_"+str(s),[(s*.24,1.57),(s*.67,2.01),(s*.77,1.49),(s*.58,1.41)],.29,"green",y=-.12,bevel=.065)
        a.prism("EarCream_"+str(s),[(s*.42,1.60),(s*.64,1.84),(s*.68,1.53)],.032,"cream",y=-.275,bevel=.037)
    for i,lon in enumerate([-125,-90,-55]):
        surface_band(a,"HeadRib_%s"%i,(0,-.17,1.23),(.67,.45,.60),lon,19,"#ADDD68")
        surface_band(a,"BodyRib_%s"%i,(0,.24,.67),(.52,.57,.53),lon,17,"#ADDD68")
    eyes(a,.26,-.607,1.28,.16,"brown",False)
    for s in [-1,1]:
        puff(a,"Muzzle_"+str(s),(s*.125,-.632,1.038),(.17,.073,.15),"cream",True)
        for k in range(2):
            a.tube("Whisker_%s_%s"%(s,k),[(s*.43,-.5,1.05-k*.1),(s*.62,-.47,1.075-k*.12)],.023,"teal",sides=6)
    puff(a,"Nose",(0,-.686,1.11),(.07,.025,.045),"pink",True)
    mouth(a,-.674,.945,.094,.07)
    a.tube("CurledTail",[(0,.66,.52),(.41,.86,.67),(.78,.85,.99),(.84,.77,1.31),(.75,.66,1.47)],.16,"green",sides=12)
    a.tube("TailRib",[(.42,.743,.72),(.72,.717,1.0),(.77,.64,1.28)],.038,"lime",sides=8)
    for i,(x,y,z) in enumerate([(-.62,-.06,1.45),(.60,-.02,.83),(.65,.76,.92),(.78,.68,1.27)]):
        puff(a,"BluntCactusNub_%s"%i,(x,y,z),(.07,.09,.07),"lime",True)
    for i in range(5):
        t=2*pi*i/5
        puff(a,"FlowerPetal_%s"%i,(.42+.12*sin(t),-.315,1.69+.12*cos(t)),(.095,.063,.095),"pink",True)
    puff(a,"FlowerCenter",(.42,-.385,1.69),(.074,.029,.073),"yellow",True)


def ufo_jelly(a):
    for i,x in enumerate([-.52,-.18,.18,.52]):
        a.tube("Tentacle_%s"%i,[(x*.68,.03,.73),(x,.02,.47),(x*1.26,-.02,.22),(x*1.19,-.09,.14)],.125,"lavender",sides=10)
        puff(a,"TentacleTip_%s"%i,(x*1.19,-.09,.14),(.14,.14,.14),"lavender",True)
    puff(a,"JellyBell",(0,.02,.99),(.66,.47,.38),"lavender")
    for i,x in enumerate([-.43,-.15,.15,.43]):
        puff(a,"BellScallop_%s"%i,(x,-.18,.80),(.22,.23,.16),"lavender",True)
    eyes(a,.245,-.433,1.035,.147,"navy",False)
    mouth(a,-.486,.898,.136,.085)
    cheeks(a,.43,-.382,.937,.09)
    a.lathe("SaucerNavySeam",[(0,0),(.79,0),(.89,.10),(.74,.25),(.47,.35),(0,.35)],"navy",loc=(0,0,1.16),segments=32)
    a.lathe("SaucerCap",[(0,0),(.83,0),(.86,.06),(.70,.19),(.46,.29),(0,.29)],"teal",loc=(0,0,1.275),segments=32)
    a.lathe("SaucerCreamBelt",[(.83,0),(.873,.02),(.861,.11),(.82,.12)],"cream",loc=(0,0,1.21),segments=32)
    a.torus("DomeCollar",(0,0,1.52),.40,.045,"teal",segments=32,sides=8)
    puff(a,"OpaqueIceDome",(0,0,1.54),(.40,.40,.35),"#ABEAFF")
    for i in range(8):
        t=2*pi*i/8
        puff(a,"SaucerRivet_%s"%i,(.626*cos(t),.626*sin(t),1.405),(.07,.07,.038),"cream",True)


def pumpkin_bunny(a):
    puff(a,"PumpkinCore",(0,.1,.71),(.58,.59,.54),"orange")
    for i in range(8):
        t=2*pi*i/8
        puff(a,"PumpkinLobe_%s"%i,(.34*cos(t),.10+.34*sin(t),.72),(.28,.28,.5),"orange" if i%2 else "#F7A21F",True)
    four_feet(a,.38,-.31,.53,.16,"cream",(.21,.25,.15),True,legs=True)
    puff(a,"FacePatch",(0,-.494,.75),(.43,.071,.40),"cream")
    for s in [-1,1]:
        leaf(a,"LeafEar_"+str(s),s*.23,.0,1.13,.44,.99,"green",lean=s*.24)
        leaf(a,"EarInset_"+str(s),s*.245,-.117,1.24,.28,.74,"lime",lean=s*.17)
        a.tube("EarVein_"+str(s),[(s*.25,-.231,1.25),(s*.31,-.231,1.57),(s*.43,-.231,1.98)],.023,"green",sides=6)
    a.cone("PumpkinStem",(0,.1,1.31),.13,.10,.31,"green",vertices=10)
    eyes(a,.23,-.573,.845,.157,"brown")
    cheeks(a,.33,-.554,.647,.082)
    puff(a,"Nose",(0,-.587,.72),(.065,.022,.04),"pink",True)
    mouth(a,-.589,.615,.075,.058)
    puff(a,"PurpleTailCore",(0,.76,.66),(.28,.27,.28),"purple",True)
    for i in range(7):
        t=2*pi*i/7
        puff(a,"TailPompom_%s"%i,(.2*cos(t),.78,.66+.2*sin(t)),(.15,.16,.15),"purple",True)


def hoodie_ghost(a):
    # Sculpted solid bell with a six-wave hem, not a floating translucent plane.
    verts=[]; faces=[]; seg=36
    rings=[(.49,.19),(.45,.43),(.43,.70),(.30,.92)]
    for k,(radius,z) in enumerate(rings):
        for i in range(seg):
            t=2*pi*i/seg
            rr=radius+(0.08*cos(6*t) if k==0 else 0)
            zz=z+(0.065*cos(6*t) if k==0 else 0)
            verts.append((rr*cos(t),rr*sin(t),zz))
    for k in range(len(rings)-1):
        for i in range(seg):
            j=(i+1)%seg
            faces.append((k*seg+i,k*seg+j,(k+1)*seg+j,(k+1)*seg+i))
    faces.append(tuple(range(seg-1,-1,-1)))
    faces.append(tuple((len(rings)-1)*seg+i for i in range(seg)))
    a.mesh("WavyGhostBody",verts,faces,"white",smooth=True)
    a.lathe("HoodieTorso",[(0,0),(.45,0),(.51,.07),(.47,.38),(.40,.55),(0,.55)],
            "purple",loc=(0,0,.34),segments=32)
    a.torus("HoodieHem",(0,0,.38),.47,.027,"navy",segments=32,sides=6)
    puff(a,"PurpleHood",(0,.01,1.24),(.66,.44,.70),"purple")
    for s in [-1,1]:
        a.prism("CatEarHood_"+str(s),[(s*.27,1.71),(s*.64,2.00),(s*.73,1.56),(s*.50,1.50)],.27,"purple",y=.04,bevel=.09)
        a.prism("CatEarInner_"+str(s),[(s*.40,1.74),(s*.61,1.86),(s*.66,1.63)],.025,"cream",y=-.116,bevel=.05)
    puff(a,"HoodNavyRim",(0,-.37,1.27),(.505,.111,.53),"navy")
    puff(a,"GhostFace",(0,-.441,1.28),(.444,.086,.466),"white")
    for s in [-1,1]:
        a.tube("HoodSeam_"+str(s),[(s*.47,-.304,.86),(s*.57,-.251,1.31),(s*.37,-.251,1.71),(0,-.27,1.89)],.031,"lavender",sides=6)
        puff(a,"HoodSleeve_"+str(s),(s*.56,-.03,.72),(.23,.28,.26),"purple",True)
        puff(a,"MittenHand_"+str(s),(s*.64,-.257,.75),(.17,.14,.19),"white",True)
        a.tube("DrawString_"+str(s),[(s*.27,-.397,.91),(s*.255,-.49,.65)],.03,"cream",sides=8)
        a.box("DrawstringTip_"+str(s),(s*.255,-.49,.64),(.085,.09,.11),"lime",bevel=.026)
    eyes(a,.21,-.527,1.34,.146,"navy",False)
    mouth(a,-.545,1.145,.112,.1)
    cheeks(a,.31,-.511,1.15,.07)
    a.box("GreenPocketBorder",(0,-.425,.50),(.73,.19,.38),"green",bevel=.11)
    a.box("GreenPocket",(0,-.535,.53),(.62,.05,.26),"lime",bevel=.08)
    a.tube("PocketTopSeam",[(-.25,-.577,.64),(0,-.585,.63),(.25,-.577,.64)],.014,"green",sides=6)


def marshmallow_dragon(a):
    puff(a,"Body",(0,.18,.70),(.54,.64,.52),"cream")
    puff(a,"Belly",(0,-.363,.62),(.38,.12,.39),"#E7CDA6",True)
    for z in [.43,.64,.84]:
        a.tube("BellySeam_"+str(z),[(-.28,-.437,z),(0,-.487,z-.04),(.28,-.437,z)],.014,"tan",sides=6)
    four_feet(a,.39,-.29,.62,.17,"cream",(.23,.28,.17),legs=True)
    for s in [-1,1]:
        for y in [-.47,.45]:
            for k in [-1,0,1]:
                puff(a,"PinkPaw_%s_%s_%s"%(s,y,k),(s*.39+k*.086,y,.156),(.068,.11,.09),"pink",True)
    puff(a,"Head",(0,-.32,1.41),(.63,.45,.55),"cream")
    puff(a,"Snout",(0,-.69,1.22),(.38,.23,.25),"cream")
    eyes(a,.29,-.70,1.47,.17,"brown")
    for s in [-1,1]:
        a.cone("GoldHorn_"+str(s),(s*.4,-.05,1.98),.14,.038,.36,"gold",vertices=16,rotation=(0,s*radians(18),0))
        a.prism("HeadFrill_"+str(s),[(s*.49,1.63),(s*.78,1.66),(s*.66,1.43),(s*.82,1.34),(s*.58,1.26)],.21,"cream",y=-.12,bevel=.05)
        a.prism("FrillPinkInset_"+str(s),[(s*.57,1.58),(s*.70,1.58),(s*.61,1.45),(s*.72,1.36),(s*.61,1.34)],.022,"pink",y=-.242,bevel=.02)
        a.prism("WingBorder_"+str(s),[(s*.40,.91),(s*.51,1.38),(s*.85,1.61),(s*1.16,1.44),
                  (s*1.26,1.12),(s*.99,1.16),(s*.86,.99),(s*.61,.91)],.19,"tan",y=.26,bevel=.05)
        a.prism("PinkWing_"+str(s),[(s*.47,.96),(s*.57,1.36),(s*.85,1.53),(s*1.10,1.40),
                  (s*1.18,1.20),(s*.98,1.24),(s*.85,1.08),(s*.62,.99)],.20,"pink",y=.231,bevel=.025)
        a.tube("WingRib_"+str(s),[(s*.52,.103,1.02),(s*.66,.103,1.37),(s*.86,.103,1.51)],.025,"cream",sides=6)
        puff(a,"Nostril_"+str(s),(s*.13,-.891,1.29),(.03,.02,.022),"brown",True)
    mouth(a,-.890,1.11,.20,.1)
    cheeks(a,.40,-.683,1.20,.09)
    a.tube("CurledTail",[(0,.66,.50),(.37,.86,.62),(.66,.80,.86),(.72,.63,1.09)],.17,"cream",sides=12)
    for i,(x,y,z,s) in enumerate([(-.18,-.65,1.83,.09),(.15,-.73,1.75,.065),(.45,.21,.86,.12),(.50,.68,.80,.09)]):
        puff(a,"ToastPatch_%s"%i,(x,y,z),(s,.03,s*.8),"tan",True)


def banana_gorilla(a):
    puff(a,"Body",(0,.10,.77),(.55,.40,.56),"brown")
    for s in [-1,1]:
        puff(a,"Pectoral_"+str(s),(s*.21,-.304,.91),(.24,.09,.21),"tan",True)
    puff(a,"BellyPatch",(0,-.32,.64),(.33,.09,.24),"tan",True)
    for s in [-1,1]:
        puff(a,"HugeUpperArm_"+str(s),(s*.63,.00,.86),(.34,.32,.37),"brown",True)
        fore=puff(a,"HugeForearm_"+str(s),(s*.76,-.17,.50),(.34,.33,.40),"brown",True)
        fore.rotation_euler[1]=s*radians(-13)
        foot(a,"KnucklePalm_"+str(s),(s*.76,-.23,.18),"tan",(.32,.31,.17))
        for k in [-1,0,1]:
            a.box("Knuckle_%s_%s"%(s,k),(s*.76+k*.16,-.46,.18),(.14,.15,.21),"tan",bevel=.052)
        puff(a,"Leg_"+str(s),(s*.30,.14,.30),(.24,.28,.25),"brown",True)
        foot(a,"Foot_"+str(s),(s*.30,-.01,.13),"tan",(.23,.28,.12),True)
    puff(a,"BananaHood",(0,.025,1.51),(.63,.46,.69),"yellow")
    a.cone("BananaStem",(.08,.06,2.18),.14,.12,.28,"yellow",vertices=10,rotation=(0,radians(13),0))
    a.cone("BrownStemTip",(.112,.06,2.30),.13,.12,.067,"brown",vertices=10,rotation=(0,radians(13),0))
    puff(a,"HoodOpeningSeam",(0,-.399,1.51),(.525,.072,.55),"navy")
    puff(a,"GorillaHead",(0,-.448,1.50),(.49,.087,.517),"brown")
    for s in [-1,1]:
        puff(a,"Ear_"+str(s),(s*.545,-.255,1.46),(.145,.092,.196),"tan",True)
        puff(a,"EarInset_"+str(s),(s*.552,-.339,1.46),(.076,.024,.11),"brown",True)
        a.prism("PeelFlap_"+str(s),[(s*.49,1.33),(s*.83,1.41),(s*1.02,1.27),(s*1.18,.92),
                 (s*1.12,.78),(s*.94,.95),(s*.77,1.09),(s*.55,1.10)],.19,"yellow",y=.10,bevel=.05)
        a.prism("PeelCream_"+str(s),[(s*.61,1.28),(s*.82,1.31),(s*.96,1.21),(s*1.10,.95),
                 (s*1.08,.90),(s*.91,1.04),(s*.74,1.16)],.027,"cream",y=-.011,bevel=.025)
    for s in [-1,1]:
        puff(a,"FaceEyePatch_"+str(s),(s*.22,-.527,1.60),(.225,.065,.27),"cream",True)
    eyes(a,.215,-.587,1.62,.142,"brown")
    puff(a,"Muzzle",(0,-.555,1.299),(.38,.145,.244),"cream")
    mouth(a,-.696,1.24,.257,.107,4)
    puff(a,"NoseBridge",(0,-.653,1.445),(.18,.074,.105),"tan",True)
    for s in [-1,1]:
        puff(a,"Nostril_"+str(s),(s*.068,-.718,1.441),(.035,.019,.037),"brown",True)


def gummy_rex(a):
    puff(a,"Body",(0,.13,.72),(.52,.47,.57),"lime")
    puff(a,"CreamBelly",(0,-.292,.69),(.36,.07,.40),"cream",True)
    for s in [-1,1]:
        puff(a,"Haunch_"+str(s),(s*.37,.16,.45),(.27,.30,.31),"lime",True)
        foot(a,"Foot_"+str(s),(s*.35,-.05,.17),"lime",(.28,.34,.17))
        for k in [-1,0,1]:
            puff(a,"ToeClaw_%s_%s"%(s,k),(s*.35+k*.12,-.32,.13),(.07,.11,.07),"cream",True)
        a.tube("TinyArm_"+str(s),[(s*.40,-.02,.99),(s*.48,-.24,.86),(s*.37,-.37,.88)],.10,"lime",sides=10)
        for k in [-1,1]:
            puff(a,"HandClaw_%s_%s"%(s,k),(s*.37+k*.05,-.441,.88),(.045,.075,.043),"cream",True)
    puff(a,"Head",(0,-.24,1.50),(.63,.49,.58),"lime")
    puff(a,"LowerJaw",(0,-.49,1.13),(.40,.37,.23),"cream")
    puff(a,"Snout",(0,-.662,1.44),(.46,.34,.30),"lime")
    mouth(a,-.829,1.208,.29,.16,2)
    eyes(a,.40,-.563,1.71,.188,"brown")
    for s in [-1,1]:
        puff(a,"Nostril_"+str(s),(s*.17,-.941,1.533),(.04,.024,.043),"green",True)
    a.tube("ThickCurlTail",[(0,.46,.50),(.30,.75,.58),(.59,.90,.88),(.61,.87,1.20),(.49,.78,1.36)],.22,"lime",sides=12)
    for i,(x,y,z,sz) in enumerate([(0,.11,2.0,.21),(0,.31,1.60,.20),(.36,.80,.92,.18),(.52,.89,1.28,.13)]):
        puff(a,"PinkDorsalBump_%s"%i,(x,y,z),(.14,sz,sz),"pink",True)


def lava_toaster(a):
    a.box("ToasterBody",(0,.03,.80),(1.40,.90,1.12),"orange",bevel=.16)
    for s in [-1,1]:
        for y in [-.24,.32]:
            a.box("RubberFoot_%s_%s"%(s,y),(s*.48,y,.15),(.30,.29,.26),"navy",bevel=.06)
            a.box("FootOrangeInset_%s_%s"%(s,y),(s*.48,y-.15,.15),(.15,.025,.10),"orange",bevel=.025)
    a.box("FaceNavyBorder",(0,-.446,.80),(1.16,.064,.91),"navy",bevel=.16)
    a.box("FaceCreamInset",(0,-.485,.80),(1.04,.05,.79),"cream",bevel=.13)
    eyes(a,.265,-.529,.895,.139,"navy",False)
    mouth(a,-.547,.655,.127,.073)
    cheeks(a,.38,-.533,.67,.082)
    a.box("TopPlate",(0,.03,1.365),(1.16,.72,.05),"cream",bevel=.10)
    for i,y in enumerate([-.16,.22]):
        a.box("ToastSlot_%s"%i,(0,y,1.397),(.89,.16,.025),"navy",bevel=.055)
        a.prism("LavaToastCrust_%s"%i,[(-.40,1.40),(-.40,1.73),(-.48,1.82),(-.45,1.93),
                  (-.30,1.99),(.30,1.99),(.45,1.93),(.48,1.82),(.40,1.73),(.40,1.40)],.125,"brown",y=y,bevel=.05)
        a.prism("LavaToastRed_%s"%i,[(-.34,1.44),(-.34,1.75),(-.41,1.84),(-.38,1.89),
                  (-.27,1.93),(.27,1.93),(.38,1.89),(.41,1.84),(.34,1.75),(.34,1.44)],.139,"red",y=y,bevel=.025)
        for j,pts in enumerate([[(-.29,y-.087,1.88),(-.1,y-.087,1.78),(-.19,y-.087,1.62),(-.12,y-.087,1.45)],
                 [( .12,y-.087,1.94),(.04,y-.087,1.82),(.21,y-.087,1.69),(.15,y-.087,1.48)]]):
            a.tube("MagmaCrack_%s_%s"%(i,j),pts,.027,"yellow",sides=6)
    a.box("LeverTrack",(-.72,-.04,.98),(.07,.27,.43),"navy",bevel=.04)
    a.box("Lever",(-.81,-.05,1.13),(.27,.29,.13),"yellow",bevel=.045)
    for i in range(3):
        a.box("SideVent_%s"%i,(.705,-.20+i*.16,.55),(.025,.05,.25),"navy",bevel=.024)
    a.cone("MagmaSideBadge",(-.723,.09,.64),.15,.15,.034,"navy",vertices=6,rotation=(0,pi/2,0))
    a.cone("MagmaInset",(-.75,.09,.64),.10,.10,.022,"red",vertices=6,rotation=(0,pi/2,0))


def moon_moth(a):
    # Four solid wing lobes have a dark seam and smaller raised color panels.
    for s in [-1,1]:
        top=[(s*.25,.83),(s*.39,1.44),(s*.83,1.94),(s*1.12,1.84),
             (s*1.20,1.53),(s*1.02,1.13),(s*.69,.90)]
        a.prism("UpperWingSeam_"+str(s),top,.22,"navy",y=.10,bevel=.06)
        topInset=[(s*.39,.99),(s*.51,1.46),(s*.86,1.80),(s*1.02,1.72),
                  (s*1.07,1.51),(s*.93,1.23),(s*.66,1.06)]
        a.prism("UpperWing_"+str(s),topInset,.25,"purple",y=.095,bevel=.065)
        low=[(s*.29,.59),(s*.37,1.03),(s*.84,1.00),(s*1.06,.76),(s*.92,.47),(s*.59,.43)]
        a.prism("LowerWingSeam_"+str(s),low,.21,"navy",y=.11,bevel=.06)
        a.prism("LowerWing_"+str(s),[(s*.40,.62),(s*.43,.92),(s*.81,.90),(s*.94,.73),(s*.85,.57),(s*.62,.54)],.24,"purple",y=.085,bevel=.045)
        crescent(a,"WingMoon_"+str(s),s*.80,-.058,1.43,.215,"cyan",mirror=s>0)
        a.prism("WingCreamEdge_"+str(s),[(s*.90,1.76),(s*1.01,1.70),(s*1.06,1.51),
                  (s*.94,1.22),(s*.89,1.16),(s*.96,1.51)],.030,"cream",y=-.040,bevel=.018)
        puff(a,"WingSpot_"+str(s),(s*.76,-.071,.73),(.13,.032,.13),"cream",True)
    puff(a,"Body",(0,-.03,.70),(.41,.32,.51),"cream")
    for i,(x,z) in enumerate([(-.27,.50),(0,.42),(.27,.50),(-.32,.77),(.32,.77)]):
        puff(a,"PlushBodyLobe_%s"%i,(x,-.155,z),(.19,.23,.19),"cream",True)
    for row,z in enumerate([.47,.65,.84]):
        for col,x in enumerate([-.23,0,.23]):
            yy=-.03-.32*sqrt(max(.1,1-(x/.43)**2-((z-.70)/.53)**2))
            puff(a,"PlushChestScallop_%s_%s"%(row,col),(x,yy,z),(.15,.075,.17),"cream",True)
    puff(a,"Head",(0,-.08,1.16),(.46,.37,.40),"cream")
    eyes(a,.20,-.424,1.22,.163,"purple",False)
    smile(a,-.462,1.014,.10,.045)
    cheeks(a,.30,-.392,1.04,.074)
    for s in [-1,1]:
        a.tube("AntennaStem_"+str(s),[(s*.14,-.03,1.44),(s*.28,-.04,1.72),(s*.44,-.025,1.97)],.055,"purple",sides=8)
        plume=puff(a,"AntennaPlume_"+str(s),(s*.35,-.05,1.83),(.135,.10,.28),"cream",True)
        plume.rotation_euler[1]=s*radians(28)
        for i in range(3):
            puff(a,"AntennaLobe_%s_%s"%(s,i),(s*(.27+i*.065),-.05,1.69+i*.10),(.12,.105,.10),"cream",True)
        foot(a,"TinyFoot_"+str(s),(s*.18,-.05,.16),"navy",(.13,.20,.14))


def royal_slime(a):
    body=a.lathe("SlimeBody",[(0,.08),(.43,.08),(.62,.20),(.65,.44),(.63,.92),
                             (.49,1.36),(.20,1.52),(0,1.55)],"blue",loc=(0,.035,0),segments=32)
    body.scale.y=.82
    for i in range(7):
        t=2*pi*i/7
        puff(a,"BaseScallop_%s"%i,(.46*cos(t),.035+.38*sin(t),.19),(.23,.205,.14),"blue",True)
    for s in [-1,1]:
        puff(a,"HandNub_"+str(s),(s*.65,-.06,.65),(.22,.24,.23),"blue",True)
    eyes(a,.27,-.463,1.018,.222,"blue")
    mouth(a,-.514,.731,.156,.103)
    crown_start=len(a.objects)
    a.torus("CrownBandSeam",(0,.025,1.506),.435,.071,"navy",segments=24,sides=8)
    a.lathe("CrownBand",[(.37,0),(.47,0),(.47,.15),(.37,.15)],"gold",loc=(0,.025,1.505),segments=24)
    # Three broad blunt crown peaks, with a matching rear wall for a full 3D crown.
    points=[(-.45,1.57),(-.48,1.97),(-.30,1.83),(0,2.10),(.30,1.83),(.48,1.97),(.45,1.57)]
    a.prism("CrownFront",points,.11,"gold",y=-.237,bevel=.055)
    a.prism("CrownRear",[(-.40,1.58),(-.40,1.90),(-.20,1.81),(0,1.96),(.20,1.81),(.40,1.90),(.40,1.58)],.10,"gold",y=.281,bevel=.045)
    for i,(x,z) in enumerate([(-.46,1.98),(0,2.1),(.46,1.98)]):
        puff(a,"CrownFinial_%s"%i,(x,-.237,z),(.115,.105,.106),"gold",True)
    a.prism("GemRim",[(-.117,1.74),(0,1.86),(.117,1.74),(.085,1.64),(-.085,1.64)],.08,"cream",y=-.324,bevel=.021)
    a.prism("PinkGem",[(-.083,1.74),(0,1.825),(.083,1.74),(.06,1.673),(-.06,1.673)],.085,"magenta",y=-.37,bevel=.012)
    for obj in a.objects[crown_start:]:
        obj.location.z-=.12


BUILDERS = {
    "P01": pocket_bulldog, "P02": toast_capybara, "P03": pancake_penguin,
    "P04": jelly_axolotl, "P05": rocket_snail, "P06": traffic_crab,
    "P07": teapot_frog, "P08": skater_shark, "P09": disco_duck,
    "P10": cloud_sheep, "P11": cactus_cat, "P12": ufo_jelly,
    "P13": pumpkin_bunny, "P14": hoodie_ghost, "P15": marshmallow_dragon,
    "P16": banana_gorilla, "P17": gummy_rex, "P18": lava_toaster,
    "P19": moon_moth, "P20": royal_slime,
}


def build(spec):
    a = Asset(spec)
    BUILDERS[spec["id"]](a)
    a.anchor("FollowAttachment",(0,.25,.65))
    a.anchor("DisplayFocus",(0,0,1.0))
    return a
