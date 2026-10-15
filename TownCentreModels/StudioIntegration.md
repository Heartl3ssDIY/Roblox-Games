# Studio integration

Installed in To be rich on 2026-09-16.

- Workspace.TownCentre.CivicBuilding is the active building.
- ServerStorage.TownCentreModels holds Normal and Crashed templates.
- ServerStorage.EventTruck holds the recoloured crashed gift truck, with doors already open.
- SpecialTruckService swaps the building and positions the truck using its markers. It restores the normal building when the event clears.
- Existing event chances, schedule, package counts, rewards, carrying and delivery logic are retained. Gift placement uses the actual plaza height and avoids benches and other solid event objects.
- Separate recolourable parts remain; installed part names are under 50 characters. SourceMeshName attributes preserve the export mapping, including names truncated by the importer.
- Backups: ServerStorage.TownEventBackup_20260916_042644.

Edit-mode checks passed: five event cases, 95 gift positions, repeated-spawn guard, scheduled start/end, forced-event expiry, and 87 walking-clearance samples per building. No Play session was started. The preview was cleared and the normal building restored.

Travel pads remain markers for future teleport integration.
