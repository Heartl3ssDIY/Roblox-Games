"""Render a review copy of one Rock Lii Action without saving or exporting the rig.

Run with Blender 5.2 in a separate background process, for example:

  blender --background "Rock Lii R6.blend" --python render_animation_previews.py -- \
      --action "Rock Lii Punch" --format mp4

The source .blend is only read. No Roblox animation is uploaded by this script.
"""

import argparse
import math
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import uuid

import bpy
from mathutils import Vector


def parse_args():
    cli = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--action", help="Exact Blender Action name; default: rig's active Action")
    parser.add_argument("--rig", help="Exact armature object name, if the file has several")
    parser.add_argument("--slot", help="Action slot identifier, if the Action has several Object slots")
    parser.add_argument("--format", choices=("mp4", "png"), default="mp4")
    parser.add_argument("--output", type=Path, help="MP4 filename or PNG frame directory")
    parser.add_argument("--ffmpeg", type=Path, help="Optional standalone FFmpeg executable for MP4 output")
    parser.add_argument("--engine", choices=("eevee", "workbench"), default="eevee")
    parser.add_argument("--width", type=int, default=960)
    parser.add_argument("--height", type=int, default=540)
    parser.add_argument("--fps", type=int, default=30)
    parser.add_argument("--max-fit-samples", type=int, default=240,
                        help="Maximum action frames sampled when fitting the camera")
    parser.add_argument("--no-floor", action="store_true", help="Hide the preview-only ground plane")
    args = parser.parse_args(cli)
    if min(args.width, args.height, args.fps, args.max_fit_samples) < 1:
        parser.error("width, height, fps, and max-fit-samples must be positive")
    return args


def choose_rig(name):
    rigs = [obj for obj in bpy.data.objects if obj.type == "ARMATURE"]
    if name:
        rig = bpy.data.objects.get(name)
        if not rig or rig.type != "ARMATURE":
            raise RuntimeError(f"Armature {name!r} not found; available: {[r.name for r in rigs]}")
        return rig
    if len(rigs) == 1:
        return rigs[0]
    raise RuntimeError(f"Specify --rig; available armatures: {[r.name for r in rigs]}")


def activate_action(rig, action_name, slot_name):
    adt = rig.animation_data_create()
    action = bpy.data.actions.get(action_name) if action_name else adt.action
    if action is None:
        raise RuntimeError(f"No Action selected; available: {[a.name for a in bpy.data.actions]}")

    previous_slot = adt.action_slot if adt.action == action else None
    # The review file may have a back-to-back NLA sequence. A preview of one
    # Action must evaluate that Action alone, not blend with those strips.
    adt.use_nla = False
    adt.action = None
    # Keys absent from the selected Action otherwise inherit the pose left by
    # the previous Action/NLA evaluation. Reset every pose channel in memory.
    for bone in rig.pose.bones:
        bone.location = (0.0, 0.0, 0.0)
        bone.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        bone.rotation_euler = (0.0, 0.0, 0.0)
        bone.rotation_axis_angle = (0.0, 0.0, 1.0, 0.0)
        bone.scale = (1.0, 1.0, 1.0)
    adt.action = action
    slots = [s for s in action.slots if s.target_id_type == "OBJECT"]
    if slot_name:
        chosen = next((s for s in slots if s.identifier == slot_name), None)
        if chosen is None:
            raise RuntimeError(f"Slot {slot_name!r} not found; available: {[s.identifier for s in slots]}")
        adt.action_slot = chosen
    elif previous_slot in slots:
        adt.action_slot = previous_slot
    elif len(slots) == 1:
        adt.action_slot = slots[0]
    elif len(slots) > 1:
        raise RuntimeError(f"Action has multiple Object slots; specify --slot from {[s.identifier for s in slots]}")

    start, end = action.frame_range
    start, end = math.floor(start), math.ceil(end)
    if end < start:
        raise RuntimeError(f"Invalid frame range for {action.name!r}: {start}..{end}")
    return action, start, end


def rig_meshes(rig):
    meshes = [
        obj for obj in bpy.data.objects
        if obj.type == "MESH" and (
            any(mod.type == "ARMATURE" and mod.object == rig for mod in obj.modifiers)
            or any(con.type == "CHILD_OF" and con.target == rig for con in obj.constraints)
        )
    ]
    if not meshes:
        raise RuntimeError(f"No mesh uses armature {rig.name!r}; refusing to render an empty rig")
    return meshes


