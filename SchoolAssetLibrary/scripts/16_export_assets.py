import re, collections
EXSCENE=bpy.data.scenes.new('Roblox import meshes')
EXPORT_RECORDS=[]
LOGOMATS={}
MARKMAT=bpy.data.materials.new('Setup markers - removed by installer');MARKMAT.diffuse_color=(1,.1,0,1)

def portable(src):
    if src.name in PMAT:return PMAT[src.name]
    if src.name in LOGOMATS:return LOGOMATS[src.name]
    m=bpy.data.materials.new('Portable bird emblem');m.use_nodes=True
    n=m.node_tree.nodes;L=m.node_tree.links;p=next(x for x in n if x.type=='BSDF_PRINCIPLED')
    tex=n.new('ShaderNodeTexImage');tex.image=image
    p.inputs['Base Color'].default_value=(1,1,1,1);p.inputs['Roughness'].default_value=.5
    L.new(tex.outputs['Color'],p.inputs['Base Color']);L.new(tex.outputs['Alpha'],p.inputs['Alpha'])
    m.surface_render_method='DITHERED';LOGOMATS[src.name]=m
    return m

def marker(name,loc):
    # Three reference markers recover orientation/scale even after moving a Studio model.
    s=.008;verts=[(x*s,y*s,z*s) for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]);me.materials.append(MARKMAT)
    o=bpy.data.objects.new(name,me);EXSCENE.collection.objects.link(o);o.location=loc
    return o

def export_asset(ai):
    bpy.context.window.scene=scene;bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
    a=ASSETS[ai-1];aid='SA%02d'%ai;aroot=bpy.data.objects[a['root']];inv=aroot.matrix_world.inverted()
    objects=[];bodies=[];totaltri=0
    for b in [b for b in BODYDATA if b['asset_id']==aid]:
        chunks=collections.defaultdict(list);bbox=[];collision=[]
        for oname in b['parts']:
            ob=bpy.data.objects[oname];ev=ob.evaluated_get(deps)
            me=bpy.data.meshes.new_from_object(ev,preserve_all_data_layers=True,depsgraph=deps)
            if not me or not me.vertices:continue
            me.calc_loop_triangles();tr=inv@ob.matrix_world;nm=tr.to_3x3().inverted().transposed()
            local=[v.co.copy() for v in me.vertices]
            lo=Vector([min(v[i] for v in local) for i in range(3)]);hi=Vector([max(v[i] for v in local) for i in range(3)])
            span=hi-lo;span=Vector([max(.00001,x) for x in span])
            verts=[tr@v for v in local];bbox.extend(verts)
            olo=Vector([min(v[i] for v in verts) for i in range(3)]);ohi=Vector([max(v[i] for v in verts) for i in range(3)])
            # Cabinet and pot walls stay separate so their interiors are usable.
            if any(t in oname for t in ['cabinet side','Cabinet back','horizontal panel','oak shelf','Tray unit','Tray divider','Pot base','Pot side','Tray bottom','Tray side','Tray rear','Tray front']):
                collision.append({'center':list((olo+ohi)/2),'size':list(ohi-olo)})
            normals=[(nm@n.vector).normalized() for n in me.corner_normals]
            for tri in me.loop_triangles:
                src=me.materials[tri.material_index] if len(me.materials)>tri.material_index else MAT['black']
                mat=portable(src);items=chunks[mat.name]
                if not items or len(items[-1])>=18000:items.append([])
                axis=max(range(3),key=lambda i:abs(tri.normal[i]));axes=[i for i in range(3) if i!=axis]
                corners=[]
                for vi,li in zip(tri.vertices,tri.loops):
                    if me.uv_layers and src.name not in PMAT:uv=tuple(me.uv_layers.active.data[li].uv)
                    else:uv=tuple(max(0,min(1,(local[vi][i]-lo[i])/span[i])) for i in axes)
                    corners.append((tuple(verts[vi]),tuple(normals[li]),uv))
                items[-1].append(corners)
            bpy.data.meshes.remove(me)
        assert bbox,b['id']
        low=Vector([min(v[i] for v in bbox) for i in range(3)]);high=Vector([max(v[i] for v in bbox) for i in range(3)])
        if b['label']=='Round graphite pencil pot':
            collision=[{'center':[0,0,.005],'size':[.13,.13,.01]}]
            for i in range(12):
                ang=2*math.pi*i/12
                collision.append({'center':[.065*math.cos(ang),.065*math.sin(ang),.06],'size':[.023,.023,.11]})
        # Rigid objects use a simple bounding collision shell; render detail does not drive physics.
        if not collision:collision=[{'center':list((low+high)/2),'size':list(high-low)}]
        info={k:v for k,v in b.items() if k not in ['parts','root','asset_root']};info['collision']=collision;info['bounds']={'min':list(low),'max':list(high)}
        bodies.append(info)
        count=0
        for matname,cs in chunks.items():
            for tris in cs:
                count+=1;name=b['id']+'_M%02d'%count
                v=[];f=[];uvs=[];nors=[];lookup={}
                for tri in tris:
                    inds=[]
                    for pos,norm,uv in tri:
                        key=pos+norm+uv
                        if key not in lookup:lookup[key]=len(v);v.append(pos)
                        inds.append(lookup[key]);uvs.append(uv);nors.append(norm)
                    f.append(inds)
                me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.materials.append(bpy.data.materials[matname]);me.update()
                uv=me.uv_layers.new(name='UVMap')
                for i,co in enumerate(uvs):uv.data[i].uv=co
                for p in me.polygons:p.use_smooth=True
                me.normals_split_custom_set(nors)
                ob=bpy.data.objects.new(name,me);EXSCENE.collection.objects.link(ob);objects.append(ob);totaltri+=len(f)
    objects += [marker(aid+'_REF_O',(0,0,0)),marker(aid+'_REF_X',(.1,0,0)),marker(aid+'_REF_Y',(0,.1,0))]
    bpy.context.window.scene=EXSCENE
    for o in EXSCENE.objects:o.select_set(False)
    for o in objects:o.select_set(True)
    EXSCENE.view_layers[0].objects.active=objects[0]
    filename=aid+'_'+re.sub('[^A-Za-z0-9]+','_',a['name']).strip('_')+'.gltf'
    bpy.ops.export_scene.gltf(filepath=os.path.join(EXPORT,filename),export_format='GLTF_SEPARATE',export_texture_dir='textures',use_selection=True,use_active_scene=True,export_yup=True,export_apply=False,export_animations=False,export_cameras=False,export_lights=False,export_extras=False,export_materials='EXPORT',export_image_format='AUTO')
    rec={'id':aid,'name':a['name'],'file':filename,'mesh_count':len(objects)-3,'triangles':totaltri,'bodies':bodies};EXPORT_RECORDS.append(rec)
    # Keep an inspectable export scene arranged like the source library.
    parent=bpy.data.objects.new(aid+' '+a['name'],None);EXSCENE.collection.objects.link(parent);parent.location=aroot.location
    for o in objects:o.parent=parent
    bpy.context.window.scene=scene
    open(os.path.join(EXPORT,'manifest.json'),'w',encoding='utf-8').write(json.dumps(EXPORT_RECORDS,indent=2))
    print('Exported',aid,a['name'],len(objects)-3,'meshes',totaltri,'triangles')
