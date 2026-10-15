# G-Blox main menu
Installed in the G-Blox main place, 74498603638770, on 6 September 2026.

The editable menu is at ReplicatedFirst > GBloxLoading > GBloxMenu > Root.
LoadingScreen and MainScreen are separate frames. Shared artwork and the sound toggle sit under Root.
GBloxLoading is the client script, MenuConfig holds artwork and sound IDs, and GBloxLobbyGate releases the player after Play.
BuildMenu.luau records how the editable UI was built. These files are local source backups; the installed copy lives in Studio.

Loading waits for the 11 menu images, 5 retro sounds, the lobby image, the initial game load and nearby streaming. Failed downloads show Retry and never claim 100%.
Play fades the menu out over 0.65 seconds, restores movement and allows the existing party zones.
Shop and Settings currently show a short coming-soon message. Add ShopPanel and SettingsPanel under MainScreen, or connect to the OpenShop and OpenSettings BindableEvents on GBloxMenu.

The existing PartyController had references to absent BotCount controls. Those controls are now optional.
QueueServer ignores zone entry until GBloxLobbyReady is true.
The .before.luau files preserve the original party scripts.

Verified in Studio:
- All menu assets loaded; loading reached 100% and opened the main menu.
- No movement while the menu was open.
- Different Shop, Settings and Play click sounds, hover response, and mute/unmute.
- Full-size and compact portrait layouts.
- Visible fade, then menu removal and restored character movement.
- Entering an existing party zone opened Create Party.
- No errors in the final play-test output; all five scripts compiled.

Changes are in the open Studio place. They have not been published to the live experience.

