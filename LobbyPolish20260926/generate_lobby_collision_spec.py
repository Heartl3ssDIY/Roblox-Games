"""Derive a conservative Roblox collision/seat plan from the saved ACU Blender scene.

Run with Blender in background mode, opening ACU_Festival_Citadel.blend first.
The script only reads the .blend and writes lobby_collision_seats_1p5.json.
"""

import json
import math
import re
from collections import Counter, defaultdict
from pathlib import Path

import bpy
from mathutils import Vector


LIVE_SCALE = 1.5
OUTPUT = Path(__file__).with_name("lobby_collision_seats_1p5.json")


def rnd(value):
    return round(float(value), 3)


def roblox_pos(blender_pos):
    return [
        rnd(-blender_pos[0] * LIVE_SCALE),
        rnd(blender_pos[2] * LIVE_SCALE),
        rnd(blender_pos[1] * LIVE_SCALE),
    ]


def mesh_points(obj):
    return [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]


def bounds(points):
    return (
        Vector((min(p[i] for p in points) for i in range(3))),
        Vector((max(p[i] for p in points) for i in range(3))),
    )


def quantile(values, fraction):
    values = sorted(values)
    at = (len(values) - 1) * fraction
    low = math.floor(at)
    high = math.ceil(at)
    return values[low] + (values[high] - values[low]) * (at - low)


def oriented_box(obj, category, shrink=0.9, minimum_depth=0.18):
    corners = [Vector(corner) for corner in obj.bound_box]
    low, high = bounds(corners)
    local_center = (low + high) * 0.5
    basis = obj.matrix_world.to_3x3()
    blender_size = [
        (high.x - low.x) * basis.col[0].length,
        (high.y - low.y) * basis.col[1].length,
        (high.z - low.z) * basis.col[2].length,
    ]
    local_x_world = basis @ Vector((1, 0, 0))
    yaw = math.degrees(math.atan2(-local_x_world.y, -local_x_world.x))
    return {
        "category": category,
        "source_object": obj.name,
        "shape": "box",
        "position": roblox_pos(obj.matrix_world @ local_center),
        "size": [
            rnd(blender_size[0] * LIVE_SCALE * shrink),
            rnd(blender_size[2] * LIVE_SCALE * shrink),
            rnd(max(minimum_depth, blender_size[1] * LIVE_SCALE * shrink)),
        ],
        "yaw_degrees": rnd(yaw),
        "transparent": True,
        "can_collide": True,
    }


def trunk_collider(obj):
    points = mesh_points(obj)
    low, high = bounds(points)
    trunk_height = high.z - low.z
    if trunk_height < 1:
        return None
    slice_bottom = low.z + min(0.6, trunk_height * 0.08)
    slice_top = low.z + min(4.2, max(1.8, trunk_height * 0.38))
    core = [p for p in points if slice_bottom <= p.z <= slice_top]
    if len(core) < 8:
        core = [p for p in points if p.z <= low.z + trunk_height * 0.55]
    if len(core) < 8:
        core = points
    center_x = quantile([p.x for p in core], 0.5)
    center_y = quantile([p.y for p in core], 0.5)
    radius = quantile(
        [math.hypot(p.x - center_x, p.y - center_y) for p in core], 0.74
    ) * 0.76
    radius = max(0.32, min(1.65 if "Hero_Sakura" in obj.name else 1.3, radius))
    height = min(8.5, max(3.8, trunk_height * 0.72))
    return {
        "category": "tree_trunk",
        "source_object": obj.name,
        "shape": "vertical_cylinder",
        "position": roblox_pos((center_x, center_y, low.z + height * 0.5)),
        "radius": rnd(radius * LIVE_SCALE),
        "height": rnd(height * LIVE_SCALE),
        "transparent": True,
        "can_collide": True,
    }


def rock_collider(obj):
    points = mesh_points(obj)
    low, high = bounds(points)
    extent = high - low
    if max(extent.x, extent.y) > 23 or extent.z > 13:
        return None
    center = (low + high) * 0.5
    return {
        "category": "prominent_rock",
        "source_object": obj.name,
        "shape": "ellipsoid",
        "position": roblox_pos(center),
        "size": [
            rnd(max(0.8, extent.x * LIVE_SCALE * 0.82)),
            rnd(max(0.55, extent.z * LIVE_SCALE * 0.78)),
            rnd(max(0.8, extent.y * LIVE_SCALE * 0.82)),
        ],
        "transparent": True,
        "can_collide": True,
    }


def is_rock(name):
    return bool(
        re.fullmatch(r"Garden_Rock_\d\d", name)
        or re.fullmatch(r"MoonPond_ShoreRock_\d\d", name)
        or re.fullmatch(r"EasternForest_MossBoulder_\d\d", name)
        or re.fullmatch(r"Portal_Garden_Rock(?:\.\d{3})?", name)
    )


