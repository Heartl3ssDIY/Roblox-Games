local items = {}
local byId = {}
for _, item in ipairs(items) do
	byId[item.id] = item
end
return { Items = items, ById = byId, Categories = { "All", "Pets", "Emotes", "Emojis", "Trails", "Highlights", "Gear" } }
