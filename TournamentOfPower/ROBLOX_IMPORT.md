# Tournament of Power — Anime Combat Units

Reference: the intact Tournament of Power arena from the supplied Dragon Ball Super images.

## Files
- Tournament_of_Power.blend: editable scene, packed textures, cameras and presentation lighting.
- exports/Tournament_of_Power_Roblox.fbx: six visual mesh modules with embedded textures.
- exports/Tournament_of_Power_Collision.fbx: separate convex floor collision mesh.
- textures: 2048px color, roughness and normal maps.
- previews: hero, overhead and underside renders.
- source: modeling helpers, construction, refinement, export and validation scripts.
- Configure_Arena.lua: optional Studio Command Bar setup for the selected imported models.

The Chunin Hall was preserved separately. Before_Tournament_of_Power.blend is the pre-build backup and is intentionally excluded from the delivery zip.

## Model
116-unit diameter court. Central pillar is 38.7 units above the floor. The curved stand has a 147-unit outer diameter. A centered 64 by 64 combat area fits inside the court. Team markers are at (0,-23,0.026) and (0,23,0.026) in Blender coordinates. The surface is at Blender Z=0.026.

The six visible modules total 25,970 triangles; the largest module has 5,856 triangles. The original spectator stand construction is retained in a hidden archive collection and is excluded from the FBX.

## Roblox setup
Use the same intended 1 Blender unit to 1 Roblox stud scale as the previous arena. Import both FBX files with matching origin and scale; check that the court diameter measures 116 studs. Blender Z becomes Roblox Y. Keep all six visual modules non-collidable and anchored. Use only the separate COL_Arena_Disc for the playable collision surface; set its CollisionFidelity to Hull.

The centre pillar remains visible and separate as TOP_Center_Pillar_NONCOLLIDE. Its custom properties document CanCollide=false, CanTouch=false, CanQuery=true. FBX metadata does not automatically configure Roblox properties: apply these in Studio or run the supplied setup helper on the selected imported models. No click interaction is implemented. CanQuery=true leaves it available for a future click interaction; ground-targeting raycasts should explicitly exclude this pillar if they must pass through it.

The floating spectator stand is decorative and has no collision proxy. The arena has no perimeter barrier, matching the open reference. Ring-out logic, AI navigation, scene transitions, effects and other gameplay behavior are not added.

The procedural World of Void background and lighting are Blender presentation elements, not exported Roblox sky assets.

## Verification
All six visual meshes were exported and re-imported into a temporary Blender scene. The round trip preserved the three texture maps, UVs, triangle count, separate pillar and its non-collision metadata. There were no zero-area faces. The saved standalone Blender file contains only the Tournament of Power scene.

The asset has not yet been imported or performance-tested in Roblox Studio.

## Regeneration
The build scripts retain the local project path in ROOT. To rebuild elsewhere, update ROOT and source paths. Run 01_build_arena.py, 02_refine_and_render.py, then 03_export.py in an empty Blender scene to avoid duplicate names. These scripts are construction sources, not game scripts.
