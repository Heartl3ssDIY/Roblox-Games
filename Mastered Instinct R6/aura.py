"""Detachable, mesh-based instinct aura for a Z-up classic R6 character.

The fighter faces -Y, feet are at Z=0, and hair reaches roughly Z=6.5.
Call build_aura(collection). All returned geometry belongs to Aura_CTRL;
hide the collection, or detach that root, to remove the entire effect.

Optional: set collection['AuraLoopEnabled'] = True before construction for
a subtle 90-frame breathing loop. Construction never changes scene time.
No world, camera, render, compositor, or global material settings are changed.
"""

import math
import random

import bpy
from mathutils import Vector


_OPACITY = "InstinctAuraOpacity"


def _material(name, colour, strength, opacity):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = (*colour, opacity)
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (520, 40)
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    transparent.location = (0, 100)
    emission = nodes.new("ShaderNodeEmission")
    emission.location = (0, -70)
    emission.inputs["Color"].default_value = (*colour, 1.0)
    emission.inputs["Strength"].default_value = strength
    attribute = nodes.new("ShaderNodeAttribute")
    attribute.attribute_name = _OPACITY
    attribute.location = (-440, 260)
    multiply = nodes.new("ShaderNodeMath")
    multiply.operation = "MULTIPLY"
    multiply.inputs[1].default_value = opacity
    multiply.location = (-200, 260)
    mix = nodes.new("ShaderNodeMixShader")
    mix.location = (280, 40)
    links = material.node_tree.links
    links.new(attribute.outputs["Fac"], multiply.inputs[0])
    links.new(multiply.outputs[0], mix.inputs[0])
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(emission.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], output.inputs["Surface"])

    # Select only enum values actually offered by the installed Blender.
    # Eevee needs a transparency-capable surface mode; Cycles uses the graph.
    for property_name, preferred in (
        ("surface_render_method", ("DITHERED", "BLENDED")),
        ("blend_method", ("HASHED", "BLEND")),
    ):
        prop = material.bl_rna.properties.get(property_name)
        if prop is not None:
            choices = {item.identifier for item in prop.enum_items}
            for value in preferred:
                if value in choices:
                    setattr(material, property_name, value)
                    break
    if hasattr(material, "use_transparent_shadow"):
        material.use_transparent_shadow = True
    return material


def _mesh(collection, root, name, vertices, faces, opacity, material):
    data = bpy.data.meshes.new(name + "_Mesh")
    data.from_pydata(vertices, [], faces)
    data.update()
    field = data.attributes.new(name=_OPACITY, type="FLOAT", domain="POINT")
    for element, value in zip(field.data, opacity):
        element.value = value
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    obj.parent = root
    data.materials.append(material)
    # These are illumination graphics, never opaque shadow-casting geometry.
    if hasattr(obj, "visible_shadow"):
        obj.visible_shadow = False
    obj["Role"] = "Detachable aura VFX; exclude from body/rig export"
    return obj


def _bezier(controls, t):
    a, b, c, d = map(Vector, controls)
    s = 1.0 - t
    return a * s ** 3 + b * (3.0 * s * s * t) + c * (3.0 * s * t * t) + d * t ** 3


def _ribbon(collection, root, name, controls, width, material, lean=0.0,
            y_offset=0.0, samples=30):
    """Five columns make a feathered core without a texture dependency."""
    vertices, faces, opacity = [], [], []
    columns = (-1.0, -0.46, 0.0, 0.46, 1.0)
    for row in range(samples + 1):
        t = row / samples
        p = _bezier(controls, t)
        ahead = _bezier(controls, min(1.0, t + 0.002))
        behind = _bezier(controls, max(0.0, t - 0.002))
        tangent = (ahead - behind).normalized()
        # Lateral in the front-facing XZ plane, with a little depth twist.
        across = Vector((tangent.z, lean * math.sin(t * math.pi), -tangent.x))
        across.normalize()
        # A fat lower-middle flame tightens continuously to a needle tip.
        shape = (0.14 + 1.30 * math.sin(math.pi * t) ** 0.7) * (1.0 - t) ** 0.52
        half_width = width * shape * 0.5
        length_fade = min(1.0, t * 7.0) * min(1.0, (1.0 - t) * 8.0)
        for column in columns:
            q = p + across * half_width * column
            q.y += y_offset
            vertices.append(tuple(q))
            edge_fade = max(0.0, 1.0 - abs(column)) ** 0.42
            opacity.append(edge_fade * length_fade)
    count = len(columns)
    for row in range(samples):
        for column in range(count - 1):
            a = row * count + column
            faces.append((a, a + 1, a + count + 1, a + count))
    return _mesh(collection, root, name, vertices, faces, opacity, material)


