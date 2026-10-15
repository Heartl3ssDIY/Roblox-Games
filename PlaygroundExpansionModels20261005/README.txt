Playground Classics — expansion models

Open Blender/Playground-Classics-Expansion-Library.blend to browse the complete collection.
For detailed editing, open a model from Blender/<category>/Blend. These individual files
include named mesh parts, editable bevel modifiers, materials, attachment markers and a
packed original reference in the hidden Reference collection. They are not flattened
copies of the FBX export.

Categories: Bats (B16–B25), Miscellaneous (M16–M25), Pets (P21–P35).
Each category has Blend, FBX, Textures, Previews and Metadata folders.
Review contains side-by-side reference/render contact sheets.

Pets have named pose bones and a JollyIdle bounce on frames 1–25 at 24 fps. Frame 1 is
the rest pose. Select the armature and enter Pose Mode to adjust the animation. Source
mesh parts have rigid bone weights so eyes, beaks and ornaments keep their toy shapes.
The FBX files contain skinned export meshes and the idle animation.

Bats are authored around their grip origin with GripAttachment markers. Other items
provide named markers appropriate to their form. One authored unit represents one
intended Roblox stud; confirm importer scale in Studio before replacing existing tools.

For Roblox, import the matching FBX. A packed palette texture is embedded in the FBX
and also supplied separately in Textures. Export meshes are split where necessary to
keep each mesh within the validated triangle budget. The hidden RobloxExport collection
in each Blend file is a prepared, triangulated snapshot; edit the named source objects
instead. Regenerate the export after source edits, or manually prepare a new export.

Source/build_pack.py builds a named ID or category with Blender in background mode.
Source/build_library.py assembles the master library after individual sources exist.
Source/validate_exports.py checks editable files and imports each FBX back into Blender
to verify geometry, UV/materials, scale, and pet rigging. Validation JSON files record
the results. Render previews are from Blender, not Roblox play tests.

Navy seam geometry is included. For a consistent outer silhouette in Roblox use the
game's outline treatment (for example an occluded Highlight with transparent fill).
Use simple collision proxies; these visual meshes are not gameplay collision shapes.
No new item abilities, prices, unlocks or Studio imports are supplied by this model pack.
The reference brief describes intended uses; those can be connected to gameplay later.

All deliverables are stored locally under the Btns project folder. No OneDrive output
paths are used. Original reference images remain untouched.
