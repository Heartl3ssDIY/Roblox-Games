import json
import math
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parent
COMPONENTS = {
    5120: ('b', 1), 5121: ('B', 1), 5122: ('h', 2),
    5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4),
}
WIDTHS = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}
IDENTITY = (1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)


def multiply(a, b):
    return tuple(sum(a[k * 4 + row] * b[column * 4 + k] for k in range(4))
                 for column in range(4) for row in range(4))


def transform(matrix, point):
    values = tuple(sum(matrix[column * 4 + row] * value
                       for column, value in enumerate((*point, 1)))
                   for row in range(4))
    assert abs(values[3]) > 1e-12, 'Invalid homogeneous point'
    result = tuple(value / values[3] for value in values[:3])
    assert all(math.isfinite(value) for value in result), 'Nonfinite world position'
    return result


def local_matrix(node):
    if 'matrix' in node:
        matrix = tuple(node['matrix'])
        assert len(matrix) == 16 and all(math.isfinite(v) for v in matrix)
        return matrix
    x, y, z, w = node.get('rotation', [0, 0, 0, 1])
    sx, sy, sz = node.get('scale', [1, 1, 1])
    tx, ty, tz = node.get('translation', [0, 0, 0])
    matrix = (
        (1 - 2 * (y*y + z*z)) * sx, 2 * (x*y + z*w) * sx,
        2 * (x*z - y*w) * sx, 0,
        2 * (x*y - z*w) * sy, (1 - 2 * (x*x + z*z)) * sy,
        2 * (y*z + x*w) * sy, 0,
        2 * (x*z + y*w) * sz, 2 * (y*z - x*w) * sz,
        (1 - 2 * (x*x + y*y)) * sz, 0, tx, ty, tz, 1,
    )
    assert all(math.isfinite(v) for v in matrix), 'Nonfinite node transform'
    return matrix


def read_glb(path):
    data = path.read_bytes()
    assert len(data) >= 20, 'Truncated GLB header'
    magic, version, length = struct.unpack_from('<4sII', data)
    assert magic == b'glTF' and version == 2 and length == len(data), 'Invalid GLB header'
    chunks = []
    offset = 12
    while offset < len(data):
        assert offset + 8 <= len(data), 'Truncated GLB chunk header'
        size, kind = struct.unpack_from('<II', data, offset)
        offset += 8
        assert size % 4 == 0 and offset + size <= len(data), 'Invalid GLB chunk length'
        chunks.append((kind, data[offset:offset + size]))
        offset += size
    assert chunks and chunks[0][0] == 0x4E4F534A, 'Missing JSON chunk'
    model = json.loads(chunks[0][1].rstrip(b' \x00'))
    binary = [chunk for kind, chunk in chunks if kind == 0x004E4942]
    assert len(binary) == 1, 'Expected one embedded binary chunk'
    assert all('uri' not in item for item in model.get('buffers', [])), 'External buffer URI'
    assert all('uri' not in item for item in model.get('images', [])), 'Image URI is not embedded'
    assert all('bufferView' in item and 0 <= item['bufferView'] < len(model.get('bufferViews', []))
               for item in model.get('images', [])), 'Image has no embedded buffer view'
    assert len(model.get('buffers', [])) == 1, 'Expected one embedded buffer'
    declared_length = model['buffers'][0]['byteLength']
    assert declared_length <= len(binary[0]) <= declared_length + 3, 'Binary buffer length mismatch'
    return model, binary[0][:declared_length]


def unpack_view(model, binary, view_index, offset, count, component, width, normalized=False):
    code, component_size = COMPONENTS[component]
    view = model['bufferViews'][view_index]
    assert view.get('buffer', 0) == 0, 'Unknown buffer'
    element_size = component_size * width
    stride = view.get('byteStride', element_size)
    assert stride >= element_size, 'Invalid byte stride'
    start = view.get('byteOffset', 0) + offset
    limit = view.get('byteOffset', 0) + view['byteLength']
    assert 0 <= start <= limit <= len(binary), 'Invalid buffer view bounds'
    if count:
        assert start + (count - 1) * stride + element_size <= limit, 'Accessor exceeds buffer view'
    result = [struct.unpack_from('<' + code * width, binary, start + index * stride)
              for index in range(count)]
    if normalized and component != 5126:
        bits = component_size * 8
        if component in (5120, 5122):
            maximum = 2 ** (bits - 1) - 1
            result = [tuple(max(value / maximum, -1) for value in row) for row in result]
        else:
            maximum = 2 ** bits - 1
            result = [tuple(value / maximum for value in row) for row in result]
    return result


def accessor_values(model, binary, accessor_index):
    accessor = model['accessors'][accessor_index]
    width = WIDTHS[accessor['type']]
    count = accessor['count']
    assert count >= 0 and accessor['componentType'] in COMPONENTS
    if 'bufferView' in accessor:
        values = unpack_view(model, binary, accessor['bufferView'], accessor.get('byteOffset', 0),
                             count, accessor['componentType'], width, accessor.get('normalized', False))
    else:
        values = [(0,) * width for _ in range(count)]
    if 'sparse' in accessor:
        sparse = accessor['sparse']
        indices = sparse['indices']
        assert indices['componentType'] in (5121, 5123, 5125), 'Invalid sparse index component'
        replacements = sparse['values']
        slots = unpack_view(model, binary, indices['bufferView'], indices.get('byteOffset', 0),
                            sparse['count'], indices['componentType'], 1)
        rows = unpack_view(model, binary, replacements['bufferView'], replacements.get('byteOffset', 0),
                           sparse['count'], accessor['componentType'], width,
                           accessor.get('normalized', False))
        previous = -1
        for (slot,), row in zip(slots, rows):
            assert previous < slot < count, 'Invalid sparse accessor index'
            values[slot] = row
            previous = slot
    assert all(math.isfinite(value) for row in values for value in row), 'Nonfinite accessor value'
    return values


