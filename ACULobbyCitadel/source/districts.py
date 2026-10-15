from common import *

def _mat(name):
    value = globals().get(name)
    if isinstance(value, bpy.types.Material):
        return value
    if 'MATS' in globals():
        return MATS.get(name, name)
    if 'mats' in globals():
        return mats.get(name, name)
    return name

def B(name, loc, size, material, group, bevel=0):
    return box(name, loc, size, _mat(material), group, bevel=bevel)

def C(name, loc, radius, depth, material, group, vertices=24):
    return cylinder(name, loc, radius, depth, _mat(material), group, vertices=vertices)

def T(name, points, radii, material, group, sides=8):
    return tube(name, points, radii, _mat(material), group, sides=sides)

def R(name, loc, outer, inner, depth, material, group, segments=48):
    return ring(name, loc, outer, inner, depth, _mat(material), group, segments=segments)

def I(name, loc, scale, material, group, subdivisions=1):
    return ico(name, loc, scale, _mat(material), group, subdivisions=subdivisions)

def X(name, body, loc, size, material, group, rotation=(pi/2, 0, 0)):
    return text(name, body, loc, size, _mat(material), group, rotation=rotation)

def _roof(name, center, width, depth, rise, group, material='roof', uplift=1.6):
    cx, cy, z = center
    nx, ny = max(8, int(width/2)), 12
    verts, faces = [], []
    def level(x, y):
        u, v = abs(x)/(width/2), abs(y)/(depth/2)
        return z + rise*(1-v) + uplift*u**7 + .75*v**6
    for layer in (0, -.35):
        for j in range(ny+1):
            y = -depth/2 + depth*j/ny
            for i in range(nx+1):
                x = -width/2 + width*i/nx
                verts.append((cx+x, cy+y, level(x,y)+layer))
    stride, count = nx+1, (nx+1)*(ny+1)
    for j in range(ny):
        for i in range(nx):
            a=j*stride+i
            faces.append((a,a+1,a+1+stride,a+stride))
            faces.append((a+count,a+stride+count,a+stride+1+count,a+1+count))
    for j in (0,ny):
        for i in range(nx):
            a=j*stride+i
            faces.append((a,a+count,a+1+count,a+1))
    for i in (0,nx):
        for j in range(ny):
            a=j*stride+i
            faces.append((a,a+stride,a+stride+count,a+count))
    mesh(name+'_curved_tiles', verts, faces, _mat(material), group)
    for side in (-1,1):
        yy=side*depth/2
        pts=[(cx+x,cy+yy,level(x,yy)+.04) for x in [(-width/2+width*i/24) for i in range(25)]]
        T(name+'_eave_gold',pts,[.13]*len(pts),'gold',group)
    for xsign in (-1,1):
        xx=xsign*width/2
        pts=[(cx+xx,cy+y,level(xx,y)+.02) for y in [(-depth/2+depth*i/20) for i in range(21)]]
        T(name+'_gable_border',pts,[.17]*len(pts),'gold',group)
    for i in range(max(7,int(width/1.6))+1):
        xx=-width/2+width*i/max(7,int(width/1.6))
        for sign in (-1,1):
            pts=[]
            for j in range(7):
                yy=sign*(depth/2)*j/6
                pts.append((cx+xx,cy+yy,level(xx,yy)+.08))
            T(name+'_tile_rib',pts,[.075]*7,'stoneDark',group,sides=6)
    T(name+'_ridge',[(cx-width/2-.5,cy,z+rise+uplift),(cx-width*.34,cy,z+rise+.28),(cx,cy,z+rise+.25),(cx+width*.34,cy,z+rise+.28),(cx+width/2+.5,cy,z+rise+uplift)],[.22]*5,'gold',group)
    for side in (-1,1):
        xx=cx+side*(width/2-.6)
        T(name+'_ridge_finial',[(xx,cy,z+rise+uplift-.4),(xx+side*.8,cy,z+rise+uplift+.7),(xx+side*.95,cy,z+rise+uplift+1.9)],[.28,.2,.035],'goldLight',group)

