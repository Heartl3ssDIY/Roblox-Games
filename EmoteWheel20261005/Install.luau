assert(not game:GetService("RunService"):IsRunning(), "Install only in Edit mode")
assert(game.PlaceId == 95034648955135, "Wrong place")
local storage = game:GetService("ServerStorage")
local starterGui = game:GetService("StarterGui")
assert(not storage:FindFirstChild("EmoteWheelBackup20261005"), "Backup exists; inspect before repeating")
assert(not starterGui:FindFirstChild("PlaygroundEmoteWheel"), "Existing wheel must be preserved")
local entries = {
{path="ReplicatedStorage.PlaygroundCatalog",before=[========[
local function item(id, name, category, slot, kind, amount, gameId, description, color)
	return {
		id = id,
		name = name,
		category = category,
		slot = slot,
		available = true,
		price = kind == "Coins" and amount or 0,
		unlock = { kind = kind, amount = amount, gameId = gameId },
		description = description,
		color = Color3.fromRGB(color[1], color[2], color[3]),
		assetId = id,
	}
end

local items = {
	item("B01", "Starter Slugger", "Bats", "Bat", "Starter", 0, nil, "Your first Bulldog bat. Ready from the start.", {218, 155, 76}),
	item("B02", "Schoolyard Alloy", "Bats", "Bat", "Coins", 750, nil, "A silver schoolyard classic with a blue grip.", {139, 185, 224}),
	item("B03", "Varsity Victory", "Bats", "Bat", "Level", 5, nil, "Earn your varsity colours by reaching level 5.", {241, 91, 101}),
	item("B04", "Street Cone", "Bats", "Bat", "Coins", 1250, nil, "Bold orange with bright playground stripes.", {255, 147, 57}),
	item("B05", "Bubblegum Bonker", "Bats", "Bat", "Level", 10, nil, "A sweet reward for reaching level 10.", {244, 113, 184}),
	item("B06", "Mudslinger", "Bats", "Bat", "Wins", 25, "StuckInTheMud", "Win 25 rounds of Stuck in the Mud.", {142, 126, 73}),
	item("B07", "Heat Coil", "Bats", "Bat", "Wins", 50, "StuckInTheMud", "A heated trophy for 50 Stuck in the Mud wins.", {255, 152, 67}),
	item("B08", "Frostbite", "Bats", "Bat", "Coins", 4000, nil, "A chunky ice-blue barrel and a deep blue grip.", {116, 225, 245}),
	item("B09", "Thunder Circuit", "Bats", "Bat", "Wins", 25, "TagYoureIt", "Win 25 rounds of Tag You're It.", {67, 143, 243}),
	item("B10", "Pixel Party", "Bats", "Bat", "Level", 20, nil, "Reach level 20 for this bright arcade bat.", {213, 97, 228}),
	item("B11", "Cosmic Orbit", "Bats", "Bat", "Coins", 10000, nil, "A violet barrel with a silver orbit ring.", {153, 120, 235}),
	item("B12", "Royal Champion", "Bats", "Bat", "Wins", 50, "BritishBulldog", "A crown for 50 British Bulldog wins.", {248, 209, 92}),
	item("B13", "Skatepark Stripe", "Bats", "Bat", "Coins", 2500, nil, "Blue, mint and coral playground style.", {82, 176, 226}),
	item("B14", "Deep Sea", "Bats", "Bat", "Coins", 6000, nil, "Ocean waves on a navy and turquoise barrel.", {71, 193, 191}),
	item("B15", "Sunburst", "Bats", "Bat", "Level", 30, nil, "A sunny reward for reaching level 30.", {255, 180, 63}),
	item("P01", "Pocket Bulldog", "Pets", "Pet", "Coins", 500, nil, "A cheerful little schoolyard companion.", {224, 184, 131}),
	item("P02", "Toast Capybara", "Pets", "Pet", "Level", 3, nil, "Reach level 3 for this sleepy toast-shaped friend.", {209, 153, 86}),
	item("P03", "Pancake Penguin", "Pets", "Pet", "Coins", 1000, nil, "A happy penguin with a pancake hat.", {118, 160, 214}),
	item("P04", "Jelly Axolotl", "Pets", "Pet", "Wins", 10, "StuckInTheMud", "Win 10 rounds of Stuck in the Mud.", {103, 221, 219}),
	item("P05", "Rocket Snail", "Pets", "Pet", "Level", 8, nil, "Reach level 8 for this tiny rocket rider.", {142, 224, 172}),
	item("P06", "Traffic Crab", "Pets", "Pet", "Coins", 1750, nil, "A blue crab wearing a bright traffic-cone hat.", {83, 176, 232}),
	item("P07", "Teapot Frog", "Pets", "Pet", "Coins", 2000, nil, "A little green frog with teapot charm.", {170, 208, 91}),
	item("P08", "Skater Shark", "Pets", "Pet", "Wins", 10, "TagYoureIt", "Win 10 rounds of Tag You're It.", {78, 203, 224}),
	item("P09", "Disco Duck", "Pets", "Pet", "Coins", 3000, nil, "A sunny duck that brings its own disco backpack.", {255, 216, 70}),
	item("P10", "Cloud Sheep", "Pets", "Pet", "Level", 12, nil, "A fluffy reward for reaching level 12.", {174, 216, 245}),
	item("P11", "Cactus Cat", "Pets", "Pet", "Coins", 4000, nil, "A cuddly cactus kitten with a pink flower.", {115, 202, 113}),
	item("P12", "UFO Jelly", "Pets", "Pet", "Level", 18, nil, "Reach level 18 for a visitor from the playground stars.", {185, 156, 233}),
	item("P13", "Pumpkin Bunny", "Pets", "Pet", "Coins", 5000, nil, "A pumpkin-shaped bunny with leafy ears.", {244, 156, 63}),
	item("P14", "Hoodie Ghost", "Pets", "Pet", "Wins", 25, "TagYoureIt", "Win 25 rounds of Tag You're It.", {174, 142, 224}),
	item("P15", "Marshmallow Dragon", "Pets", "Pet", "Coins", 7500, nil, "A soft-coloured little dragon with pink wings.", {247, 179, 205}),
	item("P16", "Banana Gorilla", "Pets", "Pet", "Wins", 25, "BritishBulldog", "Win 25 rounds of British Bulldog.", {238, 200, 65}),
	item("P17", "Gummy Rex", "Pets", "Pet", "Level", 25, nil, "Reach level 25 for a cheerful gummy dinosaur.", {163, 222, 88}),
	item("P18", "Lava Toaster", "Pets", "Pet", "Wins", 50, "StuckInTheMud", "Win 50 rounds of Stuck in the Mud.", {248, 134, 64}),
	item("P19", "Moon Moth", "Pets", "Pet", "Coins", 10000, nil, "A cream and violet companion with crescent wings.", {177, 160, 239}),
	item("P20", "Royal Slime", "Pets", "Pet", "Wins", 100, "All", "Win 100 rounds across all three games.", {100, 148, 237}),
	item("M01", "Playground Football", "Toys", "Gear", "Coins", 250, nil, "Lobby only. Kick a football that bounces for up to 5 seconds. Recharges in 5 seconds.", {224, 224, 208}),
	item("M02", "Playground Basketball", "Toys", "Gear", "Coins", 350, nil, "Lobby only. Lob a basketball high into the air. It lasts up to 5 seconds and recharges in 5 seconds.", {249, 147, 65}),
	item("M03", "Foam Bonker", "Toys", "Gear", "Coins", 500, nil, "Lobby only. Swing a harmless foam bonker with a star burst on contact. Recharges in 0.8 seconds.", {233, 129, 208}),
	item("M04", "Tumble Barrel", "Toys", "Gear", "Coins", 1000, nil, "Lobby only. Throw a tumbling barrel that bounces for up to 5 seconds. Recharges in 5 seconds.", {191, 139, 84}),
	item("M05", "Zoom Juice", "Toys", "Gear", "Coins", 750, nil, "Lobby only. Drink for 3 times your normal walking speed for 25 seconds. Recharges when the boost ends.", {69, 205, 220}),
	item("M06", "Spring Sip", "Toys", "Gear", "Coins", 750, nil, "Lobby only. Drink to jump 5 times your normal height for 10 seconds. Recharges when the boost ends.", {176, 221, 76}),
	item("M07", "Ember Elixir", "Toys", "Gear", "Coins", 1250, nil, "Lobby only. Drink, then tap to breathe fire for 10 seconds. Hits burn for 1 damage a second for 10 seconds.", {250, 136, 63}),
	item("M08", "Surprise Present", "Toys", "Gear", "Coins", 500, nil, "Lobby only. Shake a present to release colourful confetti. Recharges in 3 seconds.", {103, 207, 208}),
	item("M09", "Plunger Popper", "Toys", "Gear", "Coins", 4000, nil, "Lobby collectible. You can own and equip this launcher; its action is on hold until the plunger model is ready.", {85, 191, 187}),
	item("M10", "Frost Ray", "Toys", "Gear", "Coins", 5000, nil, "Lobby only. Freeze another player for 2.5 seconds with an icy ray. Recharges in 5 seconds.", {107, 216, 239}),
	item("M11", "Paint Splash", "Toys", "Gear", "Coins", 1500, nil, "Lobby only. Throw colourful paint that leaves a splash for 10 seconds. Recharges in 2 seconds.", {225, 118, 204}),
	item("M12", "Eggsploit", "Toys", "Gear", "Coins", 300, nil, "Lobby only. Throw an egg that shakes on impact and pops into confetti. Recharges in 3 seconds.", {238, 226, 184}),
	item("M13", "Cake Toss", "Toys", "Gear", "Coins", 600, nil, "Lobby only. Throw a cake that leaves frosting for 5 seconds. Recharges in 3 seconds.", {204, 157, 122}),
	item("M14", "Camp Torch", "Toys", "Gear", "Coins", 2500, nil, "Lobby only. Touch another player with the held torch to burn for 1 damage a second for 10 seconds.", {253, 168, 64}),
	item("M15", "Bounce Pad", "Toys", "Gear", "Coins", 3000, nil, "Lobby only. Place a shared bounce pad for 15 seconds before it bursts into sparkles. Recharges when the pad expires.", {97, 210, 224}),
}

local emoteAnimations = {}
for _, dance in ipairs({
	{ id = "E01", name = "Dougie", kind = "Coins", amount = 500, catalogId = 114756515400742, animationId = 93650537970037 },
	{ id = "E02", name = "Street Glide", kind = "Coins", amount = 750, catalogId = 137284968787523, animationId = 82378883639086 },
	{ id = "E03", name = "Money Hop Switch", kind = "Coins", amount = 1000, catalogId = 134222090358172, animationId = 132555082396072 },
	{ id = "E04", name = "Coffin Walkout", kind = "Level", amount = 5, catalogId = 117302755748327, animationId = 126771729094882 },
	{ id = "E05", name = "The Tylil Dance", kind = "Coins", amount = 1500, catalogId = 107010273569673, animationId = 110494040742516 },
	{ id = "E06", name = "Scuba Trend", kind = "Level", amount = 8, catalogId = 135211326811898, animationId = 140349022227594 },
	{ id = "E08", name = "Rollie", kind = "Coins", amount = 2000, catalogId = 110827382619943, animationId = 117558759116256 },
	{ id = "E09", name = "Out West", kind = "Coins", amount = 2500, catalogId = 133595410032960, animationId = 103687288237641 },
	{ id = "E10", name = "Four Lokos Dance", kind = "Level", amount = 12, catalogId = 115906496196760, animationId = 105190540415890 },
	{ id = "E11", name = "Griddy", kind = "Coins", amount = 5000, catalogId = 77017926307035, animationId = 81913798511136 },
	{ id = "E12", name = "Gangstar Dance", kind = "Coins", amount = 3000, catalogId = 84110142550799, animationId = 93941266454007 },
	{ id = "E13", name = "Keep It Gangsta", kind = "Level", amount = 16, catalogId = 100951835636163, animationId = 92659655601730 },
	{ id = "E14", name = "Jabba Switchway", kind = "Coins", amount = 3500, catalogId = 104940682593173, animationId = 78280967285254 },
	{ id = "E15", name = "Billy Bounce", kind = "Level", amount = 20, catalogId = 93450937830334, animationId = 119280135350752 },
	{ id = "E16", name = "Jamal Brazil Groove", kind = "Coins", amount = 4000, catalogId = 117119421748582, animationId = 106865236633450 },
	{ id = "E17", name = "67", kind = "Level", amount = 25, catalogId = 100498935359536, animationId = 108639244526475 },
	{ id = "E18", name = "Orange Justice", kind = "Coins", amount = 6500, catalogId = 110064349530772, animationId = 95127716920692 },
	{ id = "E19", name = "Dab Steps", kind = "Coins", amount = 4500, catalogId = 126353729413555, animationId = 104609460346094 },
	{ id = "E20", name = "Creepin Dance", kind = "Coins", amount = 5000, catalogId = 80985588930231, animationId = 95428460379424 },
	{ id = "E21", name = "Nervy Dance", kind = "Level", amount = 30, catalogId = 125328720114284, animationId = 90018336892195 },
	{ id = "E22", name = "Pretty Young Thing", kind = "Coins", amount = 7500, catalogId = 137234266130963, animationId = 108374677470972 },
	{ id = "E23", name = "Party Rock Anthem", kind = "Coins", amount = 10000, catalogId = 105248382902194, animationId = 134459607456762 },
	{ id = "E24", name = "Passinho do Jamal", kind = "Level", amount = 35, catalogId = 137057022541237, animationId = 100468196980144 },
	{ id = "E25", name = "Camden Bop", kind = "Coins", amount = 6000, catalogId = 86411651121424, animationId = 134644266320983 },
	{ id = "E26", name = "Every Beat", kind = "Level", amount = 40, catalogId = 134311528115559, animationId = 136095999219650 },
	{ id = "E27", name = "One Hand Push Ups", kind = "Coins", amount = 8000, catalogId = 121644855433565, animationId = 74800678690946 },
	{ id = "E28", name = "Gangnam Style", kind = "Coins", amount = 12500, catalogId = 80923445784018, animationId = 131104967711844 },
	{ id = "E29", name = "Murda Bend", kind = "Coins", amount = 9000, catalogId = 96843993997234, animationId = 90158235751747 },
	{ id = "E30", name = "Monkey", kind = "Level", amount = 3, catalogId = 3716636630, animationId = 10714388352 },
	{ id = "E31", name = "NLE Choppa Demon", kind = "Coins", amount = 15000, catalogId = 96181123599016, animationId = 133898543831391 },
	{ id = "E32", name = "Brazilian Dance", kind = "Level", amount = 50, catalogId = 76636280785091, animationId = 138980897636026 },
}) do
	local description = "Dance in the lobby. Move or jump to stop. Equip for your winner podium."
	local entry = item(dance.id, dance.name, "Emotes", "Emote", dance.kind, dance.amount, nil, description, {120, 193, 244})
	entry.catalogId = dance.catalogId
	entry.thumbnail = "rbxthumb://type=Asset&id=" .. string.format("%.0f", dance.catalogId) .. "&w=420&h=420"
	entry.playable = true
	entry.rigType = "R15"
	emoteAnimations[dance.id] = { R15AnimationId = dance.animationId }
	table.insert(items, entry)
end

local byId = {}
for _, entry in ipairs(items) do
	assert(byId[entry.id] == nil, "Duplicate catalog ID: " .. entry.id)
	assert(entry.price >= 0 and entry.price <= (entry.slot == "Emote" and 15000 or 10000), "Catalog price exceeds the coin cap")
	byId[entry.id] = entry
end

byId.M09.toyActionPending = true

return {
	Items = items,
	ById = byId,
	Categories = { "All", "Bats", "Pets", "Toys", "Emotes" },
	EmoteAnimations = emoteAnimations,
	StarterBat = "B01",
	MaxCoinPrice = 15000,
	MaxEquipmentCoinPrice = 10000,
	MaxToySlots = 4,
	GameNames = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It", StuckInTheMud = "Stuck in the Mud", All = "total" },
}


]========],after=[========[
local function item(id, name, category, slot, kind, amount, gameId, description, color)
	return {
		id = id,
		name = name,
		category = category,
		slot = slot,
		available = true,
		price = kind == "Coins" and amount or 0,
		unlock = { kind = kind, amount = amount, gameId = gameId },
		description = description,
		color = Color3.fromRGB(color[1], color[2], color[3]),
		assetId = id,
	}
end

local items = {
	item("B01", "Starter Slugger", "Bats", "Bat", "Starter", 0, nil, "Your first Bulldog bat. Ready from the start.", {218, 155, 76}),
	item("B02", "Schoolyard Alloy", "Bats", "Bat", "Coins", 750, nil, "A silver schoolyard classic with a blue grip.", {139, 185, 224}),
	item("B03", "Varsity Victory", "Bats", "Bat", "Level", 5, nil, "Earn your varsity colours by reaching level 5.", {241, 91, 101}),
	item("B04", "Street Cone", "Bats", "Bat", "Coins", 1250, nil, "Bold orange with bright playground stripes.", {255, 147, 57}),
	item("B05", "Bubblegum Bonker", "Bats", "Bat", "Level", 10, nil, "A sweet reward for reaching level 10.", {244, 113, 184}),
	item("B06", "Mudslinger", "Bats", "Bat", "Wins", 25, "StuckInTheMud", "Win 25 rounds of Stuck in the Mud.", {142, 126, 73}),
	item("B07", "Heat Coil", "Bats", "Bat", "Wins", 50, "StuckInTheMud", "A heated trophy for 50 Stuck in the Mud wins.", {255, 152, 67}),
	item("B08", "Frostbite", "Bats", "Bat", "Coins", 4000, nil, "A chunky ice-blue barrel and a deep blue grip.", {116, 225, 245}),
	item("B09", "Thunder Circuit", "Bats", "Bat", "Wins", 25, "TagYoureIt", "Win 25 rounds of Tag You're It.", {67, 143, 243}),
	item("B10", "Pixel Party", "Bats", "Bat", "Level", 20, nil, "Reach level 20 for this bright arcade bat.", {213, 97, 228}),
	item("B11", "Cosmic Orbit", "Bats", "Bat", "Coins", 10000, nil, "A violet barrel with a silver orbit ring.", {153, 120, 235}),
	item("B12", "Royal Champion", "Bats", "Bat", "Wins", 50, "BritishBulldog", "A crown for 50 British Bulldog wins.", {248, 209, 92}),
	item("B13", "Skatepark Stripe", "Bats", "Bat", "Coins", 2500, nil, "Blue, mint and coral playground style.", {82, 176, 226}),
	item("B14", "Deep Sea", "Bats", "Bat", "Coins", 6000, nil, "Ocean waves on a navy and turquoise barrel.", {71, 193, 191}),
	item("B15", "Sunburst", "Bats", "Bat", "Level", 30, nil, "A sunny reward for reaching level 30.", {255, 180, 63}),
	item("P01", "Pocket Bulldog", "Pets", "Pet", "Coins", 500, nil, "A cheerful little schoolyard companion.", {224, 184, 131}),
	item("P02", "Toast Capybara", "Pets", "Pet", "Level", 3, nil, "Reach level 3 for this sleepy toast-shaped friend.", {209, 153, 86}),
	item("P03", "Pancake Penguin", "Pets", "Pet", "Coins", 1000, nil, "A happy penguin with a pancake hat.", {118, 160, 214}),
	item("P04", "Jelly Axolotl", "Pets", "Pet", "Wins", 10, "StuckInTheMud", "Win 10 rounds of Stuck in the Mud.", {103, 221, 219}),
	item("P05", "Rocket Snail", "Pets", "Pet", "Level", 8, nil, "Reach level 8 for this tiny rocket rider.", {142, 224, 172}),
	item("P06", "Traffic Crab", "Pets", "Pet", "Coins", 1750, nil, "A blue crab wearing a bright traffic-cone hat.", {83, 176, 232}),
	item("P07", "Teapot Frog", "Pets", "Pet", "Coins", 2000, nil, "A little green frog with teapot charm.", {170, 208, 91}),
	item("P08", "Skater Shark", "Pets", "Pet", "Wins", 10, "TagYoureIt", "Win 10 rounds of Tag You're It.", {78, 203, 224}),
	item("P09", "Disco Duck", "Pets", "Pet", "Coins", 3000, nil, "A sunny duck that brings its own disco backpack.", {255, 216, 70}),
	item("P10", "Cloud Sheep", "Pets", "Pet", "Level", 12, nil, "A fluffy reward for reaching level 12.", {174, 216, 245}),
	item("P11", "Cactus Cat", "Pets", "Pet", "Coins", 4000, nil, "A cuddly cactus kitten with a pink flower.", {115, 202, 113}),
	item("P12", "UFO Jelly", "Pets", "Pet", "Level", 18, nil, "Reach level 18 for a visitor from the playground stars.", {185, 156, 233}),
	item("P13", "Pumpkin Bunny", "Pets", "Pet", "Coins", 5000, nil, "A pumpkin-shaped bunny with leafy ears.", {244, 156, 63}),
	item("P14", "Hoodie Ghost", "Pets", "Pet", "Wins", 25, "TagYoureIt", "Win 25 rounds of Tag You're It.", {174, 142, 224}),
	item("P15", "Marshmallow Dragon", "Pets", "Pet", "Coins", 7500, nil, "A soft-coloured little dragon with pink wings.", {247, 179, 205}),
	item("P16", "Banana Gorilla", "Pets", "Pet", "Wins", 25, "BritishBulldog", "Win 25 rounds of British Bulldog.", {238, 200, 65}),
	item("P17", "Gummy Rex", "Pets", "Pet", "Level", 25, nil, "Reach level 25 for a cheerful gummy dinosaur.", {163, 222, 88}),
	item("P18", "Lava Toaster", "Pets", "Pet", "Wins", 50, "StuckInTheMud", "Win 50 rounds of Stuck in the Mud.", {248, 134, 64}),
	item("P19", "Moon Moth", "Pets", "Pet", "Coins", 10000, nil, "A cream and violet companion with crescent wings.", {177, 160, 239}),
	item("P20", "Royal Slime", "Pets", "Pet", "Wins", 100, "All", "Win 100 rounds across all three games.", {100, 148, 237}),
	item("M01", "Playground Football", "Toys", "Gear", "Coins", 250, nil, "Lobby only. Kick a football that bounces for up to 5 seconds. Recharges in 5 seconds.", {224, 224, 208}),
	item("M02", "Playground Basketball", "Toys", "Gear", "Coins", 350, nil, "Lobby only. Lob a basketball high into the air. It lasts up to 5 seconds and recharges in 5 seconds.", {249, 147, 65}),
	item("M03", "Foam Bonker", "Toys", "Gear", "Coins", 500, nil, "Lobby only. Swing a harmless foam bonker with a star burst on contact. Recharges in 0.8 seconds.", {233, 129, 208}),
	item("M04", "Tumble Barrel", "Toys", "Gear", "Coins", 1000, nil, "Lobby only. Throw a tumbling barrel that bounces for up to 5 seconds. Recharges in 5 seconds.", {191, 139, 84}),
	item("M05", "Zoom Juice", "Toys", "Gear", "Coins", 750, nil, "Lobby only. Drink for 3 times your normal walking speed for 25 seconds. Recharges when the boost ends.", {69, 205, 220}),
	item("M06", "Spring Sip", "Toys", "Gear", "Coins", 750, nil, "Lobby only. Drink to jump 5 times your normal height for 10 seconds. Recharges when the boost ends.", {176, 221, 76}),
	item("M07", "Ember Elixir", "Toys", "Gear", "Coins", 1250, nil, "Lobby only. Drink, then tap to breathe fire for 10 seconds. Hits burn for 1 damage a second for 10 seconds.", {250, 136, 63}),
	item("M08", "Surprise Present", "Toys", "Gear", "Coins", 500, nil, "Lobby only. Shake a present to release colourful confetti. Recharges in 3 seconds.", {103, 207, 208}),
	item("M09", "Plunger Popper", "Toys", "Gear", "Coins", 4000, nil, "Lobby collectible. You can own and equip this launcher; its action is on hold until the plunger model is ready.", {85, 191, 187}),
	item("M10", "Frost Ray", "Toys", "Gear", "Coins", 5000, nil, "Lobby only. Freeze another player for 2.5 seconds with an icy ray. Recharges in 5 seconds.", {107, 216, 239}),
	item("M11", "Paint Splash", "Toys", "Gear", "Coins", 1500, nil, "Lobby only. Throw colourful paint that leaves a splash for 10 seconds. Recharges in 2 seconds.", {225, 118, 204}),
	item("M12", "Eggsploit", "Toys", "Gear", "Coins", 300, nil, "Lobby only. Throw an egg that shakes on impact and pops into confetti. Recharges in 3 seconds.", {238, 226, 184}),
	item("M13", "Cake Toss", "Toys", "Gear", "Coins", 600, nil, "Lobby only. Throw a cake that leaves frosting for 5 seconds. Recharges in 3 seconds.", {204, 157, 122}),
	item("M14", "Camp Torch", "Toys", "Gear", "Coins", 2500, nil, "Lobby only. Touch another player with the held torch to burn for 1 damage a second for 10 seconds.", {253, 168, 64}),
	item("M15", "Bounce Pad", "Toys", "Gear", "Coins", 3000, nil, "Lobby only. Place a shared bounce pad for 15 seconds before it bursts into sparkles. Recharges when the pad expires.", {97, 210, 224}),
}

local emoteAnimations = {}
for _, dance in ipairs({
	{ id = "E01", name = "Dougie", kind = "Coins", amount = 500, catalogId = 114756515400742, animationId = 93650537970037 },
	{ id = "E02", name = "Street Glide", kind = "Coins", amount = 750, catalogId = 137284968787523, animationId = 82378883639086 },
	{ id = "E03", name = "Money Hop Switch", kind = "Coins", amount = 1000, catalogId = 134222090358172, animationId = 132555082396072 },
	{ id = "E04", name = "Coffin Walkout", kind = "Level", amount = 5, catalogId = 117302755748327, animationId = 126771729094882 },
	{ id = "E05", name = "The Tylil Dance", kind = "Coins", amount = 1500, catalogId = 107010273569673, animationId = 110494040742516 },
	{ id = "E06", name = "Scuba Trend", kind = "Level", amount = 8, catalogId = 135211326811898, animationId = 140349022227594 },
	{ id = "E08", name = "Rollie", kind = "Coins", amount = 2000, catalogId = 110827382619943, animationId = 117558759116256 },
	{ id = "E09", name = "Out West", kind = "Coins", amount = 2500, catalogId = 133595410032960, animationId = 103687288237641 },
	{ id = "E10", name = "Four Lokos Dance", kind = "Level", amount = 12, catalogId = 115906496196760, animationId = 105190540415890 },
	{ id = "E11", name = "Griddy", kind = "Coins", amount = 5000, catalogId = 77017926307035, animationId = 81913798511136 },
	{ id = "E12", name = "Gangstar Dance", kind = "Coins", amount = 3000, catalogId = 84110142550799, animationId = 93941266454007 },
	{ id = "E13", name = "Keep It Gangsta", kind = "Level", amount = 16, catalogId = 100951835636163, animationId = 92659655601730 },
	{ id = "E14", name = "Jabba Switchway", kind = "Coins", amount = 3500, catalogId = 104940682593173, animationId = 78280967285254 },
	{ id = "E15", name = "Billy Bounce", kind = "Level", amount = 20, catalogId = 93450937830334, animationId = 119280135350752 },
	{ id = "E16", name = "Jamal Brazil Groove", kind = "Coins", amount = 4000, catalogId = 117119421748582, animationId = 106865236633450 },
	{ id = "E17", name = "67", kind = "Level", amount = 25, catalogId = 100498935359536, animationId = 108639244526475 },
	{ id = "E18", name = "Orange Justice", kind = "Coins", amount = 6500, catalogId = 110064349530772, animationId = 95127716920692 },
	{ id = "E19", name = "Dab Steps", kind = "Coins", amount = 4500, catalogId = 126353729413555, animationId = 104609460346094 },
	{ id = "E20", name = "Creepin Dance", kind = "Coins", amount = 5000, catalogId = 80985588930231, animationId = 95428460379424 },
	{ id = "E21", name = "Nervy Dance", kind = "Level", amount = 30, catalogId = 125328720114284, animationId = 90018336892195 },
	{ id = "E22", name = "Pretty Young Thing", kind = "Coins", amount = 7500, catalogId = 137234266130963, animationId = 108374677470972 },
	{ id = "E23", name = "Party Rock Anthem", kind = "Coins", amount = 10000, catalogId = 105248382902194, animationId = 134459607456762 },
	{ id = "E24", name = "Passinho do Jamal", kind = "Level", amount = 35, catalogId = 137057022541237, animationId = 100468196980144 },
	{ id = "E25", name = "Camden Bop", kind = "Coins", amount = 6000, catalogId = 86411651121424, animationId = 134644266320983 },
	{ id = "E26", name = "Every Beat", kind = "Level", amount = 40, catalogId = 134311528115559, animationId = 136095999219650 },
	{ id = "E27", name = "One Hand Push Ups", kind = "Coins", amount = 8000, catalogId = 121644855433565, animationId = 74800678690946 },
	{ id = "E28", name = "Gangnam Style", kind = "Coins", amount = 12500, catalogId = 80923445784018, animationId = 131104967711844 },
	{ id = "E29", name = "Murda Bend", kind = "Coins", amount = 9000, catalogId = 96843993997234, animationId = 90158235751747 },
	{ id = "E30", name = "Monkey", kind = "Level", amount = 3, catalogId = 3716636630, animationId = 10714388352 },
	{ id = "E31", name = "NLE Choppa Demon", kind = "Coins", amount = 15000, catalogId = 96181123599016, animationId = 133898543831391 },
	{ id = "E32", name = "Brazilian Dance", kind = "Level", amount = 50, catalogId = 76636280785091, animationId = 138980897636026 },
}) do
	local description = "Dance in the lobby. Move or jump to stop. Equip for your winner podium."
	local entry = item(dance.id, dance.name, "Emotes", "Emote", dance.kind, dance.amount, nil, description, {120, 193, 244})
	entry.catalogId = dance.catalogId
	entry.thumbnail = "rbxthumb://type=Asset&id=" .. string.format("%.0f", dance.catalogId) .. "&w=420&h=420"
	entry.playable = true
	entry.rigType = "R15"
	emoteAnimations[dance.id] = { R15AnimationId = dance.animationId }
	table.insert(items, entry)
end

local suppliedThumbnails = {
	["B01"] = "rbxassetid://103030924200276",
	["B02"] = "rbxassetid://113172886921867",
	["B03"] = "rbxassetid://125747852383163",
	["B04"] = "rbxassetid://127202176052176",
	["B05"] = "rbxassetid://96016591192959",
	["B06"] = "rbxassetid://128970507196840",
	["B07"] = "rbxassetid://108736504252281",
	["B08"] = "rbxassetid://89882889964123",
	["B09"] = "rbxassetid://77618462621016",
	["B10"] = "rbxassetid://132453529736998",
	["B11"] = "rbxassetid://77939197144871",
	["B12"] = "rbxassetid://125123911675366",
	["B13"] = "rbxassetid://103460237585059",
	["B14"] = "rbxassetid://123941198531759",
	["B15"] = "rbxassetid://103777401073836",
	["P01"] = "rbxassetid://111151667063771",
	["P02"] = "rbxassetid://74489993061441",
	["P03"] = "rbxassetid://79432424395104",
	["P04"] = "rbxassetid://84237840954591",
	["P05"] = "rbxassetid://76813277166260",
	["P06"] = "rbxassetid://128747986158558",
	["P07"] = "rbxassetid://130019925281001",
	["P08"] = "rbxassetid://122488839946964",
	["P09"] = "rbxassetid://72876142531984",
	["P10"] = "rbxassetid://83399670130730",
	["P11"] = "rbxassetid://138937113451446",
	["P12"] = "rbxassetid://91507747886254",
	["P13"] = "rbxassetid://76111324896677",
	["P14"] = "rbxassetid://74049460609660",
	["P15"] = "rbxassetid://71646045256380",
	["P16"] = "rbxassetid://74938519999469",
	["P17"] = "rbxassetid://74706180338952",
	["P18"] = "rbxassetid://115725394692957",
	["P19"] = "rbxassetid://117853703978463",
	["P20"] = "rbxassetid://113206048566146",
	["M01"] = "rbxassetid://76461123342040",
	["M02"] = "rbxassetid://87689116244271",
	["M03"] = "rbxassetid://102723663713155",
	["M04"] = "rbxassetid://108236395872604",
	["M05"] = "rbxassetid://135585921369557",
	["M06"] = "rbxassetid://100391547251774",
	["M07"] = "rbxassetid://114996802464499",
	["M08"] = "rbxassetid://93885559186954",
	["M09"] = "rbxassetid://95787089363505",
	["M10"] = "rbxassetid://86928317634247",
	["M11"] = "rbxassetid://78326564646666",
	["M12"] = "rbxassetid://108447275819300",
	["M13"] = "rbxassetid://115194745550655",
	["M14"] = "rbxassetid://120473663146818",
	["M15"] = "rbxassetid://91563971609941",
}
for _, entry in ipairs(items) do
	if suppliedThumbnails[entry.id] then
		entry.thumbnail = suppliedThumbnails[entry.id]
		entry.thumbnailSource = "UI-512"
	end
end

local byId = {}
for _, entry in ipairs(items) do
	assert(byId[entry.id] == nil, "Duplicate catalog ID: " .. entry.id)
	assert(entry.price >= 0 and entry.price <= (entry.slot == "Emote" and 15000 or 10000), "Catalog price exceeds the coin cap")
	byId[entry.id] = entry
end

byId.M09.toyActionPending = true

return {
	Items = items,
	ById = byId,
	Categories = { "All", "Bats", "Pets", "Toys", "Emotes" },
	EmoteAnimations = emoteAnimations,
	StarterBat = "B01",
	MaxCoinPrice = 15000,
	MaxEquipmentCoinPrice = 10000,
	MaxToySlots = 4,
	GameNames = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It", StuckInTheMud = "Stuck in the Mud", All = "total" },
}


]========]},
{path="ServerScriptService.PlaygroundEconomyService",before=[========[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local Catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))

local Economy = {}
Economy.__index = Economy
local slots = { Bat = true, Pet = true, Emote = true, Emoji = true, Trail = true, Highlight = true, Gear = true }
local actions = { GetStatus = true, Buy = true, Equip = true, Unequip = true, SelectToy = true, UseEmote = true, UseEmoji = true }
local ink = Color3.fromRGB(24, 35, 62)
local games = { BritishBulldog = true, TagYoureIt = true, StuckInTheMud = true }
local gamePrefixes = { BB = "BritishBulldog", TAG = "TagYoureIt", MUD = "StuckInTheMud" }
local adminLimits = table.freeze({ coinsPerGrant = 1000000, levelsPerGrant = 100, maxLevel = 1000, maxCoins = 1000000000 })
local coinPickupAmount = 5
local maxToySlots = 4

local function boundedInteger(value, minimum, maximum)
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= minimum and value <= maximum
end

local function integer(value, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(math.floor(value), 0, 1000000000)
end

local function timestamp(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return 0 end
	return math.clamp(math.floor(value), 0, 1000000000000)
end

local function isToy(item)
	return typeof(item) == "table" and item.category == "Toys" and item.slot == "Gear"
end

local function inGame(player)
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end

local function emoteDetails(data)
	if typeof(data) ~= "table" or typeof(data.Equipped) ~= "table" or typeof(data.Owned) ~= "table" then return nil end
	local id = data.Equipped.Emote
	local item = id and Catalog.ById[id]
	local animation = item and Catalog.EmoteAnimations[id]
	local animationId = animation and animation.R15AnimationId
	if not item or item.slot ~= "Emote" or item.available == false or item.playable ~= true
		or not data.Owned or data.Owned[id] ~= true or not boundedInteger(animationId, 1, 9007199254740991) then return nil end
	return { emoteId = id, emoteAnimationId = "rbxassetid://" .. string.format("%.0f", animationId), emoteRigType = "R15" }
end

local function stopEmote(player)
	player:SetAttribute("PCEmoteUntil", 0)
	player:SetAttribute("PCEmoteAction", "")
	player:SetAttribute("PCEmoteAnimationId", "")
end

local function cleanToyLoadout(equipped, owned)
	equipped = typeof(equipped) == "table" and equipped or {}
	local toys, seen = {}, {}
	local function add(id)
		local item = typeof(id) == "string" and Catalog.ById[id]
		if #toys < maxToySlots and isToy(item) and item.available ~= false and owned[id] == true and not seen[id] then
			seen[id] = true
			table.insert(toys, id)
		end
	end
	local active = typeof(equipped.Gear) == "string" and equipped.Gear or equipped.Toy
	if typeof(equipped.Toys) == "table" then
		if boundedInteger(equipped.ToyIndex, 1, 64) then active = equipped.Toys[equipped.ToyIndex] end
		for index = 1, 64 do
			add(equipped.Toys[index])
			if #toys == maxToySlots then break end
		end
	else
		add(equipped.Gear)
		if #toys == 0 then add(equipped.Toy) end
	end
	return toys, table.find(toys, active) or (#toys > 0 and 1 or 0)
end

local function setToyLoadout(data, toys, index)
	data.Equipped.Toys = toys
	data.Equipped.ToyIndex = index
	data.Equipped.Gear = toys[index]
	data.Equipped.Toy = toys[index]
end

local function equipToy(data, id)
	local toys = cleanToyLoadout(data.Equipped, data.Owned)
	local selected = table.find(toys, id)
	if not selected then
		if #toys >= maxToySlots then return false, "Your four toy slots are full. Unequip a toy first." end
		table.insert(toys, id)
		selected = #toys
	end
	setToyLoadout(data, toys, selected)
	return true
end

local function unequipToy(data, id)
	local toys, index = cleanToyLoadout(data.Equipped, data.Owned)
	local active = toys[index]
	local removed = table.find(toys, id)
	if not removed then return false, "That toy is not in your loadout." end
	table.remove(toys, removed)
	setToyLoadout(data, toys, table.find(toys, active) or math.min(index, #toys))
	return true
end

local function levelProgress(xp, base, step)
	xp = integer(xp, 0)
	base = math.max(1, integer(base, 100))
	step = integer(step, 50)
	local completed = 0
	local function cost(count) return count * base + step * count * (count - 1) / 2 end
	if step == 0 then
		completed = math.floor(xp / base)
	elseif xp > 0 then
		local linear = base - step / 2
		local root = math.sqrt(linear * linear + 2 * step * xp)
		completed = math.floor(linear >= 0 and 2 * xp / (root + linear) or (root - linear) / step)
		if cost(completed) > xp then completed = math.max(0, completed - 1) end
		if cost(completed + 1) <= xp then completed += 1 end
	end
	return completed + 1, xp - cost(completed), base + step * completed
end

local function cleanData(value)
	value = typeof(value) == "table" and value or {}
	local result = { Coins = integer(value.Coins, 0), Wins = integer(value.Wins, 0), XP = integer(value.XP, 0), Owned = {}, Equipped = {}, GameWins = {}, Version = 4 }
	for gameId in pairs(games) do
		result.GameWins[gameId] = integer(typeof(value.GameWins) == "table" and value.GameWins[gameId] or nil, 0)
	end
	if typeof(value.Owned) == "table" then
		for id, owned in pairs(value.Owned) do
			if typeof(id) == "string" and #id <= 48 and owned == true then result.Owned[id] = true end
		end
	end
	result.Owned[Catalog.StarterBat] = true
	if typeof(value.Equipped) == "table" then
		for slot, id in pairs(value.Equipped) do
			local item = typeof(id) == "string" and Catalog.ById[id]
			if slot ~= "Gear" and slots[slot] and typeof(id) == "string" and #id <= 48 and result.Owned[id] and (not item or item.slot == slot) then
				result.Equipped[slot] = id
			end
		end
	end
	local toys, toyIndex = cleanToyLoadout(value.Equipped, result.Owned)
	setToyLoadout(result, toys, toyIndex)
	if integer(value.Version, 0) < 3 and not result.Equipped.Bat then result.Equipped.Bat = Catalog.StarterBat end
	return result
end

local function unlockStatus(data, item, level)
	local rule = item.unlock or {}
	local kind = rule.kind
	local target = integer(rule.amount, 0)
	local owned = data.Owned[item.id] == true
	local progress, unlocked, label = 0, false, "Unavailable"
	if kind == "Starter" then
		unlocked, label = true, "Starter reward"
	elseif kind == "Coins" then
		progress, unlocked, label = integer(data.Coins, 0), true, tostring(item.price) .. " coins"
	elseif kind == "Level" then
		progress, label = level, "Level " .. target
		unlocked = progress >= target
	elseif kind == "Wins" and (rule.gameId == "All" or games[rule.gameId]) then
		progress = rule.gameId == "All" and integer(data.Wins, 0) or integer(data.GameWins and data.GameWins[rule.gameId], 0)
		label = target .. " " .. Catalog.GameNames[rule.gameId] .. " wins"
		unlocked = progress >= target
	end
	return {
		kind = kind, progress = progress, target = target, required = target,
		available = item.available ~= false and (owned or unlocked), unlocked = owned or unlocked,
		owned = owned, label = label,
		purchasable = kind == "Coins" and item.available ~= false and not owned and integer(data.Coins, 0) >= item.price,
	}
end

function Economy:_unlockRewards(profile)
	local level = self:LevelProgress(profile.data.XP)
	local awarded = {}
	for _, item in ipairs(Catalog.Items) do
		if item.available ~= false and item.unlock.kind ~= "Coins" and not profile.data.Owned[item.id] and unlockStatus(profile.data, item, level).unlocked then
			profile.data.Owned[item.id] = true
			table.insert(awarded, item.id)
		end
	end
	if #awarded > 0 then
		profile.newlyUnlocked = awarded
		profile.unlockSerial = (profile.unlockSerial or 0) + 1
	end
	return awarded
end

function Economy:_setting(name, fallback)
	return integer(self.lobby:GetAttribute(name), fallback)
end

function Economy:LevelProgress(xp)
	return levelProgress(xp, self:_setting("BaseLevelXP", 200), self:_setting("LevelXPStep", 50))
end

function Economy.new(lobby, storeOverride, studioOverride)
	local self = setmetatable({}, Economy)
	self.lobby = lobby
	self.bounds = lobby.Gameplay.LobbyBounds
	self.profiles = {}
	self.connections = {}
	self.awarded = {}
	self.podiumEmotes = {}
	self.podiumEmoteReads = 0
	self.isStudio = studioOverride == nil and RunService:IsStudio() or studioOverride
	self.sessionId = game.JobId .. ":" .. HttpService:GenerateGUID(false)
	self.store = storeOverride
	if not self.isStudio and not self.store then
		local ok, store = pcall(function() return DataStoreService:GetDataStore("PlaygroundClassics_Profiles_v1") end)
		if ok then self.store = store end
	end
	self.sessionOnly = not self.isStudio and self.store == nil
	self.assets = ReplicatedStorage:WaitForChild("PlaygroundCosmeticAssets")
	self.effects = Instance.new("Folder")
	self.effects.Name = "PlaygroundCosmeticEffects"
	self.effects.Parent = workspace
	self.hiddenCoins = Instance.new("Folder")
	self.hiddenCoins.Name = "PlaygroundCoinRespawns"
	self.hiddenCoins.Parent = ServerStorage
	self.coins = {}
	self.running = false
	self.elapsed = 0
	self.lastSave = os.clock()
	return self
end

function Economy:_sync(profile)
	local player = profile.player
	local toys, toyIndex = cleanToyLoadout(profile.data.Equipped, profile.data.Owned)
	setToyLoadout(profile.data, toys, toyIndex)
	profile.data.XP = integer(profile.data.XP, 0)
	local level, levelXP, requiredXP = self:LevelProgress(profile.data.XP)
	player:SetAttribute("PCCoins", profile.data.Coins)
	player:SetAttribute("PCWins", profile.data.Wins)
	player:SetAttribute("PCXP", profile.data.XP)
	player:SetAttribute("PCLevel", level)
	player:SetAttribute("PCLevelXP", levelXP)
	player:SetAttribute("PCLevelXPRequired", requiredXP)
	player:SetAttribute("PCInventoryVersion", profile.version or 0)
	player:SetAttribute("PCUnlockSerial", profile.unlockSerial or 0)
	for gameId in pairs(games) do player:SetAttribute("PCWins" .. gameId, profile.data.GameWins[gameId]) end
	player:SetAttribute("PCDataReady", profile.ready == true)
	player:SetAttribute("PCDataMode", self.isStudio and "Studio" or self.sessionOnly and "Session" or "Persistent")
	for slot in pairs(slots) do
		local id = profile.data.Equipped[slot]
		local item = id and Catalog.ById[id]
		player:SetAttribute("PC" .. slot, profile.ready == true and item and item.available ~= false and item.slot == slot and profile.data.Owned[id] == true and id or "")
	end
	local emote = profile.ready and emoteDetails(profile.data)
	player:SetAttribute("PCEquippedEmoteAnimationId", emote and emote.emoteAnimationId or "")
	player:SetAttribute("PCEquippedEmoteRigType", emote and emote.emoteRigType or "")
	for index = 1, maxToySlots do player:SetAttribute("PCToySlot" .. index, profile.ready == true and toys[index] or "") end
	player:SetAttribute("PCToy", profile.ready == true and toys[toyIndex] or "")
	player:SetAttribute("PCToyIndex", profile.ready == true and toyIndex or 0)
	player:SetAttribute("PCToyLoadoutVersion", profile.version or 0)
	local board = player:FindFirstChild("leaderstats")
	if board then
		local wins = board:FindFirstChild("Wins")
		local coins = board:FindFirstChild("Coins")
		local levelCounter = board:FindFirstChild("Level")
		if wins then wins.Value = profile.data.Wins end
		if coins then coins.Value = profile.data.Coins end
		if levelCounter then levelCounter.Value = level end
	end
end

function Economy:GetToyLoadout(player)
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then
		return { items = {}, activeIndex = 0, maxSlots = maxToySlots }
	end
	local toys, index = cleanToyLoadout(profile.data.Equipped, profile.data.Owned)
	return { items = toys, activeIndex = index, activeId = toys[index], maxSlots = maxToySlots }
end

function Economy:GetEquipped(player, slot)
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then return nil end
	if slot == "Gear" or slot == "Toy" then return self:GetToyLoadout(player).activeId end
	if typeof(slot) ~= "string" or not slots[slot] then return nil end
	local id = profile.data.Equipped[slot]
	local item = typeof(id) == "string" and Catalog.ById[id]
	return item and item.available ~= false and item.slot == slot and profile.data.Owned[id] == true and id or nil
end

function Economy:SelectToySlot(player, index)
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then return false, "Your items are still loading." end
	if inGame(player) then return false, "Toys are available in the lobby between rounds." end
	local toys, current = cleanToyLoadout(profile.data.Equipped, profile.data.Owned)
	if not boundedInteger(index, 1, maxToySlots) or not toys[index] then return false, "Choose a filled toy slot from 1 to 4." end
	if current ~= index then setToyLoadout(profile.data, toys, index) self:_touch(profile) end
	return true, "Selected " .. Catalog.ById[toys[index]].name .. "."
end

function Economy:_publishLeaderboard(userId, snapshot)
	if not self.leaderboards then return end
	local ok, err = pcall(function() self.leaderboards:PublishSaved(userId, snapshot) end)
	if not ok then warn("Leaderboard update delayed: " .. tostring(err)) end
end

function Economy:_claim(profile)
	if self.isStudio or self.sessionOnly then
		profile.data = cleanData({ Coins = self.isStudio and 150 or 0 })
		profile.ready = true
		return true
	end
	local ok, value = pcall(function()
		return self.store:UpdateAsync("u:" .. profile.player.UserId, function(old)
			old = typeof(old) == "table" and old or {}
			local lease = old.Session
			if typeof(lease) == "table" and lease.Id ~= self.sessionId and timestamp(lease.Expires) > os.time() then return nil end
			local data = cleanData(old)
			data.Session = { Id = self.sessionId, Expires = os.time() + 180 }
			return data
		end)
	end)
	if ok and typeof(value) == "table" and value.Session and value.Session.Id == self.sessionId then
		profile.data = cleanData(value)
		profile.ready = true
		self:_publishLeaderboard(profile.player.UserId, profile.data)
		return true
	end
	return false
end

function Economy:_save(profile, release)
	if self.isStudio or self.sessionOnly or not profile.ready or profile.released then return true end
	local untilTime = os.clock() + 8
	while profile.saving and os.clock() < untilTime do task.wait(0.1) end
	if profile.released then return true end
	if profile.saving then return false end
	profile.saving = true
	local version = profile.version
	local snapshot = cleanData(profile.data)
	local saved = false
	for attempt = 1, 3 do
		local ok, value = pcall(function()
			return self.store:UpdateAsync("u:" .. profile.player.UserId, function(old)
				if typeof(old) ~= "table" or typeof(old.Session) ~= "table" or old.Session.Id ~= self.sessionId then return nil end
				local data = cleanData(snapshot)
				if not release then data.Session = { Id = self.sessionId, Expires = os.time() + 180 } end
				return data
			end)
		end)
		if ok and typeof(value) == "table" then saved = true break end
		if ok and value == nil then
			profile.ready = false
			self:_sync(profile)
			break
		end
		if attempt < 3 then task.wait(attempt) end
	end
	profile.saving = false
	if saved and release then profile.released = true end
	if saved and version == profile.version then profile.dirty = false end
	if saved then self:_publishLeaderboard(profile.player.UserId, snapshot) end
	if not saved then warn("Playground profile save is pending for user " .. profile.player.UserId) end
	return saved
end

function Economy:_touch(profile)
	if profile.ready then self:_unlockRewards(profile) end
	profile.version += 1
	profile.dirty = true
	self:_sync(profile)
end

function Economy:_clearAppearance(profile)
	if profile.pet then profile.pet:Destroy() profile.pet = nil end
	local character = profile.player.Character
	if character then
		for _, name in ipairs({ "PCOutline", "PCTrail", "PCTrailTop", "PCTrailBottom" }) do
			local object = character:FindFirstChild(name, true)
			if object then object:Destroy() end
		end
	end
end

function Economy:_applyAppearance(profile)
	self:_clearAppearance(profile)
	local character = profile.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not profile.ready or profile.closed then return end
	local equipped = {}
	for slot, id in pairs(profile.data.Equipped) do
		local item = Catalog.ById[id]
		if item and item.available ~= false and item.slot == slot and profile.data.Owned[id] then equipped[slot] = id end
	end
	local outlineItem = Catalog.ById[equipped.Highlight]
	if outlineItem then
		local outline = Instance.new("Highlight")
		outline.Name = "PCOutline"
		outline.Adornee = character
		outline.FillTransparency = 1
		outline.OutlineTransparency = 0
		outline.OutlineColor = outlineItem.color
		outline.Enabled = not (profile.player:GetAttribute("BBParticipating") == true or (profile.player:GetAttribute("TGParticipating") == true or profile.player:GetAttribute("MDParticipating") == true))
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = character
	end
	local trailItem = Catalog.ById[equipped.Trail]
	if trailItem then
		local top = Instance.new("Attachment")
		top.Name = "PCTrailTop"
		top.Position = Vector3.new(0, 0.6, 1)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "PCTrailBottom"
		bottom.Position = Vector3.new(0, -0.8, 1)
		bottom.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "PCTrail"
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Color = equipped.Trail == "RainbowTrail" and ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 93, 124)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 219, 64)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(75, 213, 178)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(118, 126, 255)),
		}) or ColorSequence.new(trailItem.color, Color3.fromRGB(255, 94, 139))
		trail.Lifetime = 0.55
		trail.MinLength = 0.2
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.FaceCamera = true
		trail.Parent = root
	end
end

function Economy:_bindPlayer(player)
	if self.profiles[player] then return end
	local profile = { player = player, data = cleanData(nil), ready = false, version = 0, pickups = {}, connections = {}, lastMutation = -math.huge, lastStatus = -math.huge, lastExpression = -math.huge }
	self.profiles[player] = profile
	local board = player:FindFirstChild("leaderstats")
	if not board then board = Instance.new("Folder") board.Name = "leaderstats" board.Parent = player end
	for _, name in ipairs({ "Wins", "Level", "Coins" }) do
		if not board:FindFirstChild(name) then local counter = Instance.new("IntValue") counter.Name = name counter.Parent = board end
	end
	self:_sync(profile)
	for _, attribute in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating" }) do
		table.insert(profile.connections, player:GetAttributeChangedSignal(attribute):Connect(function()
			if inGame(player) then stopEmote(player) end
		end))
	end
	table.insert(profile.connections, player.CharacterAdded:Connect(function(character)
		stopEmote(player)
		task.spawn(function()
			character:WaitForChild("HumanoidRootPart", 10)
			if self.profiles[player] == profile and character == player.Character and not profile.closed then self:_applyAppearance(profile) end
		end)
	end))
	task.spawn(function()
		while self.running and self.profiles[player] == profile and player.Parent == Players and not profile.ready do
			if self:_claim(profile) then
				if self.profiles[player] == profile and player.Parent == Players and not profile.closed then
					self:_touch(profile)
					self:_applyAppearance(profile)
				else
					self:_save(profile, true)
				end
				break
			end
			task.wait(10)
		end
	end)
end

function Economy:Status(player, ok, message)
	local profile = self.profiles[player]
	local xp = profile and integer(profile.data.XP, 0) or 0
	local level, levelXP, requiredXP = self:LevelProgress(xp)
	local ready = profile ~= nil and profile.ready == true and not profile.closed and not profile.released
	local data = profile and profile.data or cleanData(nil)
	local loadout = self:GetToyLoadout(player)
	local equipped = table.clone(data.Equipped)
	equipped.Toys, equipped.ToyIndex = table.clone(loadout.items), loadout.activeIndex
	equipped.Gear, equipped.Toy = loadout.activeId, loadout.activeId
	local unlocks = {}
	for _, item in ipairs(Catalog.Items) do
		local status = unlockStatus(data, item, level)
		status.purchasable = ready and status.purchasable or false
		unlocks[item.id] = status
	end
	return {
		ok = ok, message = message or "", coins = data.Coins, wins = data.Wins,
		xp = xp, level = level, levelXP = levelXP, levelXPRequired = requiredXP,
		owned = table.clone(data.Owned), equipped = equipped, toyLoadout = loadout, ready = ready,
		gameWins = table.clone(data.GameWins), winsByGame = table.clone(data.GameWins), unlocks = unlocks,
		newlyUnlocked = profile and table.clone(profile.newlyUnlocked or {}) or {},
		unlockSerial = profile and profile.unlockSerial or 0,
		inventoryVersion = profile and profile.version or 0,
	}
end

function Economy:Handle(player, action, id)
	local profile = self.profiles[player]
	if not profile or profile.closed or profile.released or not profile.ready then return self:Status(player, false, "Your items are still loading.") end
	if typeof(action) ~= "string" or not actions[action] then return self:Status(player, false, "Unknown shop control.") end
	local now = os.clock()
	local key = action == "GetStatus" and "lastStatus" or "lastMutation"
	if now - profile[key] < (action == "GetStatus" and 0.1 or 0.35) then return self:Status(player, false, "Please wait a moment.") end
	profile[key] = now
	if action == "GetStatus" then return self:Status(player, true) end
	if action == "SelectToy" then
		local selected, message = self:SelectToySlot(player, id)
		return self:Status(player, selected, message)
	end
	if action == "Unequip" then
		local toy = typeof(id) == "string" and Catalog.ById[id]
		if id == "Gear" or id == "Toy" or isToy(toy) then
			if inGame(player) then return self:Status(player, false, "Toys are available in the lobby between rounds.") end
			local toyId = isToy(toy) and id or self:GetToyLoadout(player).activeId
			local removed, reason = unequipToy(profile.data, toyId)
			if not removed then return self:Status(player, false, reason) end
			self:_touch(profile)
			return self:Status(player, true, "Toy removed from your loadout.")
		end
		if typeof(id) ~= "string" or not slots[id] then return self:Status(player, false, "Choose an item first.") end
		if id == "Emote" then stopEmote(player) end
		profile.data.Equipped[id] = nil
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Unequipped.")
	end
	local item = typeof(id) == "string" and Catalog.ById[id]
	if not item or item.available == false then return self:Status(player, false, "This item is unavailable.") end
	if item.slot == "Emote" and (item.playable ~= true or not Catalog.EmoteAnimations[id]) then return self:Status(player, false, "This emote is not available to play.") end
	if action == "Buy" then
		if profile.data.Owned[id] then return self:Status(player, false, "You already own this.") end
		if item.unlock.kind ~= "Coins" then
			local status = unlockStatus(profile.data, item, self:LevelProgress(profile.data.XP))
			return self:Status(player, false, "Earn this reward: " .. status.label .. ".")
		end
		if profile.data.Coins < item.price then return self:Status(player, false, "Collect a few more coins first.") end
		profile.data.Coins -= item.price
		profile.data.Owned[id] = true
		local equipped, reason = true, nil
		if isToy(item) then
			if inGame(player) then equipped, reason = false, "Equip it in the lobby between rounds."
			else equipped, reason = equipToy(profile.data, id) end
		else profile.data.Equipped[item.slot] = id end
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, item.name .. " is yours!" .. (not equipped and " " .. reason or ""))
	end
	if not profile.data.Owned[id] then return self:Status(player, false, "You don't own this yet.") end
	if action == "Equip" then
		if item.slot == "Emote" then stopEmote(player) end
		if isToy(item) then
			if inGame(player) then return self:Status(player, false, "Toys are available in the lobby between rounds.") end
			local equipped, reason = equipToy(profile.data, id)
			if not equipped then return self:Status(player, false, reason) end
		else profile.data.Equipped[item.slot] = id end
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Equipped " .. item.name .. ".")
	end
	if action == "UseEmote" or action == "UseEmoji" then
		if now - profile.lastExpression < 4 then return self:Status(player, false, "Give it a moment.") end
		if player:GetAttribute("BBParticipating") or (player:GetAttribute("TGParticipating") or player:GetAttribute("MDParticipating")) then return self:Status(player, false, "Try this between rounds.") end
		if action == "UseEmote" then
			if item.slot ~= "Emote" then return self:Status(player, false, "Choose an emote.") end
			local character = player.Character
			if character and ((character:GetAttribute("PCToyHeld") or "") ~= "" or character:GetAttribute("PCBatHeld") == true) then
				return self:Status(player, false, "Put your toy away to dance.")
			end
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoid or not rootPart or humanoid.Health <= 0 then return self:Status(player, false, "Your character is not ready.") end
			if humanoid.RigType ~= Enum.HumanoidRigType.R15 then return self:Status(player, false, "These dances need an R15 avatar.") end
			if not self:_inside(rootPart.Position) then return self:Status(player, false, "Dance in the lobby between rounds.") end
			if humanoid.MoveDirection.Magnitude > 0.1 or humanoid.Sit or humanoid.FloorMaterial == Enum.Material.Air then
				return self:Status(player, false, "Stand still on the ground to dance.")
			end
			local animation = Catalog.EmoteAnimations[id]
			if not animation or not boundedInteger(animation.R15AnimationId, 1, 9007199254740991) then return self:Status(player, false, "This emote is unavailable.") end
			local startedAt = workspace:GetServerTimeNow()
			profile.lastExpression = now
			player:SetAttribute("PCEmoteAction", id)
			player:SetAttribute("PCEmoteAnimationId", "rbxassetid://" .. string.format("%.0f", animation.R15AnimationId))
			player:SetAttribute("PCEmoteRigType", "R15")
			player:SetAttribute("PCEmoteStartedAt", startedAt)
			player:SetAttribute("PCEmoteUntil", startedAt + 30)
			player:SetAttribute("PCEmoteSerial", integer(player:GetAttribute("PCEmoteSerial"), 0) + 1)
			return self:Status(player, true, "Move or jump to stop dancing.")
		end
		profile.lastExpression = now
		if item.slot ~= "Emoji" then return self:Status(player, false, "Choose an emoji.") end
		local head = player.Character and player.Character:FindFirstChild("Head")
		if not head then return self:Status(player, false, "Your character is loading.") end
		local bubble = Instance.new("BillboardGui")
		bubble.Name = "PCEmojiBubble"
		bubble.Size = UDim2.fromOffset(80, 80)
		bubble.StudsOffset = Vector3.new(0, 3.5, 0)
		bubble.AlwaysOnTop = false
		bubble.Adornee = head
		bubble.Parent = head
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = item.emoji
		text.TextColor3 = item.color
		text.TextStrokeColor3 = ink
		text.TextStrokeTransparency = 0
		text.TextScaled = true
		text.Parent = bubble
		Debris:AddItem(bubble, 2.5)
		return self:Status(player, true)
	end
	return self:Status(player, false, "Unknown shop control.")
end

function Economy:_publishReward(profile, coins, xp, won, roundReward)
	local player = profile.player
	profile.rewardSerial = (profile.rewardSerial or 0) + 1
	player:SetAttribute("PCRewardCoins", coins)
	player:SetAttribute("PCRewardXP", xp)
	player:SetAttribute("PCRewardWon", won == true)
	local message = "+" .. coins .. " coins"
	if roundReward then message ..= " · +" .. xp .. " XP · " .. (won and "Round won!" or "Round complete") end
	player:SetAttribute("PCRewardText", message)
	player:SetAttribute("PCRewardSerial", profile.rewardSerial)
	player:SetAttribute("PCRewardAt", workspace:GetServerTimeNow())
end

function Economy:GetPodiumEmote(userId)
	if not boundedInteger(userId, 1, 1000000000000) then return nil end
	local profile = self:_profileByUserId(userId)
	if profile then
		return profile.ready and not profile.closed and not profile.released and emoteDetails(profile.data) or nil
	end
	local cached = self.podiumEmotes[userId]
	local now = os.clock()
	if cached and (cached.busy or cached.expires > now) then return cached.value end
	if self.isStudio or not self.store or self.podiumEmoteReads >= 2 then return cached and cached.value end
	local record = cached or {}
	record.busy = true
	self.podiumEmotes[userId] = record
	self.podiumEmoteReads += 1
	task.spawn(function()
		local ok, data = pcall(function() return self.store:GetAsync("u:" .. userId) end)
		self.podiumEmoteReads -= 1
		record.busy = false
		record.expires = os.clock() + (ok and 120 or 30)
		if ok then record.value = emoteDetails(data) end
	end)
	return record.value
end

function Economy:_profileByUserId(id)
	for player, profile in pairs(self.profiles) do
		if player.UserId == id and player.Parent == Players then return profile end
	end
	return nil
end

function Economy:_adminProfile(player)
	if not player or player.Parent ~= Players then return nil, "That player is no longer in this server." end
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then return nil, "That player's data is not ready." end
	return profile
end

function Economy:AdminGrantItem(player, id, equip)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	local item = typeof(id) == "string" and #id <= 48 and Catalog.ById[id]
	if not item or item.available == false or not slots[item.slot] then return false, "Choose an available catalog item." end
	if equip ~= nil and typeof(equip) ~= "boolean" then return false, "Equip must be on or off." end
	local alreadyOwned = profile.data.Owned[id] == true
	if alreadyOwned and not equip then return false, "That player already owns " .. item.name .. "." end
	profile.data.Owned[id] = true
	local didEquip, equipReason = equip, nil
	if equip then
		if isToy(item) then
			if inGame(player) then didEquip, equipReason = false, "Equip it in the lobby between rounds."
			else didEquip, equipReason = equipToy(profile.data, id) end
		else profile.data.Equipped[item.slot] = id end
	end
	if alreadyOwned and equip and not didEquip then return false, equipReason end
	self:_touch(profile)
	if didEquip then self:_applyAppearance(profile) end
	return true, (alreadyOwned and "Equipped " or didEquip and "Granted and equipped " or "Granted ") .. item.name .. "." .. (equipReason and " " .. equipReason or "")
end

function Economy:AdminGrantCoins(player, amount)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	if not boundedInteger(amount, 1, adminLimits.coinsPerGrant) then return false, "Add a whole number from 1 to " .. adminLimits.coinsPerGrant .. " coins." end
	local balance = integer(profile.data.Coins, 0)
	if balance + amount > adminLimits.maxCoins then return false, "That grant would exceed the coin balance limit." end
	profile.data.Coins = balance + amount
	self:_touch(profile)
	self:_publishReward(profile, amount, 0, false, false)
	return true, "Added " .. amount .. " coins."
end

function Economy:AdminAddLevels(player, amount)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	if not boundedInteger(amount, 1, adminLimits.levelsPerGrant) then return false, "Add a whole number from 1 to " .. adminLimits.levelsPerGrant .. " levels." end
	local level, progress = self:LevelProgress(profile.data.XP)
	local targetLevel = level + amount
	if targetLevel > adminLimits.maxLevel then return false, "Admin level grants can reach level " .. adminLimits.maxLevel .. " at most." end
	local completed = targetLevel - 1
	local base = math.max(1, self:_setting("BaseLevelXP", 200))
	local step = self:_setting("LevelXPStep", 50)
	local targetXP = completed * base + step * completed * (completed - 1) / 2 + progress
	if not boundedInteger(targetXP, 0, 1000000000) then return false, "That grant would exceed the XP limit." end
	profile.data.XP = targetXP
	self:_touch(profile)
	return true, "Added " .. amount .. " " .. (amount == 1 and "level" or "levels") .. ". Now level " .. targetLevel .. "."
end

function Economy:AwardRound(key, winnerIds, practice, participantIds, rewardOptions)
	if practice or typeof(key) ~= "string" or #key > 96 or self.awarded[key] or typeof(winnerIds) ~= "table" or typeof(participantIds) ~= "table" then return 0 end
	local participants, winners = {}, {}
	local function validId(id) return typeof(id) == "number" and id == id and id % 1 == 0 and math.abs(id) <= 1000000000000 end
	for _, id in ipairs(participantIds) do if validId(id) then participants[id] = true end end
	for _, id in ipairs(winnerIds) do if validId(id) and participants[id] then winners[id] = true end end
	if next(participants) == nil then return 0 end
	self.awarded[key] = true
	local gameId = typeof(rewardOptions) == "table" and rewardOptions.gameId or nil
	if not games[gameId] then gameId = gamePrefixes[string.match(key, "^(%a+):")] end
	local rewarded = 0
	for id in pairs(participants) do
		local profile = self:_profileByUserId(id)
		if profile and profile.ready and not profile.closed and not profile.released then
			local won = winners[id] == true
			local coins = self:_setting(won and "WinnerCoins" or "LoserCoins", won and 150 or 50)
			local xp = self:_setting(won and "WinnerXP" or "LoserXP", 50)
			if typeof(rewardOptions) == "table" then xp = integer(won and rewardOptions.winnerXP or rewardOptions.loserXP, xp) end
			local beforeCoins = integer(profile.data.Coins, 0)
			local beforeXP = integer(profile.data.XP, 0)
			profile.data.Coins = integer(beforeCoins + coins, 0)
			profile.data.XP = integer(beforeXP + xp, 0)
			if won then
				profile.data.Wins = integer(profile.data.Wins + 1, 0)
				if games[gameId] then profile.data.GameWins[gameId] = integer(profile.data.GameWins[gameId] + 1, 0) end
			end
			self:_touch(profile)
			self:_publishReward(profile, profile.data.Coins - beforeCoins, profile.data.XP - beforeXP, won, true)
			rewarded += 1
		end
	end
	return rewarded
end

function Economy:_inside(position)
	local point = self.bounds.CFrame:PointToObjectSpace(position)
	local half = self.bounds.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Economy:_buildCoins()
	local template = self.assets:FindFirstChild("C01")
	for _, marker in ipairs(self.lobby.Gameplay.CoinSpawns:GetChildren()) do
		if marker:IsA("BasePart") then
			local coin
			if template and (template:IsA("Model") or template:IsA("BasePart")) then
				coin = template:Clone()
				if coin:IsA("Model") then
					local _, size = coin:GetBoundingBox()
					local extent = math.max(size.X, size.Y, size.Z)
					if extent > 0 then coin:ScaleTo(coin:GetScale() * 2.8 / extent) end
				else
					coin.Size *= 2.8 / math.max(coin.Size.X, coin.Size.Y, coin.Size.Z)
				end
			else
				coin = Instance.new("Part")
				coin.Shape = Enum.PartType.Cylinder
				coin.Size = Vector3.new(0.65, 2.8, 2.8)
				coin.Color = Color3.fromRGB(255, 207, 59)
				coin.Material = Enum.Material.SmoothPlastic
			end
			coin.Name = "Coin_" .. marker.Name
			local parts = coin:GetDescendants()
			table.insert(parts, coin)
			for _, object in ipairs(parts) do
				if object:IsA("BasePart") then
					object.Anchored = true
					object.CanCollide = false
					object.CanTouch = false
					object.CanQuery = false
				elseif object:IsA("LuaSourceContainer") then object:Destroy() end
			end
			coin:PivotTo(marker.CFrame)
			coin.Parent = self.effects
			table.insert(self.coins, {
				id = marker:GetAttribute("PickupId") or marker.Name,
				value = coinPickupAmount,
				cooldown = math.clamp(integer(marker:GetAttribute("RespawnSeconds"), 45), 15, 300),
				marker = marker, visual = coin, availableAt = 0,
			})
		end
	end
end

function Economy:_collectCoin(profile, coin, now)
	local player = profile.player
	if self.profiles[player] ~= profile or player.Parent ~= Players or not profile.ready or profile.closed or profile.released
		or now < coin.availableAt or coin.visual.Parent ~= self.effects or not coin.marker.Parent then return false end
	if player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true then return false end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or not self:_inside(root.Position)
		or (root.Position - coin.marker.Position).Magnitude > 5.5 then return false end
	local beforeCoins = integer(profile.data.Coins, 0)
	if beforeCoins > adminLimits.maxCoins - coinPickupAmount then return false end
	local position = coin.visual:GetPivot().Position
	coin.availableAt = now + coin.cooldown
	coin.visual.Parent = self.hiddenCoins
	profile.data.Coins = beforeCoins + coinPickupAmount
	self:_touch(profile)
	profile.pickupSerial = math.max(profile.pickupSerial or 0, integer(player:GetAttribute("PCCoinPickupSerial"), 0)) + 1
	player:SetAttribute("PCCoinPickupAmount", coinPickupAmount)
	player:SetAttribute("PCCoinPickupPosition", position)
	player:SetAttribute("PCCoinPickupSerial", profile.pickupSerial)
	return true
end

function Economy:_tick(dt)
	self.elapsed += dt
	if self.elapsed < 0.15 then return end
	self.elapsed = 0
	local now = workspace:GetServerTimeNow()
	for _, coin in ipairs(self.coins) do
		if coin.marker.Parent and coin.visual.Parent and now >= coin.availableAt then
			coin.visual:PivotTo(coin.marker.CFrame * CFrame.new(0, math.sin(now * 2 + #tostring(coin.id)) * 0.3, 0) * CFrame.Angles(0, now, 0))
			coin.visual.Parent = self.effects
		end
	end
	for player, profile in pairs(self.profiles) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and profile.ready and not profile.closed and not profile.released then
			local participating = player:GetAttribute("BBParticipating") == true or (player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true)
			local outline = character:FindFirstChild("PCOutline")
			if outline then
				outline.Enabled = not participating
				if profile.data.Equipped.Highlight == "RainbowOutline" then outline.OutlineColor = Color3.fromHSV(now * 0.12 % 1, 0.72, 1) end
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not participating and humanoid and humanoid.Health > 0 and self:_inside(root.Position) then
				for _, coin in ipairs(self.coins) do
					self:_collectCoin(profile, coin, now)
				end
			end
		end
	end
	if os.clock() - self.lastSave >= 60 then
		self.lastSave = os.clock()
		for _, profile in pairs(self.profiles) do task.spawn(function() self:_save(profile, false) end) end
	end
end

function Economy:Start()
	if self.running then return end
	self.running = true
	self:_buildCoins()
	local remote = ReplicatedStorage:WaitForChild("PlaygroundShopRequest")
	remote.OnServerInvoke = function(player, action, id) return self:Handle(player, action, id) end
	self.remote = remote
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_bindPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		local profile = self.profiles[player]
		if not profile then return end
		profile.closed = true
		for _, connection in ipairs(profile.connections) do connection:Disconnect() end
		self:_clearAppearance(profile)
		self:_save(profile, true)
		self.profiles[player] = nil
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_bindPlayer(player) end
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self:_tick(dt) end))
	for _, attributeName in ipairs({"BaseLevelXP", "LevelXPStep"}) do
		table.insert(self.connections, self.lobby:GetAttributeChangedSignal(attributeName):Connect(function()
			for _, profile in pairs(self.profiles) do if profile.ready and not profile.closed then self:_touch(profile) end end
		end))
	end
	game:BindToClose(function()
		local pending = 0
		for _, profile in pairs(self.profiles) do
			profile.closed = true
			pending += 1
			task.spawn(function() self:_save(profile, true) pending -= 1 end)
		end
		local untilTime = os.clock() + 25
		while pending > 0 and os.clock() < untilTime do task.wait(0.1) end
		if pending == 0 and self.leaderboards then
			pcall(function() self.leaderboards:Flush(2) end)
		end
	end)
end

function Economy:Stop()
	self.running = false
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
	for _, profile in pairs(self.profiles) do profile.closed = true end
	for _, profile in pairs(self.profiles) do
		for _, connection in ipairs(profile.connections) do connection:Disconnect() end
		self:_clearAppearance(profile)
		self:_save(profile, true)
	end
	self.effects:Destroy()
	self.hiddenCoins:Destroy()
	table.clear(self.profiles)
end

Economy.CleanData = cleanData
Economy.CalculateLevelProgress = levelProgress
Economy.EvaluateUnlock = unlockStatus
Economy.AdminLimits = adminLimits
return Economy


]========],after=[========[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local Catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))

