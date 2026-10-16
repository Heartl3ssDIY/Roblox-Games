"""Read-only reach check for the approved Rock Lii Triple Punch Action."""

import bpy
from mathutils import Vector


armature = bpy.data.objects["__Rock Lii_Armature"]
armature.animation_data.use_nla = False
for track in armature.animation_data.nla_tracks:
    track.mute = True
action = bpy.data.actions["Rock Lii | Triple Punch | Review"]
armature.animation_data.action = action
armature.animation_data.action_slot = action.slots[0]
scene = bpy.context.scene
scene.render.fps = 30
scene.frame_set(1)
arms = {
    "Right": bpy.data.objects["Rock Lii.model/Right Arm.Part"],
    "Left": bpy.data.objects["Rock Lii.model/Left Arm.Part"],
}
torso = bpy.data.objects["Rock Lii.model/Torso.Part"]


def points(obj):
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [evaluated.matrix_world @ vertex.co for vertex in obj.data.vertices]


def mean(items):
    return sum(items, Vector()) / len(items)


wrist_local = {}
for side, obj in arms.items():
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    minimum = min(p.z for p in points(obj))
    indices = [i for i, p in enumerate(points(obj)) if p.z <= minimum + 0.001]
    wrist_local[side] = mean([obj.data.vertices[i].co for i in indices])
    print("WRIST_VERTICES", side, len(indices), tuple(round(v, 3) for v in wrist_local[side]))

for frame, hand in ((1, "Right"), (9, "Right"), (20, "Left"), (33, "Right")):
    scene.frame_set(frame)
    center = mean(points(torso))
    obj = arms[hand]
    wrist = obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world @ wrist_local[hand]
    offset = wrist - center
    print("FRAME", frame, "HAND", hand,
          "TORSO", tuple(round(v, 4) for v in center),
          "WRIST", tuple(round(v, 4) for v in wrist),
          "OFFSET", tuple(round(v, 4) for v in offset),
          "LENGTH", round(offset.length, 4))
