local RS=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local GuiService=game:GetService("GuiService")
local UnitData=require(RS:WaitForChild("UnitData"))
local UnitViewport=require(RS:WaitForChild("UnitViewport"))
local PlayerData=require(RS:WaitForChild("PlayerData"))
local MatchResultsUI={}
local PACK_IMAGES={
    bronze="rbxassetid://73606499921543", -- Common pack art already used by PackShopGui.
    silver="rbxassetid://118796124465923",
    gold="rbxassetid://107366517958284",
}
local connections={}
local generation=0
local function resolveOverlay(subject)
    if subject.Name=="RewardOverlay" then return subject end
    if subject:FindFirstChild("RewardOverlay") then return subject.RewardOverlay end
    return subject:WaitForChild("ArenaHUD"):WaitForChild("RewardOverlay")
end
local function connect(signal,fn) local c=signal:Connect(fn); table.insert(connections,c); return c end
local function clear()
    generation+=1
    for _,c in ipairs(connections) do c:Disconnect() end
    table.clear(connections)
end
local function imageFor(o,won)
    local asset=o:GetAttribute(won and "VictoryImage" or "DefeatImage")
    if asset then o.Image=asset end
end
local function pct(n,max)
    if max<=0 then return 0 end
    return math.clamp(n/max,0,1)