local Economy = {}
Economy.__index = Economy
local slots = { Bat = true, Pet = true, Emote = true, Emoji = true, Trail = true, Highlight = true, Gear = true }
local actions = { GetStatus = true, Buy = true, Equip = true, Unequip = true, SelectToy = true, UseEmote = true, StopEmote = true, UseEmoji = true }
local ink = Color3.fromRGB(24, 35, 62)
local games = { BritishBulldog = true, TagYoureIt = true, StuckInTheMud = true }
local gamePrefixes = { BB = "BritishBulldog", TAG = "TagYoureIt", MUD = "StuckInTheMud" }
local adminLimits = table.freeze({ coinsPerGrant = 1000000, levelsPerGrant = 100, maxLevel = 1000, maxCoins = 1000000000 })
local coinPickupAmount = 5
local maxToySlots = 4

local function boundedInteger(value, minimum, maximum)
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= minimum and value <= maximum
end

local function integer(value, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(math.floor(value), 0, 1000000000)
end

local function timestamp(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return 0 end
	return math.clamp(math.floor(value), 0, 1000000000000)
end

local function isToy(item)
	return typeof(item) == "table" and item.category == "Toys" and item.slot == "Gear"
end

local function inGame(player)
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end

local function emoteDetails(data)
	if typeof(data) ~= "table" or typeof(data.Equipped) ~= "table" or typeof(data.Owned) ~= "table" then return nil end
	local id = data.Equipped.Emote
	local item = id and Catalog.ById[id]
	local animation = item and Catalog.EmoteAnimations[id]
	local animationId = animation and animation.R15AnimationId
	if not item or item.slot ~= "Emote" or item.available == false or item.playable ~= true
		or not data.Owned or data.Owned[id] ~= true or not boundedInteger(animationId, 1, 9007199254740991) then return nil end
	return { emoteId = id, emoteAnimationId = "rbxassetid://" .. string.format("%.0f", animationId), emoteRigType = "R15" }
end

local function stopEmote(player)
	player:SetAttribute("PCEmoteUntil", 0)
	player:SetAttribute("PCEmoteAction", "")
	player:SetAttribute("PCEmoteAnimationId", "")
end

local function cleanToyLoadout(equipped, owned)
	equipped = typeof(equipped) == "table" and equipped or {}
	local toys, seen = {}, {}
	local function add(id)
		local item = typeof(id) == "string" and Catalog.ById[id]
		if #toys < maxToySlots and isToy(item) and item.available ~= false and owned[id] == true and not seen[id] then
			seen[id] = true
			table.insert(toys, id)
		end
	end
	local active = typeof(equipped.Gear) == "string" and equipped.Gear or equipped.Toy
	if typeof(equipped.Toys) == "table" then
		if boundedInteger(equipped.ToyIndex, 1, 64) then active = equipped.Toys[equipped.ToyIndex] end
		for index = 1, 64 do
			add(equipped.Toys[index])
			if #toys == maxToySlots then break end
		end
	else
		add(equipped.Gear)
		if #toys == 0 then add(equipped.Toy) end
	end
	return toys, table.find(toys, active) or (#toys > 0 and 1 or 0)
end

local function setToyLoadout(data, toys, index)
	data.Equipped.Toys = toys
	data.Equipped.ToyIndex = index
	data.Equipped.Gear = toys[index]
	data.Equipped.Toy = toys[index]
end

local function equipToy(data, id)
	local toys = cleanToyLoadout(data.Equipped, data.Owned)
	local selected = table.find(toys, id)
	if not selected then
		if #toys >= maxToySlots then return false, "Your four toy slots are full. Unequip a toy first." end
		table.insert(toys, id)
		selected = #toys
	end
	setToyLoadout(data, toys, selected)
	return true
end

local function unequipToy(data, id)
	local toys, index = cleanToyLoadout(data.Equipped, data.Owned)
	local active = toys[index]
	local removed = table.find(toys, id)
	if not removed then return false, "That toy is not in your loadout." end
	table.remove(toys, removed)
	setToyLoadout(data, toys, table.find(toys, active) or math.min(index, #toys))
	return true
end

local function levelProgress(xp, base, step)
	xp = integer(xp, 0)
	base = math.max(1, integer(base, 100))
	step = integer(step, 50)
	local completed = 0
	local function cost(count) return count * base + step * count * (count - 1) / 2 end
	if step == 0 then
		completed = math.floor(xp / base)
	elseif xp > 0 then
		local linear = base - step / 2
		local root = math.sqrt(linear * linear + 2 * step * xp)
		completed = math.floor(linear >= 0 and 2 * xp / (root + linear) or (root - linear) / step)
		if cost(completed) > xp then completed = math.max(0, completed - 1) end
		if cost(completed + 1) <= xp then completed += 1 end
	end
	return completed + 1, xp - cost(completed), base + step * completed
end

local function cleanData(value)
	value = typeof(value) == "table" and value or {}
	local result = { Coins = integer(value.Coins, 0), Wins = integer(value.Wins, 0), XP = integer(value.XP, 0), Owned = {}, Equipped = {}, GameWins = {}, Version = 4 }
	for gameId in pairs(games) do
		result.GameWins[gameId] = integer(typeof(value.GameWins) == "table" and value.GameWins[gameId] or nil, 0)
	end
	if typeof(value.Owned) == "table" then
		for id, owned in pairs(value.Owned) do
			if typeof(id) == "string" and #id <= 48 and owned == true then result.Owned[id] = true end
		end
	end
	result.Owned[Catalog.StarterBat] = true
	if typeof(value.Equipped) == "table" then
		for slot, id in pairs(value.Equipped) do
			local item = typeof(id) == "string" and Catalog.ById[id]
			if slot ~= "Gear" and slots[slot] and typeof(id) == "string" and #id <= 48 and result.Owned[id] and (not item or item.slot == slot) then
				result.Equipped[slot] = id
			end
		end
	end
	local toys, toyIndex = cleanToyLoadout(value.Equipped, result.Owned)
	setToyLoadout(result, toys, toyIndex)
	if integer(value.Version, 0) < 3 and not result.Equipped.Bat then result.Equipped.Bat = Catalog.StarterBat end
	return result
end

local function unlockStatus(data, item, level)
	local rule = item.unlock or {}
	local kind = rule.kind
	local target = integer(rule.amount, 0)
	local owned = data.Owned[item.id] == true
	local progress, unlocked, label = 0, false, "Unavailable"
	if kind == "Starter" then
		unlocked, label = true, "Starter reward"
	elseif kind == "Coins" then
		progress, unlocked, label = integer(data.Coins, 0), true, tostring(item.price) .. " coins"
	elseif kind == "Level" then
		progress, label = level, "Level " .. target
		unlocked = progress >= target
	elseif kind == "Wins" and (rule.gameId == "All" or games[rule.gameId]) then
		progress = rule.gameId == "All" and integer(data.Wins, 0) or integer(data.GameWins and data.GameWins[rule.gameId], 0)
		label = target .. " " .. Catalog.GameNames[rule.gameId] .. " wins"
		unlocked = progress >= target
	end
	return {
		kind = kind, progress = progress, target = target, required = target,
		available = item.available ~= false and (owned or unlocked), unlocked = owned or unlocked,
		owned = owned, label = label,
		purchasable = kind == "Coins" and item.available ~= false and not owned and integer(data.Coins, 0) >= item.price,
	}
end

function Economy:_unlockRewards(profile)
	local level = self:LevelProgress(profile.data.XP)
	local awarded = {}
	for _, item in ipairs(Catalog.Items) do
		if item.available ~= false and item.unlock.kind ~= "Coins" and not profile.data.Owned[item.id] and unlockStatus(profile.data, item, level).unlocked then
			profile.data.Owned[item.id] = true
			table.insert(awarded, item.id)
		end
	end
	if #awarded > 0 then
		profile.newlyUnlocked = awarded
		profile.unlockSerial = (profile.unlockSerial or 0) + 1
	end
	return awarded
end

function Economy:_setting(name, fallback)
	return integer(self.lobby:GetAttribute(name), fallback)
end

function Economy:LevelProgress(xp)
	return levelProgress(xp, self:_setting("BaseLevelXP", 200), self:_setting("LevelXPStep", 50))
end

function Economy.new(lobby, storeOverride, studioOverride)
	local self = setmetatable({}, Economy)
	self.lobby = lobby
	self.bounds = lobby.Gameplay.LobbyBounds
	self.profiles = {}
	self.connections = {}
	self.awarded = {}
	self.podiumEmotes = {}
	self.podiumEmoteReads = 0
	self.isStudio = studioOverride == nil and RunService:IsStudio() or studioOverride
	self.sessionId = game.JobId .. ":" .. HttpService:GenerateGUID(false)
	self.store = storeOverride
	if not self.isStudio and not self.store then
		local ok, store = pcall(function() return DataStoreService:GetDataStore("PlaygroundClassics_Profiles_v1") end)
		if ok then self.store = store end
	end
	self.sessionOnly = not self.isStudio and self.store == nil
	self.assets = ReplicatedStorage:WaitForChild("PlaygroundCosmeticAssets")
	self.effects = Instance.new("Folder")
	self.effects.Name = "PlaygroundCosmeticEffects"
	self.effects.Parent = workspace
	self.hiddenCoins = Instance.new("Folder")
	self.hiddenCoins.Name = "PlaygroundCoinRespawns"
	self.hiddenCoins.Parent = ServerStorage
	self.coins = {}
	self.running = false
	self.elapsed = 0
	self.lastSave = os.clock()
	return self
end

function Economy:_sync(profile)
	local player = profile.player
	local toys, toyIndex = cleanToyLoadout(profile.data.Equipped, profile.data.Owned)
	setToyLoadout(profile.data, toys, toyIndex)
	profile.data.XP = integer(profile.data.XP, 0)
	local level, levelXP, requiredXP = self:LevelProgress(profile.data.XP)
	player:SetAttribute("PCCoins", profile.data.Coins)
	player:SetAttribute("PCWins", profile.data.Wins)
	player:SetAttribute("PCXP", profile.data.XP)
	player:SetAttribute("PCLevel", level)
	player:SetAttribute("PCLevelXP", levelXP)
	player:SetAttribute("PCLevelXPRequired", requiredXP)
	player:SetAttribute("PCInventoryVersion", profile.version or 0)
	player:SetAttribute("PCUnlockSerial", profile.unlockSerial or 0)
	for gameId in pairs(games) do player:SetAttribute("PCWins" .. gameId, profile.data.GameWins[gameId]) end
	player:SetAttribute("PCDataReady", profile.ready == true)
	player:SetAttribute("PCDataMode", self.isStudio and "Studio" or self.sessionOnly and "Session" or "Persistent")
	for slot in pairs(slots) do
		local id = profile.data.Equipped[slot]
		local item = id and Catalog.ById[id]
		player:SetAttribute("PC" .. slot, profile.ready == true and item and item.available ~= false and item.slot == slot and profile.data.Owned[id] == true and id or "")
	end
	local emote = profile.ready and emoteDetails(profile.data)
	player:SetAttribute("PCEquippedEmoteAnimationId", emote and emote.emoteAnimationId or "")
	player:SetAttribute("PCEquippedEmoteRigType", emote and emote.emoteRigType or "")
	for index = 1, maxToySlots do player:SetAttribute("PCToySlot" .. index, profile.ready == true and toys[index] or "") end
	player:SetAttribute("PCToy", profile.ready == true and toys[toyIndex] or "")
	player:SetAttribute("PCToyIndex", profile.ready == true and toyIndex or 0)
	player:SetAttribute("PCToyLoadoutVersion", profile.version or 0)
	local board = player:FindFirstChild("leaderstats")
	if board then
		local wins = board:FindFirstChild("Wins")
		local coins = board:FindFirstChild("Coins")
		local levelCounter = board:FindFirstChild("Level")
		if wins then wins.Value = profile.data.Wins end
		if coins then coins.Value = profile.data.Coins end
		if levelCounter then levelCounter.Value = level end
	end
end

function Economy:GetToyLoadout(player)
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then
		return { items = {}, activeIndex = 0, maxSlots = maxToySlots }
	end
	local toys, index = cleanToyLoadout(profile.data.Equipped, profile.data.Owned)
	return { items = toys, activeIndex = index, activeId = toys[index], maxSlots = maxToySlots }
end

function Economy:GetEquipped(player, slot)
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then return nil end
	if slot == "Gear" or slot == "Toy" then return self:GetToyLoadout(player).activeId end
	if typeof(slot) ~= "string" or not slots[slot] then return nil end
	local id = profile.data.Equipped[slot]
	local item = typeof(id) == "string" and Catalog.ById[id]
	return item and item.available ~= false and item.slot == slot and profile.data.Owned[id] == true and id or nil
end

function Economy:SelectToySlot(player, index)
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then return false, "Your items are still loading." end
	if inGame(player) then return false, "Toys are available in the lobby between rounds." end
	local toys, current = cleanToyLoadout(profile.data.Equipped, profile.data.Owned)
	if not boundedInteger(index, 1, maxToySlots) or not toys[index] then return false, "Choose a filled toy slot from 1 to 4." end
	if current ~= index then setToyLoadout(profile.data, toys, index) self:_touch(profile) end
	return true, "Selected " .. Catalog.ById[toys[index]].name .. "."
end

function Economy:_publishLeaderboard(userId, snapshot)
	if not self.leaderboards then return end
	local ok, err = pcall(function() self.leaderboards:PublishSaved(userId, snapshot) end)
	if not ok then warn("Leaderboard update delayed: " .. tostring(err)) end
end

function Economy:_claim(profile)
	if self.isStudio or self.sessionOnly then
		profile.data = cleanData({ Coins = self.isStudio and 150 or 0 })
		profile.ready = true
		return true
	end
	local ok, value = pcall(function()
		return self.store:UpdateAsync("u:" .. profile.player.UserId, function(old)
			old = typeof(old) == "table" and old or {}
			local lease = old.Session
			if typeof(lease) == "table" and lease.Id ~= self.sessionId and timestamp(lease.Expires) > os.time() then return nil end
			local data = cleanData(old)
			data.Session = { Id = self.sessionId, Expires = os.time() + 180 }
			return data
		end)
	end)
	if ok and typeof(value) == "table" and value.Session and value.Session.Id == self.sessionId then
		profile.data = cleanData(value)
		profile.ready = true
		self:_publishLeaderboard(profile.player.UserId, profile.data)
		return true
	end
	return false
end

function Economy:_save(profile, release)
	if self.isStudio or self.sessionOnly or not profile.ready or profile.released then return true end
	local untilTime = os.clock() + 8
	while profile.saving and os.clock() < untilTime do task.wait(0.1) end
	if profile.released then return true end
	if profile.saving then return false end
	profile.saving = true
	local version = profile.version
	local snapshot = cleanData(profile.data)
	local saved = false
	for attempt = 1, 3 do
		local ok, value = pcall(function()
			return self.store:UpdateAsync("u:" .. profile.player.UserId, function(old)
				if typeof(old) ~= "table" or typeof(old.Session) ~= "table" or old.Session.Id ~= self.sessionId then return nil end
				local data = cleanData(snapshot)
				if not release then data.Session = { Id = self.sessionId, Expires = os.time() + 180 } end
				return data
			end)
		end)
		if ok and typeof(value) == "table" then saved = true break end
		if ok and value == nil then
			profile.ready = false
			self:_sync(profile)
			break
		end
		if attempt < 3 then task.wait(attempt) end
	end
	profile.saving = false
	if saved and release then profile.released = true end
	if saved and version == profile.version then profile.dirty = false end
	if saved then self:_publishLeaderboard(profile.player.UserId, snapshot) end
	if not saved then warn("Playground profile save is pending for user " .. profile.player.UserId) end
	return saved
end

function Economy:_touch(profile)
	if profile.ready then self:_unlockRewards(profile) end
	profile.version += 1
	profile.dirty = true
	self:_sync(profile)
end

function Economy:_clearAppearance(profile)
	if profile.pet then profile.pet:Destroy() profile.pet = nil end
	local character = profile.player.Character
	if character then
		for _, name in ipairs({ "PCOutline", "PCTrail", "PCTrailTop", "PCTrailBottom" }) do
			local object = character:FindFirstChild(name, true)
			if object then object:Destroy() end
		end
	end
end

function Economy:_applyAppearance(profile)
	self:_clearAppearance(profile)
	local character = profile.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not profile.ready or profile.closed then return end
	local equipped = {}
	for slot, id in pairs(profile.data.Equipped) do
		local item = Catalog.ById[id]
		if item and item.available ~= false and item.slot == slot and profile.data.Owned[id] then equipped[slot] = id end
	end
	local outlineItem = Catalog.ById[equipped.Highlight]
	if outlineItem then
		local outline = Instance.new("Highlight")
		outline.Name = "PCOutline"
		outline.Adornee = character
		outline.FillTransparency = 1
		outline.OutlineTransparency = 0
		outline.OutlineColor = outlineItem.color
		outline.Enabled = not (profile.player:GetAttribute("BBParticipating") == true or (profile.player:GetAttribute("TGParticipating") == true or profile.player:GetAttribute("MDParticipating") == true))
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = character
	end
	local trailItem = Catalog.ById[equipped.Trail]
	if trailItem then
		local top = Instance.new("Attachment")
		top.Name = "PCTrailTop"
		top.Position = Vector3.new(0, 0.6, 1)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "PCTrailBottom"
		bottom.Position = Vector3.new(0, -0.8, 1)
		bottom.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "PCTrail"
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Color = equipped.Trail == "RainbowTrail" and ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 93, 124)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 219, 64)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(75, 213, 178)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(118, 126, 255)),
		}) or ColorSequence.new(trailItem.color, Color3.fromRGB(255, 94, 139))
		trail.Lifetime = 0.55
		trail.MinLength = 0.2
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.FaceCamera = true
		trail.Parent = root
	end
