"""Editable VIP dragon wing surfaces. Invoked by the character build script."""

import math
import bpy
from mathutils import Vector


def _lerp(a, b, t):
    return a * (1.0 - t) + b * t


def _bezier(points, t):
    a, b, c, d = [Vector(p) for p in points]
    s = 1.0 - t
    return a * s ** 3 + b * (3 * s * s * t) + c * (3 * s * t * t) + d * t ** 3


def _side(p, sign):
    return (p[0] * sign, p[1], p[2])


def _weights(obj, side):
    root = obj.vertex_groups.new(name='Wing.' + side)
    tip = obj.vertex_groups.new(name='WingTip.' + side)
    for vertex in obj.data.vertices:
        blend = max(0.0, min(1.0, (abs(vertex.co.x) - 0.95) / 0.55))
        blend = blend * blend * (3.0 - 2.0 * blend)
        if blend < 1.0:
            root.add([vertex.index], 1.0 - blend, 'REPLACE')
        if blend > 0.0:
            tip.add([vertex.index], blend, 'REPLACE')
    obj['rig_bone'] = 'Wing.' + side
    obj['rig_weights_authored'] = True
    obj['part_role'] = 'deforming_wing'


def _mesh(name, vertices, faces, collection, mats, side, material_ids=None):
    data = bpy.data.meshes.new(name + '_Mesh')
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    for mat in mats:
        data.materials.append(mat)
    for i, polygon in enumerate(data.polygons):
        polygon.use_smooth = True
        if material_ids:
            polygon.material_index = material_ids[i]
    _weights(obj, side)
    return obj


def _tube(name, path, radii, collection, materials, side, sign, sections=14, sides=8):
    vertices, faces, mat_ids = [], [], []
    centres = [_bezier(path, j / sections) for j in range(sections + 1)]
    for j, centre in enumerate(centres):
        tangent = centres[min(j + 1, sections)] - centres[max(j - 1, 0)]
        tangent.normalize()
        normal = tangent.cross(Vector((0, 1, 0))).normalized()
        binormal = tangent.cross(normal).normalized()
        progress = j / sections
        radius = radii[0] * (1.0 - progress) + radii[1] * progress
        for k in range(sides):
            angle = 2.0 * math.pi * k / sides
            vertex = centre + radius * (normal * math.cos(angle) + binormal * math.sin(angle))
            vertices.append(_side(vertex, sign))
    for j in range(sections):
        for k in range(sides):
            face = (j * sides + k, j * sides + (k + 1) % sides,
                    (j + 1) * sides + (k + 1) % sides, (j + 1) * sides + k)
            faces.append(face if sign > 0 else tuple(reversed(face)))
            mat_ids.append(1 if k in (1, 2) else 0)
    faces.append(tuple(reversed(range(sides))) if sign > 0 else tuple(range(sides)))
    last = tuple(sections * sides + k for k in range(sides))
    faces.append(last if sign > 0 else tuple(reversed(last)))
    mat_ids.extend((0, 0))
    return _mesh(name, vertices, faces, collection,
                 [materials['gold'], materials['gold_light']], side, mat_ids)


