import bpy
import bmesh
import json
import math
from pathlib import Path
from mathutils import Matrix, Vector

root = Path(r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\StuckInTheMud20261003")
native_path = root / "NativeMudGeometry.json"
isolated = bpy.app.background
blend_path = root / ("NativeMudArena_IsolatedPreview.blend" if isolated else "NativeMudArenaPreview.blend")
image_path = root / ("NativeMudArena_IsolatedWide.png" if isolated else "NativeMudArena_Wide.png")
report_path = root / ("NativeMudIsolatedRenderReport.json" if isolated else "NativeMudRenderReport.json")
native = json.loads(native_path.read_text(encoding="utf-8-sig"))
origin = Vector(native["origin"])
parts = native["parts"]
assert len(parts) == 1511
original_scene = bpy.context.scene
original_filepath = bpy.data.filepath
original_active = bpy.context.view_layer.objects.active
original_selection = set(bpy.context.selected_objects)
original_windows = [(window, window.scene, window.view_layer) for window in bpy.context.window_manager.windows]
groups = ("objects", "meshes", "materials", "worlds", "cameras", "lights", "collections", "scenes")
original_data = {name: set(getattr(bpy.data, name)) for name in groups}
created = {name: [] for name in groups}
preview = None
report = {}


def enum(owner, name, value):
    valid = [item.identifier for item in owner.bl_rna.properties[name].enum_items]
    assert value in valid, (name, value, valid)
    setattr(owner, name, value)


def linear(channel):
    value = channel / 255.0
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


try:
    preview = bpy.data.scenes.new("PCMudNativePreview20261003")
    print(json.dumps({"stage": "started", "isolatedBackground": isolated}), flush=True)
    created["scenes"].append(preview)
    collection = bpy.data.collections.new("PCMud_ActualNativeParts")
    created["collections"].append(collection)
    preview.collection.children.link(collection)
    preview["Source"] = str(native_path)
    preview["NativePartCount"] = len(parts)
    preview["RobloxOrigin"] = list(origin)
    preview["AxisConversion"] = "Roblox(X,Y,Z) to Blender(X,-Z,Y); one unit per stud"
    preview.render.resolution_x = 2048
    preview.render.resolution_y = 1152
    preview.render.resolution_percentage = 100
    enum(preview.render.image_settings, "file_format", "PNG")
    enum(preview.render.image_settings, "color_mode", "RGBA")
    preview.render.filepath = str(image_path)
    preview.render.film_transparent = False
    try:
        preview.render.engine = "BLENDER_WORKBENCH"
    except TypeError as error:
        raise RuntimeError("Workbench renderer is unavailable: " + str(error))
    shading = preview.display.shading
    enum(shading, "light", "STUDIO")
    enum(shading, "color_type", "MATERIAL")
    enum(shading, "background_type", "VIEWPORT")
    enum(shading, "cavity_type", "BOTH")
    shading.studio_light = original_scene.display.shading.studio_light
    shading.background_color = (0.16, 0.21, 0.28)
    shading.show_shadows = True
    shading.show_cavity = True
    shading.show_specular_highlight = False
    shading.show_object_outline = False
    if hasattr(shading, "curvature_ridge_factor"):
        shading.curvature_ridge_factor = 1.15
        shading.curvature_valley_factor = 1.05
    preview.view_settings.view_transform = original_scene.view_settings.view_transform
    preview.view_settings.exposure = 0.8
    preview.view_settings.gamma = 1

    meshes = {}
    for shape in ("Block", "Cylinder", "Ball"):
        mesh = bpy.data.meshes.new("PCMud_Unit" + shape)
        created["meshes"].append(mesh)
        bm = bmesh.new()
        if shape == "Block":
            bmesh.ops.create_cube(bm, size=1)
        elif shape == "Cylinder":
            bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=32, radius1=0.5, radius2=0.5, depth=1)
            bmesh.ops.transform(bm, matrix=Matrix.Rotation(math.pi / 2, 4, "Y"), verts=bm.verts)
        else:
            bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=0.5)
        bm.to_mesh(mesh)
        bm.free()
        if shape == "Ball":
            for polygon in mesh.polygons:
                polygon.use_smooth = True
        meshes[shape] = mesh

    materials = {}
    for rgb in sorted(set(tuple(part[5]) for part in parts)):
        material = bpy.data.materials.new("PCMud_RGB_" + "_".join(map(str, rgb)))
        created["materials"].append(material)
        color = tuple(linear(value) for value in rgb) + (1.0,)
        material.diffuse_color = color
        material.use_nodes = True
        principled = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
        principled.inputs[0].default_value = color
        principled.inputs[1].default_value = 0
        principled.inputs[2].default_value = 0.85
        materials[rgb] = material
    default_material = next(iter(materials.values()))
    for mesh in meshes.values():
        mesh.materials.append(default_material)

    axes = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
    corners = []
    for index, part in enumerate(parts, 1):
        name, class_name, shape, size, cframe, rgb, transparency = part
        assert class_name == "Part" and shape in meshes and transparency == 0
        assert all(math.isfinite(value) for value in size + cframe)
        assert all(value > 0 for value in size)
        native_rotation = Matrix((cframe[3:6], cframe[6:9], cframe[9:12]))
        rotation = axes @ native_rotation @ axes.transposed()
        position = axes @ (Vector(cframe[:3]) - origin)
        scale = Vector((size[0], size[2], size[1]))
        obj = bpy.data.objects.new(f"PCMud_{index:04d}_{name}", meshes[shape])
        created["objects"].append(obj)
        collection.objects.link(obj)
        obj.matrix_world = Matrix.LocRotScale(position, rotation.to_quaternion(), scale)
        obj.material_slots[0].link = "OBJECT"
        obj.material_slots[0].material = materials[tuple(rgb)]
        obj.color = materials[tuple(rgb)].diffuse_color
        obj["RobloxName"] = name
        obj["RobloxClass"] = class_name
        obj["RobloxShape"] = shape
        obj["RobloxSize"] = size
        obj["RobloxCFrame"] = cframe
        for x in (-0.5, 0.5):
            for y in (-0.5, 0.5):
                for z in (-0.5, 0.5):
                    corners.append(obj.matrix_world @ Vector((x, y, z)))

    camera_data = bpy.data.cameras.new("PCMud_OverviewCamera")
    print(json.dumps({"stage": "geometry_created", "parts": len(parts)}), flush=True)
    created["cameras"].append(camera_data)
    camera = bpy.data.objects.new("PCMud_OverviewCamera", camera_data)
    created["objects"].append(camera)
    preview.collection.objects.link(camera)
    enum(camera_data, "type", "ORTHO")
    camera_data.clip_start = 0.1
    camera_data.clip_end = 10000
    target = Vector((0, 0, 12))
    camera.location = target + Vector((880, 1080, 1280))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    preview.camera = camera
    rotation = camera.rotation_euler.to_matrix()
    camera_local = [rotation.transposed() @ (point - camera.location) for point in corners]
    min_x, max_x = min(point.x for point in camera_local), max(point.x for point in camera_local)
    min_y, max_y = min(point.y for point in camera_local), max(point.y for point in camera_local)
    camera.location += rotation @ Vector(((min_x + max_x) / 2, (min_y + max_y) / 2, 0))
    camera_data.ortho_scale = 1
    unit_frame = camera_data.view_frame(scene=preview)
    frame_width = max(point.x for point in unit_frame) - min(point.x for point in unit_frame)
    frame_height = max(point.y for point in unit_frame) - min(point.y for point in unit_frame)
    camera_data.ortho_scale = max((max_x - min_x) / frame_width, (max_y - min_y) / frame_height) * 1.1
    for view_layer in preview.view_layers:
        view_layer.update()
    if isolated:
        save_operator = bpy.ops.wm.save_as_mainfile
        save_properties = save_operator.get_rna_type().properties
        assert "filepath" in save_properties and "copy" in save_properties
        assert bpy.context.window is not None
        bpy.context.window.scene = preview
        save_operator(filepath=str(blend_path), copy=True)
    else:
        bpy.data.libraries.write(str(blend_path), {preview}, compress=True)
    print(json.dumps({"stage": "blend_saved", "path": str(blend_path)}), flush=True)
    bpy.ops.render.render(write_still=True, scene=preview.name)
    assert blend_path.is_file() and image_path.is_file()
    report = {
        "source": str(native_path),
        "isolatedBackgroundProcess": isolated,
        "nativeParts": len(parts),
        "meshes": 3,
        "materials": len(materials),
        "axisConversion": "Roblox(X,Y,Z) to Blender(X,-Z,Y)",
        "engine": preview.render.engine,
        "image": str(image_path),
        "blend": str(blend_path),
        "resolution": [preview.render.resolution_x, preview.render.resolution_y],
        "exposure": preview.view_settings.exposure,
        "cameraPosition": list(camera.location),
        "orthographicScale": camera_data.ortho_scale,
    }
finally:
    for window, scene, view_layer in original_windows:
        if window.scene != scene:
            window.scene = scene
        if window.view_layer != view_layer:
            window.view_layer = view_layer
    for scene in created["scenes"]:
        bpy.data.scenes.remove(scene)
    for name in ("objects", "collections", "meshes", "materials", "worlds", "cameras", "lights"):
        datablocks = getattr(bpy.data, name)
        for datablock in created[name]:
            datablocks.remove(datablock, do_unlink=True)
    assert bpy.context.scene == original_scene
    assert bpy.data.filepath == original_filepath
    assert bpy.context.view_layer.objects.active == original_active
    assert set(bpy.context.selected_objects) == original_selection
    assert all(set(getattr(bpy.data, name)) == original_data[name] for name in groups)
    if report:
        report["factoryStartupStateRestored" if isolated else "liveStateRestored"] = True
        if isolated:
            report["liveStateVerification"] = "Not rechecked; earlier live MCP calls timed out. This separate process does not access the live instance."
        report["originalFilepath"] = original_filepath
        report["originalScene"] = original_scene.name
        report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps(report))
