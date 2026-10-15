# Lobby travel server update

Prepared file: scripts/ArenaTravelService.luau.
Existing remote reused: ReplicatedStorage.ArenaEvents.TravelRequest.
No new remotes, persistence, purchase logic or arena gameplay was added.

LobbyConfig contract:
- RootName identifies the live lobby model.
- Destinations is the whitelist: name -> { marker = "exact marker name", label = "...", lookAt = "optional marker" }.
- Legacy LobbyPortal resolves MainMode; PackPortal resolves Packs.
- Marker parts are direct children of the lobby's Markers folder. Their live Position.Y is the floor surface.
- RequestCooldown defaults to 0.4, RootClearance fallback to 3.5, SafeLandingOffset to 0.12.
- Clearance normally comes from Humanoid.HipHeight + half the HumanoidRootPart height. R6 with zero HipHeight adds its leg height.
- lookAt controls horizontal facing. Without it, the marker's current horizontal forward direction is used.
- Moving or scaling the lobby moves the markers; the service reads current coordinates on every request.

Arena compatibility:
- Enter/Visit retain the existing catalog, TeleportReady/MatchReady restrictions, anchored arena pose and exact return pose.
- Nil Enter/Visit destination is still the legitimate default arena; malformed values and unknown arena names never silently select Tenkaichi.
- Active visits block travel and arena switching. Repeating the same action for the same arena is idempotent.
- Leave remains immediate, restores original anchoring and clears existing ActiveArena/ArenaVisitOnly attributes.
- Character removal releases the old root's anchor and visit state without moving the replacement character.
- Invalid or unavailable destinations fail before changing the avatar or visit state.

Validation:
- ArenaTravelService.luau and tests/ArenaTravelRegression.luau compile with local Luau 0.740 (exit 0).
- The isolated native regression harness is prepared but has not been run by this agent. It creates unparented fixture instances and mocks the services; it does not touch the live Workspace.
- To run in an authorized Edit harness: local verify = assert(loadstring(harnessSource))(); local result = verify(serviceSource).
- Tests cover invalid inputs, missing markers/lookAt, R6/R15 clearance, cooldown, velocity clearing, relocated/scaled lobby markers, legacy requests, arena restrictions, visit locks, idempotency, exact return pose, original anchor restoration, character removal and dead-character handling.

