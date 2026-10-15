from common import *
from districts import B,C,T,R,I,X,_post,_lantern,_sign

def _sky_roof(name,z,w,d,rise,g):
    nx,ny=8,6
    verts=[];faces=[]
    def height(x,y):
        return z+rise*(1-abs(y)/(d/2))+.85*(abs(y)/(d/2))**6+1.1*(abs(x)/(w/2))**7
    for layer in (0,-.28):
        for j in range(ny+1):
            y=-d/2+d*j/ny
            for i in range(nx+1):
                x=-w/2+w*i/nx
                verts.append((x,y,height(x,y)+layer))
    n=(nx+1)*(ny+1)
    for j in range(ny):
        for i in range(nx):
            a=j*(nx+1)+i
            faces.extend([(a,a+1,a+nx+2,a+nx+1),(a+n,a+nx+1+n,a+nx+2+n,a+1+n)])
    for i in range(nx):
        for j in (0,ny):
            a=j*(nx+1)+i
            faces.append((a,a+n,a+n+1,a+1))
    for j in range(ny):
        for i in (0,nx):
            a=j*(nx+1)+i
            faces.append((a,a+nx+1,a+nx+1+n,a+n))
    mesh(name+'_swept_roof',verts,faces,'roof',g)
    for s in (-1,1):
        pts=[(-w/2+w*k/12,s*d/2,height(-w/2+w*k/12,s*d/2)+.04) for k in range(13)]
        T(name+'_gilt_eave',pts,[.10]*13,'gold',g,sides=6)
        xx=s*w/2
        pts=[(xx,-d/2+d*k/8,height(xx,-d/2+d*k/8)+.03) for k in range(9)]
        T(name+'_gilt_gable',pts,[.11]*9,'gold',g,sides=6)
    ribs=max(6,int(w/2))
    for j in range(ribs+1):
        x=-w/2+w*j/ribs
        for s in (-1,1):
            pts=[(x,s*d*k/8,height(x,s*d*k/8)+.045) for k in range(5)]
            T(name+'_tile_rib',pts,[.052]*5,'stoneDark',g,sides=5)
    T(name+'_ridge',[(-w/2-.2,0,z+rise+1.15),(-w*.3,0,z+rise+.15),(w*.3,0,z+rise+.15),(w/2+.2,0,z+rise+1.15)],[.14]*4,'gold',g,sides=6)
    for s in (-1,1):
        T(name+'_horn',[(s*(w/2-.4),0,z+rise+.9),(s*(w/2+.4),0,z+rise+1.55),(s*(w/2+.5),0,z+rise+2.1)],[.15,.1,.012],'goldLight',g,sides=6)

def _window(name,x,y,z,width,height,g,axis=0):
    nx,ny=sin(axis),-cos(axis)
    ob=B(name+'_dark_frame',(x,y,z),(width+.22,.16,height+.24),'wood',g)
    ob.rotation_euler.z=axis
    ob=B(name+'_warm_paper',(x+nx*.03,y+ny*.03,z),(width,.17,height),'goldGlow',g)
    ob.rotation_euler.z=axis
    for off in (-.3,.3):
        xx=x+off*cos(axis)+nx*.12; yy=y+off*sin(axis)+ny*.12
        ob=B(name+'_vertical_lattice',(xx,yy,z),(.065,.045,height),'wood',g)
        ob.rotation_euler.z=axis
    for off in (-.45,.45):
        ob=B(name+'_horizontal_lattice',(x+nx*.13,y+ny*.13,z+off),(width,.04,.06),'wood',g)
        ob.rotation_euler.z=axis

def _balcony(name,w,d,z,g):
    for s in (-1,1):
        B(name+'_balcony_walk',(0,s*(d/2+.35),z),(w+1.6,1.4,.22),'wood',g)
        B(name+'_balcony_rail',(0,s*(d/2+.9),z+1.15),(w+1.6,.14,.14),'gold',g)
        for i in range(8):
            xx=-w/2-.6+(w+1.2)*i/7
            B(name+'_baluster',(xx,s*(d/2+.9),z+.67),(.095,.095,.9),'red',g)

