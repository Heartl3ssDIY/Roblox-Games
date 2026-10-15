# Continued in the build_cat namespace.
remaining=[o for o in root.all_objects if o.name.startswith('Hip lock')]
if remaining:join_group(remaining,'LowerTorso_FurTufts')

# The head is tapered at the chin and broad through the swept cheek silhouette.
loft('Head_BlackFur',[(0,0,4.84,.18,.17),(0,0,4.95,.32,.255),(0,0,5.10,.45,.32),(0,0,5.27,.58,.36),(0,.01,5.46,.65,.40),(0,.015,5.65,.61,.42),(0,.015,5.84,.55,.40),(0,.02,6.00,.44,.33),(0,.03,6.08,.23,.19)],fur,'02 Face','Head',n=40,waviness=.008)
face_outline=[(0,-.335,6.025),(.28,-.36,5.98),(.43,-.34,5.86),(.47,-.335,5.68),(.57,-.29,5.52),(.61,-.245,5.34),(.47,-.32,5.20),(.33,-.35,5.03),(.16,-.34,4.94),(0,-.35,4.91),(-.16,-.34,4.94),(-.33,-.35,5.03),(-.47,-.32,5.20),(-.61,-.245,5.34),(-.57,-.29,5.52),(-.47,-.335,5.68),(-.43,-.34,5.86),(-.28,-.36,5.98)]
face=solid_panel('Face_WhiteMask',face_outline,white,'02 Face','Head',depth=.13,bulge=.17)
# Add one subdivision to the cheek/forehead surface only.
bpy.context.view_layer.objects.active=face
mod=face.modifiers.new('Soft face planes','SUBSURF');mod.levels=2
bpy.ops.object.modifier_apply(modifier=mod.name)

for s,side in [(1,'Left'),(-1,'Right')]:
    ear=solid_panel(side+'Ear_Black',[(s*.39,-.02,5.86),(s*.57,-.01,6.17),(s*.79,.015,6.27),(s*.76,-.02,5.91),(s*.63,-.07,5.75)],fur,'02 Face','Head',depth=.17,bulge=.07)
    solid_panel(side+'Ear_Inner',[(s*.53,-.08,5.94),(s*.63,-.065,6.12),(s*.745,-.035,6.19),(s*.69,-.08,5.95),(s*.63,-.09,5.88)],inner,'02 Face','Head',depth=.025,bulge=.01)
    tufts=[]
    for j in range(4):
        z=5.7-j*.15
        x=s*(.50 + .015*j)
        tufts.append(tube('Cheek fur',[(x,.02,z),(s*(.68+j*.025),-.015,z-.02),(s*(.79+j*.026),-.035,z+.10-j*.045)],[.145,.105,.003],fur,'02 Face','Head',n=10,steps=3,aspect=.75))
    join_group(tufts,side+'Cheek_BlackTufts')
    tufts=[]
    for j in range(3):
        z=5.43-j*.12
        tufts.append(tube('White cheek fur',[(s*.41,-.335,z),(s*(.56+j*.018),-.27,z-.04),(s*(.70-j*.006),-.17,z+.015)],[.086,.075,.002],white,'02 Face','Head',n=10,steps=3,aspect=.65))
    join_group(tufts,side+'Cheek_WhiteTufts')

# Human-like eyes inside the pale cat face, with expressive black brows.
for s,side in [(1,'Left'),(-1,'Right')]:
    x=s*.245
    uvball(side+'Eye_Socket',(x,-.435,5.67),(.183,.09,.152),inner,'02 Face','Head')
    uvball(side+'Eye_White',(x,-.492,5.665),(.147,.059,.117),eye,'02 Face','Head')
    uvball(side+'Eye_Iris',(x-s*.018,-.548,5.668),(.061,.021,.074),iris,'02 Face','Head',seg=20,rings=12)
    uvball(side+'Eye_Pupil',(x-s*.018,-.568,5.668),(.031,.010,.052),black,'02 Face','Head',seg=16,rings=10)
    uvball(side+'Eye_Catchlight',(x-s*.035,-.579,5.697),(.016,.007,.018),glovewhite,'02 Face','Head',seg=12,rings=8)
    tube(side+'Eye_UpperLid',[(x-s*.147,-.502,5.67),(x-s*.085,-.536,5.755),(x+s*.02,-.54,5.779),(x+s*.136,-.496,5.714)],[.017,.021,.025,.009],white,'02 Face','Head',n=8,steps=3)
    tube(side+'Eye_LowerLid',[(x-s*.14,-.5,5.65),(x,-.528,5.553),(x+s*.134,-.493,5.635)],[.012,.02,.009],white,'02 Face','Head',n=8,steps=4)
    tube(side+'Eyebrow',[(s*.105,-.462,5.854),(s*.20,-.463,5.90),(s*.315,-.427,5.873),(s*.43,-.361,5.795)],[.035,.043,.034,.003],fur,'02 Face','Head',n=10,steps=4,aspect=.65)
    uvball(side+'Muzzle',(s*.14,-.485,5.355),(.22,.142,.135),white,'02 Face','Head',seg=28,rings=16)
uvball('Nose_Bridge',(0,-.48,5.52),(.105,.095,.155),white,'02 Face','Head')
solid_panel('Nose_Rose',[(0,-.646,5.404),(-.097,-.626,5.49),(-.073,-.629,5.535),(0,-.648,5.545),(.073,-.629,5.535),(.097,-.626,5.49)],nosemat,'02 Face','Head',depth=.058,bulge=.036)
for s,side in [(1,'Left'),(-1,'Right')]:
    uvball(side+'Nostril',(s*.056,-.659,5.482),(.019,.009,.011),mouthmat,'02 Face','Head',seg=12,rings=8)
