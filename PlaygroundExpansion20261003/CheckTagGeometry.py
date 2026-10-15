import json
import math
from pathlib import Path

root = Path(__file__).resolve().parent
obstacles = []
clearance = 3.3

def obstacle(x, z, width, depth):
    obstacles.append((x-width/2-clearance, x+width/2+clearance,
                      z-depth/2-clearance, z+depth/2+clearance))

courses = [(-102, -102, 'Sunbeam'), (102, -102, 'CoralRoofs'),
           (-102, 102, 'Wavewalk'), (102, 102, 'MintTerrace')]

for x, z, kind in courses:
    sx, sz = (1 if x > 0 else -1), (1 if z > 0 else -1)
    for side in [-1, 1]:
        for other in [-1, 1]:
            obstacle(x+side*48, z+other*48, 3.4, 3.4)
        obstacle(x+side*22, z+side*26, 24, 3)
    # The ramp starts at y=.18, finishes at y=12, and is 1.4 thick.
    run, rise = 32, 11.82
    normal_horizontal = rise / math.hypot(run, rise)
    obstacle(x+sx*64, z, 32+normal_horizontal*1.4, 18)
    obstacle(x, z+sz*64, 18, 32+normal_horizontal*1.4)
    for index in range(1, 4):
        obstacle(x, z+sz*(17+index*8), 14, 8)
    if kind == 'Sunbeam':
        for index in range(1, 6):
            obstacle(x-34+(index-1)*18, z, 14, 14)
    elif kind == 'Wavewalk':
        for index in range(1, 5):
            obstacle(x-30+(index-1)*20, z, 16, 16)
    elif kind == 'CoralRoofs':
        for side in [-1, 1]:
            for other in [-1, 1]:
                obstacle(x+side*10, z+other*12, 3.4, 3.4)
    elif kind == 'MintTerrace':
        for side in [-1, 1]:
            for other in [-1, 1]:
                obstacle(x+side*12, z+other*12, 3.4, 3.4)

for side in [-1, 1]:
    for other in [-1, 1]:
        obstacle(other*31, side*102, 3.4, 3.4)
        obstacle(side*102, other*31, 3.4, 3.4)

def point_clear(point):
    x, z = point
    return not any(x1 <= x <= x2 and z1 <= z <= z2
                   for x1, x2, z1, z2 in obstacles)

def segment_clear(a, b):
    for x1, x2, z1, z2 in obstacles:
        lo, hi = 0, 1
        for origin, delta, low, high in [
                (a[0], b[0]-a[0], x1, x2), (a[1], b[1]-a[1], z1, z2)]:
            if abs(delta) < .0001:
                if origin < low or origin > high:
                    lo = 2
                    break
            else:
                u, v = (low-origin)/delta, (high-origin)/delta
                lo, hi = max(lo, min(u, v)), min(hi, max(u, v))
        if lo <= hi and lo <= 1 and hi >= 0:
            return False
    return True

nodes = [(x, z) for x in range(-180, 181, 30) for z in range(-180, 181, 30)
         if point_clear((x, z))]
spawns = []
for side in range(1, 5):
    for index in range(1, 7):
        along = -150+(index-1)*60
        spawns.append((along, -190) if side == 1 else
                      (190, along) if side == 2 else
                      (-along, 190) if side == 3 else (-190, -along))
assert all(point_clear(spawn) for spawn in spawns)
nodes.extend(spawns)
graph = [[] for _ in nodes]
for a, q in enumerate(nodes):
    for b in range(a+1, len(nodes)):
        if math.dist(q, nodes[b]) <= 64 and segment_clear(q, nodes[b]):
            graph[a].append(b)
            graph[b].append(a)
queue, visited = [0], {0}
for current in queue:
    for neighbor in graph[current]:
        if neighbor not in visited:
            visited.add(neighbor)
            queue.append(neighbor)
assert len(visited) == len(nodes), [nodes[i] for i in range(len(nodes)) if i not in visited]
assert min(map(len, graph)) >= 1
assert len(nodes) >= 100

spec = {
    'folder': "Tag You're It", 'floor_top': 32.9,
    'center': [6500, 32.9, 4534], 'bounds_size': [416, 100, 416],
    'bounds_center': [6500, 82.9, 4534], 'area': 416*416,
    'area_ratio_to_british_bulldog': 416*416/(224*368),
    'ground_navigation': {'nodes': len(nodes), 'edges': sum(map(len, graph))//2,
                          'connected': True, 'minimum_neighbors': min(map(len, graph)),
                          'obstacle_clearance': clearance, 'all_24_spawns_connected': True},
    'spawn_pads': [[6500+x, 36.5, 4534+z] for x, z in spawns],
    'courses': [{'id': kind, 'center': [x, z], 'loop_height': 12,
                 'loop_width': 16, 'ramps': 2, 'ramp_width': 18,
                 'ramp_slope_degrees': math.degrees(math.atan(11.82/32)),
                 'ramp_run': 32, 'maximum_height': 24 if kind == 'MintTerrace' else
                 20 if kind == 'CoralRoofs' else 12,
                 'max_step_rise': 4, 'max_jump_gap': 4,
                 'open_ground_underpasses': True} for x, z, kind in courses],
    'vaults': {'count': 8, 'collision_height': 2.8, 'visual_height': 3.1},
    'shared_bridges': {'count': 4, 'height': 12, 'width': 16,
                       'ground_headroom': 10.8},
    'validation': {'ground_graph': 'passed', 'geometry_analysis': 'passed',
                   'live_humanoid_traversal': 'pending Studio playtest'},
}
(root / 'TagArenaGeometrySpec.json').write_text(json.dumps(spec, indent=2))
print(json.dumps(spec['ground_navigation']))
