"""East-island arena promenade: four monumental torii plus nine labeled portal stations.
Footprint approximately X 191..257, Y -141..-53, ground at Z 1.2.
No gameplay handlers or destination scenes are created. No Tournament of Power.
"""
from common import *

G = '60_ArenaPortals'
GROUND = 1.2

def _p(center, angle, p):
    x,y,z=p; c,s=cos(angle),sin(angle)
    return (center[0]+c*x-s*y,center[1]+s*x+c*y,GROUND+z)

def _box(name, center, angle, loc, size, mat, bevel=0):
    ob=box(name,_p(center,angle,loc),size,mat,G,bevel=bevel)
    ob.rotation_euler[2]=angle
    return ob

def _tube(name, center, angle, points, radii, mat, sides=8):
    return tube(name,[_p(center,angle,p) for p in points],radii,mat,G,sides=sides)

def _mesh(name,center,angle,verts,faces,mat):
    return mesh(name,[_p(center,angle,v) for v in verts],faces,mat,G)

def _cyl(name,center,angle,loc,radius,depth,mat,n=24):
    return cylinder(name,_p(center,angle,loc),radius,depth,mat,G,vertices=n)

def _ring(name,center,angle,loc,outer,inner,depth,mat,n=48):
    return ring(name,_p(center,angle,loc),outer,inner,depth,mat,G,segments=n)

def _text(name,body,center,angle,loc,size,mat):
    return text(name,body,_p(center,angle,loc),size,mat,G,rotation=(pi/2,0,angle))

def _plate(name,center,angle,outline,depth,mat):
    verts=list(outline)+[(x,y+depth,z) for x,y,z in outline]
    n=len(outline);faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    return _mesh(name,center,angle,verts,faces,mat)

def _gem(name,center,angle,loc,width,height,mat):
    x,y,z=loc
    verts=[(x-width,y,z),(x,y-width*.75,z),(x+width,y,z),(x,y+width*.75,z),(x,y,z+height),(x,y,z-height*.35)]
    return _mesh(name,center,angle,verts,[(i,(i+1)%4,4) for i in range(4)]+[(i,5,(i+1)%4) for i in range(4)],mat)

def _arc(name,center,angle,width,height,y,z0,mat,radius=.075):
    pts=[]
    for i in range(33):
        a=pi*i/32
        pts.append((width*cos(a),y,z0+height*sin(a)))
    return _tube(name,center,angle,pts,[radius]*len(pts),mat,6)

def _lantern(name,center,angle,x,y,z,accent='goldGlow',scale=1):
    _cyl(name+'_foot',center,angle,(x,y,z+.12*scale),.65*scale,.24*scale,'stoneDark',12)
    _cyl(name+'_stem',center,angle,(x,y,z+1.25*scale),.17*scale,2.2*scale,'gold',12)
    _box(name+'_housing',center,angle,(x,y,z+2.25*scale),(.87*scale,.87*scale,1.08*scale),'wood',.06)
    _box(name+'_lamp',center,angle,(x,y-.453*scale,z+2.25*scale),(.6*scale,.035,.74*scale),accent)
    _box(name+'_rear_lamp',center,angle,(x,y+.453*scale,z+2.25*scale),(.6*scale,.035,.74*scale),accent)
    _cyl(name+'_cap',center,angle,(x,y,z+2.92*scale),.79*scale,.23*scale,'roof',4)
    _gem(name+'_finial',center,angle,(x,y,z+3.10*scale),.16*scale,.3*scale,'gold')