def _tower(name,loc,w,d,levels,style,yaw=0):
    g='36_Backdrop_'+name
    B(name+'_stone_foot',(0,0,1.50),(w+1.7,d+1.7,.6),'stoneDark',g,bevel=.15)
    B(name+'_ivory_sockle',(0,0,2.0),(w+.5,d+.5,.48),'stoneLight',g,bevel=.08)
    base=2.25
    for k in range(levels):
        shrink=1-k*.08
        ww,dd=w*shrink,d*shrink
        z=base+k*7.55
        color='ivory' if (k+style)%3==0 else 'wood'
        B(name+'_tier_wall',(0,0,z+2.8),(ww,dd,5.6),color,g,bevel=.08)
        B(name+'_belt',(0,0,z+.1),(ww+.3,dd+.3,.27),'red',g)
        B(name+'_upper_frieze',(0,0,z+5.2),(ww+.6,dd+.6,.48),'red',g)
        for sx in (-1,1):
            for sy in (-1,1):
                B(name+'_corner_post',(sx*(ww/2-.17),sy*(dd/2-.17),z+2.8),(.34,.34,5.8),'wood' if color=='ivory' else 'red',g)
        for sy in (-1,1):
            for xx in (-ww*.29,0,ww*.29):
                _window(name+'_window',xx,sy*(dd/2+.08),z+3.15,1.7,2.25,g,axis=0 if sy==-1 else pi)
            for xx in (-ww*.43,ww*.43):
                B(name+'_wall_gilt',(xx,sy*(dd/2+.17),z+2.8),(.055,.07,4.6),'gold',g)
        for sx in (-1,1):
            for yy in (-dd*.25,dd*.25):
                B(name+'_side_warm_window',(sx*(ww/2+.06),yy,z+3.15),(.14,1.7,2.2),'goldGlow',g)
                for zz in (-.55,.15,.7):
                    B(name+'_side_lattice',(sx*(ww/2+.15),yy,z+3.15+zz),(.06,1.75,.06),'wood',g)
                B(name+'_side_window_vertical',(sx*(ww/2+.15),yy,z+3.15),(.06,.08,2.3),'wood',g)
        if k==1 or k==levels-1:
            _balcony(name+'_tier'+str(k),ww,dd,z+.35,g)
        _sky_roof(name+'_roof'+str(k),z+5.55,ww+4.3,dd+3.6,2.1 if k<levels-1 else 2.8,g)
    top=base+(levels-1)*7.55+8.7
    C(name+'_spire_base',(0,0,top+.5),.85,1.0,'gold',g,vertices=10)
    for i in range(4):
        R(name+'_spire_ring',(0,0,top+1.05+i*.6),.83-i*.13,.65-i*.13,.10,'gold',g,segments=20)
    T(name+'_spire_needle',[(0,0,top),(0,0,top+4.6)],[.18,.015],'goldLight',g,sides=6)
    for sx in (-1,1):
        _lantern(name+'_entry_lantern',sx*(w/2-.65),-d/2-.7,5.7,g,.47)
    B(name+'_entry_door',(0,-d/2-.13,4.0),(2.8,.12,3.65),'purple',g)
    B(name+'_door_gilt',(0,-d/2-.21,4.0),(.07,.07,3.4),'gold',g)
    for x in (-.36,.36):
        C(name+'_door_stud',(x,-d/2-.31,4.0),.13,.12,'gold',g,vertices=8).rotation_euler.x=pi/2
    if style%2:
        B(name+'_hanging_banner',(w/2-.8,-d/2-.46,10.25),(1.6,.08,5.3),'purple',g)
        X(name+'_banner_sigil','ACU',(w/2-.8,-d/2-.54,10.3),.42,'goldLight',g)
    transform_group(g,(loc[0],loc[1],0),yaw)

