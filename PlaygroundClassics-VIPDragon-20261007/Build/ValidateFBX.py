from pathlib import Path
from array import array
import importlib.util
import hashlib
import json
import math
import struct
import sys
import zlib

ROOT = Path(__file__).resolve().parent.parent
PARSER = ROOT.parent / 'ACULobbyCitadel/exports/ImportReady_ScaleFixed_20260926/fix_fbx_unit_scale.py'
spec = importlib.util.spec_from_file_location('fbxreader', PARSER)
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)

def value(prop):
    data = prop.raw[1:]
    if prop.t in r.SCALARS:
        return struct.unpack('<' + r.SCALARS[prop.t], data)[0]
    if prop.t in ('S', 'R'):
        return data[4:]
    count, encoding, size = struct.unpack('<III', data[:12])
    raw = zlib.decompress(data[12:]) if encoding else data[12:]
    result = array('q' if prop.t == 'l' else prop.t)
    result.frombytes(raw)
    if sys.byteorder != 'little':
        result.byteswap()
    assert len(result) == count
    return result

r.Prop.value = value

def data(node, child, default=None):
    c = r.child(node, child.encode())
    return c.props[0].value() if c and c.props else default

def name(node):
    return node.props[1].value().split(b'\0')[0].decode()

def ident():
    return [[float(i == j) for j in range(4)] for i in range(4)]

def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]

def from_fbx(a):
    return [[a[j * 4 + i] for j in range(4)] for i in range(4)]

def transform(m, v):
    return [sum(m[i][j] * v[j] for j in range(3)) + m[i][3] for i in range(3)]

def local_matrix(node):
    p = r.properties(node)
    for k in ['PreRotation', 'PostRotation', 'RotationPivot', 'ScalingPivot', 'RotationOffset', 'ScalingOffset']:
        assert all(abs(v) < 1e-8 for v in p.get(k, [0, 0, 0])), (name(node), k)
    assert p.get('RotationOrder', [0]) == [0]
    t = p.get('Lcl Translation', [0, 0, 0])
    s = p.get('Lcl Scaling', [1, 1, 1])
    x, y, z = [math.radians(a) for a in p.get('Lcl Rotation', [0, 0, 0])]
    rx = ident(); ry = ident(); rz = ident()
    rx[1][1] = rx[2][2] = math.cos(x); rx[1][2] = -math.sin(x); rx[2][1] = math.sin(x)
    ry[0][0] = ry[2][2] = math.cos(y); ry[0][2] = math.sin(y); ry[2][0] = -math.sin(y)
    rz[0][0] = rz[1][1] = math.cos(z); rz[0][1] = -math.sin(z); rz[1][0] = math.sin(z)
    matrix = mul(mul(rz, ry), rx)
    for i in range(3):
        for j in range(3):
            matrix[i][j] *= s[j]
        matrix[i][3] = t[i]
    return matrix