def _torii(name,center,angle,accent):
    # Main opening is 11 wide and 11.8 high; VFX stays around the edges.
    for n,(w,d,z) in enumerate([(20.4,13.3,.18),(19.2,12.3,.42),(18,11.3,.69)]):
        _box(name+'_stair_'+str(n),center,angle,(0,0,z),(w,d,.25),'stoneLight' if n!=1 else 'stone',.06)
    _box(name+'_floor',center,angle,(0,0,.92),(16.8,10.4,.22),'stoneDark',.05)
    for x in (-7.9,7.9):
        _box(name+'_floor_gold',center,angle,(x,0,1.05),(.095,9.7,.025),'gold')
    for y in (-4.7,4.7):
        _box(name+'_floor_gold',center,angle,(0,y,1.05),(15.7,.095,.025),'gold')
    for side in (-1,1):
        x=side*6.6
        _cyl(name+'_stone_socket',center,angle,(x,0,1.25),1.27,.62,'stone',12)
        _cyl(name+'_socket_rim',center,angle,(x,0,1.57),1.08,.16,'gold',16)
        _cyl(name+'_vermilion_pillar',center,angle,(x,0,7.75),.62,12.3,'red',20)
        _cyl(name+'_pillar_crown',center,angle,(x,0,13.86),.74,.4,'black',16)
        for z in (2.2,11.7,13.0):
            _cyl(name+'_pillar_collar',center,angle,(x,0,z),.68,.16,'gold',20)
        _box(name+'_base_symbol',center,angle,(x,-.656,3.03),(.35,.08,1.18),'gold',.025)
        _tube(name+'_energy_edge',center,angle,[(side*5.63,-.12,1.18),(side*5.63,-.12,11.7),(side*4.75,-.12,12.72)],[.085]*3,accent,6)
        # Braced outer rafters never cross the opening.
        _tube(name+'_outer_brace',center,angle,[(x,0,11.5),(side*8.25,0,13.6)],[.22,.18],'wood',8)
    _box(name+'_lower_tie',center,angle,(0,0,12.7),(15.4,.74,.47),'red',.06)
    _box(name+'_lower_tie_gold',center,angle,(0,-.405,12.76),(14.85,.06,.11),'gold')
    _plate(name+'_curved_lintel',center,angle,[
        (-8.9,-.56,14.86),(-7.8,-.56,14.2),(-4,-.56,13.8),(4,-.56,13.8),(7.8,-.56,14.2),(8.9,-.56,14.86),
        (8.54,-.56,15.49),(7.62,-.56,15.01),(4,-.56,14.6),(-4,-.56,14.6),(-7.62,-.56,15.01),(-8.54,-.56,15.49)],1.12,'red')
    _tube(name+'_roof_ridge',center,angle,[(-9.12,0,15.52),(-7.82,0,15.05),(-4,0,14.79),(0,0,14.75),(4,0,14.79),(7.82,0,15.05),(9.12,0,15.52)],[.25]*7,'roof',10)
    _tube(name+'_roof_gilt',center,angle,[(-9.12,-.57,15.39),(-7.82,-.57,14.92),(-4,-.57,14.66),(0,-.57,14.62),(4,-.57,14.66),(7.82,-.57,14.92),(9.12,-.57,15.39)],[.055]*7,'gold',6)
    _box(name+'_hanging_cartouche',center,angle,(0,-.74,13.81),(6.65,.36,1.55),'roof',.08)
    _box(name+'_cartouche_border',center,angle,(0,-.953,14.51),(6.3,.06,.055),'gold')
    _box(name+'_cartouche_border',center,angle,(0,-.953,13.1),(6.3,.06,.055),'gold')
    _text(name+'_title','ARENA TRAVEL',center,angle,(0,-.958,13.81),.65,'ivory')
    _arc(name+'_energy_arch',center,angle,5.6,5.0,-.10,7.56,accent,.055)
    for side in (-1,1):
        for j in range(5):
            _gem(name+'_edge_spark',center,angle,(side*(5.45+.22*sin(j)),.1,3+j*1.7),.105,.25,accent)
        _lantern(name+'_lantern_'+str(side),center,angle,side*8.25,-3.25,1.07,accent,.9)
    # Small ofuda pendants decorate the lintel without obstructing the opening.
    rope=[(-5.7,-.52,12.44),(-3,-.58,12.17),(0,-.62,12.08),(3,-.58,12.17),(5.7,-.52,12.44)]
    _tube(name+'_sacred_rope',center,angle,rope,[.07]*5,'gold',6)
    for j,x in enumerate((-4.6,-2.3,0,2.3,4.6)):
        z=11.64+.10*abs(x)
        _box(name+'_ofuda_'+str(j),center,angle,(x,-.64,z),(.37,.035,.72),'ivory')
        _box(name+'_ofuda_glyph_'+str(j),center,angle,(x,-.666,z),(.085,.022,.43),'purple')
    _gem(name+'_crown_core',center,angle,(0,0,16.3),.46,1.08,accent)
    for side in (-1,1):
        _tube(name+'_crown_wing',center,angle,[(side*.6,0,16.1),(side*1.35,0,16.43),(side*2.05,0,16.89)],[.13,.16,.04],'gold',6)