def inspect(path, gun_name):
    model, binary = read_glb(path)
    nodes = model.get('nodes', [])
    matches = [index for index, node in enumerate(nodes) if node.get('name') == gun_name]
    assert len(matches) == 1, 'Expected one named gun root'
    gun_index = matches[0]
    gun_matrix = local_matrix(nodes[gun_index])
    assert all(abs(value) <= 1e-7 for value in gun_matrix[12:15]), 'Gun root translation is not zero'
    assert not model.get('cameras'), 'Export contains cameras'
    assert not model.get('extensions', {}).get('KHR_lights_punctual', {}).get('lights'), 'Export contains lights'
    forbidden = ('preview', 'floor', 'camera', 'light')
    for item in nodes + model.get('meshes', []):
        name = item.get('name', '').lower()
        assert not any(word in name for word in forbidden), 'Preview object included: ' + name
    assert all('camera' not in node and 'KHR_lights_punctual' not in node.get('extensions', {})
               for node in nodes), 'Camera or light node included'
    parents = {}
    for index, node in enumerate(nodes):
        for child in node.get('children', []):
            assert 0 <= child < len(nodes) and child not in parents, 'Invalid or multiply parented node'
            parents[child] = index
    assert gun_index not in parents, 'Gun origin is nested under another transform'
    selected_scene = model['scenes'][model.get('scene', 0)]
    assert gun_index in selected_scene.get('nodes', []), 'Gun root is not in the exported scene'
    positions_cache = {}
    minimum = [math.inf] * 3
    maximum = [-math.inf] * 3
    triangles = 0
    vertices = 0
    mesh_instances = 0
    visited = set()
    used_meshes = set()

    def visit(index, parent_matrix):
        nonlocal triangles, vertices, mesh_instances
        assert index not in visited, 'Cycle or repeated node in exported hierarchy'
        visited.add(index)
        node = nodes[index]
        matrix = multiply(parent_matrix, local_matrix(node))
        if 'mesh' in node:
            mesh_index = node['mesh']
            used_meshes.add(mesh_index)
            mesh_instances += 1
            for primitive in model['meshes'][mesh_index]['primitives']:
                assert primitive.get('mode', 4) == 4, 'Expected triangle primitives'
                position_index = primitive['attributes']['POSITION']
                assert model['accessors'][position_index]['type'] == 'VEC3', 'Invalid position accessor'
                if position_index not in positions_cache:
                    positions_cache[position_index] = accessor_values(model, binary, position_index)
                positions = positions_cache[position_index]
                vertices += len(positions)
                if 'indices' in primitive:
                    index_accessor = model['accessors'][primitive['indices']]
                    assert index_accessor['type'] == 'SCALAR'
                    assert index_accessor['componentType'] in (5121, 5123, 5125)
                    indices = accessor_values(model, binary, primitive['indices'])
                    assert all(0 <= value[0] < len(positions) for value in indices), 'Out of range vertex index'
                    index_count = len(indices)
                else:
                    index_count = len(positions)
                assert index_count % 3 == 0, 'Triangle index count is not divisible by three'
                triangles += index_count // 3
                for position in positions:
                    point = transform(matrix, position)
                    for axis in range(3):
                        minimum[axis] = min(minimum[axis], point[axis])
                        maximum[axis] = max(maximum[axis], point[axis])
        for child in node.get('children', []):
            visit(child, matrix)

    visit(gun_index, IDENTITY)
    assert visited == set(range(len(nodes))), 'Export contains nodes outside the gun hierarchy'
    assert used_meshes == set(range(len(model.get('meshes', [])))), 'Export contains unused or unrelated meshes'
    assert vertices and triangles, 'Export contains no geometry'
    assert all(math.isfinite(v) for v in minimum + maximum), 'Nonfinite model bounds'
    return {
        'path': str(path), 'bytes': path.stat().st_size, 'gunRoot': gun_name,
        'rootTranslation': list(gun_matrix[12:15]), 'meshCount': len(used_meshes),
        'meshInstances': mesh_instances, 'triangleCount': triangles, 'positionCount': vertices,
        'boundsExport': [minimum, maximum],
        'dimensionsExport': [maximum[i] - minimum[i] for i in range(3)],
        'allAssetsEmbedded': True, 'finitePositions': True, 'previewObjectsExcluded': True,
        'boundsMethod': 'Embedded POSITION vertices transformed through the gun node hierarchy',
        'passed': True,
    }


def main():
    report = {'inspection': 'Refined gun export geometry; no gameplay or Studio execution', 'guns': {}}
    for gun_name in ('MudGun', 'HeatGun'):
        try:
            report['guns'][gun_name] = inspect(ROOT / (gun_name + '.glb'), gun_name)
        except (AssertionError, KeyError, IndexError, ValueError, TypeError, OSError, struct.error) as error:
            report['guns'][gun_name] = {'passed': False, 'error': str(error)}
    report['passed'] = all(item['passed'] for item in report['guns'].values())
    destination = ROOT / 'Inspection.json'
    destination.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))
    raise SystemExit(0 if report['passed'] else 1)


if __name__ == '__main__':
    main()
