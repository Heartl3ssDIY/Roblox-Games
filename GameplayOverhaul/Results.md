# To be rich — gameplay fixes
Date: 16 September 2026

## Warehouse loading and unloading
- Aligned the logical loading bays, receiving bays and staging area to the current warehouse outlines on all eight plots.
- Centred truck rear doors on the dock openings. Parking follows each plot's rotation.
- Added doorway approach points so workers approach the opening before the truck.
- Workers check obstructions and use pathfinding when their direct route is blocked; a failed trip returns parcels to staging.
- Rebuilt invisible dock collision around the openings. Clearance uses the bay outlines, so a missing decorative door frame does not close a route.
- Moved bay signs to their matching bay centres.
- Unloading travels through the receiving doorway. Parcels cannot be claimed while still unloading.
- Expanded the staging grid within its marked area.

## Related gameplay fixes
- Shared carrying joints for workers, players and gifts; carry poses clear after release.
- R6/R15 movement animation continues while carrying. Client animation setup recovers when rigs arrive after initial replication.
- Ordinary parcel pickup validates distance, visibility and ownership; duplicate claims are rejected.
- Dropped stolen parcels return to their original owner's staging area.
- Gift pickup, drop, re-grab and single reward delivery use the updated carry system.
- Chairs and laptops follow the moved desk. Seats face the laptop; tier 3 chair orientation corrected.
- Fixed new-player furniture initialization when a preview laptop already exists.
- Fixed the laptop close button's nested UI path.
- Trophy case and armoury placement use per-plot anchors.
- Guard patrol bounds follow the rotated building. Gun parts preserve their relative positions.
- Guards target thieves carrying their owner's parcels or the player who attacked them.
- Guard/CCTV visibility checks prevent detecting or shooting through solid walls.
- Armoury shots originate at the equipped weapon on the server and reject invalid aim vectors.
- Economy save snapshots are captured before retrying a save; missing plot records are guarded.
- Studio uses temporary in-memory warehouse/economy/session-lock data by default, and skips global leaderboard writes. Live servers retain their normal data stores. The existing UseLiveDataInStudio attribute can opt out.

## Checks completed
- All 48 dock openings across eight plots passed collision-ray clearance checks.
- A live 10-second worker observation recorded 287 moving samples, 92 carrying samples, six additional parcels loaded and zero wall crossings.
- Complete truck loading/departure cycles occurred during Play.
- Ordinary parcel: pickup, duplicate rejection, drop, re-grab and loading passed.
- Actual E-key pickup succeeded in the client.
- Gift: pickup, duplicate rejection, drop, re-grab, one reward, rejection of a second reward, and cleared carry state passed.
- All three chair/laptop tiers passed facing and laptop-height checks; invalid numeric tier rejected.
- New-player seating passed without the test setup: Humanoid was seated in the desk-facing seat.
- Laptop opened and closed through actual button clicks.
- Two R15 guards spawned and patrolled; two cameras spawned in a temporary night fixture.
- Changing R6 hip transforms were observed while workers moved.
- Final normal startup logged no script errors.
- 56 scripts compiled; installed changed server sources matched the saved versions.
- Temporary test code and test attributes removed. Studio returned to Edit.

## Limits
A second human player was not available. End-to-end multiplayer theft, PvP damage, CCTV freezing/repair and simultaneous gift contention still need a two-player session. Guard target and line-of-sight changes were reviewed, but the single-client patrol fixture does not establish all combat outcomes. Furniture facing/height checks do not establish a polished visual fit for every avatar size.

No real Robux purchase was tested. Automatic approval review rejected the proposed StoreService receipt-isolation change because it could affect real purchases; StoreService remains unchanged.

## Files and backup
- After/: revised script copies.
- Before/: original server script snapshots and carrying/client snapshots.
- Studio backup: ServerStorage.GameplayBackup_20260916_053432, including original script sources, client sources, and pre-edit layout markers.
- Earlier model/rebuild roadmap: ../GameRoadmap/To_be_rich_Next_Steps.md.

Changes are in the open Studio place. Publishing was not performed.

