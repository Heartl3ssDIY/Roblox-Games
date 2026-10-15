# Modern town centre and gift truck

## Included models

- **TownCentre_Normal** — modern civic building with a walk-in entrance, ramp, complete roof, raised daylight box, basic reception desk, seating and two marked travel spaces.
- **TownCentre_Crashed** — the same building, floor and interior, with a small damaged brick section beside the entrance, a bent window rail and a few loose bricks. The doorway stays clear.
- **GiftTruck_Crashed** — teal and purple gift-delivery truck with gold livery, a dented front, bent bumper, turned front wheels and open rear doors. The cargo bay is hollow.

The gift parcels and collection system are intentionally left for the later parcel project. The travel pads are visual placeholders with named markers; they do not teleport players yet.

## Blender file

Everything is saved in the existing **WarehouseRedesign/To_be_rich_Warehouse.blend**, in the scene **To be rich - Town Centre**. The warehouse, laptops, parcels and regular truck scenes remain available.

The two buildings are displayed side by side in Blender. Both exports have the same ground-centred origin, so either building can occupy exactly the same location. The crashed truck is a separate asset, displayed in its intended position beside the damaged building. The roof is included in both exports and remains a separate set of parts; only the interior preview hides it.

## Import

Import each FBX separately, retaining all mesh objects and the original scale. GLB alternatives are also included. The building footprint is 38 × 26 studs, with roof overhang and an entrance ramp beyond that footprint. The internal floor is 0.8 studs above the shared model origin.

These assets are not installed in Studio yet. `ApplyTownColours.luau` is an optional post-import colour/collision helper for selected imported models. It matches exact exported part names. `town_manifest.json` records part names, colours, collision flags, markers and placement information for the later installation.

The gift truck is exported already damaged, with its doors open. Do not apply another 110-degree opening rotation on top of the exported pose. Its local front points along -Z; the town building's entrance faces +Z. Place the truck relative to the town-centre pivot at **(10.8, 0, 21.65)**, yaw **-6 degrees**. Check Studio's imported forward axis before applying the final placement.

## Existing event logic checked

The current SpecialTruckService creates a `SpecialGifts` folder, scatters 5–25 collectible gifts and clones `ServerStorage.EventTruck`. Its dressing currently uses a fixed plaza position and a different angle; it does not swap the town hall model. Installing this new scene will therefore need a model swap at event start/end and marker-based truck/spill placement. This modelling pass did not alter reward odds, collection behaviour, event timing or game scripts.

The existing `Workspace.TownCentre.MonumentBase` occupies the middle of the old hall location. During installation it must be removed or repositioned so it does not block the new walk-in interior. Keep the plaza and leaderboard as separate map objects.

Markers are included in the manifest for player arrival, the entrance, warehouse/dealership travel, the truck root, impact and the future gift spill. Blender empties serve as guides; they are not collectible objects or active Roblox teleporters.

## Checks

FBX files were reimported to check mesh names, geometry, dimensions and materials. GLB files were checked for unwanted objects. Matching building pieces were compared, and the entrance-to-travel-pad routes were checked for clearance. No Studio Play session was started. Final gameplay and event integration checks remain for installation.
