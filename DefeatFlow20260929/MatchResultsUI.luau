local RS=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local GuiService=game:GetService("GuiService")
local UnitData=require(RS:WaitForChild("UnitData"))
local UnitViewport=require(RS:WaitForChild("UnitViewport"))
local PlayerData=require(RS:WaitForChild("PlayerData"))
local ProfileBridge=require(RS:WaitForChild("ProfileClientBridge"))
local PityConfig=require(RS:WaitForChild("PityRewardConfig"))
local Feedback=require(RS:WaitForChild("PackShopEffects"))
local MatchSettings=require(RS:WaitForChild("MatchSettings"))
local MatchResultsUI={}
local PACK_IMAGES={
    bronze="rbxassetid://73606499921543", -- Common pack art already used by PackShopGui.
    silver="rbxassetid://118796124465923",
    gold="rbxassetid://107366517958284",
}
local connections={}
local generation=0
local masteryTweens={}
local feedbackBindings=setmetatable({},{__mode="k"})
local activeFeedbackReset
local function resolveOverlay(subject)
    if subject.Name=="RewardOverlay" then return subject end
    if subject:FindFirstChild("RewardOverlay") then return subject.RewardOverlay end
    return subject:WaitForChild("ArenaHUD"):WaitForChild("RewardOverlay")
end
local function connect(signal,fn) local c=signal:Connect(fn); table.insert(connections,c); return c end
local function clear()
    generation+=1
    if activeFeedbackReset then activeFeedbackReset(); activeFeedbackReset=nil end
    for fill,tween in pairs(masteryTweens) do tween:Cancel(); masteryTweens[fill]=nil end
    for _,c in ipairs(connections) do c:Disconnect() end
    table.clear(connections)
end
local function bindFeedback(flow)
    if feedbackBindings[flow] then return feedbackBindings[flow] end
    local states={}
    local bound={}
    local function listen(signal,callback)
        table.insert(bound,signal:Connect(callback))
    end
    local function available(button)
        if not button.Active or not button.Interactable then return false end
        local current=button
        while current do
            if current:IsA("GuiObject") and not current.Visible then return false end
            if current:IsA("ScreenGui") then return current.Enabled end
            current=current.Parent
        end
        return false
    end
    local function visual(state,scaleValue,highlighted)
        if state.tween then state.tween:Cancel(); state.tween=nil end
        local enabled=MatchSettings.effectsEnabled()
        local target=(enabled and not GuiService.ReducedMotionEnabled) and scaleValue or 1
        if target==1 or GuiService.ReducedMotionEnabled then
            state.scale.Scale=target
        else
            state.tween=TweenService:Create(state.scale,TweenInfo.new(.13,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=target})
            state.tween:Play()
        end
        if state.button:IsA("ImageButton") then
            state.button.ImageColor3=enabled and highlighted and Color3.fromRGB(255,245,219) or state.color
        elseif state.stroke then
            state.stroke.Thickness=enabled and highlighted and state.thickness+.5 or state.thickness
        end
    end
    local function reset(state)
        state.pointer=false
        state.selected=false
        state.hovered=false
        state.pressToken+=1
        visual(state,1,false)
    end
    for _,button in ipairs(flow:GetDescendants()) do
        if button:IsA("GuiButton") then
            local scale=button:FindFirstChild("ResultFeedbackScale")
            if not scale then
                scale=Instance.new("UIScale")
                scale.Name="ResultFeedbackScale"
                scale.Parent=button
            end
            local stroke=button:FindFirstChildOfClass("UIStroke")
            local state={button=button,scale=scale,stroke=stroke,color=button:IsA("ImageButton") and button.ImageColor3 or nil,thickness=stroke and stroke.Thickness or 0,pointer=false,selected=false,hovered=false,pressToken=0}
            table.insert(states,state)
            local function hover(source,on)
                state[source]=on
                local active=state.pointer or state.selected
                if active and not state.hovered and available(button) then
                    state.hovered=true
                    Feedback.play("Hover")
                    visual(state,1.025,true)
                elseif not active and state.hovered then
                    reset(state)
                end
            end
            listen(button.MouseEnter,function() hover("pointer",true) end)
            listen(button.MouseLeave,function() hover("pointer",false) end)
            listen(button.SelectionGained,function() hover("selected",true) end)
            listen(button.SelectionLost,function() hover("selected",false) end)
            listen(button.Activated,function()
                if not available(button) then return end
                Feedback.play("Click")
                if not MatchSettings.effectsEnabled() or GuiService.ReducedMotionEnabled then return end
                state.pressToken+=1
                local token=state.pressToken
                visual(state,.975,true)
                task.delay(.09,function()
                    if token~=state.pressToken then return end
                    if available(button) then visual(state,state.hovered and 1.025 or 1,state.hovered) else reset(state) end
                end)
            end)
        end
    end
    local function resetAll()
        for _,state in ipairs(states) do reset(state) end
    end
    feedbackBindings[flow]=resetAll
    listen(flow.Destroying,function()
        resetAll()
        for _,c in ipairs(bound) do c:Disconnect() end
        feedbackBindings[flow]=nil
    end)
    return resetAll
