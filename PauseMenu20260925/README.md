# AI match pause menu

The in-match ArenaHUD.LeaveArena button is replaced by ArenaHUD.Pause. The menu is authored in StarterGui.ArenaHUD.PauseOverlay, with its reusable button template at ArenaHUD.Templates.PauseAction. It uses the existing purple/gold panel art, matching gloss, Permanent Marker labels and green/purple/red buttons.

Resume continues the same match. Settings contains working UI sound and battle-effect toggles. Quit opens a forfeit confirmation explaining the one-win progress penalty and retention of earned rewards. Confirming returns to the lobby and records exactly one loss, with no match-reward grant. Practice matches do not change progression. Cancelling quit preserves the match.

P or gamepad Start toggles pause. Existing external LeaveArena requests now open the pause menu during active matches. Post-match lobby navigation remains available after a match is finished.

MatchClock freezes draft deadlines, opponent draft waits, banners and inter-pick delays. CombatController pauses AI movement, damage, attacks and elapsed time; AttackAnimator pauses unit poses. Existing short-lived impact flashes may finish fading while paused.

Menu settings use current-session state. Existing PlayerData persistence remains unchanged.

Verified in Studio Play:
- Draft timer and gameplay clock frozen while paused; resume advances them.
- Sound mute/restoration and battle effects toggle.
- Quit cancellation and direct-exit guard.
- Forfeit applies one loss only, preserves earned milestones, grants no currency, restores lobby.
- AI combat health, positions, attack count and clock freeze, then resume.
- Practice exit does not charge a loss.
- Menu screenshot visually checked; all edited scripts compile.
- Temporary checks removed; Studio returned to Edit.

Backup: ServerStorage.BeforePauseMenu20260925 and backup_scripts.
Save the place in Studio to persist live edits.