end

function Economy:_bindPlayer(player)
	if self.profiles[player] then return end
	local profile = { player = player, data = cleanData(nil), ready = false, version = 0, pickups = {}, connections = {}, lastMutation = -math.huge, lastStatus = -math.huge, lastExpression = -math.huge }
	self.profiles[player] = profile
	local board = player:FindFirstChild("leaderstats")
	if not board then board = Instance.new("Folder") board.Name = "leaderstats" board.Parent = player end
	for _, name in ipairs({ "Wins", "Level", "Coins" }) do
		if not board:FindFirstChild(name) then local counter = Instance.new("IntValue") counter.Name = name counter.Parent = board end
	end
	self:_sync(profile)
	for _, attribute in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating" }) do
		table.insert(profile.connections, player:GetAttributeChangedSignal(attribute):Connect(function()
			if inGame(player) then stopEmote(player) end
		end))
	end
	table.insert(profile.connections, player.CharacterAdded:Connect(function(character)
		stopEmote(player)
		task.spawn(function()
			character:WaitForChild("HumanoidRootPart", 10)
			if self.profiles[player] == profile and character == player.Character and not profile.closed then self:_applyAppearance(profile) end
		end)
	end))
	task.spawn(function()
		while self.running and self.profiles[player] == profile and player.Parent == Players and not profile.ready do
			if self:_claim(profile) then
				if self.profiles[player] == profile and player.Parent == Players and not profile.closed then
					self:_touch(profile)
					self:_applyAppearance(profile)
				else
					self:_save(profile, true)
				end
				break
			end
			task.wait(10)
		end
	end)
