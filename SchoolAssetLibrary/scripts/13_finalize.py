import bmesh
# Refresh the remaining previews after final surface adjustments.
for name in ['03-music','04-technology','06-staffroom','08-indoor-plants']:
 review(name,True)
restore_library()
scene['project']='School — name undecided'
scene['included_assets']=len(ASSETS)
scene['material_workflow']='Editable procedural PBR materials; supplied logo image packed into file.'
scene['review_note']='Detailed Blender source models for visual review.'
for a in bpy.context.screen.areas:
 if a.type=='VIEW_3D':
  a.spaces.active.region_3d.view_perspective='CAMERA'
  a.spaces.active.region_3d.view_camera_zoom=0
  a.spaces.active.shading.type='MATERIAL'
  a.spaces.active.overlay.show_overlays=False
# Organised, current manifest; keep a useful note inside Blender as well.
for record in ASSETS:
 root=bpy.data.objects[record['root']];collection=bpy.data.collections[record['collection']]
 record['parts']=len(collection.all_objects)-1
 record['location_metres']=list(root.location)
 record['revision']='Detailed Review 02'
with open(os.path.join(BASE,'asset-manifest.json'),'w',encoding='utf-8') as f:json.dump(ASSETS,f,indent=2)
readme='SCHOOL ASSET LIBRARY — DETAILED REVIEW 02\n\nSchool name remains undecided. Only the supplied white bird emblem is used.\n\n38 assets in MCP > School Assets | Detailed Review 02, organised into ten category collections. Each asset has a named parent for moving it as a unit. Detail parts remain editable.\n\nMaterials: procedural wood grain, fabric weave, powder coat, plastics, brushed metal, ceramic and foliage. The user-supplied logo is packed into this .blend.\n\nThe original simple revision is preserved separately. This file is the detailed Blender review source.\n\nPreview images are in the adjacent renders folder. Cameras for each group are in Presentation.\n'
txt=bpy.data.texts.get('START HERE - School asset library') or bpy.data.texts.new('START HERE - School asset library');txt.clear();txt.write(readme)
with open(os.path.join(BASE,'README.txt'),'w',encoding='utf-8') as f:f.write(readme)
# Verify no unconfirmed school-name text remains on scene objects.
name_text=[o.name for o in scene.objects if o.type=='FONT' and ('WREN' in o.data.body.upper().replace(' ',''))]
missing=[im.filepath for im in bpy.data.images if im.source=='FILE' and not im.packed_file and not os.path.exists(bpy.path.abspath(im.filepath))]
assert not name_text,name_text
assert not missing,missing
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BASE,'School_Asset_Library_v02.blend'))
print(json.dumps({'saved_file':bpy.data.filepath,'assets':len(ASSETS),'scene_objects':len(scene.objects),'mesh_objects':sum(o.type=='MESH' for o in LIB.all_objects),'base_polygons':sum(len(o.data.polygons) for o in LIB.all_objects if o.type=='MESH'),'unconfirmed_brand_text':name_text,'missing_images':missing,'logo_packed':bool(image.packed_file)}))
