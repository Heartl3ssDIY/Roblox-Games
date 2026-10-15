local items = {
	{ id = "BubbleBee", name = "Bubble Bee", category = "Pets", slot = "Pet", price = 45, color = Color3.fromRGB(255, 207, 59), preview = "Bee" },
	{ id = "CloudPup", name = "Cloud Pup", category = "Pets", slot = "Pet", price = 70, color = Color3.fromRGB(205, 235, 255), preview = "Cloud" },
	{ id = "Wave", name = "Hello Wave", category = "Emotes", slot = "Emote", price = 30, color = Color3.fromRGB(107, 204, 255), preview = "Wave" },
	{ id = "Cheer", name = "Big Cheer", category = "Emotes", slot = "Emote", price = 45, color = Color3.fromRGB(255, 130, 181), preview = "Cheer" },
	{ id = "Star", name = "Starstruck", category = "Emojis", slot = "Emoji", price = 25, color = Color3.fromRGB(255, 212, 74), preview = "Star", emoji = "★" },
	{ id = "Heart", name = "Sending Love", category = "Emojis", slot = "Emoji", price = 25, color = Color3.fromRGB(255, 103, 146), preview = "Heart", emoji = "♥" },
	{ id = "SunsetTrail", name = "Sunset Ribbon", category = "Trails", slot = "Trail", price = 40, color = Color3.fromRGB(255, 157, 67), preview = "Ribbon" },
	{ id = "RainbowTrail", name = "Rainbow Ribbon", category = "Trails", slot = "Trail", price = 70, color = Color3.fromRGB(128, 113, 255), preview = "Rainbow" },
	{ id = "SkyOutline", name = "Sky Outline", category = "Highlights", slot = "Highlight", price = 40, color = Color3.fromRGB(53, 168, 255), preview = "Outline" },
	{ id = "RainbowOutline", name = "Rainbow Outline", category = "Highlights", slot = "Highlight", price = 90, color = Color3.fromRGB(147, 115, 255), preview = "Outline" },
	{ id = "SnowPotion", name = "Snow Potion", category = "Gear", slot = "Gear", price = 75, color = Color3.fromRGB(148, 228, 255), preview = "Potion", available = false },
	{ id = "StarWand", name = "Star Wand", category = "Gear", slot = "Gear", price = 75, color = Color3.fromRGB(255, 207, 59), preview = "Wand", available = false },
}
local byId = {}
for _, item in ipairs(items) do
	byId[item.id] = item
end
return { Items = items, ById = byId, Categories = { "All", "Pets", "Emotes", "Emojis", "Trails", "Highlights", "Gear" } }
