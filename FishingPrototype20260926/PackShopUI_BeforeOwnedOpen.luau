local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local PackOpening = require(ReplicatedStorage:WaitForChild("PackOpening"))
local PackReveal = require(ReplicatedStorage:WaitForChild("PackReveal"))

local ShopEffects = require(ReplicatedStorage:WaitForChild("PackShopEffects"))

local PackShopUI = {}
local gui, board, panel
local wanted = false
local busy = false
local noticeVersion = 0
local names = {silver = "Silver", gold = "Gold", diamond = "Diamond", bronze = "Common"}

local function notify(message)
    ShopEffects.play("Unavailable")
    noticeVersion += 1
    local token = noticeVersion
    panel.Notice.Text = message
    panel.Notice.Visible = true
    task.delay(4, function()
        if noticeVersion == token then panel.Notice.Visible = false end
    end)
end

local function fit()
    if gui:GetAttribute("AutoFit") == false then return end
    local margin = gui:GetAttribute("FitMargin") or 48
    local verticalMargin = margin + math.max(0, -gui.AbsolutePosition.Y)
    board.FitToScreen.Scale = math.max(0.1, math.min(1, (gui.AbsoluteSize.X - margin * 2) / board.Size.X.Offset, (gui.AbsoluteSize.Y - verticalMargin * 2) / board.Size.Y.Offset))
end

function PackShopUI.details(packId)
    local info = PackOpening.info(packId)
    if not info then return "" end
    local lines = {"Maximum: " .. info.cap .. " XP cards", ""}
    local newEligible = 0
    for _, tier in ipairs(info.tiers) do
        newEligible += tier.unlockable
        table.insert(lines, string.format("%s: %d–%d XP; %g%% new", tier.rarity, tier.minimum, tier.maximum, tier.chance * 100))
    end
    table.insert(lines, "")
    table.insert(lines, "New-unit chances apply only to unlocked, unowned units. Eligible now: " .. newEligible .. ".")
    table.insert(lines, "XP cards go to owned units of that rarity. 1 card = 1 XP.")
    table.insert(lines, "Guaranteed for your collection: " .. info.guaranteed .. " XP cards.")
    if not info.eligible then table.insert(lines, "No eligible units in your collection yet.") end
    if packId == "bronze" then table.insert(lines, "2 purchases per day. Both reset together at 00:00 UTC.") end
    return table.concat(lines, "\n")
end

local function showInfo(packId, group)
    local tooltip = panel.Tooltip
    tooltip.Title.Text = PackOpening.PACKS[packId].name
    tooltip.Body.Text = PackShopUI.details(packId)
    local x = group.Position.X.Offset + group.Size.X.Offset + 10
    if x + tooltip.Size.X.Offset > panel.Size.X.Offset - 20 then
        x = math.max(20, group.Position.X.Offset - tooltip.Size.X.Offset - 10)
    end
    tooltip.Position = UDim2.fromOffset(x, 150)
    tooltip.Visible = true
end

local function refresh()
    if not gui then return end
    local common = panel.Common
    local remaining = ShopConfig.commonRemaining()
    common.Remaining.Text = remaining .. "/" .. ShopConfig.commonPack.limit .. " remaining"
    for index, name in ipairs({"PackOne", "PackTwo"}) do
        common.Art[name].Visible = ShopConfig.canClaim(ShopConfig.bitPacks[index].id)
    end
    if remaining < ShopConfig.commonPack.limit then
        local seconds = ShopConfig.commonResetSeconds()
        common.Remaining.Text ..= string.format("\nResets in %02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60)
    end
    common.Buy.Interactable = remaining > 0
    common.Buy.ImageTransparency = remaining == 0 and 0.45 or 0
    for _, spec in ipairs(ShopConfig.packs) do
        local group = panel[names[spec.id]]
        group.Buy.Price.Text = tostring(spec.cost)
        group.Availability.Visible = false
        group.Availability.Text = "No eligible units yet"
        group.Buy.ImageColor3 = Color3.new(1, 1, 1)
    end
end

function PackShopUI.buy(packId)
    if not gui or busy then return false end
    if packId == "bronze" then
        if ShopConfig.commonRemaining() == 0 then notify("Today's Common packs are sold out.")
        else notify("Common-pack purchases are not available yet.") end
        return false
    end
    local spec
    for _, entry in ipairs(ShopConfig.packs) do if entry.id == packId then spec = entry; break end end
    if not spec then return false end
    local info = PackOpening.info(packId)
    if not info or not info.eligible then
        notify("Unlock an eligible unit before buying this pack.")
        return false
    end
    if PlayerData.gems() < spec.cost then notify("Not enough diamonds."); return false end
    busy = true
    local rewards = PackOpening.roll(packId)
    if not rewards then busy = false; return false end
    if not PlayerData.spendGems(spec.cost) then busy = false; return false end
    PackOpening.apply(rewards)
    ShopEffects.play("Confirm")
    panel.Tooltip.Visible = false
    gui.Enabled = false
    PackReveal.play(Players.LocalPlayer.PlayerGui, rewards, function()
        busy = false
        if wanted then gui.Enabled = true; refresh() end
    end)
    return true
end

function PackShopUI.build(playerGui)
    if gui then return gui end
    gui = playerGui:WaitForChild("PackShopGui")
    board = gui.Board
    panel = board.Panel
    ShopEffects.bind(gui)
    panel.Close.Activated:Connect(PackShopUI.close)
    for _, id in ipairs({"silver", "gold", "diamond", "bronze"}) do
        local group = panel[names[id]]
        local artworks = id == "bronze" and {group.Art.PackOne, group.Art.PackTwo} or {group.Pack}
        for _, art in ipairs(artworks) do
            art.MouseEnter:Connect(function() showInfo(id, group) end)
            art.MouseLeave:Connect(function() panel.Tooltip.Visible = false end)
            art.SelectionGained:Connect(function() showInfo(id, group) end)
            art.SelectionLost:Connect(function() panel.Tooltip.Visible = false end)
            art.Activated:Connect(function()
                if panel.Tooltip.Visible and panel.Tooltip.Title.Text == PackOpening.PACKS[id].name then
                    panel.Tooltip.Visible = false
                else showInfo(id, group) end
            end)
        end
        group.Buy.Activated:Connect(function() PackShopUI.buy(id) end)
    end
    PlayerData.Changed:Connect(refresh)
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(fit)
    gui.Enabled = false
    panel.Tooltip.Visible = false
    refresh()
    fit()
    task.spawn(function()
        while gui.Parent do
            if gui.Enabled then refresh() end
            task.wait(1)
        end
    end)
    return gui
end

function PackShopUI.open(playerGui)
    PackShopUI.build(playerGui)
    wanted = true
    refresh()
    fit()
    if not busy then gui.Enabled = true end
end

function PackShopUI.close()
    wanted = false
    if gui then
        gui.Enabled = false
        panel.Tooltip.Visible = false
    end
end

function PackShopUI.isOpen()
    return gui ~= nil and gui.Enabled
end

return PackShopUI

