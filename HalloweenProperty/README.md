# Halloween property

An original Blender exterior model based on the pale house and landscaped lot visible around **3:35–3:45** in [the supplied gameplay video](https://www.youtube.com/watch?v=Bc1hwOcs0JU&t=215s).

Open **Halloween_Property.blend** in Blender. All three texture maps are packed into the file. The house, fence, trees, shrubs, groundcover and pathways are organized into separate collections. Camera and lighting objects live in their own preview collection.

Included: clapboard house exterior, shuttered windows, front door, porch and steps, shingle roof, chimney, gutters, pale picket fencing, four branching trees, bushes, flowering plants, grass tufts, fallen leaves, pumpkins, garden path and pavement.

This is a reconstruction from dark, partly obscured frames. Dimensions, hidden sides and some details are inferred. It is an exterior shell with a closed front door; no furnished or playable interior is included.

## Files

- `Halloween_Property.blend` — editable source with packed textures and preview lighting.
- `Halloween_Property.fbx` — complete property for Roblox's 3D Importer, with embedded textures.
- `Halloween_Property.glb` — portable version with embedded geometry and textures.
- `Property_Albedo.png`, `Property_Roughness.png`, `Property_Normal.png` — shared 2048 × 2048 texture maps.
- `Property_Daylight.png`, `Property_Front.png`, `Property_Night.png` — rendered previews.
- `Model_Report.json` and `Export_Check.json` — geometry counts and export checks.

## Roblox import

Use Studio's 3D Importer to open `Halloween_Property.fbx`. The source is modeled in **metres**: the house is 14 m wide and the complete property is approximately 25 × 29.8 m. Check the source scale in the importer and enable Anchored for a static property. Lighting is included in the Blender scene only; set your game's lighting separately.

The model is divided into meshes below Roblox's 20,000-triangle limit. Foliage is closed geometry and does not require transparent leaf images. Groundcover and tree leaves should have collisions disabled after import; use simple collision shapes around the house, ground and tree trunks as needed. The model contains no gameplay scripts.

The FBX has been imported back into Blender to check dimensions, triangle counts and texture loading. Direct import into Roblox Studio has not been tested because Studio was not connected during creation.

Roblox references: [3D mesh specifications](https://create.roblox.com/docs/art/modeling/specifications), [texture assignment](https://create.roblox.com/docs/art/modeling/assign-textures), [importer workflow](https://create.roblox.com/docs/art/accessories/creating-rigid/importing).
