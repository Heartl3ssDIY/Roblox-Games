Playground Classics — custom emote wheel and original item PNGs

Installed in Roblox Studio Edit mode. Play was not started or stopped.

StarterGui.PlaygroundEmoteWheel contains the authored, editable wheel and its Controller.
Use the Emotes button or period key in the lobby. Gamepad: D-pad down opens, A selects,
B closes, bumpers change page. Mouse/touch can select any visible dance. Keyboard 1–8
selects a slot while the wheel is open. Owned dances appear eight per page.

The native Roblox emote menu is hidden by the client controller. The wheel reuses the
existing shop ownership, unlock, avatar and lobby rules. The shop still sets the podium
emote independently. Stop ends the current dance without changing that equipped choice.
Movement/jumping also stops dances. Roblox-unavailable Take The L remains omitted.

The supplied original UI-512 PNGs are now bound to all 50 existing bat, pet and toy
catalog entries and the four toy hotbar slots. Six event-bat images are imported and
mapped separately for future event catalog entries. No event IDs are confused with
the emote E IDs. ItemIconAssets.json records source paths, SHA256 and Roblox image IDs.
All 56 image assets passed an ImageLabel-instance load check.

Existing shop positions/sizes and gameplay prices/actions are preserved. The new GUI
and Thumbnail ImageLabels are authored in StarterGui; controllers update content and
visibility without rewriting their layout coordinates. All existing script capability
settings are retained. The new wheel uses the established toy-UI controller sandbox.

After contains installed sources. Before and ServerStorage.EmoteWheelBackup20261005
retain the previous scripts and UI. Install.luau refuses to overwrite changed sources
or repeat an installation over the backup. Do not rerun it on the installed place.

NativeLayoutValidation.json covers nine device sizes. Tests contains native behavior,
real-widget binding, Stop-action, PNG and source-preservation checks. These are Edit-mode
checks, not a live multiplayer playtest. The separate expansion model pack is in
../PlaygroundExpansionModels20261005; those FBX models are ready for later Studio import.

Roblox documentation used:
https://create.roblox.com/docs/characters/emotes
https://create.roblox.com/docs/reference/engine/classes/ContextActionService