end

function Economy:Status(player, ok, message)
	local profile = self.profiles[player]
	local xp = profile and integer(profile.data.XP, 0) or 0
	local level, levelXP, requiredXP = self:LevelProgress(xp)
	local ready = profile ~= nil and profile.ready == true and not profile.closed and not profile.released
	local data = profile and profile.data or cleanData(nil)
	local loadout = self:GetToyLoadout(player)
	local equipped = table.clone(data.Equipped)
	equipped.Toys, equipped.ToyIndex = table.clone(loadout.items), loadout.activeIndex
	equipped.Gear, equipped.Toy = loadout.activeId, loadout.activeId
	local unlocks = {}
	for _, item in ipairs(Catalog.Items) do
		local status = unlockStatus(data, item, level)
		status.purchasable = ready and status.purchasable or false
		unlocks[item.id] = status
	end
	return {
		ok = ok, message = message or "", coins = data.Coins, wins = data.Wins,
		xp = xp, level = level, levelXP = levelXP, levelXPRequired = requiredXP,
		owned = table.clone(data.Owned), equipped = equipped, toyLoadout = loadout, ready = ready,
		gameWins = table.clone(data.GameWins), winsByGame = table.clone(data.GameWins), unlocks = unlocks,
		newlyUnlocked = profile and table.clone(profile.newlyUnlocked or {}) or {},
		unlockSerial = profile and profile.unlockSerial or 0,
		inventoryVersion = profile and profile.version or 0,
	}
end

function Economy:Handle(player, action, id)
	local profile = self.profiles[player]
	if not profile or profile.closed or profile.released or not profile.ready then return self:Status(player, false, "Your items are still loading.") end
	if typeof(action) ~= "string" or not actions[action] then return self:Status(player, false, "Unknown shop control.") end
	if action == "StopEmote" then
		stopEmote(player)
		return self:Status(player, true, "Dance stopped.")
	end
	local now = os.clock()
	local key = action == "GetStatus" and "lastStatus" or "lastMutation"
	if now - profile[key] < (action == "GetStatus" and 0.1 or 0.35) then return self:Status(player, false, "Please wait a moment.") end
	profile[key] = now
	if action == "GetStatus" then return self:Status(player, true) end
	if action == "SelectToy" then
		local selected, message = self:SelectToySlot(player, id)
		return self:Status(player, selected, message)
	end
	if action == "Unequip" then
		local toy = typeof(id) == "string" and Catalog.ById[id]
		if id == "Gear" or id == "Toy" or isToy(toy) then
			if inGame(player) then return self:Status(player, false, "Toys are available in the lobby between rounds.") end
			local toyId = isToy(toy) and id or self:GetToyLoadout(player).activeId
			local removed, reason = unequipToy(profile.data, toyId)
			if not removed then return self:Status(player, false, reason) end
			self:_touch(profile)
			return self:Status(player, true, "Toy removed from your loadout.")
		end
		if typeof(id) ~= "string" or not slots[id] then return self:Status(player, false, "Choose an item first.") end
		if id == "Emote" then stopEmote(player) end
		profile.data.Equipped[id] = nil
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Unequipped.")
	end
	local item = typeof(id) == "string" and Catalog.ById[id]
	if not item or item.available == false then return self:Status(player, false, "This item is unavailable.") end
	if item.slot == "Emote" and (item.playable ~= true or not Catalog.EmoteAnimations[id]) then return self:Status(player, false, "This emote is not available to play.") end
	if action == "Buy" then
		if profile.data.Owned[id] then return self:Status(player, false, "You already own this.") end
		if item.unlock.kind ~= "Coins" then
			local status = unlockStatus(profile.data, item, self:LevelProgress(profile.data.XP))
			return self:Status(player, false, "Earn this reward: " .. status.label .. ".")
		end
		if profile.data.Coins < item.price then return self:Status(player, false, "Collect a few more coins first.") end
		profile.data.Coins -= item.price
		profile.data.Owned[id] = true
		local equipped, reason = true, nil
		if isToy(item) then
			if inGame(player) then equipped, reason = false, "Equip it in the lobby between rounds."
			else equipped, reason = equipToy(profile.data, id) end
		else profile.data.Equipped[item.slot] = id end
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, item.name .. " is yours!" .. (not equipped and " " .. reason or ""))
	end
	if not profile.data.Owned[id] then return self:Status(player, false, "You don't own this yet.") end
	if action == "Equip" then
		if item.slot == "Emote" then stopEmote(player) end
		if isToy(item) then
			if inGame(player) then return self:Status(player, false, "Toys are available in the lobby between rounds.") end
			local equipped, reason = equipToy(profile.data, id)
			if not equipped then return self:Status(player, false, reason) end
		else profile.data.Equipped[item.slot] = id end
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Equipped " .. item.name .. ".")
	end
	if action == "UseEmote" or action == "UseEmoji" then
		if now - profile.lastExpression < 4 then return self:Status(player, false, "Give it a moment.") end
		if player:GetAttribute("BBParticipating") or (player:GetAttribute("TGParticipating") or player:GetAttribute("MDParticipating")) then return self:Status(player, false, "Try this between rounds.") end
		if action == "UseEmote" then
			if item.slot ~= "Emote" then return self:Status(player, false, "Choose an emote.") end
			local character = player.Character
			if character and ((character:GetAttribute("PCToyHeld") or "") ~= "" or character:GetAttribute("PCBatHeld") == true) then
				return self:Status(player, false, "Put your toy away to dance.")
			end
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoid or not rootPart or humanoid.Health <= 0 then return self:Status(player, false, "Your character is not ready.") end
			if humanoid.RigType ~= Enum.HumanoidRigType.R15 then return self:Status(player, false, "These dances need an R15 avatar.") end
			if not self:_inside(rootPart.Position) then return self:Status(player, false, "Dance in the lobby between rounds.") end
			if humanoid.MoveDirection.Magnitude > 0.1 or humanoid.Sit or humanoid.FloorMaterial == Enum.Material.Air then
				return self:Status(player, false, "Stand still on the ground to dance.")
			end
			local animation = Catalog.EmoteAnimations[id]
			if not animation or not boundedInteger(animation.R15AnimationId, 1, 9007199254740991) then return self:Status(player, false, "This emote is unavailable.") end
			local startedAt = workspace:GetServerTimeNow()
			profile.lastExpression = now
			player:SetAttribute("PCEmoteAction", id)
			player:SetAttribute("PCEmoteAnimationId", "rbxassetid://" .. string.format("%.0f", animation.R15AnimationId))
			player:SetAttribute("PCEmoteRigType", "R15")
			player:SetAttribute("PCEmoteStartedAt", startedAt)
			player:SetAttribute("PCEmoteUntil", startedAt + 30)
			player:SetAttribute("PCEmoteSerial", integer(player:GetAttribute("PCEmoteSerial"), 0) + 1)
			return self:Status(player, true, "Move or jump to stop dancing.")
		end
		profile.lastExpression = now
		if item.slot ~= "Emoji" then return self:Status(player, false, "Choose an emoji.") end
		local head = player.Character and player.Character:FindFirstChild("Head")
		if not head then return self:Status(player, false, "Your character is loading.") end
		local bubble = Instance.new("BillboardGui")
		bubble.Name = "PCEmojiBubble"
		bubble.Size = UDim2.fromOffset(80, 80)
		bubble.StudsOffset = Vector3.new(0, 3.5, 0)
		bubble.AlwaysOnTop = false
		bubble.Adornee = head
		bubble.Parent = head
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = item.emoji
		text.TextColor3 = item.color
		text.TextStrokeColor3 = ink
		text.TextStrokeTransparency = 0
		text.TextScaled = true
		text.Parent = bubble
		Debris:AddItem(bubble, 2.5)
		return self:Status(player, true)
	end
	return self:Status(player, false, "Unknown shop control.")
end

function Economy:_publishReward(profile, coins, xp, won, roundReward)
	local player = profile.player
	profile.rewardSerial = (profile.rewardSerial or 0) + 1
	player:SetAttribute("PCRewardCoins", coins)
	player:SetAttribute("PCRewardXP", xp)
	player:SetAttribute("PCRewardWon", won == true)
	local message = "+" .. coins .. " coins"
	if roundReward then message ..= " · +" .. xp .. " XP · " .. (won and "Round won!" or "Round complete") end
	player:SetAttribute("PCRewardText", message)
	player:SetAttribute("PCRewardSerial", profile.rewardSerial)
	player:SetAttribute("PCRewardAt", workspace:GetServerTimeNow())
end

function Economy:GetPodiumEmote(userId)
	if not boundedInteger(userId, 1, 1000000000000) then return nil end
	local profile = self:_profileByUserId(userId)
	if profile then
		return profile.ready and not profile.closed and not profile.released and emoteDetails(profile.data) or nil
	end
	local cached = self.podiumEmotes[userId]
	local now = os.clock()
	if cached and (cached.busy or cached.expires > now) then return cached.value end
	if self.isStudio or not self.store or self.podiumEmoteReads >= 2 then return cached and cached.value end
	local record = cached or {}
	record.busy = true
	self.podiumEmotes[userId] = record
	self.podiumEmoteReads += 1
	task.spawn(function()
		local ok, data = pcall(function() return self.store:GetAsync("u:" .. userId) end)
		self.podiumEmoteReads -= 1
		record.busy = false
		record.expires = os.clock() + (ok and 120 or 30)
		if ok then record.value = emoteDetails(data) end
	end)
	return record.value
end

function Economy:_profileByUserId(id)
	for player, profile in pairs(self.profiles) do
		if player.UserId == id and player.Parent == Players then return profile end
	end
	return nil
end

function Economy:_adminProfile(player)
	if not player or player.Parent ~= Players then return nil, "That player is no longer in this server." end
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then return nil, "That player's data is not ready." end
	return profile
end

function Economy:AdminGrantItem(player, id, equip)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	local item = typeof(id) == "string" and #id <= 48 and Catalog.ById[id]
	if not item or item.available == false or not slots[item.slot] then return false, "Choose an available catalog item." end
	if equip ~= nil and typeof(equip) ~= "boolean" then return false, "Equip must be on or off." end
	local alreadyOwned = profile.data.Owned[id] == true
	if alreadyOwned and not equip then return false, "That player already owns " .. item.name .. "." end
	profile.data.Owned[id] = true
	local didEquip, equipReason = equip, nil
	if equip then
		if isToy(item) then
			if inGame(player) then didEquip, equipReason = false, "Equip it in the lobby between rounds."
			else didEquip, equipReason = equipToy(profile.data, id) end
		else profile.data.Equipped[item.slot] = id end
	end
	if alreadyOwned and equip and not didEquip then return false, equipReason end
	self:_touch(profile)
	if didEquip then self:_applyAppearance(profile) end
	return true, (alreadyOwned and "Equipped " or didEquip and "Granted and equipped " or "Granted ") .. item.name .. "." .. (equipReason and " " .. equipReason or "")
end

function Economy:AdminGrantCoins(player, amount)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	if not boundedInteger(amount, 1, adminLimits.coinsPerGrant) then return false, "Add a whole number from 1 to " .. adminLimits.coinsPerGrant .. " coins." end
	local balance = integer(profile.data.Coins, 0)
	if balance + amount > adminLimits.maxCoins then return false, "That grant would exceed the coin balance limit." end
	profile.data.Coins = balance + amount
	self:_touch(profile)
	self:_publishReward(profile, amount, 0, false, false)
	return true, "Added " .. amount .. " coins."
end

function Economy:AdminAddLevels(player, amount)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	if not boundedInteger(amount, 1, adminLimits.levelsPerGrant) then return false, "Add a whole number from 1 to " .. adminLimits.levelsPerGrant .. " levels." end
	local level, progress = self:LevelProgress(profile.data.XP)
	local targetLevel = level + amount
	if targetLevel > adminLimits.maxLevel then return false, "Admin level grants can reach level " .. adminLimits.maxLevel .. " at most." end
	local completed = targetLevel - 1
	local base = math.max(1, self:_setting("BaseLevelXP", 200))
	local step = self:_setting("LevelXPStep", 50)
	local targetXP = completed * base + step * completed * (completed - 1) / 2 + progress
	if not boundedInteger(targetXP, 0, 1000000000) then return false, "That grant would exceed the XP limit." end
	profile.data.XP = targetXP
	self:_touch(profile)
	return true, "Added " .. amount .. " " .. (amount == 1 and "level" or "levels") .. ". Now level " .. targetLevel .. "."
