# Wano — Flower Capital Street

A simplified, stylized Wano street arena built from the user's supplied references. The open tan street is the combat space. Colourful curved roofs, cherry trees, a red torii gate, a red-railed approach bridge and a raised castle framed by a giant curved tree provide the setting. Mountains and grassy stone pillars complete the backdrop.

This is an interpretation for gameplay, not an exact reconstruction of one anime shot. Buildings intentionally use simple forms and restrained detail.

## Files
- Wano_Flower_Capital.blend: final consolidated model, packed textures, cameras and presentation lighting.
- Wano_Flower_Capital_Editable.blend: separate construction components.
- exports/Wano_Flower_Capital_Roblox.fbx: 28 visual meshes, 97,832 triangles; largest mesh 11,970 triangles.
- exports/Wano_Flower_Capital_Collision.fbx: 33 simplified collision meshes.
- textures/: 1024 × 1024 color, normal and roughness maps.
- previews/: hero, street and overhead views.
- Configure_Arena.lua: optional Studio Edit mode helper for selected imported models.
- source/: numbered Blender construction scripts and helpers. Update ROOT paths if moved.

## Combat area
The clear combat region is 64 × 64 Blender units, centred at (0, 0, 0.035), before the red gate. The street is approximately 76 units wide.
Team marker empties are at (0, -22, 0.035) and (0, 22, 0.035). Board corner markers are at (-32, -32, 0.035) and (32, 32, 0.035). These Blender markers are not in the mesh-only FBX.

## Studio setup
Import both FBX files using matching scale and transforms. Keep their relative alignment; do not centre them independently. Scale both together to match your game's units.
Preserve WA_ and COL_ prefixes. Select both imported models and run Configure_Arena.lua in the Studio command bar in Edit mode. It only changes matching parts within the selection.

Visual meshes should be anchored and noncollidable. COL_ proxies should be anchored, invisible and collidable. Collisions cover the main ground and street, simplified house volumes, gate posts, the four trees beside the street, bridge and palace base. Background mountains, roofs, foliage and most distant scenery are decorative; this is not a fully traversable town or rooftop level.

Maps are WA_ColorAtlas.png, WA_NormalAtlas.png and WA_RoughnessAtlas.png. They are embedded in the visual FBX and supplied separately for manual material assignment if required. Blender sky colour and lighting need separate setup in Studio.

## Verification and limits
Both FBX files were re-imported into Blender. The visual mesh and triangle counts, UVs, all three loaded texture maps and collision mesh count passed verification. There are no zero-area visual triangles or raised collision obstacles in the 64 × 64 fighting region.
Studio import, live collision behaviour and device performance have not yet been tested.
The environment includes no characters, crowds, execution scene, animated water, falling-petal animation, AI or match logic.
All geometry and textures were created for this task. The user's six supplied images were the visual references; no external model was downloaded.

Run the numbered scripts in order in a new Blender scene. common.py supplies the shared helpers.
