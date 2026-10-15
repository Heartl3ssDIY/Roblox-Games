# Attack choreography update

Status: installed in Anime Combat Units Studio, place 111313211501470, on September 26, 2026. Current script backups are in ServerStorage.BeforeAttackTiming_20260926_1790446414. The place has not been saved or published by this setup.

Combat now separates wind-up, release and recovery. Damage and blast effects occur at release, once per attack. A pending attack cannot overlap another, fire after its attacker is defeated, or retarget a dead opponent. Match pause freezes charges and beams. Winning attacks keep their recovery/landing before the result is delivered.

Master Roshu: crouch, jump, airborne charge with cupped hands, release at 1.35 seconds, recoil, descent and landing at 2.25 seconds. His 5.3-second cooldown is unchanged. His logical root remains on the arena; the rig's body rises about 2.8 studs through its root joint.

Unit cooldowns in seconds (attack start to next attack start):

| Unit | Previous | New |
| --- | ---: | ---: |
| Yumcha | 0.30 | 0.60 |
| Krillen | 0.30 | 0.60 |
| Goku | 1.00 | 1.05 |
| Tein | 1.00 | 1.05 |
| Pikkolo | 0.30 | 0.82 |
| Bluma | 0.50 | 0.72 |
| Master Roshu | 5.30 | 5.30 |

The fastest attacks have a larger relative slowdown to fit visible anticipation and recovery. Health, damage per hit, rarities, unlocks and all other UnitData fields are unchanged. These cooldown changes affect damage per second and match balance; they have not yet been playtested. UnitData and the shared AttackTimeline agree so displayed cooldowns match combat.

## Files and checks

- scripts/AttackTimeline.luau: shared release/duration/cooldown profiles.
- scripts/AttackAnimator.luau: R6/R15 keyed poses, clock-based sampling and restoration.
- scripts/CombatController.luau: queued releases, hand-aligned charge/blast effects and lifecycle handling.
- scripts/UnitData.luau: six cooldown changes only.
- before/: exact pre-update sources for the three replaced modules, plus MatchClock reference.
- tests/LocalCompilation.json: all four modules and installer compiled with official Luau 0.740.
- tests/AttackTimelineOfflineResults.json: seven unit profiles and data preservation passed offline.
- tests/R6PalmGeometry.json: mathematical palm alignment and jump timing check. The installed modules also passed tests/RealRoshiPoseAudit.luau on a clone of the actual R6 character. At 0.68 seconds his torso is 2.8 studs above rest and both hands are cupped; at 1.35 seconds the hands extend for release; by 2.25 seconds the torso returns to rest. The logical root never moved.
- tests/AttackTimingRegression.luau: compiled native regression harness covering release timing, pause/cancel/death/effects/outcome and R6/R15 pose restoration. It passed in Edit mode using isolated native instances: 28 controller traces, two animator rigs and nine lifecycle scenarios, including pause, cancellation, death, and Roshu landing before the result callback.

## Applying and restoring

The verified target was Anime Combat Units, place 111313211501470, in Edit mode.

InstallAttackTiming.luau embeds the four prepared sources. It compiles them, verifies the expected existing sources, and creates a ServerStorage.BeforeAttackTiming_20260926_<timestamp> backup before changing anything. It refuses a different place, Play mode, conflicting existing AttackTimeline, or changed source versions. An application error restores old sources and removes newly created modules. It does not save or publish the place.

The isolated regression harness passed. A full live fight visual check remains useful after saving the place.

To restore, stop the playtest; restore AttackAnimator, CombatController and UnitData Source from that ServerStorage backup, and remove only the newly added AttackTimeline module. The before/ files are the local fallback. This restores the preceding motion polish. Neither backup is a complete place backup.