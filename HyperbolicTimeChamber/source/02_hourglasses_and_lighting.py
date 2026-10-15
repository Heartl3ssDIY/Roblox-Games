exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\HyperbolicTimeChamber\source\common.py',encoding='utf-8').read(),'common.py','exec'))
for side in [-1,1]:
 x=side*51;loc=(x,82,0)
 lathe('TC_Hourglass_Plinth_'+str(side),[(7.4,.625),(7.4,1.1),(6.9,1.35),(6.9,1.85),(6.5,2.2),(6.5,3.5),(6.8,3.75)],loc,4,'20_Hourglass_Gold',GOLD)
 lathe('TC_Hourglass_Base_Inset_'+str(side),[(6.2,2.3),(6.2,3.35)],loc,11,'21_Hourglass_Accents')
 profile=[(5.9,3.8),(6.1,4.5),(6.15,8),(5.9,11.8),(5.05,14.5),(3.3,16.5),(1.25,18.6),(.6,20),(.8,20.6),(2,21.6),(4.2,23.6),(5.6,26),(6.1,28.8),(6.1,34.3),(5.9,35.2)]
 lathe('TC_Glass_Hourglass_'+str(side),profile,loc,9,'22_Glass',GLASS,n=64)
 # Sand fills the upper bowl and forms a conical heap below.
 upper=[(.2,20.7),(.5,22),(2.6,23.2),(4.5,25),(5.6,27.5),(5.72,32.9)]
 lathe('TC_Upper_Green_Sand_'+str(side),upper,loc,8,'23_Green_Sand')
 bottom=[(5.6,4),(5.7,5),(5.0,6.4),(3.6,7.9),(1.6,9.5),(.12,10.5)]
 lathe('TC_Lower_Green_Sand_'+str(side),bottom,loc,8,'23_Green_Sand')
 tube('TC_Falling_Sand_'+str(side),[(x,82,10.3),(x,82,23)],.14,9,'23_Green_Sand',n=8)
 lathe('TC_Hourglass_Top_Band_'+str(side),[(6.1,34.7),(6.8,35),(6.8,35.6),(6.5,35.9)],loc,4,'20_Hourglass_Gold',GOLD)
 dome('TC_Hourglass_Cap_'+str(side),6.5,5.3,35.8,loc,4,'20_Hourglass_Gold',GOLD)
 lathe('TC_Hourglass_Spire_'+str(side),[(.58,40.7),(.48,41.4),(.055,44.1)],loc,4,'20_Hourglass_Gold',GOLD,n=24)
 for i in range(12):
  a=i*2*pi/12;pts=[(x+6.54*cos(t)*cos(a),82+6.54*cos(t)*sin(a),35.8+5.32*sin(t)) for t in np.linspace(0,pi/2-.09,13)]
  tube('TC_Hourglass_Cap_Rib_%s_%s'%(side,i),pts,.045,5,'20_Hourglass_Gold',GOLD,n=5)
 # Slim opaque highlights retain the bottle silhouette in game engines.
 for j,a in enumerate(np.radians([-125,-65])):
  pts=[(x+(r+.025)*cos(a),82+(r+.025)*sin(a),z) for r,z in profile[1:-1]]
  tube('TC_Glass_Glint_%s_%s'%(side,j),pts,.055,0,'21_Hourglass_Accents',n=6)
 x=side*67
 lathe('TC_Orb_Lamp_Stand_'+str(side),[(1.6,.63),(1.6,1),(1.05,1.3),(.38,1.8),(.26,18.7),(.6,19.2),(.75,19.5)],(x,82,0),4,'24_Orb_Lamps',GOLD,n=28)
 prof=[(2.65*sin(t),22.1-2.65*cos(t)) for t in np.linspace(.015,pi-.015,23)]
 lathe('TC_Orb_Lamp_Globe_'+str(side),prof,(x,82,0),9,'24_Orb_Lamps',n=40)
 lathe('TC_Orb_Lamp_Crown_'+str(side),[(1.35,24.25),(1.35,24.65),(.7,24.85)],(x,82,0),4,'24_Orb_Lamps',GOLD,n=32)
for ob in list(bpy.context.scene.objects):
 if ob.type=='MESH' and ob.name.startswith('TC_Pink_Barrel'):
  bm=bmesh.new();bm.from_mesh(ob.data)
  for f in bm.faces:
   if f.normal.z<-.1:f.normal_flip()
  bm.to_mesh(ob.data);bm.free();ob.data.update()
for name,loc in [('TC_Arena_Center',(0,0,0)),('TC_Team_A_Spawn',(0,-22,0)),('TC_Team_B_Spawn',(0,22,0)),('TC_Board_Min',(-32,-32,0)),('TC_Board_Max',(32,32,0))]:
 ob=bpy.data.objects.new(name,None);collection('80_Gameplay_Markers').objects.link(ob);ob.location=loc;ob.empty_display_size=1
sc=bpy.context.scene;sc['Combat_Size']='64 x 64 Blender units, clear white floor';sc['Hall_Center']=(0,82,0)
world=bpy.data.worlds.new('Time Chamber | endless white');world.use_nodes=True;bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.94,.95,.91,1);bg.inputs['Strength'].default_value=.8;sc.world=world
for name,loc,target,energy,size,color in [
 ('TC_Soft_Key',(-55,-15,125),(0,75,10),185000,85,(1,.94,.82)),
 ('TC_Soft_Fill',(70,35,90),(0,75,15),105000,70,(.82,.94,1)),
 ('TC_Rim_Light',(0,130,100),(0,75,18),140000,65,(1,1,1))]:
 d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.shape='DISK';d.size=size;d.color=color;o=bpy.data.objects.new(name,d);collection('90_Presentation').objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
camera('TC_Camera_Hero',(132,-125,130),(0,69,13),ortho=174)
camera('TC_Camera_Front',(0,-135,48),(0,82,20),ortho=158)
camera('TC_Camera_Layout',(100,-155,170),(0,25,0),ortho=214)
camera('TC_Camera_Top',(0,35,260),(0,35,0),ortho=175)
sc.camera=bpy.data.objects['TC_Camera_Hero'];sc.render.resolution_x=1800;sc.render.resolution_y=1300;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG'
try:sc.view_settings.view_transform='AgX'
except Exception:pass
sc.render.filepath=os.path.join(ROOT,'previews','Time_Chamber_Hero.png')
bpy.context.view_layer.update()
bpy.data.libraries.write(os.path.join(ROOT,'Hyperbolic_Time_Chamber_Editable.blend'),{sc},fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print('Hourglasses and lighting complete',len(sc.objects))