def bench_entries(name, planks):
    if len(planks) != 4:
        raise ValueError(f"{name}: expected four seat planks, found {len(planks)}")
    first = planks[0]
    axis = first.matrix_world.to_3x3()
    side = Vector((axis.col[0].x, axis.col[0].y, 0)).normalized()
    back = Vector((axis.col[1].x, axis.col[1].y, 0)).normalized()
    center = sum((obj.matrix_world.translation for obj in planks), Vector()) / 4
    points = [point for obj in planks for point in mesh_points(obj)]
    seat_top = max(point.z for point in points)
    half_span = (max(point.dot(side) for point in points) - min(point.dot(side) for point in points)) / 2
    depth = max(point.dot(back) for point in points) - min(point.dot(back) for point in points)
    front_roblox = Vector((back.x, -back.y))
    yaw = math.degrees(math.atan2(-front_roblox.x, -front_roblox.y))
    offsets = (-min(1.35, half_span * 0.47), min(1.35, half_span * 0.47))
    entries = []
    for index, offset in enumerate(offsets, 1):
        seat_center = center + side * offset
        seat_center.z = seat_top - 0.05
        entries.append(
            {
                "category": "bench_seat",
                "source_object": name,
                "seat_index": index,
                "shape": "seat",
                "position": roblox_pos(seat_center),
                "size": [rnd(min(3.2, half_span * LIVE_SCALE * 0.72)), 0.2, rnd(min(2.35, depth * LIVE_SCALE * 0.84))],
                "yaw_degrees": rnd(yaw),
                "transparent": True,
                "can_collide": True,
            }
        )
    back_center = center + back * (depth * 0.5 + 0.12)
    back_center.z = seat_top + 0.55
    entries.append(
        {
            "category": "bench_back",
            "source_object": name,
            "shape": "box",
            "position": roblox_pos(back_center),
            "size": [rnd(half_span * 2 * LIVE_SCALE * 0.91), 1.7, 0.25],
            "yaw_degrees": rnd(yaw),
            "transparent": True,
            "can_collide": True,
        }
    )
    return entries


def build():
    scene = bpy.context.scene
    if scene is None or "Festival Citadel" not in scene.name:
        raise RuntimeError("Open the authoritative ACU_Festival_Citadel.blend first")
    bpy.context.view_layer.update()
    objects = {
        obj.name: obj
        for obj in scene.objects
        if obj.type == "MESH" and not obj.hide_render
    }
    entries = []
    for name in sorted(objects):
        obj = objects[name]
        if "trunk" in name.lower():
            collider = trunk_collider(obj)
            if collider:
                entries.append(collider)
        elif is_rock(name):
            collider = rock_collider(obj)
            if collider:
                entries.append(collider)

    counter_names = {
        "MoonTea_counter",
        "ScrollAtelier_counter",
        "LuckyCharms_counter",
        "SHOP_counter",
    }
    sign_names = {
        "PVP_RANKED_sign_back",
        "PVP_UNRANKED_sign_back",
        "BOARD_SEASON_RANK_body",
        "BOARD_MOST_WINS_body",
        "BOARD_ARENA_MASTERY_body",
        "TrainingCourt_SignPost",
        "TrainingCourt_SignPost.001",
    }
    for name in sorted(counter_names | sign_names):
        obj = objects.get(name)
        if obj is None:
            raise RuntimeError(f"Missing expected lobby source object: {name}")
        entries.append(
            oriented_box(
                obj,
                "market_counter" if name in counter_names else "sign_or_board",
                shrink=0.92 if name in counter_names else 0.87,
            )
        )

    bench_planks = defaultdict(list)
    for name, obj in objects.items():
        match = re.fullmatch(r"(.+)_SeatPlank_0[0-3]", name)
        if match:
            bench_planks[match.group(1)].append(obj)
    if len(bench_planks) != 12:
        raise RuntimeError(f"Expected 12 source benches, found {len(bench_planks)}")
    for name in sorted(bench_planks):
        entries.extend(bench_entries(name, bench_planks[name]))

    entries.sort(key=lambda item: (item["category"], item["source_object"], item.get("seat_index", 0)))
    counts = dict(sorted(Counter(entry["category"] for entry in entries).items()))
    result = {
        "source_blend": str(Path(bpy.data.filepath).resolve()),
        "target_place_id": 111313211501470,
        "target_model": "Workspace.Lobby_MainModeZone",
        "lobby_model_scale": LIVE_SCALE,
        "coordinate_map": "Roblox (X,Y,Z) = (-Blender X, Blender Z, Blender Y) * 1.5",
        "purpose": "Conservative invisible prop colliders and two Roblox Seats per existing bench. Excludes terrain, cliffs, paths and roads.",
        "collision_folder": "Workspace.Lobby_MainModeZone.Collision.LobbyPolish20260926",
        "counts": counts,
        "entries": entries,
    }
    OUTPUT.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(f"SPEC_SAVED {OUTPUT}")
    print(f"COUNTS {json.dumps(counts, sort_keys=True)}")


if __name__ == "__main__":
    build()