end

function Economy:AwardRound(key, winnerIds, practice, participantIds, rewardOptions)
	if practice or typeof(key) ~= "string" or #key > 96 or self.awarded[key] or typeof(winnerIds) ~= "table" or typeof(participantIds) ~= "table" then return 0 end
	local participants, winners = {}, {}
	local function validId(id) return typeof(id) == "number" and id == id and id % 1 == 0 and math.abs(id) <= 1000000000000 end
	for _, id in ipairs(participantIds) do if validId(id) then participants[id] = true end end
	for _, id in ipairs(winnerIds) do if validId(id) and participants[id] then winners[id] = true end end
	if next(participants) == nil then return 0 end
	self.awarded[key] = true
	local gameId = typeof(rewardOptions) == "table" and rewardOptions.gameId or nil
	if not games[gameId] then gameId = gamePrefixes[string.match(key, "^(%a+):")] end
	local rewarded = 0
	for id in pairs(participants) do
		local profile = self:_profileByUserId(id)
		if profile and profile.ready and not profile.closed and not profile.released then
			local won = winners[id] == true
			local coins = self:_setting(won and "WinnerCoins" or "LoserCoins", won and 150 or 50)
			local xp = self:_setting(won and "WinnerXP" or "LoserXP", 50)
			if typeof(rewardOptions) == "table" then xp = integer(won and rewardOptions.winnerXP or rewardOptions.loserXP, xp) end
			local beforeCoins = integer(profile.data.Coins, 0)
			local beforeXP = integer(profile.data.XP, 0)
			profile.data.Coins = integer(beforeCoins + coins, 0)
			profile.data.XP = integer(beforeXP + xp, 0)
			if won then
				profile.data.Wins = integer(profile.data.Wins + 1, 0)
				if games[gameId] then profile.data.GameWins[gameId] = integer(profile.data.GameWins[gameId] + 1, 0) end
			end
			self:_touch(profile)
			self:_publishReward(profile, profile.data.Coins - beforeCoins, profile.data.XP - beforeXP, won, true)
			rewarded += 1
		end
	end
	return rewarded
end

function Economy:_inside(position)
	local point = self.bounds.CFrame:PointToObjectSpace(position)
	local half = self.bounds.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Economy:_buildCoins()
	local template = self.assets:FindFirstChild("C01")
	for _, marker in ipairs(self.lobby.Gameplay.CoinSpawns:GetChildren()) do
		if marker:IsA("BasePart") then
			local coin
			if template and (template:IsA("Model") or template:IsA("BasePart")) then
				coin = template:Clone()
				if coin:IsA("Model") then
					local _, size = coin:GetBoundingBox()
					local extent = math.max(size.X, size.Y, size.Z)
					if extent > 0 then coin:ScaleTo(coin:GetScale() * 2.8 / extent) end
				else
					coin.Size *= 2.8 / math.max(coin.Size.X, coin.Size.Y, coin.Size.Z)
				end
			else
				coin = Instance.new("Part")
				coin.Shape = Enum.PartType.Cylinder
				coin.Size = Vector3.new(0.65, 2.8, 2.8)
				coin.Color = Color3.fromRGB(255, 207, 59)
				coin.Material = Enum.Material.SmoothPlastic
			end
			coin.Name = "Coin_" .. marker.Name
			local parts = coin:GetDescendants()
			table.insert(parts, coin)
			for _, object in ipairs(parts) do
				if object:IsA("BasePart") then
					object.Anchored = true
					object.CanCollide = false
					object.CanTouch = false
					object.CanQuery = false
				elseif object:IsA("LuaSourceContainer") then object:Destroy() end
			end
			coin:PivotTo(marker.CFrame)
			coin.Parent = self.effects
			table.insert(self.coins, {
				id = marker:GetAttribute("PickupId") or marker.Name,
				value = coinPickupAmount,
				cooldown = math.clamp(integer(marker:GetAttribute("RespawnSeconds"), 45), 15, 300),
				marker = marker, visual = coin, availableAt = 0,
			})
		end
	end
end

function Economy:_collectCoin(profile, coin, now)
	local player = profile.player
	if self.profiles[player] ~= profile or player.Parent ~= Players or not profile.ready or profile.closed or profile.released
		or now < coin.availableAt or coin.visual.Parent ~= self.effects or not coin.marker.Parent then return false end
	if player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true then return false end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or not self:_inside(root.Position)
		or (root.Position - coin.marker.Position).Magnitude > 5.5 then return false end
	local beforeCoins = integer(profile.data.Coins, 0)
	if beforeCoins > adminLimits.maxCoins - coinPickupAmount then return false end
	local position = coin.visual:GetPivot().Position
	coin.availableAt = now + coin.cooldown
	coin.visual.Parent = self.hiddenCoins
	profile.data.Coins = beforeCoins + coinPickupAmount
	self:_touch(profile)
	profile.pickupSerial = math.max(profile.pickupSerial or 0, integer(player:GetAttribute("PCCoinPickupSerial"), 0)) + 1
	player:SetAttribute("PCCoinPickupAmount", coinPickupAmount)
	player:SetAttribute("PCCoinPickupPosition", position)
	player:SetAttribute("PCCoinPickupSerial", profile.pickupSerial)
	return true
end

function Economy:_tick(dt)
	self.elapsed += dt
	if self.elapsed < 0.15 then return end
	self.elapsed = 0
	local now = workspace:GetServerTimeNow()
	for _, coin in ipairs(self.coins) do
		if coin.marker.Parent and coin.visual.Parent and now >= coin.availableAt then
			coin.visual:PivotTo(coin.marker.CFrame * CFrame.new(0, math.sin(now * 2 + #tostring(coin.id)) * 0.3, 0) * CFrame.Angles(0, now, 0))
			coin.visual.Parent = self.effects
		end
	end
	for player, profile in pairs(self.profiles) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and profile.ready and not profile.closed and not profile.released then
			local participating = player:GetAttribute("BBParticipating") == true or (player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true)
			local outline = character:FindFirstChild("PCOutline")
			if outline then
				outline.Enabled = not participating
				if profile.data.Equipped.Highlight == "RainbowOutline" then outline.OutlineColor = Color3.fromHSV(now * 0.12 % 1, 0.72, 1) end
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not participating and humanoid and humanoid.Health > 0 and self:_inside(root.Position) then
				for _, coin in ipairs(self.coins) do
					self:_collectCoin(profile, coin, now)
				end
			end
		end
	end
	if os.clock() - self.lastSave >= 60 then
		self.lastSave = os.clock()
		for _, profile in pairs(self.profiles) do task.spawn(function() self:_save(profile, false) end) end
	end
end

function Economy:Start()
	if self.running then return end
	self.running = true
	self:_buildCoins()
	local remote = ReplicatedStorage:WaitForChild("PlaygroundShopRequest")
	remote.OnServerInvoke = function(player, action, id) return self:Handle(player, action, id) end
	self.remote = remote
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_bindPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		local profile = self.profiles[player]
		if not profile then return end
		profile.closed = true
		for _, connection in ipairs(profile.connections) do connection:Disconnect() end
		self:_clearAppearance(profile)
		self:_save(profile, true)
		self.profiles[player] = nil
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_bindPlayer(player) end
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self:_tick(dt) end))
	for _, attributeName in ipairs({"BaseLevelXP", "LevelXPStep"}) do
		table.insert(self.connections, self.lobby:GetAttributeChangedSignal(attributeName):Connect(function()
			for _, profile in pairs(self.profiles) do if profile.ready and not profile.closed then self:_touch(profile) end end
		end))
	end
	game:BindToClose(function()
		local pending = 0
		for _, profile in pairs(self.profiles) do
			profile.closed = true
			pending += 1
			task.spawn(function() self:_save(profile, true) pending -= 1 end)
		end
		local untilTime = os.clock() + 25
		while pending > 0 and os.clock() < untilTime do task.wait(0.1) end
		if pending == 0 and self.leaderboards then
			pcall(function() self.leaderboards:Flush(2) end)
		end
	end)
end

function Economy:Stop()
	self.running = false
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
	for _, profile in pairs(self.profiles) do profile.closed = true end
	for _, profile in pairs(self.profiles) do
		for _, connection in ipairs(profile.connections) do connection:Disconnect() end
		self:_clearAppearance(profile)
		self:_save(profile, true)
	end
	self.effects:Destroy()
	self.hiddenCoins:Destroy()
	table.clear(self.profiles)
end

Economy.CleanData = cleanData
Economy.CalculateLevelProgress = levelProgress
Economy.EvaluateUnlock = unlockStatus
Economy.AdminLimits = adminLimits
return Economy



]========]},
{path="StarterGui.PlaygroundShell.Controller",before=[========[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local gui = script.Parent
local shop = gui:WaitForChild("ShopPanel")
local vote = gui:WaitForChild("VotePanel")
local compactVote = gui:WaitForChild("CompactVotePanel")
local votePanels = { vote, compactVote }
local wallet = gui:WaitForChild("Wallet")
local dock = gui:WaitForChild("Dock")
local toast = gui:WaitForChild("RewardToast")
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then warn("Playground catalog is unavailable") return end
local catalog = require(catalogObject)
local ink = Color3.fromRGB(27, 45, 61)
local white = Color3.fromRGB(255, 255, 248)
local gold = Color3.fromRGB(255, 211, 78)
local blue = Color3.fromRGB(89, 193, 244)
local pink = Color3.fromRGB(255, 153, 166)
local mint = Color3.fromRGB(130, 225, 180)
local muted = Color3.fromRGB(194, 201, 206)
local data = { coins = player:GetAttribute("PCCoins") or 0, ready = player:GetAttribute("PCDataReady") == true, owned = {}, equipped = {}, unlocks = {} }
local category = "All"
local page = 1
local pageCount = 1
local busy = false
local pendingStatus = false
local voteBusy = false
local toastToken = 0
local lastUnlockSerial = nil
local slots = {}
local previews = {}
local lastReward = player:GetAttribute("PCRewardAt")
local lastCoinPickup = player:GetAttribute("PCCoinPickupSerial") or 0
local coinPopups = {}
local wasInsideShop = false
local state = nil
local stateConnection = nil
local pager = shop:WaitForChild("Pager")
local emoteEmptyState = shop:WaitForChild("EmoteEmptyState")
local gameLabels = { BritishBulldog = "Bulldog", TagYoureIt = "Tag", StuckInTheMud = "Mud", All = "total" }

local function showToast(message, duration)
	toastToken += 1
	local token = toastToken
	toast.Message.Text = tostring(message)
	toast.Visible = true
	task.delay(duration or 3.2, function()
		if token == toastToken and toast.Parent then toast.Visible = false end
	end)
end

local function clearCoinPopup(popup)
	local record = coinPopups[popup]
	if not record then return end
	coinPopups[popup] = nil
	if record.completed then record.completed:Disconnect() end
	for _, tween in ipairs(record.tweens) do tween:Cancel() end
	popup:Destroy()
end

local function showCoinPickup(amount, position)
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 or amount % 1 ~= 0 or typeof(position) ~= "Vector3" then return end
	local templates = gui:FindFirstChild("Templates")
	local template = templates and templates:FindFirstChild("CoinPickupPopup")
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local gameplay = lobby and lobby:FindFirstChild("Gameplay")
	local markers = gameplay and gameplay:FindFirstChild("CoinSpawns")
	if not template or not template:IsA("BillboardGui") or not markers then return end
	local anchor, distance = nil, 8
	for _, marker in ipairs(markers:GetChildren()) do
		if marker:IsA("BasePart") then
			local gap = (marker.Position - position).Magnitude
			if gap < distance then anchor, distance = marker, gap end
		end
	end
	if not anchor then return end
	local popup = template:Clone()
	popup.Name = "CoinPickup"
	local label = popup:FindFirstChild("Amount")
	if not label or not label:IsA("TextLabel") then popup:Destroy() return end
	label.Text = "+" .. tostring(amount)
	popup.Adornee = anchor
	popup.StudsOffsetWorldSpace += position - anchor.Position
	popup.Enabled = true
	popup.Parent = gui
	local lift = TweenService:Create(popup, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = popup.StudsOffsetWorldSpace + Vector3.new(0, 1.8, 0) })
	local fade = TweenService:Create(label, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { TextTransparency = 1 })
	local record = { tweens = { lift, fade } }
	coinPopups[popup] = record
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then table.insert(record.tweens, TweenService:Create(stroke, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { Transparency = 1 })) end
	record.completed = fade.Completed:Connect(function() clearCoinPopup(popup) end)
	for _, tween in ipairs(record.tweens) do tween:Play() end
	return popup
end

local function setText(label, value)
	label.Text = value
	local caption = label:FindFirstChild("LiveCaption")
	if caption and caption:IsA("TextLabel") then caption.Text = value end
end

local function refreshWallet()
	local coins = data.ready and tostring(data.coins or 0) or "..."
	wallet.Coins.Text = coins
	wallet.Wins.Text = data.ready and tostring(player:GetAttribute("PCWins") or 0) or "..."
	wallet.Level.Text = data.ready and tostring(player:GetAttribute("PCLevel") or 1) or "..."
	shop.Coins.Text = coins .. " coins"
end

local function visibleBounds(model)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local point = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
						low = low:Min(point)
						high = high:Max(point)
					end
				end
			end
		end
	end
	if low.X == math.huge then return Vector3.zero, Vector3.one end
	return (low + high) * 0.5, high - low
end

local function framePreview(record)
	if not record.model or not record.model.Parent then return end
	local viewport = record.card.Preview
	local camera = viewport:FindFirstChild("PreviewCamera")
	if not camera or not camera:IsA("Camera") then
		camera = Instance.new("Camera")
		camera.Name = "PreviewCamera"
		camera.FieldOfView = viewport:GetAttribute("PreviewFieldOfView") or 35
		camera.Parent = viewport
	end
	local aspect = math.max(0.2, viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y))
	local angle = math.rad(camera.FieldOfView * 0.5)
	local radius = record.radius
	local distance = radius / math.sin(math.min(angle, math.atan(math.tan(angle) * aspect))) * 1.12
	local direction = Vector3.new(0.5, 0.2, -1).Unit
	camera.CFrame = CFrame.lookAt(direction * distance, Vector3.zero)
	viewport.CurrentCamera = camera
end

local function emotePlayable(item)
	return item and item.slot == "Emote" and item.playable == true and item.available ~= false
end

local function emoteInLobby()
	return player:GetAttribute("BBParticipating") ~= true
		and player:GetAttribute("TGParticipating") ~= true
		and player:GetAttribute("MDParticipating") ~= true
end

local function emoteThumbnail(item)
	if typeof(item.thumbnail) == "string" and item.thumbnail ~= "" then return item.thumbnail end
	local id = item.catalogId
	if typeof(id) == "number" and id == id and id > 0 and id < math.huge and id % 1 == 0 then
		return "rbxthumb://type=Asset&id=" .. string.format("%.0f", id) .. "&w=420&h=420"
	end
	return ""
end

local function refreshThumbnail(record)
	local thumbnail = record.card.Thumbnail
	local status = record.card.ThumbnailStatus
	status.Visible = thumbnail.Visible and (thumbnail.Image == "" or not thumbnail.IsLoaded)
	status.Text = (thumbnail.Image == "" or record.thumbnailTimedOut) and "Preview unavailable" or "Loading preview..."
end

local function renderPreview(record, item)
	local id = item and item.id or nil
	if record.previewId == id and (not id or record.model or item.slot == "Emote" and record.card.Thumbnail.Image == emoteThumbnail(item)) then return end
	record.previewId = nil
	record.previewToken = (record.previewToken or 0) + 1
	local token = record.previewToken
	record.card.Thumbnail.Visible = false
	record.card.ThumbnailStatus.Visible = false
	record.card.Preview.Visible = item ~= nil and item.slot ~= "Emote"
	if record.model then record.model:Destroy() end
	record.model = nil
	previews[record] = nil
	local world = record.card.Preview:FindFirstChild("World")
	if world then for _, child in ipairs(world:GetChildren()) do child:Destroy() end end
	if not item then return end
	if item.slot == "Emote" then
		record.previewId = id
		record.thumbnailTimedOut = false
		record.card.Thumbnail.Image = emoteThumbnail(item)
		record.card.Thumbnail.Visible = true
		refreshThumbnail(record)
		task.delay(8, function()
			if record.previewToken == token and record.card.Parent then
				record.thumbnailTimedOut = true
				refreshThumbnail(record)
			end
		end)
		return
	end
	if not world then return end
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local original = assets and assets:FindFirstChild(id)
	if not original or not original:IsA("Model") then return end
	local model = original:Clone()
	model.Name = "ItemModel"
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
		elseif child:IsA("ParticleEmitter") or child:IsA("Trail") then child.Enabled = false end
	end
	local center, size = visibleBounds(model)
	model:PivotTo(CFrame.new(-center) * model:GetPivot())
	model.Parent = world
	record.model = model
	record.previewId = id
	record.pivot = model:GetPivot()
	record.radius = math.max(0.01, size.Magnitude * 0.5)
	previews[record] = record
	framePreview(record)
	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync({ model }) end)
		if record.model == model and world.Parent then
			model.Parent = nil
			model.Parent = world
			framePreview(record)
		end
	end)
end

local function requirement(item, unlock)
	local rule = item.unlock or { kind = "Coins", amount = item.price or 0 }
	if rule.kind == "Starter" then return "Starter reward", "FREE" end
	if rule.kind == "Coins" then return tostring(item.price or rule.amount or 0) .. " coins", item.category end
	local progress = unlock and unlock.progress or 0
	local target = rule.amount or 0
	if rule.kind == "Level" then return "Level " .. tostring(target), tostring(math.min(progress, target)) .. " / " .. tostring(target) end
	return tostring(target) .. " " .. (gameLabels[rule.gameId] or "total") .. " wins", tostring(math.min(progress, target)) .. " / " .. tostring(target)
end

local function isEquipped(item)
	if item.slot == "Gear" and typeof(data.equipped.Toys) == "table" then
		return table.find(data.equipped.Toys, item.id) ~= nil
	end
	return data.equipped[item.slot] == item.id
end

local function refreshCards()
	refreshWallet()
	local filtered = {}
	for _, item in ipairs(catalog.Items) do
		if category == "All" or item.category == category then table.insert(filtered, item) end
	end
	emoteEmptyState.Visible = category == "Emotes" and #filtered == 0
	pager.Visible = #filtered > 0
	pageCount = math.max(1, math.ceil(#filtered / math.max(1, #slots)))
	page = math.clamp(page, 1, pageCount)
	setText(pager.PageLabel, tostring(page) .. " / " .. tostring(pageCount))
	for _, spec in ipairs({ { pager.Previous, page > 1 }, { pager.Next, page < pageCount } }) do
		spec[1].Active = spec[2] and not busy
		spec[1].Selectable = spec[1].Active
		spec[1].BackgroundColor3 = spec[1].Active and blue or muted
	end
	for index, record in ipairs(slots) do
		local item = filtered[(page - 1) * #slots + index]
		local card = record.card
		record.item = item
		card.Visible = item ~= nil
		renderPreview(record, item)
		if item then
			card:SetAttribute("CatalogId", item.id)
			setText(card:FindFirstChild("Name"), item.name)
			local owned = data.owned[item.id] == true
			local equipped = isEquipped(item)
			local unlock = data.unlocks[item.id]
			local price, detail = requirement(item, unlock)
			setText(card.Price, owned and (equipped and "Equipped" or "Owned") or price)
			setText(card.Category, owned and item.category or detail)
			local isCoins = item.unlock and item.unlock.kind == "Coins"
			local canBuy = isCoins and (unlock and unlock.purchasable == true or not unlock and data.coins >= (item.price or 0))
			local available = item.available ~= false and (item.slot ~= "Emote" or emotePlayable(item))
			local action = not available and "UNAVAILABLE" or not data.ready and "LOADING" or equipped and "UNEQUIP" or owned and "EQUIP" or isCoins and "BUY" or "LOCKED"
			if busy then action = "PLEASE WAIT" end
			setText(card.Action, action)
			card.Action.Visible = true
			card.Action.Active = not busy and data.ready and available and (owned or canBuy)
			card.Action.Selectable = card.Action.Active
			card.Action.BackgroundColor3 = not card.Action.Active and muted or equipped and mint or owned and blue or gold
			local canPlay = emotePlayable(item) and owned
			setText(card.Try, canPlay and "PLAY" or "INFO")
			card.Try.Visible = true
			card.Try.Active = not canPlay or not busy and data.ready and emoteInLobby()
			card.Try.Selectable = card.Try.Active
			local outline = card:FindFirstChild("Outline")
			if outline then outline.Color = equipped and gold or ink end
		else
			card:SetAttribute("CatalogId", nil)
		end
	end
	for _, button in ipairs(shop.Categories:GetChildren()) do
		if button:IsA("TextButton") and button.Visible then button.BackgroundColor3 = button.Name == category and gold or white end
	end
end

local function applyReply(reply)
	if typeof(reply) ~= "table" then return end
	if typeof(reply.coins) == "number" then data.coins = reply.coins end
	if typeof(reply.ready) == "boolean" then data.ready = reply.ready end
	if typeof(reply.owned) == "table" then data.owned = reply.owned end
	if typeof(reply.equipped) == "table" then data.equipped = reply.equipped end
	if typeof(reply.unlocks) == "table" then data.unlocks = reply.unlocks end
	if typeof(reply.unlockSerial) == "number" and reply.unlockSerial ~= lastUnlockSerial then
		lastUnlockSerial = reply.unlockSerial
		if typeof(reply.newlyUnlocked) == "table" and #reply.newlyUnlocked > 0 then
			local names = {}
			for index, id in ipairs(reply.newlyUnlocked) do
				if index > 2 then break end
				local item = catalog.ById[id]
				if item then table.insert(names, item.name) end
			end
			if #names > 0 then
				local more = #reply.newlyUnlocked > 2 and " and " .. tostring(#reply.newlyUnlocked - 2) .. " more" or ""
				showToast("Unlocked: " .. table.concat(names, ", ") .. more .. "!", 5)
			end
		end
	end
	refreshCards()
end

local request
request = function(action, id, quiet, onSuccess)
	if busy then
		if action == "GetStatus" then pendingStatus = true end
		return
	end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundShopRequest")
	if not remote or not remote:IsA("RemoteFunction") then
		if not quiet then shop.Status.Text = "The shop is getting ready. Try again in a moment." end
		return
	end
	busy = true
	refreshCards()
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, id) end)
		busy = false
		if ok and typeof(reply) == "table" then
			applyReply(reply)
			if reply.ok == true and onSuccess then onSuccess(reply) end
			if not quiet or not reply.ok then shop.Status.Text = tostring(reply.message or (reply.ok and "All set!" or "Try again in a moment.")) end
			if not reply.ok and not shop.Visible and not quiet then showToast(reply.message or "Try again in a moment.") end
		else
			refreshCards()
			if not quiet then shop.Status.Text = "That did not go through. Try again in a moment." end
		end
		if pendingStatus then
			pendingStatus = false
			task.defer(function() request("GetStatus", nil, true) end)
		end
	end)
end

local function setShop(visible)
	shop.Visible = visible
	gui.Backdrop.Visible = visible
	if visible then
		shop.Status.Text = data.ready and "Earn rewards, or spend your coins." or "Your coins are loading..."
		request("GetStatus", nil, true)
	end
end

local function setCategory(value)
	category = value
	page = 1
	shop.Cards.CanvasPosition = Vector2.zero
	refreshCards()
end

local function useOrInfo(record)
	local item = record.item
	if not item or not record.card.Try.Active then return end
	if emotePlayable(item) and data.owned[item.id] then
		if busy or not data.ready or not emoteInLobby() then return end
		request("UseEmote", item.id, false, function()
			setShop(false)
			showToast("Starting " .. item.name .. ". Move to stop.", 3)
		end)
		return
	end
	local unlock = data.unlocks[item.id]
	local description = item.description or item.name
	if unlock and not data.owned[item.id] then description ..= " " .. unlock.label .. "." end
	showToast(description, 5)
end

for _, card in ipairs(shop.Cards:GetChildren()) do
	if card:IsA("Frame") and card:FindFirstChild("Preview") and card:FindFirstChild("Action") then
		table.insert(slots, { card = card })
	end
end
table.sort(slots, function(a, b) return a.card.Name < b.card.Name end)
for _, record in ipairs(slots) do
	record.card.Action.Activated:Connect(function()
		local item = record.item
		if busy or not data.ready or not item or not record.card.Action.Active then return end
		if isEquipped(item) then request("Unequip", item.slot == "Gear" and item.id or item.slot)
		elseif data.owned[item.id] then request("Equip", item.id)
		else request("Buy", item.id) end
	end)
	record.card.Try.Activated:Connect(function() useOrInfo(record) end)
	record.card.Preview:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() framePreview(record) end)
	record.card.Thumbnail:GetPropertyChangedSignal("IsLoaded"):Connect(function() refreshThumbnail(record) end)
end
for _, button in ipairs(shop.Categories:GetChildren()) do
	if button:IsA("TextButton") and button.Visible then button.Activated:Connect(function() setCategory(button.Name) end) end
end
pager.Previous.Activated:Connect(function()
	if busy or page <= 1 then return end
	page -= 1
	shop.Cards.CanvasPosition = Vector2.zero
	refreshCards()
end)
pager.Next.Activated:Connect(function()
	if busy or page >= pageCount then return end
	page += 1
	shop.Cards.CanvasPosition = Vector2.zero
	refreshCards()
end)
dock.Shop.Activated:Connect(function() setShop(not shop.Visible) end)
shop.Close.Activated:Connect(function() setShop(false) end)
gui.Backdrop.Activated:Connect(function() setShop(false) end)
dock.Pets.Activated:Connect(function() setCategory("Pets") setShop(true) end)
dock.Toys.Activated:Connect(function() setCategory("Toys") setShop(true) end)
for _, attribute in ipairs({ "PCCoins", "PCWins", "PCLevel", "PCDataReady" }) do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		local wasReady = data.ready
		data.coins = player:GetAttribute("PCCoins") or data.coins
		data.ready = player:GetAttribute("PCDataReady") == true
		refreshCards()
		if data.ready and not wasReady then request("GetStatus", nil, true) end
	end)
