# Units UI replacement — 21 September 2026

Implemented in Anime Combat Units (place 111313211501470).

- Original PNGs are in assets; Roblox image IDs are in scripts/UnitsUIAssets.luau.
- UnitsUI builds the collection, selected-unit detail, search, filters, lock state, equip/unequip, full-team replacement and level-up confirmation.
- LobbyMenuClient opens the new interface and uses the supplied Units button. The existing Shop remains available.
- PlayerData adds unit lock state and blocks changing locked units away from owned.
- Mastery intentionally has no navigation. Abilities replaces Spells and currently has no collectible abilities to show.
- Existing player progress and loadout are client-side prototype data; progress and locks reset on rejoin. This change does not add persistence or a unit-deletion feature.

Checked in Studio Play mode: artwork/model rendering, collection/detail views, search, front-line filter, equip/unequip, full-team swap, lock ownership guard, Abilities empty state, Shop navigation and paid level-up (level 1 to 2; 1000 coins; health 126 to 139; damage 13 to 14). Temporary verification was removed after testing. Final test run produced no script errors.

The backup_scripts directory contains the exact pre-change sources. No live experience publication was performed.
## Animated previews

UnitPreviewAnimator adds a procedural fighting guard with breathing and weight shifts for the existing R6 and R15 unit rigs. Selecting a unit plays a short jab–cross–kick sequence in the larger ViewportFrame and blends back into guard. Clicking that preview replays the combo. Cards continue their idle motion with staggered timing. Hidden or scrolled-out previews pause, and destroyed previews release their animation state. Only cloned UI models are animated; AttackAnimator and gameplay models are unchanged. No external animation pack or uploaded animation IDs are required.

Verified visible limb movement on R6 Yumcha and R15 Krillen, combo rendering and return to idle, plus clean Studio output.