def fit_bounds(scene, meshes, start, end, max_samples):
    step = max(1, math.ceil((end - start + 1) / max_samples))
    frames = list(range(start, end + 1, step))
    if frames[-1] != end:
        frames.append(end)
    minimum = Vector((float("inf"),) * 3)
    maximum = Vector((float("-inf"),) * 3)
    for frame in frames:
        scene.frame_set(frame)
        depsgraph = bpy.context.evaluated_depsgraph_get()
        for obj in meshes:
            evaluated = obj.evaluated_get(depsgraph)
            for corner in evaluated.bound_box:
                world = evaluated.matrix_world @ Vector(corner)
                for axis in range(3):
                    minimum[axis] = min(minimum[axis], world[axis])
                    maximum[axis] = max(maximum[axis], world[axis])
    if not all(math.isfinite(x) for x in (*minimum, *maximum)):
        raise RuntimeError("Could not evaluate animated mesh bounds")
    scene.frame_set(start)
    return minimum, maximum


def add_camera(scene, minimum, maximum, aspect):
    center = (minimum + maximum) / 2
    span = maximum - minimum
    distance = max(max(span) * 2.5, 8.0)
    camera_data = bpy.data.cameras.new("Review Camera")
    camera = bpy.data.objects.new("Review Camera", camera_data)
    scene.collection.objects.link(camera)
    # The imported character's face points along Blender +Y.
    camera.location = center + Vector((-1.1, 1.5, 0.35)).normalized() * distance
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.clip_end = distance * 10
    scene.camera = camera
    bpy.context.view_layer.update()

    inv = camera.matrix_world.inverted()
    projected = [inv @ Vector((x, y, z)) for x in (minimum.x, maximum.x)
                 for y in (minimum.y, maximum.y) for z in (minimum.z, maximum.z)]
    width = max(p.x for p in projected) - min(p.x for p in projected)
    height = max(p.y for p in projected) - min(p.y for p in projected)
    camera_data.ortho_scale = max(width, height * aspect, 2.0) * 1.3
    return center, span


def add_stage(scene, center, span, minimum, with_floor):
    world = bpy.data.worlds.new("Review World")
    world.use_nodes = True
    background = next(node for node in world.node_tree.nodes if node.type == "BACKGROUND")
    background.inputs["Color"].default_value = (0.075, 0.09, 0.13, 1)
    background.inputs["Strength"].default_value = 0.8
    scene.world = world

    reach = max(max(span), 4.0)
    for name, offset, energy, tint in (
        ("Review Key", (0.7, 0.8, 1.1), 650, (1.0, 0.91, 0.77)),
        ("Review Fill", (-1.1, 0.2, 0.65), 430, (0.65, 0.81, 1.0)),
    ):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy * (reach / 5.0) ** 2
        data.shape = "DISK"
        data.size = reach * 1.5
        data.color = tint
        light = bpy.data.objects.new(name, data)
        scene.collection.objects.link(light)
        light.location = center + Vector(offset) * reach
        light.rotation_euler = (center - light.location).to_track_quat("-Z", "Y").to_euler()

    if with_floor:
        bpy.ops.mesh.primitive_plane_add(size=2, location=(center.x, center.y, minimum.z - 0.01))
        floor = bpy.context.object
        floor.name = "Review Floor"
        floor.scale = (max(span.x, 4) * 0.8, max(span.y, 4) * 0.8, 1)
        material = bpy.data.materials.new("Review Floor Material")
        material.diffuse_color = (0.1, 0.12, 0.17, 1)
        material.use_nodes = True
        principled = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
        principled.inputs["Base Color"].default_value = material.diffuse_color
        principled.inputs["Roughness"].default_value = 0.85
        floor.data.materials.append(material)


def configure_render(scene, args):
    if args.engine == "eevee":
        for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
            try:
                scene.render.engine = engine
                break
            except TypeError:
                continue
        else:
            raise RuntimeError("Eevee is unavailable in this Blender installation")
    else:
        engine = "BLENDER_WORKBENCH"
        scene.render.engine = engine
    if engine == "BLENDER_WORKBENCH":
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "TEXTURE"
        scene.display.shading.show_cavity = True
    elif hasattr(scene, "eevee") and hasattr(scene.eevee, "taa_render_samples"):
        scene.eevee.taa_render_samples = 16
    scene.render.resolution_x = args.width
    scene.render.resolution_y = args.height
    scene.render.resolution_percentage = 100
    scene.render.fps = args.fps
    scene.render.fps_base = 1.0
    scene.render.film_transparent = False