def _post(name, x, y, bottom, top, group, material='wood', radius=.65):
    C(name+'_base',(x,y,bottom+.3),radius*1.65,.6,'stoneLight',group)
    C(name+'_shaft',(x,y,(bottom+top)/2),radius,top-bottom,material,group)
    for z in (bottom+.8, top-1.2, top-.3):
        C(name+'_binding',(x,y,z),radius*1.1,.2,'gold',group)
    B(name+'_capital',(x,y,top),(radius*4,radius*3.4,.45),'red',group,bevel=.08)
    for s in (-1,1):
        B(name+'_bracket',(x+s*.9,y,top-.7),(1.6,.7,.38),'gold',group,bevel=.04)
        B(name+'_bracket_small',(x+s*.5,y,top-1.15),(.9,.6,.32),'wood',group,bevel=.04)

def _lantern(name, x, y, z, group, radius=.55, hanging=True):
    C(name+'_luminous_body',(x,y,z),radius,1.15,'goldGlow',group,vertices=12)
    for dz in (-.62,.62):
        C(name+'_cap',(x,y,z+dz),radius*1.13,.12,'wood',group,vertices=12)
    for i in range(8):
        a=2*pi*i/8
        T(name+'_cage',[(x+radius*cos(a),y+radius*sin(a),z-.59),(x+radius*cos(a),y+radius*sin(a),z+.59)],[.035,.035],'red',group,sides=5)
    if hanging:
        T(name+'_suspension',[(x,y,z+.7),(x,y,z+1.8)],[.025,.025],'gold',group,sides=5)
        T(name+'_tassel',[(x,y,z-.66),(x,y,z-1.12)],[.06,.025],'red',group,sides=5)

def _hologram(name, x, y, z, scale, group, material='holo'):
    I(name+'_head',(x,y,z+5.7*scale),(.62*scale,.55*scale,.69*scale),material,group,subdivisions=2)
    B(name+'_chest',(x,y,z+4.05*scale),(1.7*scale,.87*scale,1.8*scale),material,group,bevel=.14*scale)
    B(name+'_belt',(x,y,z+3.05*scale),(1.5*scale,.85*scale,.32*scale),'goldGlow',group)
    for s in (-1,1):
        T(name+'_arm',[(x+s*.92*scale,y,z+4.65*scale),(x+s*1.25*scale,y-.12*scale,z+3.9*scale),(x+s*1.45*scale,y-.35*scale,z+3.3*scale)],[.32*scale,.27*scale,.18*scale],material,group)
        T(name+'_leg',[(x+s*.45*scale,y,z+2.95*scale),(x+s*.57*scale,y,z+1.6*scale),(x+s*.65*scale,y-.28*scale,z+.3*scale)],[.35*scale,.29*scale,.25*scale],material,group)
        B(name+'_foot',(x+s*.65*scale,y-.48*scale,z+.18*scale),(.55*scale,.9*scale,.3*scale),material,group,bevel=.07)
    T(name+'_katana',[(x+1.5*scale,y-.4*scale,z+3.4*scale),(x+2.7*scale,y-.4*scale,z+6.7*scale)],[.065*scale,.015*scale],'cyanGlow',group)
    for zz in (1.3,3.6,5.2):
        R(name+'_scanline',(x,y,z+zz*scale),2.1*scale,2.06*scale,.045,'cyanGlow',group,segments=32)

def _portal(name, x, y, z, width, height, group, material='cyanGlow'):
    pts=[]
    for i in range(49):
        a=2*pi*i/48
        pts.append((x+width/2*cos(a),y,z+height/2*sin(a)))
    T(name+'_energy_rim',pts,[.11]*len(pts),material,group,sides=8)
    pts2=[(xx*0+ (x+(xx-x)*.9),yy+.22,z+(zz-z)*.93) for xx,yy,zz in pts]
    T(name+'_inner_rim',pts2,[.045]*len(pts2),material,group,sides=6)
    for s in (-1,1):
        for j in range(3):
            I(name+'_orbit_shard',(x+s*(width*.53+j*.15),y,z+(j-1)*height*.23),(.25,.21,.8),material,group)

