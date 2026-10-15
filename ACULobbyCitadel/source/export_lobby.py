"""Export the loaded ACU lobby from a separate Blender background process.

Usage:
  blender -b ACU_Festival_Citadel.blend --python source/export_lobby.py
  Optional script arguments after --: --output PATH --max-triangles 9000 --chunk-size 48

This script mutates only the loaded background session, NEVER saves a blend file.
Geometry is baked in Blender Z-up coordinates; FBX/GLB export to Y-up.
"""
import argparse
import ast
import bmesh
import bpy
import datetime
import json
import math
import os
from pathlib import Path
import re
import shutil
import struct
import sys
import time
import zlib
from collections import defaultdict
from array import array
import numpy as np

SOURCE_DIR = Path(__file__).resolve().parent
ROOT = SOURCE_DIR.parent
EXCLUDED = ('82_Backdrop', '80_Lighting', '81_Cameras', '90_InteractionMarkers', '99_References')
SOURCE_TYPES = {'MESH', 'FONT', 'CURVE', 'SURFACE', 'META'}
GLOW_KEYS = {'cyanGlow', 'purpleGlow', 'goldGlow', 'holo'}


def read_palette():
    tree = ast.parse((SOURCE_DIR / 'common.py').read_text(encoding='utf-8-sig'))
    for statement in tree.body:
        if isinstance(statement, ast.Assign):
            if any(isinstance(t, ast.Name) and t.id == 'PALETTE' for t in statement.targets):
                return ast.literal_eval(statement.value)
    raise RuntimeError('common.PALETTE was not found.')


def clean_name(value):
    return re.sub(r'[^A-Za-z0-9_]+', '_', value).strip('_')[:95] or 'Unnamed'


def collection_name(ob):
    names = [c.name.split('|')[-1].strip() for c in ob.users_collection]
    names = sorted(n for n in names if not n.startswith('EXPORT_'))
    return names[0] if names else '00_Unsorted'


def excluded(ob):
    return any(any(c.name.split('|')[-1].strip().startswith(prefix) for prefix in EXCLUDED)
               for c in ob.users_collection)


def png_chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)


def srgb_byte(linear):
    x = max(0.0, min(1.0, float(linear)))
    x = 12.92*x if x <= .0031308 else 1.055*(x ** (1/2.4))-.055
    return round(255*x)


def write_atlas(path, palette):
    # PNG scan lines run top to bottom; UV cell row zero starts at the bottom.
    colors = [bytes([srgb_byte(c) for c in col] + [255]) for col in palette.values()]
    colors += [bytes((15,18,30,255))] * (32-len(colors))
    rows = []
    for top_y in range(512):
        cell_y = 3-top_y//128
        row = b''.join(colors[cell_y*8+x]*128 for x in range(8))
        rows.append(b'\x00'+row)
    raw = b''.join(rows)
    header = struct.pack('>IIBBBBB', 1024,512,8,6,0,0,0)
    data = b'\x89PNG\r\n\x1a\n'+png_chunk(b'IHDR',header)+png_chunk(b'sRGB',b'\x00')
    data += png_chunk(b'IDAT',zlib.compress(raw,7))+png_chunk(b'IEND',b'')
    path.write_bytes(data)


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding='utf-8')


def material_image(mat):
    if not mat or not mat.use_nodes:
        return None
    for node in mat.node_tree.nodes:
        if node.type == 'TEX_IMAGE' and node.image is not None:
            return node.image
    return None


def principled(mat):
    if mat and mat.use_nodes:
        return next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    return None


