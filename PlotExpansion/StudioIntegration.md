# Visible warehouse plots

Applied to To be rich in Studio Edit mode on 16 September 2026.

- Plot 1 remains Workspace.Warehouse. Plots 2–8 are copies in Workspace.Plots, arranged around the town centre with the front name signs facing it.
- All eight remain visible and editable when unclaimed. Signs read UNCLAIMED WAREHOUSE.
- Players automatically receive an available plot on joining. Unclaimed plots do not run worker or truck production.
- On leaving, save the owner first, then restore that plot's unclaimed snapshot. Capture a separate snapshot for each plot when the server starts so edits to different plots are retained.
- Worker homes, pickup approaches, load-bay approaches and access boundaries follow each plot's rotation. Staging and truck routes already use local transforms.
- Extended Baseplate Z size from 2048 to 2560 to support the rear plots and truck departure paths; ground height remains unchanged.

Updated scripts: PlotService, WorkerService, TruckService and AccessBarriers. Copies are in this folder.

Backup in Studio: ServerStorage.PlotLayoutBackup_20260916_044447. Contains original warehouse, original script sources and original baseplate size.

Edit-only checks passed:

- Eight distinct automatic assignments; ninth assignment cannot take an occupied slot.
- Released slots 1 and 2 stay visible, reset unclaimed, and can be reassigned. Save runs before clearing the owner.
- All eight structural checks and name-sign facing checks passed.
- 56 worker positions are inside their floors.
- 768 staging positions match the rotated source warehouse.
- All 48 load/offload routes match the rotated source and remain within the baseplate. Maximum position error was below 0.00007 studs.
- Modified sources compile. No Play session was started; live multiplayer behaviour has not been play-tested.
