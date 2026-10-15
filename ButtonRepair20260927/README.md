# Main screen button repair — 27 September 2026

The connected Anime Combat Units place is 111313211501470. These changes are installed in Roblox Studio Edit mode; save the place in Studio to keep them.

- Repaired an ArenaSelectionUI startup crash: the arena Teleport control is a TextButton, so its disabled appearance now uses text/background transparency rather than ImageTransparency.
- Play and Packs reopen their intended panels directly after travel. PvP closes older panels before travel so an invisible or stale panel cannot block the next selection.
- Buttons for areas still under construction and Units Mastery now show clear notices. The Shop's Robux controls show stub notices; they do not initiate a purchase or grant an item.
- The top navigation buttons use the authored scale of 0.24, are centered at 0.25 / 0.5 / 0.75 across the screen, cap at 300 × 125 pixels, and retain a 2.4 aspect ratio.

The pre-change Studio scripts are backed up under ServerStorage.BeforeMainScreenRepair_20260927. The final Luau source files are in this folder.

A live Play check passed for Play and reopening it, arena Main and Back, Packs and reopening it, PvP, Units and Mastery, Shop, and BattlePass. No button-related console errors appeared in that check. Product purchasing, ranked play, and other unfinished game features are still unimplemented.
