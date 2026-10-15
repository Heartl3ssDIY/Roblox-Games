# Hyperbolic Time Chamber — Dragon Ball Z

A stylized arena based on the user's six supplied reference images: a gold-domed central pavilion with a clock, four turned white columns, pink barrel roofs, blue tiled curved steps, two green hourglasses and orb lamps. The large white field in front is left empty for combat.

## Included files
- Hyperbolic_Time_Chamber.blend: final consolidated scene with packed textures, lighting and four cameras.
- Hyperbolic_Time_Chamber_Editable.blend: separate construction components.
- exports/Hyperbolic_Time_Chamber_Roblox.fbx: 17 visual meshes and 50,429 triangles; largest mesh 10,704 triangles.
- exports/Hyperbolic_Time_Chamber_Collision.fbx: 19 simplified collision meshes.
- textures/: shared 1024 × 1024 color, normal and roughness maps.
- previews/: hero, front, gameplay layout and overhead views.
- Configure_Arena.lua: optional Studio Edit mode helper for selected imported models.
- source/: numbered construction scripts and shared helpers; update local ROOT paths if moving the package.

## Combat layout
The clear combat region is 64 × 64 Blender units, centred at (0, 0, 0). Team markers are at (0, -22, 0) and (0, 22, 0). Board corners are (-32, -32, 0) and (32, 32, 0). These editable Blender empties are not in the mesh-only FBX.
The hall sits behind the fighting region, centred around Y = 82. The first curved step begins at Y = 37. The white floor is a finite 2000 × 2000-unit surface, giving a visually open environment; it is not mathematically infinite.

## Studio setup
Import the visual and collision FBX files using the same scale and transforms. Preserve their relative alignment and scale both together for your game's units. The white floor is intentionally large; it can be replaced by an ordinary white anchored Part of the desired size if that better suits your import settings.

Preserve TC_ and COL_ name prefixes. Select both imported models and run Configure_Arena.lua from the Studio command bar in Edit mode. It only changes matching parts in the selection.
Visual parts become anchored and noncollidable. Collision parts become anchored, invisible and collidable. Glass shells remain separate and receive 0.75 transparency. Their names begin TC_22_Glass.
Glass appearance varies by renderer. The green sand and highlight geometry are modeled separately, so the hourglass remains recognizable when transparency is adjusted.

The shared maps are TC_ColorAtlas.png, TC_NormalAtlas.png and TC_RoughnessAtlas.png. They are embedded in the visual FBX and supplied as separate files for manual material assignment if needed. Blender lighting, gold response and the softly bright white floor need corresponding visual tuning in Studio.

## Checks and scope
Both FBX files were re-imported into Blender. Visual mesh count, triangle count, UVs, all three loaded texture maps and collision mesh count passed verification. No zero-area visual triangles or raised collision obstacles were found in the 64 × 64 combat area.
Collision includes the white floor, terrace, curved steps and simplified hall and landmark obstacles. The scenery is not a fully navigable interior or rooftop level.
Studio import, gameplay behaviour and device performance have not yet been tested.
The clock, hourglass sand and interior furnishings are static. No characters, animated sand, match logic or AI are included.
All geometry and textures were created for this task from the supplied visual references.

Run numbered source scripts in order in a fresh Blender scene; common.py supplies helpers.
