# Cat in the Hat — Roblox morph assets

Two editable character models for the **Cat in the hat** Roblox horror-game project: an original stylized base and a scarier variant.

## Horror variant

![Horror Cat portrait](horror/CatInTheHat_Horror_Portrait.png)

Sunken eyes, slit pupils, a fixed uneven grin, longer fingers, a slimmer waist, and a forward head tilt.

[Blender project](horror/CatInTheHat_Horror.blend) · [FBX export](horror/CatInTheHat_Horror.fbx) · [GLB export](horror/CatInTheHat_Horror.glb) · [Full-body preview](horror/CatInTheHat_Horror_Studio.png)

## Original base

![Original Cat model](base/CatInTheHat_ThreeQuarter.png)

[Blender project](base/CatInTheHat_Base.blend) · [FBX export](base/CatInTheHat_Base.fbx) · [GLB export](base/CatInTheHat_Base.glb)

## Recolourable parts

Both models keep the hat bands, brim, bow tie pieces, gloves/cuffs, black body, white belly and face, eyes, mouth, and tail as separate meshes. The horror version also has separately editable teeth and eye-shadow pieces.

The materials use solid colours. The normal texture supplies surface detail without baking the character colours into an image.

## Project files

- `base/` — original Blender project, exports, surface texture, previews, colour helper, and validation reports.
- `horror/` — horror Blender project, exports, surface texture, previews, and validation reports.
- `source/` — original Blender generation, refinement, rendering, and export scripts.
- `references/` — the five supplied visual references.
- `archive/Before_Horror.blend` — saved Blender state immediately before making the horror version.
- `FILES.json` — file inventory with sizes and SHA-256 checksums.

The source scripts preserve the original build history and workspace paths. They are not a standalone installer; adjust the paths before rerunning them elsewhere. The Blender projects are the primary editable source assets.

## Status and importing

These are **unrigged visual model bases**. Rigging, skin weights, animations, and the playable morph system remain to be implemented and tested in Roblox Studio.

Keep **Merge Meshes disabled** when importing so each region stays separately recolourable. Check the height is approximately **8 studs including the hat**. See the [base import guide](base/README.md) and [horror notes](horror/README.md).

The original has 62 meshes and 57,162 triangles. The horror variant has 67 meshes and 58,720 triangles. Both passed closed-geometry checks and FBX/GLB re-import checks in Blender, including matching names and export sizes. No Studio playtest has been performed yet.

Avatar proportions reference: [Roblox Cat In the Hat bundle](https://www.roblox.com/bundles/139187072420539/Cat-In-the-Hat).
