assert(not game:GetService("RunService"):IsRunning(),"Stop Play before editing voting properties")
assert(game.PlaceId==95034648955135,"Wrong experience")
local shell=game:GetService("StarterGui").PlaygroundShell
for _,panel in {shell.VotePanel,shell.CompactVotePanel}do
	assert(panel:GetAttribute("DuckDuckGooseVoting20261010")==true,"Voting UI missing")
	panel.Message.Position=UDim2.new(0,14,1,-29)
	panel.Choices.DuckDuckGoose.Button:SetAttribute("UISkinAssetKey","PNG/07-Resizable-Skins/gold-normal.png")
end
return {panels=2,authoredPropertiesUpdated=true}
