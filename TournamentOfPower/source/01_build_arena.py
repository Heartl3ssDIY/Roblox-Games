exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TournamentOfPower\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.data.scenes.new('Tournament of Power')
bpy.context.window.scene=sc
sc.unit_settings.system='NONE'
try:sc.render.engine='BLENDER_EEVEE'
except TypeError:pass
MAT=make_atlas()
disk('Floor_dark_grout_base',58,0,4,'01_Arena_Floor')
disk('Center_ochre_medallion',5.4,.022,1,'01_Arena_Floor')
for name,r1,r2,cat in [('Center_ivory_rim',5.4,6.2,0),('Inner_band',16,17,0),('Inner_ochre_outline',17,18,11),('Middle_separator',28,29.1,0),('Middle_ochre_outline',29.1,30,11),('Outer_separator',41,42.1,0),('Outer_ochre_outline',42.1,43,11),('Perimeter_ivory',54,55.2,0),('Perimeter_ochre',55.2,56.5,3),('Edge_ivory',56.5,57.1,0)]:
 ring(name,r1,r2,.025,.025,cat,'01_Arena_Floor')
mosaic('Inner_radial_inlays',6.2,16,.026,.026,120,'bars','01_Arena_Floor')
mosaic('Inner_triangle_mosaic',18,28,.026,.026,40,'teeth','01_Arena_Floor')
mosaic('Middle_radial_inlays',30,41,.026,.026,96,'bars','01_Arena_Floor')
mosaic('Outer_triangle_mosaic',43,54,.026,.026,56,'teeth','01_Arena_Floor')
mosaic('Edge_inlay',57.1,58,.026,.026,96,'bars','01_Arena_Floor')
cylinder('Arena_striped_outer_fascia',58,-4.6,0,[2,3],'02_Rim',96,False)
for i,(rad,z0,z1,cat) in enumerate([(58.08,-.27,-.02,7),(58.08,-4.6,-4.35,4),(57.8,-4.92,-4.6,3),(57.3,-5.2,-4.92,0)]):
 cylinder('Edge_moulding_%02d'%i,rad,z0,z1,cat,'02_Rim',192,False)
ring('Underside_dark_ground',4.5,57.3,-30,-5.2,4,'03_Tapered_Underside',192,bottom=True)
def z(r):return -30+(r-4.5)*(24.8/52.8)
for r1,r2,cat in [(4.5,6,0),(6,7,11),(16,17,0),(17,18,11),(30,31.5,0),(31.5,32.3,11),(44,45.3,0),(45.3,46,11),(55.5,57.3,0)]:
 ring('Underside_trim_'+str(r1),r1,r2,z(r1)-.03,z(r2)-.03,cat,'03_Tapered_Underside',192,bottom=True)
for r1,r2,count,kind in [(7,16,80,'bars'),(18,30,40,'teeth'),(32.3,44,96,'bars'),(46,55.5,56,'teeth')]:
 mosaic('Underside_mosaic_'+str(r1),r1,r2,z(r1)-.035,z(r2)-.035,count,kind,'03_Tapered_Underside',True)
cylinder('Underside_neck',4.5,-31.3,-30,11,'04_Lower_Spindle',128)
colors=[0,2,1,2,0,2,1,2,0]
for i in range(9):
 z0=-31.3-i*2.15;z1=z0-2.15
 ring('Lower_stripe_%02d'%i,3.35-i*.13,3.22-i*.13,z0,z1,colors[i],'04_Lower_Spindle',96,bottom=True)
ring('Spindle_tip',2.18,.001,-50.65,-54.8,11,'04_Lower_Spindle',96,bottom=True)
for i,cat in enumerate(colors):
 ob=cylinder('Pillar_stripe_%02d'%i,2.9,i*4.3,(i+1)*4.3,cat,'05_Center_Pillar',128,i in [0,8])
 ob['Roblox_CanCollide']=False;ob['Roblox_CanTouch']=False;ob['Roblox_CanQuery']=True
for i in range(1,9):
 cylinder('Pillar_joint_%02d'%i,2.905,i*4.3-.035,i*4.3+.035,4,'05_Center_Pillar',128,False)
disk('Pillar_top_cap',2.9,38.705,9,'05_Center_Pillar',128)
ring('Pillar_top_lip',2.55,2.9,38.71,38.71,3,'05_Center_Pillar',128)
ring('Pillar_top_inner_ring',1.7,1.95,38.712,38.712,3,'05_Center_Pillar',128)
disk('Pillar_top_center',.52,38.715,3,'05_Center_Pillar',64)
arcsolid('Spectator_arc_foundation',62.5,73.5,7.5,9,5,'06_Spectator_Stand')
for row in range(4):
 r0=63+row*2.35; ztop=9.4+row*1.25
 arcsolid('Grandstand_tier_%02d'%row,r0,r0+2.35,8.8,ztop,6,'06_Spectator_Stand')
 arcsolid('Grandstand_tread_%02d'%row,r0+.13,r0+2.17,ztop,ztop+.12,11,'06_Spectator_Stand')
 arcsolid('Grandstand_seat_lip_%02d'%row,r0+.04,r0+.21,ztop+.1,ztop+.22,3,'06_Spectator_Stand')