def _floor_circuit(name, width, depth, group, color='cyanGlow'):
    for sign in (-1,1):
        x=sign*(width/2-1.1)
        T(name+'_inlay',[(x,-depth/2+1.1,1.225),(x,-depth*.2,1.225),(x-sign*2,-depth*.1,1.225),(x-sign*2,depth/2-1.1,1.225)],[.07]*4,color,group,sides=5)

def _sign(name, title, x, y, z, width, group, material='goldGlow', size=1.4):
    B(name+'_back',(x,y+.05,z),(width,.38,2.6),'stoneDark',group,bevel=.18)
    B(name+'_top',(x,y-.2,z+1.22),(width+.18,.16,.10),'gold',group)
    B(name+'_bottom',(x,y-.2,z-1.22),(width+.18,.16,.10),'gold',group)
    X(name+'_lettering',title,(x,y-.19,z-.47),size,material,group)

def _story():
    g='30_StoryGate'
    B('STORY_gate_platform',(0,0,.95),(45,20,.5),'stoneLight',g,bevel=.25)
    for x in (-20,20):
        B('STORY_side_mosaic',(x,0,1.23),(3.2,15,.05),'purple',g)
    for x in (-14,14):
        _post('STORY_main_pillar',x,0,1.2,23,g,'red',radius=1.23)
        B('STORY_pillar_front_gold',(x,-1.22,10.5),(.16,.06,13),'gold',g)
        B('STORY_pillar_back_gold',(x,1.22,10.5),(.16,.06,13),'gold',g)
        _post('STORY_secondary_pillar',x,6,1.2,21,g,'wood',radius=.7)
        B('STORY_depth_brace',(x,3,20),(1.1,10,.9),'red',g)
        for y in (-4.8,4.8):
            _lantern('STORY_celestial_lantern',x,y,20.2,g,.8)
    B('STORY_lintel',(0,0,22.4),(36,2.2,1.35),'red',g,bevel=.15)
    B('STORY_lintel_gold',(0,-1.15,22.4),(35,.13,.20),'gold',g)
    B('STORY_secondary_lintel',(0,6,21),(35,1.4,.8),'wood',g)
    _roof('STORY_grand_roof',(0,2.3,23.5),42,17,5.0,g,uplift=2.3)
    _roof('STORY_lower_cornice',(0,.5,19.4),34,8,1.45,g,uplift=1.1)
    _portal('STORY_interverse_aperture',0,4,12.9,21,22,g,'purpleGlow')
    for x in (-19,19):
        C('STORY_side_obelisk_base',(x,-4,1.7),2,.95,'stoneDark',g,vertices=8)
        I('STORY_side_obelisk_crystal',(x,-4,4.15),(1.0,1.0,2.25),'purpleGlow',g)
        R('STORY_obelisk_orbit',(x,-4,3.6),1.7,1.58,.10,'gold',g)
    _sign('STORY_header','STORY',0,-3.6,22.45,14,g,'goldGlow',2.2)
    X('STORY_subtitle','WORLDS BEYOND',(0,-4.05,19.05),.78,'ivory',g)
    _floor_circuit('STORY_route',25,18,g,'purpleGlow')
    transform_group(g,(0,68,0),0)
    marker('PORTAL_Story',(0,66,1.2),'teleport_story')
    marker('SPAWN_Story_Return',(0,53,1.2),'return_story')

