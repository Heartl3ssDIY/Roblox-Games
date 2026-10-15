ROOT=None;COL=STAGE
PREVIEWS={
 '01-seating':(['02 Student seating','03 Staff seating'],(6,4,.53),(8,-11,7.5),14.5,(2200,820)),
 '02-stationery':(['01 Stationery'],(.66,-.04,.83),(1.20,-1.8,1.85),1.68,(1500,1000)),
 '03-music':(['04 Music'],(1.2,7.9,.58),(3.2,2.4,3.1),4.6,(1700,1050)),
 '04-technology':(['05 Technology'],(8.7,7.95,.99),(10.3,5.1,2.7),2.45,(1600,1100)),
 '05-storage':(['06 Storage'],(2.0,12,.85),(5.0,5.0,4.5),6.4,(1700,1000)),
 '06-staffroom':(['07 Staffroom'],(7.05,12,.83),(8.0,10.0,1.85),1.9,(1700,950)),
 '07-boards':(['08 Boards'],(1.65,16,1.2),(4.4,7.8,4.2),6.1,(1800,1100)),
 '08-indoor-plants':(['09 Indoor plants'],(8.6,16,.63),(10.4,12.9,2.2),2.65,(1400,1200)),
 '09-outdoors':(['10 Outdoors'],(4.8,20.7,1.5),(10.2,8.8,8.2),13.0,(1900,1100)),
}
PREVIEWCAMS={}
for name,(_,target,position,scale,res) in PREVIEWS.items():PREVIEWCAMS[name]=cam('CAM | '+name,position,target,scale)
def review(name,render=True):
 cats,target,position,scale,res=PREVIEWS[name]
 for label,c in CATS.items():c.hide_render=label not in cats
 for ob in STAGE.objects:
  if 'pedestal' in ob.name.lower():ob.hide_render=not (('Stationery' in ob.name and name=='02-stationery') or ('Technology' in ob.name and name=='04-technology') or ('Staffroom' in ob.name and name=='06-staffroom'))
 target=Vector(target);distance=max(scale*.60,1.0)
 for lname,offset,power in [('Key | large softbox',(-.45,-.8,1.2),170),('Fill | cool softbox',(1,.2,.9),100),('Rim | daylight',(-.3,1,1.1),190)]:
  light=bpy.data.objects[lname];light.location=target+Vector(offset)*distance;light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler();light.data.energy=power*distance**2;light.data.size=distance*.85
 scene.camera=PREVIEWCAMS[name];scene.render.resolution_x=res[0];scene.render.resolution_y=res[1];scene.render.filepath=os.path.join(BASE,'renders',name+'.png')
 if render:bpy.ops.render.render(write_still=True)
 print('Review',name,scene.render.filepath)
def restore_library():
 for c in CATS.values():c.hide_render=False
 for o in STAGE.objects:o.hide_render=False
 scene.camera=bpy.data.objects['CAM | Full library']
 scene.camera.location=(27,-25,29);scene.camera.rotation_euler=(Vector((5.2,10.4,1.0))-scene.camera.location).to_track_quat('-Z','Y').to_euler();scene.camera.data.ortho_scale=29
 scene.render.resolution_x=1800;scene.render.resolution_y=1450;scene.render.filepath=os.path.join(BASE,'renders','00-library-overview.png')
 for lname,location,power,size in [('Key | large softbox',(1,-4,15),6500,10),('Fill | cool softbox',(17,8,11),5000,9),('Rim | daylight',(2,22,13),7500,8)]:
  l=bpy.data.objects[lname];l.location=location;l.rotation_euler=(Vector((6,10,0))-l.location).to_track_quat('-Z','Y').to_euler();l.data.energy=power;l.data.size=size
for record in ASSETS:
 root=bpy.data.objects[record['root']]
 root.asset_mark();root.asset_data.description='Wren School / '+record['category']+' / Editable first-review model. Metre scale.'
 root.asset_data.tags.new('Wren School');root.asset_data.tags.new('School props')
 record['parts']=len(bpy.data.collections[record['collection']].all_objects)-1
with open(os.path.join(BASE,'asset-manifest.json'),'w',encoding='utf-8') as f:json.dump(ASSETS,f,indent=2)
restore_library()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BASE,'Wren_School_Asset_Library_v01.blend'))
print('Saved',len(ASSETS),'assets',len(scene.objects),'objects')