end
player:GetAttributeChangedSignal("PCInventoryVersion"):Connect(function() request("GetStatus", nil, true) end)
player:GetAttributeChangedSignal("PCEmotePlaybackStatus"):Connect(function()
	if player:GetAttribute("PCEmotePlaybackStatus") == "failed" then
		showToast(player:GetAttribute("PCEmotePlaybackMessage") or "That emote could not load. Please try again.", 5)
	end
end)
player:GetAttributeChangedSignal("PCRewardAt"):Connect(function()
	local now = player:GetAttribute("PCRewardAt")
	if now and now ~= lastReward then
		lastReward = now
		local message = player:GetAttribute("PCRewardText")
		if typeof(message) == "string" and message ~= "" then showToast(message, 4) end
	end
end)
local coinPickupConnection = player:GetAttributeChangedSignal("PCCoinPickupSerial"):Connect(function()
	local serial = player:GetAttribute("PCCoinPickupSerial")
	if typeof(serial) ~= "number" or serial <= lastCoinPickup then return end
	lastCoinPickup = serial
	showCoinPickup(player:GetAttribute("PCCoinPickupAmount"), player:GetAttribute("PCCoinPickupPosition"))
end)
script.Destroying:Connect(function()
	coinPickupConnection:Disconnect()
	while next(coinPopups) do clearCoinPopup(next(coinPopups)) end
end)
ReplicatedStorage.ChildAdded:Connect(function(child)
	if child.Name == "PlaygroundShopRequest" then request("GetStatus", nil, true)
	elseif child.Name == "PlaygroundCosmeticAssets" then refreshCards() end
end)

local function insideZone(zone,root)
 if not zone or not zone:IsA("BasePart") or not root then return false end
 local point=zone.CFrame:PointToObjectSpace(root.Position)
 return math.abs(point.X)<=zone.Size.X/2 and math.abs(point.Y)<=zone.Size.Y/2 and math.abs(point.Z)<=zone.Size.Z/2
end
local function votesText(count)
 return tostring(count)..(count==1 and " vote" or " votes")
end
local function refreshVotes()
 local phase=state and state:GetAttribute("Phase") or "Waiting"
 local voting=phase=="Voting"
 local chosen=player:GetAttribute("PCVote")
 for _,vote in ipairs(votePanels) do
 vote.Title.Text=voting and "PICK THE NEXT ROUND" or "NEXT ROUND"
 local ending=state and state:GetAttribute("VotingEndsAt") or 0
 vote.Timer.Text=voting and tostring(math.max(0,math.ceil(ending-workspace:GetServerTimeNow()))).."s" or phase=="Playing" and "PLAYING" or phase=="Paused" and "PAUSED" or "WAITING"
 vote.VotesBritishBulldog.Text=votesText(state and state:GetAttribute("VotesBritishBulldog") or 0)
 vote.VotesTagYoureIt.Text=votesText(state and state:GetAttribute("VotesTagYoureIt") or 0)
 vote.VotesStuckInTheMud.Text=votesText(state and state:GetAttribute("VotesStuckInTheMud") or 0)
 vote.BritishBulldog.BackgroundColor3=chosen=="BritishBulldog" and gold or blue
 vote.TagYoureIt.BackgroundColor3=chosen=="TagYoureIt" and gold or pink
 vote.StuckInTheMud.BackgroundColor3=chosen=="StuckInTheMud" and gold or mint
 vote.BritishBulldog.Active=voting and not voteBusy
 vote.TagYoureIt.Active=voting and not voteBusy
 local mudAvailable=state and state:GetAttribute("AvailableStuckInTheMud")~=false
 vote.StuckInTheMud.Active=voting and not voteBusy and mudAvailable
 if not mudAvailable then
  vote.StuckInTheMud.BackgroundColor3=Color3.fromRGB(162,169,184)
  local minimum=state:GetAttribute("MinimumStuckInTheMud") or 4
  vote.VotesStuckInTheMud.Text=(state:GetAttribute("ReadyPlayerCount") or 0)<minimum and "Needs "..tostring(minimum).." players" or "Unavailable"
 end
 vote.StuckInTheMud.Selectable=vote.StuckInTheMud.Active
 vote.BritishBulldog.Selectable=vote.BritishBulldog.Active
 vote.TagYoureIt.Selectable=vote.TagYoureIt.Active
 if not voteBusy then
  vote.Message.Text=voting and (chosen and chosen~="" and "Your vote is saved. You can change it." or "Step onto a card to vote, or tap it here.") or phase=="Playing" and "Another round is underway." or phase=="Paused" and "The next round is paused." or "Voting opens when the next round is ready."
 end
 end
end
local function bindState(object)
 if not object or object==state then return end
 if stateConnection then stateConnection:Disconnect() end
 state=object
 stateConnection=state.AttributeChanged:Connect(refreshVotes)
 refreshVotes()
end
bindState(ReplicatedStorage:FindFirstChild("PlaygroundState"))
ReplicatedStorage.ChildAdded:Connect(function(child) if child.Name=="PlaygroundState" then bindState(child) end end)
player:GetAttributeChangedSignal("PCVote"):Connect(refreshVotes)
local function castVote(id)
 if voteBusy or not state or state:GetAttribute("Phase")~="Voting" then return end
 local remote=ReplicatedStorage:FindFirstChild("PlaygroundVoteRequest")
 if not remote or not remote:IsA("RemoteFunction") then return end
 voteBusy=true
 refreshVotes()
 task.spawn(function()
  local ok,reply=pcall(function() return remote:InvokeServer(id) end)
  voteBusy=false
  refreshVotes()
  if not ok then
   for _,panel in ipairs(votePanels) do panel.Message.Text="That vote did not go through. Try again." end
  elseif typeof(reply)=="table" and reply.ok==false then
   for _,panel in ipairs(votePanels) do panel.Message.Text=tostring(reply.message or "Step into the voting area first.") end
  end
 end)
end
for _,panel in ipairs(votePanels) do
 for _,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud"}) do panel[id].Activated:Connect(function() castVote(id) end) end
end
player.CharacterAdded:Connect(function() wasInsideShop=false end)
local elapsed=0
local previewTime=0
RunService.Heartbeat:Connect(function(delta)
 elapsed+=delta
 previewTime+=delta
 if elapsed<0.15 then return end
 elapsed=0
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local lobby=workspace:FindFirstChild("Playground Lobby")
 local gameplay=lobby and lobby:FindFirstChild("Gameplay")
 local participating=player:GetAttribute("BBParticipating")==true or (player:GetAttribute("TGParticipating")==true or player:GetAttribute("MDParticipating")==true)
 wallet.Visible=not participating
 dock.Visible=not participating
 if participating and shop.Visible then setShop(false) end
 local shopZone=gameplay and gameplay:FindFirstChild("ShopZone")
 local voteZone=gameplay and gameplay:FindFirstChild("VoteZone")
 local inShop=insideZone(shopZone,root)
 if inShop and not wasInsideShop and not participating then setShop(true) end
 wasInsideShop=inShop
 local showVote=not participating and insideZone(voteZone,root) and not shop.Visible
 local camera=workspace.CurrentCamera
 local useCompactVote=camera and (camera.ViewportSize.X<980 or camera.ViewportSize.Y<450) or false
 vote.Visible=showVote and not useCompactVote
 compactVote.Visible=showVote and useCompactVote
 if showVote then refreshVotes() end
 if shop.Visible then
  local rotation=math.sin(previewTime*0.45)*0.30
  for _,preview in pairs(previews) do
   if preview.model.Parent then preview.model:PivotTo(CFrame.Angles(0,rotation,0)*preview.pivot) end
  end
 end
end)
refreshCards()
refreshVotes()
request("GetStatus",nil,true)



]========],after=[========[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local gui = script.Parent
local shop = gui:WaitForChild("ShopPanel")
local vote = gui:WaitForChild("VotePanel")
local compactVote = gui:WaitForChild("CompactVotePanel")
local votePanels = { vote, compactVote }
local wallet = gui:WaitForChild("Wallet")
local dock = gui:WaitForChild("Dock")
local toast = gui:WaitForChild("RewardToast")
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then warn("Playground catalog is unavailable") return end
local catalog = require(catalogObject)
local ink = Color3.fromRGB(27, 45, 61)
local white = Color3.fromRGB(255, 255, 248)
local gold = Color3.fromRGB(255, 211, 78)
local blue = Color3.fromRGB(89, 193, 244)
local pink = Color3.fromRGB(255, 153, 166)
local mint = Color3.fromRGB(130, 225, 180)
local muted = Color3.fromRGB(194, 201, 206)
local data = { coins = player:GetAttribute("PCCoins") or 0, ready = player:GetAttribute("PCDataReady") == true, owned = {}, equipped = {}, unlocks = {} }
local category = "All"
local page = 1
local pageCount = 1
local busy = false
local pendingStatus = false
local voteBusy = false
local toastToken = 0
local lastUnlockSerial = nil
local slots = {}
local alive = true
local thumbnailConnections = {}
local lastReward = player:GetAttribute("PCRewardAt")
local lastCoinPickup = player:GetAttribute("PCCoinPickupSerial") or 0
local coinPopups = {}
local wasInsideShop = false
local state = nil
local stateConnection = nil
local pager = shop:WaitForChild("Pager")
local emoteEmptyState = shop:WaitForChild("EmoteEmptyState")
local gameLabels = { BritishBulldog = "Bulldog", TagYoureIt = "Tag", StuckInTheMud = "Mud", All = "total" }

local function showToast(message, duration)
	toastToken += 1
	local token = toastToken
	toast.Message.Text = tostring(message)
	toast.Visible = true
	task.delay(duration or 3.2, function()
		if token == toastToken and toast.Parent then toast.Visible = false end
	end)
end

local function clearCoinPopup(popup)
	local record = coinPopups[popup]
	if not record then return end
	coinPopups[popup] = nil
	if record.completed then record.completed:Disconnect() end
	for _, tween in ipairs(record.tweens) do tween:Cancel() end
	popup:Destroy()
end

local function showCoinPickup(amount, position)
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 or amount % 1 ~= 0 or typeof(position) ~= "Vector3" then return end
	local templates = gui:FindFirstChild("Templates")
	local template = templates and templates:FindFirstChild("CoinPickupPopup")
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local gameplay = lobby and lobby:FindFirstChild("Gameplay")
	local markers = gameplay and gameplay:FindFirstChild("CoinSpawns")
	if not template or not template:IsA("BillboardGui") or not markers then return end
	local anchor, distance = nil, 8
	for _, marker in ipairs(markers:GetChildren()) do
		if marker:IsA("BasePart") then
			local gap = (marker.Position - position).Magnitude
			if gap < distance then anchor, distance = marker, gap end
		end
	end
	if not anchor then return end
	local popup = template:Clone()
	popup.Name = "CoinPickup"
	local label = popup:FindFirstChild("Amount")
	if not label or not label:IsA("TextLabel") then popup:Destroy() return end
	label.Text = "+" .. tostring(amount)
	popup.Adornee = anchor
	popup.StudsOffsetWorldSpace += position - anchor.Position
	popup.Enabled = true
	popup.Parent = gui
	local lift = TweenService:Create(popup, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = popup.StudsOffsetWorldSpace + Vector3.new(0, 1.8, 0) })
	local fade = TweenService:Create(label, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { TextTransparency = 1 })
	local record = { tweens = { lift, fade } }
	coinPopups[popup] = record
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then table.insert(record.tweens, TweenService:Create(stroke, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { Transparency = 1 })) end
	record.completed = fade.Completed:Connect(function() clearCoinPopup(popup) end)
	for _, tween in ipairs(record.tweens) do tween:Play() end
	return popup
end

local function setText(label, value)
	label.Text = value
	local caption = label:FindFirstChild("LiveCaption")
	if caption and caption:IsA("TextLabel") then caption.Text = value end
end

local function refreshWallet()
	local coins = data.ready and tostring(data.coins or 0) or "..."
	wallet.Coins.Text = coins
	wallet.Wins.Text = data.ready and tostring(player:GetAttribute("PCWins") or 0) or "..."
	wallet.Level.Text = data.ready and tostring(player:GetAttribute("PCLevel") or 1) or "..."
	shop.Coins.Text = coins .. " coins"
end

local function emotePlayable(item)
	return item and item.slot == "Emote" and item.playable == true and item.available ~= false
end

local function emoteInLobby()
	return player:GetAttribute("BBParticipating") ~= true
		and player:GetAttribute("TGParticipating") ~= true
		and player:GetAttribute("MDParticipating") ~= true
end

local function itemThumbnail(item)
	if not item then return "" end
	if typeof(item.thumbnail) == "string" and item.thumbnail ~= "" then return item.thumbnail end
	local id = item.catalogId
	if item.slot == "Emote" and typeof(id) == "number" and id == id and id > 0 and id < math.huge and id % 1 == 0 then
		return "rbxthumb://type=Asset&id=" .. string.format("%.0f", id) .. "&w=420&h=420"
	end
	return ""
end

local function refreshThumbnail(record)
	if not alive or not record.card.Parent then return end
	local thumbnail = record.card.Thumbnail
	local status = record.card.ThumbnailStatus
	status.Visible = thumbnail.Visible and (thumbnail.Image == "" or not thumbnail.IsLoaded)
	status.Text = (thumbnail.Image == "" or record.thumbnailTimedOut) and "Preview unavailable" or "Loading preview..."
end

local function renderPreview(record, item)
	local id = item and item.id or nil
	local image = itemThumbnail(item)
	if record.previewId == id and record.card.Thumbnail.Image == image then return end
	record.previewId = id
	record.previewToken = (record.previewToken or 0) + 1
	local token = record.previewToken
	record.thumbnailTimedOut = false
	record.card.Preview.Visible = false
	record.card.Thumbnail.Image = image
	record.card.Thumbnail.Visible = item ~= nil
	refreshThumbnail(record)
	if item and image ~= "" and not record.card.Thumbnail.IsLoaded then
		task.delay(8, function()
			if alive and record.previewToken == token and record.card.Parent and record.card.Thumbnail.Image == image then
				record.thumbnailTimedOut = true
				refreshThumbnail(record)
			end
		end)
	end
end

local function requirement(item, unlock)
	local rule = item.unlock or { kind = "Coins", amount = item.price or 0 }
	if rule.kind == "Starter" then return "Starter reward", "FREE" end
	if rule.kind == "Coins" then return tostring(item.price or rule.amount or 0) .. " coins", item.category end
	local progress = unlock and unlock.progress or 0
	local target = rule.amount or 0
	if rule.kind == "Level" then return "Level " .. tostring(target), tostring(math.min(progress, target)) .. " / " .. tostring(target) end
	return tostring(target) .. " " .. (gameLabels[rule.gameId] or "total") .. " wins", tostring(math.min(progress, target)) .. " / " .. tostring(target)
end

local function isEquipped(item)
	if item.slot == "Gear" and typeof(data.equipped.Toys) == "table" then
		return table.find(data.equipped.Toys, item.id) ~= nil
	end
	return data.equipped[item.slot] == item.id
end

local function refreshCards()
	refreshWallet()
	local filtered = {}
	for _, item in ipairs(catalog.Items) do
		if category == "All" or item.category == category then table.insert(filtered, item) end
	end
	emoteEmptyState.Visible = category == "Emotes" and #filtered == 0
	pager.Visible = #filtered > 0
	pageCount = math.max(1, math.ceil(#filtered / math.max(1, #slots)))
	page = math.clamp(page, 1, pageCount)
	setText(pager.PageLabel, tostring(page) .. " / " .. tostring(pageCount))
	for _, spec in ipairs({ { pager.Previous, page > 1 }, { pager.Next, page < pageCount } }) do
		spec[1].Active = spec[2] and not busy
		spec[1].Selectable = spec[1].Active
		spec[1].BackgroundColor3 = spec[1].Active and blue or muted
	end
	for index, record in ipairs(slots) do
		local item = filtered[(page - 1) * #slots + index]
		local card = record.card
		record.item = item
		card.Visible = item ~= nil
		renderPreview(record, item)
		if item then
			card:SetAttribute("CatalogId", item.id)
			setText(card:FindFirstChild("Name"), item.name)
			local owned = data.owned[item.id] == true
			local equipped = isEquipped(item)
			local unlock = data.unlocks[item.id]
			local price, detail = requirement(item, unlock)
			setText(card.Price, owned and (equipped and "Equipped" or "Owned") or price)
			setText(card.Category, owned and item.category or detail)
			local isCoins = item.unlock and item.unlock.kind == "Coins"
			local canBuy = isCoins and (unlock and unlock.purchasable == true or not unlock and data.coins >= (item.price or 0))
			local available = item.available ~= false and (item.slot ~= "Emote" or emotePlayable(item))
			local action = not available and "UNAVAILABLE" or not data.ready and "LOADING" or equipped and "UNEQUIP" or owned and "EQUIP" or isCoins and "BUY" or "LOCKED"
			if busy then action = "PLEASE WAIT" end
			setText(card.Action, action)
			card.Action.Visible = true
			card.Action.Active = not busy and data.ready and available and (owned or canBuy)
			card.Action.Selectable = card.Action.Active
			card.Action.BackgroundColor3 = not card.Action.Active and muted or equipped and mint or owned and blue or gold
			local canPlay = emotePlayable(item) and owned
			setText(card.Try, canPlay and "PLAY" or "INFO")
			card.Try.Visible = true
			card.Try.Active = not canPlay or not busy and data.ready and emoteInLobby()
			card.Try.Selectable = card.Try.Active
			local outline = card:FindFirstChild("Outline")
			if outline then outline.Color = equipped and gold or ink end
		else
			card:SetAttribute("CatalogId", nil)
		end
	end
	for _, button in ipairs(shop.Categories:GetChildren()) do
		if button:IsA("TextButton") and button.Visible then button.BackgroundColor3 = button.Name == category and gold or white end
	end
end

local function applyReply(reply)
	if typeof(reply) ~= "table" then return end
	if typeof(reply.coins) == "number" then data.coins = reply.coins end
	if typeof(reply.ready) == "boolean" then data.ready = reply.ready end
	if typeof(reply.owned) == "table" then data.owned = reply.owned end
	if typeof(reply.equipped) == "table" then data.equipped = reply.equipped end
	if typeof(reply.unlocks) == "table" then data.unlocks = reply.unlocks end
	if typeof(reply.unlockSerial) == "number" and reply.unlockSerial ~= lastUnlockSerial then
		lastUnlockSerial = reply.unlockSerial
		if typeof(reply.newlyUnlocked) == "table" and #reply.newlyUnlocked > 0 then
			local names = {}
			for index, id in ipairs(reply.newlyUnlocked) do
				if index > 2 then break end
				local item = catalog.ById[id]
				if item then table.insert(names, item.name) end
			end
			if #names > 0 then
				local more = #reply.newlyUnlocked > 2 and " and " .. tostring(#reply.newlyUnlocked - 2) .. " more" or ""
				showToast("Unlocked: " .. table.concat(names, ", ") .. more .. "!", 5)
			end
		end
	end
	refreshCards()
end

local request
request = function(action, id, quiet, onSuccess)
	if busy then
		if action == "GetStatus" then pendingStatus = true end
		return
	end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundShopRequest")
	if not remote or not remote:IsA("RemoteFunction") then
		if not quiet then shop.Status.Text = "The shop is getting ready. Try again in a moment." end
		return
	end
	busy = true
	refreshCards()
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, id) end)
		busy = false
		if ok and typeof(reply) == "table" then
			applyReply(reply)
			if reply.ok == true and onSuccess then onSuccess(reply) end
			if not quiet or not reply.ok then shop.Status.Text = tostring(reply.message or (reply.ok and "All set!" or "Try again in a moment.")) end
			if not reply.ok and not shop.Visible and not quiet then showToast(reply.message or "Try again in a moment.") end
		else
			refreshCards()
			if not quiet then shop.Status.Text = "That did not go through. Try again in a moment." end
		end
		if pendingStatus then
			pendingStatus = false
			task.defer(function() request("GetStatus", nil, true) end)
		end
	end)
end

local function setShop(visible)
	shop.Visible = visible
	gui.Backdrop.Visible = visible
	if visible then
		shop.Status.Text = data.ready and "Earn rewards, or spend your coins." or "Your coins are loading..."
		request("GetStatus", nil, true)
	end
end

local function setCategory(value)
	category = value
	page = 1
	shop.Cards.CanvasPosition = Vector2.zero
	refreshCards()
end

local function useOrInfo(record)
	local item = record.item
	if not item or not record.card.Try.Active then return end
	if emotePlayable(item) and data.owned[item.id] then
		if busy or not data.ready or not emoteInLobby() then return end
		request("UseEmote", item.id, false, function()
			setShop(false)
			showToast("Starting " .. item.name .. ". Move to stop.", 3)
		end)
		return
	end
	local unlock = data.unlocks[item.id]
	local description = item.description or item.name
	if unlock and not data.owned[item.id] then description ..= " " .. unlock.label .. "." end
	showToast(description, 5)
end

for _, card in ipairs(shop.Cards:GetChildren()) do
	if card:IsA("Frame") and card:FindFirstChild("Preview") and card:FindFirstChild("Action") then
		table.insert(slots, { card = card })
	end
end
table.sort(slots, function(a, b) return a.card.Name < b.card.Name end)
for _, record in ipairs(slots) do
	record.card.Action.Activated:Connect(function()
		local item = record.item
		if busy or not data.ready or not item or not record.card.Action.Active then return end
		if isEquipped(item) then request("Unequip", item.slot == "Gear" and item.id or item.slot)
		elseif data.owned[item.id] then request("Equip", item.id)
		else request("Buy", item.id) end
	end)
	record.card.Try.Activated:Connect(function() useOrInfo(record) end)
	table.insert(thumbnailConnections, record.card.Thumbnail:GetPropertyChangedSignal("IsLoaded"):Connect(function() refreshThumbnail(record) end))
end
for _, button in ipairs(shop.Categories:GetChildren()) do
	if button:IsA("TextButton") and button.Visible then button.Activated:Connect(function() setCategory(button.Name) end) end
end
pager.Previous.Activated:Connect(function()
	if busy or page <= 1 then return end
	page -= 1
	shop.Cards.CanvasPosition = Vector2.zero
	refreshCards()
end)
pager.Next.Activated:Connect(function()
	if busy or page >= pageCount then return end
	page += 1
	shop.Cards.CanvasPosition = Vector2.zero
	refreshCards()
end)
dock.Shop.Activated:Connect(function() setShop(not shop.Visible) end)
shop.Close.Activated:Connect(function() setShop(false) end)
gui.Backdrop.Activated:Connect(function() setShop(false) end)
dock.Pets.Activated:Connect(function() setCategory("Pets") setShop(true) end)
dock.Toys.Activated:Connect(function() setCategory("Toys") setShop(true) end)
gui:GetAttributeChangedSignal("OpenEmoteShopSerial"):Connect(function()
	if not alive or not emoteInLobby() then return end
	setCategory("Emotes")
	setShop(true)
end)
for _, attribute in ipairs({ "PCCoins", "PCWins", "PCLevel", "PCDataReady" }) do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		local wasReady = data.ready
		data.coins = player:GetAttribute("PCCoins") or data.coins
		data.ready = player:GetAttribute("PCDataReady") == true
		refreshCards()
		if data.ready and not wasReady then request("GetStatus", nil, true) end
	end)
end
player:GetAttributeChangedSignal("PCInventoryVersion"):Connect(function() request("GetStatus", nil, true) end)
player:GetAttributeChangedSignal("PCEmotePlaybackStatus"):Connect(function()
	if player:GetAttribute("PCEmotePlaybackStatus") == "failed" then
		showToast(player:GetAttribute("PCEmotePlaybackMessage") or "That emote could not load. Please try again.", 5)
	end
end)
player:GetAttributeChangedSignal("PCRewardAt"):Connect(function()
	local now = player:GetAttribute("PCRewardAt")
	if now and now ~= lastReward then
		lastReward = now
		local message = player:GetAttribute("PCRewardText")
		if typeof(message) == "string" and message ~= "" then showToast(message, 4) end
	end
end)
local coinPickupConnection = player:GetAttributeChangedSignal("PCCoinPickupSerial"):Connect(function()
	local serial = player:GetAttribute("PCCoinPickupSerial")
	if typeof(serial) ~= "number" or serial <= lastCoinPickup then return end
	lastCoinPickup = serial
	showCoinPickup(player:GetAttribute("PCCoinPickupAmount"), player:GetAttribute("PCCoinPickupPosition"))
end)
script.Destroying:Connect(function()
	alive = false
	for _, connection in ipairs(thumbnailConnections) do connection:Disconnect() end
	for _, record in ipairs(slots) do record.previewToken = (record.previewToken or 0) + 1 end
	coinPickupConnection:Disconnect()
	while next(coinPopups) do clearCoinPopup(next(coinPopups)) end
end)
ReplicatedStorage.ChildAdded:Connect(function(child)
	if child.Name == "PlaygroundShopRequest" then request("GetStatus", nil, true) end
end)

local function insideZone(zone,root)
 if not zone or not zone:IsA("BasePart") or not root then return false end
 local point=zone.CFrame:PointToObjectSpace(root.Position)
 return math.abs(point.X)<=zone.Size.X/2 and math.abs(point.Y)<=zone.Size.Y/2 and math.abs(point.Z)<=zone.Size.Z/2
end
local function votesText(count)
 return tostring(count)..(count==1 and " vote" or " votes")
end
local function refreshVotes()
 local phase=state and state:GetAttribute("Phase") or "Waiting"
 local voting=phase=="Voting"
 local chosen=player:GetAttribute("PCVote")
 for _,vote in ipairs(votePanels) do
 vote.Title.Text=voting and "PICK THE NEXT ROUND" or "NEXT ROUND"
 local ending=state and state:GetAttribute("VotingEndsAt") or 0
 vote.Timer.Text=voting and tostring(math.max(0,math.ceil(ending-workspace:GetServerTimeNow()))).."s" or phase=="Playing" and "PLAYING" or phase=="Paused" and "PAUSED" or "WAITING"
 vote.VotesBritishBulldog.Text=votesText(state and state:GetAttribute("VotesBritishBulldog") or 0)
 vote.VotesTagYoureIt.Text=votesText(state and state:GetAttribute("VotesTagYoureIt") or 0)
 vote.VotesStuckInTheMud.Text=votesText(state and state:GetAttribute("VotesStuckInTheMud") or 0)
 vote.BritishBulldog.BackgroundColor3=chosen=="BritishBulldog" and gold or blue
 vote.TagYoureIt.BackgroundColor3=chosen=="TagYoureIt" and gold or pink
 vote.StuckInTheMud.BackgroundColor3=chosen=="StuckInTheMud" and gold or mint
 vote.BritishBulldog.Active=voting and not voteBusy
 vote.TagYoureIt.Active=voting and not voteBusy
 local mudAvailable=state and state:GetAttribute("AvailableStuckInTheMud")~=false
 vote.StuckInTheMud.Active=voting and not voteBusy and mudAvailable
 if not mudAvailable then
  vote.StuckInTheMud.BackgroundColor3=Color3.fromRGB(162,169,184)
  local minimum=state:GetAttribute("MinimumStuckInTheMud") or 4
  vote.VotesStuckInTheMud.Text=(state:GetAttribute("ReadyPlayerCount") or 0)<minimum and "Needs "..tostring(minimum).." players" or "Unavailable"
 end
 vote.StuckInTheMud.Selectable=vote.StuckInTheMud.Active
 vote.BritishBulldog.Selectable=vote.BritishBulldog.Active
 vote.TagYoureIt.Selectable=vote.TagYoureIt.Active
 if not voteBusy then
  vote.Message.Text=voting and (chosen and chosen~="" and "Your vote is saved. You can change it." or "Step onto a card to vote, or tap it here.") or phase=="Playing" and "Another round is underway." or phase=="Paused" and "The next round is paused." or "Voting opens when the next round is ready."
 end
 end
