"""Rebuild the editable ACU Festival Citadel in a clean Blender 5 scene.

Run in a separate Blender process:
    blender --background --factory-startup --python source/rebuild_citadel.py

The in-memory scene is reset. The existing ACU_Festival_Citadel.blend is never
saved over. The only blend written is ACU_Festival_Citadel_Rebuilt.blend.
No renders, exports, uploads or game changes are performed.
"""
from pathlib import Path
import ast
import importlib.util
import random
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "source"
OUTPUT = ROOT / "ACU_Festival_Citadel_Rebuilt.blend"
SCENE_NAME = "ACU | Festival Citadel"

MODULE_NAMES = (
    "common", "base", "statue", "districts", "gardens", "presentation",
    "polish", "garden_polish", "district_backdrop", "expansion",
    "city_expansion", "outer_gardens", "finishing", "arena_portal_walk",
    "city_fixes", "landscape_fixes", "final_fixes", "texture_pass",
)

PBR_MAPS = ("Color", "Normal", "Roughness")

FINAL_CAMERAS = {
    "CAM_08_ExpandedCity": ((483, -677, 510), (0, 0, 6), 43),
    "CAM_09_MarketStreet": ((155, -211, 9), (155, -91, 18), 31),
    "CAM_10_Waterfall": ((-290, 40, 25), (-239, 130, 32), 31),
    "CAM_11_Pagoda": ((93, 70, 19), (140, 140, 39), 28),
    "CAM_12_GrandEntrance": ((0, -285, 11), (0, -128, 17), 31),
    "CAM_13_CivicCourt": ((-31, -31, 10), (9, 45, 17), 28),
}


def _texture_assets():
    path = SOURCE / "texture_pass.py"
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    for statement in tree.body:
        if isinstance(statement, ast.Assign) and any(
            isinstance(target, ast.Name) and target.id == "SPECS"
            for target in statement.targets
        ):
            specs = ast.literal_eval(statement.value)
            assets = sorted({entry[0] for entry in specs.values()})
            if not assets or not all(isinstance(asset, str) and asset for asset in assets):
                raise ValueError("texture_pass.SPECS must contain image texture family names.")
            return assets
    raise ValueError("texture_pass.py has no literal SPECS mapping for asset preflight.")


def _preflight():
    required = [SOURCE / (name + ".py") for name in MODULE_NAMES]
    required.extend(ROOT / "textures" / name for name in (
        "ACU_Logo.png",
        "Anime_Combat_Units_Full_Logo.png",
        "PermanentMarker-Regular.ttf",
    ))
    required.extend(
        ROOT / "textures" / "PBR" / (asset + "_" + channel + ".jpg")
        for asset in _texture_assets() for channel in PBR_MAPS
    )
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise FileNotFoundError("Missing packaged rebuild inputs:\n" + "\n".join(missing))
    if bpy.app.version < (5, 0, 0):
        raise RuntimeError("This saved presentation pipeline requires Blender 5 or newer.")
    for folder in ("previews", "exports"):
        (ROOT / folder).mkdir(parents=True, exist_ok=True)


def _load_module(name):
    path = SOURCE / (name + ".py")
    spec = importlib.util.spec_from_file_location(name, str(path))
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    module.ROOT = str(ROOT)
    return module


def _fresh_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = SCENE_NAME
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = engine
            break
        except (TypeError, ValueError):
            continue
    else:
        raise RuntimeError("No Eevee render engine is available.")
    return scene


def _reserve_character_pedestal():
    collection = bpy.data.collections.get("ACU | 20_Statue")
    allowed = ("dais", "plinth", "pedestal", "step", "base_ring", "foundation")
    if collection:
        for ob in list(collection.objects):
            if not any(token in ob.name.lower() for token in allowed):
                bpy.data.objects.remove(ob, do_unlink=True)


def _remove_statue_glow():
    collection = bpy.data.collections.get("ACU | 21_StatueGlow")
    if collection:
        for ob in list(collection.objects):
            bpy.data.objects.remove(ob, do_unlink=True)


def _final_cameras(presentation):
    for name, (location, target, lens) in FINAL_CAMERAS.items():
        camera = bpy.data.objects.get(name)
        if camera is None:
            camera = presentation.camera(name, location, target, lens)
        camera.location = location
        camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
        camera.data.lens = lens
        camera.data.clip_start = 0.1
        camera.data.clip_end = 3000
    bpy.context.scene.camera = bpy.data.objects["CAM_13_CivicCourt"]