def _stall(name,loc,style,yaw,title):
    g='37_MerchantStalls_'+name
    w,d=7.9,5.7
    B(name+'_stone_pad',(0,0,1.22),(9.2,7.7,.12),'stoneLight',g,bevel=.10)
    B(name+'_counter',(0,-1.8,2.65),(7.2,1.5,2.7),'wood',g,bevel=.09)
    B(name+'_counter_gold',(0,-1.8,4.06),(7.5,1.7,.13),'gold',g)
    B(name+'_rear_shelf',(0,2.1,3.7),(7.4,.9,.18),'wood',g)
    for x in (-3.4,3.4):
        _post(name+'_post',x,1.7,1.2,6.2,g,'red',radius=.16)
    if style==0:
        _sky_roof(name+'_roof',6.15,9.8,7.1,1.55,g)
    else:
        verts=[(-4.8,-3.8,5.8),(-4.8,.3,7.2),(-4.8,3.5,6.3),(4.8,-3.8,5.8),(4.8,.3,7.2),(4.8,3.5,6.3)]
        mesh(name+'_festival_canopy',verts,[(0,3,4,1),(1,4,5,2)],'purple' if style==1 else 'red',g)
        for x in (-4.75,4.75):
            T(name+'_awning_gold',[(x,-3.8,5.81),(x,.3,7.21),(x,3.5,6.31)],[.07]*3,'gold',g,sides=6)
        for i in range(9):
            B(name+'_scallop',(-4.4+i*1.1,-3.8,5.54),(1.01,.07,.55),'gold' if i%2 else 'purple',g,bevel=.05)
    X(name+'_store_sign',title,(0,-3.87,5.45),.60,'goldLight',g)
    for x in (-3.5,3.5):
        _lantern(name+'_lantern',x,-2.9,5.3,g,.30)
    if style==0:
        for x in (-2.3,0,2.3):
            C(name+'_tea_tray',(x,-1.8,4.2),.65,.10,'gold',g,vertices=16)
            for yy in (-.25,.25):
                C(name+'_teacup',(x,-1.8+yy,4.43),.15,.35,'ivory',g,vertices=12)
        for x in (-2.7,-.9,.9,2.7):
            C(name+'_tea_canister',(x,2,4.25),.4,.9,'ivory',g,vertices=12)
            C(name+'_tea_canister_lid',(x,2,4.73),.44,.12,'gold',g,vertices=12)
    elif style==1:
        for x in (-2.6,-.9,.9,2.6):
            B(name+'_scroll_base',(x,-1.8,4.15),(1.0,.8,.16),'ivory',g)
            for yy in (-.45,.45):
                c=C(name+'_scroll_roller',(x,-1.8+yy,4.29),.11,1.2,'gold',g,vertices=8)
                c.rotation_euler.y=pi/2
            B(name+'_ink_line',(x,-1.8,4.24),(.07,.55,.015),'purple',g)
        for x in (-2,0,2):
            C(name+'_scroll_case',(x,2,4.75),.36,1.95,'red',g,vertices=12)
            C(name+'_scroll_case_cap',(x,2,5.78),.4,.12,'gold',g,vertices=12)
    else:
        for x in (-2.4,0,2.4):
            C(name+'_souvenir_plinth',(x,-1.8,4.23),.65,.28,'stoneDark',g,vertices=8)
            I(name+'_lucky_crystal',(x,-1.8,4.90),(.39,.32,.66),'purpleGlow' if x==0 else 'cyanGlow',g)
        for x in (-2.6,-.8,.8,2.6):
            C(name+'_coin_bowl',(x,2,3.98),.48,.4,'gold',g,vertices=12)
            I(name+'_coin_pile',(x,2,4.17),(.36,.32,.20),'goldLight',g)
    transform_group(g,(loc[0],loc[1],0),yaw)
    ca,sa=cos(yaw),sin(yaw)
    marker('NPC_'+name,(loc[0]-.6*sa,loc[1]+.6*ca,1.2),'npc_merchant_'+name.lower())
    marker('INTERACT_'+name,(loc[0]+4.6*sa,loc[1]-4.6*ca,1.2),'hobby_'+name.lower())

def build():
    _tower('CrimsonArchive',(-87,63),11.5,11.5,4,0,.08)
    _tower('LotusLibrary',(-42,87),12.5,12.0,3,1,-.07)
    _tower('CelestialObservatory',(-9,97),12.0,12.0,4,2,0)
    _tower('EasternBellhouse',(88,62),11.0,10.0,3,0,-.11)
    _tower('LanternInn',(92,22),11.0,12.0,3,1,-pi/2)
    _tower('ScholarsRetreat',(-67,89),13.0,11.0,3,2,.12)
    _tower('SakuraSanctum',(20,90),10.5,11.0,3,0,-.06)
    _stall('MoonTea',(-43,-39),0,-.40,'MOON TEA')
    _stall('ScrollAtelier',(-29,-60),1,.24,'SCROLL ATELIER')
    _stall('LuckyCharms',(44,-62),2,-.2,'LUCKY CHARMS')