def _filament(collection, root, name, controls, thickness, material):
    """Thin tapered six-sided mesh strand, robust from oblique views."""
    vertices, faces, opacity = [], [], []
    samples, sides = 26, 6
    for row in range(samples + 1):
        t = row / samples
        p = _bezier(controls, t)
        p.y -= 0.07
        tangent = (_bezier(controls, min(1.0, t + 0.003)) -
                   _bezier(controls, max(0.0, t - 0.003))).normalized()
        across = tangent.cross(Vector((0.0, 1.0, 0.0))).normalized()
        other = tangent.cross(across).normalized()
        taper = math.sin(math.pi * t) ** 0.46
        radius = thickness * (0.10 + taper)
        for side in range(sides):
            angle = 2.0 * math.pi * side / sides
            q = p + radius * (math.cos(angle) * across + math.sin(angle) * other)
            vertices.append(tuple(q))
            opacity.append(taper)
    for row in range(samples):
        for side in range(sides):
            a = row * sides + side
            b = row * sides + (side + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    return _mesh(collection, root, name, vertices, faces, opacity, material)


def _spark(collection, root, name, location, size, material):
    x, y, z = location
    # A pair of intersecting tiny diamonds: restrained, not a particle cloud.
    vertices = [(x, y, z + size), (x + size * 0.25, y, z),
                (x, y, z - size), (x - size * 0.25, y, z),
                (x, y, z),
                (x, y + size * 0.25, z), (x, y - size * 0.25, z)]
    faces = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4),
             (0, 5, 4), (5, 2, 4), (2, 6, 4), (6, 0, 4)]
    return _mesh(collection, root, name, vertices, faces,
                 [0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0], material)


def _gentle_loop(obj, phase):
    """Object-only VFX animation. R6 body and its action are untouched."""
    for frame in (1, 16, 31, 46, 61, 76, 90):
        angle = (frame - 1) / 89.0 * math.tau + phase
        obj.location = (math.sin(angle) * 0.026, 0.0, math.cos(angle) * 0.043)
        obj.scale = (1.0 + math.sin(angle) * 0.012, 1.0,
                     1.0 + math.cos(angle) * 0.008)
        obj.keyframe_insert(data_path="location", frame=frame, group="Aura Breath")
        obj.keyframe_insert(data_path="scale", frame=frame, group="Aura Breath")
    # Restore static transforms without setting the scene's current frame.
    obj.location = (0.0, 0.0, 0.0)
    obj.scale = (1.0, 1.0, 1.0)
    obj["LoopFrames"] = "1-90; repeat the action for continuous VFX"