def _summon():
    g='31_SummonHall'
    B('SUMMON_foundation',(0,0,.85),(35,29,.7),'stoneLight',g,bevel=.3)
    B('SUMMON_floor',(0,0,1.19),(31,25,.04),'stoneDark',g)
    B('SUMMON_backwall',(0,11.5,7),(29,.8,11.6),'wood',g,bevel=.08)
    B('SUMMON_backwall_inset',(0,10.98,7.5),(26,.12,8.5),'purple',g)
    for x in range(-12,13,3):
        B('SUMMON_lattice_upright',(x,10.85,7.5),(.13,.16,8.6),'gold',g)
    for z in (4,6.4,8.8,11.2):
        B('SUMMON_lattice_transom',(0,10.85,z),(26,.16,.12),'gold',g)
    for x in (-13.5,13.5):
        for y in (-9.5,1,10):
            _post('SUMMON_structural_post',x,y,1.2,14.1,g,'wood',radius=.58)
        B('SUMMON_outer_frieze',(x,1,12.7),(.65,25,1),'red',g)
        B('SUMMON_lower_screen',(x,5,3.25),(.35,11,4),'ivory',g)
        for y in (0,2.2,4.4,6.6,8.8):
            B('SUMMON_screen_lattice',(x-.2,y,4),(.14,.11,4.5),'wood',g)
    for y in (-9.5,10):
        B('SUMMON_main_frieze',(0,y,13.4),(31,1.1,1.0),'red',g)
        B('SUMMON_frieze_gilt',(0,y-.58,13.4),(30,.10,.12),'gold',g)
    _roof('SUMMON_main_roof',(0,1,14.0),36,30,4.6,g,uplift=1.8)
    _roof('SUMMON_upper_crown',(0,2,20.0),20,14,3.5,g,uplift=1.25)
    B('SUMMON_upper_drum',(0,2,18.4),(16,9,3.2),'wood',g)
    for x in (-6,-3,0,3,6):
        B('SUMMON_upper_window',(x,-2.55,18.5),(1.7,.10,1.9),'cyanGlow',g)
    _sign('SUMMON_marquee','SUMMON',0,-12.6,13.7,20,g,'cyanGlow',2.0)
    X('SUMMON_legend','DISCOVER YOUR NEXT LEGEND',(0,-12.86,11.55),.60,'ivory',g)
    for i,x in enumerate((-8,0,8)):
        C('SUMMON_capsule_plinth',(x,3,1.64),3.05,.85,'stoneDark',g,vertices=32)
        R('SUMMON_capsule_foot_light',(x,3,2.1),2.8,2.65,.14,'cyanGlow',g)
        capsule_verts=[]
        for zz in (2.17,10.07):
            for n in range(17):
                a=pi*n/16
                capsule_verts.append((x+2.53*cos(a),3+2.53*sin(a),zz))
        capsule_faces=[(n,n+1,n+18,n+17) for n in range(16)]
        mesh('SUMMON_capsule_glazed_rear',capsule_verts,capsule_faces,_mat('glass'),g)
        for side in (-1,1):
            T('SUMMON_capsule_open_edge',[(x+side*2.53,3,2.17),(x+side*2.53,3,10.07)],[.065,.065],'cyanGlow',g)
        R('SUMMON_capsule_crown',(x,3,10.15),2.95,2.55,.35,'gold',g)
        R('SUMMON_capsule_crown_light',(x,3,9.85),2.73,2.6,.12,'cyanGlow',g)
        for a in (0,2*pi/3,4*pi/3):
            T('SUMMON_capsule_rib',[(x+2.8*cos(a),3+2.8*sin(a),2.25),(x+2.8*cos(a),3+2.8*sin(a),9.98)],[.08,.08],'gold',g)
        _hologram('SUMMON_unit_'+str(i+1),x,3,2.4,1.04,g)
    for x in (-13.5,13.5):
        _lantern('SUMMON_welcome_lamp',x,-10.2,10.5,g)
    _floor_circuit('SUMMON_floor',31,25,g)
    for x in (-8,0,8):
        B('SUMMON_selection_console',(x,-6,2.8),(4,1.6,2.8),'stoneDark',g,bevel=.18)
        B('SUMMON_console_screen',(x,-6.86,3.1),(3.2,.10,1.2),'cyanGlow',g)
    transform_group(g,(67,8,0),-pi/2)
    marker('INTERACT_Summon',(57,8,1.2),'summon_packs')
    marker('SPAWN_Summon',(49,8,1.2),'travel_summon')