def _hourglass(name,center,angle,x,y,z):
    for zz in (z,z+2.3):
        _cyl(name+'_rim',center,angle,(x,y,zz),.63,.17,'gold',20)
    for side in (-1,1):
        _tube(name+'_glass',center,angle,[(x,y,z+1.15),(x,y,z+1.15+side*.86)],[.12,.54],'glass',16)
    _tube(name+'_sand',center,angle,[(x,y,z+.22),(x,y,z+1.08),(x,y,z+2.02)],[.38,.05,.35],'goldGlow',12)

def _theme(name,theme,center,angle):
    # Small environmental glyphs, never character sculptures.
    x=3.25; y=.18; z=.96
    _cyl(name+'_glyph_base',center,angle,(x,y,z),1.0,.31,'stoneDark',12)
    if theme=='sun':
        _gem(name+'_sun',center,angle,(x,y,z+1.65),.70,.75,'goldGlow')
        for i in range(8):
            a=i*pi/4
            _tube(name+'_sun_ray',center,angle,[(x+.92*cos(a),y,z+1.65+.92*sin(a)),(x+1.16*cos(a),y,z+1.65+1.16*sin(a))],[.055,.02],'gold',5)
    elif theme=='sand':
        for i in range(4):
            ico(name+'_sand_rock',_p(center,angle,(x+.32*cos(i*2.1),y+.22*sin(i),z+.24+i*.27)),(.70-i*.1,.53-i*.05,.38),'stoneLight',G,1)
        _gem(name+'_sand_seal',center,angle,(x,y-.5,z+1.12),.24,.5,'gold')
    elif theme=='harbor':
        _tube(name+'_mast',center,angle,[(x,y,z+.2),(x,y,z+2.9)],[.06,.05],'wood',7)
        _mesh(name+'_sail',center,angle,[(x-.07,y,z+2.6),(x-1.05,y,z+.9),(x-.07,y,z+.9)],[(0,1,2)],'ivory')
        _mesh(name+'_sail_gold',center,angle,[(x+.1,y,z+2.5),(x+.86,y,z+1.24),(x+.1,y,z+1.24)],[(0,1,2)],'gold')
        _tube(name+'_wave',center,angle,[(x-1.1,y-.15,z+.3),(x-.5,y-.15,z+.48),(x,y-.15,z+.3),(x+.5,y-.15,z+.48),(x+1.1,y-.15,z+.3)],[.065]*5,'cyanGlow',6)
    elif theme=='shrine':
        _tube(name+'_shrine_frame',center,angle,[(x-.72,y,z+.2),(x-.72,y,z+2.45),(x+.72,y,z+2.45),(x+.72,y,z+.2)],[.11]*4,'red',8)
        for xx in (-.46,0,.46):
            _box(name+'_paper_charm',center,angle,(x+xx,y-.12,z+1.68),(.23,.045,.93),'ivory')
            _box(name+'_paper_rune',center,angle,(x+xx,y-.155,z+1.68),(.06,.025,.64),'purpleGlow')
    elif theme=='wisteria':
        _tube(name+'_wisteria_branch',center,angle,[(x,y,z),(x+.15,y,z+1.8),(x-.38,y,z+2.8),(x+.8,y,z+2.9)],[.20,.14,.075,.015],'wood',8)
        for j in range(8):
            xx=x-.76+j*.22; top=z+2.72+.15*sin(j)
            for k in range(4):
                ico(name+'_wisteria_drop',_p(center,angle,(xx,y-.08,top-k*.22)),(.18-k*.025,.15,.22),'purpleGlow' if k==0 else 'purple',G,1)
    elif theme=='arena':
        _box(name+'_ring_miniature',center,angle,(x,y,z+.35),(1.67,1.67,.37),'ivory',.04)
        for xx in (-.65,.65):
            for yy in (-.65,.65):
                _cyl(name+'_ring_post',center,angle,(x+xx,y+yy,z+.76),.065,.49,'gold',8)
        for k in (-.4,0,.4):
            _box(name+'_ring_tile',center,angle,(x+k,y,z+.555),(.022,1.55,.008),'stoneDark')
            _box(name+'_ring_tile',center,angle,(x,y+k,z+.555),(1.55,.022,.008),'stoneDark')
    elif theme=='hourglass':
        _hourglass(name,center,angle,x,y,z+.2)
    elif theme=='capital':
        for i in range(7):
            a=-.1+i*pi/7
            _tube(name+'_fan_ray',center,angle,[(x,y,z+.45),(x+1.14*cos(a),y,z+.45+1.8*sin(a))],[.035,.055],'gold',6)
        _tube(name+'_fan_silk',center,angle,[(x+cos(pi*j/24),y,z+.45+1.6*sin(pi*j/24)) for j in range(25)],[.15]*25,'red',7)
    elif theme=='ice':
        for i,(dx,dy,h) in enumerate([(-.55,.14,1.4),(0,.2,2.7),(.51,-.13,1.7),(-.05,-.48,1.15)]):
            _gem(name+'_ice_'+str(i),center,angle,(x+dx,y+dy,z+.3),.33,h,'cyan' if i%2 else 'ivory')