class Exporter:
    def __init__(self, output, max_triangles, chunk_size):
        self.output = Path(output)
        self.output.mkdir(parents=True, exist_ok=True)
        self.tex_dir = self.output / 'textures'
        self.tex_dir.mkdir(exist_ok=True)
        self.palette = read_palette()
        # Read the saved scene's actual colors, without importing common/init().
        for key in list(self.palette):
            mat = bpy.data.materials.get('ACU_' + key)
            bs = principled(mat)
            if bs is not None and not bs.inputs['Base Color'].is_linked:
                self.palette[key] = tuple(bs.inputs['Base Color'].default_value[:3])
            elif mat is not None:
                self.palette[key] = tuple(mat.diffuse_color[:3])
        self.keys = list(self.palette)
        self.max_triangles = max_triangles
        self.chunk_size = chunk_size
        self.materials = {}
        self.material_uv = {}
        self.material_maps = {}
        self.uv_projection_fallbacks = []
        self.image_copies = {}
        self.buckets = {}
        self.part_counts = defaultdict(int)
        self.mesh_records = []
        self.objects = []
        self.pending_meshes = []
        self.evaluated_temporaries = []
        self.source_objects = []
        self.warnings = []
        self.removed_faces = 0
        self.source_triangles = 0
        self.atlas_images = {}
        self.atlas_dirty = True
        self.collection = bpy.data.collections.new('EXPORT_ACU_LOBBY')
        bpy.context.scene.collection.children.link(self.collection)
        self.atlas_for_page(0)

    def atlas_for_page(self, page):
        if page not in self.atlas_images:
            name = 'ACU_Palette_1024x512.png' if page == 0 else 'ACU_Palette_%02d_1024x512.png' % (page+1)
            path = self.tex_dir / name
            entries = dict(list(self.palette.items())[page*32:(page+1)*32])
            write_atlas(path, entries)
            image = bpy.data.images.load(str(path), check_existing=False)
            image.colorspace_settings.name = 'sRGB'
            self.atlas_images[page] = image
        return self.atlas_images[page]

    def refresh_atlases(self):
        pages = max(1, (len(self.palette)+31)//32)
        for page in range(pages):
            image = self.atlas_for_page(page)
            entries = dict(list(self.palette.items())[page*32:(page+1)*32])
            write_atlas(Path(bpy.path.abspath(image.filepath)), entries)
            image.reload()
        self.atlas_dirty = False

    def get_material(self, source_mat, source_ob):
        image = material_image(source_mat)
        # Logo texture detection takes priority over legacy ACU_Material tags.
        if image is not None:
            key = 'image__' + clean_name(source_mat.name)
            if key not in self.materials:
                source_uv_names = {node.uv_map for node in source_mat.node_tree.nodes
                                   if node.type == 'UVMAP' and node.uv_map}
                if len(source_uv_names) > 1:
                    raise RuntimeError('PBR material uses multiple named UV maps: '+source_mat.name)
                source_uv = next(iter(source_uv_names), None)
                mat = source_mat.copy()
                mat.name = 'ACU_EXPORT_' + key
                mat.use_backface_culling = False
                for node in mat.node_tree.nodes:
                    if node.type == 'TEX_IMAGE' and node.image is not None:
                        node.image = self.copy_image(node.image)
                    elif node.type == 'UVMAP':
                        node.uv_map = 'UVMap'
                    elif node.type == 'NORMAL_MAP' and node.space == 'TANGENT':
                        node.uv_map = 'UVMap'
                self.material_uv[key] = source_uv
                self.material_maps[key] = self.describe_pbr_maps(source_mat, mat, source_uv)
                self.materials[key] = mat
            return key, self.materials[key], True

        tag = source_mat.name.removeprefix('ACU_') if source_mat else str(source_ob.get('ACU_Material', 'stone'))
        source_bs = principled(source_mat)
        if source_bs is not None and source_bs.inputs['Base Color'].is_linked:
            raise RuntimeError('Unbaked procedural color on '+source_mat.name+'; preserve it with a texture before exporting.')
        rgb = tuple(source_bs.inputs['Base Color'].default_value[:3]) if source_bs else (
            tuple(source_mat.diffuse_color[:3]) if source_mat else tuple(self.palette.get(tag, self.palette['stone'])))
        if tag not in self.palette:
            # Extra colors receive their own atlas cells; never quantize to a nearby color.
            self.palette[tag] = rgb
            self.keys.append(tag)
            self.atlas_dirty = True
        elif tuple(self.palette[tag]) != rgb:
            self.palette[tag] = rgb
            self.atlas_dirty = True
        if tag not in self.materials:
            mat = bpy.data.materials.new('ACU_EXPORT_' + tag)
            mat.use_nodes = True
            mat.diffuse_color = (1,1,1,1)
            mat.use_backface_culling = False
            mat['ACU_PaletteKey'] = tag
            bs = principled(mat)
            if source_bs:
                # Preserve original PBR and emission parameters, including their distinct tint.
                for socket in bs.inputs:
                    original = source_bs.inputs.get(socket.name)
                    if original is None or not hasattr(original, 'default_value') or not hasattr(socket, 'default_value'):
                        continue
                    if original.is_linked:
                        continue
                    try:
                        value = original.default_value
                        socket.default_value = value[:] if hasattr(value, '__len__') else value
                    except (TypeError,ValueError):
                        pass
            else:
                bs.inputs['Roughness'].default_value = .7
            bs.inputs['Base Color'].default_value = (1,1,1,1)
            tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
            tex.image = self.atlas_for_page(self.keys.index(tag)//32)
            tex.interpolation = 'Closest'
            mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
            self.materials[tag] = mat
        return tag, self.materials[tag], False

    def describe_pbr_maps(self, original, copied, source_uv):
        def image_for_socket(socket, visited=None):
            if socket is None or not socket.is_linked:
                return None
            visited = set() if visited is None else visited
            node = socket.links[0].from_node
            if node.name in visited:
                return None
            visited.add(node.name)
            if node.type == 'TEX_IMAGE':
                return node.image
            # Follow NormalMap and optional color multiply nodes without dropping maps.
            candidates = [inp for inp in node.inputs if inp.is_linked]
            for inp in candidates:
                result = image_for_socket(inp, visited)
                if result is not None:
                    return result
            return None
        shader = principled(copied)
        channels = {'ColorMap':'Base Color','NormalMap':'Normal',
                    'RoughnessMap':'Roughness','MetalnessMap':'Metallic'}
        maps = {}
        if shader:
            for channel, socket_name in channels.items():
                image = image_for_socket(shader.inputs.get(socket_name))
                if image is not None:
                    maps[channel] = 'textures/'+Path(image.filepath).name
        tint_nodes = [node for node in original.node_tree.nodes
                      if node.type == 'MIX_RGB' and node.blend_type == 'MULTIPLY']
        if tint_nodes:
            self.warnings.append('Material %s includes a color multiply node. The shader is preserved, but glTF/FBX tint conversion should be checked; direct image links are recommended.' % original.name)
        return {'sourceMaterial':original.name,'exportMaterial':copied.name,
                'sourceUV':source_uv or '<active>','exportUV':'UVMap',
                'SurfaceAppearance':maps,'allImageMaps':[
                    'textures/'+Path(node.image.filepath).name
                    for node in copied.node_tree.nodes
                    if node.type == 'TEX_IMAGE' and node.image is not None],
                'colorMultiplyRequiresCheck':bool(tint_nodes)}

    def copy_image(self, image):
        if image.name in self.image_copies:
            return self.image_copies[image.name]
        source = Path(bpy.path.abspath(image.filepath)) if image.filepath else None
        suffix = source.suffix.lower() if source and source.suffix.lower() in ('.png','.jpg','.jpeg','.tga','.bmp') else '.png'
        target = self.tex_dir / (clean_name(image.name.rsplit('.',1)[0]) + suffix)
        if source and source.is_file():
            if source.resolve() != target.resolve():
                shutil.copy2(source, target)
            clone = bpy.data.images.load(str(target), check_existing=False)
        else:
            target = target.with_suffix('.png')
            clone = image.copy()
            clone.filepath_raw = str(target)
            clone.file_format = 'PNG'
            clone.save()
        # Roughness and tangent normal maps must remain Non-Color data.
        clone.colorspace_settings.name = image.colorspace_settings.name
        clone.alpha_mode = image.alpha_mode
        self.image_copies[image.name] = clone
        return clone

    def palette_uv(self, key):
        k = self.keys.index(key) % 32
        return ((k%8+.5)/8, (k//8+.5)/4)

    def add_triangle(self, key, mat, source_id, source_name, coords, vertex_ids, uv, normals, smooth, doublesided):
        group, material_key, sx, sy, sz, _ = key
        bucket = self.buckets.get(key)
        if bucket is None:
            bucket = {'vertices':[], 'faces':[], 'uv':array('f'), 'normals':array('f'), 'smooth':[], 'lookup':{}, 'sources':set(), 'material':mat}
            self.buckets[key] = bucket
        face = []
        for co, original in zip(coords,vertex_ids):
            vertex_key = (source_id, original)
            index = bucket['lookup'].get(vertex_key)
            if index is None:
                index = len(bucket['vertices'])
                bucket['lookup'][vertex_key] = index
                bucket['vertices'].append(co)
            face.append(index)
        bucket['faces'].append(tuple(face))
        for value in uv:
            bucket['uv'].extend(value)
        for value in normals:
            bucket['normals'].extend(value)
        bucket['smooth'].append(smooth)
        bucket['sources'].add(source_name)
        if len(bucket['faces']) >= self.max_triangles:
            self.flush(key)

    def flush(self, key):
        bucket = self.buckets.pop(key, None)
        if not bucket or not bucket['faces']:
            return
        group, material_key, sx, sy, sz, doublesided = key
        self.part_counts[key] += 1
        cell = 'X%s_Y%s_Z%s' % (str(sx).replace('-','m'),str(sy).replace('-','m'),str(sz).replace('-','m'))
        name = clean_name('ACU_%s_%s_%s_%03d%s' % (group,material_key,cell,self.part_counts[key],'_DS' if doublesided else ''))
        # Keep pure Python geometry only; even orphan mesh creation dirties depsgraph.
        assert len(bucket['faces']) <= self.max_triangles
        bucket.pop('lookup', None)
        self.pending_meshes.append((name, bucket, {
            'ACU_Collection':group, 'ACU_Material':material_key,
            'ACU_DoubleSided':bool(doublesided),
            'ACU_TriangleCount':len(bucket['faces']),
            'ACU_Collision':'Use separate lobby collision proxy'}))
        self.mesh_records.append({
            'name':name, 'collection':group, 'material':material_key,
            'triangles':len(bucket['faces']), 'vertices':len(bucket['vertices']),
            'doubleSided':bool(doublesided), 'sources':sorted(bucket['sources']),
            'boundsBlender':[[min(v[i] for v in bucket['vertices']) for i in range(3)],
                             [max(v[i] for v in bucket['vertices']) for i in range(3)]]
        })

    def materialize_export_objects(self):
        # Source extraction has ended. Consume each packed chunk while constructing
        # the export meshes, freeing Python geometry as soon as Blender owns it.
        self.pending_meshes.reverse()
        count = len(self.pending_meshes)
        while self.pending_meshes:
            name, bucket, props = self.pending_meshes.pop()
            me = bpy.data.meshes.new(name)
            me.from_pydata(bucket['vertices'], [], bucket['faces'])
            me.materials.append(bucket['material'])
            uv = me.uv_layers.new(name='UVMap')
            uv.data.foreach_set('uv', bucket['uv'])
            me.polygons.foreach_set('use_smooth', bucket['smooth'])
            me.update()
            if hasattr(me, 'use_auto_smooth'):
                me.use_auto_smooth = True
            normals = np.frombuffer(bucket['normals'], dtype=np.float32).reshape((-1, 3))
            me.normals_split_custom_set(normals)
            ob = bpy.data.objects.new(name, me)
            self.collection.objects.link(ob)
            for key, value in props.items():
                ob[key] = value
            self.objects.append(ob)
            if len(self.objects) % 150 == 0:
                print('EXPORT_LINK_PROGRESS %d/%d meshes' % (len(self.objects),count),flush=True)
        bpy.context.view_layer.update()

    def process_object(self, ob, source_id, depsgraph):
        group = collection_name(ob)
        plain_mesh = (ob.type == 'MESH' and ob.data.shape_keys is None
                      and not any(mod.show_viewport for mod in ob.modifiers))
        if plain_mesh:
            me = ob.data
            world = ob.matrix_world
        else:
            evaluated = ob.evaluated_get(depsgraph)
            world = evaluated.matrix_world
            if evaluated.type == 'MESH':
                me = evaluated.data
            else:
                me = evaluated.to_mesh(preserve_all_data_layers=True, depsgraph=depsgraph)
                if me is None:
                    self.warnings.append('No evaluated geometry: '+ob.name)
                    return
                self.evaluated_temporaries.append(evaluated)
        # These calls calculate runtime caches only. No mesh copies/transforms,
        # bmesh writes, ID creation/removal or object linking occur in this pass.
        me.calc_loop_triangles()
        self.source_triangles += len(me.loop_triangles)
        local_coords = np.empty(len(me.vertices)*3, dtype=np.float32)
        me.vertices.foreach_get('co', local_coords)
        local_coords = local_coords.reshape((-1,3))
        wm = np.asarray(world, dtype=np.float64)
        world_coords = local_coords @ wm[:3,:3].T + wm[:3,3]
        if not np.isfinite(world_coords).all():
            raise RuntimeError('Non-finite geometry in '+ob.name)
        coords = [tuple(co) for co in world_coords]
        if hasattr(me, 'calc_normals_split'):
            me.calc_normals_split()
        normal_values = np.empty(len(me.loops)*3,dtype=np.float32)
        if hasattr(me, 'corner_normals'):
            me.corner_normals.foreach_get('vector',normal_values)
        else:
            me.loops.foreach_get('normal',normal_values)
        local_normals = normal_values.reshape((-1,3))
        normal_matrix = np.asarray(world.to_3x3().inverted_safe().transposed(),dtype=np.float64)
        world_normals = local_normals @ normal_matrix.T
        lengths = np.linalg.norm(world_normals,axis=1)
        lengths[lengths < 1e-20] = 1
        world_normals /= lengths[:,None]
        if not np.isfinite(world_normals).all():
            raise RuntimeError('Non-finite normals in '+ob.name)
        uv_layer = me.uv_layers.active
        material_cache = {}
        projection_axis_cache = {}
        polygon_materials = [poly.material_index for poly in me.polygons]
        polygon_smooth = [poly.use_smooth for poly in me.polygons]
        mirrored = world.to_3x3().determinant() < 0
        always_double = 'cape' in ob.name.lower() or bool(ob.get('ACU_DoubleSided',False))
        for triangle in me.loop_triangles:
            vs = tuple(triangle.vertices)
            loops = tuple(triangle.loops)
            if mirrored:
                vs = (vs[0],vs[2],vs[1])
                loops = (loops[0],loops[2],loops[1])
            tri = [coords[i] for i in vs]
            a,b,c = tri
            ux,uy,uz = b[0]-a[0],b[1]-a[1],b[2]-a[2]
            vx,vy,vz = c[0]-a[0],c[1]-a[1],c[2]-a[2]
            cx,cy,cz = uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
            if cx*cx+cy*cy+cz*cz <= 1e-24:
                self.removed_faces += 1
                continue
            material_index = polygon_materials[triangle.polygon_index]
            if material_index not in material_cache:
                source_mat = me.materials[material_index] if material_index < len(me.materials) else ob.active_material
                material_key,mat,textured = self.get_material(source_mat,ob)
                selected_uv = uv_layer
                projection_tile = None
                if textured:
                    required_uv = self.material_uv.get(material_key)
                    if required_uv:
                        selected_uv = me.uv_layers.get(required_uv)
                    if selected_uv is None:
                        tile = source_mat.get('ACU_TileSize') if source_mat else None
                        if tile is not None and float(tile) > 0:
                            # FONT/CURVE geometry did not exist during the source MESH UV pass.
                            # Generate the same world-space box projection in export buffers only.
                            projection_tile = float(tile)
                            self.uv_projection_fallbacks.append({
                                'object':ob.name,'sourceType':ob.type,
                                'material':source_mat.name,'requestedUV':required_uv,
                                'tileSize':projection_tile,'sourceModified':False})
                        else:
                            raise RuntimeError('Material '+source_mat.name+' requires missing UV layer '+str(required_uv)+' on '+ob.name+' and has no ACU_TileSize fallback.')
                material_cache[material_index] = (material_key,mat,textured,None if textured else self.palette_uv(material_key),selected_uv,projection_tile)
            material_key,mat,textured,constant_uv,selected_uv,projection_tile = material_cache[material_index]
            centroid = ((a[0]+b[0]+c[0])/3,(a[1]+b[1]+c[1])/3,(a[2]+b[2]+c[2])/3)
            sx = math.floor(centroid[0]/self.chunk_size)
            sy = math.floor(centroid[1]/self.chunk_size)
            sz = math.floor(centroid[2]/64)
            doublesided = always_double or 'logo' in material_key.lower()
            key = (group,material_key,sx,sy,sz,doublesided)
            if textured:
                if projection_tile is not None:
                    polygon_id = triangle.polygon_index
                    axis = projection_axis_cache.get(polygon_id)
                    if axis is None:
                        n = normal_matrix @ np.asarray(me.polygons[polygon_id].normal)
                        axis = int(np.argmax(np.abs(n)))
                        projection_axis_cache[polygon_id] = axis
                    axes = (0,1) if axis == 2 else ((0,2) if axis == 1 else (1,2))
                    uv = world_coords[list(vs)][:,axes] / projection_tile
                else:
                    if selected_uv is None:
                        raise RuntimeError('Textured object has no UV map: '+ob.name)
                    uv = [tuple(selected_uv.data[i].uv) for i in loops]
            else:
                uv = (constant_uv,constant_uv,constant_uv)
            self.add_triangle(key,mat,source_id,ob.name,tri,vs,uv,
                              [world_normals[i] for i in loops],
                              polygon_smooth[triangle.polygon_index],doublesided)

    def markers(self):
        result = []
        for ob in bpy.context.scene.objects:
            if ob.type == 'EMPTY' and (ob.get('ACU_Role') or any('90_InteractionMarkers' in c.name for c in ob.users_collection)):
                x,y,z = ob.matrix_world.translation
                result.append({'name':ob.name,'role':str(ob.get('ACU_Role','')),
                               'wired':bool(ob.get('ACU_Wired',False)),
                               'blender':[x,y,z], 'roblox':[x,z,-y],
                               'matrixWorldBlender':[list(row) for row in ob.matrix_world]})
        result.sort(key=lambda v:v['name'])
        return {'units':'1 Blender unit = 1 Roblox stud',
                'conversion':'Blender (X,Y,Z) to Roblox (X,Z,-Y)',
                'markers':result}

    def select_exports(self):
        bpy.ops.object.select_all(action='DESELECT')
        for ob in self.objects:
            ob.hide_set(False)
            ob.select_set(True)
        bpy.context.view_layer.objects.active = self.objects[0]

    def operator(self, name, addon=None):
        namespace,operator = name.split('.')
        op = getattr(getattr(bpy.ops,namespace),operator)
        try:
            op.get_rna_type()
            return op
        except Exception:
            if addon:
                try:
                    bpy.ops.preferences.addon_enable(module=addon)
                    op.get_rna_type()
                    return op
                except Exception:
                    pass
        return None

    def call_operator(self, operator, kwargs):
        allowed = set(operator.get_rna_type().properties.keys())
        if 'apply_scale_options' in kwargs:
            required = {'global_scale', 'apply_unit_scale', 'apply_scale_options',
                        'axis_forward', 'axis_up', 'bake_space_transform'}
            missing = required - allowed
            if missing:
                raise RuntimeError('FBX scale-critical options unavailable: ' + ', '.join(sorted(missing)))
        result = operator(**{key:value for key,value in kwargs.items() if key in allowed})
        if 'FINISHED' not in result:
            raise RuntimeError('Exporter did not finish: '+str(result))

    def run(self):
        bpy.context.view_layer.update()
        source_blend = bpy.data.filepath
        marker_data = self.markers()
        write_json(self.output/'markers.json',marker_data)
        objects = [ob for ob in bpy.context.scene.objects if ob.type in SOURCE_TYPES and not excluded(ob)]
        objects.sort(key=lambda ob:(collection_name(ob),ob.name))
        # Finish every export material/image mutation before source evaluation begins.
        seen_materials = set()
        for ob in objects:
            for slot in ob.material_slots:
                mat = slot.material
                if mat is not None and mat.name not in seen_materials:
                    self.get_material(mat, ob)
                    seen_materials.add(mat.name)
        bpy.context.view_layer.update()
        depsgraph = bpy.context.evaluated_depsgraph_get()
        previous_group = None
        processing_started = time.perf_counter()
        print('EXPORT_BEGIN %d source objects; no geometry decimation; deferred object linking' % len(objects),flush=True)
        for i,ob in enumerate(objects):
            group = collection_name(ob)
            if previous_group is not None and group != previous_group:
                for key in [key for key in self.buckets if key[0] == previous_group]:
                    self.flush(key)
            self.process_object(ob,i,depsgraph)
            previous_group = group
            if (i+1)%150 == 0:
                elapsed = time.perf_counter()-processing_started
                print('EXPORT_PROGRESS %d/%d source objects | %.1fs | %.1f objects/s' %
                      (i+1,len(objects),elapsed,(i+1)/max(elapsed,.001)),flush=True)
        for key in list(self.buckets):
            self.flush(key)
        for evaluated in self.evaluated_temporaries:
            evaluated.to_mesh_clear()
        self.evaluated_temporaries.clear()
        print('EXPORT_LINKING %d completed meshes' % len(self.pending_meshes),flush=True)
        self.materialize_export_objects()
        if not self.objects:
            raise RuntimeError('No geometry was available to export.')
        self.refresh_atlases()
        assert all(v['triangles'] <= self.max_triangles for v in self.mesh_records)
        self.select_exports()
        outputs = {}
        failures = {}
        fbx = self.operator('export_scene.fbx','io_scene_fbx')
        if fbx:
            path = self.output/'ACU_Citadel_Roblox.fbx'
            try:
                self.call_operator(fbx,dict(filepath=str(path),use_selection=True,object_types={'MESH'},
                    global_scale=0.01,apply_unit_scale=False,apply_scale_options='FBX_SCALE_NONE',
                    axis_forward='-Z',axis_up='Y',use_space_transform=True,bake_space_transform=True,
                    use_mesh_modifiers=False,mesh_smooth_type='FACE',use_tspace=False,
                    bake_anim=False,use_custom_props=True,path_mode='COPY',embed_textures=True,
                    add_leaf_bones=False))
                outputs['fbx'] = path.name
            except Exception as exc:
                failures['fbx'] = str(exc)
        else:
            failures['fbx'] = 'Standard FBX operator unavailable, even after enabling io_scene_fbx.'

        gltf = self.operator('export_scene.gltf','io_scene_gltf2')
        if gltf:
            path = self.output/'ACU_Citadel_Roblox.glb'
            try:
                self.call_operator(gltf,dict(filepath=str(path),export_format='GLB',use_selection=True,
                    export_yup=True,export_apply=False,export_materials='EXPORT',export_texcoords=True,
                    export_normals=True,export_colors=False,export_animations=False,export_extras=True,
                    export_cameras=False,export_lights=False))
                outputs['glb'] = path.name
            except Exception as exc:
                failures['glb'] = str(exc)
        else:
            failures['glb'] = 'Standard glTF operator unavailable.'

        for kind,filename in list(outputs.items()):
            path = self.output/filename
            if not path.is_file() or path.stat().st_size < 256:
                failures[kind] = 'Exporter produced no usable file.'
                outputs.pop(kind)
        atlas = [{'key':key,'linearRGB':list(value),'srgbRGB':[srgb_byte(v) for v in value],
                  'uv':list(self.palette_uv(key)), 'atlasPage':self.keys.index(key)//32} for key,value in self.palette.items()]
        manifest = {
            'sourceBlend':source_blend,
            'generatedUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'blenderVersion':bpy.app.version_string,
            'editableBlendSaved':False,
            'outputs':outputs,'exportFailures':failures,
            'sourceObjects':len(objects),'exportMeshes':len(self.mesh_records),
            'sourceTrianglesBeforeCleanup':self.source_triangles,'zeroAreaTrianglesRemoved':self.removed_faces,
            'decimationApplied':False,'sourceLoopNormalsPreserved':True,
            'triangles':sum(v['triangles'] for v in self.mesh_records),
            'maximumMeshTriangles':max(v['triangles'] for v in self.mesh_records),
            'triangleLimit':self.max_triangles,'spatialCellSize':self.chunk_size,
            'paletteTexture':'textures/ACU_Palette_1024x512.png',
            'paletteTextures':['textures/'+Path(image.filepath).name for _,image in sorted(self.atlas_images.items())],
            'paletteColorSource':'Actual saved scene material Base Color; common.PALETTE only for fallback/order',
            'palette':atlas,'PBRMaterials':self.material_maps,'excludedCollections':list(EXCLUDED),
            'exportOnlyUVProjections':self.uv_projection_fallbacks,
            'markers':len(marker_data['markers']),
            'coordinateConversion':'Blender (X,Y,Z) -> Roblox (X,Z,-Y); origin preserved',
            'robloxImport':{'unitScale':1,'visualCanCollide':False,'anchored':True,
                             'textures':'Import included textures; leave MeshPart Color white',
                             'doubleSided':'Enable DoubleSided on meshes whose metadata is true',
                             'collision':'Import the separately supplied collision proxy'},
            'warnings':sorted(set(self.warnings)),'meshes':self.mesh_records}
        write_json(self.output/'export_manifest.json',manifest)
        notes = [
            'ACU FESTIVAL CITADEL — EXPORT PACKAGE',
            '',
            'The editable Blender source was not overwritten.',
            'Import ACU_Citadel_Roblox.fbx into Roblox at unit scale 1.',
            'All visual meshes are at most %d triangles. Geometry was split without decimation.' % self.max_triangles,
            'Use the included textures folder; keep MeshPart Color white.',
            'PBR material ColorMap, NormalMap, RoughnessMap and MetalnessMap paths are listed in export_manifest.json under PBRMaterials for Roblox SurfaceAppearance.',
            'Normal/roughness maps retain Non-Color settings. Original DetailUV coordinates are exported as UVMap.',
            'Visual geometry should be Anchored with CanCollide false.',
            'Use the separately supplied collision model for movement.',
            'Set DoubleSided true only for meshes whose doubleSided metadata is true in export_manifest.json.',
            'markers.json provides interaction anchors; no gameplay handlers are wired.',
            'The FBX and GLB use Y-up; marker Roblox coordinates are (X,Z,-Y).',
            'The GLB is an additional portable preview/export, not a replacement for the FBX.',
            '',
            'Export failures: '+json.dumps(failures),
        ]
        (self.output/'IMPORT_README.txt').write_text('\n'.join(notes),encoding='utf-8')
        print('EXPORT_COMPLETE '+json.dumps({k:manifest[k] for k in ('outputs','exportFailures','sourceObjects','exportMeshes','triangles','maximumMeshTriangles','markers')}),flush=True)
        if 'fbx' not in outputs:
            raise RuntimeError('Required FBX export failed; see export_manifest.json.')
        return manifest


def main():
    argv = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument('--output',default=str(ROOT/'exports'))
    parser.add_argument('--max-triangles',type=int,default=9000)
    parser.add_argument('--chunk-size',type=float,default=48)
    args = parser.parse_args(argv)
    if not 1 <= args.max_triangles <= 9000:
        raise ValueError('max-triangles must be between 1 and 9000.')
    if args.chunk_size <= 0:
        raise ValueError('chunk-size must be positive.')
    Exporter(args.output,args.max_triangles,args.chunk_size).run()


if __name__ == '__main__':
    main()
