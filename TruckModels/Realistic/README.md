# Realistic delivery trucks

Six rebuilt truck designs in the existing **To_be_rich_Warehouse.blend**, scene **To be rich - Trucks**. Original tier colours retained. The preceding design remains in **To be rich - Trucks - Previous**.

## Changes

- Shaped cab faces, sloping curved windscreens and rounded roof deflectors.
- Wheel openings, tread grooves, eight-hole rims, wheel nuts, hubs and valves.
- Recessed projector lamps, indicators, mirrors, wipers and number plates.
- Seats, dashboard and steering wheel, with a right-hand driving position.
- Chassis rails, axles, suspension, fuel tanks, steps and side guards.
- Separate rear doors with seals, hinges, locking rods, latches and reflective strips.
- Hollow cargo box with a timber floor and internal load rails.

Each export keeps paint, glass, metal, tyres, individual wheels and rear doors separate. Small fittings sharing a material and moving group are combined for import. The source Blender scene retains the individual fittings for editing. The trucks use an original fictional ATLAS badge.

## Import

The new realistic versions have **not yet replaced the working trucks in Studio**. Import one `Realistic_*.fbx` per truck through Studio's 3D Importer, keeping the objects separate and at the existing scale. The `.glb` alternatives preserve metal/roughness material values; actual appearance also depends on Studio lighting and import handling.

After import, the models need their wheel and door groups reconnected to the existing TruckService rig. `realistic_manifest.json` records every exported part, its material, local position, wheel/hinge pivots, cargo bounds and rear marker. Wheel tracks have changed to fit the new cab and wheel arches, so use these new pivots rather than copying the previous wheel pivots unchanged. The exported files contain geometry, not a complete Roblox vehicle script.

The current Studio models and truck script remain available throughout this handoff. No Play session was started for this revision.

## Blender preview

Frame 1: closed doors. Frames 40–70: open doors. Frame 95: closed again. Frame 160: moved forward with wheel rotation. The source remains in the same warehouse Blender file.

`Basic_Detail.png` and `Rear_Detail.png` show the new front and cargo bay. `Lineup0001.png` shows all six tiers.

These detailed versions have approximately 72,000–93,000 triangles each, split into 59–73 mesh pieces. Every exported mesh is below 8,000 triangles. Geometry, dimensions, names, UVs and materials were checked by importing the FBXs back into Blender. This is higher-detail artwork; performance in a populated Roblox server still needs checking after installation.

Reference proportions were informed by [Isuzu delivery trucks](https://www.isuzu.co.za/complete-care/isuzu-insight) and [Mercedes-Benz Atego box trucks](https://acr-juretzki.de/de/849-1/mercedes-benz-atego-816.html). The models are original designs, not exact replicas.
