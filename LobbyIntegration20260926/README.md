# Festival Citadel lobby setup

Installed in Anime Combat Units, place 111313211501470, on September 26, 2026.

The active lobby is Workspace.Lobby_MainModeZone. Its 42 imported batches are organized into 17 districts. The installation was verified at scale 1, approximately 632 studs across. The live model has since been scaled to 1.5; recheck position-sensitive patches if it is scaled again. Move or scale the whole model so its scenery, collision and markers stay aligned.

The old lobby is archived at ServerStorage.BeforeLobbyIntegration_20260926_174357.Lobby_MainModeZone. Source backups are in that folder's Scripts child and in this folder's before directory.

## Connected features

- One lobby spawn.
- Play and Packs buttons connected to the new story gate and summon hall.
- Fourteen fast-travel destinations with an editable StarterGui.LobbyTravelGui menu.
- Nine arena gates in the catalog order, with Jujutsu High at number 4.
- Existing shop, units, mastery, daily-win rewards and story-guide interactions.
- Each free-play gate requires that same arena's 100-point story completion. Completion stays unlocked after losses. Free play uses walking controls and the normal camera; story combat keeps its existing controls.
- Ranked, PvP, clans, leaderboards and character displays remain reserved locations. Matchmaking and rank rewards were not implemented.
- Tournament of Power remains outside the nine-arena catalog.

## Collision and textures

The 4,728 decorative meshes are anchored and non-colliding. There are 1,599 hidden solid proxies: 798 imported meshes plus 801 native parts covering missing surfaces, structures and all 84 waterfall steps.

ReplicatedStorage.LobbyCollision and ServerScriptService.LobbyCollisionService apply these roles at startup. RepairCollision.luau is the reusable command-bar version.

Four missing ACU logo materials now reference the supplied original logo, asset 109321621439717. Other texture assignments and existing authored UI layouts were preserved.

## Progression limitation

PlayerData currently holds progress in client memory for the running session. Gate labels, panels and normal client travel calls check completion. Unlocks do not persist across rejoins and the server has no authoritative completion records. The raw Visit remote remains a prototype route; these are not exploit-resistant server locks. No remote accepting client claims of completion was added.

## Verification

All 11 scripts and the installer compile. Thirty-eight isolated native Studio travel checks and ten isolated progression checks passed. All 14 lobby destinations and all nine arena arrivals have ground. The lobby arrivals have no detected overlap with native structural colliders. All 84 added waterfall stair treads passed collision checks. The lobby and travel menu were visually inspected in Studio.

A full player walkthrough is still needed, particularly irregular architecture and bridge approaches. The installed road-junction cleanup has not yet been verified in a live Play session.

Save the place in Studio before the walkthrough. The game was not published.

## Editable locations

- Visuals: district artwork.
- Collision: original proxies and supplemental native parts.
- Markers: travel, interaction, NPC and future-system positions.
- ReplicatedStorage.LobbyConfig: destination mapping and menu order.
- StarterGui.LobbyTravelGui: travel menu layout and Permanent Marker typography.

InstallLobby.luau is the guarded installation record. Do not rerun it on an already integrated lobby.

## Road-junction cleanup

The road cleanup is installed in Studio Edit on the 1.5-scale lobby. RoadJunctionCleanup.luau backed up five targeted collision parts in ServerStorage.BeforeRoadJunction_20260926, joined the main route and arrival boulevard collision surfaces at z = -165, and marked the decorative foundation and two indigo border strips with LobbyNoCollision = true so startup collision setup leaves them non-colliding. Set MODE to rollback in the same script to restore those five collision parts.

Six imported visual rail chunks are backed up in ServerStorage.BeforeRoadVisualJoin_20260926, and 20 native rail segments were added at the road junction. The collision script does not roll back those separate visual rail changes. The pavement meshes remain imported. A live Play test of the installed cleanup is pending.

## Button repair

Play, Packs and PvP previously appeared unresponsive because ReplicatedStorage.ArenaEvents.TravelRequest was missing. ArenaTravelClient waited for that RemoteFunction before the client scripts could bind their buttons. TravelRequest has been restored in Studio Edit, and ArenaTravelService now recreates it if absent. The original server script is backed up at ServerStorage.BeforeButtonRepair_20260926; the compiled replacement is scripts/ArenaTravelService_ButtonRepair.luau.

LobbyClient, PackShopClient and LobbyMenuClient now show on-screen travel feedback when a destination fails. After successful PvP travel, the player is told that PvP modes are still being configured. Their original scripts are also backed up at ServerStorage.BeforeButtonRepair_20260926. Compiled local copies are scripts/LobbyClient_ButtonRepair.luau, scripts/PackShopClient_ButtonRepair.luau and scripts/LobbyMenuClient_ButtonRepair.luau.

The authored HUD hitboxes were separated: PacksBtn moved 60 px left, PvPBtn moved 60 px right, and PlayBtn stayed in place. At the current editor viewport, their horizontal bounds are 222–522, 533–833 and 848–1148 px respectively, with no overlap. Original button clones are at ServerStorage.BeforeButtonRepair_20260926.ButtonLayout.

A live Play check of these buttons and their feedback is pending a confirmed place save.