end
local function bindState(object)
 if not object or object==state then return end
 if stateConnection then stateConnection:Disconnect() end
 state=object
 stateConnection=state.AttributeChanged:Connect(refreshVotes)
 refreshVotes()
end
bindState(ReplicatedStorage:FindFirstChild("PlaygroundState"))
ReplicatedStorage.ChildAdded:Connect(function(child) if child.Name=="PlaygroundState" then bindState(child) end end)
player:GetAttributeChangedSignal("PCVote"):Connect(refreshVotes)
local function castVote(id)
 if voteBusy or not state or state:GetAttribute("Phase")~="Voting" then return end
 local remote=ReplicatedStorage:FindFirstChild("PlaygroundVoteRequest")
 if not remote or not remote:IsA("RemoteFunction") then return end
 voteBusy=true
 refreshVotes()
 task.spawn(function()
  local ok,reply=pcall(function() return remote:InvokeServer(id) end)
  voteBusy=false
  refreshVotes()
  if not ok then
   for _,panel in ipairs(votePanels) do panel.Message.Text="That vote did not go through. Try again." end
  elseif typeof(reply)=="table" and reply.ok==false then
   for _,panel in ipairs(votePanels) do panel.Message.Text=tostring(reply.message or "Step into the voting area first.") end
  end
 end)
end
for _,panel in ipairs(votePanels) do
 for _,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud"}) do panel[id].Activated:Connect(function() castVote(id) end) end
end
player.CharacterAdded:Connect(function() wasInsideShop=false end)
local elapsed=0
RunService.Heartbeat:Connect(function(delta)
 elapsed+=delta
 if elapsed<0.15 then return end
 elapsed=0
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local lobby=workspace:FindFirstChild("Playground Lobby")
 local gameplay=lobby and lobby:FindFirstChild("Gameplay")
 local participating=player:GetAttribute("BBParticipating")==true or (player:GetAttribute("TGParticipating")==true or player:GetAttribute("MDParticipating")==true)
 wallet.Visible=not participating
 dock.Visible=not participating
 if participating and shop.Visible then setShop(false) end
 local shopZone=gameplay and gameplay:FindFirstChild("ShopZone")
 local voteZone=gameplay and gameplay:FindFirstChild("VoteZone")
 local inShop=insideZone(shopZone,root)
 if inShop and not wasInsideShop and not participating then setShop(true) end
 wasInsideShop=inShop
 local showVote=not participating and insideZone(voteZone,root) and not shop.Visible
 local camera=workspace.CurrentCamera
 local useCompactVote=camera and (camera.ViewportSize.X<980 or camera.ViewportSize.Y<450) or false
 vote.Visible=showVote and not useCompactVote
 compactVote.Visible=showVote and useCompactVote
 if showVote then refreshVotes() end
end)
refreshCards()
refreshVotes()
request("GetStatus",nil,true)




]========]},
{path="StarterGui.PlaygroundToyHotbar.Controller",before=[========[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local gui = script.Parent
local bar = gui:WaitForChild("Bar")
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then bar.Visible = false return end
local catalog = require(catalogObject)
local connections = {}
local slots = {}
local alive = true
local pending = false
local requestToken = 0
local notice = ""
local noticeUntil = 0
local activeIndex = 0
local activeId = ""
local refresh
local backpackSuppressed = false
local savedBackpackState = nil

local function showNativeBackpack(show)
	if not show and not backpackSuppressed then
		local ok, previous = pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) end)
		if not ok then return end
		local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
		if applied then savedBackpackState = previous backpackSuppressed = true end
	elseif show and backpackSuppressed then
		local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, savedBackpackState) end)
		if applied then backpackSuppressed = false savedBackpackState = nil end
	end
end

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function inRound()
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end

local function modalOpen()
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if shell then
		for _, name in ipairs({ "ShopPanel", "VotePanel", "CompactVotePanel" }) do
			local panel = shell:FindFirstChild(name)
			if panel and panel.Visible then return true end
		end
	end
	local admin = player.PlayerGui:FindFirstChild("PlaygroundAdminPanel")
	local adminHub = admin and admin:FindFirstChild("AdminHub")
	if admin and admin.Enabled and adminHub and adminHub.Visible then return true end
	return GuiService.MenuIsOpen
end

local function usable()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player:GetAttribute("PCDataReady") == true and not inRound() and humanoid and humanoid.Health > 0
end

local function tell(message, seconds)
	notice = tostring(message or "")
	noticeUntil = workspace:GetServerTimeNow() + (seconds or 3)
end

local function cooldownEndsAt(id)
	local now = workspace:GetServerTimeNow()
	local ember = tonumber(player:GetAttribute("PCToyEmberUntil")) or 0
	local attribute = id == "M07" and ember > now and "PCToyEmberShotUntil" or "PCToyCooldown_" .. id
	return tonumber(player:GetAttribute(attribute)) or 0
end

local function bounds(model)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
				local point = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
				low = low:Min(point)
				high = high:Max(point)
			end end end
		end
	end
	if low.X == math.huge then return Vector3.zero, Vector3.one end
	return (low + high) * 0.5, high - low
end

local function framePreview(record)
	if not record.model or not record.model.Parent then return end
	local viewport = record.button.Preview
	local camera = viewport:FindFirstChild("PreviewCamera")
	if not camera or not camera:IsA("Camera") then
		camera = Instance.new("Camera")
		camera.Name = "PreviewCamera"
		camera.FieldOfView = viewport:GetAttribute("PreviewFieldOfView") or 35
		camera.Parent = viewport
	end
	local aspect = math.max(0.2, viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y))
	local angle = math.rad(camera.FieldOfView * 0.5)
	local distance = record.radius / math.sin(math.min(angle, math.atan(math.tan(angle) * aspect))) * 1.1
	camera.CFrame = CFrame.lookAt(Vector3.new(0.5, 0.2, -1).Unit * distance, Vector3.zero)
	viewport.CurrentCamera = camera
end

local function preview(record, id)
	if record.id == id and (id == "" or record.model) then return end
	record.id = id
	record.generation += 1
	local generation = record.generation
	local world = record.button.Preview.World
	for _, child in ipairs(world:GetChildren()) do child:Destroy() end
	record.model = nil
	record.button.Preview.Visible = id ~= ""
	record.button.PreviewNote.Visible = false
	if id == "" then return end
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local original = assets and assets:FindFirstChild(id)
	if not original or not original:IsA("Model") then
		record.button.PreviewNote.Text = "NO PREVIEW"
		record.button.PreviewNote.Visible = true
		return
	end
	local model = original:Clone()
	model.Name = "ToyPreview"
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
		elseif child:IsA("ParticleEmitter") or child:IsA("Trail") then child.Enabled = false end
	end
	local center, size = bounds(model)
	model:PivotTo(CFrame.new(-center) * model:GetPivot())
	model.Parent = world
	record.model = model
	record.radius = math.max(0.05, size.Magnitude * 0.5)
	framePreview(record)
	local complete = false
	task.delay(8, function()
		if alive and generation == record.generation and not complete then
			record.button.PreviewNote.Text = "PREVIEW DELAYED"
			record.button.PreviewNote.Visible = true
		end
	end)
	task.spawn(function()
		local loaded = true
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ model }, function(contentId, status)
				if contentId ~= "" and status ~= Enum.AssetFetchStatus.Success then loaded = false end
			end)
		end)
		complete = true
		if not alive or generation ~= record.generation or not world.Parent then return end
		record.button.PreviewNote.Visible = not ok or not loaded
		record.button.PreviewNote.Text = "PREVIEW DELAYED"
		model.Parent = nil
		model.Parent = world
		framePreview(record)
	end)
end

local function syncLoadout()
	if not alive then return end
	for index, record in ipairs(slots) do
		local id = player:GetAttribute("PCToySlot" .. tostring(index))
		if typeof(id) ~= "string" or not catalog.ById[id] then id = "" end
		preview(record, id)
		record.button.ItemName.Text = id ~= "" and catalog.ById[id].name or "EMPTY"
	end
	activeIndex = math.clamp(math.floor(tonumber(player:GetAttribute("PCToyIndex")) or 0), 0, 4)
	activeId = slots[activeIndex] and slots[activeIndex].id or ""
	refresh()
end

local function invoke(remoteName, action, payload, itemId)
	if pending or not alive then return end
	local remote = ReplicatedStorage:FindFirstChild(remoteName)
	if not remote or not remote:IsA("RemoteFunction") then tell("Toys are getting ready.") refresh() return end
	pending = true
	requestToken += 1
	local token = requestToken
	refresh()
	task.delay(8, function()
		if not alive or requestToken ~= token or not pending then return end
		requestToken += 1
		pending = false
		tell("That took too long. Try again.")
		refresh()
	end)
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, payload) end)
		if not alive or requestToken ~= token then return end
		pending = false
		if ok and typeof(reply) == "table" then
			if reply.message then tell(reply.message) elseif not reply.ok then tell("That did not go through.") end
		else
			tell("That did not go through. Try again.")
		end
		refresh()
	end)
end

local function aimAt(screenPosition)
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local position = screenPosition or camera.ViewportSize * 0.5
	local ray = screenPosition and camera:ScreenPointToRay(position.X, position.Y) or camera:ViewportPointToRay(position.X, position.Y)
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = player.Character and { player.Character } or {}
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, parameters)
	return hit and hit.Position or ray.Origin + ray.Direction * 150
end

local function useToy(position)
	if not gui.Enabled or not bar.Visible or not usable() or modalOpen() or activeId == "" or pending then return end
	local item = catalog.ById[activeId]
	if item and item.toyActionPending then tell("This toy's action is coming soon.") refresh() return end
	if cooldownEndsAt(activeId) > workspace:GetServerTimeNow() then return end
	invoke("PlaygroundToyRequest", "Use", aimAt(position), activeId)
end

local function selectToy(index)
	local record = slots[index]
	if not gui.Enabled or not record or record.id == "" or not bar.Visible or not usable() or modalOpen() or pending then return end
	invoke("PlaygroundShopRequest", "SelectToy", index)
end

refresh = function()
	if not alive then return end
	local hasToy = false
	for _, record in ipairs(slots) do if record.id ~= "" then hasToy = true break end end
	local available = usable()
	bar.Visible = hasToy and player:GetAttribute("PCDataReady") == true and not inRound() and not modalOpen()
	showNativeBackpack(not (hasToy and player:GetAttribute("PCDataReady") == true and not inRound() and gui.Enabled))
	local now = workspace:GetServerTimeNow()
	local remaining = math.max(0, cooldownEndsAt(activeId) - now)
	local item = catalog.ById[activeId]
	local actionPending = item and item.toyActionPending == true
	local character = player.Character
	local heldTool = character and character:FindFirstChildOfClass("Tool")
	local heldId = heldTool and heldTool:GetAttribute("CatalogId")
	for index, record in ipairs(slots) do
		local selected = index == activeIndex and record.id ~= ""
		local selectionTag = record.button:FindFirstChild("Selected")
		selectionTag.Visible = selected
		selectionTag.Text = selected and heldId == record.id and "HELD" or "READY"
		record.button.Key.TextColor3 = selected and Color3.fromRGB(255, 215, 74) or Color3.fromRGB(255, 249, 224)
		record.button.Active = available and not pending and record.id ~= ""
		record.button.Selectable = record.button.Active
		record.button.ReusableSkin.ImageColor3 = record.id == "" and Color3.fromRGB(155, 155, 155) or Color3.new(1, 1, 1)
	end
	bar.Use.Active = available and not pending and activeId ~= "" and remaining <= 0 and not actionPending
	bar.Use.Selectable = bar.Use.Active
	local label = pending and "WAIT..." or actionPending and "SOON" or remaining > 0 and string.format("%.1fs", remaining) or "USE"
	bar.Use.Text = label
	bar.Use.LiveCaption.Text = label
	bar.Use.ReusableSkin.ImageColor3 = bar.Use.Active and Color3.new(1, 1, 1) or Color3.fromRGB(165, 165, 165)
	bar.Status.Text = now < noticeUntil and notice or not available and "Respawning..." or activeId == "" and "Select a toy" or actionPending and "Action coming soon" or UserInputService.TouchEnabled and "Tap a slot, then USE" or "1–4 select • click to use"
	local ember = tonumber(player:GetAttribute("PCToyEmberUntil")) or 0
	gui.Crosshair.Visible = bar.Visible and available and (activeId == "M10" or activeId == "M07" and ember > now)
end

for index = 1, 4 do
	local button = bar.Slots:WaitForChild("Slot" .. tostring(index))
	local record = { button = button, id = nil, generation = 0 }
	table.insert(slots, record)
	connect(button.Activated, function() selectToy(index) end)
	connect(button.Preview:GetPropertyChangedSignal("AbsoluteSize"), function() framePreview(record) end)
end
connect(bar.Use.Activated, function() useToy(nil) end)
local numberKeys = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4 }
connect(UserInputService.InputBegan, function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	local index = numberKeys[input.KeyCode]
	if index then selectToy(index)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then useToy(UserInputService:GetMouseLocation())
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then useToy(nil) end
end)
connect(UserInputService.TouchTapInWorld, function(position, processed)
	if not processed and not UserInputService:GetFocusedTextBox() then useToy(position) end
end)
connect(player:GetAttributeChangedSignal("PCToyLoadoutVersion"), syncLoadout)
for _, key in ipairs({ "PCDataReady", "BBParticipating", "TGParticipating", "MDParticipating", "PCToyEmberUntil", "PCToyEmberShotUntil" }) do
	connect(player:GetAttributeChangedSignal(key), refresh)
end
for index = 1, 15 do connect(player:GetAttributeChangedSignal(string.format("PCToyCooldown_M%02d", index)), refresh) end
local elapsed = 0
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.1 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	alive = false
	showNativeBackpack(true)
	bar.Visible = false
	gui.Crosshair.Visible = false
	requestToken += 1
	for _, connection in ipairs(connections) do connection:Disconnect() end
	for _, record in ipairs(slots) do
		record.generation += 1
		if record.model then record.model:Destroy() end
	end
end)
syncLoadout()

]========],after=[========[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local gui = script.Parent
local bar = gui:WaitForChild("Bar")
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then bar.Visible = false return end
local catalog = require(catalogObject)
local connections = {}
local slots = {}
local alive = true
local pending = false
local requestToken = 0
local notice = ""
local noticeUntil = 0
local activeIndex = 0
local activeId = ""
local refresh
local backpackSuppressed = false
local savedBackpackState = nil

local function showNativeBackpack(show)
	if not show and not backpackSuppressed then
		local ok, previous = pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) end)
		if not ok then return end
		local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
		if applied then savedBackpackState = previous backpackSuppressed = true end
	elseif show and backpackSuppressed then
		local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, savedBackpackState) end)
		if applied then backpackSuppressed = false savedBackpackState = nil end
	end
end

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function inRound()
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end

local function modalOpen()
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if shell then
		for _, name in ipairs({ "ShopPanel", "VotePanel", "CompactVotePanel" }) do
			local panel = shell:FindFirstChild(name)
			if panel and panel.Visible then return true end
		end
	end
	local wheel = player.PlayerGui:FindFirstChild("PlaygroundEmoteWheel")
	local wheelPanel = wheel and wheel:FindFirstChild("Panel")
	if wheel and wheel.Enabled and wheelPanel and wheelPanel.Visible then return true end
	local admin = player.PlayerGui:FindFirstChild("PlaygroundAdminPanel")
	local adminHub = admin and admin:FindFirstChild("AdminHub")
	if admin and admin.Enabled and adminHub and adminHub.Visible then return true end
	return GuiService.MenuIsOpen
end

local function usable()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player:GetAttribute("PCDataReady") == true and not inRound() and humanoid and humanoid.Health > 0
end

local function tell(message, seconds)
	notice = tostring(message or "")
	noticeUntil = workspace:GetServerTimeNow() + (seconds or 3)
end

local function cooldownEndsAt(id)
	local now = workspace:GetServerTimeNow()
	local ember = tonumber(player:GetAttribute("PCToyEmberUntil")) or 0
	local attribute = id == "M07" and ember > now and "PCToyEmberShotUntil" or "PCToyCooldown_" .. id
	return tonumber(player:GetAttribute(attribute)) or 0
end

local function refreshThumbnail(record)
	if not alive or not record.button.Parent then return end
	local thumbnail = record.button.Thumbnail
	local note = record.button.PreviewNote
	note.Visible = thumbnail.Visible and (thumbnail.Image == "" or not thumbnail.IsLoaded)
	note.Text = (thumbnail.Image == "" or record.thumbnailTimedOut) and "NO PREVIEW" or "LOADING..."
end

local function preview(record, id)
	local item = catalog.ById[id]
	local image = item and typeof(item.thumbnail) == "string" and item.thumbnail or ""
	if record.id == id and record.button.Thumbnail.Image == image then return end
	record.id = id
	record.generation += 1
	local generation = record.generation
	record.thumbnailTimedOut = false
	record.button.Preview.Visible = false
	record.button.Thumbnail.Image = image
	record.button.Thumbnail.Visible = id ~= ""
	refreshThumbnail(record)
	if id ~= "" and image ~= "" and not record.button.Thumbnail.IsLoaded then
		task.delay(8, function()
			if alive and generation == record.generation and record.button.Parent and record.button.Thumbnail.Image == image then
				record.thumbnailTimedOut = true
				refreshThumbnail(record)
			end
		end)
	end
end

local function syncLoadout()
	if not alive then return end
	for index, record in ipairs(slots) do
		local id = player:GetAttribute("PCToySlot" .. tostring(index))
		if typeof(id) ~= "string" or not catalog.ById[id] then id = "" end
		preview(record, id)
		record.button.ItemName.Text = id ~= "" and catalog.ById[id].name or "EMPTY"
	end
	activeIndex = math.clamp(math.floor(tonumber(player:GetAttribute("PCToyIndex")) or 0), 0, 4)
	activeId = slots[activeIndex] and slots[activeIndex].id or ""
	refresh()
end

local function invoke(remoteName, action, payload, itemId)
	if pending or not alive then return end
	local remote = ReplicatedStorage:FindFirstChild(remoteName)
	if not remote or not remote:IsA("RemoteFunction") then tell("Toys are getting ready.") refresh() return end
	pending = true
	requestToken += 1
	local token = requestToken
	refresh()
	task.delay(8, function()
		if not alive or requestToken ~= token or not pending then return end
		requestToken += 1
		pending = false
		tell("That took too long. Try again.")
		refresh()
	end)
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, payload) end)
		if not alive or requestToken ~= token then return end
		pending = false
		if ok and typeof(reply) == "table" then
			if reply.message then tell(reply.message) elseif not reply.ok then tell("That did not go through.") end
		else
			tell("That did not go through. Try again.")
		end
		refresh()
	end)
end

local function aimAt(screenPosition)
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local position = screenPosition or camera.ViewportSize * 0.5
	local ray = screenPosition and camera:ScreenPointToRay(position.X, position.Y) or camera:ViewportPointToRay(position.X, position.Y)
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = player.Character and { player.Character } or {}
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, parameters)
	return hit and hit.Position or ray.Origin + ray.Direction * 150
end

local function useToy(position)
	if not gui.Enabled or not bar.Visible or not usable() or modalOpen() or activeId == "" or pending then return end
	local item = catalog.ById[activeId]
	if item and item.toyActionPending then tell("This toy's action is coming soon.") refresh() return end
	if cooldownEndsAt(activeId) > workspace:GetServerTimeNow() then return end
	invoke("PlaygroundToyRequest", "Use", aimAt(position), activeId)
end

local function selectToy(index)
	local record = slots[index]
	if not gui.Enabled or not record or record.id == "" or not bar.Visible or not usable() or modalOpen() or pending then return end
	invoke("PlaygroundShopRequest", "SelectToy", index)
end

refresh = function()
	if not alive then return end
	local hasToy = false
	for _, record in ipairs(slots) do if record.id ~= "" then hasToy = true break end end
	local available = usable()
	bar.Visible = hasToy and player:GetAttribute("PCDataReady") == true and not inRound() and not modalOpen()
	showNativeBackpack(not (hasToy and player:GetAttribute("PCDataReady") == true and not inRound() and gui.Enabled))
	local now = workspace:GetServerTimeNow()
	local remaining = math.max(0, cooldownEndsAt(activeId) - now)
	local item = catalog.ById[activeId]
	local actionPending = item and item.toyActionPending == true
	local character = player.Character
	local heldTool = character and character:FindFirstChildOfClass("Tool")
	local heldId = heldTool and heldTool:GetAttribute("CatalogId")
	for index, record in ipairs(slots) do
		local selected = index == activeIndex and record.id ~= ""
		local selectionTag = record.button:FindFirstChild("Selected")
		selectionTag.Visible = selected
		selectionTag.Text = selected and heldId == record.id and "HELD" or "READY"
		record.button.Key.TextColor3 = selected and Color3.fromRGB(255, 215, 74) or Color3.fromRGB(255, 249, 224)
		record.button.Active = available and not pending and record.id ~= ""
		record.button.Selectable = record.button.Active
		record.button.ReusableSkin.ImageColor3 = record.id == "" and Color3.fromRGB(155, 155, 155) or Color3.new(1, 1, 1)
	end
	bar.Use.Active = available and not pending and activeId ~= "" and remaining <= 0 and not actionPending
	bar.Use.Selectable = bar.Use.Active
	local label = pending and "WAIT..." or actionPending and "SOON" or remaining > 0 and string.format("%.1fs", remaining) or "USE"
	bar.Use.Text = label
	bar.Use.LiveCaption.Text = label
	bar.Use.ReusableSkin.ImageColor3 = bar.Use.Active and Color3.new(1, 1, 1) or Color3.fromRGB(165, 165, 165)
	bar.Status.Text = now < noticeUntil and notice or not available and "Respawning..." or activeId == "" and "Select a toy" or actionPending and "Action coming soon" or UserInputService.TouchEnabled and "Tap a slot, then USE" or "1–4 select • click to use"
	local ember = tonumber(player:GetAttribute("PCToyEmberUntil")) or 0
	gui.Crosshair.Visible = bar.Visible and available and (activeId == "M10" or activeId == "M07" and ember > now)
end

for index = 1, 4 do
	local button = bar.Slots:WaitForChild("Slot" .. tostring(index))
	local record = { button = button, id = nil, generation = 0 }
	table.insert(slots, record)
	connect(button.Activated, function() selectToy(index) end)
	connect(button.Thumbnail:GetPropertyChangedSignal("IsLoaded"), function() refreshThumbnail(record) end)
end
connect(bar.Use.Activated, function() useToy(nil) end)
local numberKeys = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4 }
connect(UserInputService.InputBegan, function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	local index = numberKeys[input.KeyCode]
	if index then selectToy(index)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then useToy(UserInputService:GetMouseLocation())
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then useToy(nil) end
end)
connect(UserInputService.TouchTapInWorld, function(position, processed)
	if not processed and not UserInputService:GetFocusedTextBox() then useToy(position) end
end)
connect(player:GetAttributeChangedSignal("PCToyLoadoutVersion"), syncLoadout)
for _, key in ipairs({ "PCDataReady", "BBParticipating", "TGParticipating", "MDParticipating", "PCToyEmberUntil", "PCToyEmberShotUntil" }) do
	connect(player:GetAttributeChangedSignal(key), refresh)
end
for index = 1, 15 do connect(player:GetAttributeChangedSignal(string.format("PCToyCooldown_M%02d", index)), refresh) end
local elapsed = 0
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.1 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	alive = false
	showNativeBackpack(true)
	bar.Visible = false
	gui.Crosshair.Visible = false
	requestToken += 1
	for _, connection in ipairs(connections) do connection:Disconnect() end
	for _, record in ipairs(slots) do
		record.generation += 1
	end
end)
syncLoadout()


]========]}
}
local function resolve(path)
    local node = game
    for name in string.gmatch(path, "[^.]+") do node = assert(node:FindFirstChild(name), path .. " missing") end
    return node
end
local function normalized(source) return (source:gsub("\r\n", "\n")) end
for _, entry in ipairs(entries) do
    entry.object = resolve(entry.path)
    assert(normalized(entry.object.Source) == normalized(entry.before), "Source changed: " .. entry.path)
end
local backup = Instance.new("Folder")
backup.Name = "EmoteWheelBackup20261005"
backup:SetAttribute("CreatedFor", "Custom emote wheel and original UI-512 thumbnails")
backup.Parent = storage
for index, entry in ipairs(entries) do
    local copy = entry.object:Clone()
    copy.Name = "Source" .. tostring(index)
    copy:SetAttribute("OriginalPath", entry.path)
    copy.Parent = backup
end
for _, name in ipairs({ "PlaygroundShell", "PlaygroundToyHotbar" }) do
    local copy = starterGui[name]:Clone()
    copy.Name = name .. "UI"
    copy.Parent = backup