def destination(args, action):
    base = Path(bpy.data.filepath).resolve().parent if bpy.data.filepath else Path.cwd()
    preview_dir = base / "previews"
    preview_dir.mkdir(parents=True, exist_ok=True)
    if args.output:
        target = args.output.expanduser().resolve()
    else:
        slug = "".join(c if c.isalnum() or c in "-_" else "_" for c in action.name).strip("_")
        name = f"{slug or 'Action'}_{uuid.uuid4().hex[:8]}"
        target = preview_dir / (name + (".mp4" if args.format == "mp4" else ""))
    if target.exists():
        raise FileExistsError(f"Refusing to overwrite existing preview: {target}")
    if args.format == "mp4" and target.suffix.lower() != ".mp4":
        raise ValueError("MP4 output must end in .mp4")
    target.parent.mkdir(parents=True, exist_ok=True)
    return target


def ffmpeg_executable(args):
    if args.ffmpeg:
        executable = args.ffmpeg.expanduser().resolve()
        if not executable.is_file():
            raise FileNotFoundError(f"FFmpeg executable not found: {executable}")
        return str(executable)
    bundled = Path(__file__).resolve().parent / "preview_tools" / "imageio_ffmpeg" / "binaries"
    matches = sorted(bundled.glob("ffmpeg*.exe"))
    if matches:
        return str(matches[0])
    on_path = shutil.which("ffmpeg")
    if on_path:
        return on_path
    raise RuntimeError("MP4 requires standalone FFmpeg; pass --ffmpeg path or use --format png")


def render(scene, args, target):
    if args.format == "png":
        target.mkdir(exist_ok=False)
        scene.render.image_settings.file_format = "PNG"
        scene.render.image_settings.color_mode = "RGBA"
        scene.render.filepath = str(target / "frame_")
        bpy.ops.render.render(animation=True)
        frames = sorted(target.glob("frame_*.png"))
        if not frames:
            raise RuntimeError(f"Blender produced no PNG frames in {target}")
        print(f"PREVIEW_READY {target} ({len(frames)} frames)")
        return

    encoder = ffmpeg_executable(args)
    # Some Blender builds expose FFMPEG in RNA but refuse to select it, notably
    # with Workbench. Render to a private PNG sequence, then encode externally.
    with tempfile.TemporaryDirectory(prefix="rock_lii_preview_", dir=target.parent) as temporary:
        temp_dir = Path(temporary)
        scene.render.image_settings.file_format = "PNG"
        scene.render.image_settings.color_mode = "RGB"
        scene.render.filepath = str(temp_dir / "frame_")
        bpy.ops.render.render(animation=True)
        frames = sorted(temp_dir.glob("frame_*.png"))
        expected = scene.frame_end - scene.frame_start + 1
        if len(frames) != expected:
            raise RuntimeError(f"Expected {expected} PNG frames, found {len(frames)} in {temporary}")
        movie = temp_dir / "preview.mp4"
        command = [
            encoder, "-hide_banner", "-loglevel", "error", "-n",
            "-framerate", str(args.fps),
            "-start_number", str(scene.frame_start),
            "-i", str(temp_dir / "frame_%04d.png"),
            "-frames:v", str(expected),
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(movie),
        ]
        encoded = subprocess.run(command, capture_output=True, text=True)
        if encoded.returncode != 0 or not movie.is_file():
            raise RuntimeError(f"FFmpeg failed ({encoded.returncode}): {encoded.stderr[-2000:]}")
        # Exclusive creation keeps an explicit or default destination safe from overwrite.
        with target.open("xb") as output, movie.open("rb") as source:
            shutil.copyfileobj(source, output)
    print(f"PREVIEW_READY {target}")


def main():
    args = parse_args()
    rig = choose_rig(args.rig)
    action, start, end = activate_action(rig, args.action, args.slot)
    meshes = rig_meshes(rig)
    target = destination(args, action)
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = start, end
    minimum, maximum = fit_bounds(scene, meshes, start, end, args.max_fit_samples)
    center, span = add_camera(scene, minimum, maximum, args.width / args.height)
    add_stage(scene, center, span, minimum, not args.no_floor)
    configure_render(scene, args)
    print(f"RENDERING {action.name!r}: frames {start}..{end}, {len(meshes)} rig meshes")
    render(scene, args, target)


if __name__ == "__main__":
    main()