end
local function animateGroup(group,delaySeconds,token)
    group.GroupTransparency=1
    task.delay(delaySeconds,function()
        if token~=generation or not group.Parent then return end
        group.Visible=true
        if GuiService.ReducedMotionEnabled then group.GroupTransparency=0; return end
        TweenService:Create(group,TweenInfo.new(.33,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{GroupTransparency=0}):Play()
    end)
end
local function showStageAwards(flow,data,token)
    if token~=generation then return end
    local mastery=flow.StageMastery
    local awards=flow.StageAwards
    mastery.Visible=false
    awards.Visible=true
    local p=awards.Background
    imageFor(p,data.playerWon)
    p.CoinBalance.Text=tostring(PlayerData.coins())
    p.ChipsStrip.Balance.Text=tostring(PlayerData.masteryChips())
    p.PassXP.Visible=data.passXp~=nil
    if data.passXp~=nil then p.PassXP.Text="+"..tostring(data.passXp).." PASS XP" end
    local trophyDelta=data.trophyDelta
    if trophyDelta==nil then trophyDelta=data.playerWon and 10 or -4 end
    p.TrophyDelta.Text=(trophyDelta>=0 and "+" or "")..tostring(trophyDelta)
    local bonus={}
    if (data.milestoneCoins or 0)>0 then table.insert(bonus,"+"..tostring(data.milestoneCoins).." MILESTONE COINS") end
    if (data.milestoneGems or 0)>0 then table.insert(bonus,"+"..tostring(data.milestoneGems).." DIAMONDS") end
    p.MilestoneBonus.Text=table.concat(bonus,"  •  ")
    p.MilestoneBonus.Visible=#bonus>0
    for index=1,3 do
        local card=p.RewardCards["Card"..index]
        imageFor(card.Background,data.playerWon)
        card.Icon.Visible=index~=1
        card.UnitModel.Visible=false
        if index==1 then
            if data.playerWon then
                local pack=tostring(data.dailyPack or "")
                card.Icon.Image=PACK_IMAGES[pack] or ""
                card.Icon.Visible=PACK_IMAGES[pack]~=nil
                card.Value.Text=""
                card.Caption.Text=data.dailyPack and (string.upper(pack=="bronze" and "common" or pack).." PACK") or "DAILY PACKS COMPLETE"
            else
                card.Value.Text=""
                card.Caption.Text="NO PACK"
            end
        elseif index==2 then
            card.Value.Text="+"..tostring((data.coins or 0)+(data.milestoneCoins or 0))
            card.Caption.Text="COINS"
        else
            card.Value.Text="+"..tostring(data.masteryChips or 0)
            card.Caption.Text="MASTERY CHIPS"
        end
        animateGroup(card,(index-1)*.28,token)
    end
end
function MatchResultsUI.hide(playerGui)
    clear()
    local overlay=playerGui and resolveOverlay(playerGui)
    local flow=overlay and overlay:FindFirstChild("ResultFlow")
    if flow then flow.Visible=false end
    local legacy=overlay and overlay:FindFirstChild("RewardPanel")
    if legacy then legacy.Visible=true end
    if overlay then overlay.Visible=false end
end
function MatchResultsUI.show(playerGui,data,onLobby,onNextMatch)
    assert(playerGui and data,"MatchResultsUI.show requires PlayerGui and result data")
    local overlay=resolveOverlay(playerGui)
    clear()
    local token=generation
    local flow=overlay:WaitForChild("ResultFlow")
    local legacy=overlay:FindFirstChild("RewardPanel")
    if legacy then legacy.Visible=false end
    overlay.Visible=true
    flow.Visible=true
    flow.StageMastery.Visible=true
    flow.StageAwards.Visible=false
    local p=flow.StageMastery.Background
    imageFor(p,data.playerWon)
    local slots=data.unitMastery or {}
    for index=1,4 do
        local slot=p.UnitCards["Card"..index]
        local item=slots[index]
        slot.Visible=item~=nil
        if item then
            local info=UnitData.get(item.id)
            local name=item.name or (info and info.name) or tostring(item.id)
            slot.UnitCard.UnitName.Text=name
            local model=info and info.model
            if model then UnitViewport.show(slot.UnitCard.UnitModel,model) else UnitViewport.clear(slot.UnitCard.UnitModel) end
            local gained=tonumber(item.gained) or 0
            slot.UnitCard.Gain.Visible=(gained==10 or gained==4)
            imageFor(slot.UnitCard.Gain,data.playerWon)
            slot.UnitCard.GainValue.Text=(gained==10 or gained==4) and "" or "+"..tostring(gained)
            local rarity=item.rarity or (info and info.rarity) or "Common"
            local threshold=PlayerData.masteryThreshold(rarity)
            local current=PlayerData.masteryFor(item.id)
            local fill=slot.MasteryTrack.Fill
            fill.Size=UDim2.fromScale(pct(math.max(0,current-gained),threshold),1)
            slot.MasteryValue.Text=tostring(current).." / "..tostring(threshold)
            local spent=false
            slot.Boost.Active=true; slot.Boost.AutoButtonColor=true
            slot.Boost.ImageTransparency=0; slot.BoostState.Text=""
            connect(slot.Boost.Activated,function()
                if token~=generation or spent then return end
                if PlayerData.masteryChips()<1 then
                    slot.BoostState.Text="NEED 1 MASTERY CHIP"
                    return
                end
                PlayerData.addMasteryChips(-1)
                PlayerData.addMasteryPoints(item.id,10)
                spent=true
                local total=PlayerData.masteryFor(item.id)
                slot.MasteryValue.Text=tostring(total).." / "..tostring(threshold)
                slot.BoostState.Text="BOOSTED +10"
                slot.Boost.Active=false; slot.Boost.AutoButtonColor=false; slot.Boost.ImageTransparency=.48
                if GuiService.ReducedMotionEnabled then fill.Size=UDim2.fromScale(pct(total,threshold),1)
                else TweenService:Create(fill,TweenInfo.new(.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.fromScale(pct(total,threshold),1)}):Play() end
            end)
            animateGroup(slot,(index-1)*.65,token)
            task.delay((index-1)*.65+.48,function()
                if token~=generation or not fill.Parent then return end
                local goal=UDim2.fromScale(pct(current,threshold),1)
                if GuiService.ReducedMotionEnabled then fill.Size=goal
                else TweenService:Create(fill,TweenInfo.new(.65,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=goal}):Play() end
                if model then UnitViewport.reveal(slot.UnitCard.UnitModel,.55) end
            end)
        end
    end
    connect(p.Continue.Activated,function() showStageAwards(flow,data,token) end)
    local a=flow.StageAwards.Background
    connect(a.BackLobby.Activated,function()
        if token~=generation then return end
        MatchResultsUI.hide(playerGui)
        overlay.Visible=false
        if onLobby then onLobby() end
    end)
    connect(a.Continue.Activated,function()
        if token~=generation then return end
        MatchResultsUI.hide(playerGui)
        overlay.Visible=false
        if onNextMatch then onNextMatch() end
    end)
    return flow
end
return MatchResultsUI

