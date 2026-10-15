# Chunin Exam Hall

A stylized, reference-based Naruto Chunin preliminary-exam hall for Anime Combat Units, following the Tenkaichi arena's editable Blender and Roblox export workflow.

Includes green stone tiling, a semicircular judges' dais, giant hand-sign sculpture with patterned green sleeves, raised side galleries, railings, access stairs, tall wall panels, blue rear windows and lanterns. No characters or gameplay logic are included.

## Files
- Chunin_Exam_Hall.blend: finished scene, open in Blender; organized into 15 editable visual mesh modules.
- Chunin_Exam_Hall_Editable.blend: construction scene with individual building components, before final mesh consolidation.
- Before_Chunin_Hall.blend: backup of the original unsaved default scene.
- exports/Chunin_Exam_Hall_Roblox.fbx: visual model, with embedded color/normal/roughness textures.
- exports/Chunin_Hall_Collision.fbx: 37 separate collision shapes.
- textures/: three 2048px portable PBR maps.
- previews/: hero view, sculpture detail and overhead view.
- source/: modeling, refinement, export and validation scripts.
- Configure_Hall.lua: optional helper for selected imported models.
- exports/mesh_report.json and fbx_validation.json: measured geometry and export checks.

## Scale and layout
One Blender unit is intended as one Roblox stud, matching the Tenkaichi workflow.
- Overall foundation: approximately 82 x 110.
- Clear combat square: 64 x 64, Blender center (0, -20, 0.2).
- Combat bounds: X -32 to 32; Y -52 to 12.
- Fighting surface height: Blender Z = 0.2.
- Dais top: 1.5; gallery top: approximately 14.
- Non-rendering markers: Arena_Center, Team_A_Spawn, Team_B_Spawn and Camera_Target.
- Roof/front are open for the overhead game camera; side and rear walls are modeled.
- The entrance stairs sit outside the combat square.

## Roblox import
Import the visual and collision FBX files with identical scene-position, unit and orientation settings used for Tenkaichi. The exports use Z Forward / Y Up and FBX unit-scale conversion. Check the 64-unit combat area before accepting importer scaling.

Keep imported visual parts anchored and non-collidable. Keep COL_ parts anchored, solid and invisible. The optional Configure_Hall.lua works only on the selected imports.

If the importer does not create all SurfaceAppearance maps, assign:
- Chunin_ColorAtlas.png -> ColorMap
- Chunin_NormalAtlas.png -> NormalMap
- Chunin_RoughnessAtlas.png -> RoughnessMap
Use a white MeshPart color. No metalness map is needed.

The baked color atlas preserves the palette; render lights/cameras remain Blender presentation elements. Add game lighting in Studio as needed. Collision shapes cover the main floor, galleries, stairs, rear dais, sculpture block, and side/rear walls. The front remains open.

## Verification
The visual FBX was imported into a separate Blender validation scene:
- 15 meshes, 87,698 triangles total.
- Largest individual mesh: 13,992 triangles.
- All meshes have UVs.
- Three textures successfully loaded.
- Zero zero-area faces.
- Hero, overhead and close renders visually inspected.
- Not imported into or performance-tested in Roblox Studio yet.

All outputs are stored locally, outside OneDrive.
