"""Original ACU champion. Bounds approx X +/-9, Y -7.9..7.9, Z 1.2..28.
Build geometry only; keep the front (-Y) open. Intended budget below 30k triangles.
"""
from common import *

G = '20_Statue'
E = '21_StatueGlow'

def _loft(name, sections, material, group=G):
    profile = [(-.68,-1),(.68,-1),(1,-.48),(1,.55),(.64,1),(-.64,1),(-1,.55),(-1,-.48)]
    verts = []
    for center, width, depth in sections:
        verts.extend([(center[0]+x*width, center[1]+y*depth, center[2]) for x,y in profile])
    faces = [tuple(reversed(range(8)))]
    for j in range(len(sections)-1):
        for i in range(8):
            a=j*8+i; b=j*8+(i+1)%8
            faces.append((a,b,b+8,a+8))
    faces.append(tuple((len(sections)-1)*8+i for i in range(8)))
    return mesh(name, verts, faces, material, group)

def _solidplate(name, front, depth, material, group=G):
    n=len(front)
    verts=list(front)+[(x,y+depth,z) for x,y,z in front]
    faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    for i in range(n):
        j=(i+1)%n
        faces.append((i,j,j+n,i+n))
    return mesh(name,verts,faces,material,group)

def _vertical_ring(name,cx,y,cz,outer,inner,depth,material,segments=80,group=G):
    verts=[]
    for yy in (y-depth/2,y+depth/2):
        for r in (outer,inner):
            for i in range(segments):
                a=2*pi*i/segments
                verts.append((cx+r*cos(a),yy,cz+r*sin(a)))
    faces=[]
    for i in range(segments):
        j=(i+1)%segments
        faces += [(i,j,segments+j,segments+i),
                  (2*segments+i,3*segments+i,3*segments+j,2*segments+j),
                  (i,2*segments+i,2*segments+j,j),
                  (segments+i,segments+j,3*segments+j,3*segments+i)]
    return mesh(name,verts,faces,material,group)

def _gem(name,center,width,height,depth,material,group=G):
    x,y,z=center
    verts=[(x,y-depth,z),(x-width,y,z),(x,y,z+height),(x+width,y,z),(x,y,z-height),(x,y+depth,z)]
    return mesh(name,verts,[(0,1,2),(0,2,3),(0,3,4),(0,4,1),(5,2,1),(5,3,2),(5,4,3),(5,1,4)],material,group)

def _blade(name,tip,hilt,width,material,group=G):
    x,y,z=hilt; tx,ty,tz=tip
    verts=[(x-width,y,z),(x,y-.17,z),(x+width,y,z),(x,y+.17,z),
           (tx,ty-.06,tz),(tx,ty+.06,tz)]
    return mesh(name,verts,[(0,1,4),(1,2,4),(2,3,5,4),(3,0,4,5),(0,3,2,1)],material,group)

def _limb(name,a,b,wa,wb,depth,material):
    axis=Vector(b)-Vector(a)
    tangent=axis.normalized()
    side=tangent.cross(Vector((0,1,0))).normalized()
    ahead=side.cross(tangent).normalized()
    shape=[(-.7,-1),(.7,-1),(1,-.5),(1,.55),(.6,1),(-.6,1),(-1,.55),(-1,-.5)]
    sections=[(0,wa*.84),(.16,wa),(0.78,wb),(1,wb*.82)]
    verts=[]
    for t,w in sections:
        center=Vector(a)+axis*t
        for s,f in shape:
            p=center+side*s*w+ahead*f*depth
            verts.append(tuple(p))
    faces=[tuple(reversed(range(8)))]
    for row in range(3):
        for i in range(8):
            n=(i+1)%8
            faces.append((row*8+i,row*8+n,(row+1)*8+n,(row+1)*8+i))
    faces.append(tuple(24+i for i in range(8)))
    return mesh(name,verts,faces,material,G)

