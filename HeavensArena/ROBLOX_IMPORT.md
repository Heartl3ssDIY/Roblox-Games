# Heavens Arena — Hunter x Hunter

A simplified stadium arena based on the user's three references: the octagonal seating bowl from the second image, pale green seating and blue floor from the first, and a single square tiled platform. The fighting surface has no logos, lettering, smaller rings or obstacles.

## Deliverables
- Heavens_Arena.blend: final consolidated scene with packed textures, lights and three cameras.
- Heavens_Arena_Editable.blend: separate construction components for easier layout edits.
- exports/Heavens_Arena_Roblox.fbx: 36 visual meshes, 194,716 triangles; largest mesh 12,000 triangles.
- exports/Heavens_Arena_Collision.fbx: 16 simple collision meshes.
- textures/: 1024 × 1024 color, normal and roughness atlases.
- previews/: overhead, hero and ringside views.
- Configure_Arena.lua: optional helper for configuring the selected imported models in Studio Edit mode.
- source/: numbered Blender construction scripts. Update ROOT paths if moving the package.

## Layout
The fighting area is 64 × 64 Blender units, centred at the origin. The platform collision surface is Z = 1.795. Blender marker empties mark the centre, team positions at (0, -22, 1.8) and (0, 22, 1.8), and board corners at (-32, -32, 1.8) and (32, 32, 1.8). Markers are not included in the mesh-only FBX.
Eight seating sections surround the floor, with two decks, stair aisles, handrails and a perimeter lighting band. The centre of the roof is open for overhead gameplay viewing and inspection. No crowd characters are included.

## Studio setup
Import both FBX files with matching scale and transforms. Keep their relative alignment rather than centring each import separately; scale both together to suit your game.
Preserve HA_ and COL_ prefixes. Select the two imported models and run Configure_Arena.lua from Studio's command bar in Edit mode. The helper touches only matching parts within the selection.

Visual meshes are anchored, noncollidable and excluded from queries. Collision meshes are anchored, invisible and collidable. Collision covers the arena floor, platform and short platform steps. Invisible boundaries keep fighters out of the spectator stands. The seating decks are scenery and do not have walkable collision.

The atlases are embedded in the visual FBX and supplied separately. If material maps need manual assignment after import, use HA_ColorAtlas.png for color, HA_NormalAtlas.png for normals, and HA_RoughnessAtlas.png for roughness. Blender lamp emission and scene lighting are presentation settings and need separate setup in Studio.

## Checks and limitations
Both FBX files were re-imported into Blender. Mesh counts, visual triangle count, UVs and all three loaded texture maps passed validation. There are no zero-area visual triangles and no raised collision obstacles inside the 64 × 64 fighting area.
The package archive was checked for integrity. Studio import, live collision behaviour and device performance have not yet been tested.
This package contains the environment, not match logic, AI, audience animation or a full tower exterior.

## References
The user's supplied images are the primary visual references. Additional image research:
- https://medium.com/@animetips/heavens-arena-the-start-of-killua-and-gons-enduring-friendship-31bcfea8f399
- https://sfmlab.com/project/5f8e025f-0b9e-4540-a4d6-f99735cbdda9/

All geometry in this package was built for this task; no external arena model was downloaded or reused.
To reconstruct, run the numbered scripts in order in a fresh Blender scene. common.py supplies the shared helpers.
