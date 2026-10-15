    local short = math.min(viewport.width,viewport.height)
    local compact = viewport.width<=900 or short<=600 or (short<=1024 and math.max(viewport.width,viewport.height)<=1400)
    local portrait = compact and viewport.height>viewport.width
    visible(clones,"PlaygroundShell.LevelPanel",not compact)
    visible(clones,"PlaygroundShell.CompactLevelPanel",compact and not inRound)
    visible(clones,"PlaygroundShell.Dock",not compact and not inRound)
    visible(clones,"PlaygroundShell.CompactDock",compact and not inRound)
    visible(clones,"PlaygroundSessionControls.Toggle",not compact and not inRound)
    visible(clones,"PlaygroundSessionControls.Spectate",not compact and not inRound)
    visible(clones,"PlaygroundSessionControls.CompactToggle",compact and not portrait and not inRound)
    visible(clones,"PlaygroundSessionControls.CompactSpectate",compact and not portrait and not inRound)
    visible(clones,"PlaygroundSessionControls.PortraitToggle",portrait and not inRound)
    visible(clones,"PlaygroundSessionControls.PortraitSpectate",portrait and not inRound)
    visible(clones,"PlaygroundSessionControls.RoundToggle",not compact and inRound)
    visible(clones,"PlaygroundSessionControls.CompactRoundToggle",compact and not portrait and inRound)
    visible(clones,"PlaygroundSessionControls.PortraitRoundToggle",portrait and inRound)
    visible(clones,"BritishBulldogHUD.MovementControls.Meter",not compact)
    visible(clones,"TagHUD.SprintPanel.Meter",not compact)
    visible(clones,"PlaygroundEmoteWheel.Toggle",not compact and not inRound)
    visible(clones,"PlaygroundEmoteWheel.CompactEmoteToggle",compact and not portrait and not inRound)
    visible(clones,"PlaygroundEmoteWheel.PortraitEmoteToggle",portrait and not inRound)
    visible(clones,"PlaygroundIntermissionHUD.Desktop",not compact and not inRound)
    visible(clones,"PlaygroundIntermissionHUD.Compact",compact and not portrait and not inRound)
    visible(clones,"PlaygroundIntermissionHUD.Portrait",portrait and not inRound)
    visible(clones,"PlaygroundFishingHUD.DesktopDock",not compact and hasBoosts)
    visible(clones,"PlaygroundFishingHUD.CompactDock",compact and not portrait and hasBoosts)
    visible(clones,"PlaygroundFishingHUD.PortraitDock",portrait and hasBoosts)
    visible(clones,"PlaygroundFishingHUD.RoundDock",compact and inRound)
    for _,dockName in {"DesktopDock","CompactDock","PortraitDock","RoundDock"} do
        for _,boost in {"Coins","XP"} do visible(clones,"PlaygroundFishingHUD."..dockName.."."..boost,hasBoosts or inRound) end
    end
    local wallet=resolve(clones,"PlaygroundShell.Wallet.Coins")
    if wallet then wallet.Text="100,000" end
    local level=resolve(clones,"PlaygroundShell.CompactLevelPanel")
    if level then
        level.Level.Text="LV 500"
        level.NextLevel.Text="NEXT: LV 501"
        level.XP.Text="99,999 / 100,000 XP"
    end
    for _,cardName in {"Compact","Portrait"} do
        local card=resolve(clones,"PlaygroundIntermissionHUD."..cardName)
        if card then card.Title.Text="WAITING" card.Timer.Text="" card.Detail.Text="Players ready: 1 / 2" end
    end
