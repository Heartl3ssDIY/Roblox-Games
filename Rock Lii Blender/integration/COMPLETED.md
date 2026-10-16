# Rock Lii animation integration — 29 September 2026

Both reviewed Blender clips were published as Animation assets owned by Deus Invictus Studios (group 168026080) and connected in Anime Combat Units (place 111313211501470).

| Move | Asset ID | Duration |
| --- | --- | --- |
| Triple Punch | 91381829613134 | 1.5 seconds |
| Drunken Fist | 82528180377250 | 7 seconds |

The three base damage events align with Blender impact frames 9, 20, and 33. Rock Lii approaches within 3 studs before attacking. Hand effects alternate with the punches. Drunken Fist keeps gameplay-controlled travel and immunity; both animated fists deal 50 damage on a fresh enemy contact, rearming after separation. Motion and playback synchronize before Animator evaluation; contact checks follow it. Playback preloads, pauses with the match clock, and resets R6 offsets on completion or cancellation.

Validation: `qa_animation_final.json` passes 37 animation checks, including published-asset loading, both rig forms, punch markers, leg motion, planted feet, one full spin, pause/resume, and cleanup. `qa_combat_verified.json` passes 17 production-controller checks, including three 20-damage punches, a seven-second ability, immunity, route travel and return, 50-damage contact/re-entry, and one use per round. Tests used temporary Client Play rigs without reward callbacks or player-profile writes.

The original scripts are preserved in `ServerStorage.RockLiiAnimationExports.IntegrationBackup`. Final local sources are `RockAnimationPlayer.luau`, `CombatController.proposed.luau`, and `AttackTimeline.proposed.luau`; despite the proposal filenames, these final versions have been applied in Studio.

The complete edited place was saved locally as `../Anime Combat Units - Rock Lii Animations.rbxl`. The entire place was not published to live servers by this task. Portable animation exports are in `../exports/*.rbxmx`, with published IDs in `../exports/published_assets.json`. Use the corrected JSON/RBXMX files for future import, not the provenance-only raw RBXMonkey files.

Remaining scope: mastery retains its existing four-hit damage timing but still needs a separate reviewed four-punch animation. Drunken Fist works on both models. Very short contacts during frame hitches over 0.1 seconds may be missed because long interpolated sweeps are deliberately avoided.