end
local ok, result = xpcall(function()
    local buildWheel = function()
local StarterGui = game:GetService("StarterGui")
assert(not StarterGui:FindFirstChild("PlaygroundEmoteWheel"), "PlaygroundEmoteWheel already exists; preserve the authored UI and controller before rebuilding")

local skins = {
	Panel = "https://www.roblox.com/asset/?id=117403446558356&version=1",
	Cream = "rbxassetid://80217215544210",
	Gold = "rbxassetid://84589903135132",
	Blue = "https://www.roblox.com/asset/?id=90528629970043&version=1",
	Purple = "rbxassetid://109174047078490",
	Disabled = "rbxassetid://101720017581430",
	Selected = "rbxassetid://85788093672458",
}
local ink = Color3.fromRGB(24, 30, 51)
local cream = Color3.fromRGB(255, 249, 229)

local function label(parent, name, text, position, size, maximum, minimum)
	local object = Instance.new("TextLabel")
	object.Name = name
	object.BackgroundTransparency = 1
	object.BorderSizePixel = 0
	object.Position = position
	object.Size = size
	object.Text = text
	object.Font = Enum.Font.FredokaOne
	object.TextColor3 = cream
	object.TextScaled = true
	object.TextWrapped = true
	object.TextXAlignment = Enum.TextXAlignment.Center
	object.TextYAlignment = Enum.TextYAlignment.Center
	object.TextStrokeTransparency = 1
	object.ZIndex = 7
	object.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.Name = "TextSizeLimit"
	limit.MinTextSize = minimum or 9
	limit.MaxTextSize = maximum or 22
	limit.Parent = object
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TextOutline"
	stroke.Color = ink
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.BorderStrokePosition = Enum.BorderStrokePosition.Outer
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = 0.085
	stroke.Parent = object
	return object
end

local function skin(parent, image, name)
	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = name or "ReusableSkin"
	imageLabel.BackgroundTransparency = 1
	imageLabel.BorderSizePixel = 0
	imageLabel.Size = UDim2.fromScale(1, 1)
	imageLabel.Image = image
	imageLabel.ScaleType = Enum.ScaleType.Slice
	imageLabel.SliceCenter = Rect.new(88, 88, 424, 232)
	imageLabel.SliceScale = 0.25
	imageLabel.ZIndex = parent.ZIndex
	imageLabel:SetAttribute("DefaultImage", image)
	imageLabel.Parent = parent
	return imageLabel
end

local function button(parent, name, text, position, size, image)
	local object = Instance.new("TextButton")
	object.Name = name
	object.BackgroundTransparency = 1
	object.BorderSizePixel = 0
	object.Position = position
	object.Size = size
	object.Text = text
	object.TextTransparency = 1
	object.TextStrokeTransparency = 1
	object.AutoButtonColor = false
	object.Selectable = true
	object.Active = true
	object.ZIndex = 6
	object:SetAttribute("NormalImage", image)
	object:SetAttribute("SelectedImage", skins.Gold)
	object:SetAttribute("DisabledImage", skins.Disabled)
	object.Parent = parent
	local hitSize = Instance.new("UISizeConstraint")
	hitSize.Name = "MinimumHitSize"
	hitSize.MinSize = Vector2.new(30, 26)
	hitSize.Parent = object
	skin(object, image)
	local caption = label(object, "LiveCaption", text, UDim2.fromScale(0.1, 0.18), UDim2.fromScale(0.8, 0.58), 21, 9)
	caption.ZIndex = 8
	return object
end

local gui = Instance.new("ScreenGui")
gui.Name = "PlaygroundEmoteWheel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 45
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = true
gui:SetAttribute("AuthoredUIVersion", 1)
gui:SetAttribute("SlotsPerPage", 8)
gui:SetAttribute("ToggleKeyboard", "Period")
gui:SetAttribute("ToggleGamepad", "DPadDown")
gui:SetAttribute("UsesOriginalEmoteThumbnails", true)

local backdrop = Instance.new("TextButton")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = ink
backdrop.BackgroundTransparency = 0.35
backdrop.BorderSizePixel = 0
backdrop.Text = ""
backdrop.AutoButtonColor = false
backdrop.Active = true
backdrop.Modal = true
backdrop.Selectable = false
backdrop.Visible = false
backdrop.ZIndex = 1
backdrop.Parent = gui

local toggle = button(gui, "Toggle", "EMOTES  [ . ]", UDim2.new(1, -18, 1, -160), UDim2.fromOffset(140, 38), skins.Purple)
toggle.AnchorPoint = Vector2.new(1, 1)
toggle.ZIndex = 10
toggle.ReusableSkin.ZIndex = 10
toggle.LiveCaption.ZIndex = 11
toggle:SetAttribute("PlacementNote", "12px above the authored 130px toy hotbar; independent of the existing dock")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundTransparency = 1
panel.BorderSizePixel = 0
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Size = UDim2.fromScale(0.94, 0.92)
panel.Visible = false
panel.Active = true
panel.ZIndex = 3
panel.Parent = gui
skin(panel, skins.Panel)
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.Name = "PanelAspect"
aspect.AspectRatio = 0.96
aspect.AspectType = Enum.AspectType.FitWithinMaxSize
aspect.DominantAxis = Enum.DominantAxis.Width
aspect.Parent = panel
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.Name = "SizeLimit"
sizeLimit.MinSize = Vector2.new(270, 281.25)
sizeLimit.MaxSize = Vector2.new(650, 680)
sizeLimit.Parent = panel
label(panel, "Title", "YOUR EMOTES", UDim2.fromScale(0.08, 0.025), UDim2.fromScale(0.72, 0.065), 34, 16)
local close = button(panel, "Close", "X", UDim2.fromScale(0.87, 0.027), UDim2.fromScale(0.085, 0.060), skins.Purple)

local wheel = Instance.new("Frame")
wheel.Name = "Wheel"
wheel.BackgroundTransparency = 1
wheel.BorderSizePixel = 0
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.fromScale(0.5, 0.415)
wheel.Size = UDim2.fromScale(0.94, 0.640)
wheel.ZIndex = 4
wheel.Parent = panel
local wheelAspect = Instance.new("UIAspectRatioConstraint")
wheelAspect.Name = "WheelAspect"
wheelAspect.AspectRatio = 1
wheelAspect.AspectType = Enum.AspectType.FitWithinMaxSize
wheelAspect.DominantAxis = Enum.DominantAxis.Width
wheelAspect.Parent = wheel

local templates = Instance.new("Folder")
templates.Name = "Templates"
templates.Parent = gui
local slot = Instance.new("ImageButton")
slot.Name = "EmoteSlot"
slot.AnchorPoint = Vector2.new(0.5, 0.5)
slot.Size = UDim2.fromScale(0.245, 0.245)
slot.BackgroundTransparency = 1
slot.BorderSizePixel = 0
slot.Image = ""
slot.AutoButtonColor = false
slot.Active = true
slot.Selectable = true
slot.Visible = false
slot.ZIndex = 5
slot:SetAttribute("NormalImage", skins.Cream)
slot:SetAttribute("SelectedImage", skins.Gold)
slot:SetAttribute("DisabledImage", skins.Disabled)
slot:SetAttribute("ContentSource", "Owned emote catalog entries")
slot.Parent = templates
skin(slot, skins.Cream)
local thumbnail = Instance.new("ImageLabel")
thumbnail.Name = "Thumbnail"
thumbnail.AnchorPoint = Vector2.new(0.5, 0)
thumbnail.Position = UDim2.fromScale(0.5, 0.065)
thumbnail.Size = UDim2.fromScale(0.72, 0.405)
thumbnail.BackgroundTransparency = 1
thumbnail.BorderSizePixel = 0
thumbnail.Image = ""
thumbnail.ScaleType = Enum.ScaleType.Fit
thumbnail.ZIndex = 6
thumbnail.Parent = slot
label(slot, "ItemName", "EMPTY", UDim2.fromScale(0.015, 0.475), UDim2.fromScale(0.97, 0.335), 17, 7)
label(slot, "State", "", UDim2.fromScale(0.08, 0.82), UDim2.fromScale(0.84, 0.16), 11, 7)
local selected = Instance.new("ImageLabel")
selected.Name = "Selected"
selected.AnchorPoint = Vector2.new(1, 0)
selected.Position = UDim2.fromScale(0.96, 0.025)
selected.Size = UDim2.fromScale(0.19, 0.19)
selected.BackgroundTransparency = 1
selected.BorderSizePixel = 0
selected.Image = skins.Selected
selected.ScaleType = Enum.ScaleType.Fit
selected.Visible = false
selected.ZIndex = 9
selected.Parent = slot

local slots = {}
for index = 1, 8 do
	local angle = -math.pi * 0.5 + (index - 1) * math.pi * 0.25
	local clone = slot:Clone()
	clone.Name = "Slot" .. index
	clone.Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.357, 0.5 + math.sin(angle) * 0.357)
	clone.LayoutOrder = index
	clone.Visible = true
	clone:SetAttribute("SlotIndex", index)
	clone.Parent = wheel
	slots[index] = clone
end

local hint = label(panel, "Hint", "CHOOSE AN\nEMOTE", UDim2.fromScale(0.37, 0.342), UDim2.fromScale(0.26, 0.085), 20, 8)
hint:SetAttribute("DefaultText", "CHOOSE AN\nEMOTE")
local stop = button(panel, "StopButton", "STOP", UDim2.fromScale(0.42, 0.448), UDim2.fromScale(0.16, 0.048), skins.Purple)
stop.Visible = false
stop.Active = false
stop.Selectable = false
stop:SetAttribute("RequiresServerStopEndpoint", true)

label(panel, "Status", "Loading your emotes...", UDim2.fromScale(0.075, 0.741), UDim2.fromScale(0.85, 0.038), 18, 9)
local previous = button(panel, "Previous", "<", UDim2.fromScale(0.22, 0.790), UDim2.fromScale(0.12, 0.074), skins.Blue)
label(panel, "PageLabel", "1 / 1", UDim2.fromScale(0.36, 0.794), UDim2.fromScale(0.28, 0.064), 20, 10)
local nextButton = button(panel, "Next", ">", UDim2.fromScale(0.66, 0.790), UDim2.fromScale(0.12, 0.074), skins.Blue)
local shop = button(panel, "ShopButton", "EMOTE SHOP", UDim2.fromScale(0.25, 0.894), UDim2.fromScale(0.50, 0.070), skins.Gold)
for index, object in ipairs(slots) do
	object.NextSelectionLeft = slots[(index - 2) % 8 + 1]
	object.NextSelectionRight = slots[index % 8 + 1]
	object.NextSelectionUp = close
	object.NextSelectionDown = shop
end
previous.NextSelectionRight = nextButton
nextButton.NextSelectionLeft = previous
previous.NextSelectionDown = shop
nextButton.NextSelectionDown = shop
shop.NextSelectionUp = slots[5]
close.NextSelectionDown = slots[1]
gui.Parent = StarterGui

return { path = gui:GetFullName(), slots = 8, version = 1, closed = not panel.Visible, stopAvailable = false }

    end
    local wheelResult = buildWheel()
    local buildThumbnails = function()
local function install(starterGui)
	local shell = assert(starterGui:FindFirstChild("PlaygroundShell"), "PlaygroundShell missing")
	local hotbar = assert(starterGui:FindFirstChild("PlaygroundToyHotbar"), "PlaygroundToyHotbar missing")
	local cards = shell.ShopPanel.Cards
	local templates = shell:FindFirstChild("Templates")
	local targets = {}
	for _, child in ipairs(cards:GetChildren()) do
		if child:IsA("Frame") and child:FindFirstChild("Preview") and child:FindFirstChild("Action") then table.insert(targets, child) end
	end
	local template = templates and templates:FindFirstChild("ItemCard")
	if template then table.insert(targets, template) end
	for index = 1, 4 do table.insert(targets, assert(hotbar.Bar.Slots:FindFirstChild("Slot" .. tostring(index)))) end
	local created = 0
	for _, host in ipairs(targets) do
		local preview = assert(host:FindFirstChild("Preview"), "Preview missing")
		local thumbnail = host:FindFirstChild("Thumbnail")
		if not thumbnail then
			thumbnail = Instance.new("ImageLabel")
			thumbnail.Name = "Thumbnail"
			thumbnail.AnchorPoint = preview.AnchorPoint
			thumbnail.Position = preview.Position
			thumbnail.Size = preview.Size
			thumbnail.Rotation = preview.Rotation
			thumbnail.ZIndex = preview.ZIndex
			thumbnail.LayoutOrder = preview.LayoutOrder
			thumbnail.BackgroundTransparency = 1
			thumbnail.BorderSizePixel = 0
			thumbnail.ScaleType = Enum.ScaleType.Fit
			thumbnail.ImageColor3 = Color3.new(1, 1, 1)
			thumbnail.Visible = false
			thumbnail:SetAttribute("Purpose", "Original supplied item PNG; image bound from catalog.thumbnail")
			thumbnail.Parent = host
			created += 1
		end
		assert(thumbnail:IsA("ImageLabel"), "Thumbnail must be an editable ImageLabel")
		preview.Visible = false
	end
	return { created = created, targets = #targets }
end
return install


    end
    local thumbnailResult = buildThumbnails()(starterGui)
    for _, entry in ipairs(entries) do entry.object.Source = entry.after end
    local controller = starterGui.PlaygroundToyHotbar.Controller:Clone()
    controller.Name = "Controller"
    controller.Source = [========[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local gui = script.Parent
local panel = gui:WaitForChild("Panel")
local backdrop = gui:WaitForChild("Backdrop")
local toggle = gui:WaitForChild("Toggle")
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then toggle.Visible = false return end
local catalog = require(catalogObject)
local alive = true
local connections = {}
local slots = {}
local owned = {}
local equipped = {}
local ready = false
local page = 1
local pageCount = 1
local dances = {}
local busy = false
local requestSerial = 0
local requestWorker
local refreshQueued = false
local lastFetch = -math.huge
local notice = ""
local noticeUntil = 0
local previousSelection
local nativeSuppressed = false
local savedNativeState
local render
local request
local setOpen
local actionName = "PlaygroundEmoteWheelControls"
local numberKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight }

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function inRound()
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end

local function otherModalOpen()
	if GuiService.MenuIsOpen then return true end
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if shell then
		for _, name in ipairs({ "ShopPanel", "VotePanel", "CompactVotePanel" }) do
			local object = shell:FindFirstChild(name)
			if object and object.Visible then return true end
		end
	end
	local admin = player.PlayerGui:FindFirstChild("PlaygroundAdminPanel")
	local hub = admin and admin:FindFirstChild("AdminHub")
	return admin and admin.Enabled and hub and hub.Visible or false
end

local function isPlaying()
	local status = player:GetAttribute("PCEmotePlaybackStatus")
	return (status == "playing" or status == "loading") and (player:GetAttribute("PCEmoteUntil") or 0) > workspace:GetServerTimeNow()
end

local function tell(message, seconds)
	notice = tostring(message or "")
	noticeUntil = os.clock() + (seconds or 4)
end

local function gamepadActive()
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad", 1, true) ~= nil
end

local function buttonState(button, enabled, selected)
	button.Active = enabled
	button.Selectable = enabled
	local skin = button:FindFirstChild("ReusableSkin")
	local attribute = not enabled and "DisabledImage" or selected and "SelectedImage" or "NormalImage"
	local image = button:GetAttribute(attribute)
	if skin and typeof(image) == "string" then skin.Image = image end
end

local function restoreSelection()
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then
		GuiService.SelectedObject = previousSelection and previousSelection.Parent and previousSelection or nil
	end
	previousSelection = nil
end

local function selectFirst()
	if not gamepadActive() then return end
	for _, record in ipairs(slots) do
		if record.button.Visible and record.button.Selectable then GuiService.SelectedObject = record.button return end
	end
	GuiService.SelectedObject = panel.ShopButton
end

local function imageState(record)
	if not record.item then return end
	if record.button.Thumbnail.IsLoaded then
		record.imageStatus = ""
	else
		if panel.Visible and not record.imageStartedAt then record.imageStartedAt = os.clock() end
		record.imageStatus = record.imageStartedAt and os.clock() - record.imageStartedAt >= 8 and "IMAGE UNAVAILABLE" or "LOADING IMAGE"
	end
end

local function setImage(record, item)
	if record.item == item then imageState(record) return end
	record.item = item
	record.imageStartedAt = nil
	record.imageStatus = ""
	local thumbnail = record.button.Thumbnail
	thumbnail.Image = item and item.thumbnail or ""
	thumbnail.Visible = item ~= nil
	if not item then return end
	imageState(record)
end

render = function()
	if not alive then return end
	dances = {}
	for _, item in ipairs(catalog.Items) do
		if item.slot == "Emote" and item.playable == true and item.available ~= false and owned[item.id] == true then
			table.insert(dances, item)
		end
	end
	pageCount = math.max(1, math.ceil(#dances / 8))
	page = math.clamp(page, 1, pageCount)
	local active = isPlaying() and player:GetAttribute("PCEmoteAction") or ""
	for index, record in ipairs(slots) do
		local item = dances[(page - 1) * 8 + index]
		setImage(record, item)
		local button = record.button
		button.Visible = item ~= nil
		buttonState(button, item ~= nil and ready and not busy, item ~= nil and (active == item.id or record.hovered == true))
		button.ItemName.Text = item and item.name or ""
		record.selected.Visible = item ~= nil and (active == item.id or record.hovered == true)
		button.State.Text = item and (active == item.id and "PLAYING" or record.imageStatus ~= "" and record.imageStatus or equipped.Emote == item.id and "PODIUM EMOTE" or "") or ""
	end
	panel.PageLabel.Text = tostring(page) .. " / " .. tostring(pageCount)
	buttonState(panel.Previous, not busy and page > 1)
	buttonState(panel.Next, not busy and page < pageCount)
	buttonState(panel.StopButton, not busy and isPlaying())
	panel.StopButton.Visible = isPlaying()
	if notice ~= "" and os.clock() < noticeUntil then panel.Status.Text = notice
	elseif busy then panel.Status.Text = "Loading..."
	elseif not ready then panel.Status.Text = "Your emotes are getting ready."
	elseif #dances == 0 then panel.Status.Text = "No emotes yet. Unlock dances in the shop."
	else panel.Status.Text = tostring(#dances) .. " owned • Move or jump to stop" end
	panel.Hint.Text = not ready and "LOADING\nEMOTES" or #dances == 0 and "UNLOCK DANCES\nIN THE SHOP" or gamepadActive() and "A TO PLAY\nB TO CLOSE" or UserInputService.TouchEnabled and "TAP A\nDANCE" or "CLICK OR 1–8\nTO DANCE"
	local caption = toggle:FindFirstChild("LiveCaption")
	if caption then caption.Text = gamepadActive() and "EMOTES [D-PAD]" or UserInputService.TouchEnabled and "EMOTES" or "EMOTES [ . ]" end
end

local function acceptStatus(reply)
	if typeof(reply) ~= "table" then return false end
	if typeof(reply.owned) == "table" and typeof(reply.equipped) == "table" and typeof(reply.ready) == "boolean" then
		owned, equipped, ready = reply.owned, reply.equipped, reply.ready
		return true
	end
	return false
end

request = function(action, id)
	if not alive then return end
	if busy then
		if action == "GetStatus" then refreshQueued = true end
		return
	end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundShopRequest")
	if not remote or not remote:IsA("RemoteFunction") then tell("The emote shop is getting ready.") render() return end
	if action == "GetStatus" and os.clock() - lastFetch < 0.2 then
		refreshQueued = true
		return
	end
	busy = true
	requestSerial += 1
	local serial = requestSerial
	if action == "GetStatus" then lastFetch = os.clock() end
	render()
	task.delay(8, function()
		if not alive or serial ~= requestSerial or not busy then return end
		requestSerial += 1
		busy = false
		if requestWorker then pcall(task.cancel, requestWorker) requestWorker = nil end
		tell("That took too long. Open the wheel to try again.")
		render()
	end)
	requestWorker = task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, id) end)
		if not alive or serial ~= requestSerial then return end
		requestWorker = nil
		busy = false
		local valid = ok and acceptStatus(reply)
		if not valid then
			tell("The emote shop could not respond. Try again.")
		elseif action == "UseEmote" and reply.ok == true then
			notice = ""
			setOpen(false)
		elseif action ~= "GetStatus" then
			tell(reply.message ~= "" and reply.message or (reply.ok and "Done." or "Try again in a moment."))
		end
		render()
		if panel.Visible then selectFirst() end
	end)
end

setOpen = function(show)
	if not alive then return end
	if show and (not gui.Enabled or inRound() or otherModalOpen()) then return end
	if show == panel.Visible then return end
	panel.Visible = show
	backdrop.Visible = show
	if show then
		previousSelection = GuiService.SelectedObject
		notice = ""
		render()
		selectFirst()
		request("GetStatus")
	else
		restoreSelection()
	end
end

local function playSlot(index)
	local record = slots[index]
	if not panel.Visible or busy or not ready or inRound() or otherModalOpen() or not record or not record.item then return end
	request("UseEmote", record.item.id)
end

for index = 1, 8 do
	local button = panel.Wheel:WaitForChild("Slot" .. tostring(index))
	local record = { button = button, selected = button:WaitForChild("Selected"), imageStatus = "", hovered = false }
	table.insert(slots, record)
	connect(button.Activated, function() playSlot(index) end)
	connect(button.MouseEnter, function() record.hovered = true render() end)
	connect(button.MouseLeave, function() record.hovered = false render() end)
	connect(button.SelectionGained, function() record.hovered = true render() end)
	connect(button.SelectionLost, function() record.hovered = false render() end)
	connect(button.Thumbnail:GetPropertyChangedSignal("IsLoaded"), function() imageState(record) render() end)
end

local function movePage(delta)
	if busy then return end
	page = math.clamp(page + delta, 1, pageCount)
	for _, record in ipairs(slots) do record.hovered = false end
	render()
	selectFirst()
end

connect(toggle.Activated, function() setOpen(not panel.Visible) end)
connect(panel.Close.Activated, function() setOpen(false) end)
connect(backdrop.Activated, function() setOpen(false) end)
connect(panel.Previous.Activated, function() movePage(-1) end)
connect(panel.Next.Activated, function() movePage(1) end)
connect(panel.StopButton.Activated, function() if not busy then request("StopEmote") end end)
connect(panel.ShopButton.Activated, function()
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if not shell then tell("The shop is getting ready.") render() return end
	setOpen(false)
	shell:SetAttribute("OpenEmoteShopSerial", (tonumber(shell:GetAttribute("OpenEmoteShopSerial")) or 0) + 1)
end)

local function inputAction(_, state, input)
	if not gui.Enabled or UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
	local key = input.KeyCode
	if key == Enum.KeyCode.DPadDown and panel.Visible then return Enum.ContextActionResult.Pass end
	if key == Enum.KeyCode.Period or key == Enum.KeyCode.DPadDown then
		if inRound() or otherModalOpen() then return Enum.ContextActionResult.Pass end
		if state == Enum.UserInputState.Begin then setOpen(not panel.Visible) end
		return Enum.ContextActionResult.Sink
	end
	if not panel.Visible then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then
		if key == Enum.KeyCode.ButtonB then setOpen(false)
		elseif key == Enum.KeyCode.ButtonL1 then movePage(-1)
		elseif key == Enum.KeyCode.ButtonR1 then movePage(1)
		else
			local index = table.find(numberKeys, key)
			if index then playSlot(index) end
		end
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(actionName, inputAction, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Period, Enum.KeyCode.DPadDown, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, table.unpack(numberKeys))

for _, attribute in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating" }) do
	connect(player:GetAttributeChangedSignal(attribute), function() if inRound() then setOpen(false) end render() end)
end
for _, attribute in ipairs({ "PCInventoryVersion", "PCDataReady" }) do
	connect(player:GetAttributeChangedSignal(attribute), function()
		if player:GetAttribute("PCDataReady") ~= true then ready = false end
		refreshQueued = true
		render()
	end)
end
for _, attribute in ipairs({ "PCEmotePlaybackStatus", "PCEmoteAction", "PCEmoteUntil", "PCEmote" }) do
	connect(player:GetAttributeChangedSignal(attribute), function()
		if attribute == "PCEmotePlaybackStatus" and player:GetAttribute(attribute) == "failed" then
			tell(player:GetAttribute("PCEmotePlaybackMessage") or "This dance could not load.", 5)
		end
		render()
	end)
end
connect(UserInputService.LastInputTypeChanged, function() render() end)
connect(player.CharacterAdded, function() setOpen(false) refreshQueued = true end)
connect(player.CharacterRemoving, function() setOpen(false) end)
connect(gui:GetPropertyChangedSignal("Enabled"), function() if not gui.Enabled then setOpen(false) end end)
connect(ReplicatedStorage.ChildAdded, function(child) if child.Name == "PlaygroundShopRequest" then refreshQueued = true end end)

panel.Visible = false
backdrop.Visible = false
render()
refreshQueued = true

task.spawn(function()
	for _ = 1, 10 do
		if not alive then return end
		local ok, previous = pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu) end)
		if ok then
			local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false) end)
			if applied then savedNativeState = previous nativeSuppressed = true return end
		end
		task.wait(0.5)
	end
	warn("Playground emote wheel could not hide the native emote menu")
end)

task.spawn(function()
	while alive do
		local blocked = inRound() or otherModalOpen() or not gui.Enabled
		toggle.Visible = not blocked and not panel.Visible
		if blocked then setOpen(false) end
		if refreshQueued and not busy and os.clock() - lastFetch >= 0.2 then
			refreshQueued = false
			request("GetStatus")
		end
		if panel.Visible then render() end
		task.wait(0.2)
	end
end)

connect(script.Destroying, function()
	setOpen(false)
	alive = false
	requestSerial += 1
	if requestWorker then pcall(task.cancel, requestWorker) requestWorker = nil end
	ContextActionService:UnbindAction(actionName)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	if nativeSuppressed then pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, savedNativeState) end) end
end)
]========]
    controller.Parent = starterGui.PlaygroundEmoteWheel
    backup:SetAttribute("Installed", true)
    return { wheel = wheelResult, thumbnails = thumbnailResult, existingScriptCapabilitiesUnchanged = true, controllerCapabilities = tostring(controller.Capabilities), running = false }
end, debug.traceback)
if not ok then
    for _, entry in ipairs(entries) do pcall(function() entry.object.Source = entry.before end) end
    local wheel = starterGui:FindFirstChild("PlaygroundEmoteWheel")
    if wheel then wheel:Destroy() end
    for _, name in ipairs({ "PlaygroundShell", "PlaygroundToyHotbar" }) do
        local current = starterGui:FindFirstChild(name)
        if current then current:Destroy() end
        local restored = backup[name .. "UI"]:Clone()
        restored.Name = name
        restored.Parent = starterGui
    end
    backup:SetAttribute("InstallationError", tostring(result))
    error(result)
end
return game:GetService("HttpService"):JSONEncode(result)
