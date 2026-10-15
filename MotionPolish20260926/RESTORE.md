# Restore notes — motion polish

Target: Anime Combat Units, place 111313211501470.

**No whole-place save or publish has been confirmed.** These files preserve the changed scripts and their previous sources; they do not contain a complete Roblox place or all of its assets.

## Verified local files

Each of these six filenames exists in both `scripts/` (polished version) and `before/` (pre-polish source):

- AttackAnimator.luau
- CombatController.luau
- PackReveal.luau
- UnitPreviewAnimator.luau
- UnitsUI.luau
- UnitViewport.luau

Also present:

- `PolishPackRevealGui.luau` — idempotent property patch for the existing StarterGui.PackRevealGui.
- `backups/UnitPreviewAnimator.before.luau` — duplicate original animator backup, equivalent to the copy in `before/` after line-ending/trailing-whitespace normalization.
- `tests/CombatRegression.luau`
- `tests/CombatRegressionResults.json`
- `tests/FinalInstallVerification.json`

No original PackRevealGui instance export, .rbxl, or .rbxlx is included in this folder. The GUI patch is **not** a reverse patch or a replacement GUI builder.

## Studio backup

Final read-only verification confirmed `ServerStorage.BeforeMotionPolish20260926` is still present in the same Studio session. The earlier installation placed copies of the six original modules and the original PackRevealGui there. This remains an in-memory backup; its survival after a future restart depends on saving/recovery.

Do not confuse it with `ServerStorage.BeforePackOpeningV2_20260926`, which belongs to the earlier pack-opening redesign.

## Safe rollback

1. Let Studio respond, confirm the target place, leave Play mode, and save the current place as a separate backup before changing it.
2. For each of the six existing `ReplicatedStorage` ModuleScripts, restore its Source from the corresponding `before/` file. Keep the existing instances, names, and paths. Restore all six together to keep their helper APIs consistent.
3. If the Studio backup folder still exists, preserve the current PackRevealGui, then use its backed-up PackRevealGui to restore the pre-polish GUI in `StarterGui`. Verify that no newer manual layout changes would be discarded.
4. If the in-memory GUI backup has been lost, obtain a saved/recovered place version containing the pre-polish GUI. This local package cannot reproduce an exact GUI rollback.
5. Verify the restored layout and normal pack/combat flow in a fresh session after securing the place.

## Reapplying the polish

Use the six `scripts/` files as the replacement sources of the matching existing `ReplicatedStorage` modules. Apply the function returned by `PolishPackRevealGui.luau` to the existing `StarterGui.PackRevealGui`; keep it as an editable authored GUI.

Final read-only verification confirmed all six live sources match the local files and compile, including the ancestor-aware UnitViewport ReducedMotion check. Studio was in Edit mode, all 154 GUI geometry checks matched the backup, all 60 text labels/buttons had TextOutline, no _MotionPolishQA fixture remained, and PackRevealGui.Enabled was false. Reapplication is unnecessary for that verified session. After a restart or recovery, compare sources before applying anything again.

Reapplication and rollback are instructions only; creating these documents did not call Studio, restart it, start Play, or save/publish the place.


