# Pack shop gloss and audio

Applied to the connected Anime Combat Units Studio place on 2026-09-24.

Editable gloss lives under StarterGui.PackShopGui: ShopFinish on five pack images and four buy buttons. Layout, Common clipping, XP reward cards, and prices are preserved.

PackShopEffects binds hover/selection/click feedback and runs staggered gloss every 7 seconds. PackShopGui.GlossInterval adjusts cadence. Closing cancels active gloss. PackShopUI plays confirmation only after a successful purchase and unavailable feedback on blocked actions.

Editable sound volume and playback speed: SoundService.PackShopSounds. All audio is free Creator Store audio:
- Hover: UI_3_Clicks_02_Hover, CoreCraft Studio, https://create.roblox.com/store/asset/139719503904449
- Click: ui-simple-button-click, AmbientSorcery, https://create.roblox.com/store/asset/88442833509532
- Confirm: UI - Confirm 1, lluma3D, https://create.roblox.com/store/asset/116995696565929
- Unavailable: ui-simple-negative-error, AmbientSorcery, https://create.roblox.com/store/asset/87519554692663

Verified in Studio Play: all four audio assets loaded and accepted Play; nine gloss layers; no authored button geometry changes; Common mask and two packs intact; unavailable purchase guard; close cancels gloss and reopen resumes. Screenshot inspected. Temporary runtime check removed.

Common Robux purchase backend remains unavailable, as before. Save the place in Studio to persist live edits.
