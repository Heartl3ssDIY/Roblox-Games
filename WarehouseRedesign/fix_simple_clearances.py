import bpy,json
scene=bpy.context.scene
bpy.data.objects['WarehouseNameBoard'].location.y=46.31
bpy.data.objects['Preview_Name'].location.y=46.63
for ob in scene.objects:
 if ob.name.startswith('WallColourBand'):ob.location.z=14.1
 if ob.name.startswith(('Pallet3','Cargo3')) or (ob.users_collection and ob.users_collection[0].name=='Forklift'):
  ob.location.y+=1
  if ob.get('Cells'):
   pieces=json.loads(ob['Cells'])
   for p,s in pieces:p[1]+=1
   ob['Cells']=json.dumps(pieces)
for ob in list(scene.objects):
 if ob.name=='OfficeStorageBody' or ob.name.startswith(('StorageDoor','StorageHandle','StorageTop')):bpy.data.objects.remove(ob,do_unlink=True)
solid('OfficeStorageBody',[
 ((83.15,.25,2.1),(.3,2.2,4.2)),((94.85,.25,2.1),(.3,2.2,4.2)),
 ((89,1.25,2.1),(11.4,.2,4.2)),((89,.15,.15),(11.4,2,.3)),
 ((89,.15,4.05),(11.4,2,.3))],'Pillar','OfficeFurniture','Pillar')
for i,x in enumerate((85.15,89,92.85)):
 box('StorageDoor%d'%i,(x,-1,2.1),(3.7,.25,3.5),'OfficeWall','OfficeFurniture')
 box('StorageHandle%d'%i,(x+1.2,-1.2,2.1),(.1,.15,.7),'Metal','OfficeFurniture')
box('StorageTop',(89,.25,4.32),(12,2.2,.24),'Wood','OfficeFurniture')
print('Clearances corrected')