def _station(number,title,arena_id,theme,center,focus,accent):
    dx=focus[0]-center[0];dy=focus[1]-center[1]
    angle=math.atan2(dx,-dy)
    name='Arena_%02d_%s' % (number,arena_id)
    _cyl(name+'_foundation',center,angle,(0,0,.17),3.8,.26,'stoneDark',32)
    _cyl(name+'_step',center,angle,(0,0,.35),3.45,.2,'stoneLight',32)
    _cyl(name+'_platform',center,angle,(0,0,.55),3.12,.2,'stone',32)
    _ring(name+'_gilt_circle',center,angle,(0,0,.67),2.91,2.82,.025,'gold',48)
    _ring(name+'_arrival_sigils',center,angle,(0,0,.70),1.61,1.50,.025,accent,48)
    for side in (-1,1):
        _cyl(name+'_arch_foot',center,angle,(side*2.38,.43,.85),.59,.45,'stoneDark',12)
        _cyl(name+'_arch_post',center,angle,(side*2.38,.43,3.25),.20,4.95,'red',12)
        for z in (1.26,5.45):
            _cyl(name+'_arch_band',center,angle,(side*2.38,.43,z),.24,.12,'gold',12)
    _tube(name+'_lintel',center,angle,[(-3.1,.43,6.06),(-2.65,.43,5.84),(0,.43,5.63),(2.65,.43,5.84),(3.1,.43,6.06)],[.23]*5,'red',8)
    _tube(name+'_roof_gilt',center,angle,[(-3.17,.43,6.19),(-2.65,.43,5.97),(0,.43,5.76),(2.65,.43,5.97),(3.17,.43,6.19)],[.07]*5,'gold',6)
    _arc(name+'_light_outline',center,angle,1.89,2.6,.47,2.5,accent,.055)
    for side in (-1,1):
        _tube(name+'_light_upright',center,angle,[(side*1.89,.47,.74),(side*1.89,.47,2.5)],[.055,.055],accent,6)
    _box(name+'_name_sign',center,angle,(0,-2.86,1.8),(6.72,.24,1.51),'roof',.065)
    _box(name+'_sign_top',center,angle,(0,-3.012,2.52),(6.4,.028,.04),'gold')
    _text(name+'_name',title.upper(),center,angle,(0,-3.014,1.92),.48 if len(title)>13 else .57,'ivory')
    _text(name+'_number','ARENA %02d' % number,center,angle,(0,-3.018,1.31),.28,accent)
    # Low floor labels are deliberately outside the traversable portal opening.
    _theme(name,theme,center,angle)
    _gem(name+'_hover_rune',center,angle,(0,.48,4.64),.17,.40,accent)
    for j in range(3):
        _gem(name+'_rune_mote',center,angle,(-1.47+j*1.47,.50,1.14+.20*j),.06,.12,accent)
    marker('PORTAL_%02d_%s' % (number,arena_id),_p(center,angle,(0,0,.84)),'Teleport:'+arena_id)