tube('Muzzle_CenterLine',[(0,-.626,5.409),(0,-.632,5.352),(0,-.621,5.31)],[.008,.009,.007],nosemat,'02 Face','Head',n=8,steps=3)
uvball('Smile_Opening',(0,-.469,5.194),(.253,.07,.105),mouthmat,'02 Face','Head',seg=32,rings=16)
solid_panel('Smile_UpperTeeth',[(-.194,-.531,5.235),(-.12,-.546,5.247),(0,-.55,5.247),(.12,-.546,5.247),(.194,-.531,5.235),(.15,-.54,5.207),(0,-.551,5.199),(-.15,-.54,5.207)],teeth,'02 Face','Head',depth=.025,bulge=.007)
tube('Smile_LowerLip',[(-.246,-.486,5.218),(-.16,-.516,5.14),(0,-.531,5.122),(.16,-.516,5.14),(.246,-.486,5.218)],[.012,.024,.031,.024,.012],white,'02 Face','Head',n=10,steps=4)
uvball('Chin_White',(0,-.35,5.02),(.24,.145,.12),white,'02 Face','Head')
for s,side in [(1,'Left'),(-1,'Right')]:
    whisk=[]
    for j in range(3):
        z=5.365-j*.06
        uvball(side+'WhiskerRoot_'+str(j),(s*(.27+.01*j),-.592+j*.015,z),(.012,.006,.012),inner,'02 Face','Head',seg=8,rings=6)
        whisk.append(tube('Whisker',[(s*.30,-.566,z),(s*.54,-.54,z+.035-j*.02),(s*.83,-.48,z+.09-j*.048)],[.007,.006,.0015],inner,'02 Face','Head',n=6,steps=3))
    join_group(whisk,side+'Whiskers')

# Gloves: flared cuffs, a palm, four separated fingers and one bent thumb.
for s,side in [(1,'Left'),(-1,'Right')]:
    bone=side+'Hand'
    center=Vector((s*1.86,-.06,2.91))
    down=Vector((s*.35,-.03,-.94)).normalized()
    across=Vector((s*.94,0,.35)).normalized()
    palm=uvball(side+'Glove_Palm',center,(.235,.15,.285),glovewhite,'05 Gloves',bone)
    palm.rotation_euler[1]=-s*.30
    pieces=[palm]
    for i,(off,length) in enumerate([(-.15,.30),(-.047,.40),(.062,.365),(.16,.27)]):
        p=center+across*off+down*.16
        q=p+down*length*.58
        end=p+down*length+Vector((0,-.065,0))+across*off*.18
        pieces.append(tube('Glove finger',[p,q,end],[.071,.066,.018],glovewhite,'05 Gloves',bone,n=12,steps=4))
        uvball(side+'Glove_Knuckle_'+str(i),p+down*.08+Vector((0,-.112,0)),(.045,.025,.052),glovewhite,'05 Gloves',bone,seg=12,rings=8)
    p=center-across*.15+Vector((0,-.01,.07))
    pieces.append(tube('Glove thumb',[p,p-across*.17+down*.02,p-across*.225+down*.20+Vector((0,-.055,0))],[.106,.09,.022],glovewhite,'05 Gloves',bone,n=14,steps=4))
    join_group(pieces,side+'Glove_White')
    cuff=tube(side+'Glove_Cuff',[(s*1.678,-.037,3.18),(s*1.717,-.045,3.10),(s*1.757,-.05,3.02)],[.205,.214,.186],glovewhite,'05 Gloves',bone,n=28,steps=2,aspect=.85)
    for i in [-1,0,1]:
        a=center+across*i*.085-down*.01+Vector((0,-.15,0))
        b=a+down*.18
        tube(side+'Glove_Stitch_'+str(i),[a,(a+b)/2+Vector((0,-.008,0)),b],[.005,.007,.003],seammat,'05 Gloves',bone,n=6,steps=3)

# A long black tail, curled away from the legs and finished with pale fur.
tailpts=[(0,.40,2.79),(.12,.74,2.55),(.25,.95,2.05),(.40,1.05,1.50),(.67,1.04,1.12),(1.02,.97,1.07),(1.30,.86,1.27),(1.44,.75,1.56)]
tube('Tail_Black',tailpts,[.145,.15,.14,.13,.125,.12,.102,.075],fur,'06 Tail','LowerTorso',n=18,steps=5)
tube('Tail_WhiteTip',[(1.42,.76,1.51),(1.48,.73,1.69),(1.47,.70,1.84),(1.39,.67,1.97)],[.087,.105,.071,.005],white,'06 Tail','LowerTorso',n=16,steps=4)
tufts=[]
for j in range(5):
    a=2*pi*j/5
    tufts.append(tube('Tail tip lock',[(1.475+.06*cos(a),.73+.06*sin(a),1.69),(1.47+.10*cos(a),.70+.09*sin(a),1.83),(1.39+.07*cos(a),.67+.07*sin(a),1.99)],[.049,.04,.003],white,'06 Tail','LowerTorso',n=8,steps=2))
join_group(tufts,'Tail_WhiteTufts')

print('CAT_STAGE_DETAILS complete: '+str(len(list(root.all_objects)))+' meshes')
