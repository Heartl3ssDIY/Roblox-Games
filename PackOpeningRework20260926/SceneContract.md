# Pack opening v2 scene contract

Build root: C:/Users/sandt/Documents/Local Projects/Roblox UI Assets/Btns/PackOpeningRework20260926
Presentation only. Existing reward generation, odds, purchases and PlayerData remain untouched. Preserve PackReveal.play(playerGui, received, onDone), revealNow(), skip(), close(), isOpen().

ScreenGui PackRevealGui, Enabled=false, ResetOnSpawn=false, DisplayOrder=220, safe screen insets, sibling ZIndex (required for cropped CanvasGroup tear/fade). Attributes: Revision='Cinematic20260926', AutoOpenDelay=1.1, ReducedMotion=false, SoundEnabled=true, XPBeatSeconds=.38, NewUnitHoldSeconds=1.15. Timings are editable attributes with conservative code fallbacks.

Top-level:
- Background (Frame full-screen), UIGradient named ThemeGradient.
- Atmosphere (Frame full-screen transparent, Z2): Aura (ImageLabel smoke_main.dds), Rays (Frame with 14 radial gradient Frame rays), Motes (Frame). All decorative, no input blocking.
- Flash (Frame full-screen white, transparency1, Z90, Active=false).
- Particles (Frame full-screen transparent Z80, Active=false).
- Landscape and Portrait (Frame, fixed authoring sizes 1280x800 and460x820, centred with AnchorPoint .5,.5), UIScale Fit. Only one visible at runtime. No blanket CanvasGroup for viewport reliability.
Each layout has identical child paths:
  Header (TextLabel top, e.g. GOLD PACK), Subheading (TextLabel e.g. ANIME COMBAT UNITS).
  Opening (Frame full layout, visible initially):
    Pack (ImageButton, authored size ~280x460 desktop /228x374 portrait, anchored centre, image Assets.Gold). UIScale Motion=1.
      Seal (CanvasGroup, top .14 crop, hidden): Artwork ImageLabel correctly cropped; ClipsDescendants true.
      Body (CanvasGroup, lower .86 crop, hidden): Artwork correctly cropped; ClipsDescendants true.
      Foil (Frame inset to printed area, clipped): Shine(Frame full) with UIGradient Sweep, soft diagonal transparencies.
      Seam (Frame at14% Y, fullwidthgold, alpha1), SeamProgress (Frame growing left-to-right, initially width0; use Size only during animation).
    Hint (TextLabel TAP TO OPEN), Subhint (TextLabel optional).
  Rewards (Frame full, hidden):
    Title (TextLabel YOUR REWARDS)
    Cards (ScrollingFrame with UIGridLayout Grid; desktop cells186x264,4/5cols, portrait cells126x188,3cols; UIPadding; AutomaticCanvasSize Y)
    Empty (TextLabel,hidden)
    Continue (TextButton) with Label TextLabel, UIScale Motion; green/gold clear shape.
    Totals (TextLabel XP summary)
  Showcase (Frame full, hidden):
    Kicker (TextLabel NEW UNIT DISCOVERED), Rarity (TextLabel EPIC), UnitName (TextLabel), Subtitle (TextLabel)
    Hero (Frame anchored centre): UIScale Motion, ViewportFrame UnitModel (fills hero), Fallback (TextLabel ?/name hidden), silhouette should use overlay or LightColor but do not mutate source models.
    Mystery (ImageLabel, question mark child Question, UIScale Motion), initially visible onlyduringmystery, uses rarity card asset.
    Continue (TextButton) with Label and UIScale Motion, hidden untilhold.
  Skip (TextButton SKIP ANIMATION), alwaysbottomright/portraitbottomcenter, UIScale Motion.

Templates (Folder):
- Card (Frame fixed186x264). UIScale Motion. All template children use SCALE positions to work in126x188cells too. Children:
  Back(ImageLabel Asset XPCommon,full), Edge(UIStroke oncard), UnitModel(ViewportFrame), Fallback(TextLabel), UnitName(TextLabel), Amount(TextLabel), NewUnit(TextLabel/badge), Level(TextLabel), XPTrack(Frame) with Fill(Frame relativewidth) and Value(TextLabel). Samepathsonallrarities: set Back.Image fromAssets and Edge.Color.
- Spark (ImageLabel sparkles_main.dds,white, transparentbackground), Confetti(Frame), TearShard(Frame), all Visible=false, centredanchors, noActive.

Sounds (Folder inGUI): Windup, Tear, Tick, Reveal, Land, Continue (Sound). Use existing game-authorized SoundIDs as reasonable placeholders:
Click rbxassetid://88442833509532, Confirm rbxassetid://116995696565929, Hover rbxassetid://139719503904449. Do not call any audio purchase/search/publish. Volume<=.35, differentPlaybackSpeed as authored. Runtime clones/plays per cue, SoundEnabled attribute, preload nonblocking.

Visual direction: nativeRobloxUI and userACUpackart. Rich GOLD opening atmosphere matchingreference, subtleplumedges/creamgoldcore; color theme accordingtopack. Movingsoftglow and14thinrays, restrainedsparks. Packhasanticipationsquash,bilateraltilt, progressivebrighttearline, topsealspinsaway/bodyfallsaway, smallmatchingfoilshards. DuplicateXPcards arrive briskly and countXP, no2seconddelaypercard. ForNEW units background shiftsraritycolor, mysterycardcharges~.65sec, flip/narrowflash(alwayslow-intensity/reducedmotionrespect), thenlargeanimatedactualUnitViewport model hero +boldname andrarity. Hold1.15thenContinue to nextnewunit/summary. Finishallrewardsclearlyvisible responsivegrid withXP/newtags/Continue. No random rewardlogic.

Responsiveness: fit active logical board withUIScale. Portraitlayout460x820 scales todevicewidth; landscape1280x800. Selectone basedavailableviewportaspectratio<.85; orientationcrossoverduringsequence cancelsvisualsequenceandsettlescompleteResults onnewlayout withoutcallback/rewardsmutation. Same-aspectresizes justfit. Runtime onlyanimatesauthoredposes/clonestemplates; do not rebuildauthoredlayouts.

Cleanup: versiontokens + sessionidentity, cancelalltweens/delays bytoken, disconnectinputandrenderconnections onclose; UnitViewport.clear beforedestroy. Externalgui disable/destroy must releasecallbackonce. Replay previouscallbackexactlyonce before newassignment withoutinvalidatingnewsessions. BuildrebindifPlayerGui/GUIreplaced. CallbackonlyClose/finishedContinue, NEVERskip. Missingmodelsusefallback. Skipanytime=>allsummary. Empty/malformedresultstillclosable. GamepadA/Return/Spaceadvance; B/EscskiporcloseResults; restoreoldGuiService.SelectedObject onlyifvalid andnotownedbynewsession. Noinputactionswhenclosed.

