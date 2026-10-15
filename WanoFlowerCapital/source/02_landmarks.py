exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\WanoFlowerCapital\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene
crag('WA_Castle_Rock_and_Trunk',(0,177,0),28,61,2,'40_Castle_Foundation',n=18)
# Root ridges give the central pedestal a tree-like silhouette.
for i,a in enumerate(np.linspace(0,2*pi,13,endpoint=False)):
 pts=[(29*cos(a),177+29*sin(a),1),(24*cos(a),177+24*sin(a),19),(18*cos(a),177+18*sin(a),47),(15*cos(a),177+15*sin(a),59)]
 tube('WA_Pedestal_Root_%02d'%i,pts,[2.2,1.5,1.1,.4],3,'40_Castle_Foundation',n=7)
for x in [-12,12]:
 waterfall=Builder()
 for xx,w,cat,y in [(x,3.1,8,152),(x-.55,.6,11,151.92),(x+.8,.28,14,151.87)]:
  waterfall.face([(xx-w/2,y,8),(xx+w/2,y,8),(xx+w/2,y+7,59),(xx-w/2,y+7,59)],cat)
 waterfall.build('WA_Waterfall_'+str(x),'41_Waterfalls')
 ico('WA_Waterfall_Foam_'+str(x),(x,151,6),(3.7,2.3,.8),11,'41_Waterfalls')
# Large gatehouse at the end of the street, below the raised castle.
before=set(bpy.data.objects)
box('WA_Palace_Gate_Base',(0,0,6.5),(33,22,13),3,'42_Lower_Gatehouse')
box('WA_Palace_Gate_Door',(0,-11.12,7),(9,.2,13),15,'42_Lower_Gatehouse')
for side in [-1,1]:
 box('WA_Palace_Gate_Pier_'+str(side),(side*14,-11.4,7),(2,2,14),4,'42_Lower_Gatehouse')
roof('WA_Palace_Gate_Roof',41,30,14,7,8,'42_Lower_Gatehouse')
roof('WA_Palace_Gate_Upper_Roof',26,22,25,6,8,'42_Lower_Gatehouse')
box('WA_Palace_Gate_Upper_Storey',(0,0,23),(21,18,5),14,'42_Lower_Gatehouse')
for side in [-1,1]:
 tube('WA_Gold_Gate_Horn_'+str(side),[(side*3,-16,20),(side*9,-16,23),(side*12,-16,32),(side*12.5,-16,38)],[1.2,1,.65,.06],5,'42_Lower_Gatehouse',GOLD,n=10)
for ob in bpy.data.objects:
 if ob not in before:ob.location.y+=147
# Castle tiers retain the strong silhouette without fine architectural carving.
before=set(bpy.data.objects)
for j,(w,d,z,h) in enumerate([(34,25,60,10),(25,19,78,9),(16,13,95,9)]):
 box('WA_Castle_Storey_%s'%j,(0,0,z+h/2),(w,d,h),14,'43_Castle')
 box('WA_Castle_Base_Band_%s'%j,(0,0,z+.4),(w+1.4,d+1.4,.8),4 if j==0 else 15,'43_Castle')
 for xx in np.linspace(-w/2+2,w/2-2,7 if j==0 else 5):
  box('WA_Castle_Window_%s_%s'%(j,xx),(xx,-d/2-.08,z+h*.58),(1.2,.18,h*.43),15,'43_Castle')
  box('WA_Castle_Post_%s_%s'%(j,xx),(xx-1,-d/2-.15,z+h/2),(.2,.2,h),15,'43_Castle')
 roof('WA_Castle_Roof_%s'%j,w+10,d+9,z+h+.4,6,15,'44_Castle_Roofs')
 for side in [-1,1]:
  tube('WA_Castle_Gold_Finial_%s_%s'%(j,side),[(0,side*(d/2+4),z+h+6.8),(0,side*(d/2+5.5),z+h+8),(0,side*(d/2+5.2),z+h+9.5)],[.42,.3,.07],5,'45_Castle_Gold',GOLD,n=8)
# Red veranda below the lowest tier.
box('WA_Castle_Veranda',(0,-.2,59.3),(40,31,1.1),4,'43_Castle')
for x in np.arange(-19,20,3):
 box('WA_Castle_Veranda_Post_'+str(x),(x,-15.3,61),( .28,.28,3.2),4,'43_Castle')
box('WA_Castle_Veranda_Rail',(0,-15.3,62.4),(40,.35,.35),4,'43_Castle')
for ob in bpy.data.objects:
 if ob not in before:ob.location.y+=176
