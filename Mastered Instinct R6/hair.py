"""Hand-shaped silver anime hair for the Mastered Instinct R6 model.

The module only creates meshes in the collection supplied to build_hair().
Coordinates: Z up, character faces -Y. All pieces belong to the R6 Head.
No operators, files, scene deletion, or external assets are used.
"""

import math
import bpy
from mathutils import Vector


def _material(name, color, metallic=0.13, roughness=0.34):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    node = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if node:
        node.inputs['Base Color'].default_value = (*color, 1.0)
        node.inputs['Metallic'].default_value = metallic
        node.inputs['Roughness'].default_value = roughness
    return mat


def _mesh(name, verts, faces, collection, materials, indices=None):
    data = bpy.data.meshes.new(name + '_Mesh')
    data.from_pydata(verts, [], faces)
    data.materials.clear()
    for mat in materials:
        data.materials.append(mat)
    data.update()
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    obj['r6_part'] = 'Head'
    obj['component'] = 'Silver hair - rigid head attachment'
    if indices:
        for poly, index in zip(data.polygons, indices):
            poly.material_index = index
    # Deliberate broad jewel-like planes, rather than smooth cone shading.
    for poly in data.polygons:
        poly.use_smooth = False
    return obj


def _bezier(points, t):
    a, b, c, d = [Vector(p) for p in points]
    q = 1.0 - t
    pos = q*q*q*a + 3*q*q*t*b + 3*q*t*t*c + t*t*t*d
    tan = 3*q*q*(b-a) + 6*q*t*(c-b) + 3*t*t*(d-c)
    tan.normalize()
    # All locks are shaped primarily in XZ. This leaves a visible front ridge.
    width = Vector((0, 1, 0)).cross(tan)
    if width.length < 0.001:
        width = Vector((1, 0, 0))
    width.normalize()
    depth = tan.cross(width).normalized()
    if depth.y < 0:
        depth = -depth
        width = -width
    return pos, width, depth


def _width_profile(t):
    # Wide shoulder, long flowing middle, and needle-like drawn-out hooked end.
    keys = [(0, .48), (.10, .79), (.23, 1), (.39, .98), (.56, .80),
            (.71, .55), (.84, .29), (.94, .095), (1, 0)]
    for (a, va), (b, vb) in zip(keys, keys[1:]):
        if a <= t <= b:
            u = (t-a)/(b-a)
            return va*(1-u) + vb*u
    return 0.0


def _lock(name, points, half_width, thickness, collection, mats, grooves=True):
    steps = [0, .08, .17, .27, .38, .50, .62, .73, .83, .91, .965]
    # First point is the frontal ridge. The five front planes make this a
    # sculpted blade-shaped tuft rather than a round tapered tube.
    cross = [(0, -1.22), (.48, -.79), (1, -.08), (.69, .63),
             (0, .92), (-.69, .63), (-1, -.08), (-.48, -.79)]
    verts = []
    for t in steps:
        p, u, v = _bezier(points, t)
        w = half_width*_width_profile(t)
        depth = thickness*(.64 + .36*math.sin(math.pi*t))*(1-t)**.56
        for x, y in cross:
            verts.append(tuple(p + u*(x*w) + v*(y*depth)))
    tip_index = len(verts)
    verts.append(tuple(Vector(points[-1])))
    faces = []
    ids = []
    # Silver, bright highlight, icy middle, slate shadow, and underside.
    facet_mats = [1, 0, 2, 3, 3, 2, 0, 4]
    for j in range(len(steps)-1):
        for k in range(8):
            faces.append((j*8+k, j*8+(k+1)%8, (j+1)*8+(k+1)%8, (j+1)*8+k))
            ids.append(facet_mats[k])
    j = len(steps)-1
    for k in range(8):
        faces.append((j*8+k, j*8+(k+1)%8, tip_index))
        ids.append(facet_mats[k])
    faces.append(tuple(reversed(range(8))))
    ids.append(3)
    objects = [_mesh(name, verts, faces, collection, mats, ids)]
    if grooves:
        # Fine recessed-looking curved channels follow the actual leaf surface.
        # They remain geometry so the hairstyle does not depend on a texture.
        for number, lane in enumerate((-.38, .47)):
            vv, ff = [], []
            for j in range(13):
                t = .13 + .77*j/12
                p, u, v = _bezier(points, t)
                w = half_width*_width_profile(t)
                dep = thickness*(.64+.36*math.sin(math.pi*t))*(1-t)**.56
                q = lane*(1-.22*t)
                # Interpolate the first two frontal ridge panels.
                aq = abs(q)
                frontal = -1.22 + (.43/ .48)*aq if aq < .48 else -.79 + (.71/.52)*(aq-.48)
                line = p + u*(q*w) + v*(frontal*dep-.003)
                sw = .0065*math.sin(math.pi*j/12)**.45
                vv.extend((tuple(line-u*sw), tuple(line+u*sw)))
                if j:
                    ff.append(((j-1)*2, (j-1)*2+1, j*2+1, j*2))
            objects.append(_mesh(name+'_Strand_'+str(number+1), vv, ff, collection, [mats[5]]))
    return objects


