# Bring facial fur into a single flowing surface and soften glove tips.
for name in ['Face_WhiteFur','Bib_WhiteFurEdge']:
    o=bpy.data.objects.get(name)
    if o:bpy.data.objects.remove(o,do_unlink=True)
half=[(0,-.335,6.025),(.28,-.36,5.98),(.43,-.34,5.86),(.46,-.335,5.69),(.47,-.33,5.57),(.61,-.27,5.53),(.555,-.29,5.45),(.64,-.25,5.40),(.55,-.30,5.34),(.605,-.265,5.28),(.49,-.335,5.235),(.37,-.36,5.085),(.18,-.35,4.96),(0,-.35,4.925)]
outline=half+[(-x,y,z) for x,y,z in half[-2:0:-1]]
parts=[solid_panel('Face foundation',outline,white,'02 Face','Head',depth=.15,bulge=.17)]
for s in [-1,1]:
    parts.append(uvball('Soft muzzle',(s*.14,-.485,5.355),(.205,.126,.127),white,'02 Face','Head',seg=24,rings=16))
parts.append(uvball('Soft chin',(0,-.346,5.045),(.245,.135,.145),white,'02 Face','Head'))
parts.append(uvball('Nose bridge',(0,-.48,5.52),(.105,.083,.153),white,'02 Face','Head'))
fuse(parts,'Face_WhiteFur',white,'02 Face','Head',voxel=.008,target=6000,smooth=6)

# Ears sit beside the hat, below the rolled brim.
for name in ['Head_BlackFur','LeftEar_Inner','RightEar_Inner']:
    o=bpy.data.objects.get(name)
    for v in o.data.vertices:
        p=o.matrix_world@v.co
        if p.z>5.89 and abs(p.x)>.47:
            p.z-=min(.25,(p.z-5.89)*.70)
            v.co=o.matrix_world.inverted()@p

for s,side in [(1,'Left'),(-1,'Right')]:
    o=bpy.data.objects.get(side+'Glove_White')
    if o:bpy.data.objects.remove(o,do_unlink=True)
    bone=side+'Hand';center=Vector((s*1.86,-.06,2.91))
    down=Vector((s*.35,-.03,-.94)).normalized();across=Vector((s*.94,0,.35)).normalized()
    palm=uvball('Smooth glove palm',center,(.234,.146,.27),glovewhite,'05 Gloves',bone)
    palm.rotation_euler[1]=-s*.3
    parts=[palm]
    for off,length in [(-.15,.27),(-.047,.36),(.062,.325),(.16,.24)]:
        p=center+across*off+down*.17
        q=p+down*length*.6
        end=p+down*length+Vector((0,-.052,0))+across*off*.12
        parts.append(tube('Rounded finger',[p,q,end],[.072,.065,.052],glovewhite,'05 Gloves',bone,n=12,steps=3))
        parts.append(uvball('Round fingertip',end,(.053,.057,.057),glovewhite,'05 Gloves',bone,seg=12,rings=8))
    p=center-across*.15+Vector((0,-.01,.07));end=p-across*.205+down*.20+Vector((0,-.05,0))
    parts.append(tube('Rounded thumb',[p,p-across*.17+down*.02,end],[.104,.085,.058],glovewhite,'05 Gloves',bone,n=12,steps=4))
    parts.append(uvball('Round thumb tip',end,(.063,.061,.065),glovewhite,'05 Gloves',bone,seg=12,rings=8))
    fuse(parts,side+'Glove_White',glovewhite,'05 Gloves',bone,voxel=.009,target=2000,smooth=5)

for m,color in [(red,(.32,.0025,.008)),(bowred,(.37,.003,.011)),(fur,(.008,.010,.013))]:
    m.diffuse_color=(*color,1)
    m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*color,1)
scene.view_settings.exposure=-.35
scene.cycles.samples=48
scene.render.resolution_x=1200;scene.render.resolution_y=1400
camera.location=(7,-23,9);aim(camera,(0,0,3.97));camera.data.ortho_scale=8.9
# Match viewport material swatches and export materials to the final palette.
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'CatInTheHat_Base.blend'))
print('Final shape polish saved')