def _cape():
    # The unequal hems and twisting ribs keep the sculptural silhouette alive.
    cols=19; rows=15
    verts=[]
    for j in range(rows):
        t=j/(rows-1)
        for i in range(cols):
            u=(i/(cols-1))*2-1
            width=3.9+2.25*t
            x=u*width + .75*sin(t*pi)
            y=1.05+3.65*t+.52*sin(u*pi*4.2+.7*t)*(.15+.85*t)
            y+=.6*(1-u*u)*sin(t*pi)
            z=18.1-11.8*t + .6*abs(u)-.38*sin(u*pi*2.5)*t*t
            z+=1.9*max(0,u)*t*t
            verts.append((x,y,z))
    faces=[]
    for j in range(rows-1):
        for i in range(cols-1):
            a=j*cols+i
            faces.extend([(a,a+1,a+cols+1),(a,a+cols+1,a+cols)])
    mesh('Champion_Cape_Faceted_Velvet',verts,faces,'purple',G)
    for col in (0,cols-1):
        pts=[verts[j*cols+col] for j in range(rows)]
        tube('Cape_Gold_Edge_'+str(col),pts,[.065]*len(pts),'gold',G,sides=6)
    pts=verts[(rows-1)*cols:]
    tube('Cape_Gold_Hem',pts,[.07]*len(pts),'gold',G,sides=6)
    for col in (3,7,11,15):
        pts=[verts[j*cols+col] for j in range(3,rows)]
        tube('Cape_Woven_Rib_'+str(col),[(x,y+.025,z) for x,y,z in pts],[.035]*len(pts),'gold',G,sides=5)
    # Graphic sunburst sewn into the back.
    _vertical_ring('Cape_Emblem_Rim',.6,4.2,10.55,1.0,.91,.035,'gold',48)
    for i in range(8):
        a=i*pi/4
        x=.6+1.2*cos(a); z=10.55+1.2*sin(a)
        _gem('Cape_Star_'+str(i),(x,4.15,z),.08,.2,.04,'gold')