def build():
    random.seed(606)
    # Clipped western boundary respects the separate merchant street.
    boundary=[(191,-78),(195,-66),(211,-55),(236,-58),(251,-70),(258,-92),(250,-118),(231,-139),(212,-140),(198,-124),(197,-96)]
    verts=[(x,y,GROUND+.07) for x,y in boundary]
    mesh('Arena_Promenade_Paving',verts,[tuple(range(len(verts)))],'stone',G)
    tube('Arena_Promenade_Curb',[(x,y,GROUND+.23) for x,y in boundary+[boundary[0]]],[.19]*(len(boundary)+1),'stoneLight',G,sides=8)
    tube('Arena_Promenade_Gold_Inlay',[(x*.998+.43,y*.998-.2,GROUND+.35) for x,y in boundary+[boundary[0]]],[.038]*(len(boundary)+1),'gold',G,sides=5)
    # A broad open central approach runs northeast from the hub.
    mesh('Arena_Promenade_Entry',[(184,-82,1.29),(196,-75,1.29),(216,-92,1.29),(207,-104,1.29)],[(0,1,2,3)],'stoneLight',G)
    for t in range(9):
        yy=-85-t*4
        box('Promenade_Edge_Tile',(196.7+.015*t,yy,1.34),(1.0,1.8,.12),'stoneDark',G,bevel=.02)
    centers=[((209,-66),-.13*pi,'goldGlow'),((238,-74),-.50*pi,'purpleGlow'),
             ((244,-101),-.50*pi,'cyanGlow'),((224,-126),-.99*pi,'goldGlow')]
    for i,(center,angle,accent) in enumerate(centers):
        _torii('Grand_Arena_Torii_%02d' % (i+1),center,angle,accent)
    # Nine small world portals surround one legible shared promenade.
    stations=[
        ('Tenkaichi','Tenkaichi','sun',(201,-81),'goldGlow'),
        ('Chunin Exam','ChuninExamHall','sand',(201,-93),'goldGlow'),
        ('Loguetown','Loguetown','harbor',(202,-105),'cyanGlow'),
        ('Jujutsu High','JujutsuHigh','shrine',(205,-117),'purpleGlow'),
        ('Fujikasane','Fujikasane','wisteria',(216,-112),'purpleGlow'),
        ('Heavens Arena','HeavensArena','arena',(229,-115),'cyanGlow'),
        ('Time Chamber','HyperbolicTimeChamber','hourglass',(226,-101),'goldGlow'),
        ('Wano','Wano','capital',(230,-88),'goldGlow'),
        ('Marineford','Marineford','ice',(219,-80),'cyanGlow')]
    for i,(title,arena_id,theme,center,accent) in enumerate(stations):
        _station(i+1,title,arena_id,theme,center,(214,-99),accent)
    # The central compass stays low and leaves the arrival path open.
    ring('Arena_Travel_Compass',(215,-100,1.37),5.4,5.2,.035,'gold',G,segments=80)
    ring('Arena_Travel_Compass_Inner',(215,-100,1.37),3.2,3.13,.035,'cyanGlow',G,segments=64)
    for i in range(8):
        a=i*pi/4
        tube('Compass_Ray',[(215+3.6*cos(a),-100+3.6*sin(a),1.38),(215+4.8*cos(a),-100+4.8*sin(a),1.38)],[.06,.02],'gold',G,sides=5)
    # Sculpted rocks and night lanterns cluster on the outer boundary.
    for i,(x,y) in enumerate([(194,-72),(231,-58),(252,-85),(247,-113),(229,-136),(210,-135)]):
        ico('Portal_Garden_Rock',(x,y,2.03),(1.8,1.4,1.05),'rock',G,1)
        ico('Portal_Garden_Moss',(x+.3,y+.1,2.84),(1.4,1.12,.27),'moss',G,1)
        for j in range(3):
            a=j*2.1+i
            ico('Portal_Garden_Accent',(x+1.35*cos(a),y+1.03*sin(a),1.48),(.68,.55,.42),'leaf',G,1)
        _lantern('Promenade_Lantern_%02d' % i,(x+1.7,y),0,0,0,.3,'goldGlow',.76)
    marker('ARRIVAL_Arena_Promenade',(191,-81,1.7),'DistrictArrival:ArenaPortals')
