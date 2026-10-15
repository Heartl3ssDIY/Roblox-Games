local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
assert(not RunService:IsRunning(), "UI reskin audit requires Edit mode")
local contracts = HttpService:JSONDecode([==[{"paths":[["StarterGui.BritishBulldogHUD.TopCard.Panel","Frame"],["StarterGui.BritishBulldogHUD.TopCard.Panel.BulldogChip","Frame"],["StarterGui.BritishBulldogHUD.TopCard.Panel.RunnerChip","Frame"],["StarterGui.BritishBulldogHUD.RolePill.Panel","Frame"],["StarterGui.BritishBulldogHUD.Departure.Panel","Frame"],["StarterGui.BritishBulldogHUD.Departure.Panel.SecondsBadge","Frame"],["StarterGui.BritishBulldogHUD.Tagged.Panel","Frame"],["StarterGui.BritishBulldogHUD.Results.Panel","Frame"],["StarterGui.BritishBulldogHUD.MovementControls.Meter","Frame"],["StarterGui.BritishBulldogHUD.MovementControls.Meter.Track","Frame"],["StarterGui.BritishBulldogHUD.MovementControls.Sprint","TextButton"],["StarterGui.BritishBulldogHUD.MovementControls.Dodge","TextButton"],["StarterGui.BritishBulldogHUD.MovementControls.EscapeBoost","Frame"],["StarterGui.BritishBulldogHUD.CompactDeparture.Panel","Frame"],["StarterGui.BritishBulldogHUD.CompactDeparture.Panel.SecondsBadge","Frame"],["StarterGui.TagHUD.Top","Frame"],["StarterGui.TagHUD.Top.TaggerChip","Frame"],["StarterGui.TagHUD.Role","Frame"],["StarterGui.TagHUD.Controls.Vault","TextButton"],["StarterGui.TagHUD.Controls.Dodge","TextButton"],["StarterGui.TagHUD.Results","Frame"],["StarterGui.TagHUD.SprintPanel.Meter","Frame"],["StarterGui.TagHUD.SprintPanel.Meter.Track","Frame"],["StarterGui.TagHUD.SprintPanel.Sprint","TextButton"],["StarterGui.PlaygroundAdminPanel.Toggle","TextButton"],["StarterGui.PlaygroundAdminPanel.Panel","Frame"],["StarterGui.PlaygroundAdminPanel.Panel.Close","TextButton"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.BritishBulldog","Frame"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.BritishBulldog.BBStart","TextButton"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.BritishBulldog.BBRunner","TextButton"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.BritishBulldog.BBBulldog","TextButton"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.TagYoureIt","Frame"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.TagYoureIt.TagStart","TextButton"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.TagYoureIt.TagRunner","TextButton"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.TagYoureIt.TagTagger","TextButton"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.StuckInTheMud","Frame"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.StuckInTheMud.MudStart","TextButton"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.StuckInTheMud.MudShooter","TextButton"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.StuckInTheMud.MudMedic","TextButton"],["StarterGui.PlaygroundAdminPanel.Panel.StopRound","TextButton"],["StarterGui.PlaygroundAdminPanel.Panel.ToggleAutomatic","TextButton"],["StarterGui.PlaygroundAdminPanel.CompactPanel","Frame"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Close","TextButton"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.BritishBulldog","Frame"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.BritishBulldog.BBStart","TextButton"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.BritishBulldog.BBRunner","TextButton"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.BritishBulldog.BBBulldog","TextButton"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.TagYoureIt","Frame"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.TagYoureIt.TagStart","TextButton"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.TagYoureIt.TagRunner","TextButton"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.TagYoureIt.TagTagger","TextButton"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.StuckInTheMud","Frame"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.StuckInTheMud.MudStart","TextButton"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.StuckInTheMud.MudShooter","TextButton"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.StuckInTheMud.MudMedic","TextButton"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.StopRound","TextButton"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.ToggleAutomatic","TextButton"],["StarterGui.PlaygroundAdminPanel.CompactToggle","TextButton"],["StarterGui.PlaygroundShell.Wallet","Frame"],["StarterGui.PlaygroundShell.Dock.Shop","TextButton"],["StarterGui.PlaygroundShell.Dock.Emote","TextButton"],["StarterGui.PlaygroundShell.Dock.Emoji","TextButton"],["StarterGui.PlaygroundShell.RewardToast","Frame"],["StarterGui.PlaygroundShell.ShopPanel","Frame"],["StarterGui.PlaygroundShell.ShopPanel.Close","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Categories.All","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Categories.Pets","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Categories.Emotes","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Categories.Emojis","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Categories.Trails","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Categories.Highlights","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Categories.Gear","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot01","Frame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot01.Preview","ViewportFrame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot01.Action","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot01.Try","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot02","Frame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot02.Preview","ViewportFrame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot02.Action","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot02.Try","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot03","Frame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot03.Preview","ViewportFrame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot03.Action","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot03.Try","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot04","Frame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot04.Preview","ViewportFrame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot04.Action","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot04.Try","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot05","Frame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot05.Preview","ViewportFrame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot05.Action","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot05.Try","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot06","Frame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot06.Preview","ViewportFrame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot06.Action","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot06.Try","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot07","Frame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot07.Preview","ViewportFrame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot07.Action","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot07.Try","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot08","Frame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot08.Preview","ViewportFrame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot08.Action","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot08.Try","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot09","Frame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot09.Preview","ViewportFrame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot09.Action","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot09.Try","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot10","Frame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot10.Preview","ViewportFrame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot10.Action","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot10.Try","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot11","Frame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot11.Preview","ViewportFrame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot11.Action","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot11.Try","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot12","Frame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot12.Preview","ViewportFrame"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot12.Action","TextButton"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot12.Try","TextButton"],["StarterGui.PlaygroundShell.Templates.ItemCard","Frame"],["StarterGui.PlaygroundShell.Templates.ItemCard.Preview","ViewportFrame"],["StarterGui.PlaygroundShell.Templates.ItemCard.Action","TextButton"],["StarterGui.PlaygroundShell.Templates.ItemCard.Try","TextButton"],["StarterGui.PlaygroundShell.VotePanel","Frame"],["StarterGui.PlaygroundShell.VotePanel.BritishBulldog","TextButton"],["StarterGui.PlaygroundShell.VotePanel.TagYoureIt","TextButton"],["StarterGui.PlaygroundShell.VotePanel.StuckInTheMud","TextButton"],["StarterGui.PlaygroundShell.LevelPanel","Frame"],["StarterGui.PlaygroundShell.LevelPanel.XPTrack","Frame"],["StarterGui.PlaygroundShell.CompactLevelPanel","Frame"],["StarterGui.PlaygroundShell.CompactLevelPanel.XPTrack","Frame"],["StarterGui.PlaygroundShell.CompactVotePanel","Frame"],["StarterGui.PlaygroundShell.CompactVotePanel.BritishBulldog","TextButton"],["StarterGui.PlaygroundShell.CompactVotePanel.TagYoureIt","TextButton"],["StarterGui.PlaygroundShell.CompactVotePanel.StuckInTheMud","TextButton"],["StarterGui.MudHUD.Main.Top","Frame"],["StarterGui.MudHUD.Main.Top.Team","TextButton"],["StarterGui.MudHUD.Main.Controls.Meter","Frame"],["StarterGui.MudHUD.Main.Controls.Meter.Track","Frame"],["StarterGui.MudHUD.Main.Controls.Mud","TextButton"],["StarterGui.MudHUD.Main.Controls.Heat","TextButton"],["StarterGui.MudHUD.Main.Controls.Fire","TextButton"],["StarterGui.MudHUD.Main.Controls.Sprint","TextButton"],["StarterGui.MudHUD.Main.Frozen","Frame"],["StarterGui.MudHUD.Main.Frozen.RescueTrack","Frame"],["StarterGui.MudHUD.Main.Results","Frame"],["StarterGui.MudHUD.Main.DesktopControls.Meter","Frame"],["StarterGui.MudHUD.Main.DesktopControls.Meter.Track","Frame"],["StarterGui.MudHUD.Main.DesktopControls.Mud","TextButton"],["StarterGui.MudHUD.Main.DesktopControls.Heat","TextButton"],["StarterGui.MudHUD.Main.DesktopControls.Fire","TextButton"],["StarterGui.MudHUD.Main.DesktopControls.Sprint","TextButton"],["StarterGui.MudHUD.ColourToggle","TextButton"],["StarterGui.MudHUD.ColourPicker","Frame"],["StarterGui.MudHUD.ColourPicker.Close","TextButton"],["StarterGui.MudHUD.ColourPicker.Red","TextButton"],["StarterGui.MudHUD.ColourPicker.Blue","TextButton"],["StarterGui.MudHUD.ColourPicker.Green","TextButton"],["StarterGui.MudHUD.ColourPicker.Black","TextButton"],["StarterGui.BritishBulldogHUD.MovementControls.Meter.Track.Fill","Frame"],["StarterGui.TagHUD.SprintPanel.Meter.Track.Fill","Frame"],["StarterGui.PlaygroundShell.LevelPanel.XPTrack.Fill","Frame"],["StarterGui.PlaygroundShell.CompactLevelPanel.XPTrack.Fill","Frame"],["StarterGui.MudHUD.Main.Controls.Meter.Track.Fill","Frame"],["StarterGui.MudHUD.Main.Frozen.RescueTrack.Fill","Frame"],["StarterGui.MudHUD.Main.DesktopControls.Meter.Track.Fill","Frame"],["StarterGui.BritishBulldogHUD.MovementControls.Sprint.Icon","ImageLabel"],["StarterGui.BritishBulldogHUD.MovementControls.Dodge.Icon","ImageLabel"],["StarterGui.PlaygroundShell.Wallet.Coin","Frame"],["StarterGui.PlaygroundShell.LevelPanel.LevelIcon","ImageLabel"]],"meters":[["StarterGui.BritishBulldogHUD.MovementControls.Meter.Track.Fill","PreserveNativeFill"],["StarterGui.TagHUD.SprintPanel.Meter.Track.Fill","PreserveNativeFill"],["StarterGui.PlaygroundShell.LevelPanel.XPTrack.Fill","UseBlueArtwork"],["StarterGui.PlaygroundShell.CompactLevelPanel.XPTrack.Fill","UseBlueArtwork"],["StarterGui.MudHUD.Main.Controls.Meter.Track.Fill","UseBlueArtwork"],["StarterGui.MudHUD.Main.Frozen.RescueTrack.Fill","PreserveNativeFill"],["StarterGui.MudHUD.Main.DesktopControls.Meter.Track.Fill","UseBlueArtwork"]],"backgrounds":[["StarterGui.BritishBulldogHUD.TopCard.Panel","PNG/07-Resizable-Skins/panel-normal.png"],["StarterGui.BritishBulldogHUD.TopCard.Panel.BulldogChip","PNG/07-Resizable-Skins/red-normal.png"],["StarterGui.BritishBulldogHUD.TopCard.Panel.RunnerChip","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.BritishBulldogHUD.RolePill.Panel","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.BritishBulldogHUD.Departure.Panel","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.BritishBulldogHUD.Departure.Panel.SecondsBadge","PNG/07-Resizable-Skins/cream-normal.png"],["StarterGui.BritishBulldogHUD.Tagged.Panel","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.BritishBulldogHUD.Results.Panel","PNG/07-Resizable-Skins/panel-normal.png"],["StarterGui.BritishBulldogHUD.MovementControls.Meter","PNG/07-Resizable-Skins/panel-normal.png"],["StarterGui.BritishBulldogHUD.MovementControls.Meter.Track","PNG/04-Meter-Parts/stamina-track.png"],["StarterGui.BritishBulldogHUD.MovementControls.Sprint","PNG/05-Favourite-Buttons-Blank/sprint.png"],["StarterGui.BritishBulldogHUD.MovementControls.Dodge","PNG/05-Favourite-Buttons-Blank/dodge.png"],["StarterGui.BritishBulldogHUD.MovementControls.EscapeBoost","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.BritishBulldogHUD.CompactDeparture.Panel","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.BritishBulldogHUD.CompactDeparture.Panel.SecondsBadge","PNG/07-Resizable-Skins/cream-normal.png"],["StarterGui.TagHUD.Top","PNG/01-Empty-Panels/TagHUD-Top.png"],["StarterGui.TagHUD.Top.TaggerChip","PNG/07-Resizable-Skins/red-normal.png"],["StarterGui.TagHUD.Role","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.TagHUD.Controls.Vault","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.TagHUD.Controls.Dodge","PNG/05-Favourite-Buttons-Blank/dodge.png"],["StarterGui.TagHUD.Results","PNG/07-Resizable-Skins/panel-normal.png"],["StarterGui.TagHUD.SprintPanel.Meter","PNG/07-Resizable-Skins/panel-normal.png"],["StarterGui.TagHUD.SprintPanel.Meter.Track","PNG/04-Meter-Parts/stamina-track.png"],["StarterGui.TagHUD.SprintPanel.Sprint","PNG/05-Favourite-Buttons-Blank/sprint.png"],["StarterGui.PlaygroundAdminPanel.Toggle","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundAdminPanel.Panel","PNG/01-Empty-Panels/PlaygroundAdminPanel-Panel.png"],["StarterGui.PlaygroundAdminPanel.Panel.Close","PNG/05-Favourite-Buttons-Blank/close.png"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.BritishBulldog","PNG/01-Empty-Panels/PlaygroundAdminPanel-Panel_BritishBulldog.png"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.BritishBulldog.BBStart","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.BritishBulldog.BBRunner","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.BritishBulldog.BBBulldog","PNG/07-Resizable-Skins/red-normal.png"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.TagYoureIt","PNG/01-Empty-Panels/PlaygroundAdminPanel-Panel_BritishBulldog.png"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.TagYoureIt.TagStart","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.TagYoureIt.TagRunner","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.TagYoureIt.TagTagger","PNG/07-Resizable-Skins/red-normal.png"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.StuckInTheMud","PNG/01-Empty-Panels/PlaygroundAdminPanel-Panel_BritishBulldog.png"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.StuckInTheMud.MudStart","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.StuckInTheMud.MudShooter","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundAdminPanel.Panel.Body.Content.StuckInTheMud.MudMedic","PNG/07-Resizable-Skins/red-normal.png"],["StarterGui.PlaygroundAdminPanel.Panel.StopRound","PNG/07-Resizable-Skins/red-normal.png"],["StarterGui.PlaygroundAdminPanel.Panel.ToggleAutomatic","PNG/07-Resizable-Skins/green-normal.png"],["StarterGui.PlaygroundAdminPanel.CompactPanel","PNG/07-Resizable-Skins/panel-normal.png"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Close","PNG/05-Favourite-Buttons-Blank/close.png"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.BritishBulldog","PNG/01-Empty-Panels/PlaygroundAdminPanel-CompactPanel_BritishBulldog.png"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.BritishBulldog.BBStart","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.BritishBulldog.BBRunner","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.BritishBulldog.BBBulldog","PNG/07-Resizable-Skins/red-normal.png"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.TagYoureIt","PNG/01-Empty-Panels/PlaygroundAdminPanel-CompactPanel_BritishBulldog.png"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.TagYoureIt.TagStart","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.TagYoureIt.TagRunner","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.TagYoureIt.TagTagger","PNG/07-Resizable-Skins/red-normal.png"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.StuckInTheMud","PNG/01-Empty-Panels/PlaygroundAdminPanel-CompactPanel_BritishBulldog.png"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.StuckInTheMud.MudStart","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.StuckInTheMud.MudShooter","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.StuckInTheMud.MudMedic","PNG/07-Resizable-Skins/red-normal.png"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.StopRound","PNG/07-Resizable-Skins/red-normal.png"],["StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.ToggleAutomatic","PNG/07-Resizable-Skins/green-normal.png"],["StarterGui.PlaygroundAdminPanel.CompactToggle","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundShell.Wallet","PNG/07-Resizable-Skins/panel-normal.png"],["StarterGui.PlaygroundShell.Dock.Shop","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundShell.Dock.Emote","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundShell.Dock.Emoji","PNG/07-Resizable-Skins/silver-normal.png"],["StarterGui.PlaygroundShell.RewardToast","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundShell.ShopPanel","PNG/07-Resizable-Skins/panel-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Close","PNG/05-Favourite-Buttons-Blank/close.png"],["StarterGui.PlaygroundShell.ShopPanel.Categories.All","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Categories.Pets","PNG/07-Resizable-Skins/cream-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Categories.Emotes","PNG/07-Resizable-Skins/cream-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Categories.Emojis","PNG/07-Resizable-Skins/cream-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Categories.Trails","PNG/07-Resizable-Skins/cream-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Categories.Highlights","PNG/07-Resizable-Skins/cream-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Categories.Gear","PNG/07-Resizable-Skins/cream-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot01","PNG/02-Item-Frame-Parts/item-frame.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot01.Preview","PNG/02-Item-Frame-Parts/item-preview-background.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot01.Action","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot01.Try","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot02","PNG/02-Item-Frame-Parts/item-frame.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot02.Preview","PNG/02-Item-Frame-Parts/item-preview-background.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot02.Action","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot02.Try","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot03","PNG/02-Item-Frame-Parts/item-frame.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot03.Preview","PNG/02-Item-Frame-Parts/item-preview-background.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot03.Action","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot03.Try","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot04","PNG/02-Item-Frame-Parts/item-frame.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot04.Preview","PNG/02-Item-Frame-Parts/item-preview-background.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot04.Action","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot04.Try","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot05","PNG/02-Item-Frame-Parts/item-frame.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot05.Preview","PNG/02-Item-Frame-Parts/item-preview-background.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot05.Action","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot05.Try","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot06","PNG/02-Item-Frame-Parts/item-frame.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot06.Preview","PNG/02-Item-Frame-Parts/item-preview-background.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot06.Action","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot06.Try","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot07","PNG/02-Item-Frame-Parts/item-frame.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot07.Preview","PNG/02-Item-Frame-Parts/item-preview-background.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot07.Action","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot07.Try","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot08","PNG/02-Item-Frame-Parts/item-frame.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot08.Preview","PNG/02-Item-Frame-Parts/item-preview-background.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot08.Action","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot08.Try","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot09","PNG/02-Item-Frame-Parts/item-frame.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot09.Preview","PNG/02-Item-Frame-Parts/item-preview-background.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot09.Action","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot09.Try","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot10","PNG/02-Item-Frame-Parts/item-frame.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot10.Preview","PNG/02-Item-Frame-Parts/item-preview-background.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot10.Action","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot10.Try","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot11","PNG/02-Item-Frame-Parts/item-frame.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot11.Preview","PNG/02-Item-Frame-Parts/item-preview-background.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot11.Action","PNG/07-Resizable-Skins/silver-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot11.Try","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot12","PNG/02-Item-Frame-Parts/item-frame.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot12.Preview","PNG/02-Item-Frame-Parts/item-preview-background.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot12.Action","PNG/07-Resizable-Skins/silver-normal.png"],["StarterGui.PlaygroundShell.ShopPanel.Cards.Slot12.Try","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundShell.Templates.ItemCard","PNG/02-Item-Frame-Parts/item-frame.png"],["StarterGui.PlaygroundShell.Templates.ItemCard.Preview","PNG/02-Item-Frame-Parts/item-preview-background.png"],["StarterGui.PlaygroundShell.Templates.ItemCard.Action","PNG/07-Resizable-Skins/gold-normal.png"],["StarterGui.PlaygroundShell.Templates.ItemCard.Try","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundShell.VotePanel","PNG/07-Resizable-Skins/panel-normal.png"],["StarterGui.PlaygroundShell.VotePanel.BritishBulldog","PNG/06-Smooth-Game-Card-Blanks/british-bulldog.png"],["StarterGui.PlaygroundShell.VotePanel.TagYoureIt","PNG/06-Smooth-Game-Card-Blanks/tag-youre-it.png"],["StarterGui.PlaygroundShell.VotePanel.StuckInTheMud","PNG/06-Smooth-Game-Card-Blanks/stuck-in-the-mud.png"],["StarterGui.PlaygroundShell.LevelPanel","PNG/07-Resizable-Skins/panel-normal.png"],["StarterGui.PlaygroundShell.LevelPanel.XPTrack","PNG/04-Meter-Parts/xp-track.png"],["StarterGui.PlaygroundShell.CompactLevelPanel","PNG/07-Resizable-Skins/panel-normal.png"],["StarterGui.PlaygroundShell.CompactLevelPanel.XPTrack","PNG/04-Meter-Parts/xp-track.png"],["StarterGui.PlaygroundShell.CompactVotePanel","PNG/07-Resizable-Skins/panel-normal.png"],["StarterGui.PlaygroundShell.CompactVotePanel.BritishBulldog","PNG/07-Resizable-Skins/blue-normal.png"],["StarterGui.PlaygroundShell.CompactVotePanel.TagYoureIt","PNG/07-Resizable-Skins/red-normal.png"],["StarterGui.PlaygroundShell.CompactVotePanel.StuckInTheMud","PNG/07-Resizable-Skins/green-normal.png"],["StarterGui.MudHUD.Main.Top","PNG/01-Empty-Panels/MudHUD-Top.png"],["StarterGui.MudHUD.Main.Top.Team","PNG/05-Favourite-Buttons-Blank/team-blue-status.png"],["StarterGui.MudHUD.Main.Controls.Meter","PNG/07-Resizable-Skins/panel-normal.png"],["StarterGui.MudHUD.Main.Controls.Meter.Track","PNG/04-Meter-Parts/stamina-track.png"],["StarterGui.MudHUD.Main.Controls.Mud","PNG/05-Favourite-Buttons-Blank/mud-slot.png"],["StarterGui.MudHUD.Main.Controls.Heat","PNG/05-Favourite-Buttons-Blank/heat-slot.png"],["StarterGui.MudHUD.Main.Controls.Fire","PNG/05-Favourite-Buttons-Blank/splat.png"],["StarterGui.MudHUD.Main.Controls.Sprint","PNG/05-Favourite-Buttons-Blank/sprint-wide.png"],["StarterGui.MudHUD.Main.Frozen","PNG/07-Resizable-Skins/panel-normal.png"],["StarterGui.MudHUD.Main.Frozen.RescueTrack","PNG/04-Meter-Parts/stamina-track.png"],["StarterGui.MudHUD.Main.Results","PNG/01-Empty-Panels/MudHUD-Results.png"],["StarterGui.MudHUD.Main.DesktopControls.Meter","PNG/07-Resizable-Skins/panel-normal.png"],["StarterGui.MudHUD.Main.DesktopControls.Meter.Track","PNG/04-Meter-Parts/stamina-track.png"],["StarterGui.MudHUD.Main.DesktopControls.Mud","PNG/05-Favourite-Buttons-Blank/mud-slot.png"],["StarterGui.MudHUD.Main.DesktopControls.Heat","PNG/05-Favourite-Buttons-Blank/heat-slot.png"],["StarterGui.MudHUD.Main.DesktopControls.Fire","PNG/05-Favourite-Buttons-Blank/splat.png"],["StarterGui.MudHUD.Main.DesktopControls.Sprint","PNG/05-Favourite-Buttons-Blank/sprint-wide.png"],["StarterGui.MudHUD.ColourToggle","PNG/05-Favourite-Buttons-Blank/team-toggle.png"],["StarterGui.MudHUD.ColourPicker","PNG/01-Empty-Panels/MudHUD-ColourPicker.png"],["StarterGui.MudHUD.ColourPicker.Close","PNG/05-Favourite-Buttons-Blank/close.png"],["StarterGui.MudHUD.ColourPicker.Red","PNG/05-Favourite-Buttons-Blank/team-red.png"],["StarterGui.MudHUD.ColourPicker.Blue","PNG/05-Favourite-Buttons-Blank/team-blue.png"],["StarterGui.MudHUD.ColourPicker.Green","PNG/05-Favourite-Buttons-Blank/team-green.png"],["StarterGui.MudHUD.ColourPicker.Black","PNG/05-Favourite-Buttons-Blank/team-black.png"]]}]==])
local issues = {}
local summary = { controllers = 0, sourcesCompiled = 0, planPaths = 0, legacyNodes = 0, blankShopSlots = 0, meterGradients = 0, imageMeterGradients = 0, visibleGlyphs = 0, imageAssets = 0, previewBackgrounds = 0, boards = 0, rowSkins = 0, rankSkins = 0, avatarBorders = 0 }

local function issue(code, path, detail)
	table.insert(issues, { code = code, path = path, detail = detail })
end

local function resolve(path)
	local current = game
	for segment in string.gmatch(path, "[^.]+") do current = current and current:FindFirstChild(segment) end
	return current
end

local function requireObject(path, className)
	local object = resolve(path)
	if not object then issue("missing", path, "Expected " .. className) return nil end
	if not object:IsA(className) then issue("class", path, object.ClassName .. " must remain " .. className) return nil end
	return object
end

local function compile(path)
	local object = requireObject(path, "LuaSourceContainer")
	if not object then return end
	local ok, chunk, errorText = pcall(loadstring, object.Source, "=" .. path)
	if not ok or typeof(chunk) ~= "function" then
		issue("compile", path, tostring(not ok and chunk or errorText))
	else
		summary.sourcesCompiled += 1
	end
end

local roots = { "BritishBulldogHUD", "TagHUD", "MudHUD", "PlaygroundShell", "PlaygroundAdminPanel" }
for _, name in ipairs(roots) do
	local path = "StarterGui." .. name
	local gui = requireObject(path, "ScreenGui")
	if gui then
		local controller = requireObject(path .. ".ReusableSkinController", "LocalScript")
		if controller then
			summary.controllers += 1
			compile(controller:GetFullName())
			if not controller.Enabled then issue("disabledController", controller:GetFullName(), "Skin behavior will not bind") end
			if not controller.Sandboxed then issue("sandbox", controller:GetFullName(), "Expected UI-only sandbox") end
			if string.find(tostring(controller.Capabilities), "Input", 1, true) then issue("capability", controller:GetFullName(), "Cosmetic controller unexpectedly has Input capability") end
			local source = controller.Source
			for _, property in ipairs({ "Position", "Size", "AnchorPoint" }) do
				if string.find(source, "%.%s*" .. property .. "%s*=") then issue("runtimeLayoutWrite", controller:GetFullName(), property) end
			end
			if string.find(source, "UserInputService", 1, true) or string.find(source, "InputObject", 1, true) then issue("globalInput", controller:GetFullName(), "Expected GuiButton-only cosmetic events") end
		end
	end
end
for _, path in ipairs({ "ReplicatedStorage.PlaygroundCatalog", "ServerScriptService.PlaygroundEconomyService", "StarterGui.PlaygroundShell.Controller" }) do compile(path) end

for _, object in ipairs(StarterGui:GetDescendants()) do
	if object.Name == "UserArtwork" or object.Name == "TextlessSkin" or object.Name == "UserArtworkController" then
		summary.legacyNodes += 1
		issue("legacyArtwork", object:GetFullName(), "Obsolete artwork or binding remains")
	end
end
for _, entry in ipairs(contracts.paths) do
	local object = requireObject(entry[1], entry[2])
	if object then summary.planPaths += 1 end
end

local function imageIsSet(image, path)
	if not image or not image:IsA("ImageLabel") then issue("missingImage", path, "Expected authored ImageLabel") return false end
	if image.Image == "" then issue("emptyImage", path, "No artwork content ID") return false end
	return true
end

for _, entry in ipairs(contracts.backgrounds) do
	local target = resolve(entry[1])
	if target then
		if target:IsA("ViewportFrame") then
			local image = target.Parent:FindFirstChild(target.Name .. "ReusableSkin")
			if imageIsSet(image, entry[1] .. " background sibling") then
				summary.previewBackgrounds += 1
				if image.ZIndex >= target.ZIndex then issue("previewLayer", entry[1], "Artwork must render below the live viewport") end
				if image:GetAttribute("UISkinTargetPath") ~= entry[1] then issue("previewBinding", entry[1], "Background metadata does not identify its viewport") end
			end
			if target.BackgroundTransparency ~= 1 then issue("previewBackground", entry[1], "Native viewport background obscures supplied artwork") end
		else
			local image = target:FindFirstChild("ReusableSkin")
			if imageIsSet(image, entry[1] .. ".ReusableSkin") and image:GetAttribute("AssetKey") ~= entry[2] then issue("artworkMapping", entry[1], "Installed artwork differs from final SkinPlan") end
		end
	end
end

local cosmetics = requireObject("ReplicatedStorage.PlaygroundCosmeticAssets", "Folder")
if cosmetics and #cosmetics:GetChildren() ~= 0 then issue("cosmeticsRemain", cosmetics:GetFullName(), tostring(#cosmetics:GetChildren()) .. " placeholder assets remain") end
for index = 1, 12 do
	local path = string.format("StarterGui.PlaygroundShell.ShopPanel.Cards.Slot%02d", index)
	local card = requireObject(path, "Frame")
	if card then
		local before = #issues
		if card:GetAttribute("CatalogId") ~= nil then issue("catalogId", path, "Blank slot retains a catalog item") end
		if card:GetAttribute("EmptyShopSlot") ~= true then issue("emptySlotFlag", path, "Expected editable empty slot") end
		local preview = requireObject(path .. ".Preview", "ViewportFrame")
		local world = requireObject(path .. ".Preview.World", "WorldModel")
		if world and #world:GetChildren() ~= 0 then issue("previewContent", path, "Placeholder preview objects remain") end
		if preview and not preview.CurrentCamera then issue("previewCamera", path, "Editable viewport has no camera") end
		for _, name in ipairs({ "Name", "Price", "Category", "Action", "Try" }) do
			local object = card:FindFirstChild(name)
			if object then
				if (object:IsA("TextLabel") or object:IsA("TextButton")) and object.Text ~= "" then issue("placeholderText", object:GetFullName(), "Blank slot text is not empty") end
				local caption = object:FindFirstChild("LiveCaption")
				if caption and caption:IsA("TextLabel") and caption.Text ~= "" then issue("placeholderCaption", caption:GetFullName(), "Blank slot overlay is not empty") end
				if (name == "Action" or name == "Try") and object:IsA("GuiButton") and (object.Active or object.Visible) then issue("blankSlotAction", object:GetFullName(), "Empty slot action should be hidden and inactive") end
			end
		end
		if #issues == before then summary.blankShopSlots += 1 end
	end
end

local function sameTransparency(a, b)
	local first, second = a.Keypoints, b.Keypoints
	if #first ~= #second then return false end
	for index, point in ipairs(first) do
		local other = second[index]
		if math.abs(point.Time - other.Time) > 0.000001 or math.abs(point.Value - other.Value) > 0.000001 or math.abs(point.Envelope - other.Envelope) > 0.000001 then return false end
	end
	return true
end
for _, entry in ipairs(contracts.meters) do
	local fill = resolve(entry[1])
	local source = requireObject(entry[1] .. ".Progress", "UIGradient")
	if source then summary.meterGradients += 1 end
	if fill and entry[2] == "PreserveNativeFill" then
		if fill.BackgroundTransparency ~= 0 then issue("nativeMeter", entry[1], "Role/rescue fill is invisible") end
	elseif fill and source then
		local gradient = requireObject(entry[1] .. ".ReusableSkin.Progress", "UIGradient")
		if gradient then
			summary.imageMeterGradients += 1
			if not sameTransparency(source.Transparency, gradient.Transparency) then issue("meterGradient", entry[1], "Image progress does not match original source gradient") end
		end
	end
end

local function visibleText(label)
	if label.Text == "" or label.TextTransparency >= 1 or label:GetAttribute("UISkinHiddenText") == true then return false end
	local current = label
	while current and current ~= game do
		if current:IsA("GuiObject") and not current.Visible then return false end
		if current:IsA("LayerCollector") and not current.Enabled then return false end
		current = current.Parent
	end
	return true
end
local function inspectGlyphs(root)
	for _, object in ipairs(root:GetDescendants()) do
		if (object:IsA("TextLabel") or object:IsA("TextButton")) and visibleText(object) then
			summary.visibleGlyphs += 1
			local outline = object:FindFirstChild("TextOutline")
			if not outline or not outline:IsA("UIStroke") or not outline.Enabled or outline.Transparency >= 1 or outline.ApplyStrokeMode ~= Enum.ApplyStrokeMode.Contextual then issue("glyphOutline", object:GetFullName(), "Visible text needs an enabled contextual TextOutline") end
		end
		if object:IsA("ImageLabel") and (object:GetAttribute("AssetKey") or object:GetAttribute("UISkinAssetKey")) then
			summary.imageAssets += 1
			imageIsSet(object, object:GetFullName())
		end
	end
end
inspectGlyphs(StarterGui)

for _, name in ipairs({ "HighestLevel", "MostWins" }) do
	local path = "Workspace.Playground Lobby.Leaderboards." .. name .. ".Face.Display"
	local gui = requireObject(path, "SurfaceGui")
	if gui then
		summary.boards += 1
		imageIsSet(gui:FindFirstChild("LeaderboardBoardArtwork"), path .. ".LeaderboardBoardArtwork")
		local header = requireObject(path .. ".Header", "Frame")
		if header then imageIsSet(header:FindFirstChild("LeaderboardHeaderArtwork"), header:GetFullName() .. ".LeaderboardHeaderArtwork") end
		for index = 1, 11 do
			local rowPath = path .. (index <= 10 and string.format(".Body.Row%02d", index) or ".Templates.RowTemplate")
			local row = requireObject(rowPath, "Frame")
			if row then
				if imageIsSet(row:FindFirstChild("LeaderboardRowArtwork"), rowPath .. ".LeaderboardRowArtwork") then summary.rowSkins += 1 end
				local badge = requireObject(rowPath .. ".RankBadge", "Frame")
				if badge and imageIsSet(badge:FindFirstChild("LeaderboardRankArtwork"), rowPath .. ".RankBadge.LeaderboardRankArtwork") then summary.rankSkins += 1 end
				local avatar = requireObject(rowPath .. ".Avatar", "ImageLabel")
				if avatar and imageIsSet(avatar:FindFirstChild("LeaderboardAvatarBorder"), rowPath .. ".Avatar.LeaderboardAvatarBorder") then summary.avatarBorders += 1 end
			end
		end
		inspectGlyphs(gui)
	end
end

return HttpService:JSONEncode({ ok = #issues == 0, mode = "Edit static audit", gameplayTested = false, summary = summary, issues = issues })
