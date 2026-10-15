import bpy,os,json
state=bpy.app.driver_namespace['cardboard_bake'];plane=state['plane'];scene=bpy.context.scene
for ob in scene.objects:ob.select_set(False)
plane.select_set(True);bpy.context.view_layer.objects.active=plane
done=[]
for material in state['materials']:
    if material.get('BakedCardboard'):continue
    nt=material.node_tree;n=nt.nodes;l=nt.links
    bsdf=next(x for x in n if x.type=='BSDF_PRINCIPLED');output=next(x for x in n if x.type=='OUTPUT_MATERIAL')
    image=bpy.data.images.new(material.name+'_Colour',width=1024,height=1024)
    target=n.new('ShaderNodeTexImage');target.image=image;n.active=target
    emit=n.new('ShaderNodeEmission');l.new(n[material['BakeRamp']].outputs[0],emit.inputs['Color']);l.new(emit.outputs[0],output.inputs['Surface'])
    plane.data.materials.clear();plane.data.materials.append(material)
    bpy.ops.object.bake(type='EMIT')
    image.filepath_raw=os.path.join(state['out'],material.name+'.png');image.file_format='PNG';image.save()
    l.new(bsdf.outputs[0],output.inputs['Surface']);n.remove(emit)
    l.new(target.outputs['Color'],bsdf.inputs['Base Color'])
    material['BakedCardboard']=True
    done.append(material.name)
    if len(done)==2:break
print(json.dumps({'baked':done}))
