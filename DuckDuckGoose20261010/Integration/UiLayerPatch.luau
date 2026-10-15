assert(not game:GetService("RunService"):IsRunning(),"Stop Play before correcting voting layers")
assert(game.PlaceId==95034648955135,"Wrong experience")
local shell=game:GetService("StarterGui").PlaygroundShell
local panels={shell.VotePanel,shell.CompactVotePanel}
local ids={"BritishBulldog","TagYoureIt","StuckInTheMud","HideAndSeek","DuckDuckGoose"}
for _,panel in panels do
	assert(panel:GetAttribute("DuckDuckGooseVoting20261010")==true and panel.Choices:IsA("ScrollingFrame"),"Voting row missing")
	assert(panel.ReusableSkin.ZIndex<9,"Voting background unexpectedly covers layer9")
	for _,id in ids do assert(panel.Choices[id]:IsA("Frame") and panel.Choices[id].Button:IsA("TextButton"),"Card missing: "..id) end
end
local changed=0
for _,panel in panels do
	panel.Choices.ZIndex=9
	for _,id in ids do panel.Choices[id].ZIndex=9 changed+=1 end
	local hint=panel.ScrollHint
	hint.ZIndex,hint.TextStrokeTransparency=13,1
	hint.Text="SWIPE OR SCROLL FOR ALL 5 GAMES"
	for _,child in hint:GetDescendants()do if child:IsA("UIStroke")or child:IsA("UITextSizeConstraint")then child:Destroy()end end
	hint.Font=Enum.Font.GothamMedium
	hint.TextTruncate,hint.TextWrapped,hint.TextScaled=Enum.TextTruncate.None,false,false
	hint.TextSize=13
	panel:SetAttribute("DuckDuckGooseVotingLayer20261010",true)
end
return {cardsAboveBackground=changed,hintsReadable=true,positionsPreserved=true}
