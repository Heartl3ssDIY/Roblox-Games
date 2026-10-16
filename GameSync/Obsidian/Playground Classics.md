---
updated: 2026-10-16
tags:
  - roblox
  - game-work
---

# Playground Classics

[[Roblox Games]] · [[Shared assets]] · [[Sync status]]

[Source chat: Playground Classics](codex://threads/01a0ff07-1491-7a90-8129-097a94add2e6)

Status below is based on the latest relevant chat records reviewed on 16 October 2026. Past checks are reported evidence; they are not a new playtest or confirmation that the experience was published.

## Completed work recorded in chat

- Stuck in the Mud converted to Laser Tag: balanced red/blue teams, three overhead hearts, third enemy hit eliminates, rectangular lasers, recoloured existing guns, darkened arena, spectating, updated voting/admin/HUD.
- Latest mobile changes lock crosshair to camera aim and add right-side Shoot button with Sprint below, avoiding Jump; editable StarterGui/MudHUD.
- Gun readiness retry/error reporting and Lazer Tag arena-name/admin initialization fix passed Studio practice tests.
- Skipping Rope: three ropes/eight players each, six turners, first hit halves health/second eliminates, two minutes, +5% speed every ten seconds; Solo Practice awards no coins/XP/wins.
- Hide and Seek: 32 classrooms; 30 seconds hide/5 minutes seek; 25-second sprint; partial recharge sprint in all games; E disguise change or seeker scan (10 seconds/60-second cooldown); Q decoys (max 3, 10-second interval, 5-second owner reveal when hit); F furniture hiding; props and rotations corrected.
- Duck Duck Goose snap-backs removed; clockwise arrows, briefing/rules button, lap-to-chair, moving chasers and OUT exclusion.
- Wrong cave tiles disappear immediately, reset after 3.5 seconds; equipment cleanup limited to toy Tools.

## Open work and verification gaps

- [ ] Recent Studio changes explicitly unpublished.
- [ ] Full multiplayer tests for Laser Tag, Skipping Rope, Hide and Seek and Duck Duck Goose remain needed.
- [ ] Published-only gun access cause not confirmed; fresh-server test after publishing needed.
- [ ] Tutorial was deferred.

A fresh read-only snapshot of the connected Edit data model is stored under `GameSync/StudioSnapshots/Playground Classics`. It captures current authored script sources and selected world settings, not a complete `.rbxl` place or all models and UI properties. Historical ServerStorage backup scripts are inventoried separately. Read its metadata for the exact capture time and coverage.

The fresh Studio read captured 81 current scripts and verified them against a second read. The current round-camera script allows 0.5–25 studs; StarterPlayer defaults are 0.5–128. The legacy folder still has CameraZoomDistance=30. These supersede the older chat summaries of 30 and five studs. The selected world-state snapshot confirms the 288-stud crossing. This was a read-only capture, not a gameplay test.

Supporting work: [[School assets]] and [[Shared assets]].

## Files

- [GameSync/StudioSnapshots/Playground Classics](https://github.com/Heartl3ssDIY/Roblox-Games/tree/main/GameSync/StudioSnapshots/Playground%20Classics) · [local files](file:///C:/Users/sandt/Documents/Local%20Projects/Roblox%20UI%20Assets/Btns/GameSync/StudioSnapshots/Playground%20Classics)
- [GameSync/Assets/PlayGround Classics](https://github.com/Heartl3ssDIY/Roblox-Games/tree/main/GameSync/Assets/PlayGround%20Classics) · [local files](file:///C:/Users/sandt/Documents/Local%20Projects/Roblox%20UI%20Assets/Btns/GameSync/Assets/PlayGround%20Classics)
- [LaserTagMobile20261014](https://github.com/Heartl3ssDIY/Roblox-Games/tree/main/LaserTagMobile20261014) · [local files](file:///C:/Users/sandt/Documents/Local%20Projects/Roblox%20UI%20Assets/Btns/LaserTagMobile20261014)
- [LaserTagAccess20261014](https://github.com/Heartl3ssDIY/Roblox-Games/tree/main/LaserTagAccess20261014) · [local files](file:///C:/Users/sandt/Documents/Local%20Projects/Roblox%20UI%20Assets/Btns/LaserTagAccess20261014)
- [DuckDuckGooseRepair20261012](https://github.com/Heartl3ssDIY/Roblox-Games/tree/main/DuckDuckGooseRepair20261012) · [local files](file:///C:/Users/sandt/Documents/Local%20Projects/Roblox%20UI%20Assets/Btns/DuckDuckGooseRepair20261012)
- [HideSeekAbilities20261012](https://github.com/Heartl3ssDIY/Roblox-Games/tree/main/HideSeekAbilities20261012) · [local files](file:///C:/Users/sandt/Documents/Local%20Projects/Roblox%20UI%20Assets/Btns/HideSeekAbilities20261012)
- [SkippingRope20261012](https://github.com/Heartl3ssDIY/Roblox-Games/tree/main/SkippingRope20261012) · [local files](file:///C:/Users/sandt/Documents/Local%20Projects/Roblox%20UI%20Assets/Btns/SkippingRope20261012)
- [SchoolAssetLibrary](https://github.com/Heartl3ssDIY/Roblox-Games/tree/main/SchoolAssetLibrary) · [local files](file:///C:/Users/sandt/Documents/Local%20Projects/Roblox%20UI%20Assets/Btns/SchoolAssetLibrary)

## Chat evidence

Reviewed turn IDs: `01a13873-680e-7bd0-9fbd-cc32e9a143ae`, `01a13855-7baa-7760-96f8-71a73299a766`, `01a1365e-dca2-7910-a85b-b05bdda8b99b`, `01a12d7a-fb3c-7a52-a2c5-f7d3cf26f460`, `01a12d5b-a27f-79c0-8399-75e3806fd42c`.