def _ranked():
    g='32_RankedHall'
    B('RANKED_dais',(0,0,.95),(33,29,.5),'stoneLight',g,bevel=.25)
    B('RANKED_inset_floor',(0,0,1.22),(29,25,.035),'stoneDark',g)
    for x in (-14,0,14):
        _post('RANKED_column',x,1,1.2,15,g,'red',radius=.7)
        _post('RANKED_rear_column',x,9,1.2,15,g,'wood',radius=.5)
    B('RANKED_beam',(0,1,14.4),(33,1.6,1.1),'red',g,bevel=.13)
    B('RANKED_beam_trim',(0,.14,14.2),(32,.10,.18),'gold',g)
    _roof('RANKED_ceremonial_roof',(0,4.5,15.0),36,21,4.7,g,uplift=2.0)
    _roof('RANKED_canopy',(0,-4,11.6),30,9,1.9,g,uplift=1.0)
    for x, title, color in ((-7,'RANKED','goldGlow'),(7,'UNRANKED','cyanGlow')):
        _portal('PVP_'+title,x,6,7.25,10.7,11.3,g,color)
        B('PVP_'+title+'_threshold',(x,4,1.26),(11,4,.12),color,g,bevel=.12)
        _sign('PVP_'+title+'_sign',title,x,-4.5,11.25,12,g,color,1.15 if title=='RANKED' else .92)
        C('PVP_'+title+'_crest_plinth',(x,-7,1.57),2.25,.6,'stoneDark',g,vertices=12)
        R('PVP_'+title+'_crest',(x,-7,1.90),1.75,1.52,.07,color,g,segments=32)
        for j in range(3):
            h=.7+(1-abs(j-1))*.6
            B('PVP_'+title+'_crest_bar',(x+(j-1)*.5,-7,2+h/2),(.28,.3,h),'gold',g,bevel=.04)
    for x in (-14,14):
        _lantern('RANKED_gate_lantern',x,-2,10.3,g,.72)
    X('PVP_subtitle','YOUR TEAM. YOUR LEGACY.',(0,-7.15,5.45),.62,'goldLight',g)
    _floor_circuit('RANKED_floor',30,26,g,'goldGlow')
    transform_group(g,(-66,12,0),pi/2)
    marker('PORTAL_Ranked',(-72,5,1.2),'teleport_ranked')
    marker('PORTAL_Unranked',(-72,19,1.2),'teleport_unranked')
    marker('SPAWN_PvP_Return',(-47,12,1.2),'return_pvp')

def _board(name,x,y,z,title,group):
    B(name+'_body',(x,y,z),(10.4,.75,12.4),'wood',group,bevel=.15)
    B(name+'_face',(x,y-.41,z),(9.35,.06,10.95),'stoneDark',group)
    for xx in (-5.0,5.0):
        B(name+'_side_gilt',(x+xx,y-.43,z),(.10,.10,12.1),'gold',group)
    for zz in (-5.95,5.95):
        B(name+'_gilt',(x,y-.45,z+zz),(10.0,.10,.10),'gold',group)
    X(name+'_title',title,(x,y-.48,z+4.1),.63,'goldGlow',group)
    for i in range(5):
        zz=z+2.5-i*1.7
        B(name+'_row',(x,y-.475,zz),(8.65,.025,1.22),'purple',group)
        X(name+'_number',str(i+1).zfill(2),(x-3.6,y-.51,zz-.2),.43,'goldLight',group)
        B(name+'_dynamic_name_placeholder',(x-.6,y-.503,zz+.05),(4.6,.016,.08),'stoneLight',group)
        B(name+'_dynamic_score_placeholder',(x+3,y-.505,zz+.05),(1.0,.016,.10),'cyan',group)
    _roof(name+'_cap',(x,y,z+6.5),11.9,4.0,1.0,group,uplift=.65)

