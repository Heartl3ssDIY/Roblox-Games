from common import *
import landscape_fixes
def build():
    bpy.context.view_layer.update()
    name='50_City_WesternWard9'
    c=bpy.data.collections.get('ACU | '+name)
    if c:
        rect=landscape_fixes._rect_for_collection(c)
        cx=(rect[0]+rect[1])/2;cy=(rect[2]+rect[3])/2
        if cy>100:
            occupied=[r for n,r in landscape_fixes._building_rects() if n!=name]
            hx=(rect[1]-rect[0])/2+5;hy=(rect[3]-rect[2])/2+5
            for x,y in [(-144,-229),(-144,-264),(-185,-240),(-105,-249)]:
                if all(x+hx<r[0] or x-hx>r[1] or y+hy<r[2] or y-hy>r[3] for r in occupied):
                    landscape_fixes._shift_objects(c.objects,(x-cx,y-cy,0))
                    print('Moved cliff-intersecting ward to',x,y);break
            else:raise RuntimeError('No clear replacement site for WesternWard9')
    # The larger shadow pool avoids missing shadows in the dense districts.
    s=bpy.context.scene;s.eevee.shadow_pool_size='1024'
    cam=bpy.data.objects.get('CAM_10_Waterfall')
    if cam:
        cam.location=(-290,40,25);cam.rotation_euler=(Vector((-239,130,32))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=31
    # Keep all source references and signage portable in the saved file.
    s.render.resolution_x=2400;s.render.resolution_y=1500;s.render.resolution_percentage=100
    bpy.context.view_layer.update()

    cam=bpy.data.objects.get('CAM_12_GrandEntrance')
    if cam:
        cam.location=(0,-285,11);cam.rotation_euler=(Vector((0,-128,17))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=31
    for ob in s.objects:
        if ob.type=='MESH' and any(m and 'Logo_Texture' in m.name for m in ob.data.materials):
            me=ob.data;lo=min(v.co.x for v in me.vertices);hi=max(v.co.x for v in me.vertices);bottom=min(v.co.z for v in me.vertices);top=max(v.co.z for v in me.vertices)
            uv=me.uv_layers.active
            for p in me.polygons:
                for li in p.loop_indices:
                    v=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=((v.x-lo)/(hi-lo),(v.z-bottom)/(top-bottom))
