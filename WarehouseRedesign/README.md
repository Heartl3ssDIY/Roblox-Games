# To be rich — simplified warehouse

The existing To_be_rich_Warehouse.blend has been updated in place. The original default Scene is still present; the active asset scene is To be rich - Warehouse.

## This revision

- 159 independently recolourable meshes, reduced from 1,118.
- 6,356 triangles; the largest individual mesh has 516 triangles.
- One mesh per main wall side, with openings built into the wall geometry.
- Original 110 × 90 stud hall layout and flat 112 × 92 × 0.6 roof at Roblox Y = 15.3.
- No bevel modifiers, decorative wall ribs, pitched roof, vents or skylights.
- Matte colours, plain block shapes and simplified fittings.
- Redesigned desk with separate top, supports, drawers and handles; matching storage cabinet and bookcase.
- Chairs, laptop, plants and parcels are excluded. These will be separate models. Original placement guides remain available.

## Files

- To_be_rich_Warehouse.blend: editable source. Blender opens on the exterior view with both roofs visible.
- To_be_rich_Warehouse.fbx: complete warehouse asset.
- FBX_Parts: twelve collection exports. Cargo contains only empty pallets.
- ApplyColours.luau: sets colours, Roblox materials, collision flags and the six existing CustomGroup attributes on a selected imported model.
- parts_manifest.json: exact part names, dimensions and colour groups.
- warehouse_office.png, warehouse_interior.png, warehouse_cutaway.png, warehouse_exterior.png and warehouse_receiving.png: updated previews.
- geometry_checks.json and validation.json: geometry and FBX verification results.

Hide the Roof collection to inspect the interior. Each exported part has its own single material. Edit that material's Base Color to recolour it independently. GameplayGuides contains hidden reference markers and is excluded from exports. Presentation contains cameras, render lights and sample sign text, also excluded from exports.

## Studio import

Import the complete FBX or the separate collection files. Keep Merge Meshes off; enable Anchored, Insert Using Scene Position and Set Pivot to Scene Origin. Use Studs as the scale unit. Verify the main hall dimensions before installation. Select the imported model and run ApplyColours.luau in the Command Bar to restore the intended colours and CustomGroup attributes.

The six groups remain Wall, Roof, OfficeWall, Pillar, Trim and Neon. The general body, roof and furniture use SmoothPlastic in the colour helper to preserve the simpler Roblox look. Glass and neon are assigned only to their corresponding parts.

Import settings: https://create.roblox.com/docs/studio/importer

## Gameplay bindings

This is a visual asset; the live Studio game has not been changed. Preserve Workspace.Warehouse and its LoadBays, OffloadBays, Staging, spawn objects, BaySigns, NameSign, CameraSlots, furniture anchors and teleporter interaction components. Truck code expects native Part bay pads, not replacement MeshParts. Preserve the live SurfaceGuis for company and warehouse names.

PlotService derives its origin from part centres when no root Floor exists. The inspected original reference is (20.5, 8.375, 0). Preserve this reference explicitly when swapping visuals so plot-relative systems do not shift. Main dimensions and gameplay guide positions are retained, but mesh consolidation can still change the calculated origin. No game code has been modified.

## Checks

All 159 meshes were imported into a fresh Blender process with matching names, positions, sizes and single-material assignments. Geometry checks found no part intersections at the checked tolerance, no non-manifold mesh edges and no modifiers. The check uses solid component boxes for compound meshes and conservative bounds for simple meshes. Rendered exterior, interior and office views were inspected. Roblox import and gameplay remain untested; no play session was started or stopped.