def _champions():
    g='33_Champions'
    B('CHAMPIONS_terrace',(0,0,.9),(40,31,.6),'stoneLight',g,bevel=.25)
    B('CHAMPIONS_inlay',(0,-3,1.225),(37,20,.03),'stoneDark',g)
    for x in (-17.5,17.5):
        _post('CHAMPIONS_outerpost',x,11.5,1.2,18,g,'wood',radius=.52)
        B('CHAMPIONS_banner',(x,11.35,12.2),(2.7,.11,8.5),'purple',g)
        B('CHAMPIONS_banner_gold',(x,11.27,12.2),(.16,.05,7.5),'gold',g)
        _lantern('CHAMPIONS_lamp',x,-8,4.1,g,.58,False)
        C('CHAMPIONS_lampstand',(x,-8,2.7),.12,2.8,'gold',g)
    for x,title in ((-11.5,'SEASON RANK'),(0,'MOST WINS'),(11.5,'ARENA MASTERY')):
        _board('BOARD_'+title.replace(' ','_'),x,9.5,8.2,title,g)
    for x,number,height in ((-5,2,1.4),(0,1,2.3),(5,3,.9)):
        C('PODIUM_'+str(number),(x,-4,1.2+height/2),2.8,height,'stoneDark',g,vertices=8)
        R('PODIUM_golden_lip',(x,-4,1.2+height),2.79,2.57,.14,'gold',g,segments=32)
        X('PODIUM_position',str(number),(x,-6.61,1.28+height*.24),1.0,'goldGlow',g)
        _hologram('PODIUM_empty_champion_'+str(number),x,-4,1.35+height,.63,g,'holo')
    X('CHAMPIONS_title','HALL OF CHAMPIONS',(0,-11.5,1.28),1.27,'gold',g,rotation=(0,0,0))
    for x in (-14.4,14.4):
        C('STRONGEST_unit_pedestal',(x,-3,1.8),2.5,1.2,'stoneDark',g,vertices=12)
        R('STRONGEST_hologram_emitter',(x,-3,2.44),2.15,1.95,.12,'purpleGlow',g)
        _hologram('STRONGEST_unit_preview',x,-3,2.7,.75,g)
        _sign('STRONGEST_unit_label','FEATURED UNIT',x,-6.0,3.5,8,g,'ivory',.60)
    for x in (-19,19):
        for y in (-12,-5,2,9):
            B('CHAMPIONS_railing_post',(x,y,2.0),(.3,.3,1.6),'wood',g)
        T('CHAMPIONS_rail',[(x,-12,2.7),(x,10,2.7)],[.11,.11],'gold',g)
    transform_group(g,(-58,59,0),0)
    marker('INTERACT_Leaderboards',(-58,46,1.2),'leaderboards')
    marker('DISPLAY_SeasonChampion',(-58,55,3.5),'season_champion')
    marker('DISPLAY_StrongestUnit_A',(-72.4,56,2.4),'strongest_unit')
    marker('DISPLAY_StrongestUnit_B',(-43.6,56,2.4),'strongest_unit')

