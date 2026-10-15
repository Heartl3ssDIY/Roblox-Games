exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TournamentOfPower\source\common.py',encoding='utf-8').read(),'common.py','exec'))
old=bpy.data.objects.get('TOP_Curved_Spectator_Stand')
profile=[(62.4,7.4,5),(73.5,7.4,7),(73.5,14.7,9),(72.65,14.7,7),(72.65,13.27,11),(70.26,13.27,3),(70.05,13.27,6),(70.05,12.02,11),(67.91,12.02,3),(67.7,12.02,6),(67.7,10.77,11),(65.56,10.77,3),(65.35,10.77,6),(65.35,9.52,11),(63.21,9.52,3),(63,9.52,7),(62.4,9.52,7)]
b=Builder();start=-.13*pi;end=1.13*pi;n=160
for j,(r0,z0,cat) in enumerate(profile):
 r1,z1,_=profile[(j+1)%len(profile)]
 for i in range(n):
  a=start+(end-start)*i/n;c=start+(end-start)*(i+1)/n
  b.face([polar(r0,a,z0),polar(r0,c,z0),polar(r1,c,z1),polar(r1,a,z1)],cat)
b.face([polar(r,start,z) for r,z,_ in reversed(profile)],7)
b.face([polar(r,end,z) for r,z,_ in profile],7)
new=b.build('TOP_Curved_Spectator_Stand_Refined','06_Spectator_Stand')
bm=bmesh.new();bm.from_mesh(new.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(new.data);bm.free()
if old:
 for c in list(old.users_collection):c.objects.unlink(old)
 archived=collection('98_Construction_Archive');archived.objects.link(old);archived.hide_render=True;archived.hide_viewport=True
new.name='TOP_Spectator_Stand'
spindle=bpy.data.objects['TOP_Lower_Spindle']
bm=bmesh.new();bm.from_mesh(spindle.data);bm.normal_update()
for f in bm.faces:
 mid=f.calc_center_median()
 if f.normal.x*mid.x+f.normal.y*mid.y<0:f.normal_flip()
bm.to_mesh(spindle.data);bm.free()
for name in ['TOP_Center_Pillar_NONCOLLIDE','TOP_Striped_Rim','TOP_Lower_Spindle']:
 ob=bpy.data.objects[name];bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bm.to_mesh(ob.data);bm.free()
 for p in ob.data.polygons:p.use_smooth=abs(p.normal.z)<.8
# Portable subtle stone roughness and normal textures.
size=2048;tile=512
normal=np.ones((size,size,4),dtype=np.float32);rough=np.ones((size,size,4),dtype=np.float32)
yy,xx=np.mgrid[0:tile,0:tile]/tile;rng=np.random.default_rng(187)
for k in range(16):
 h=.008*np.sin(xx*44+yy*17)*np.cos(yy*71-xx*31)+rng.normal(0,.001,(tile,tile))
 dy,dx=np.gradient(h);v=np.stack([-dx*1.5,-dy*1.5,np.ones_like(dx)],axis=2);v/=np.linalg.norm(v,axis=2)[:,:,None]
 row,col=divmod(k,4)
 normal[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]=v*.5+.5
 val=np.clip(.76+h*2,.68,.84)
 rough[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]=val[:,:,None]
for name,data in [('TOP_NormalAtlas',normal),('TOP_RoughnessAtlas',rough)]:
 img=bpy.data.images.new(name,width=size,height=size,alpha=False);img.colorspace_settings.name='Non-Color';img.pixels.foreach_set(data.ravel());img.filepath_raw=os.path.join(ROOT,'textures',name+'.png');img.file_format='PNG';img.save();img.pack()
 tex=MAT.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img
 bs=next(n for n in MAT.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 if name=='TOP_NormalAtlas':
  nm=MAT.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.32
  MAT.node_tree.links.new(tex.outputs['Color'],nm.inputs['Color']);MAT.node_tree.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
 else:MAT.node_tree.links.new(tex.outputs['Color'],bs.inputs['Roughness'])
ob=bpy.data.objects['TOP_Tapered_Mosaic'];uv=ob.data.uv_layers.active
for p in ob.data.polygons:
 u,v=uv.data[p.loop_start].uv
 cat=min(3,int(u*4))+4*min(3,int(v*4))
 if cat!=4:
  for vi in p.vertices:ob.data.vertices[vi].co.z-=.18
ob.data.update()
sc=bpy.context.scene
sc.camera=bpy.data.objects['Camera_Hero.001'] if bpy.data.objects.get('Camera_Hero.001') in sc.objects[:] else next(o for o in sc.objects if o.type=='CAMERA' and 'Hero' in o.name)
sc.camera.location=(126,-190,87);sc.camera.rotation_euler=(Vector((0,4,-6))-sc.camera.location).to_track_quat('-Z','Y').to_euler();sc.camera.data.lens=48
sc.render.resolution_x=1600;sc.render.resolution_y=1250
sc.render.filepath=os.path.join(ROOT,'previews','Tournament_of_Power_Hero.png');bpy.ops.render.render(write_still=True)
sc.camera=next(o for o in sc.objects if o.type=='CAMERA' and 'Low_Underside' in o.name)
sc.render.filepath=os.path.join(ROOT,'previews','Tournament_of_Power_Underside.png');bpy.ops.render.render(write_still=True)
sc.camera=next(o for o in sc.objects if o.type=='CAMERA' and 'Top' in o.name)
sc.render.resolution_x=1500;sc.render.resolution_y=1500
sc.render.filepath=os.path.join(ROOT,'previews','Tournament_of_Power_Top.png');bpy.ops.render.render(write_still=True)
sc.camera=next(o for o in sc.objects if o.type=='CAMERA' and 'Hero' in o.name)
sc.render.resolution_x=1600;sc.render.resolution_y=1250
sc.render.filepath=os.path.join(ROOT,'previews','Tournament_of_Power_Hero.png')
bpy.data.libraries.write(os.path.join(ROOT,'Tournament_of_Power.blend'),{sc},fake_user=True,compress=True)
print('Refined stand, corrected spindle normals, rendered three views and saved.')
