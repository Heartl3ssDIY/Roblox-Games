-- Shared artwork for Battle Pass reward cards. Reward contents and quantities live in SeasonPassData.
local RewardArt = {
    coins = { title = "COINS", image = "rbxassetid://104639886186145" },
    diamonds = { title = "DIAMONDS", image = "rbxassetid://138321736461215" },
    masteryChips = { title = "MASTERY CHIPS", image = "rbxassetid://82519543150534" },
    commonPack = { title = "COMMON PACK", image = "rbxassetid://73606499921543" },
    silverPack = { title = "SILVER PACK", image = "rbxassetid://118796124465923" },
    goldPack = { title = "GOLD PACK", image = "rbxassetid://107366517958284" },
    diamondPack = { title = "DIAMOND PACK", image = "rbxassetid://110308903192424" },
    packPoolUnlock = { title = "BEERAS COMING SOON", image = "", previewModel = "Beeras" },
    unitXp = { title = "BEERAS XP", image = "", previewModel = "Beeras" },
}
RewardArt.bronze = RewardArt.commonPack
RewardArt.silver = RewardArt.silverPack
RewardArt.gold = RewardArt.goldPack
RewardArt.coin = RewardArt.coins
RewardArt.diamond = RewardArt.diamonds
RewardArt.masteryChip = RewardArt.masteryChips

function RewardArt.forReward(reward)
    if type(reward) ~= "table" then return nil end
    local packRarity = reward.packRarity or reward.pack
    if reward.kind == "pack" then packRarity = packRarity or reward.rarity end
    if packRarity then
        local packKey = ({ bronze = "commonPack", common = "commonPack", silver = "silverPack", gold = "goldPack", diamond = "diamondPack" })[packRarity]
        return packKey and RewardArt[packKey] or nil
    end
    local kind = reward.icon or reward.kind or reward.item or reward.currency
    return RewardArt[kind]
end

local function formatAmount(amount)
    local formatted = tostring(amount):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return formatted:gsub("^,", "")
end

function RewardArt.displayName(reward)
    local art = RewardArt.forReward(reward)
    if not art then return "" end
    if reward.kind == "packPoolUnlock" or reward.kind == "unitXp" then return art.title end
    if reward.kind == "pack" then
        return reward.amount and reward.amount > 1 and ("x" .. reward.amount .. " " .. art.title) or art.title
    end
    return reward.amount and (formatAmount(reward.amount) .. " " .. art.title) or art.title
end

return RewardArt