def _cap(collection, mats):
    verts, faces, ids = [], [], []
    sectors = 40
    # The forehead edge stays safely above the eyebrows; the back and sides
    # wrap lower so there is no bald seam under the swept outer locks.
    for j in range(7):
        t = j/7
        shrink = math.cos(t*math.pi/2)
        for k in range(sectors):
            a = 2*math.pi*k/sectors
            front = max(0, -math.sin(a))
            base_z = 4.88 + .34*front**2
            z = base_z*(1-t) + 5.56*t
            ripple = 1 + .020*math.sin(a*9+t*4)
            verts.append((.89*shrink*math.cos(a)*ripple,
                          .655*shrink*math.sin(a)*ripple + .04, z))
    tip = len(verts)
    verts.append((0, .04, 5.56))
    for j in range(6):
        for k in range(sectors):
            faces.append((j*sectors+k, j*sectors+(k+1)%sectors,
                          (j+1)*sectors+(k+1)%sectors, (j+1)*sectors+k))
            ids.append(2 if k % 5 in (0, 1) else 0)
    for k in range(sectors):
        faces.append((6*sectors+k, 6*sectors+(k+1)%sectors, tip))
        ids.append(0)
    return _mesh('MI_Hair_Sculpted_Crown', verts, faces, collection, mats, ids)


def build_hair(collection):
    """Return the new head-attached mesh objects; keep caller's scene intact."""
    mats = [
        _material('MI Hair | Silver pearl', (.57, .65, .79)),
        _material('MI Hair | White ridge', (.91, .95, 1.0), .09, .28),
        _material('MI Hair | Blue silver', (.29, .38, .56)),
        _material('MI Hair | Slate underside', (.12, .17, .29)),
        _material('MI Hair | Ice highlight', (.73, .83, .98)),
        _material('MI Hair | Strand channel', (.23, .30, .46)),
    ]
    objects = [_cap(collection, mats)]
    # Back tier first: these arcs expose volume in profile and three-quarter
    # views. None is merely a straight cone pointing radially from the skull.
    locks = [
        ('Back_Crown', ((-.02,.43,5.20),(-.20,.73,5.56),(-.04,.86,5.96),(.12,.87,6.16)), .30,.16),
        ('Back_Sweep_L', ((-.43,.42,5.04),(-.75,.77,5.12),(-1.08,.91,5.53),(-1.19,.81,5.78)), .30,.15),
        ('Back_Sweep_R', ((.40,.44,5.02),(.78,.71,5.18),(1.08,.88,5.49),(1.19,.78,5.65)), .31,.15),
        ('Nape_L', ((-.25,.51,4.99),(-.65,.74,4.78),(-.97,.82,4.94),(-1.11,.69,5.09)), .20,.11),
        ('Nape_R', ((.23,.52,4.98),(.67,.76,4.80),(.98,.85,4.98),(1.12,.71,5.13)), .20,.11),
        # Primary outer silhouette: long sweeping leaves with offset peaks.
        ('Crown_Ascendant', ((-.08,.13,5.29),(-.23,.10,5.72),(-.47,.25,6.03),(-.31,.29,6.48)), .36,.20),
        ('High_Left_Sweep', ((-.32,.06,5.28),(-.52,-.01,5.70),(-.99,.09,6.05),(-1.15,.14,6.20)), .37,.18),
        ('High_Right_Sweep', ((.18,.13,5.30),(.42,.02,5.74),(.82,.19,5.79),(.93,.26,6.21)), .34,.19),
        ('Outer_Left_Wing', ((-.49,.02,5.17),(-.94,.02,5.24),(-1.19,.10,5.59),(-1.42,.13,5.83)), .34,.17),
        ('Outer_Right_Wing', ((.45,.05,5.18),(.80,-.01,5.65),(1.12,.08,5.82),(1.42,.12,6.00)), .36,.18),
        ('Left_Temple_Sweep', ((-.56,-.06,5.02),(-.97,-.12,5.01),(-1.17,-.05,5.21),(-1.40,.04,5.35)), .26,.13),
        ('Right_Temple_Sweep', ((.57,-.07,5.01),(.89,-.13,5.14),(1.18,-.03,5.35),(1.44,.05,5.51)), .28,.14),
        # Upper frontal tier arches over the long outer silhouette.
        ('Front_Left_Crest', ((-.02,-.27,5.25),(-.29,-.48,5.78),(-.67,-.25,5.90),(-.91,-.11,6.09)), .29,.16),
        ('Front_Right_Crest', ((.16,-.23,5.27),(.46,-.42,5.51),(.72,-.32,5.74),(1.04,-.11,5.79)), .28,.16),
        ('Left_Low_Flick', ((-.62,-.15,4.99),(-.80,-.18,4.79),(-1.02,-.10,4.89),(-1.13,.03,4.98)), .18,.11),
        ('Right_Low_Flick', ((.62,-.11,5.00),(.83,-.18,4.88),(1.02,-.10,4.92),(1.16,.02,5.10)), .18,.11),
        # Four hooked bangs frame, rather than conceal, the stern eyes.
        ('Bang_Left_Hook', ((-.02,-.46,5.56),(-.50,-.65,5.57),(-.71,-.71,5.19),(-.60,-.72,4.87)), .245,.105),
        ('Bang_Right_Hook', ((.16,-.43,5.53),(.52,-.65,5.42),(.56,-.74,5.18),(.36,-.76,4.95)), .24,.11),
        ('Bang_Central_Curl', ((.11,-.58,5.55),(-.13,-.79,5.43),(-.21,-.79,5.14),(-.25,-.76,4.91)), .19,.095),
        ('Bang_Outer_Right', ((.45,-.39,5.39),(.69,-.59,5.27),(.80,-.65,5.11),(.74,-.64,4.92)), .17,.09),
    ]
    for name, points, width, depth in locks:
        objects.extend(_lock('MI_Hair_'+name, points, width, depth, collection, mats))
    return objects