arcsolid('Grandstand_front_pale_curb',62.4,63,7.4,9.5,7,'06_Spectator_Stand')
arcsolid('Grandstand_outer_pale_wall',72.65,73.5,7.4,14.7,7,'06_Spectator_Stand')
arcsolid('Grandstand_outer_dark_coping',72.52,73.63,14.7,15,9,'06_Spectator_Stand')
for a,sgn in [(-.13*pi,1),(1.13*pi,-1)]:
 arcsolid('Stand_end_cap',62.4,73.5,7.4,9.5,7,'06_Spectator_Stand',a-.003,a+.003,n=1)
 for row in range(4):
  arcsolid('Stepped_endcap',63+row*2.35,65.35+row*2.35,9.5,9.65+row*1.25,7,'06_Spectator_Stand',a-.004,a+.004,n=1)
for group,name in [('01_Arena_Floor','TOP_Arena_Mosaic'),('02_Rim','TOP_Striped_Rim'),('03_Tapered_Underside','TOP_Tapered_Mosaic'),('04_Lower_Spindle','TOP_Lower_Spindle'),('05_Center_Pillar','TOP_Center_Pillar_NONCOLLIDE'),('06_Spectator_Stand','TOP_Curved_Spectator_Stand')]:
 ob=join_group(group,name)
 if group=='05_Center_Pillar':
  ob['Roblox_CanCollide']=False;ob['Roblox_CanTouch']=False;ob['Roblox_CanQuery']=True;ob['Role']='Visible central timer pillar. Non-blocking gameplay; queryable for later click behavior.'
for name,loc in [('Arena_Center',(0,0,.026)),('Team_A_Spawn',(0,-23,.026)),('Team_B_Spawn',(0,23,.026)),('Board_Min',(-32,-32,.026)),('Board_Max',(32,32,.026))]:
 ob=bpy.data.objects.new(name,None);collection('80_Gameplay_Markers').objects.link(ob);ob.location=loc;ob.empty_display_size=2
col=cylinder('COL_Arena_Disc',58,-4.6,0,4,'85_Collision',128)
col['Role']='Solid playable floor; center pillar deliberately excluded.'
collection('85_Collision').hide_render=True;collection('85_Collision').hide_viewport=True
world=bpy.data.worlds.new('World of Void | preview only');sc.world=world;world.use_nodes=True
nodes=world.node_tree.nodes;nodes.clear()
out=nodes.new('ShaderNodeOutputWorld');bg=nodes.new('ShaderNodeBackground')
bg.inputs['Strength'].default_value=.3
coord=nodes.new('ShaderNodeTexCoord');noise=nodes.new('ShaderNodeTexNoise')
noise.inputs['Scale'].default_value=3.2;noise.inputs['Detail'].default_value=4;noise.inputs['Roughness'].default_value=.68;noise.inputs['Distortion'].default_value=.4
ramp=nodes.new('ShaderNodeValToRGB')
ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1])
for pos,color in [(0,(.002,.003,.009,1)),(.38,(.009,.006,.024,1)),(.53,(.019,.055,.063,1)),(.64,(.035,.13,.11,1)),(.76,(.09,.17,.14,1)),(1,(.24,.26,.17,1))]:
 e=ramp.color_ramp.elements[0] if pos==0 else ramp.color_ramp.elements.new(pos);e.position=pos;e.color=color
world.node_tree.links.new(coord.outputs['Normal'],noise.inputs['Vector']);world.node_tree.links.new(noise.outputs['Factor'],ramp.inputs['Factor']);world.node_tree.links.new(ramp.outputs['Color'],bg.inputs['Color']);world.node_tree.links.new(bg.outputs['Background'],out.inputs['Surface'])
area('Key_softbox',(-50,-60,125),(0,0,-5),210000,(1,.88,.70),80)
area('Cool_fill',(90,-10,65),(0,0,-10),140000,(.66,.83,1),75)
area('Rear_rim',(-30,80,60),(0,0,-5),220000,(.72,1,.89),65)
area('Underside_fill',(0,-80,-40),(0,0,-20),90000,(.68,.83,.91),60)
hero=camera('Camera_Hero',(126,-178,116),(0,4,-5),48);sc.camera=hero
camera('Camera_Low_Underside',(130,-180,-68),(0,0,-11),48)
top=camera('Camera_Top',(0,0,170),(0,0,0),50);top.data.type='ORTHO';top.data.ortho_scale=166
sc.render.resolution_x=1600;sc.render.resolution_y=1300;sc.render.resolution_percentage=100
sc.render.image_settings.file_format='PNG';sc.render.filepath=os.path.join(ROOT,'previews','Tournament_of_Power_Hero.png')
sc.view_settings.view_transform='AgX';sc.view_settings.look='None'
for screen in bpy.data.screens:
 for a in screen.areas:
  if a.type=='VIEW_3D':
   a.spaces.active.region_3d.view_perspective='CAMERA';a.spaces.active.overlay.show_overlays=False;a.spaces.active.shading.type='MATERIAL'
bpy.ops.object.select_all(action='DESELECT')
bpy.data.libraries.write(os.path.join(ROOT,'Tournament_of_Power.blend'),{sc},fake_user=True,compress=True)
print('Built',len(sc.objects),'objects')
bpy.ops.render.render(write_still=True)
