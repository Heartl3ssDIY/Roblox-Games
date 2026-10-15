# Motion polish — 26 September 2026

Target: Anime Combat Units, place 111313211501470.

Final read-only verification succeeded in the same Studio session in Edit mode. All six live modules match the local files, including the ancestor-aware UnitViewport ReducedMotion check, and all six compile. A whole-place save or publish has **not** been confirmed.

## Changes

- **UnitViewport:** fits visible model geometry, excludes fully transparent accessories from framing, reuses preview models, smooths camera resizing, and adds a gentle camera reveal without resizing the viewport.
- **UnitPreviewAnimator:** blends R6/R15 idle and combo poses, smooths retriggers, uses Motor6D.Transform without changing the original C0, pauses hidden previews, and cleans up connections.
- **UnitsUI:** uses the shared viewport helper for collection previews.
- **PackReveal:** softens card entrances and uses a camera push for the hero reveal while keeping its viewport at a fixed size.
- **CombatController:** interpolates displayed movement between existing simulation updates. Logical combat positions and combat timing remain unchanged.
- **AttackAnimator:** eases walking and attack poses and disconnects its render loop when no units remain.
- **PolishPackRevealGui.luau:** updates existing PackRevealGui text outlines, Continue-button borders, card edges, and viewport lighting in place.

The existing Permanent Marker font, ACU artwork, textured 3D units, button sizes, positions, and anchors are retained. Pack odds, prices, rewards, currency, and progression were not changed.

## Validation

- All six replacements compiled before the main installation and again during final verification. The six final live sources match the local files after line-ending/trailing-whitespace normalization.
- Final verification confirmed all **154 existing GuiObject positions, sizes, and anchors** still match the original backup, and all 60 text labels/buttons have TextOutline.
- GUI patch report: 60 text outlines, 6 button borders, 1 card edge, and 4 viewport lighting updates.
- Saved combat regression results pass all five cases: 60 FPS, 30 FPS, jitter/hitches, pause/resume, and cancellation. Old/new health, attacks, winner, and logical movement matched; maximum logical position error was zero. Connections were cleared after cancellation.
- Preview checks covered R6/R15 at 30/60/120 FPS, attach/retrigger continuity, hidden previews, reduced motion, and cleanup. In Studio, 40 rendered samples showed all tested rigs moving, unchanged C0 values, reused previews, and maximum joint residual below 0.000001 studs.
- Native previews were visually checked with the actual textured unit models. A native combat visual test **could not complete because Studio became unresponsive**. The deterministic combat checks are not a substitute for that remaining visual check.

Final verification also confirmed the Studio backup folder is present, no _MotionPolishQA fixture remains, and PackRevealGui.Enabled is false. No additional live edits or playtests were performed during this verification.

The saved combat harness, results, and [final installation verification](tests/FinalInstallVerification.json) are in [tests](tests). Preview verification evidence was reported during the session; there is no separate preview-results file in this folder.

See [RESTORE.md](RESTORE.md) for backups and rollback boundaries.