end
local function imageFor(o,won)
    local asset=o:GetAttribute(won and "VictoryImage" or "DefeatImage")
    if asset then o.Image=asset end
end
local MASTERY_THRESHOLDS=assert(PlayerData.MASTERY_LEVEL_THRESHOLDS,"Global mastery thresholds are required")
local MASTERY_CAP=MASTERY_THRESHOLDS[#MASTERY_THRESHOLDS]

local function clampPoints(value)
    return math.clamp(math.floor(tonumber(value) or 0),0,MASTERY_CAP)
end

local function masteryFrame(id,total)
    total=clampPoints(total)
    if total==clampPoints(PlayerData.masteryFor(id)) then
        local progress,needed,level=PlayerData.masteryProgress(id)
        local nextThreshold=PlayerData.masteryNextThreshold(id)
        return nextThreshold and math.clamp(progress/math.max(needed,1),0,1) or 1,nextThreshold,level
    end
    for level=#MASTERY_THRESHOLDS,1,-1 do
        local floor=MASTERY_THRESHOLDS[level]
        if total>=floor then
            local nextThreshold=MASTERY_THRESHOLDS[level+1]
            if not nextThreshold then return 1,nil,level end
            return math.clamp((total-floor)/(nextThreshold-floor),0,1),nextThreshold,level
        end
    end
    return 0,MASTERY_THRESHOLDS[2],1
end

local function setMastery(slot,id,total)
    total=clampPoints(total)
    local fraction,nextThreshold=masteryFrame(id,total)
    slot.MasteryTrack.Fill.Size=UDim2.fromScale(fraction,1)
    slot.MasteryValue.Text=nextThreshold and (tostring(total).." / "..tostring(nextThreshold)) or "LV 10 MAX"
end

local function animateMastery(slot,id,fromPoints,toPoints,duration,token,onComplete)
    fromPoints=clampPoints(fromPoints)
    toPoints=clampPoints(toPoints)
    setMastery(slot,id,fromPoints)
    if toPoints<=fromPoints or GuiService.ReducedMotionEnabled then
        setMastery(slot,id,toPoints)
        if onComplete then onComplete() end
        return
    end
    task.spawn(function()
        local fill=slot.MasteryTrack.Fill
        local totalGain=toPoints-fromPoints
        local cursor=fromPoints
        local function tweenFill(fraction,seconds)
            if token~=generation or not fill.Parent then return false end
            local previous=masteryTweens[fill]
            if previous then previous:Cancel() end
            local tween=TweenService:Create(fill,TweenInfo.new(math.max(.05,seconds),Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.fromScale(fraction,1)})
            masteryTweens[fill]=tween
            tween:Play()
            local playback=tween.Completed:Wait()
            if masteryTweens[fill]==tween then masteryTweens[fill]=nil end
            return playback==Enum.PlaybackState.Completed and token==generation and fill.Parent~=nil
        end
        for level=2,#MASTERY_THRESHOLDS do
            local threshold=MASTERY_THRESHOLDS[level]
            if threshold>cursor and threshold<=toPoints then
                if not tweenFill(1,duration*(threshold-cursor)/totalGain) then return end
                cursor=threshold
                setMastery(slot,id,cursor)
            end
        end
        if toPoints>cursor then
            local fraction=masteryFrame(id,toPoints)
            if not tweenFill(fraction,duration*(toPoints-cursor)/totalGain) then return end
        end
        setMastery(slot,id,toPoints)
        if onComplete then onComplete() end
    end)
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
    if feedbackBindings[flow] then feedbackBindings[flow]() end
    local mastery=flow.StageMastery
    local awards=flow.StageAwards
    mastery.Visible=false
    flow.StagePity.Visible=false
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
                local pity=data.pityReward
                if pity and pity.kind=="unitXp" then
                    local info=UnitData.get(pity.unitId)
                    if info then
                        card.UnitModel.Visible=true
                        UnitViewport.show(card.UnitModel,info.model)
                    end
                    card.Value.Text="+"..tostring(pity.amount or 0)
                    card.Caption.Text=(info and string.upper(info.name) or "UNIT").." XP"
                elseif pity and pity.kind=="masteryChips" then
                    card.Icon.Visible=true
                    card.Icon.Image="rbxassetid://82519543150534"
                    card.Value.Text="+"..tostring(pity.amount or 0)
                    card.Caption.Text="PITY MASTERY CHIPS"
                elseif pity and pity.kind=="coins" then
                    card.Icon.Visible=true
                    card.Icon.Image="rbxassetid://94275735623851"
                    card.Value.Text="+"..tostring(pity.amount or 0)
                    card.Caption.Text="PITY COINS"
                else
                    card.Value.Text=""
                    card.Caption.Text="NO PITY PICK"
                end
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
function MatchResultsUI.showPity(playerGui,unitIds,onChoice)
    assert(playerGui and type(unitIds)=="table" and type(onChoice)=="function","MatchResultsUI.showPity requires a team and callback")
    local overlay=resolveOverlay(playerGui)
    clear()
    local token=generation
    local flow=overlay:WaitForChild("ResultFlow")
    activeFeedbackReset=bindFeedback(flow)
    local legacy=overlay:FindFirstChild("RewardPanel")
    if legacy then legacy.Visible=false end
    overlay.Visible=true
    flow.Visible=true
    flow.StageMastery.Visible=false
    flow.StageAwards.Visible=false
    flow.StagePity.Visible=true
    local panel=flow.StagePity.Panel
    local choices=panel.Choices
    local picker=panel.UnitPicker
    picker.Visible=false
    panel.Hint.Text="One extra reward after this defeat. Pick one."
    panel.Status.Text=""
    choices.CardUnitXP.Amount.Text="+"..tostring(PityConfig.unitXp).." XP TO ONE UNIT"
    local function setCurrency(button,amount,name)
        button.Active=type(amount)=="number" and amount>0
        button.AutoButtonColor=button.Active
        button.ImageTransparency=button.Active and 0 or .5
        button.Amount.Text=button.Active and ("+"..tostring(amount).." "..name) or "PENDING"
    end
    setCurrency(choices.CardMasteryChips,PityConfig.masteryChips,"CHIPS")
    setCurrency(choices.CardCoins,PityConfig.coins,"COINS")
    local busy=false
    local function submit(choice)
        if busy or token~=generation then return end
        busy=true
        panel.Status.Text="SAVING YOUR PICK..."
        task.spawn(function()
            local called,ok,reason=pcall(onChoice,choice)
            if token~=generation then return end
            if not called then reason="profile request failed"; ok=false end
            if not ok then
                busy=false
                panel.Status.Text="Could not save: "..tostring(reason or "try again")
            end
        end)
    end
    connect(choices.CardUnitXP.Activated,function()
        if busy then return end
        if activeFeedbackReset then activeFeedbackReset() end
        picker.Visible=true
        panel.Hint.Text="Choose an equipped unit for +"..tostring(PityConfig.unitXp).." XP."
        panel.Status.Text=""
    end)
    connect(choices.CardMasteryChips.Activated,function()
        if not choices.CardMasteryChips.Active then return end
        picker.Visible=false
        submit({kind="masteryChips"})
    end)
    connect(choices.CardCoins.Activated,function()
        if not choices.CardCoins.Active then return end
        picker.Visible=false
        submit({kind="coins"})
    end)
    for index=1,4 do
        local button=picker["Unit"..index]
        local id=unitIds[index]
        local unit=id and UnitData.get(id)
        button.Visible=unit~=nil
        if unit then
            button.Text=unit.name
            connect(button.Activated,function() submit({kind="unitXp",unitId=id}) end)
        end
    end
    return flow.StagePity
end

function MatchResultsUI.hide(playerGui)
    clear()
    local overlay=playerGui and resolveOverlay(playerGui)
    local flow=overlay and overlay:FindFirstChild("ResultFlow")
    if flow then flow.StagePity.Visible=false; flow.Visible=false end
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
    activeFeedbackReset=bindFeedback(flow)
    local legacy=overlay:FindFirstChild("RewardPanel")
    if legacy then legacy.Visible=false end
    overlay.Visible=true
    flow.Visible=true
    flow.StagePity.Visible=false
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
            local current=clampPoints(item.afterPoints or PlayerData.masteryFor(item.id))
            local gained=tonumber(item.gained) or 0
            local before=item.beforePoints and clampPoints(item.beforePoints)
                or (current==MASTERY_CAP and current or clampPoints(current-gained))
            before=math.min(before,current)
            local actualGain=current-before
            slot.UnitCard.Gain.Visible=actualGain==10 or actualGain==4
            imageFor(slot.UnitCard.Gain,data.playerWon)
            slot.UnitCard.GainValue.Text=(actualGain==10 or actualGain==4 or actualGain==0) and "" or "+"..tostring(actualGain)
            setMastery(slot,item.id,before)
            local spent=false
            local requesting=false
            local retryable=false
            local introFinished=false
            local visibleCurrent=current
            local function updateBoost()
                local enabled=introFinished and not spent and not requesting and not retryable and visibleCurrent<MASTERY_CAP
                slot.Boost.Active=enabled
                slot.Boost.AutoButtonColor=enabled
                slot.Boost.ImageTransparency=enabled and 0 or .48
                if not retryable and not spent and visibleCurrent>=MASTERY_CAP then slot.BoostState.Text="MAX MASTERY" end
            end
            slot.BoostState.Text=""
            updateBoost()
            connect(slot.Boost.Activated,function()
                if token~=generation or spent or requesting or not introFinished then return end
                if visibleCurrent>=MASTERY_CAP then
                    updateBoost()
                    return
                end
                requesting=true
                slot.BoostState.Text="SAVING BOOST..."
                updateBoost()
                task.spawn(function()
                    local requestOk,response=pcall(ProfileBridge.action,"BoostMastery",item.id)
                    if not requestOk then response={ok=false,error="profile request failed",retryable=true} end
                    if token~=generation or not slot.Parent then return end
                    requesting=false
                    if response and response.ok and type(response.result)=="table" then
                        local result=response.result
                        local beforeBoost=clampPoints(result.beforePoints)
                        local afterBoost=clampPoints(result.afterPoints)
                        spent=true
                        retryable=false
                        visibleCurrent=afterBoost
                        slot.BoostState.Text="BOOSTED +"..tostring(tonumber(result.gained) or (afterBoost-beforeBoost))
                        updateBoost()
                        animateMastery(slot,item.id,beforeBoost,afterBoost,.3,token)
                    else
                        retryable=response and response.retryable==true or false
                        if retryable then
                            slot.BoostState.Text="SAVE PENDING - RETRYING"
                        elseif response and response.error=="not enough mastery chips" then
                            slot.BoostState.Text="NEED 1 MASTERY CHIP"
                        elseif response and response.error=="mastery is at maximum" then
                            visibleCurrent=MASTERY_CAP
                            setMastery(slot,item.id,visibleCurrent)
                            slot.BoostState.Text="MAX MASTERY"
                        else
                            slot.BoostState.Text="BOOST FAILED"
                        end
                        if not retryable and not (response and response.error=="mastery is at maximum") then
                            visibleCurrent=clampPoints(PlayerData.masteryFor(item.id))
                        end
                        updateBoost()
                    end
                end)
            end)
            animateGroup(slot,(index-1)*.65,token)
            task.delay((index-1)*.65+.48,function()
                if token~=generation or not slot.MasteryTrack.Fill.Parent then return end
                animateMastery(slot,item.id,before,current,.65,token,function()
                    if token~=generation then return end
                    introFinished=true
                    updateBoost()
                end)
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