def build_aura(collection):
    """Create and return [Aura_CTRL, ...mesh objects] in the given collection."""
    root = bpy.data.objects.new("Aura_CTRL", None)
    collection.objects.link(root)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.32
    root["Effect"] = "Mastered Instinct / detachable rim flames"
    root["Detach"] = "Hide this collection or remove Aura_CTRL and its children"
    root["RobloxNote"] = "Preview meshes; rebuild emission/transparency in Roblox VFX"
    root["Front"] = "-Y; clear front chest and face"
    result = [root]

    cyan = _material("MI_Aura_Cyan_Veil", (0.085, 0.56, 1.0), 2.8, 0.36)
    ice = _material("MI_Aura_Ice_Core", (0.46, 0.88, 1.0), 3.5, 0.48)
    violet = _material("MI_Aura_Violet_Edge", (0.38, 0.10, 1.0), 2.6, 0.28)
    white = _material("MI_Aura_White_Filament", (0.79, 0.94, 1.0), 5.0, 0.84)
    spark_material = _material("MI_Aura_Sparks", (0.68, 0.88, 1.0), 6.0, 0.92)

    # Each four-point path is a deliberate flame gesture behind the silhouette.
    # Ten separate tongues leave large negative spaces: no enclosing aura shell.
    paths = [
        ("Left_Low", [(-1.03, 0.65, 0.20), (-2.80, 0.75, 0.85),
                      (-1.96, 0.80, 1.90), (-2.48, 0.74, 2.68)], 0.62),
        ("Right_Low", [(1.08, 0.62, 0.16), (2.72, 0.65, 1.00),
                       (1.98, 0.84, 1.65), (2.60, 0.72, 2.42)], 0.58),
        ("Left_Mid", [(-1.75, 0.84, 1.62), (-2.82, 0.92, 2.55),
                      (-2.45, 0.78, 3.20), (-2.72, 0.76, 4.13)], 0.68),
        ("Right_Mid", [(1.82, 0.91, 1.73), (2.86, 0.91, 2.48),
                       (2.26, 0.77, 3.33), (2.80, 0.82, 4.24)], 0.66),
        ("Left_Shoulder", [(-2.08, 1.02, 3.21), (-2.95, 1.00, 4.14),
                           (-2.14, 0.92, 4.88), (-2.54, 1.02, 5.78)], 0.63),
        ("Right_Shoulder", [(2.04, 1.02, 3.44), (2.88, 1.03, 4.34),
                            (2.17, 1.02, 4.98), (2.52, 1.04, 5.67)], 0.61),
        ("Left_Crown", [(-1.70, 1.10, 4.75), (-2.09, 1.16, 5.78),
                        (-1.25, 1.18, 6.04), (-1.50, 1.06, 6.96)], 0.56),
        ("Right_Crown", [(1.62, 1.10, 4.79), (2.00, 1.15, 5.72),
                         (1.18, 1.20, 6.27), (1.52, 1.12, 7.05)], 0.53),
        ("Crown_Left_Peak", [(-0.78, 1.20, 5.74), (-0.93, 1.21, 6.42),
                             (-0.38, 1.23, 6.38), (-0.60, 1.16, 7.18)], 0.41),
        ("Crown_Right_Peak", [(0.70, 1.23, 5.66), (0.92, 1.26, 6.39),
                              (0.25, 1.29, 6.67), (0.46, 1.20, 7.08)], 0.40),
    ]
    for index, (label, controls, width) in enumerate(paths):
        # Violet outer fringe, feathered cyan body, and a slender ice-white vein.
        outer = _ribbon(collection, root, "Aura_" + label + "_Violet",
                        controls, width * 1.30, violet, lean=0.22, y_offset=0.03)
        main = _ribbon(collection, root, "Aura_" + label + "_Cyan",
                       controls, width, cyan, lean=0.16)
        core = _ribbon(collection, root, "Aura_" + label + "_Ice",
                       controls, width * 0.31, ice, lean=0.10, y_offset=-0.028)
        result.extend((outer, main, core))
        # Filaments on alternating tongues keep the silhouette readable.
        if index % 2 == 0:
            result.append(_filament(collection, root,
                                    "Aura_" + label + "_WhiteFilament",
                                    controls, 0.012, white))

    rng = random.Random(260930)
    for index in range(15):
        side = -1.0 if index % 2 == 0 else 1.0
        z = 0.65 + (index / 14.0) * 6.05
        x = side * (2.52 + rng.uniform(-0.08, 0.26))
        if z > 5.75:
            x *= 0.76
        result.append(_spark(collection, root, "Aura_Spark_%02d" % (index + 1),
                             (x, rng.uniform(0.50, 1.15), z),
                             rng.uniform(0.048, 0.105), spark_material))

    if bool(collection.get("AuraLoopEnabled", False)):
        for index, obj in enumerate(result[1:]):
            _gentle_loop(obj, (index // 3) * 0.63)

    root["MeshObjects"] = len(result) - 1
    root["TriangleBudget"] = sum(sum(len(p.vertices) - 2 for p in obj.data.polygons)
                                 for obj in result if obj.type == "MESH")
    return result
