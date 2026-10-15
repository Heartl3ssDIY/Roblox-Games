# G-Blox — Gravity Hall

An original enclosed lobby shell, built in a separate Blender scene. Your current Roblox lobby was only measured, not edited. The original Blender default scene is preserved in the project.

## Deliverables

- `G-Blox_Gravity_Hall.blend`: editable scene with named collections, bevel modifiers, materials, lights and four cameras. Roof and every wall are present and enabled.
- `G-Blox_Gravity_Hall.fbx`: separate named mesh objects for Roblox import; no Blender cameras or lights, no unrelated default cube.
- `01_Gravity_Hall_Interior.png`: interior overview with the closed roof.
- `02_Entrance_View.png`: centered statue and gallery view.
- `03_Practice_Obby.png`: side practice circuit.
- `04_Layout_Cutaway.png`: planning view; roof and near walls hidden for this image only.

## Dimensions and layout

Measured original floor: 144.17134 × 100.06603 studs.
New floor: **288.34268 × 200.13206 studs** — exactly twice both horizontal dimensions, four times the area.
Floor thickness: 3 studs. Interior roof height: 62 studs.
Blender coordinates: X width, Y depth, Z height; one design unit represents one stud. Origin is at the floor's center/top surface.

The rear gallery is 18 studs above the floor. Twin staircases have 1.125-stud rises and 2.4-stud treads. The optional eight-platform practice circuit has a continuous floor beneath it and no scripted hazards. It is architectural geometry, not a configured gameplay system, and needs an avatar playtest after import.

Existing shops, eggs, gift box, leaderboards, treadmills, teleport pads and gameplay objects were deliberately not recreated. Broad side bays and the central approach are left empty for your objects.

## Roblox handoff

Import the FBX as a new, separate model; do not replace the old lobby until you are happy with placement. Keep individual meshes separate. Check the main floor dimensions against 288.34268 × 200.13206 studs and correct any importer unit conversion by uniformly scaling the whole model.

Anchor the imported geometry. Enable collisions on the main floor, shell, stairs, gallery and obby landing surfaces. Decorative floor inlays, lettering, light strips and small decorations should not obstruct players. Use simple collision shapes on rectangular walking surfaces and test stairs/rails with a normal avatar.

Blender illumination does not become Roblox lighting through this FBX. Recreate lights at the ceiling strip fixtures and make `EMIT_` pieces Neon as desired. Material colors are supplied, but the Roblox lighting look still needs tuning in Studio. This delivery is not uploaded, published or installed into the live experience.

Hide the `03 Roof - hide for placement` collection temporarily in Blender when arranging objects, then show it again. The obby, statue, gallery and decorations are separate collections so you can move or remove them independently.

## Checks

506 scene objects including lights/cameras; approximately 119,280 evaluated triangles including bevels and lettering. The saved scene has a complete roof. All four preview images were rendered from the model. Live multiplayer performance, Roblox collision behavior and final import scale still require Studio testing.

The included build/export scripts reproduce this deliverable. Running the build script again adds another scene; do not run it merely to open the lobby.
