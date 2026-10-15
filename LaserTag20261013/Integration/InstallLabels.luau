assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local function resolve(path) local v=game for name in path:gmatch("[^.]+") do v=assert(v:FindFirstChild(name),path) end return v end
local backup=game.ServerStorage:FindFirstChild("LaserTagIntegrationBackup20261013")
if not backup then backup=Instance.new("Folder") backup.Name="LaserTagIntegrationBackup20261013" backup.Parent=game.ServerStorage end

local edits={{path="StarterGui.PlaygroundShell.ShopPanel.Cards.Slot06.Price",before=[==[25 Mud wins]==],after=[==[25 Laser Tag wins]==]},
{path="StarterGui.PlaygroundShell.ShopPanel.Cards.Slot07.Price",before=[==[50 Mud wins]==],after=[==[50 Laser Tag wins]==]},
{path="StarterGui.PlaygroundShell.VotePanel.Choices.StuckInTheMud.Button.LiveCaption",before=[==[STUCK IN
THE MUD]==],after=[==[LASER TAG]==]},
{path="StarterGui.PlaygroundShell.CompactVotePanel.Choices.StuckInTheMud.Button.LiveCaption",before=[==[STUCK IN
THE MUD]==],after=[==[LASER TAG]==]},
{path="StarterGui.PlaygroundAdminPanel.Panel.Body.Content.StuckInTheMud.Title",before=[==[STUCK IN THE MUD]==],after=[==[LASER TAG]==]},
{path="StarterGui.PlaygroundAdminPanel.Panel.Body.Content.StuckInTheMud.MudShooter",before=[==[SOLO MUD GUN]==],after=[==[SOLO RED TEAM]==]},
{path="StarterGui.PlaygroundAdminPanel.Panel.Body.Content.StuckInTheMud.MudShooter.LiveCaption",before=[==[SOLO MUD GUN]==],after=[==[SOLO RED TEAM]==]},
{path="StarterGui.PlaygroundAdminPanel.Panel.Body.Content.StuckInTheMud.MudMedic",before=[==[SOLO RESCUE]==],after=[==[SOLO BLUE TEAM]==]},
{path="StarterGui.PlaygroundAdminPanel.Panel.Body.Content.StuckInTheMud.MudMedic.LiveCaption",before=[==[SOLO RESCUE]==],after=[==[SOLO BLUE TEAM]==]},
{path="StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.StuckInTheMud.Title",before=[==[STUCK IN THE MUD]==],after=[==[LASER TAG]==]},
{path="StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.StuckInTheMud.MudShooter",before=[==[SOLO MUD GUN]==],after=[==[SOLO RED TEAM]==]},
{path="StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.StuckInTheMud.MudShooter.LiveCaption",before=[==[SOLO MUD GUN]==],after=[==[SOLO RED TEAM]==]},
{path="StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.StuckInTheMud.MudMedic",before=[==[SOLO RESCUE]==],after=[==[SOLO BLUE TEAM]==]},
{path="StarterGui.PlaygroundAdminPanel.CompactPanel.Body.Content.StuckInTheMud.MudMedic.LiveCaption",before=[==[SOLO RESCUE]==],after=[==[SOLO BLUE TEAM]==]},
{path="StarterGui.PlaygroundAdminPanel.AdminHub.Pages.Rounds.StuckInTheMud.Title",before=[==[STUCK IN THE MUD]==],after=[==[LASER TAG]==]},
{path="StarterGui.PlaygroundAdminPanel.AdminHub.Pages.Rounds.StuckInTheMud.MudShooter",before=[==[SOLO MUD GUN]==],after=[==[SOLO RED TEAM]==]},
{path="StarterGui.PlaygroundAdminPanel.AdminHub.Pages.Rounds.StuckInTheMud.MudShooter.LiveCaption",before=[==[SOLO MUD GUN]==],after=[==[SOLO RED TEAM]==]},
{path="StarterGui.PlaygroundAdminPanel.AdminHub.Pages.Rounds.StuckInTheMud.MudMedic",before=[==[SOLO RESCUE]==],after=[==[SOLO BLUE TEAM]==]},
{path="StarterGui.PlaygroundAdminPanel.AdminHub.Pages.Rounds.StuckInTheMud.MudMedic.LiveCaption",before=[==[SOLO RESCUE]==],after=[==[SOLO BLUE TEAM]==]},
{path="Workspace.Playground Lobby.VotingAlcove.StuckInTheMudStand.ChoiceCardFace.GameName.Label",before=[==[Stuck in the Mud]==],after=[==[Laser Tag]==]}}
for _,edit in edits do assert(resolve(edit.path).Text==edit.before,"Label changed: "..edit.path) end
for _,edit in edits do local object=resolve(edit.path) local saved=Instance.new("StringValue") saved.Name=edit.path saved.Value=edit.before saved.Parent=backup object.Text=edit.after end
return {labelsUpdated=#edits}
