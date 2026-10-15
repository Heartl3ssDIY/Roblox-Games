local originalGame=game
local core=game:GetService("CoreGui")
local gui=game.StarterGui.ArenaSelectGui:Clone();gui.Name="ArenaTeleportVerification";gui.Parent=core
local changed=Instance.new("BindableEvent");local removing=Instance.new("BindableEvent")
local pg={WaitForChild=function() return gui end,GetChildren=function() return {gui} end}
local visitCount,leaveCount=0,0
local stubs={
 ArenaCatalog=assert(loadstring(game.ReplicatedStorage.ArenaCatalog.Source))(),
 PlayerData={arenaProgress=function() return {progressWins=0,claimed={}} end,dailyWinRewards=function() return {} end,pendingDailyPack=function() return nil end,dailyWinPacksRemaining=function() return 4 end,Changed=changed.Event},
 ArenaUIAssets={Claim="rbxassetid://0",Battle=gui.Board.Action.Image},
 ArenaTravelClient={visit=function() visitCount+=1;return true end,leave=function() leaveCount+=1;return true end,restore=function() end},
 ModePickerUI={open=function() end,close=function() end},PackShopEffects={bind=function() end,play=function() end},
 Loadout={count=function() return 4 end},PackOpening={},PackReveal={}
}
local fakePlayers={LocalPlayer={PlayerGui=pg,CharacterRemoving=removing.Event}}
local fakeGame={GetService=function(_,name) if name=="Players" then return fakePlayers end return originalGame:GetService(name) end}
local f=assert(loadstring(game.ReplicatedStorage.ArenaSelectionUI.Source))
setfenv(f,setmetatable({game=fakeGame,require=function(m) assert(stubs[m.Name],"Unexpected require: "..m.Name);return stubs[m.Name] end,task={spawn=function() end,delay=function() end}},{__index=getfenv()}))
local ui=f();ui.open(pg)
for i=1,9 do
 assert(gui.Board.Title.Text==stubs.ArenaCatalog.get(i).displayName)
 assert(gui.Board.ArenaNumber.Label.Text=="Arena "..i)
 assert(gui.Board.Teleport.Visible==(i>1))
 if i>1 then
 assert(ui.teleport());assert(gui.ReturnToLobby.Visible and not gui.Board.Visible)
 ui.returnFromVisit();assert(not gui.ReturnToLobby.Visible and gui.Board.Visible)
 end
 ui.nextArena()
end
assert(gui.Board.Title.Text=="Tenkaichi");assert(visitCount==8 and leaveCount==8)
for _=1,6 do ui.nextArena() end
gui:SetAttribute("VerificationResult","9 labels, 8 visit/return flows, wraparound passed")
changed:Destroy();removing:Destroy()
return gui:GetAttribute("VerificationResult")