def _final_lighting():
    scene = bpy.context.scene
    world = scene.world
    if world is None:
        raise RuntimeError("The presentation module did not create a world.")
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    background = next(node for node in nodes if node.type == "BACKGROUND")
    sky = next((node for node in nodes if node.type == "TEX_SKY"), None)
    if sky is None:
        sky = nodes.new("ShaderNodeTexSky")
    sky.name = "ACU Festival Multi-Scattering Sky"
    sky.sky_type = "MULTIPLE_SCATTERING"
    sky.sun_elevation = 0.27
    sky.sun_rotation = 2.2
    sky.sun_disc = False
    sky.air_density = 1.0
    sky.aerosol_density = 0.65
    links.new(sky.outputs["Color"], background.inputs["Color"])
    background.inputs["Strength"].default_value = 0.055
    scene.view_settings.exposure = 0.1

    compositor = scene.compositing_node_group
    if compositor is None:
        raise RuntimeError("The presentation module did not create the compositor.")
    glare_nodes = [node for node in compositor.nodes if node.type == "GLARE"]
    if not glare_nodes:
        raise RuntimeError("The presentation compositor has no Glare node.")
    for glare in glare_nodes:
        glare.inputs["Type"].default_value = "Fog Glow"
        glare.inputs["Threshold"].default_value = 2.0
        glare.inputs["Strength"].default_value = 0.18
        glare.inputs["Size"].default_value = 0.28

    eevee = scene.eevee
    eevee.use_fast_gi = True
    eevee.fast_gi_quality = 1.0
    eevee.fast_gi_ray_count = 4
    eevee.fast_gi_step_count = 32
    eevee.fast_gi_distance = 20.0
    eevee.use_raytracing = True
    eevee.taa_render_samples = 128
    scene.render.resolution_x = 2400
    scene.render.resolution_y = 1500
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.filepath = str(ROOT / "previews" / "Rebuilt_Civic_Court.png")


def _run(label, function):
    print("ACU rebuild: " + label, flush=True)
    function()
    bpy.context.view_layer.update()


def build():
    _preflight()
    if str(SOURCE) not in sys.path:
        sys.path.insert(0, str(SOURCE))
    for name in MODULE_NAMES:
        sys.modules.pop(name, None)

    scene = _fresh_scene()
    modules = {}
    common = _load_module("common")
    modules["common"] = common
    common.FONT = bpy.data.fonts.load(
        str(ROOT / "textures" / "PermanentMarker-Regular.ttf"),
        check_existing=True,
    )
    for name in MODULE_NAMES[1:]:
        modules[name] = _load_module(name)

    random.seed(90726)
    _run("original civic foundation", modules["base"].build)
    _run("editable character podium", modules["statue"].build)
    _reserve_character_pedestal()
    _run("civic activity buildings", modules["districts"].build)
    _run("inner gardens", modules["gardens"].build)
    _run("original ACU branding", modules["base"].brand)
    _run("presentation, lighting and cameras", lambda: modules["presentation"].build(save=False))
    _final_cameras(modules["presentation"])
    _run("architectural and festival polish", modules["polish"].build)
    _remove_statue_glow()
    _run("canopy and garden detail", modules["garden_polish"].build)
    _run("inner town skyline", modules["district_backdrop"].build)
    _run("expanded land and avenues", modules["expansion"].build)
    _run("outer city architecture", modules["city_expansion"].build)
    _run("waterfall, lake and forest districts", modules["outer_gardens"].build)
    _run("final land perimeter and brand monument", modules["finishing"].build)
    _run("nine arena portal stations", modules["arena_portal_walk"].build)
    _run("street and upper-gallery access fixes", modules["city_fixes"].build)
    _run("landscape and building-clearance fixes", modules["landscape_fixes"].build)

    _reserve_character_pedestal()
    _remove_statue_glow()
    _final_cameras(modules["presentation"])
    _final_lighting()
    _run("final cliff, shadow-pool and waterfall-camera fixes", modules["final_fixes"].build)
    _run("real image PBR surface textures", modules["texture_pass"].apply)
    scene["ACU_RebuildSource"] = "source/rebuild_citadel.py"
    scene["ACU_RebuildOutput"] = OUTPUT.name
    scene["ACU_CharacterPedestal"] = "Reserved for the user's Roblox character."
    scene["ACU_EditableBuild"] = True
    bpy.context.view_layer.update()

    if bpy.context.screen:
        for area in bpy.context.screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.region_3d.view_perspective = "CAMERA"
                area.spaces.active.clip_end = 3000
    bpy.ops.file.pack_all()
    for image in bpy.data.images:
        if image.source == "FILE" and image.filepath:
            absolute = Path(bpy.path.abspath(image.filepath))
            if absolute.is_file():
                image.filepath = bpy.path.relpath(str(absolute), start=str(ROOT))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
    print("ACU_REBUILD_COMPLETE " + str(OUTPUT), flush=True)
    return OUTPUT


if __name__ == "__main__":
    build()