def _membrane(name, apex, edge_a, edge_b, scallop, collection, materials, side, sign):
    radial_steps, arc_steps = 10, 16
    apex = Vector(apex)
    front = [apex.copy()]
    for row in range(1, radial_steps + 1):
        t = row / radial_steps
        for column in range(arc_steps + 1):
            u = column / arc_steps
            boundary = _bezier(scallop, u)
            left = _bezier(edge_a, t)
            right = _bezier(edge_b, t)
            straight_left = _lerp(apex, Vector(scallop[0]), t)
            straight_right = _lerp(apex, Vector(scallop[-1]), t)
            p = _lerp(apex, boundary, t)
            p += _lerp(left - straight_left, right - straight_right, u)
            p.y -= 0.048 * math.sin(math.pi * u) * math.sin(math.pi * t)
            front.append(p)
    def index(row, col):
        return 1 + (row - 1) * (arc_steps + 1) + col
    faces = [(0, index(1, col), index(1, col + 1)) for col in range(arc_steps)]
    for row in range(1, radial_steps):
        for col in range(arc_steps):
            faces.append((index(row, col), index(row + 1, col),
                          index(row + 1, col + 1), index(row, col + 1)))
    # Orient the visible membrane toward the character's front (-Y).
    a, b, c = [front[i] for i in faces[0]]
    if (b - a).cross(c - a).y > 0:
        faces = [tuple(reversed(face)) for face in faces]
    count = len(front)
    vertices = [_side(v + Vector((0, -0.012, 0)), sign) for v in front]
    vertices.extend(_side(v + Vector((0, 0.012, 0)), sign) for v in front)
    front_faces = faces[:]
    faces.extend(tuple(i + count for i in reversed(face)) for face in front_faces)
    material_ids = [0] * len(front_faces) + [1] * len(front_faces)
    border = [0] + [index(row, 0) for row in range(1, radial_steps + 1)]
    border += [index(radial_steps, col) for col in range(1, arc_steps + 1)]
    border += [index(row, arc_steps) for row in range(radial_steps - 1, 0, -1)]
    # Match rim winding to the face order by checking a boundary half edge.
    edge_set = set((face[i], face[(i + 1) % len(face)])
                   for face in front_faces for i in range(len(face)))
    if (border[0], border[1]) not in edge_set:
        border.reverse()
    for j, a in enumerate(border):
        b = border[(j + 1) % len(border)]
        faces.append((b, a, a + count, b + count))
        material_ids.append(1)
    if sign < 0:
        faces = [tuple(reversed(face)) for face in faces]
    obj = _mesh(name, vertices, faces, collection,
                [materials['scarlet'], materials['crimson']], side, material_ids)
    obj['surface_detail'] = 'Closed quad membrane with scalloped trailing edge and relaxed camber'
    return obj


def build_wings(collection, materials):
    objects = []
    wrist = (1.12, 0.15, 1.72)
    inner = (0.42, 0.25, 0.72)
    finger = (1.08, 0.12, 0.60)
    outer = (1.70, 0.23, 1.14)
    inner_edge = [wrist, (0.89, 0.20, 1.16), (0.64, 0.23, 0.93), inner]
    middle_edge = [wrist, (1.17, 0.13, 1.37), (1.17, 0.11, 0.96), finger]
    outer_edge = [wrist, (1.44, 0.16, 1.64), (1.63, 0.20, 1.40), outer]
    inner_scallop = [inner, (0.72, 0.22, 1.00), (0.94, 0.14, 0.96), finger]
    outer_scallop = [finger, (1.26, 0.14, 1.11), (1.53, 0.22, 1.20), outer]
    for side, sign in [('L', 1), ('R', -1)]:
        objects.append(_membrane('VIPDragon_WingInner_' + side, wrist, inner_edge, middle_edge,
                       inner_scallop, collection, materials, side, sign))
        objects.append(_membrane('VIPDragon_WingOuter_' + side, wrist, middle_edge, outer_edge,
                       outer_scallop, collection, materials, side, sign))
        for label, path, radii, segments in [
                ('InnerFrame', inner_edge, (0.064, 0.030), 12),
                ('FingerFrame', middle_edge, (0.061, 0.014), 14),
                ('LeadingFrame', outer_edge, (0.070, 0.009), 16)]:
            objects.append(_tube('VIPDragon_Wing' + label + '_' + side,
                           path, radii, collection, materials, side, sign, segments))
        shoulder = [(0.30, 0.18, 1.05), (0.55, 0.24, 1.06), (0.92, 0.20, 1.37), wrist]
        objects.append(_tube('VIPDragon_WingArm_' + side, shoulder, (0.070, 0.061),
                       collection, materials, side, sign, 12))
        horn = [(1.12, 0.15, 1.70), (1.12, 0.15, 1.77), (1.08, 0.15, 1.85), (1.06, 0.15, 1.91)]
        objects.append(_tube('VIPDragon_WingWristHorn_' + side, horn, (0.080, 0.004),
                       collection, materials, side, sign, 7, 10))
        for label, path, t in [('UpperJoint', outer_edge, 0.51), ('FingerJoint', middle_edge, 0.84)]:
            point = _bezier(path, t)
            tangent = (_bezier(path, t + 0.02) - _bezier(path, t - 0.02)).normalized()
            start, end = point - tangent * 0.019, point + tangent * 0.019
            cuff_path = [start, _lerp(start, end, 1 / 3), _lerp(start, end, 2 / 3), end]
            radius = (0.070 * (1 - t) + 0.018 * t) + 0.009
            objects.append(_tube('VIPDragon_Wing' + label + '_' + side, cuff_path, (radius, radius),
                           collection, materials, side, sign, 2, 10))
    return objects