def build():
    # Wide beveled, layered dais; the main navigation route passes around it.
    cylinder('Champion_Dais_Foundation',(0,0,1.39),7.85,.38,'stoneDark',G,vertices=64)
    cylinder('Champion_Dais_Step_01',(0,0,1.67),7.4,.28,'stoneLight',G,vertices=64)
    ring('Dais_Inlaid_Gold',(0,0,1.835),7.0,6.87,.035,'gold',G,segments=96)
    cylinder('Champion_Dais_Step_02',(0,0,2.08),6.15,.52,'stone',G,vertices=12)
    ring('Dais_Cyan_Channel',(0,0,2.35),5.92,5.79,.05,'cyanGlow',E,segments=96)
    cylinder('Champion_Plinth_Foot',(0,0,2.67),4.92,.6,'gold',G,vertices=8)
    cylinder('Champion_Plinth',(0,0,3.6),4.62,1.38,'stoneDark',G,vertices=8)
    cylinder('Champion_Plinth_Capital',(0,0,4.44),4.94,.32,'gold',G,vertices=8)
    cylinder('Champion_Plinth_Top',(0,0,4.74),4.66,.30,'ivory',G,vertices=8)
    ring('Pedestal_Glow_Rim',(0,0,4.91),4.5,4.40,.025,'goldGlow',E,segments=64)
    for i in range(8):
        a=(i+.5)*pi/4
        x=4.33*cos(a); y=4.33*sin(a)
        p=box('Plinth_Gold_Inlay_'+str(i),(x,y,3.57),(.22,.16,1.04),'gold',G,bevel=.035)
        p.rotation_euler[2]=a-pi/2
    text('Champion_Title','THE FIRST CHAMPION',(0,-4.315,3.57),.35,'goldLight',G)
    text('Champion_Subtitle','WORLDS UNITE',(0,-4.34,3.07),.21,'ivory',G)
    # Separated front crest and four rune plates, giving the dais a crafted identity.
    _gem('Dais_Front_Crest',(0,-5.02,2.18),.32,.31,.13,'purpleGlow',E)
    for i in range(12):
        a=i*2*pi/12
        if abs(sin(a)+1)<.15:
            continue
        x=6.48*cos(a); y=6.48*sin(a)
        slab=box('Dais_Radial_Inlay_'+str(i),(x,y,1.83),(.1,.48,.035),'gold',G)
        slab.rotation_euler[2]=a-pi/2
    # A rock under the rear boot anchors a dynamic contrapposto stance.
    ico('Oath_Rock',(2.35,.55,5.45),(2.1,1.65,1.1),'stoneDark',G,subdivisions=1)
    ico('Oath_Rock_Facet',(3.03,.26,5.6),(1.05,1.3,.9),'stoneLight',G,subdivisions=1)
    # Sculpted footwear, shin armor and cloth underlayer.
    _loft('Boot_Left',[
        ((-1.82,-.47,4.92),.86,1.47),((-1.88,-.42,5.12),1.03,1.56),
        ((-1.98,-.09,5.5),.91,1.22),((-2.01,.15,6.5),.62,.73),
        ((-2,.18,7.22),.72,.72)],'gold')
    _loft('Boot_Right',[
        ((2.33,.25,5.92),.83,1.34),((2.35,.18,6.13),.96,1.45),
        ((2.39,.39,6.63),.8,1.15),((2.37,.5,7.32),.63,.69)],'gold')
    _loft('Left_Greave',[
        ((-2,.18,6.5),.57,.65),((-1.97,.14,7.2),.85,.83),
        ((-1.7,.16,8.7),.92,.88),((-1.49,.05,9.8),.77,.78)],'ivory')
    _loft('Right_Greave',[
        ((2.37,.5,7.06),.63,.68),((2.28,.27,7.7),.8,.86),
        ((1.93,-.1,8.75),.94,.84),((1.63,-.46,9.78),.88,.81)],'ivory')
    _solidplate('Left_Shin_Gold_Ridge',[(-2.28,-.73,7.14),(-1.98,-.91,7.01),(-1.24,-.72,9.34),(-1.48,-.84,9.9),(-1.89,-.9,9.44)],.12,'gold')
    _solidplate('Right_Shin_Gold_Ridge',[(1.89,-.65,7.55),(2.31,-.77,7.37),(2.17,-1.06,9.2),(1.65,-1.37,10.0),(1.24,-1.2,9.5)],.1,'gold')
    _gem('Left_Kneecap',(-1.46,-.8,9.75),.91,.79,.32,'goldLight')
    _gem('Right_Kneecap',(1.62,-1.15,9.83),.96,.78,.32,'goldLight')
    _gem('Left_Knee_Inlay',(-1.46,-1.14,9.76),.28,.33,.04,'purple')
    _gem('Right_Knee_Inlay',(1.62,-1.48,9.82),.28,.33,.04,'purple')
    _loft('Left_Thigh',[
        ((-1.47,.13,9.61),.73,.79),((-1.25,.29,10.45),.95,.9),
        ((-.93,.30,12.0),1.03,.97),((-.9,.21,12.88),.9,.9)],'gold')
    _loft('Right_Thigh',[
        ((1.6,-.44,9.78),.74,.78),((1.4,-.12,10.5),.96,.98),
        ((1.01,.15,12.0),1.05,.98),((.94,.15,12.85),.87,.87)],'gold')
    # Wide three-panel tassets replace the silhouette of a primitive mannequin.
    for side in (-1,1):
        _solidplate('Outer_Tasset_'+str(side),[
            (side*.43,-.92,13.12),(side*1.98,-.6,13.05),(side*2.34,-.59,11.76),
            (side*1.73,-.91,11.07),(side*.81,-1.09,11.39)],.28,'ivory')
        tube('Tasset_Edge_'+str(side),[(side*.52,-1.02,12.93),(side*.82,-1.16,11.5),(side*1.74,-1.01,11.19),(side*2.26,-.69,11.83)],[.07]*4,'gold',G,sides=6)
    _solidplate('Central_Tabard',[
        (-.71,-1.25,13.1),(.71,-1.25,13.1),(.59,-1.57,11.26),(0,-1.67,10.56),(-.59,-1.57,11.26)],.16,'purple')
    tube('Tabard_Gold_Trim',[(-.62,-1.42,12.93),(-.5,-1.69,11.33),(0,-1.79,10.76),(.5,-1.69,11.33),(.62,-1.42,12.93)],[.055]*5,'gold',G,sides=6)
    _loft('Waist_Armored_Belt',[
        ((0,.15,12.77),1.83,1.05),((0,.13,13.05),1.91,1.12),
        ((0,.1,13.44),1.81,1.03)],'gold')
    _gem('Belt_Buckle',(0,-1.1,13.16),.55,.43,.21,'goldLight')
    _gem('Belt_Core',(0,-1.35,13.16),.24,.22,.06,'purpleGlow',E)
    _loft('Cuirass_Shadow_Underbody',[
        ((0,.13,13.25),1.58,.90),((0,.08,14.2),1.78,1.05),
        ((-.08,.13,16.3),2.54,1.25),((-.12,.18,17.55),2.65,1.13),
        ((-.1,.16,18.12),1.29,.89)],'stoneDark')
    # Segmented breastplate with central keel and chamfered edges.
    for side in (-1,1):
        _solidplate('Breastplate_'+str(side),[
            (side*.1,-1.25,17.49),(side*1.48,-1.08,18.05),
            (side*2.56,-.78,17.38),(side*2.24,-1.18,15.94),
            (side*.22,-1.55,15.46)],.31,'ivory')
        tube('Cuirass_Gold_Border_'+str(side),[
            (side*.15,-1.29,17.53),(side*1.48,-1.12,18.1),(side*2.6,-.82,17.42),
            (side*2.28,-1.25,15.91),(side*.19,-1.6,15.4)],[.11]*5,'gold',G,sides=6)
        _solidplate('Breastplate_Inlaid_Wing_'+str(side),[
            (side*.37,-1.57,16.18),(side*1.82,-1.34,16.69),
            (side*2.03,-1.15,17.24),(side*.82,-1.5,16.86)],.055,'gold')
    for n in range(3):
        z=13.7+n*.56
        _solidplate('Abdominal_Lame_'+str(n),[(-1.64-n*.11,-1.0,z+.4),(1.64+n*.11,-1.0,z+.4),(1.42+n*.11,-1.22,z-.05),(0,-1.45,z-.23),(-1.42-n*.11,-1.22,z-.05)],.23,'gold' if n==1 else 'ivory')
    _gem('Heart_Crest_Frame',(-.03,-1.65,16.68),.58,.83,.2,'goldLight')
    _gem('Heart_Crest_Core',(-.03,-1.9,16.68),.30,.51,.11,'purpleGlow',E)
    # Shoulder shells are oversized and layered, turning the hero into a readable icon.
    for side in (-1,1):
        for n in range(3):
            z=17.05+n*.58
            x=side*(2.67+n*.18)
            _loft('Pauldron_'+str(side)+'_'+str(n),[
                ((x,.16,z-.28),.96+n*.14,.83),
                ((x,.12,z+.24),1.30+n*.1,1.12),
                ((x-side*.15,.14,z+.66),.92+n*.05,.82)],'gold' if n==1 else 'ivory')
        for j in range(3):
            x=side*(3.37+j*.35)
            _solidplate('Shoulder_Crown_'+str(side)+'_'+str(j),[
                (x-side*.26,-.07,18.43),(x+side*.36,.02,18.31),
                (x+side*.62,.2,19.26+j*.18),(x-side*.12,.1,18.85)],.36,'gold')
        ico('Cape_Clasp_'+str(side),(side*1.75,-.72,18.03),(.34,.23,.34),'goldLight',G,subdivisions=2)
    # Bent supporting arm on the grounded sword.
    _limb('Sword_Upper_Arm',(3.31,.11,17.34),(4.92,-.29,15.02),.90,.69,.73,'gold')
    _gem('Sword_Elbow',(4.91,-.76,14.94),.73,.71,.3,'ivory')
    _limb('Sword_Forearm',(4.95,-.32,14.88),(5.6,-1.02,12.98),.72,.60,.67,'ivory')
    _solidplate('Sword_Vambrace_Ridge',[(4.84,-1.06,14.76),(5.33,-.98,14.55),(5.93,-1.54,13.13),(5.46,-1.69,12.81)],.17,'gold')
    _loft('Sword_Gauntlet',[
        ((5.66,-1.2,12.25),.48,.55),((5.64,-1.19,12.63),.65,.67),
        ((5.58,-1.06,13.17),.56,.59)],'gold')
    for i in range(4):
        x=5.2+i*.29
        tube('Sword_Gauntlet_Finger_'+str(i),[(x,-1.71,12.68),(x,-1.95,12.41),(x,-1.82,12.13)],[.13,.145,.1],'goldLight',G,sides=6)
    # The raised arm creates the deliberately asymmetrical hero silhouette.
    _limb('Raised_Upper_Arm',(-3.25,.10,17.6),(-4.84,-.16,20.15),.9,.65,.7,'gold')
    _gem('Raised_Elbow',(-4.98,-.69,20.06),.76,.8,.29,'ivory')
    _limb('Raised_Forearm',(-4.89,-.15,20.25),(-5.45,-.42,23.04),.79,.58,.64,'ivory')
    tube('Raised_Vambrace_Ridge',[(-5.02,-.87,20.55),(-5.32,-1.02,21.73),(-5.51,-1.06,22.78)],[.09,.12,.07],'gold',G,sides=6)
    _loft('Raised_Gauntlet',[
        ((-5.47,-.42,22.73),.62,.60),((-5.54,-.44,23.35),.74,.70),
        ((-5.5,-.48,23.85),.62,.67)],'gold')
    for i in range(4):
        x=-6.06+i*.34
        z=23.9 + (.14 if i in (1,2) else 0)
        tube('Raised_Finger_'+str(i),[(x,-.92,z-.5),(x,-1.15,z),(x,-.83,z+.27)],[.145,.16,.12],'goldLight',G,sides=6)
    tube('Raised_Thumb',[(-4.94,-.74,23.1),(-4.65,-.9,23.6),(-4.92,-1.12,23.87)],[.20,.20,.14],'goldLight',G,sides=7)
    # Tall neck, angular mask, cheek plates and a swept helmet crest.
    _loft('Neck',[
        ((-.12,.16,18.08),.65,.65),((-.12,.16,19.04),.7,.65)],'gold')
    _loft('Helmet_Main',[
        ((-.12,-.04,19.02),.65,.7),((-.12,-.02,19.5),1.06,1.0),
        ((-.12,.06,20.88),1.27,1.12),((-.12,.14,21.77),1.0,.93),
        ((-.12,.18,22.1),.41,.5)],'gold')
    _solidplate('Face_Ivory_Mask',[
        (-1.02,-.96,20.94),(-.72,-1.18,21.19),(.51,-1.18,21.19),(.84,-.96,20.94),
        (.63,-1.13,19.71),(-.13,-1.34,19.29),(-.85,-1.13,19.71)],.17,'ivory')
    mesh('Face_Nose',[(-.32,-1.28,20.78),(.09,-1.28,20.78),(-.1,-1.65,20.12),(-.43,-1.31,20.07),(.2,-1.31,20.07)],[(0,1,2),(0,2,3),(1,4,2),(2,4,3)],'gold',G)
    for side in (-1,1):
        xx=-.12+side*.54
        _solidplate('Eye_Slit_'+str(side),[(xx-side*.35,-1.25,20.73),(xx+side*.30,-1.20,20.82),(xx+side*.27,-1.225,20.64),(xx-side*.24,-1.30,20.55)],.025,'purpleGlow',E)
        tube('Helmet_Brow_'+str(side),[(-.12+side*.13,-1.28,20.95),(-.12+side*.91,-1.1,21.18)],[.11,.07],'gold',G,sides=6)
        _solidplate('Helmet_Cheek_'+str(side),[
            (-.12+side*1.14,-.73,20.38),(-.12+side*.96,-1.10,20.05),
            (-.12+side*.61,-1.20,19.26),(-.12+side*1.17,-.53,19.68)],.26,'gold')
        _solidplate('Helmet_Wing_'+str(side),[
            (-.12+side*1.04,.13,20.86),(-.12+side*1.57,.31,21.39),
            (-.12+side*1.76,1.06,22.54),(-.12+side*1.06,.71,21.82)],.19,'goldLight')
    tube('Mouth_Seam',[(-.48,-1.33,19.81),(-.12,-1.40,19.73),(.24,-1.33,19.81)],[.025]*3,'stoneDark',G,sides=5)
    _solidplate('Helmet_Center_Crest',[
        (-.34,-.76,21.55),(.10,-.76,21.55),(.21,.10,22.84),
        (-.12,1.45,23.49),(-.47,.38,22.82)],.25,'goldLight')
    _gem('Helmet_Forehead',(-.12,-1.10,21.65),.25,.33,.12,'purpleGlow',E)
    # Oath sword: hand around wrapped grip, sculpted guard, planar sharpened blade.
    tube('Sword_Grip',[(5.58,-1.42,11.8),(5.62,-1.4,13.55)],[.20,.21],'purple',G,sides=10)
    for n in range(7):
        cylinder('Sword_Grip_Wrap_'+str(n),(5.61,-1.41,12.01+n*.20),.225,.055,'gold',G,vertices=12)
    _gem('Sword_Pommel',(5.62,-1.4,13.87),.35,.48,.35,'gold')
    _gem('Sword_Pommel_Stone',(5.62,-1.76,13.89),.14,.22,.06,'cyanGlow',E)
    _solidplate('Sword_Crossguard',[
        (3.86,-1.43,11.78),(4.20,-1.56,12.23),(5.64,-1.64,12.03),
        (6.98,-1.56,12.23),(7.34,-1.43,11.78),(6.27,-1.43,11.60),(4.91,-1.43,11.60)],.36,'goldLight')
    _blade('Sword_Blade',(5.31,-1.46,5.15),(5.6,-1.43,11.73),.46,'ivory')
    tube('Sword_Blade_Fuller',[(5.56,-1.617,11.5),(5.39,-1.566,6.49),(5.31,-1.515,5.39)],[.045,.035,.0],'gold',G,sides=5)
    _gem('Sword_Guard_Core',(5.6,-1.71,11.85),.28,.34,.06,'purpleGlow',E)
    _cape()
    # Halo is behind the helmet; negative Y face remains completely unobstructed.
    _vertical_ring('Champion_Halo_Frame',0,2.86,20.31,5.92,5.63,.22,'gold',96)
    _vertical_ring('Champion_Halo_Inner',0,2.74,20.31,5.35,5.29,.06,'goldLight',96)
    _vertical_ring('Champion_Halo_Light',0,2.69,20.31,5.62,5.55,.055,'goldGlow',96,E)
    for i in range(24):
        a=2*pi*i/24
        r=6.06
        long=1.13 if i%3==0 else .56
        p0=(r*cos(a),2.86,20.31+r*sin(a))
        p1=((r+long)*cos(a),2.86,20.31+(r+long)*sin(a))
        tube('Halo_Ray_'+str(i),[p0,p1],[.095,.018],'gold',G,sides=6)
    # A spear-shaped floating crystal symbol above the open gauntlet.
    _gem('Raised_Crystal_Heart',(-5.55,-.42,25.21),.62,1.56,.51,'purpleGlow',E)
    _gem('Raised_Crystal_WhiteFacet',(-5.65,-.78,25.40),.18,1.17,.10,'ivory')
    for i in range(5):
        a=i*2*pi/5
        x=-5.55+1.06*cos(a); y=-.42+.67*sin(a)
        _gem('Crystal_Satellite_'+str(i),(x,y,25.20+.24*cos(a)),.13,.37,.16,'goldLight')
    _vertical_ring('Crystal_Orbit',-5.55,-.24,25.14,1.14,1.08,.05,'gold',64)
    marker('FOCUS_CentralChampion',(0,-8,9),'landmark_focus')
