"""Arrange the two authored Actions for local review in the open Blender file."""

import bpy


def setup_review_playback(armature):
    animation = armature.animation_data_create()
    if animation.nla_tracks:
        raise RuntimeError("Existing NLA tracks need review before rearranging playback")
    punch = bpy.data.actions["Rock Lii | Triple Punch | Review"]
    drunken = bpy.data.actions["Rock Lii - Drunken Fist (REVIEW)"]
    animation.action = None
    for bone in armature.pose.bones:
        bone.location = (0, 0, 0)
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.scale = (1, 1, 1)
    animation.use_nla = True
    track = animation.nla_tracks.new()
    track.name = "REVIEW | Triple Punch then Drunken Fist"
    for name, start, action in (
        ("Triple Punch | 1.5 seconds", 1, punch),
        ("Drunken Fist | 7 seconds", 76, drunken),
    ):
        strip = track.strips.new(name, start, action)
        strip.action_slot = action.slots[0]
        strip.action_frame_start = action.frame_range[0]
        strip.action_frame_end = action.frame_range[1]
        strip.frame_start = start
        strip.frame_end = start + action.frame_range[1] - action.frame_range[0]
        strip.extrapolation = "NOTHING"
        strip.blend_type = "REPLACE"
        strip.use_auto_blend = False
        strip.blend_in = 0
        strip.blend_out = 0
    scene = bpy.context.scene
    scene.render.fps = 30
    scene.render.fps_base = 1.0
    scene.frame_start = 1
    scene.frame_end = 300
    for label, frame in (
        ("REVIEW: Triple Punch", 1),
        ("Hit 1", 9), ("Hit 2", 20), ("Hit 3", 33),
        ("REVIEW: Drunken Fist", 76),
        ("Return to neutral", 286),
    ):
        scene.timeline_markers.new(label, frame=frame)
    scene["animation_review"] = "Local draft only; user review required before Roblox upload."
    scene.frame_set(1)
    text = bpy.data.texts.get("Rock Lii Animation Review Notes") or bpy.data.texts.new("Rock Lii Animation Review Notes")
    text.clear()
    text.write(
        "ROCK LII — LOCAL ANIMATION REVIEW\n\n"
        "Press Space over a viewport to play the two moves.\n"
        "Frames 1–46: right/left/right triple punch (1.5 seconds).\n"
        "Frames 76–286: Drunken Fist (7 seconds).\n"
        "Both individual Actions remain available for editing.\n\n"
        "This is the exported Rock Lee R6 model; in-game name is Rock Lii.\n"
        "Hair is deferred. These Actions are not uploaded to Roblox.\n"
        "Drunken Fist stays in place for review. Gameplay must move the unit\n"
        "through enemy rows, evaluate fist contacts, and apply invulnerability.\n"
    )
    return track