# Monumental curved tree behind the castle.
pts=[(8,189,12),(27,190,37),(42,191,66),(48,191,93),(39,191,116),(19,190,131),(-6,189,132),(-27,188,115)]
tube('WA_Giant_Curved_Tree',pts,[8,7.5,6.2,5.1,4.3,3.5,2.7,1.0],3,'46_Giant_Tree',n=14)
tube('WA_Giant_Tree_Right_Branch',[(36,191,63),(53,191,80),(67,193,84)],[4.3,2.6,.55],3,'46_Giant_Tree',n=10)
tube('WA_Giant_Tree_Left_Branch',[(-1,189,131),(-20,188,134),(-34,188,129)],[2.3,1.7,.35],3,'46_Giant_Tree',n=10)
for j,(x,y,z,s) in enumerate([(-27,188,118,1.2),(-30,189,134,1.2),(-5,189,136,1.5),(22,191,136,1.5),(44,191,119,1.3),(55,193,97,1.5),(65,193,88,1.2)]):
 for k in range(4):
  ico('WA_Giant_Blossom_%s_%s'%(j,k),(x+random.uniform(-5,5)*s,y+random.uniform(-3,3)*s,z+random.uniform(-1,2)*s),(6*s,4.6*s,2.8*s),13 if k%2 else 6,'47_Giant_Blossoms')
# Background mountain silhouettes and grassy stone pillars.
crag('WA_Distant_Blue_Peak',(-68,193,0),15,146,12,'48_Mountains',n=9)
lathe('WA_Peak_Snow',[(5.5,141),(.06,166)],(-68,193,0),11,'48_Mountains',n=9)
for j,(x,y,r,h) in enumerate([(77,183,24,77),(-93,170,18,62),(101,200,14,52)]):
 crag('WA_Cliff_'+str(j),(x,y,0),r,h,2,'48_Mountains',n=11)
 ico('WA_Grassy_Cliff_Crown_'+str(j),(x,y,h),(r*.65,r*.6,3.4),10,'49_Cliff_Green')
# Distant pagoda to enrich the skyline with only three simple tiers.
before=set(bpy.data.objects)
for j in range(3):
 w=16-j*3;z=8+j*12
 box('WA_Distant_Pagoda_Body_'+str(j),(0,0,z),(w,w,8),14,'50_Distant_Pagoda')
 roof('WA_Distant_Pagoda_Roof_'+str(j),w+6,w+6,z+4,4,7,'50_Distant_Pagoda')
for o in bpy.data.objects:
 if o not in before:o.location.x-=95;o.location.y+=122
# Correct the two broad faces of the torii cap.
ob=bpy.data.objects['WA_Torii_Curved_Cap'];bm=bmesh.new();bm.from_mesh(ob.data);bm.faces.ensure_lookup_table()
for f in bm.faces:
 if f.index%4 in [0,1]:f.normal_flip()
bm.to_mesh(ob.data);bm.free();ob.data.update()
world=bpy.data.worlds.new('Wano | clear blue sky');world.use_nodes=True;bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.38,.66,.85,1);bg.inputs['Strength'].default_value=.6;sc.world=world
for name,loc,target,power,size,color in [
 ('WA_Sun_Softbox',(-95,-50,195),(0,65,5),800000,95,(1,.87,.68)),
 ('WA_Sky_Fill',(100,30,150),(0,65,25),410000,120,(.73,.9,1)),
 ('WA_Back_Light',(0,235,205),(0,80,35),600000,110,(1,.9,.87))]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=color;o=bpy.data.objects.new(name,d);collection('90_Presentation').objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
camera('WA_Camera_Hero',(195,-215,230),(0,57,39),ortho=340)
camera('WA_Camera_Street',(0,-106,19),(0,138,52),lens=26)
camera('WA_Camera_Top',(0,58,350),(0,58,0),ortho=360)
sc.camera=bpy.data.objects['WA_Camera_Hero'];sc.render.resolution_x=1700;sc.render.resolution_y=1500;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG'
try:sc.view_settings.view_transform='AgX'
except Exception:pass
sc.render.filepath=os.path.join(ROOT,'previews','Wano_Hero.png')
bpy.context.view_layer.update()
bpy.data.libraries.write(os.path.join(ROOT,'Wano_Flower_Capital_Editable.blend'),{sc},fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print('Built Flower Capital landmarks',len(sc.objects))
