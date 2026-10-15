# To be rich — trucks

Six truck designs: Starter, Basic, Power, Super, Premium and Mythic.

## Already installed in Studio

The matching editable Roblox part models are in ReplicatedStorage.TruckModels. There is no need to import the FBX files to use this update. TruckTemplate uses Basic for incoming deliveries.

TruckService now opens the two rear doors, shows stacked cargo, closes the doors before departure, rotates the wheels with distance travelled, and drives trucks straight beyond the road before fading them out. Incoming trucks reverse into their receiving bay. Capacities, upgrade prices, parcel values and Mythic's 5× multiplier are preserved.

Cargo uses a maximum of 60 visible parcels per truck to represent its fill level. Every parcel still counts toward capacity and payment, including trucks holding more than 60. The new parcel imports are not yet connected to PackageService; the current game parcel visuals are used until that is done.

Truck movement is scripted and anchored, not player-driven vehicle physics. Parts remain separate and recolourable, with grouped wheels and rear doors.

## Warehouse and ground

The floor foundation now extends down to the baseplate without changing the warehouse floor's top height. Dispatch and receiving roads have a short slope to the baseplate at their far ends. Decorative road markings no longer collide.

Leave the baseplate in place. Transparency controls visibility only; CanCollide controls physical collision. The ramps and floor foundation fix the height transitions without removing the ground under the rest of the map.

## Blender

The existing WarehouseRedesign/To_be_rich_Warehouse.blend contains the new “To be rich - Trucks” scene. Other scenes are retained. Frame 1: doors closed. Frames 40–70: doors open. Frame 95: closed. Frame 160: driven forward, with wheels rotated. This Blender timeline is a preview; Studio uses TruckService animation.

The six FBXs are optional geometry exports, around 1,900–2,500 triangles each. They contain separate named mesh parts and materials. They do not install the Studio scripts or door/wheel grouping automatically. The manifest records the local Roblox part transforms, cargo bounds and hinge/wheel pivots. Export orientation matches the earlier laptop and parcel exports.

## Checks and backup

All checks were performed in Edit mode, without starting Play. Checks covered Luau compilation, all six door/wheel rigs, cargo fit and clearing, road/wheel clearance, ramp surface heights, capacity limits, saved cargo restoration, payout values and duplicate-departure prevention. FBX exports were reimported to check part names, dimensions and materials. A live multiplayer playtest remains to be done.

Original Studio content is backed up under ServerStorage.TruckUpgradeBackup_20260916_023656, including the prior TruckModels, warehouse and TruckService source. This update has not been published.