def _shop():
    g='34_Shop'
    B('SHOP_foundation',(0,0,.95),(28,22,.5),'stoneLight',g,bevel=.2)
    B('SHOP_floor',(0,0,1.22),(24,18,.04),'wood',g)
    B('SHOP_rear_wall',(0,8,6),(23,.55,9.6),'ivory',g)
    for x in (-11,11):
        B('SHOP_side_wall',(x,3,5.7),(.48,10,9),'ivory',g)
        _post('SHOP_frontpost',x,-6.7,1.2,11,g,'red',radius=.42)
        _post('SHOP_backpost',x,7.5,1.2,11,g,'wood',radius=.42)
    for x in (-10,-5,0,5,10):
        B('SHOP_wall_timber',(x,7.65,6),(.24,.15,9.4),'wood',g)
    for z in (3,8):
        B('SHOP_wall_crossbeam',(0,7.6,z),(22,.2,.22),'wood',g)
    _roof('SHOP_teahouse_roof',(0,1,10.8),29,23,4,g,uplift=1.6)
    _roof('SHOP_porch_awning',(0,-6.3,8.3),26,9,1.2,g,uplift=.9)
    _sign('SHOP_ACU','ACU SHOP',0,-10.55,8.4,17,g,'goldGlow',1.55)
    for x in (-8,-4,0,4,8):
        B('SHOP_noren',(x,-9.6,6.85),(3.8,.06,1.7),'purple',g)
        X('SHOP_noren_symbol','A' if x==0 else '•',(x,-9.65,6.38),.76,'goldLight',g)
    B('SHOP_counter',(0,-4,2.8),(20,2.2,3.2),'wood',g,bevel=.1)
    B('SHOP_counter_lip',(0,-4,4.46),(21,2.6,.25),'gold',g,bevel=.08)
    for x in (-7,0,7):
        C('SHOP_item_display_base',(x,-4,4.8),1.65,.36,'stoneDark',g,vertices=12)
        R('SHOP_item_display_light',(x,-4,5.0),1.55,1.4,.07,'purpleGlow',g,segments=32)
        B('SHOP_pack',(x,-4,6.35),(1.8,.75,2.3),'purple',g,bevel=.12)
        B('SHOP_pack_gilt_top',(x,-4.41,7.40),(1.9,.06,.13),'gold',g)
        B('SHOP_pack_gilt_bottom',(x,-4.41,5.3),(1.9,.06,.13),'gold',g)
        X('SHOP_pack_ACU','ACU',(x,-4.45,6.1),.49,'goldLight',g)
    for x in (-8,8):
        for z in (4,6.6,9.2):
            B('SHOP_back_shelf',(x,6.3,z),(4.7,1.9,.18),'wood',g)
            for xx in (-1.3,0,1.3):
                C('SHOP_tea_jar',(x+xx,6.3,z+.5),.32,.8,'ivory',g,vertices=12)
                C('SHOP_tea_lid',(x+xx,6.3,z+.92),.34,.09,'gold',g,vertices=12)
        _lantern('SHOP_porch_lantern',x,-8.2,7.4,g,.53)
    transform_group(g,(63,-48,0),0)
    marker('INTERACT_Shop',(63,-56.5,1.2),'weekly_store')
    marker('NPC_Shopkeeper',(63,-46,1.2),'npc_shop')

def _npc_station(group,name,title,location,accent):
    B(name+'_tile',(0,0,1.19),(7.5,6.7,.12),'stoneLight',group,bevel=.1)
    C(name+'_npc_pedestal',(0,.3,1.49),1.42,.55,'stoneDark',group,vertices=12)
    R(name+'_interaction_light',(0,.3,1.82),1.42,1.3,.08,accent,group,segments=24)
    for x in (-3,3):
        _post(name+'_post',x,1.3,1.2,6.4,group,'wood',radius=.19)
    _roof(name+'_shelter',(0,1.1,6.2),8.3,5.0,1.3,group,uplift=.7)
    _sign(name+'_header',title,0,-1.1,5.6,6.9,group,accent,.60)
    _lantern(name+'_lamp',-2.9,-.3,4.6,group,.3)
    B(name+'_noticeboard',(2.2,-.5,2.9),(1.25,.18,1.65),'wood',group,bevel=.05)
    B(name+'_notice_paper',(2.2,-.61,2.92),(.98,.025,1.38),'ivory',group)
    for z in (2.55,2.85,3.15):
        B(name+'_notice_line',(2.2,-.63,z),(.69,.015,.05),'purple',group)
    transform_group(group,location,0)
    marker(name+'_NPC',(location[0],location[1]+.3,1.82),'npc_'+name.lower())
    marker(name+'_Interaction',(location[0],location[1]-3.8,1.2),'interact_'+name.lower())

def _npcs():
    _npc_station('35_NPCStations_Quest','QUEST_GUIDE','QUEST GUIDE',(-24,-36,0),'goldGlow')
    _npc_station('35_NPCStations_Mastery','MASTERY','MASTERY',(-40,-8,0),'cyanGlow')
    _npc_station('35_NPCStations_Daily','DAILY_REWARDS','DAILY GIFTS',(29,-34,0),'purpleGlow')
    target=collection('35_NPCStations')
    for subname in ('35_NPCStations_Quest','35_NPCStations_Mastery','35_NPCStations_Daily'):
        sub=collection(subname)
        if sub.name not in target.children:
            target.children.link(sub)
        if sub.name in bpy.context.scene.collection.children:
            bpy.context.scene.collection.children.unlink(sub)

def build():
    _story()
    _summon()
    _ranked()
    _champions()
    _shop()
    _npcs()
