# ACU pack-opening redesign

Installed in the open Anime Combat Units Studio project, place 111313211501470, on 26 September 2026. The game has not been published by this task.

## Installed content

- StarterGui.PackRevealGui: editable Landscape (1280x800), Portrait (460x820), and CompactLandscape (960x400) layouts, card and effect templates, and sound cues.
- ReplicatedStorage.PackReveal: animation, responsive layout selection and input handling. The existing play, revealNow, skip, close and isOpen interface remains compatible with PackShopUI and ArenaSelectionUI.

The scene uses the game's existing textured 3D unit models through UnitViewport. Drawn browser-preview characters are not included. Existing ACU pack/card images and Permanent Marker remain in use.

The presentation now includes a cropped foil tear, faster duplicate XP reveals, rarity-coloured character showcases, a restrained confetti celebration and complete reward summaries. Reduced motion and sound can be controlled through the ScreenGui attributes; Roblox's reduced-motion preference is also honoured. Background decoration fills the screen while controls stay within the safe area. Existing unit models preload asynchronously during opening.

No pack odds, prices, currency, inventory, progression or reward-generation scripts were changed.

## Backups and restoration

The original GUI and module are preserved at ServerStorage.BeforePackOpeningV2_20260926, under their original names. PreviousPackReveal.luau is also a local source backup.

To restore, stop Play mode, archive the current StarterGui.PackRevealGui, clone the backed-up GUI to StarterGui, and copy the backed-up PackReveal.Source into ReplicatedStorage.PackReveal.Source. Start a fresh playtest so the module cache is refreshed. No data migration is required.

## Validation performed

Both the GUI builder and final controller compiled in Studio. Native screenshots checked desktop, iPhone 17 Pro portrait and iPhone 17 Pro landscape. The game supports both orientations (StarterGui.ScreenOrientation = Sensor). The compact landscape Continue button measured approximately 215x46 screen pixels at a 749x303 safe viewport, compared with 108x22 before its dedicated layout.

Synthetic presentation results verified all five actual 3D reward models, complete reward summaries, missing-model fallback, empty rewards, repeated opening, Skip, external disable, GUI destruction/rebinding, and exactly-once close callbacks. PlayerData was unchanged before and after these checks.

The new-unit celebration produced 24 confetti pieces plus 12 brief sparks; cancellation removed all particles without delayed leftovers. Reduced motion produced no particles, and disabling sound stopped active cues. All six authored sound cues loaded. The Studio console was clear during the checked sequences.

Desktop-to-phone orientation changes settled safely to the reward summary. Physical mouse/touch/controller input was not simulated; controls were inspected and the public presentation methods were exercised programmatically. Final asynchronous model preloading was compile-checked after the visual/behavior pass.

Studio was left in Edit mode with the reveal disabled and device simulation reset to default. The temporary browser preview server was stopped.

## Editing and reinstalling

Edit the three ScreenGui boards directly in Studio. Keep their matching named child paths. ZIndexBehavior must remain Sibling for the tear CanvasGroups. Timing attributes include AutoOpenDelay, XPBeatSeconds and NewUnitHoldSeconds.

CreatePackRevealV2.luau returns an unparented replacement ScreenGui. scripts/PackReveal.luau contains the installed controller source. Back up the current two objects before rebuilding; parent the returned GUI under StarterGui and update the module only while Play mode is stopped. The builder does not install or publish by itself.