def inspect(path):
    version, nodes = r.read(path)
    obs = next(n for n in nodes if n.name == b'Objects')
    connections = next(n for n in nodes if n.name == b'Connections')
    links = [r.prop_values(c) for c in connections.children if c.name == b'C']
    objects = {int(n.props[0].value()): n for n in obs.children}
    models = {i: n for i, n in objects.items() if n.name == b'Model'}
    geometry = {i: n for i, n in objects.items() if n.name == b'Geometry'}
    bones = {i: n for i, n in models.items() if n.props[2].value() == b'LimbNode'}
    parents = {child: parent for kind, child, parent, *rest in links if kind == b'OO' and child in models and (parent == 0 or parent in models)}
    worlds = {}
    def world(i):
        if not i:
            return ident()
        if i not in worlds:
            worlds[i] = mul(world(parents.get(i, 0)), local_matrix(models[i]))
        return worlds[i]
    poses = {}
    duplicate_bind_error = 0.0
    for pose in [n for n in obs.children if n.name == b'Pose']:
        for pn in pose.children:
            if pn.name != b'PoseNode':
                continue
            i = data(pn, 'Node')
            matrix = list(data(pn, 'Matrix'))
            if i in poses:
                duplicate_bind_error = max(duplicate_bind_error, max(abs(x-y) for x,y in zip(matrix, poses[i])))
            poses[i] = matrix
    rest_bind_error = max(abs(world(i)[a][b] - from_fbx(m)[a][b]) for i,m in poses.items() for a in range(4) for b in range(4))
    low = [math.inf] * 3; high = [-math.inf] * 3
    meshes = []
    for gid, geo in geometry.items():
        model = next(parent for kind, child, parent, *rest in links if kind == b'OO' and child == gid and parent in models)
        v = data(geo, 'Vertices'); indices = data(geo, 'PolygonVertexIndex')
        polygon_sizes = []
        polygon_size = 0
        for index in indices:
            polygon_size += 1
            if index < 0:
                assert polygon_size >= 3
                polygon_sizes.append(polygon_size)
                polygon_size = 0
        assert polygon_size == 0
        assert all(0 <= (i if i >= 0 else -i-1) < len(v)//3 for i in indices)
        for n in range(0, len(v), 3):
            p = transform(world(model), v[n:n+3])
            for axis in range(3):
                low[axis] = min(low[axis], p[axis]); high[axis] = max(high[axis], p[axis])
        skins = [child for kind, child, parent, *rest in links if kind == b'OO' and parent == gid and child in objects and objects[child].name == b'Deformer']
        assert len(skins) == 1, (name(geo), len(skins))
        clusters = [objects[child] for kind, child, parent, *rest in links if kind == b'OO' and parent == skins[0] and child in objects and objects[child].name == b'Deformer']
        sums = [0.0] * (len(v)//3); influences = [0] * len(sums)
        for cluster in clusters:
            weights = data(cluster, 'Weights', []); vertex_ids = data(cluster, 'Indexes', [])
            assert len(weights) == len(vertex_ids)
            for vi, weight in zip(vertex_ids, weights):
                assert math.isfinite(weight) and -1e-7 <= weight <= 1 + 1e-6
                sums[vi] += weight
                if weight > 1e-8:
                    influences[vi] += 1
        unweighted = sum(total <= 1e-8 for total in sums)
        weight_error = max(abs(total - 1) for total in sums)
        meshes.append({'name': name(geo), 'vertices': len(v)//3, 'triangles': sum(s-2 for s in polygon_sizes), 'unweightedVertices': unweighted,
                       'allFacesTriangulated': all(s == 3 for s in polygon_sizes), 'largestPolygonCorners': max(polygon_sizes),
                       'maximumWeightSumError': weight_error, 'maximumInfluences': max(influences),
                       'hasUV': r.child(geo, b'LayerElementUV') is not None})
        assert unweighted == 0 and weight_error < 1e-5 and max(influences) <= 4
    curves = [n for n in obs.children if n.name == b'AnimationCurve']
    curve_nodes = {i: n for i, n in objects.items() if n.name == b'AnimationCurveNode'}
    animated = []
    max_loop_error = 0
    key_times = set()
    for curve in curves:
        times = data(curve, 'KeyTime'); values = data(curve, 'KeyValueFloat')
        assert len(times) == len(values) and len(values) >= 2
        assert all(math.isfinite(v) for v in values)
        assert all(a < b for a, b in zip(times, times[1:]))
        max_loop_error = max(max_loop_error, abs(values[-1] - values[0]))
        key_times.update(times)
        span = max(values) - min(values)
        if span > 1e-5:
            cid = int(curve.props[0].value())
            curve_link = next(link for link in links if link[0] == b'OP' and link[1] == cid)
            node_link = next(link for link in links if link[0] == b'OP' and link[1] == curve_link[2] and link[2] in models)
            animated.append({'bone': name(models[node_link[2]]), 'property': node_link[3].decode(), 'component': curve_link[3].decode(), 'range': span})
    embedded = []
    palette = (path.parent / 'VIP-Dragon-Palette.png').read_bytes()
    for video in [n for n in obs.children if n.name == b'Video']:
        content = data(video, 'Content', b'')
        embedded.append({'name': name(video), 'bytes': len(content), 'matchesPaletteBytes': content == palette})
    settings = r.properties(next(n for n in nodes if n.name == b'GlobalSettings'))
    report = {'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'version': version,
              'meshCount': len(meshes), 'triangles': sum(m['triangles'] for m in meshes), 'maximumMeshTriangles': max(m['triangles'] for m in meshes),
              'boneCount': len(bones), 'boneNames': [name(n) for n in bones.values()],
              'restBounds': {'min': low, 'max': high, 'size': [high[i] - low[i] for i in range(3)]},
              'unitScaleFactor': settings['UnitScaleFactor'][0],
              'bindPoses': sum(n.name == b'Pose' for n in obs.children), 'duplicateBindMaximumError': duplicate_bind_error,
              'initialTransformVsBindPoseMaximumDifference': rest_bind_error, 'meshes': meshes, 'embeddedTextures': embedded,
              'animationCurveCount': len(curves), 'sampleCount': len(key_times),
              'durationSeconds': (max(key_times)-min(key_times))/46186158000 if key_times else 0,
              'maximumFirstLastCurveError': max_loop_error, 'animatedChannels': animated}
    assert len(meshes) == 8 and len(bones) == 14
    assert abs(report['restBounds']['size'][0] - 3) < 1e-6
    assert settings['UnitScaleFactor'] == [1.0]
    assert duplicate_bind_error < 1e-6
    assert all(e['matchesPaletteBytes'] for e in embedded) and embedded
    if 'Rigged' in path.name:
        assert not curves and rest_bind_error < 2e-5
    else:
        assert curves and max_loop_error < 1e-4
        for wing in ['Wing.L', 'Wing.R', 'WingTip.L', 'WingTip.R']:
            assert any(c['bone'] == wing and c['property'] == 'Lcl Rotation' for c in animated), wing
    report['passed'] = True
    return report, poses

reports = []
bindsets = []
for filename in ['VIP-Dragon-Rigged.fbx', 'VIP-Dragon-Hover.fbx', 'VIP-Dragon-Fly.fbx']:
    report, poses = inspect(ROOT / 'Roblox' / filename)
    reports.append(report)
    bindsets.append(poses)
assert bindsets[0] == bindsets[1] == bindsets[2]
result = {'allPassed': True, 'method': 'Independent direct binary FBX parse; hierarchical XYZ local transforms compared against BindPose matrices; skin cluster weights inspected per vertex.',
          'bindPosesIdenticalAcrossThreeExports': True, 'robloxRuntimeImportVerified': False,
          'notes': ['Numeric model width is exactly 3.0 exported units. Select Studs and import scale 1 in Roblox.',
                    'Embedded palette bytes match the external PNG. Exporter .fbm references are fallback extraction paths, not required while Content is embedded.',
                    'All three exports share identical neutral bind poses; Rigged contains no animation curves and its model transforms reproduce its neutral bind pose. Animated files intentionally start posed, so their initial transforms differ from the neutral bind pose.',
                    'Loop closure checked in all exported channels. Visual wing motion and full-animation bounds remain separate render/evaluation checks.'],
          'files': reports}
(ROOT / 'Build' / 'Validation-FBX.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps({'allPassed': True, 'files': [{k: f[k] for k in ['file','meshCount','triangles','boneCount','restBounds','animationCurveCount','durationSeconds','maximumFirstLastCurveError','initialTransformVsBindPoseMaximumDifference']} for f in reports]}))
