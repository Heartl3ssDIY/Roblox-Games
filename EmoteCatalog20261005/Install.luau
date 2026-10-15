assert(not game:GetService("RunService"):IsRunning(), "Install only in Edit mode")
assert(game.PlaceId == 95034648955135, "Wrong place")
local storage=game:GetService("ServerStorage")
assert(not storage:FindFirstChild("EmoteCatalogBackup20261005"), "Installation backup already exists; inspect before repeating")
local entries={
{path="ReplicatedStorage.PlaygroundCatalog",before=[====[
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

local byId = {}
for _, entry in ipairs(items) do
	assert(byId[entry.id] == nil, "Duplicate catalog ID: " .. entry.id)
	assert(entry.price >= 0 and entry.price <= 10000, "Catalog price exceeds the coin cap")
	byId[entry.id] = entry
end

byId.M09.toyActionPending = true

return {
	Items = items,
	ById = byId,
	Categories = { "All", "Bats", "Pets", "Toys", "Emotes" },
	EmoteAnimations = {},
	StarterBat = "B01",
	MaxCoinPrice = 10000,
	MaxToySlots = 4,
	GameNames = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It", StuckInTheMud = "Stuck in the Mud", All = "total" },
}


]====],after=[====[
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


]====]},
{path="ServerScriptService.PlaygroundEconomyService",before=[====[
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
	table.insert(profile.connections, player.CharacterAdded:Connect(function(character)
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
		profile.data.Equipped[id] = nil
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Unequipped.")
	end
	local item = typeof(id) == "string" and Catalog.ById[id]
	if not item or item.available == false then return self:Status(player, false, "This item is unavailable.") end
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
		profile.lastExpression = now
		if action == "UseEmote" then
			if item.slot ~= "Emote" then return self:Status(player, false, "Choose an emote.") end
			player:SetAttribute("PCEmoteAction", id)
			player:SetAttribute("PCEmoteUntil", workspace:GetServerTimeNow() + 2.4)
			local response = self:Status(player, true)
			return response
		end
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


]====],after=[====[
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


]====]},
{path="ServerScriptService.PlaygroundLeaderboardService",before=[====[
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Service = {}
Service.__index = Service
local definitions = {
	{ name = "HighestLevel", stat = "XP", store = "PlaygroundClassics_TopXP_v1" },
	{ name = "MostWins", stat = "Wins", store = "PlaygroundClassics_TopWins_v1" },
}
local regionNames = { Europe = "Europe", NorthAmerica = "North America", SouthAmerica = "South America", Africa = "Africa", Asia = "Asia", Oceania = "Oceania" }
local states = { ready = 1, loading = 2, stale = 3, unavailable = 4 }

local function integer(value, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(math.floor(value), 0, 1000000000)
end

local function validUserId(value)
	return typeof(value) == "number" and value == value and value > 0 and value < 1000000000000 and value % 1 == 0
end

local function ranked(a, b)
	return a.value > b.value or (a.value == b.value and a.userId < b.userId)
end

local function child(parent, name, className)
	local object = assert(parent:FindFirstChild(name), parent:GetFullName() .. "." .. name .. " is missing")
	assert(object:IsA(className), object:GetFullName() .. " must be a " .. className)
	return object
end

function Service.new(lobby, dependencies)
	local root = child(lobby, "Leaderboards", "Model")
	dependencies = dependencies or {}
	local self = setmetatable({ lobby = lobby, root = root, boards = {}, queue = {}, published = {}, identities = {}, identityBusy = {}, running = false, isStudio = RunService:IsStudio(), writeBusy = false, generation = 0, nextWriteAt = 0, nextReadAt = 0, flushDeadline = 0, regions = {}, regionLookups = {}, saved = {}, connections = {}, resolveRegion = dependencies.resolveRegion }, Service)
	for _, definition in ipairs(definitions) do
		local model = child(root, definition.name, "Model")
		local gui = child(child(model, "Face", "BasePart"), "Display", "SurfaceGui")
		local body = child(gui, "Body", "Frame")
		child(gui, "Empty", "TextLabel")
		child(gui, "Status", "TextLabel")
		local board = { definition = definition, gui = gui, rows = {}, entries = {}, state = "loading", status = "GLOBAL · CONNECTING", emptyText = "Scores are loading", refreshAt = 0 }
		for index = 1, 10 do
			local row = child(body, string.format("Row%02d", index), "Frame")
			for _, name in ipairs({ "Rank", "PlayerName", "Value" }) do child(row, name, "TextLabel") end
			child(child(row, "Avatar", "ImageLabel"), "Placeholder", "TextLabel")
			board.rows[index] = row
		end
		table.insert(self.boards, board)
	end
	self.global = { id = "global", label = "GLOBAL", boards = self.boards, queue = self.queue, published = self.published }
	return self
end

function Service:_level(xp)
	xp = integer(xp, 0)
	local base = math.max(1, integer(self.lobby:GetAttribute("BaseLevelXP"), 200))
	local step = integer(self.lobby:GetAttribute("LevelXPStep"), 50)
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
	return completed + 1
end

function Service:_identity(userId)
	local cached = self.identities[userId]
	if cached and cached.expires > os.clock() then return cached end
	local player = Players:GetPlayerByUserId(userId)
	local name = player and player.Name or (cached and cached.name) or "Player " .. userId
	if self.identityBusy[userId] then return cached or { name = name, image = "" } end
	self.identityBusy[userId] = true
	local nameOk = player ~= nil
	if not nameOk then
		local ok, value = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
		if ok and typeof(value) == "string" then name, nameOk = value, true end
	end
	local image = cached and cached.image or ""
	local ok, value, ready = pcall(function() return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
	if ok and ready and typeof(value) == "string" then image = value end
	cached = { name = name, image = image, expires = os.clock() + (nameOk and ok and ready and 600 or 30) }
	self.identities[userId] = cached
	self.identityBusy[userId] = nil
	return cached
end

function Service:_render(board, entries, status, state, emptyText)
	board.entries = entries
	board.status = status
	board.state = state or "ready"
	board.emptyText = emptyText or (self.isStudio and "No players yet" or "Your next win could put you here!")
	if not board.gui then return end
	for index, row in ipairs(board.rows) do
		local entry = entries[index]
		row.Visible = entry ~= nil
		if entry then
			row:SetAttribute("UserId", entry.userId)
			row.Rank.Text = tostring(index)
			row.PlayerName.Text = entry.name or ("Player " .. entry.userId)
			row.Avatar.Image = entry.image or ""
			row.Avatar.Placeholder.Visible = row.Avatar.Image == ""
			row.Value.Text = board.definition.stat == "XP" and ("LV " .. self:_level(entry.value)) or tostring(entry.value)
		end
	end
	board.gui.Empty.Visible = #entries == 0
	board.gui.Empty.Text = board.emptyText
	board.gui.Status.Text = status
end

function Service:_scopes()
	local result = { self.global }
	for _, region in pairs(self.regions) do table.insert(result, region) end
	return result
end

function Service:_connectStores()
	if self.isStudio then return end
	for _, scope in ipairs(self:_scopes()) do
		for _, board in ipairs(scope.boards) do
			if not board.store and os.clock() >= (board.connectAt or 0) then
				board.connectAt = os.clock() + 30
				local ok, store = pcall(function() return DataStoreService:GetOrderedDataStore(board.definition.store) end)
				if ok then board.store = store end
			end
		end
	end
end

function Service:_serverEntries(stat, regionId)
	local entries = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local region = self.regionLookups[player.UserId]
		if validUserId(player.UserId) and player:GetAttribute("PCDataReady") == true
			and (not regionId or (region and region.id == regionId)) then
			local cached = self.identities[player.UserId]
			table.insert(entries, { userId = player.UserId, value = integer(player:GetAttribute("PC" .. stat), 0), name = player.Name, image = cached and cached.image or "" })
		end
	end
	table.sort(entries, ranked)
	while #entries > 10 do table.remove(entries) end
	return entries
end

function Service:_refresh(board, generation, scope)
	scope = scope or self.global
	local entries = {}
	if self.isStudio then
		entries = self:_serverEntries(board.definition.stat, scope.id ~= "global" and scope.id or nil)
	else
		local ok, page = pcall(function()
			assert(board.store, "Leaderboard store unavailable")
			return board.store:GetSortedAsync(false, 10, 1):GetCurrentPage()
		end)
		if not self.running or self.generation ~= generation then return end
		if not ok then
			self:_render(board, board.entries, scope.label .. (#board.entries > 0 and " · RECONNECTING" or " · UNAVAILABLE RIGHT NOW"), #board.entries > 0 and "stale" or "unavailable", "Scores will appear when connected")
			return
		end
		for _, entry in ipairs(page) do
			local userId, value = tonumber(entry.key), integer(entry.value, nil)
			if validUserId(userId) and value then table.insert(entries, { userId = userId, value = value }) end
		end
	end
	table.sort(entries, ranked)
	while #entries > 10 do table.remove(entries) end
	for _, entry in ipairs(entries) do
		local identity = self:_identity(entry.userId)
		if not self.running or self.generation ~= generation then return end
		entry.name, entry.image = identity.name, identity.image
	end
	if not self.running or self.generation ~= generation then return end
	self:_render(board, entries, self.isStudio and (scope.id == "global" and "THIS SERVER · STUDIO PREVIEW" or scope.label .. " · STUDIO PREVIEW") or scope.label .. " · UPDATES EVERY MINUTE", "ready", self.isStudio and "No players yet" or scope.id ~= "global" and "Regional scores appear as players play and save" or nil)
end

function Service:_queueScores(scope, userId, scores)
	local xp, wins = scores.XP, scores.Wins
	local published = scope.published[userId] or { XP = 0, Wins = 0 }
	if xp <= published.XP and wins <= published.Wins then return true end
	local pending = scope.queue[userId]
	if pending then
		pending.XP, pending.Wins = math.max(pending.XP, xp), math.max(pending.Wins, wins)
	else
		scope.queue[userId] = { XP = xp, Wins = wins, due = os.clock(), attempts = 0 }
	end
	return true
end

function Service:_region(id)
	local region = self.regions[id]
	if region then return region end
	region = { id = id, label = "REGION · " .. string.upper(regionNames[id]), boards = {}, queue = {}, published = {} }
	for _, definition in ipairs(definitions) do
		table.insert(region.boards, {
			definition = { name = definition.name, stat = definition.stat, store = definition.store .. "_Region_" .. id },
			rows = {}, entries = {}, refreshAt = 0, state = "loading", status = region.label .. " · CONNECTING", emptyText = "Regional scores are loading",
		})
	end
	self.regions[id] = region
	return region
end

function Service:_resolvePlayer(player, generation)
	local userId = player.UserId
	if not validUserId(userId) then return end
	local lookup = self.regionLookups[userId]
	if not lookup then
		lookup = { state = "loading", attempts = 0, retryAt = 0 }
		self.regionLookups[userId] = lookup
	end
	if lookup.id or lookup.busy or lookup.state == "unavailable" or os.clock() < lookup.retryAt then return end
	if typeof(self.resolveRegion) ~= "function" then lookup.state = "unavailable" return end
	lookup.busy = true
	lookup.attempts += 1
	task.spawn(function()
		local ok, region = pcall(self.resolveRegion, player)
		lookup.busy = false
		if not self.running or self.generation ~= generation then return end
		if ok and typeof(region) == "table" and regionNames[region.id] then
			lookup.id, lookup.state = region.id, "ready"
			local scope = self:_region(region.id)
			if not self.isStudio and self.saved[userId] then self:_queueScores(scope, userId, self.saved[userId]) end
		elseif ok or lookup.attempts >= 3 then
			lookup.state = "unavailable"
		else
			lookup.retryAt = os.clock() + 15 * lookup.attempts
		end
	end)
end

function Service:PublishSaved(userId, profile)
	if self.isStudio or not validUserId(userId) or typeof(profile) ~= "table" then return false end
	local xp, wins = integer(profile.XP, nil), integer(profile.Wins, nil)
	if xp == nil or wins == nil then return false end
	local saved = self.saved[userId]
	self.saved[userId] = { XP = math.max(saved and saved.XP or 0, xp), Wins = math.max(saved and saved.Wins or 0, wins) }
	self:_queueScores(self.global, userId, self.saved[userId])
	local lookup = self.regionLookups[userId]
	if lookup and lookup.id then
		self:_queueScores(self:_region(lookup.id), userId, self.saved[userId])
	elseif self.running then
		local player = Players:GetPlayerByUserId(userId)
		if player then self:_resolvePlayer(player, self.generation) end
	end
	return true
end

function Service:_writeOne(generation, deadline)
	if self.writeBusy or self.isStudio or self.generation ~= generation or os.clock() < self.nextWriteAt then return end
	local userId, pending, scope
	for _, bucket in ipairs(self:_scopes()) do
		for id, candidate in pairs(bucket.queue) do
			if candidate.due <= os.clock() and (not pending or candidate.due < pending.due) then userId, pending, scope = id, candidate, bucket end
		end
	end
	if not pending then return end
	self.writeBusy = true
	self.nextWriteAt = os.clock() + 3
	local published = scope.published[userId] or { XP = 0, Wins = 0 }
	scope.published[userId] = published
	local success = true
	local interrupted = false
	for _, board in ipairs(scope.boards) do
		if self.generation ~= generation or (deadline and os.clock() >= deadline) then interrupted = true break end
		local stat = board.definition.stat
		local snapshot = pending[stat]
		if snapshot > published[stat] then
			local ok = pcall(function()
				assert(board.store, "Leaderboard store unavailable")
				board.store:UpdateAsync(tostring(userId), function(old) return math.max(integer(old, 0), snapshot) end)
			end)
			if self.generation ~= generation then interrupted = true break end
			if ok then published[stat] = snapshot else success = false end
		end
	end
	if success and not interrupted and published.XP >= pending.XP and published.Wins >= pending.Wins then
		scope.queue[userId] = nil
	elseif success and not interrupted then
		pending.due = os.clock()
	elseif not interrupted then
		pending.attempts += 1
		pending.due = os.clock() + math.min(120, 5 * 2 ^ math.min(pending.attempts, 5))
	end
	self.writeBusy = false
end

function Service:_activeRegions()
	local result = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local lookup = self.regionLookups[player.UserId]
		if lookup and lookup.id then result[lookup.id] = true end
	end
	return result
end

function Service:_refreshNext(generation)
	if os.clock() < self.nextReadAt then return end
	local active = self:_activeRegions()
	local chosen, chosenScope
	for _, scope in ipairs(self:_scopes()) do
		if scope.id == "global" or active[scope.id] then
			for _, board in ipairs(scope.boards) do
				if board.refreshAt <= os.clock() and (not chosen or board.refreshAt < chosen.refreshAt) then chosen, chosenScope = board, scope end
			end
		end
	end
	if not chosen then return end
	self.nextReadAt = os.clock() + (self.isStudio and 0.5 or 2)
	chosen.refreshAt = os.clock() + (self.isStudio and 5 or 60)
	local ok = pcall(function() self:_refresh(chosen, generation, chosenScope) end)
	if not ok and self.running and self.generation == generation then
		self:_render(chosen, chosen.entries, chosenScope.label .. " · UNAVAILABLE RIGHT NOW", #chosen.entries > 0 and "stale" or "unavailable", "Scores will appear when connected")
	end
end

function Service:_displayEntries(entries, stat)
	local result = {}
	for _, entry in ipairs(entries) do
		local cached = self.identities[entry.userId]
		table.insert(result, { userId = entry.userId, name = entry.name or (cached and cached.name) or "Player " .. entry.userId, image = cached and cached.image or entry.image or "", value = stat == "XP" and "LV " .. self:_level(entry.value) or tostring(entry.value) })
	end
	return result
end

function Service:GetSnapshot(player, requested)
	local scope = requested == "server" and "server" or requested == "region" and "region" or "global"
	local lookup = player and self.regionLookups[player.UserId]
	local regionId = lookup and lookup.id
	local response = { scope = scope, region = regionId and regionNames[regionId] or nil, regionId = regionId, boards = {}, state = "ready", retryAfter = 30 }
	if scope == "server" then
		response.status = self.isStudio and "THIS SERVER · STUDIO PREVIEW" or "THIS SERVER · CURRENT PLAYERS"
		for _, definition in ipairs(definitions) do
			response.boards[definition.name] = { entries = self:_displayEntries(self:_serverEntries(definition.stat), definition.stat), state = "ready", status = response.status, emptyText = "No players with loaded scores yet" }
		end
		return response
	end
	if scope == "region" and not regionId then
		response.state = lookup and lookup.state or (self.running and "loading" or "unavailable")
		response.status = response.state == "loading" and "REGION · FINDING YOUR REGION" or "REGION · LOCATION UNAVAILABLE"
		response.retryAfter = response.state == "loading" and 5 or 60
		for _, definition in ipairs(definitions) do
			response.boards[definition.name] = { entries = {}, state = response.state, status = response.status, emptyText = response.state == "loading" and "Finding your broad region" or "Your region could not be determined" }
		end
		return response
	end
	local bucket = scope == "global" and self.global or self.regions[regionId]
	for _, board in ipairs(bucket.boards) do
		response.boards[board.definition.name] = { entries = self:_displayEntries(board.entries, board.definition.stat), state = board.state, status = board.status, emptyText = board.emptyText }
		if states[board.state] > states[response.state] then response.state = board.state end
	end
	local suffix = response.state == "loading" and "CONNECTING" or response.state == "stale" and "RECONNECTING · SHOWING SAVED SCORES" or response.state == "unavailable" and "UNAVAILABLE RIGHT NOW" or "UPDATES EVERY MINUTE"
	response.status = self.isStudio and (scope == "global" and "THIS SERVER · STUDIO PREVIEW" or bucket.label .. " · STUDIO PREVIEW") or bucket.label .. " · " .. suffix
	response.retryAfter = response.state == "loading" and 5 or 30
	return response
end

function Service:Start()
	if self.running then return self end
	for _, board in ipairs(self.boards) do self:_render(board, board.entries, self.isStudio and "THIS SERVER · STUDIO PREVIEW" or "GLOBAL · CONNECTING", #board.entries > 0 and "stale" or "loading", "Scores are loading") end
	self.generation += 1
	local generation = self.generation
	self.running = true
	local function added(player)
		self:_resolvePlayer(player, generation)
		if validUserId(player.UserId) then task.spawn(function() if self.running and self.generation == generation then self:_identity(player.UserId) end end) end
	end
	table.insert(self.connections, Players.PlayerAdded:Connect(added))
	for _, player in ipairs(Players:GetPlayers()) do added(player) end
	task.spawn(function()
		while self.running and self.generation == generation do
			self:_connectStores()
			for _, player in ipairs(Players:GetPlayers()) do self:_resolvePlayer(player, generation) end
			self:_refreshNext(generation)
			task.wait(1)
		end
	end)
	task.spawn(function()
		while self.running and self.generation == generation do
			self:_writeOne(generation)
			task.wait(3)
		end
	end)
	return self
end

function Service:_pending()
	if self.writeBusy then return true end
	for _, scope in ipairs(self:_scopes()) do if next(scope.queue) then return true end end
	for userId, lookup in pairs(self.regionLookups) do
		if self.saved[userId] and lookup.state == "loading" then return true end
	end
	return false
end

function Service:Flush(seconds)
	if self.isStudio then return true end
	if typeof(seconds) ~= "number" or seconds ~= seconds or math.abs(seconds) == math.huge then seconds = 3 end
	local deadline = os.clock() + math.clamp(seconds, 0, 5)
	local generation = self.generation
	self.flushDeadline = math.max(self.flushDeadline, deadline)
	if self.flushWorkerGeneration ~= generation then
		self.flushWorkerGeneration = generation
		task.spawn(function()
			while self.generation == generation and os.clock() < self.flushDeadline and self:_pending() do
				self:_writeOne(generation, self.flushDeadline)
				task.wait(0.05)
			end
			if self.flushWorkerGeneration == generation then self.flushWorkerGeneration = nil end
		end)
	end
	while self.generation == generation and os.clock() < deadline and self:_pending() do task.wait(math.max(0, math.min(0.05, deadline - os.clock()))) end
	return not self:_pending()
end

function Service:Stop()
	self.running = false
	self.generation += 1
	self.flushDeadline = 0
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
end

return Service


]====],after=[====[
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Service = {}
Service.__index = Service
local definitions = {
	{ name = "HighestLevel", stat = "XP", store = "PlaygroundClassics_TopXP_v1" },
	{ name = "MostWins", stat = "Wins", store = "PlaygroundClassics_TopWins_v1" },
}
local regionNames = { Europe = "Europe", NorthAmerica = "North America", SouthAmerica = "South America", Africa = "Africa", Asia = "Asia", Oceania = "Oceania" }
local states = { ready = 1, loading = 2, stale = 3, unavailable = 4 }

local function integer(value, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(math.floor(value), 0, 1000000000)
end

local function validUserId(value)
	return typeof(value) == "number" and value == value and value > 0 and value < 1000000000000 and value % 1 == 0
end

local function ranked(a, b)
	return a.value > b.value or (a.value == b.value and a.userId < b.userId)
end

local function child(parent, name, className)
	local object = assert(parent:FindFirstChild(name), parent:GetFullName() .. "." .. name .. " is missing")
	assert(object:IsA(className), object:GetFullName() .. " must be a " .. className)
	return object
end

function Service.new(lobby, dependencies)
	local root = child(lobby, "Leaderboards", "Model")
	dependencies = dependencies or {}
	local self = setmetatable({ lobby = lobby, root = root, boards = {}, queue = {}, published = {}, identities = {}, identityBusy = {}, running = false, isStudio = RunService:IsStudio(), writeBusy = false, generation = 0, nextWriteAt = 0, nextReadAt = 0, flushDeadline = 0, regions = {}, regionLookups = {}, saved = {}, connections = {}, resolveRegion = dependencies.resolveRegion, resolveEmote = dependencies.resolveEmote }, Service)
	for _, definition in ipairs(definitions) do
		local model = child(root, definition.name, "Model")
		local gui = child(child(model, "Face", "BasePart"), "Display", "SurfaceGui")
		local body = child(gui, "Body", "Frame")
		child(gui, "Empty", "TextLabel")
		child(gui, "Status", "TextLabel")
		local board = { definition = definition, gui = gui, rows = {}, entries = {}, state = "loading", status = "GLOBAL · CONNECTING", emptyText = "Scores are loading", refreshAt = 0 }
		for index = 1, 10 do
			local row = child(body, string.format("Row%02d", index), "Frame")
			for _, name in ipairs({ "Rank", "PlayerName", "Value" }) do child(row, name, "TextLabel") end
			child(child(row, "Avatar", "ImageLabel"), "Placeholder", "TextLabel")
			board.rows[index] = row
		end
		table.insert(self.boards, board)
	end
	self.global = { id = "global", label = "GLOBAL", boards = self.boards, queue = self.queue, published = self.published }
	return self
end

function Service:_level(xp)
	xp = integer(xp, 0)
	local base = math.max(1, integer(self.lobby:GetAttribute("BaseLevelXP"), 200))
	local step = integer(self.lobby:GetAttribute("LevelXPStep"), 50)
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
	return completed + 1
end

function Service:_identity(userId)
	local cached = self.identities[userId]
	if cached and cached.expires > os.clock() then return cached end
	local player = Players:GetPlayerByUserId(userId)
	local name = player and player.Name or (cached and cached.name) or "Player " .. userId
	if self.identityBusy[userId] then return cached or { name = name, image = "" } end
	self.identityBusy[userId] = true
	local nameOk = player ~= nil
	if not nameOk then
		local ok, value = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
		if ok and typeof(value) == "string" then name, nameOk = value, true end
	end
	local image = cached and cached.image or ""
	local ok, value, ready = pcall(function() return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
	if ok and ready and typeof(value) == "string" then image = value end
	cached = { name = name, image = image, expires = os.clock() + (nameOk and ok and ready and 600 or 30) }
	self.identities[userId] = cached
	self.identityBusy[userId] = nil
	return cached
end

function Service:_render(board, entries, status, state, emptyText)
	board.entries = entries
	board.status = status
	board.state = state or "ready"
	board.emptyText = emptyText or (self.isStudio and "No players yet" or "Your next win could put you here!")
	if not board.gui then return end
	for index, row in ipairs(board.rows) do
		local entry = entries[index]
		row.Visible = entry ~= nil
		if entry then
			row:SetAttribute("UserId", entry.userId)
			row.Rank.Text = tostring(index)
			row.PlayerName.Text = entry.name or ("Player " .. entry.userId)
			row.Avatar.Image = entry.image or ""
			row.Avatar.Placeholder.Visible = row.Avatar.Image == ""
			row.Value.Text = board.definition.stat == "XP" and ("LV " .. self:_level(entry.value)) or tostring(entry.value)
		end
	end
	board.gui.Empty.Visible = #entries == 0
	board.gui.Empty.Text = board.emptyText
	board.gui.Status.Text = status
end

function Service:_scopes()
	local result = { self.global }
	for _, region in pairs(self.regions) do table.insert(result, region) end
	return result
end

function Service:_connectStores()
	if self.isStudio then return end
	for _, scope in ipairs(self:_scopes()) do
		for _, board in ipairs(scope.boards) do
			if not board.store and os.clock() >= (board.connectAt or 0) then
				board.connectAt = os.clock() + 30
				local ok, store = pcall(function() return DataStoreService:GetOrderedDataStore(board.definition.store) end)
				if ok then board.store = store end
			end
		end
	end
end

function Service:_serverEntries(stat, regionId)
	local entries = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local region = self.regionLookups[player.UserId]
		if validUserId(player.UserId) and player:GetAttribute("PCDataReady") == true
			and (not regionId or (region and region.id == regionId)) then
			local cached = self.identities[player.UserId]
			table.insert(entries, { userId = player.UserId, value = integer(player:GetAttribute("PC" .. stat), 0), name = player.Name, image = cached and cached.image or "" })
		end
	end
	table.sort(entries, ranked)
	while #entries > 10 do table.remove(entries) end
	return entries
end

function Service:_refresh(board, generation, scope)
	scope = scope or self.global
	local entries = {}
	if self.isStudio then
		entries = self:_serverEntries(board.definition.stat, scope.id ~= "global" and scope.id or nil)
	else
		local ok, page = pcall(function()
			assert(board.store, "Leaderboard store unavailable")
			return board.store:GetSortedAsync(false, 10, 1):GetCurrentPage()
		end)
		if not self.running or self.generation ~= generation then return end
		if not ok then
			self:_render(board, board.entries, scope.label .. (#board.entries > 0 and " · RECONNECTING" or " · UNAVAILABLE RIGHT NOW"), #board.entries > 0 and "stale" or "unavailable", "Scores will appear when connected")
			return
		end
		for _, entry in ipairs(page) do
			local userId, value = tonumber(entry.key), integer(entry.value, nil)
			if validUserId(userId) and value then table.insert(entries, { userId = userId, value = value }) end
		end
	end
	table.sort(entries, ranked)
	while #entries > 10 do table.remove(entries) end
	for _, entry in ipairs(entries) do
		local identity = self:_identity(entry.userId)
		if not self.running or self.generation ~= generation then return end
		entry.name, entry.image = identity.name, identity.image
	end
	if not self.running or self.generation ~= generation then return end
	self:_render(board, entries, self.isStudio and (scope.id == "global" and "THIS SERVER · STUDIO PREVIEW" or scope.label .. " · STUDIO PREVIEW") or scope.label .. " · UPDATES EVERY MINUTE", "ready", self.isStudio and "No players yet" or scope.id ~= "global" and "Regional scores appear as players play and save" or nil)
end

function Service:_queueScores(scope, userId, scores)
	local xp, wins = scores.XP, scores.Wins
	local published = scope.published[userId] or { XP = 0, Wins = 0 }
	if xp <= published.XP and wins <= published.Wins then return true end
	local pending = scope.queue[userId]
	if pending then
		pending.XP, pending.Wins = math.max(pending.XP, xp), math.max(pending.Wins, wins)
	else
		scope.queue[userId] = { XP = xp, Wins = wins, due = os.clock(), attempts = 0 }
	end
	return true
end

function Service:_region(id)
	local region = self.regions[id]
	if region then return region end
	region = { id = id, label = "REGION · " .. string.upper(regionNames[id]), boards = {}, queue = {}, published = {} }
	for _, definition in ipairs(definitions) do
		table.insert(region.boards, {
			definition = { name = definition.name, stat = definition.stat, store = definition.store .. "_Region_" .. id },
			rows = {}, entries = {}, refreshAt = 0, state = "loading", status = region.label .. " · CONNECTING", emptyText = "Regional scores are loading",
		})
	end
	self.regions[id] = region
	return region
end

function Service:_resolvePlayer(player, generation)
	local userId = player.UserId
	if not validUserId(userId) then return end
	local lookup = self.regionLookups[userId]
	if not lookup then
		lookup = { state = "loading", attempts = 0, retryAt = 0 }
		self.regionLookups[userId] = lookup
	end
	if lookup.id or lookup.busy or lookup.state == "unavailable" or os.clock() < lookup.retryAt then return end
	if typeof(self.resolveRegion) ~= "function" then lookup.state = "unavailable" return end
	lookup.busy = true
	lookup.attempts += 1
	task.spawn(function()
		local ok, region = pcall(self.resolveRegion, player)
		lookup.busy = false
		if not self.running or self.generation ~= generation then return end
		if ok and typeof(region) == "table" and regionNames[region.id] then
			lookup.id, lookup.state = region.id, "ready"
			local scope = self:_region(region.id)
			if not self.isStudio and self.saved[userId] then self:_queueScores(scope, userId, self.saved[userId]) end
		elseif ok or lookup.attempts >= 3 then
			lookup.state = "unavailable"
		else
			lookup.retryAt = os.clock() + 15 * lookup.attempts
		end
	end)
end

function Service:PublishSaved(userId, profile)
	if self.isStudio or not validUserId(userId) or typeof(profile) ~= "table" then return false end
	local xp, wins = integer(profile.XP, nil), integer(profile.Wins, nil)
	if xp == nil or wins == nil then return false end
	local saved = self.saved[userId]
	self.saved[userId] = { XP = math.max(saved and saved.XP or 0, xp), Wins = math.max(saved and saved.Wins or 0, wins) }
	self:_queueScores(self.global, userId, self.saved[userId])
	local lookup = self.regionLookups[userId]
	if lookup and lookup.id then
		self:_queueScores(self:_region(lookup.id), userId, self.saved[userId])
	elseif self.running then
		local player = Players:GetPlayerByUserId(userId)
		if player then self:_resolvePlayer(player, self.generation) end
	end
	return true
end

function Service:_writeOne(generation, deadline)
	if self.writeBusy or self.isStudio or self.generation ~= generation or os.clock() < self.nextWriteAt then return end
	local userId, pending, scope
	for _, bucket in ipairs(self:_scopes()) do
		for id, candidate in pairs(bucket.queue) do
			if candidate.due <= os.clock() and (not pending or candidate.due < pending.due) then userId, pending, scope = id, candidate, bucket end
		end
	end
	if not pending then return end
	self.writeBusy = true
	self.nextWriteAt = os.clock() + 3
	local published = scope.published[userId] or { XP = 0, Wins = 0 }
	scope.published[userId] = published
	local success = true
	local interrupted = false
	for _, board in ipairs(scope.boards) do
		if self.generation ~= generation or (deadline and os.clock() >= deadline) then interrupted = true break end
		local stat = board.definition.stat
		local snapshot = pending[stat]
		if snapshot > published[stat] then
			local ok = pcall(function()
				assert(board.store, "Leaderboard store unavailable")
				board.store:UpdateAsync(tostring(userId), function(old) return math.max(integer(old, 0), snapshot) end)
			end)
			if self.generation ~= generation then interrupted = true break end
			if ok then published[stat] = snapshot else success = false end
		end
	end
	if success and not interrupted and published.XP >= pending.XP and published.Wins >= pending.Wins then
		scope.queue[userId] = nil
	elseif success and not interrupted then
		pending.due = os.clock()
	elseif not interrupted then
		pending.attempts += 1
		pending.due = os.clock() + math.min(120, 5 * 2 ^ math.min(pending.attempts, 5))
	end
	self.writeBusy = false
end

function Service:_activeRegions()
	local result = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local lookup = self.regionLookups[player.UserId]
		if lookup and lookup.id then result[lookup.id] = true end
	end
	return result
end

function Service:_refreshNext(generation)
	if os.clock() < self.nextReadAt then return end
	local active = self:_activeRegions()
	local chosen, chosenScope
	for _, scope in ipairs(self:_scopes()) do
		if scope.id == "global" or active[scope.id] then
			for _, board in ipairs(scope.boards) do
				if board.refreshAt <= os.clock() and (not chosen or board.refreshAt < chosen.refreshAt) then chosen, chosenScope = board, scope end
			end
		end
	end
	if not chosen then return end
	self.nextReadAt = os.clock() + (self.isStudio and 0.5 or 2)
	chosen.refreshAt = os.clock() + (self.isStudio and 5 or 60)
	local ok = pcall(function() self:_refresh(chosen, generation, chosenScope) end)
	if not ok and self.running and self.generation == generation then
		self:_render(chosen, chosen.entries, chosenScope.label .. " · UNAVAILABLE RIGHT NOW", #chosen.entries > 0 and "stale" or "unavailable", "Scores will appear when connected")
	end
end

function Service:_displayEntries(entries, stat)
	local result = {}
	for index, entry in ipairs(entries) do
		local cached = self.identities[entry.userId]
		local display = { userId = entry.userId, name = entry.name or (cached and cached.name) or "Player " .. entry.userId, image = cached and cached.image or entry.image or "", value = stat == "XP" and "LV " .. self:_level(entry.value) or tostring(entry.value) }
		if index <= 3 and typeof(self.resolveEmote) == "function" then
			local ok, emote = pcall(self.resolveEmote, entry.userId)
			if ok and typeof(emote) == "table" then
				display.emoteId, display.emoteAnimationId, display.emoteRigType = emote.emoteId, emote.emoteAnimationId, emote.emoteRigType
			end
		end
		table.insert(result, display)
	end
	return result
end

function Service:GetSnapshot(player, requested)
	local scope = requested == "server" and "server" or requested == "region" and "region" or "global"
	local lookup = player and self.regionLookups[player.UserId]
	local regionId = lookup and lookup.id
	local response = { scope = scope, region = regionId and regionNames[regionId] or nil, regionId = regionId, boards = {}, state = "ready", retryAfter = 30 }
	if scope == "server" then
		response.status = self.isStudio and "THIS SERVER · STUDIO PREVIEW" or "THIS SERVER · CURRENT PLAYERS"
		for _, definition in ipairs(definitions) do
			response.boards[definition.name] = { entries = self:_displayEntries(self:_serverEntries(definition.stat), definition.stat), state = "ready", status = response.status, emptyText = "No players with loaded scores yet" }
		end
		return response
	end
	if scope == "region" and not regionId then
		response.state = lookup and lookup.state or (self.running and "loading" or "unavailable")
		response.status = response.state == "loading" and "REGION · FINDING YOUR REGION" or "REGION · LOCATION UNAVAILABLE"
		response.retryAfter = response.state == "loading" and 5 or 60
		for _, definition in ipairs(definitions) do
			response.boards[definition.name] = { entries = {}, state = response.state, status = response.status, emptyText = response.state == "loading" and "Finding your broad region" or "Your region could not be determined" }
		end
		return response
	end
	local bucket = scope == "global" and self.global or self.regions[regionId]
	for _, board in ipairs(bucket.boards) do
		response.boards[board.definition.name] = { entries = self:_displayEntries(board.entries, board.definition.stat), state = board.state, status = board.status, emptyText = board.emptyText }
		if states[board.state] > states[response.state] then response.state = board.state end
	end
	local suffix = response.state == "loading" and "CONNECTING" or response.state == "stale" and "RECONNECTING · SHOWING SAVED SCORES" or response.state == "unavailable" and "UNAVAILABLE RIGHT NOW" or "UPDATES EVERY MINUTE"
	response.status = self.isStudio and (scope == "global" and "THIS SERVER · STUDIO PREVIEW" or bucket.label .. " · STUDIO PREVIEW") or bucket.label .. " · " .. suffix
	response.retryAfter = response.state == "loading" and 5 or 30
	return response
end

function Service:Start()
	if self.running then return self end
	for _, board in ipairs(self.boards) do self:_render(board, board.entries, self.isStudio and "THIS SERVER · STUDIO PREVIEW" or "GLOBAL · CONNECTING", #board.entries > 0 and "stale" or "loading", "Scores are loading") end
	self.generation += 1
	local generation = self.generation
	self.running = true
	local function added(player)
		self:_resolvePlayer(player, generation)
		if validUserId(player.UserId) then task.spawn(function() if self.running and self.generation == generation then self:_identity(player.UserId) end end) end
	end
	table.insert(self.connections, Players.PlayerAdded:Connect(added))
	for _, player in ipairs(Players:GetPlayers()) do added(player) end
	task.spawn(function()
		while self.running and self.generation == generation do
			self:_connectStores()
			for _, player in ipairs(Players:GetPlayers()) do self:_resolvePlayer(player, generation) end
			self:_refreshNext(generation)
			task.wait(1)
		end
	end)
	task.spawn(function()
		while self.running and self.generation == generation do
			self:_writeOne(generation)
			task.wait(3)
		end
	end)
	return self
end

function Service:_pending()
	if self.writeBusy then return true end
	for _, scope in ipairs(self:_scopes()) do if next(scope.queue) then return true end end
	for userId, lookup in pairs(self.regionLookups) do
		if self.saved[userId] and lookup.state == "loading" then return true end
	end
	return false
end

function Service:Flush(seconds)
	if self.isStudio then return true end
	if typeof(seconds) ~= "number" or seconds ~= seconds or math.abs(seconds) == math.huge then seconds = 3 end
	local deadline = os.clock() + math.clamp(seconds, 0, 5)
	local generation = self.generation
	self.flushDeadline = math.max(self.flushDeadline, deadline)
	if self.flushWorkerGeneration ~= generation then
		self.flushWorkerGeneration = generation
		task.spawn(function()
			while self.generation == generation and os.clock() < self.flushDeadline and self:_pending() do
				self:_writeOne(generation, self.flushDeadline)
				task.wait(0.05)
			end
			if self.flushWorkerGeneration == generation then self.flushWorkerGeneration = nil end
		end)
	end
	while self.generation == generation and os.clock() < deadline and self:_pending() do task.wait(math.max(0, math.min(0.05, deadline - os.clock()))) end
	return not self:_pending()
end

function Service:Stop()
	self.running = false
	self.generation += 1
	self.flushDeadline = 0
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
end

return Service


]====]},
{path="ServerScriptService.PlaygroundBootstrap",before=[====[
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")
local BritishBulldog = require(ServerScriptService:WaitForChild("BritishBulldogService"))
local Tag = require(ServerScriptService:WaitForChild("TagService"))
local Mud = require(ServerScriptService:WaitForChild("StuckInTheMudService"))
local TagSprint = require(ServerScriptService:WaitForChild("TagSprintService"))
local Economy = require(ServerScriptService:WaitForChild("PlaygroundEconomyService"))
local Coordinator = require(ServerScriptService:WaitForChild("PlaygroundCoordinator"))
local Admin = require(ServerScriptService:WaitForChild("PlaygroundAdminService"))

local lobby = workspace:WaitForChild("Playground Lobby")
local britishBulldog = BritishBulldog.new(workspace:WaitForChild("British Bulldog game"))
local tag = Tag.new(workspace:WaitForChild("Tag You're It"))
local mud = Mud.new(workspace:WaitForChild("Stuck in the Mud"))
local tagSprint = TagSprint.new(tag)
local spawn = lobby.Gameplay.LobbySpawn
britishBulldog.lobbySpawn = spawn
tag.lobbySpawn = spawn
mud.lobbySpawn = spawn
britishBulldog:Start()
tag:Start()
mud:Start()
tagSprint:Start()
local economy = Economy.new(lobby)
local leaderboardModule = ServerScriptService:FindFirstChild("PlaygroundLeaderboardService")
if leaderboardModule and lobby:FindFirstChild("Leaderboards") then
	local ok, result = pcall(function()
		local Leaderboards = require(leaderboardModule)
		local Regions = require(ServerScriptService:WaitForChild("PlaygroundRegions"))
		return Leaderboards.new(lobby, {
			resolveRegion = function(player)
				return Regions.Resolve(LocalizationService:GetCountryRegionForPlayerAsync(player))
			end,
		}):Start()
	end)
	if ok then
		economy.leaderboards = result
		local request = ReplicatedStorage:WaitForChild("PlaygroundLeaderboardRequest")
		local requests = {}
		local scopes = { global = true, server = true, region = true }
		request.OnServerInvoke = function(player, scope)
			if player.Parent ~= Players or type(scope) ~= "string" or not scopes[scope] then
				return { state = "unavailable", status = "INVALID REQUEST" }
			end
			local now = os.clock()
			local rate = requests[player]
			if not rate or now - rate.started >= 5 then
				rate = { started = now, count = 0 }
				requests[player] = rate
			end
			if rate.count >= 10 then
				return { scope = scope, state = "loading", status = "PLEASE WAIT", retryAfter = 5 }
			end
			rate.count += 1
			local succeeded, snapshot = pcall(result.GetSnapshot, result, player, scope)
			if succeeded then return snapshot end
			warn("Leaderboard request failed: " .. tostring(snapshot))
			return { scope = scope, state = "unavailable", status = "RANKINGS UNAVAILABLE", retryAfter = 10 }
		end
		local leaving = Players.PlayerRemoving:Connect(function(player)
			requests[player] = nil
		end)
		script.Destroying:Connect(function()
			request.OnServerInvoke = nil
			leaving:Disconnect()
			table.clear(requests)
			result:Stop()
		end)
	else
		warn("Lobby leaderboards could not start: " .. tostring(result))
	end
end
economy:Start()
local Equipment = require(ServerScriptService:WaitForChild("PlaygroundEquipmentService"))
local Toys = require(ServerScriptService:WaitForChild("PlaygroundToyService"))
local toys = Toys.new({ playBonk = function(position)
	local template = ReplicatedStorage:FindFirstChild("ToyBonk")
	if not template or not template:IsA("Sound") then return end
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Size, anchor.Position = "ToyBonkSound", Vector3.new(0.1, 0.1, 0.1), position
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.Transparency = true, false, false, false, 1
	anchor.Parent = workspace
	local sound = template:Clone()
	sound.Volume, sound.RollOffMaxDistance, sound.Parent = 0.4, 50, anchor
	sound:Play()
	game:GetService("Debris"):AddItem(anchor, 4)
end }):Start()
local equipment = Equipment.new({ BritishBulldog = britishBulldog, TagYoureIt = tag }, toys):Start()
for service, methodName in pairs({ [britishBulldog] = "_beginRound", [tag] = "_begin", [mud] = "_begin" }) do
	local original = service[methodName]
	service[methodName] = function(instance, selected, ...)
		equipment:PrepareRound(selected)
		return original(instance, selected, ...)
	end
end
local toyRequest = ReplicatedStorage:WaitForChild("PlaygroundToyRequest")
local toyRequests = {}
toyRequest.OnServerInvoke = function(player, action, aim)
	if player.Parent ~= Players or action ~= "Use" then return { ok = false, message = "Invalid toy request." } end
	local current = os.clock()
	if current - (toyRequests[player] or -math.huge) < 0.1 then return { ok = false, message = "Please wait." } end
	toyRequests[player] = current
	return equipment:UseToy(player, aim)
end
local toyLeaving = Players.PlayerRemoving:Connect(function(player) toyRequests[player] = nil end)
script.Destroying:Connect(function()
	toyRequest.OnServerInvoke = nil
	toyLeaving:Disconnect()
	equipment:Stop()
	toys:Stop()
end)
local coordinator = Coordinator.new({ BritishBulldog = britishBulldog, TagYoureIt = tag, StuckInTheMud = mud }, lobby, economy)
coordinator:Start()
local admin = Admin.Start(coordinator)
script:SetAttribute("Ready", true)




]====],after=[====[
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")
local BritishBulldog = require(ServerScriptService:WaitForChild("BritishBulldogService"))
local Tag = require(ServerScriptService:WaitForChild("TagService"))
local Mud = require(ServerScriptService:WaitForChild("StuckInTheMudService"))
local TagSprint = require(ServerScriptService:WaitForChild("TagSprintService"))
local Economy = require(ServerScriptService:WaitForChild("PlaygroundEconomyService"))
local Coordinator = require(ServerScriptService:WaitForChild("PlaygroundCoordinator"))
local Admin = require(ServerScriptService:WaitForChild("PlaygroundAdminService"))

local lobby = workspace:WaitForChild("Playground Lobby")
local britishBulldog = BritishBulldog.new(workspace:WaitForChild("British Bulldog game"))
local tag = Tag.new(workspace:WaitForChild("Tag You're It"))
local mud = Mud.new(workspace:WaitForChild("Stuck in the Mud"))
local tagSprint = TagSprint.new(tag)
local spawn = lobby.Gameplay.LobbySpawn
britishBulldog.lobbySpawn = spawn
tag.lobbySpawn = spawn
mud.lobbySpawn = spawn
britishBulldog:Start()
tag:Start()
mud:Start()
tagSprint:Start()
local economy = Economy.new(lobby)
local leaderboardModule = ServerScriptService:FindFirstChild("PlaygroundLeaderboardService")
if leaderboardModule and lobby:FindFirstChild("Leaderboards") then
	local ok, result = pcall(function()
		local Leaderboards = require(leaderboardModule)
		local Regions = require(ServerScriptService:WaitForChild("PlaygroundRegions"))
		return Leaderboards.new(lobby, {
			resolveEmote = function(userId) return economy:GetPodiumEmote(userId) end,
			resolveRegion = function(player)
				return Regions.Resolve(LocalizationService:GetCountryRegionForPlayerAsync(player))
			end,
		}):Start()
	end)
	if ok then
		economy.leaderboards = result
		local request = ReplicatedStorage:WaitForChild("PlaygroundLeaderboardRequest")
		local requests = {}
		local scopes = { global = true, server = true, region = true }
		request.OnServerInvoke = function(player, scope)
			if player.Parent ~= Players or type(scope) ~= "string" or not scopes[scope] then
				return { state = "unavailable", status = "INVALID REQUEST" }
			end
			local now = os.clock()
			local rate = requests[player]
			if not rate or now - rate.started >= 5 then
				rate = { started = now, count = 0 }
				requests[player] = rate
			end
			if rate.count >= 10 then
				return { scope = scope, state = "loading", status = "PLEASE WAIT", retryAfter = 5 }
			end
			rate.count += 1
			local succeeded, snapshot = pcall(result.GetSnapshot, result, player, scope)
			if succeeded then return snapshot end
			warn("Leaderboard request failed: " .. tostring(snapshot))
			return { scope = scope, state = "unavailable", status = "RANKINGS UNAVAILABLE", retryAfter = 10 }
		end
		local leaving = Players.PlayerRemoving:Connect(function(player)
			requests[player] = nil
		end)
		script.Destroying:Connect(function()
			request.OnServerInvoke = nil
			leaving:Disconnect()
			table.clear(requests)
			result:Stop()
		end)
	else
		warn("Lobby leaderboards could not start: " .. tostring(result))
	end
end
economy:Start()
local Equipment = require(ServerScriptService:WaitForChild("PlaygroundEquipmentService"))
local Toys = require(ServerScriptService:WaitForChild("PlaygroundToyService"))
local toys = Toys.new({ playBonk = function(position)
	local template = ReplicatedStorage:FindFirstChild("ToyBonk")
	if not template or not template:IsA("Sound") then return end
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Size, anchor.Position = "ToyBonkSound", Vector3.new(0.1, 0.1, 0.1), position
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.Transparency = true, false, false, false, 1
	anchor.Parent = workspace
	local sound = template:Clone()
	sound.Volume, sound.RollOffMaxDistance, sound.Parent = 0.4, 50, anchor
	sound:Play()
	game:GetService("Debris"):AddItem(anchor, 4)
end }):Start()
local equipment = Equipment.new({ BritishBulldog = britishBulldog, TagYoureIt = tag }, toys):Start()
for service, methodName in pairs({ [britishBulldog] = "_beginRound", [tag] = "_begin", [mud] = "_begin" }) do
	local original = service[methodName]
	service[methodName] = function(instance, selected, ...)
		equipment:PrepareRound(selected)
		return original(instance, selected, ...)
	end
end
local toyRequest = ReplicatedStorage:WaitForChild("PlaygroundToyRequest")
local toyRequests = {}
toyRequest.OnServerInvoke = function(player, action, aim)
	if player.Parent ~= Players or action ~= "Use" then return { ok = false, message = "Invalid toy request." } end
	local current = os.clock()
	if current - (toyRequests[player] or -math.huge) < 0.1 then return { ok = false, message = "Please wait." } end
	toyRequests[player] = current
	return equipment:UseToy(player, aim)
end
local toyLeaving = Players.PlayerRemoving:Connect(function(player) toyRequests[player] = nil end)
script.Destroying:Connect(function()
	toyRequest.OnServerInvoke = nil
	toyLeaving:Disconnect()
	equipment:Stop()
	toys:Stop()
end)
local coordinator = Coordinator.new({ BritishBulldog = britishBulldog, TagYoureIt = tag, StuckInTheMud = mud }, lobby, economy)
coordinator:Start()
local admin = Admin.Start(coordinator)
script:SetAttribute("Ready", true)




]====]},
{path="StarterPlayer.StarterPlayerScripts.PlaygroundEmotes",before=[====[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local records = {}
local function restore(record)
	for joint, entry in pairs(record.joints) do
		if joint.Parent and joint.Transform == entry.applied then joint.Transform = entry.original end
	end
	table.clear(record.joints)
end
local function pose(record, joint, offset)
	if not joint or not (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then return end
	local previous = record.joints[joint]
	local original = joint.Transform
	if previous and original == previous.applied then original = previous.original end
	joint.Transform = original * offset
	record.joints[joint] = { original = original, applied = joint.Transform }
end
local bodyNames = {
	"HumanoidRootPart", "Torso", "LowerTorso", "UpperTorso", "Head",
	"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"Right Arm", "Left Arm", "Right Leg", "Left Leg",
}
local function collectJoints(character)
	local joints = {}
	for _, name in ipairs(bodyNames) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("Motor6D") or child:IsA("AnimationConstraint") then joints[child.Name] = child end
			end
		end
	end
	return joints
end
local function bodyJoints(record, character, now)
	if not record.bodyJoints or now - (record.jointsAt or -math.huge) >= 0.5 then
		record.bodyJoints = collectJoints(character)
		record.jointsAt = now
	end
	return record.bodyJoints
end
local function vector(x, y, z) return Vector3.new(x, y, z) end
local batPoses = {
	{ time = 0, r6 = vector(90, 0, -8), r15 = vector(65, 0, -8), elbow = 25,
		wrist = vector(0, 0, 0), root = vector(0, 0, 0), waist = vector(0, 0, 0),
		guide = vector(75, -30, 16), guideElbow = 48, guideWeight = 0, bodyWeight = 0 },
	{ time = 0.105, r6 = vector(116, 4, -40), r15 = vector(91, 4, -35), elbow = 42,
		wrist = vector(-6, -12, -8), root = vector(3, -16, -3), waist = vector(2, -19, -2),
		guide = vector(106, -60, 10), guideElbow = 15, guideWeight = 1, bodyWeight = 1 },
	{ time = 0.15, r6 = vector(111, 4, -35), r15 = vector(87, 4, -30), elbow = 36,
		wrist = vector(-9, -9, -5), root = vector(1, -9, -2), waist = vector(0, -12, -1),
		guide = vector(100, -60, 10), guideElbow = 8, guideWeight = 1, bodyWeight = 1 },
	{ time = 0.22, r6 = vector(45, 28, -16), r15 = vector(36, 28, -16), elbow = 9,
		wrist = vector(-7, 3, 2), root = vector(-5, 9, 4), waist = vector(-3, 15, 2),
		guide = vector(56, -68, 10), guideElbow = 5, guideWeight = 1, bodyWeight = 1 },
	{ time = 0.30, r6 = vector(74, 84, -24), r15 = vector(54, 80, -19), elbow = 33,
		wrist = vector(8, 13, 10), root = vector(-2, 18, 5), waist = vector(-1, 23, 3),
		guide = vector(53, -8, 15), guideElbow = 35, guideWeight = 0.5, bodyWeight = 1 },
	{ time = 0.365, r6 = vector(88, 62, -18), r15 = vector(65, 56, -15), elbow = 37,
		wrist = vector(4, 8, 4), root = vector(0, 13, 3), waist = vector(0, 15, 2),
		guide = vector(41, -4, 9), guideElbow = 28, guideWeight = 0.25, bodyWeight = 0.65 },
	{ time = 0.48, r6 = vector(90, 0, -8), r15 = vector(65, 0, -8), elbow = 25,
		wrist = vector(0, 0, 0), root = vector(0, 0, 0), waist = vector(0, 0, 0),
		guide = vector(75, -30, 16), guideElbow = 48, guideWeight = 0, bodyWeight = 0 },
}
local function tangent(index, key)
	if index == 1 or index == #batPoses then return batPoses[index][key] * 0 end
	local before, current, after = batPoses[index - 1], batPoses[index], batPoses[index + 1]
	local incoming = (current[key] - before[key]) / (current.time - before.time)
	local outgoing = (after[key] - current[key]) / (after.time - current.time)
	return (incoming + outgoing) * 0.35
end
local function sampleBatPose(elapsed, classic)
	local first = batPoses[1]
	if elapsed < 0 or elapsed >= 0.48 then elapsed = 0 end
	local index = 2
	while index < #batPoses and elapsed > batPoses[index].time do index += 1 end
	local start, finish = batPoses[index - 1], batPoses[index]
	local duration = finish.time - start.time
	local t = math.clamp((elapsed - start.time) / duration, 0, 1)
	local t2, t3 = t * t, t * t * t
	local result = {}
	for key, value in pairs(first) do
		if key ~= "time" then
			result[key] = start[key] * (2 * t3 - 3 * t2 + 1)
				+ tangent(index - 1, key) * duration * (t3 - 2 * t2 + t)
				+ finish[key] * (-2 * t3 + 3 * t2)
				+ tangent(index, key) * duration * (t3 - t2)
		end
	end
	result.shoulder = result[classic and "r6" or "r15"]
	result.guideWeight = math.clamp(result.guideWeight, 0, 1)
	result.bodyWeight = math.clamp(result.bodyWeight, 0, 1)
	return result
end
local function weaponJoint(record, joint, angles, weight, additive)
	if not joint or not joint.Parent or weight <= 0
		or not (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) or not joint.Enabled then return end
	local previous = record.joints[joint]
	local original = joint.Transform
	if previous and original == previous.applied then original = previous.original end
	local basis = joint.C0.Rotation
	local rotation = CFrame.fromEulerAnglesYXZ(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z))
	local target = basis:Inverse() * rotation * basis
	if additive then target = original * target end
	joint.Transform = original:Lerp(target, math.clamp(weight, 0, 1))
	record.joints[joint] = { original = original, applied = joint.Transform }
end
local function applyBatPose(record, joints, sampled, classic, fade)
	weaponJoint(record, joints[classic and "Right Shoulder" or "RightShoulder"], sampled.shoulder, fade)
	weaponJoint(record, joints.RightElbow, vector(sampled.elbow, 0, 0), fade)
	weaponJoint(record, joints.RightWrist, sampled.wrist, fade)
	local guide = sampled.guideWeight * fade
	weaponJoint(record, joints[classic and "Left Shoulder" or "LeftShoulder"], sampled.guide, guide)
	weaponJoint(record, joints.LeftElbow, vector(sampled.guideElbow, 0, 0), guide)
	weaponJoint(record, joints.LeftWrist, vector(0, 10, -8), guide)
	local root = sampled.root * (classic and 1 or 0.55)
	weaponJoint(record, joints.RootJoint or joints.Root, root, fade, true)
	if not classic then weaponJoint(record, joints.Waist, sampled.waist, fade, true) end
	local chest = root + (classic and Vector3.zero or sampled.waist)
	weaponJoint(record, joints.Neck, vector(-chest.X * 0.4, -chest.Y * 0.6, -chest.Z * 0.5), fade, true)
	local weight = sampled.bodyWeight
	weaponJoint(record, joints[classic and "Right Hip" or "RightHip"],
		vector(-root.X + 2 * weight, -root.Y * 0.8, -root.Z), fade, true)
	weaponJoint(record, joints[classic and "Left Hip" or "LeftHip"],
		vector(-root.X - 2 * weight, -root.Y * 0.8, -root.Z), fade, true)
	weaponJoint(record, joints.RightKnee, vector(-3 * weight, 0, 0), fade, true)
	weaponJoint(record, joints.LeftKnee, vector(-5 * weight, 0, 0), fade, true)
end
local function animateBat(record, player, character, humanoid, now)
	local gameName = character:GetAttribute("PCBatGame")
	local participating = (gameName == "BritishBulldog" and player:GetAttribute("BBParticipating") == true)
		or (gameName == "TagYoureIt" and player:GetAttribute("TGParticipating") == true)
	if humanoid.Health <= 0 or character:GetAttribute("PCBatHeld") ~= true or not participating
		or player:GetAttribute("MDParticipating") == true
		or player:GetAttribute("BBRagdolled") == true or player:GetAttribute("TGRagdolled") == true then
		record.weapon = nil
		return false
	end
	if record.weapon ~= gameName then
		record.weapon = gameName
		record.weaponAt = now
		record.jointsAt = nil
	end
	local started = player:GetAttribute("PCBatSwingAt")
	local elapsed = typeof(started) == "number" and started == started and now - started or math.huge
	local classic = humanoid.RigType == Enum.HumanoidRigType.R6
	local sampled = sampleBatPose(elapsed, classic)
	local fade = math.clamp((now - record.weaponAt) / 0.1, 0, 1)
	applyBatPose(record, bodyJoints(record, character, now), sampled, classic, fade)
	return true
end
local toyActions = {
	M01 = { action = "Kick", duration = 1.10, placeAt = 0.24, contactAt = 0.60 },
	M02 = { action = "Lob", duration = 0.85, contactAt = 0.34 },
	M03 = { action = "Bonk", duration = 0.58, contactAt = 0.23 },
	M04 = { action = "BarrelThrow", duration = 1.10, contactAt = 0.52 },
	M05 = { action = "Drink", duration = 1.30, contactAt = 0.82 },
	M06 = { action = "Drink", duration = 1.30, contactAt = 0.82 },
	M07 = { action = "Drink", duration = 1.30, contactAt = 0.82, alternateAction = "Aim", alternateDuration = 0.80 },
	M08 = { action = "Shake", duration = 1.05, contactAt = 0.65 },
	M10 = { action = "Aim", duration = 0.80, contactAt = 0.35 },
	M11 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M12 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M13 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M14 = { action = "Carry", duration = 0 },
	M15 = { action = "Place", duration = 1.00, contactAt = 0.46 },
}
local function toyPose(values)
	local result = {
		right = vector(64, 0, -8), elbow = 20, wrist = Vector3.zero,
		left = vector(55, -32, 10), leftElbow = 20, leftWeight = 0,
		root = Vector3.zero, waist = Vector3.zero,
		rightHip = Vector3.zero, leftHip = Vector3.zero,
		rightKnee = 0, leftKnee = 0,
		barrelLift = 0, drinkTip = 0,
	}
	for key, value in pairs(values or {}) do result[key] = value end
	return result
end
local toyIdle = {
	M01 = toyPose({right=vector(52,0,-12)}),
	M02 = toyPose({right=vector(65,8,-20),elbow=25,left=vector(65,-34,14),leftElbow=24,leftWeight=0.65}),
	M03 = toyPose({right=vector(82,0,-10),elbow=25}),
	M04 = toyPose({right=vector(63,14,-25),elbow=18,left=vector(65,-34,18),leftElbow=18,leftWeight=1}),
	M05 = toyPose(), M06 = toyPose(), M07 = toyPose(),
	M08 = toyPose({right=vector(65,12,-24),elbow=24,left=vector(65,-34,18),leftElbow=24,leftWeight=0.85}),
	M10 = toyPose({right=vector(75,4,-12),elbow=20,left=vector(63,-35,15),leftElbow=25,leftWeight=0.45}),
	M11 = toyPose(), M12 = toyPose(), M13 = toyPose(),
	M14 = toyPose({right=vector(90,-6,-17),elbow=23}),
	M15 = toyPose({right=vector(52,12,-20),elbow=16,left=vector(53,-36,17),leftElbow=16,leftWeight=1}),
}
local function toyKey(time, values) return { time=time, pose=toyPose(values) } end
local toyTracks = {
	Kick = {
		toyKey(0),
		toyKey(0.24,{right=vector(48,8,-18),elbow=6,root=vector(-28,0,0),waist=vector(-14,0,0),
			left=vector(20,-5,18),leftWeight=.7,rightHip=vector(22,0,0),leftHip=vector(22,0,0),rightKnee=-24,leftKnee=-24}),
		toyKey(0.43,{right=vector(20,-4,-22),elbow=6,root=vector(-2,-5,-3),
			left=vector(18,0,25),leftWeight=.7,rightHip=vector(-26,0,-3),rightKnee=-32}),
		toyKey(0.60,{right=vector(27,-5,-28),elbow=8,root=vector(8,8,3),waist=vector(5,5,0),
			left=vector(25,0,28),leftWeight=.85,rightHip=vector(72,0,-3),leftHip=vector(-5,0,0),rightKnee=-4}),
		toyKey(0.76,{right=vector(30,0,-19),elbow=12,root=vector(4,6,2),
			left=vector(24,0,18),leftWeight=.5,rightHip=vector(38,0,0),rightKnee=-12}),
		toyKey(1.10),
	},
	Lob = {
		toyKey(0),
		toyKey(0.19,{right=vector(122,8,-22),elbow=48,left=vector(125,-27,19),leftElbow=44,leftWeight=1,
			root=vector(5,0,0),waist=vector(4,0,0),rightKnee=-9,leftKnee=-9}),
		toyKey(0.34,{right=vector(153,7,-15),elbow=8,left=vector(151,-18,14),leftElbow=8,leftWeight=1,
			root=vector(-3,0,0),waist=vector(-3,0,0)}),
		toyKey(0.48,{right=vector(132,9,-17),elbow=12,wrist=vector(14,0,0),
			left=vector(126,-20,15),leftElbow=14,leftWeight=.8,root=vector(-4,0,0)}),
		toyKey(0.85),
	},
	Bonk = {
		toyKey(0),
		toyKey(0.12,{right=vector(118,-24,-32),elbow=36,root=vector(3,-15,-3),waist=vector(0,-12,0),
			left=vector(75,-47,16),leftElbow=30,leftWeight=.65}),
		toyKey(0.23,{right=vector(47,28,-17),elbow=9,wrist=vector(-9,5,0),
			root=vector(-5,10,4),waist=vector(-3,13,0),left=vector(43,-28,18),leftElbow=12,leftWeight=.4}),
		toyKey(0.34,{right=vector(71,76,-23),elbow=28,root=vector(-2,17,4),waist=vector(0,19,0)}),
		toyKey(0.58),
	},
	BarrelThrow = {
		toyKey(0),
		toyKey(0.23,{right=vector(102,8,-20),elbow=35,left=vector(104,-29,19),leftElbow=35,leftWeight=1,
			root=vector(-8,0,0),waist=vector(-5,0,0),rightKnee=-13,leftKnee=-13}),
		toyKey(0.40,{right=vector(164,8,-18),elbow=22,left=vector(163,-20,17),leftElbow=22,leftWeight=1,barrelLift=1,
			root=vector(7,0,0),waist=vector(6,0,0)}),
		toyKey(0.52,{right=vector(104,5,-15),elbow=5,left=vector(103,-20,16),leftElbow=5,leftWeight=1,
			root=vector(-13,0,0),waist=vector(-8,0,0)}),
		toyKey(0.69,{right=vector(69,9,-18),elbow=9,left=vector(68,-25,18),leftElbow=9,leftWeight=.8,
			root=vector(-10,0,0),waist=vector(-5,0,0)}),
		toyKey(1.10),
	},
	Drink = {
		toyKey(0),
		toyKey(0.32,{right=vector(128,8,-37),elbow=58,wrist=vector(-14,0,-8),root=vector(2,0,0)}),
		toyKey(0.60,{right=vector(136,7,-39),elbow=65,wrist=vector(-31,0,-8),root=vector(4,0,0),waist=vector(2,0,0),drinkTip=1}),
		toyKey(0.82,{right=vector(135,7,-39),elbow=64,wrist=vector(-35,0,-8),root=vector(4,0,0),waist=vector(2,0,0),drinkTip=1}),
		toyKey(1.02,{right=vector(113,8,-27),elbow=44,wrist=vector(-10,0,-3),root=vector(1,0,0)}),
		toyKey(1.30),
	},
	Shake = {
		toyKey(0),
		toyKey(0.20,{right=vector(94,13,-28),elbow=34,left=vector(93,-35,20),leftElbow=33,leftWeight=1}),
		toyKey(0.35,{right=vector(103,6,-31),elbow=39,left=vector(103,-41,23),leftElbow=38,leftWeight=1,root=vector(0,-3,-2)}),
		toyKey(0.48,{right=vector(82,20,-23),elbow=26,left=vector(82,-28,17),leftElbow=25,leftWeight=1,root=vector(0,3,2)}),
		toyKey(0.65,{right=vector(105,7,-32),elbow=40,left=vector(104,-40,23),leftElbow=39,leftWeight=1,root=vector(0,-3,-2)}),
		toyKey(0.78,{right=vector(83,18,-24),elbow=28,left=vector(84,-30,18),leftElbow=27,leftWeight=.9,root=vector(0,2,1)}),
		toyKey(1.05),
	},
	Aim = {
		toyKey(0),
		toyKey(0.22,{right=vector(89,5,-11),elbow=14,left=vector(81,-37,19),leftElbow=32,leftWeight=.9,
			root=vector(-3,-5,0),waist=vector(0,-5,0)}),
		toyKey(0.35,{right=vector(89,5,-11),elbow=14,left=vector(81,-37,19),leftElbow=32,leftWeight=.9,
			root=vector(-3,-5,0),waist=vector(0,-5,0)}),
		toyKey(0.41,{right=vector(97,3,-14),elbow=24,left=vector(85,-38,20),leftElbow=38,leftWeight=.9,
			root=vector(1,-5,0),waist=vector(2,-5,0)}),
		toyKey(0.80),
	},
	Throw = {
		toyKey(0),
		toyKey(0.17,{right=vector(136,-31,-32),elbow=44,root=vector(4,-14,-3),waist=vector(2,-14,0),
			left=vector(62,6,16),leftWeight=.6}),
		toyKey(0.30,{right=vector(90,11,-16),elbow=5,wrist=vector(12,0,0),
			root=vector(-7,10,3),waist=vector(-4,12,0),left=vector(32,-7,19),leftWeight=.4}),
		toyKey(0.45,{right=vector(57,49,-25),elbow=16,root=vector(-5,15,3),waist=vector(-3,12,0)}),
		toyKey(0.78),
	},
	Place = {
		toyKey(0),
		toyKey(0.24,{right=vector(47,12,-21),elbow=12,left=vector(49,-36,18),leftElbow=12,leftWeight=1,
			root=vector(-18,0,0),waist=vector(-12,0,0),rightHip=vector(15,0,0),leftHip=vector(15,0,0),rightKnee=-20,leftKnee=-20}),
		toyKey(0.46,{right=vector(41,12,-20),elbow=3,left=vector(42,-35,17),leftElbow=3,leftWeight=1,
			root=vector(-29,0,0),waist=vector(-16,0,0),rightHip=vector(26,0,0),leftHip=vector(26,0,0),rightKnee=-30,leftKnee=-30}),
		toyKey(0.64,{right=vector(31,6,-20),elbow=8,left=vector(32,-21,18),leftElbow=8,leftWeight=.7,
			root=vector(-16,0,0),waist=vector(-8,0,0),rightHip=vector(13,0,0),leftHip=vector(13,0,0),rightKnee=-16,leftKnee=-16}),
		toyKey(1.00),
	},
}
local function sampleToyPose(id, action, elapsed)
	local idle = toyIdle[id]
	local definition = toyActions[id]
	if not idle or not definition then return nil end
	local track = toyTracks[action]
	local duration = action == definition.action and definition.duration or action == definition.alternateAction and definition.alternateDuration
	if not duration or not track or elapsed ~= elapsed or elapsed < 0 or elapsed >= duration then return idle end
	local index = 2
	while index < #track and elapsed > track[index].time do index += 1 end
	local before, after = track[index - 1], track[index]
	local alpha = math.clamp((elapsed - before.time) / (after.time - before.time), 0, 1)
	alpha = alpha * alpha * (3 - 2 * alpha)
	local first = index == 2 and idle or before.pose
	local last = index == #track and idle or after.pose
	local sampled = {}
	for key, value in pairs(first) do sampled[key] = value + (last[key] - value) * alpha end
	return sampled
end
local function applyToyPose(record, joints, sampled, classic, fade)
	local right = sampled.right - vector(classic and 0 or sampled.elbow,0,0)
	local left = sampled.left - vector(classic and 0 or sampled.leftElbow,0,0)
	if classic then
		right += vector(-24,32,-12) * sampled.barrelLift
		left += vector(-23,-20,13) * sampled.barrelLift
	end
	local wrist = sampled.wrist + (classic and Vector3.zero or vector(45,80,38) * sampled.drinkTip)
	weaponJoint(record,joints[classic and "Right Shoulder" or "RightShoulder"],right,fade)
	weaponJoint(record,joints.RightElbow,vector(sampled.elbow,0,0),fade)
	weaponJoint(record,joints.RightWrist,wrist,fade)
	weaponJoint(record,joints[classic and "Left Shoulder" or "LeftShoulder"],left,fade*sampled.leftWeight)
	weaponJoint(record,joints.LeftElbow,vector(sampled.leftElbow,0,0),fade*sampled.leftWeight)
	local root = sampled.root * (classic and 1 or 0.55)
	weaponJoint(record,joints.RootJoint or joints.Root,root,fade,true)
	weaponJoint(record,joints.Waist,sampled.waist,fade,true)
	local chest = root + (classic and Vector3.zero or sampled.waist)
	weaponJoint(record,joints.Neck,vector(-chest.X*.35,-chest.Y*.5,-chest.Z*.4),fade,true)
	weaponJoint(record,joints[classic and "Right Hip" or "RightHip"],sampled.rightHip,fade,true)
	weaponJoint(record,joints[classic and "Left Hip" or "LeftHip"],sampled.leftHip,fade,true)
	weaponJoint(record,joints.RightKnee,vector(sampled.rightKnee,0,0),fade,true)
	weaponJoint(record,joints.LeftKnee,vector(sampled.leftKnee,0,0),fade,true)
end
local function animateToy(record, player, character, humanoid, now)
	local id = character:GetAttribute("PCToyHeld")
	if typeof(id) ~= "string" or not toyActions[id] or humanoid.Health <= 0
		or player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true or player:GetAttribute("BBRagdolled") == true
		or player:GetAttribute("TGRagdolled") == true then
		record.toy = nil
		return false
	end
	if record.toy ~= id then
		record.toy = id
		record.toyAt = now
		record.jointsAt = nil
	end
	local started = player:GetAttribute("PCToyActionAt")
	local action = player:GetAttribute("PCToyAction")
	local matches = player:GetAttribute("PCToyActionItem") == id
	local elapsed = matches and typeof(started) == "number" and started == started and now - started or math.huge
	local sampled = sampleToyPose(id, action, elapsed)
	local fade = math.clamp((now-record.toyAt)/0.12,0,1)
	applyToyPose(record,bodyJoints(record,character,now),sampled,humanoid.RigType==Enum.HumanoidRigType.R6,fade)
	return true
end
local function animateDodge(record, player, character, humanoid, now)
	if not character or not humanoid or humanoid.Health <= 0 or player:GetAttribute("BBRagdolled") == true
		or player:GetAttribute("TGRagdolled") == true or player:GetAttribute("MDParticipating") == true then return false end
	local prefix
	if player:GetAttribute("BBParticipating") == true and player:GetAttribute("BBRole") == "Runner"
		and player:GetAttribute("BBStatus") == "Crossing" then prefix = "BB"
	elseif player:GetAttribute("TGParticipating") == true then prefix = "TG" end
	if not prefix then return false end
	local states = game:GetService("ReplicatedStorage")
	local state = states:FindFirstChild(prefix == "BB" and "BritishBulldogState" or "TagState")
	if not state or state:GetAttribute("Phase") ~= (prefix == "BB" and "Crossing" or "Playing") then return false end
	local started = player:GetAttribute(prefix .. "DodgeStartedAt")
	local duration = player:GetAttribute(prefix .. "DodgeDuration")
	local direction = player:GetAttribute(prefix .. "DodgeDirection")
	if typeof(started) ~= "number" or started ~= started or started <= 0 or typeof(duration) ~= "number"
		or duration ~= duration or duration < 0.15 or duration > 0.5 or typeof(direction) ~= "Vector3" then return false end
	local elapsed = now - started
	duration += 0.14
	if elapsed < 0 or elapsed >= duration then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local side = math.clamp(root.CFrame:VectorToObjectSpace(direction).X, -1, 1)
	if side ~= side then return false end
	local alpha = math.clamp(elapsed / duration, 0, 1)
	local strength = alpha < 0.22 and math.sin(alpha / 0.22 * math.pi / 2)
		or math.cos((alpha - 0.22) / 0.78 * math.pi / 2)^2
	local joints = bodyJoints(record, character, now)
	local classic = humanoid.RigType == Enum.HumanoidRigType.R6
	local lean = vector(-9, 8 * side, -26 * side)
	weaponJoint(record, joints.RootJoint or joints.Root, lean, strength * (classic and 1 or 0.65), true)
	weaponJoint(record, joints.Waist, lean, strength * 0.35, true)
	weaponJoint(record, joints[classic and "Right Shoulder" or "RightShoulder"], vector(-12,0,18), strength, true)
	weaponJoint(record, joints[classic and "Left Shoulder" or "LeftShoulder"], vector(-12,0,-18), strength, true)
	return true
end


local botRecords = {}
local function animatePracticeBots(now)
	local state = game:GetService("ReplicatedStorage"):FindFirstChild("TagState")
	local folder = workspace:FindFirstChild("TagPracticeBots")
	local playing = state and state:GetAttribute("Phase") == "Playing"
	for character, record in pairs(botRecords) do
		restore(record)
		if not playing or not folder or character.Parent ~= folder then botRecords[character] = nil end
	end
	if not playing or not folder then return end
	for _, character in ipairs(folder:GetChildren()) do
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or humanoid.Health <= 0 or humanoid.PlatformStand then continue end
		local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
		if speed < 0.1 then continue end
		local record = botRecords[character]
		if not record then record = { character = character, joints = {} } botRecords[character] = record end
		local joints = bodyJoints(record, character, now)
		local classic = humanoid.RigType == Enum.HumanoidRigType.R6
		local swing = math.sin(now * 10) * math.min(speed / 16, 1) * 24
		weaponJoint(record, joints[classic and "Right Hip" or "RightHip"], vector(swing,0,0), 1, true)
		weaponJoint(record, joints[classic and "Left Hip" or "LeftHip"], vector(-swing,0,0), 1, true)
		weaponJoint(record, joints[classic and "Right Shoulder" or "RightShoulder"], vector(-swing,0,0), 1, true)
		weaponJoint(record, joints[classic and "Left Shoulder" or "LeftShoulder"], vector(swing,0,0), 1, true)
	end
end

local beforeAnimation = RunService.PreAnimation:Connect(function()
	for _, record in pairs(records) do restore(record) end
	for _, record in pairs(botRecords) do restore(record) end
end)
local frame = RunService.PreSimulation:Connect(function()
	local now = workspace:GetServerTimeNow()
	animatePracticeBots(now)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local record = records[player]
		if not record or record.character ~= character then
			if record then restore(record) end
			record = { character = character, joints = {} }
			records[player] = record
		end
		restore(record)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then record.weapon = nil record.toy = nil continue end
		if animateDodge(record, player, character, humanoid, now) then continue end
		if animateBat(record, player, character, humanoid, now) then record.toy = nil continue end
		if animateToy(record, player, character, humanoid, now) then continue end
		local untilTime = player:GetAttribute("PCEmoteUntil")
		local action = player:GetAttribute("PCEmoteAction")
		if not character or typeof(untilTime) ~= "number" or now >= untilTime or player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") then
			continue
		end
		bodyJoints(record, character, now)
		local classic = humanoid.RigType == Enum.HumanoidRigType.R6
		local right = record.bodyJoints[classic and "Right Shoulder" or "RightShoulder"]
		local left = record.bodyJoints[classic and "Left Shoulder" or "LeftShoulder"]
		local t = 2.4 - (untilTime - now)
		local fade = math.min(1, t / 0.18, (untilTime - now) / 0.2)
		if action == "Wave" then
			local swing = math.sin(t * 13) * 20
			pose(record, right, classic and CFrame.Angles(math.rad(-110 * fade), math.rad(swing * fade), 0) or CFrame.Angles(math.rad(20 * fade), 0, math.rad((125 + swing) * fade)))
			pose(record, record.bodyJoints.RightElbow, CFrame.Angles(math.rad(-25 * fade), 0, 0))
		elseif action == "Cheer" then
			local rise = (145 + math.sin(t * 8) * 12) * fade
			pose(record, right, classic and CFrame.Angles(math.rad(-rise), 0, 0) or CFrame.Angles(math.rad(12 * fade), 0, math.rad(rise)))
			pose(record, left, classic and CFrame.Angles(math.rad(-rise), 0, 0) or CFrame.Angles(math.rad(12 * fade), 0, math.rad(-rise)))
			pose(record, record.bodyJoints.Waist, CFrame.Angles(math.rad(math.sin(t * 8) * 4 * fade), 0, 0))
		end
	end
end)
local removing = Players.PlayerRemoving:Connect(function(player)
	local record = records[player]
	if record then restore(record) records[player] = nil end
end)
script.Destroying:Connect(function()
	beforeAnimation:Disconnect()
	frame:Disconnect()
	removing:Disconnect()
	for _, record in pairs(records) do restore(record) end
	for _, record in pairs(botRecords) do restore(record) end
	table.clear(botRecords)
end)



]====],after=[====[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local records = {}
local function restore(record)
	for joint, entry in pairs(record.joints) do
		if joint.Parent and joint.Transform == entry.applied then joint.Transform = entry.original end
	end
	table.clear(record.joints)
end
local function pose(record, joint, offset)
	if not joint or not (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then return end
	local previous = record.joints[joint]
	local original = joint.Transform
	if previous and original == previous.applied then original = previous.original end
	joint.Transform = original * offset
	record.joints[joint] = { original = original, applied = joint.Transform }
end
local bodyNames = {
	"HumanoidRootPart", "Torso", "LowerTorso", "UpperTorso", "Head",
	"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"Right Arm", "Left Arm", "Right Leg", "Left Leg",
}
local function collectJoints(character)
	local joints = {}
	for _, name in ipairs(bodyNames) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("Motor6D") or child:IsA("AnimationConstraint") then joints[child.Name] = child end
			end
		end
	end
	return joints
end
local function bodyJoints(record, character, now)
	if not record.bodyJoints or now - (record.jointsAt or -math.huge) >= 0.5 then
		record.bodyJoints = collectJoints(character)
		record.jointsAt = now
	end
	return record.bodyJoints
end
local function vector(x, y, z) return Vector3.new(x, y, z) end
local batPoses = {
	{ time = 0, r6 = vector(90, 0, -8), r15 = vector(65, 0, -8), elbow = 25,
		wrist = vector(0, 0, 0), root = vector(0, 0, 0), waist = vector(0, 0, 0),
		guide = vector(75, -30, 16), guideElbow = 48, guideWeight = 0, bodyWeight = 0 },
	{ time = 0.105, r6 = vector(116, 4, -40), r15 = vector(91, 4, -35), elbow = 42,
		wrist = vector(-6, -12, -8), root = vector(3, -16, -3), waist = vector(2, -19, -2),
		guide = vector(106, -60, 10), guideElbow = 15, guideWeight = 1, bodyWeight = 1 },
	{ time = 0.15, r6 = vector(111, 4, -35), r15 = vector(87, 4, -30), elbow = 36,
		wrist = vector(-9, -9, -5), root = vector(1, -9, -2), waist = vector(0, -12, -1),
		guide = vector(100, -60, 10), guideElbow = 8, guideWeight = 1, bodyWeight = 1 },
	{ time = 0.22, r6 = vector(45, 28, -16), r15 = vector(36, 28, -16), elbow = 9,
		wrist = vector(-7, 3, 2), root = vector(-5, 9, 4), waist = vector(-3, 15, 2),
		guide = vector(56, -68, 10), guideElbow = 5, guideWeight = 1, bodyWeight = 1 },
	{ time = 0.30, r6 = vector(74, 84, -24), r15 = vector(54, 80, -19), elbow = 33,
		wrist = vector(8, 13, 10), root = vector(-2, 18, 5), waist = vector(-1, 23, 3),
		guide = vector(53, -8, 15), guideElbow = 35, guideWeight = 0.5, bodyWeight = 1 },
	{ time = 0.365, r6 = vector(88, 62, -18), r15 = vector(65, 56, -15), elbow = 37,
		wrist = vector(4, 8, 4), root = vector(0, 13, 3), waist = vector(0, 15, 2),
		guide = vector(41, -4, 9), guideElbow = 28, guideWeight = 0.25, bodyWeight = 0.65 },
	{ time = 0.48, r6 = vector(90, 0, -8), r15 = vector(65, 0, -8), elbow = 25,
		wrist = vector(0, 0, 0), root = vector(0, 0, 0), waist = vector(0, 0, 0),
		guide = vector(75, -30, 16), guideElbow = 48, guideWeight = 0, bodyWeight = 0 },
}
local function tangent(index, key)
	if index == 1 or index == #batPoses then return batPoses[index][key] * 0 end
	local before, current, after = batPoses[index - 1], batPoses[index], batPoses[index + 1]
	local incoming = (current[key] - before[key]) / (current.time - before.time)
	local outgoing = (after[key] - current[key]) / (after.time - current.time)
	return (incoming + outgoing) * 0.35
end
local function sampleBatPose(elapsed, classic)
	local first = batPoses[1]
	if elapsed < 0 or elapsed >= 0.48 then elapsed = 0 end
	local index = 2
	while index < #batPoses and elapsed > batPoses[index].time do index += 1 end
	local start, finish = batPoses[index - 1], batPoses[index]
	local duration = finish.time - start.time
	local t = math.clamp((elapsed - start.time) / duration, 0, 1)
	local t2, t3 = t * t, t * t * t
	local result = {}
	for key, value in pairs(first) do
		if key ~= "time" then
			result[key] = start[key] * (2 * t3 - 3 * t2 + 1)
				+ tangent(index - 1, key) * duration * (t3 - 2 * t2 + t)
				+ finish[key] * (-2 * t3 + 3 * t2)
				+ tangent(index, key) * duration * (t3 - t2)
		end
	end
	result.shoulder = result[classic and "r6" or "r15"]
	result.guideWeight = math.clamp(result.guideWeight, 0, 1)
	result.bodyWeight = math.clamp(result.bodyWeight, 0, 1)
	return result
end
local function weaponJoint(record, joint, angles, weight, additive)
	if not joint or not joint.Parent or weight <= 0
		or not (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) or not joint.Enabled then return end
	local previous = record.joints[joint]
	local original = joint.Transform
	if previous and original == previous.applied then original = previous.original end
	local basis = joint.C0.Rotation
	local rotation = CFrame.fromEulerAnglesYXZ(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z))
	local target = basis:Inverse() * rotation * basis
	if additive then target = original * target end
	joint.Transform = original:Lerp(target, math.clamp(weight, 0, 1))
	record.joints[joint] = { original = original, applied = joint.Transform }
end
local function applyBatPose(record, joints, sampled, classic, fade)
	weaponJoint(record, joints[classic and "Right Shoulder" or "RightShoulder"], sampled.shoulder, fade)
	weaponJoint(record, joints.RightElbow, vector(sampled.elbow, 0, 0), fade)
	weaponJoint(record, joints.RightWrist, sampled.wrist, fade)
	local guide = sampled.guideWeight * fade
	weaponJoint(record, joints[classic and "Left Shoulder" or "LeftShoulder"], sampled.guide, guide)
	weaponJoint(record, joints.LeftElbow, vector(sampled.guideElbow, 0, 0), guide)
	weaponJoint(record, joints.LeftWrist, vector(0, 10, -8), guide)
	local root = sampled.root * (classic and 1 or 0.55)
	weaponJoint(record, joints.RootJoint or joints.Root, root, fade, true)
	if not classic then weaponJoint(record, joints.Waist, sampled.waist, fade, true) end
	local chest = root + (classic and Vector3.zero or sampled.waist)
	weaponJoint(record, joints.Neck, vector(-chest.X * 0.4, -chest.Y * 0.6, -chest.Z * 0.5), fade, true)
	local weight = sampled.bodyWeight
	weaponJoint(record, joints[classic and "Right Hip" or "RightHip"],
		vector(-root.X + 2 * weight, -root.Y * 0.8, -root.Z), fade, true)
	weaponJoint(record, joints[classic and "Left Hip" or "LeftHip"],
		vector(-root.X - 2 * weight, -root.Y * 0.8, -root.Z), fade, true)
	weaponJoint(record, joints.RightKnee, vector(-3 * weight, 0, 0), fade, true)
	weaponJoint(record, joints.LeftKnee, vector(-5 * weight, 0, 0), fade, true)
end
local function animateBat(record, player, character, humanoid, now)
	local gameName = character:GetAttribute("PCBatGame")
	local participating = (gameName == "BritishBulldog" and player:GetAttribute("BBParticipating") == true)
		or (gameName == "TagYoureIt" and player:GetAttribute("TGParticipating") == true)
	if humanoid.Health <= 0 or character:GetAttribute("PCBatHeld") ~= true or not participating
		or player:GetAttribute("MDParticipating") == true
		or player:GetAttribute("BBRagdolled") == true or player:GetAttribute("TGRagdolled") == true then
		record.weapon = nil
		return false
	end
	if record.weapon ~= gameName then
		record.weapon = gameName
		record.weaponAt = now
		record.jointsAt = nil
	end
	local started = player:GetAttribute("PCBatSwingAt")
	local elapsed = typeof(started) == "number" and started == started and now - started or math.huge
	local classic = humanoid.RigType == Enum.HumanoidRigType.R6
	local sampled = sampleBatPose(elapsed, classic)
	local fade = math.clamp((now - record.weaponAt) / 0.1, 0, 1)
	applyBatPose(record, bodyJoints(record, character, now), sampled, classic, fade)
	return true
end
local toyActions = {
	M01 = { action = "Kick", duration = 1.10, placeAt = 0.24, contactAt = 0.60 },
	M02 = { action = "Lob", duration = 0.85, contactAt = 0.34 },
	M03 = { action = "Bonk", duration = 0.58, contactAt = 0.23 },
	M04 = { action = "BarrelThrow", duration = 1.10, contactAt = 0.52 },
	M05 = { action = "Drink", duration = 1.30, contactAt = 0.82 },
	M06 = { action = "Drink", duration = 1.30, contactAt = 0.82 },
	M07 = { action = "Drink", duration = 1.30, contactAt = 0.82, alternateAction = "Aim", alternateDuration = 0.80 },
	M08 = { action = "Shake", duration = 1.05, contactAt = 0.65 },
	M10 = { action = "Aim", duration = 0.80, contactAt = 0.35 },
	M11 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M12 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M13 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M14 = { action = "Carry", duration = 0 },
	M15 = { action = "Place", duration = 1.00, contactAt = 0.46 },
}
local function toyPose(values)
	local result = {
		right = vector(64, 0, -8), elbow = 20, wrist = Vector3.zero,
		left = vector(55, -32, 10), leftElbow = 20, leftWeight = 0,
		root = Vector3.zero, waist = Vector3.zero,
		rightHip = Vector3.zero, leftHip = Vector3.zero,
		rightKnee = 0, leftKnee = 0,
		barrelLift = 0, drinkTip = 0,
	}
	for key, value in pairs(values or {}) do result[key] = value end
	return result
end
local toyIdle = {
	M01 = toyPose({right=vector(52,0,-12)}),
	M02 = toyPose({right=vector(65,8,-20),elbow=25,left=vector(65,-34,14),leftElbow=24,leftWeight=0.65}),
	M03 = toyPose({right=vector(82,0,-10),elbow=25}),
	M04 = toyPose({right=vector(63,14,-25),elbow=18,left=vector(65,-34,18),leftElbow=18,leftWeight=1}),
	M05 = toyPose(), M06 = toyPose(), M07 = toyPose(),
	M08 = toyPose({right=vector(65,12,-24),elbow=24,left=vector(65,-34,18),leftElbow=24,leftWeight=0.85}),
	M10 = toyPose({right=vector(75,4,-12),elbow=20,left=vector(63,-35,15),leftElbow=25,leftWeight=0.45}),
	M11 = toyPose(), M12 = toyPose(), M13 = toyPose(),
	M14 = toyPose({right=vector(90,-6,-17),elbow=23}),
	M15 = toyPose({right=vector(52,12,-20),elbow=16,left=vector(53,-36,17),leftElbow=16,leftWeight=1}),
}
local function toyKey(time, values) return { time=time, pose=toyPose(values) } end
local toyTracks = {
	Kick = {
		toyKey(0),
		toyKey(0.24,{right=vector(48,8,-18),elbow=6,root=vector(-28,0,0),waist=vector(-14,0,0),
			left=vector(20,-5,18),leftWeight=.7,rightHip=vector(22,0,0),leftHip=vector(22,0,0),rightKnee=-24,leftKnee=-24}),
		toyKey(0.43,{right=vector(20,-4,-22),elbow=6,root=vector(-2,-5,-3),
			left=vector(18,0,25),leftWeight=.7,rightHip=vector(-26,0,-3),rightKnee=-32}),
		toyKey(0.60,{right=vector(27,-5,-28),elbow=8,root=vector(8,8,3),waist=vector(5,5,0),
			left=vector(25,0,28),leftWeight=.85,rightHip=vector(72,0,-3),leftHip=vector(-5,0,0),rightKnee=-4}),
		toyKey(0.76,{right=vector(30,0,-19),elbow=12,root=vector(4,6,2),
			left=vector(24,0,18),leftWeight=.5,rightHip=vector(38,0,0),rightKnee=-12}),
		toyKey(1.10),
	},
	Lob = {
		toyKey(0),
		toyKey(0.19,{right=vector(122,8,-22),elbow=48,left=vector(125,-27,19),leftElbow=44,leftWeight=1,
			root=vector(5,0,0),waist=vector(4,0,0),rightKnee=-9,leftKnee=-9}),
		toyKey(0.34,{right=vector(153,7,-15),elbow=8,left=vector(151,-18,14),leftElbow=8,leftWeight=1,
			root=vector(-3,0,0),waist=vector(-3,0,0)}),
		toyKey(0.48,{right=vector(132,9,-17),elbow=12,wrist=vector(14,0,0),
			left=vector(126,-20,15),leftElbow=14,leftWeight=.8,root=vector(-4,0,0)}),
		toyKey(0.85),
	},
	Bonk = {
		toyKey(0),
		toyKey(0.12,{right=vector(118,-24,-32),elbow=36,root=vector(3,-15,-3),waist=vector(0,-12,0),
			left=vector(75,-47,16),leftElbow=30,leftWeight=.65}),
		toyKey(0.23,{right=vector(47,28,-17),elbow=9,wrist=vector(-9,5,0),
			root=vector(-5,10,4),waist=vector(-3,13,0),left=vector(43,-28,18),leftElbow=12,leftWeight=.4}),
		toyKey(0.34,{right=vector(71,76,-23),elbow=28,root=vector(-2,17,4),waist=vector(0,19,0)}),
		toyKey(0.58),
	},
	BarrelThrow = {
		toyKey(0),
		toyKey(0.23,{right=vector(102,8,-20),elbow=35,left=vector(104,-29,19),leftElbow=35,leftWeight=1,
			root=vector(-8,0,0),waist=vector(-5,0,0),rightKnee=-13,leftKnee=-13}),
		toyKey(0.40,{right=vector(164,8,-18),elbow=22,left=vector(163,-20,17),leftElbow=22,leftWeight=1,barrelLift=1,
			root=vector(7,0,0),waist=vector(6,0,0)}),
		toyKey(0.52,{right=vector(104,5,-15),elbow=5,left=vector(103,-20,16),leftElbow=5,leftWeight=1,
			root=vector(-13,0,0),waist=vector(-8,0,0)}),
		toyKey(0.69,{right=vector(69,9,-18),elbow=9,left=vector(68,-25,18),leftElbow=9,leftWeight=.8,
			root=vector(-10,0,0),waist=vector(-5,0,0)}),
		toyKey(1.10),
	},
	Drink = {
		toyKey(0),
		toyKey(0.32,{right=vector(128,8,-37),elbow=58,wrist=vector(-14,0,-8),root=vector(2,0,0)}),
		toyKey(0.60,{right=vector(136,7,-39),elbow=65,wrist=vector(-31,0,-8),root=vector(4,0,0),waist=vector(2,0,0),drinkTip=1}),
		toyKey(0.82,{right=vector(135,7,-39),elbow=64,wrist=vector(-35,0,-8),root=vector(4,0,0),waist=vector(2,0,0),drinkTip=1}),
		toyKey(1.02,{right=vector(113,8,-27),elbow=44,wrist=vector(-10,0,-3),root=vector(1,0,0)}),
		toyKey(1.30),
	},
	Shake = {
		toyKey(0),
		toyKey(0.20,{right=vector(94,13,-28),elbow=34,left=vector(93,-35,20),leftElbow=33,leftWeight=1}),
		toyKey(0.35,{right=vector(103,6,-31),elbow=39,left=vector(103,-41,23),leftElbow=38,leftWeight=1,root=vector(0,-3,-2)}),
		toyKey(0.48,{right=vector(82,20,-23),elbow=26,left=vector(82,-28,17),leftElbow=25,leftWeight=1,root=vector(0,3,2)}),
		toyKey(0.65,{right=vector(105,7,-32),elbow=40,left=vector(104,-40,23),leftElbow=39,leftWeight=1,root=vector(0,-3,-2)}),
		toyKey(0.78,{right=vector(83,18,-24),elbow=28,left=vector(84,-30,18),leftElbow=27,leftWeight=.9,root=vector(0,2,1)}),
		toyKey(1.05),
	},
	Aim = {
		toyKey(0),
		toyKey(0.22,{right=vector(89,5,-11),elbow=14,left=vector(81,-37,19),leftElbow=32,leftWeight=.9,
			root=vector(-3,-5,0),waist=vector(0,-5,0)}),
		toyKey(0.35,{right=vector(89,5,-11),elbow=14,left=vector(81,-37,19),leftElbow=32,leftWeight=.9,
			root=vector(-3,-5,0),waist=vector(0,-5,0)}),
		toyKey(0.41,{right=vector(97,3,-14),elbow=24,left=vector(85,-38,20),leftElbow=38,leftWeight=.9,
			root=vector(1,-5,0),waist=vector(2,-5,0)}),
		toyKey(0.80),
	},
	Throw = {
		toyKey(0),
		toyKey(0.17,{right=vector(136,-31,-32),elbow=44,root=vector(4,-14,-3),waist=vector(2,-14,0),
			left=vector(62,6,16),leftWeight=.6}),
		toyKey(0.30,{right=vector(90,11,-16),elbow=5,wrist=vector(12,0,0),
			root=vector(-7,10,3),waist=vector(-4,12,0),left=vector(32,-7,19),leftWeight=.4}),
		toyKey(0.45,{right=vector(57,49,-25),elbow=16,root=vector(-5,15,3),waist=vector(-3,12,0)}),
		toyKey(0.78),
	},
	Place = {
		toyKey(0),
		toyKey(0.24,{right=vector(47,12,-21),elbow=12,left=vector(49,-36,18),leftElbow=12,leftWeight=1,
			root=vector(-18,0,0),waist=vector(-12,0,0),rightHip=vector(15,0,0),leftHip=vector(15,0,0),rightKnee=-20,leftKnee=-20}),
		toyKey(0.46,{right=vector(41,12,-20),elbow=3,left=vector(42,-35,17),leftElbow=3,leftWeight=1,
			root=vector(-29,0,0),waist=vector(-16,0,0),rightHip=vector(26,0,0),leftHip=vector(26,0,0),rightKnee=-30,leftKnee=-30}),
		toyKey(0.64,{right=vector(31,6,-20),elbow=8,left=vector(32,-21,18),leftElbow=8,leftWeight=.7,
			root=vector(-16,0,0),waist=vector(-8,0,0),rightHip=vector(13,0,0),leftHip=vector(13,0,0),rightKnee=-16,leftKnee=-16}),
		toyKey(1.00),
	},
}
local function sampleToyPose(id, action, elapsed)
	local idle = toyIdle[id]
	local definition = toyActions[id]
	if not idle or not definition then return nil end
	local track = toyTracks[action]
	local duration = action == definition.action and definition.duration or action == definition.alternateAction and definition.alternateDuration
	if not duration or not track or elapsed ~= elapsed or elapsed < 0 or elapsed >= duration then return idle end
	local index = 2
	while index < #track and elapsed > track[index].time do index += 1 end
	local before, after = track[index - 1], track[index]
	local alpha = math.clamp((elapsed - before.time) / (after.time - before.time), 0, 1)
	alpha = alpha * alpha * (3 - 2 * alpha)
	local first = index == 2 and idle or before.pose
	local last = index == #track and idle or after.pose
	local sampled = {}
	for key, value in pairs(first) do sampled[key] = value + (last[key] - value) * alpha end
	return sampled
end
local function applyToyPose(record, joints, sampled, classic, fade)
	local right = sampled.right - vector(classic and 0 or sampled.elbow,0,0)
	local left = sampled.left - vector(classic and 0 or sampled.leftElbow,0,0)
	if classic then
		right += vector(-24,32,-12) * sampled.barrelLift
		left += vector(-23,-20,13) * sampled.barrelLift
	end
	local wrist = sampled.wrist + (classic and Vector3.zero or vector(45,80,38) * sampled.drinkTip)
	weaponJoint(record,joints[classic and "Right Shoulder" or "RightShoulder"],right,fade)
	weaponJoint(record,joints.RightElbow,vector(sampled.elbow,0,0),fade)
	weaponJoint(record,joints.RightWrist,wrist,fade)
	weaponJoint(record,joints[classic and "Left Shoulder" or "LeftShoulder"],left,fade*sampled.leftWeight)
	weaponJoint(record,joints.LeftElbow,vector(sampled.leftElbow,0,0),fade*sampled.leftWeight)
	local root = sampled.root * (classic and 1 or 0.55)
	weaponJoint(record,joints.RootJoint or joints.Root,root,fade,true)
	weaponJoint(record,joints.Waist,sampled.waist,fade,true)
	local chest = root + (classic and Vector3.zero or sampled.waist)
	weaponJoint(record,joints.Neck,vector(-chest.X*.35,-chest.Y*.5,-chest.Z*.4),fade,true)
	weaponJoint(record,joints[classic and "Right Hip" or "RightHip"],sampled.rightHip,fade,true)
	weaponJoint(record,joints[classic and "Left Hip" or "LeftHip"],sampled.leftHip,fade,true)
	weaponJoint(record,joints.RightKnee,vector(sampled.rightKnee,0,0),fade,true)
	weaponJoint(record,joints.LeftKnee,vector(sampled.leftKnee,0,0),fade,true)
end
local function animateToy(record, player, character, humanoid, now)
	local id = character:GetAttribute("PCToyHeld")
	if typeof(id) ~= "string" or not toyActions[id] or humanoid.Health <= 0
		or player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true or player:GetAttribute("BBRagdolled") == true
		or player:GetAttribute("TGRagdolled") == true then
		record.toy = nil
		return false
	end
	if record.toy ~= id then
		record.toy = id
		record.toyAt = now
		record.jointsAt = nil
	end
	local started = player:GetAttribute("PCToyActionAt")
	local action = player:GetAttribute("PCToyAction")
	local matches = player:GetAttribute("PCToyActionItem") == id
	local elapsed = matches and typeof(started) == "number" and started == started and now - started or math.huge
	local sampled = sampleToyPose(id, action, elapsed)
	local fade = math.clamp((now-record.toyAt)/0.12,0,1)
	applyToyPose(record,bodyJoints(record,character,now),sampled,humanoid.RigType==Enum.HumanoidRigType.R6,fade)
	return true
end
local function animateDodge(record, player, character, humanoid, now)
	if not character or not humanoid or humanoid.Health <= 0 or player:GetAttribute("BBRagdolled") == true
		or player:GetAttribute("TGRagdolled") == true or player:GetAttribute("MDParticipating") == true then return false end
	local prefix
	if player:GetAttribute("BBParticipating") == true and player:GetAttribute("BBRole") == "Runner"
		and player:GetAttribute("BBStatus") == "Crossing" then prefix = "BB"
	elseif player:GetAttribute("TGParticipating") == true then prefix = "TG" end
	if not prefix then return false end
	local states = game:GetService("ReplicatedStorage")
	local state = states:FindFirstChild(prefix == "BB" and "BritishBulldogState" or "TagState")
	if not state or state:GetAttribute("Phase") ~= (prefix == "BB" and "Crossing" or "Playing") then return false end
	local started = player:GetAttribute(prefix .. "DodgeStartedAt")
	local duration = player:GetAttribute(prefix .. "DodgeDuration")
	local direction = player:GetAttribute(prefix .. "DodgeDirection")
	if typeof(started) ~= "number" or started ~= started or started <= 0 or typeof(duration) ~= "number"
		or duration ~= duration or duration < 0.15 or duration > 0.5 or typeof(direction) ~= "Vector3" then return false end
	local elapsed = now - started
	duration += 0.14
	if elapsed < 0 or elapsed >= duration then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local side = math.clamp(root.CFrame:VectorToObjectSpace(direction).X, -1, 1)
	if side ~= side then return false end
	local alpha = math.clamp(elapsed / duration, 0, 1)
	local strength = alpha < 0.22 and math.sin(alpha / 0.22 * math.pi / 2)
		or math.cos((alpha - 0.22) / 0.78 * math.pi / 2)^2
	local joints = bodyJoints(record, character, now)
	local classic = humanoid.RigType == Enum.HumanoidRigType.R6
	local lean = vector(-9, 8 * side, -26 * side)
	weaponJoint(record, joints.RootJoint or joints.Root, lean, strength * (classic and 1 or 0.65), true)
	weaponJoint(record, joints.Waist, lean, strength * 0.35, true)
	weaponJoint(record, joints[classic and "Right Shoulder" or "RightShoulder"], vector(-12,0,18), strength, true)
	weaponJoint(record, joints[classic and "Left Shoulder" or "LeftShoulder"], vector(-12,0,-18), strength, true)
	return true
end


local botRecords = {}
local function animatePracticeBots(now)
	local state = game:GetService("ReplicatedStorage"):FindFirstChild("TagState")
	local folder = workspace:FindFirstChild("TagPracticeBots")
	local playing = state and state:GetAttribute("Phase") == "Playing"
	for character, record in pairs(botRecords) do
		restore(record)
		if not playing or not folder or character.Parent ~= folder then botRecords[character] = nil end
	end
	if not playing or not folder then return end
	for _, character in ipairs(folder:GetChildren()) do
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or humanoid.Health <= 0 or humanoid.PlatformStand then continue end
		local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
		if speed < 0.1 then continue end
		local record = botRecords[character]
		if not record then record = { character = character, joints = {} } botRecords[character] = record end
		local joints = bodyJoints(record, character, now)
		local classic = humanoid.RigType == Enum.HumanoidRigType.R6
		local swing = math.sin(now * 10) * math.min(speed / 16, 1) * 24
		weaponJoint(record, joints[classic and "Right Hip" or "RightHip"], vector(swing,0,0), 1, true)
		weaponJoint(record, joints[classic and "Left Hip" or "LeftHip"], vector(-swing,0,0), 1, true)
		weaponJoint(record, joints[classic and "Right Shoulder" or "RightShoulder"], vector(-swing,0,0), 1, true)
		weaponJoint(record, joints[classic and "Left Shoulder" or "LeftShoulder"], vector(swing,0,0), 1, true)
	end
end

local catalogEmote
local lastEmoteSerial = 0
local retiredEmotes = {}

local function emoteAnimationId(value)
	if typeof(value) ~= "string" then return nil end
	local digits = value:match("^rbxassetid://(%d+)$")
	if not digits or #digits > 18 or tonumber(digits) <= 0 then return nil end
	return value
end

local function emoteNumber(value)
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function emoteStatus(status, message)
	local player = Players.LocalPlayer
	if player then
		player:SetAttribute("PCEmotePlaybackMessage", message or "")
		player:SetAttribute("PCEmotePlaybackStatus", status)
	end
end

local function disposeEmote(track, animation)
	if track then pcall(function() track:Destroy() end) end
	if animation then animation:Destroy() end
end

local function cleanRetiredEmotes(force)
	for index = #retiredEmotes, 1, -1 do
		local entry = retiredEmotes[index]
		if force or os.clock() >= entry.destroyAt then
			disposeEmote(entry.track, entry.animation)
			table.remove(retiredEmotes, index)
		end
	end
end

local function stopCatalogEmote(message, failed)
	local request = catalogEmote
	if not request then return end
	catalogEmote = nil
	request.expired = true
	if request.worker and coroutine.status(request.worker) ~= "dead" and request.worker ~= coroutine.running() then pcall(task.cancel, request.worker) end
	if request.track then
		pcall(function() request.track:Stop(0.12) end)
		table.insert(retiredEmotes, {track=request.track,animation=request.animation,destroyAt=os.clock()+0.2})
	else disposeEmote(nil, request.animation) end
	emoteStatus(failed and "failed" or "stopped", message)
end

local function emoteCanContinue(player, character, humanoid)
	if not character or not character.Parent or not humanoid or humanoid.Health <= 0 or humanoid.PlatformStand
		or humanoid.RigType ~= Enum.HumanoidRigType.R15 or player:GetAttribute("PCDataReady") ~= true then return false end
	if player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true or player:GetAttribute("BBRagdolled") == true
		or player:GetAttribute("TGRagdolled") == true or character:GetAttribute("PCBatHeld") == true then return false end
	local toy = character:GetAttribute("PCToyHeld")
	if typeof(toy) == "string" and toy ~= "" then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or humanoid.MoveDirection.Magnitude > 0.08 or humanoid.Jump then return false end
	local velocity = root.AssemblyLinearVelocity
	if Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 1.5 then return false end
	local state = humanoid:GetState()
	return state ~= Enum.HumanoidStateType.Jumping and state ~= Enum.HumanoidStateType.Freefall
		and state ~= Enum.HumanoidStateType.Climbing and state ~= Enum.HumanoidStateType.Swimming
		and state ~= Enum.HumanoidStateType.Seated and state ~= Enum.HumanoidStateType.Dead
end

local function updateCatalogEmote(now)
	cleanRetiredEmotes(false)
	local player = Players.LocalPlayer
	if not player then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local serial = player:GetAttribute("PCEmoteSerial")
	local expires = player:GetAttribute("PCEmoteUntil")
	if catalogEmote and (catalogEmote.character ~= character or serial ~= catalogEmote.serial
		or not emoteNumber(expires) or now >= expires or not emoteCanContinue(player, character, humanoid)
		or (tonumber(player:GetAttribute("PCToyActionAt")) or 0) > catalogEmote.startedAt) then
		stopCatalogEmote("Dance stopped")
	end
	if emoteNumber(serial) and serial > 0 and serial % 1 == 0 and serial ~= lastEmoteSerial then
		lastEmoteSerial = serial
		local asset = emoteAnimationId(player:GetAttribute("PCEmoteAnimationId"))
		local started = player:GetAttribute("PCEmoteStartedAt")
		if not asset or player:GetAttribute("PCEmoteRigType") ~= "R15" or not emoteNumber(started)
			or not emoteNumber(expires) or started > now + 0.5 or expires <= now or expires - started > 35
			or not emoteCanContinue(player, character, humanoid) then return end
		catalogEmote = {serial=serial,character=character,humanoid=humanoid,asset=asset,startedAt=started,loadAt=os.clock()}
		emoteStatus("loading", "Loading dance...")
	end
	local request = catalogEmote
	if not request then return end
	if os.clock() - request.loadAt > 8 and (not request.track or request.track.Length <= 0) then
		stopCatalogEmote("This dance couldn't load. Try playing it again.", true)
		return
	end
	if request.track then
		if request.track.Length > 0 then
			if not request.track.IsPlaying then stopCatalogEmote("Dance stopped")
			elseif not request.ready then request.ready = true emoteStatus("playing", "Move or jump to stop dancing") end
		end
		return
	end
	if request.loading then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	request.loading = true
	local animation = Instance.new("Animation")
	animation.Name = "PlaygroundCatalogEmote"
	animation.AnimationId = request.asset
	request.animation = animation
	request.worker = task.spawn(function()
		local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
		if catalogEmote ~= request or request.expired then
			if ok then disposeEmote(track, nil) end
			return
		end
		if not ok then stopCatalogEmote("This dance couldn't load. Try playing it again.", true) return end
		request.track = track
		local played = pcall(function()
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.2)
		end)
		if not played then stopCatalogEmote("This dance couldn't play. Try again.", true) end
	end)
end


local beforeAnimation = RunService.PreAnimation:Connect(function()
	for _, record in pairs(records) do restore(record) end
	for _, record in pairs(botRecords) do restore(record) end
end)
local frame = RunService.PreSimulation:Connect(function()
	local now = workspace:GetServerTimeNow()
	updateCatalogEmote(now)
	animatePracticeBots(now)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local record = records[player]
		if not record or record.character ~= character then
			if record then restore(record) end
			record = { character = character, joints = {} }
			records[player] = record
		end
		restore(record)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then record.weapon = nil record.toy = nil continue end
		if player == Players.LocalPlayer and catalogEmote and catalogEmote.character == character then continue end
		if animateDodge(record, player, character, humanoid, now) then continue end
		if animateBat(record, player, character, humanoid, now) then record.toy = nil continue end
		if animateToy(record, player, character, humanoid, now) then continue end
		local untilTime = player:GetAttribute("PCEmoteUntil")
		local action = player:GetAttribute("PCEmoteAction")
		if not character or typeof(untilTime) ~= "number" or now >= untilTime or player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") then
			continue
		end
		bodyJoints(record, character, now)
		local classic = humanoid.RigType == Enum.HumanoidRigType.R6
		local right = record.bodyJoints[classic and "Right Shoulder" or "RightShoulder"]
		local left = record.bodyJoints[classic and "Left Shoulder" or "LeftShoulder"]
		local t = 2.4 - (untilTime - now)
		local fade = math.min(1, t / 0.18, (untilTime - now) / 0.2)
		if action == "Wave" then
			local swing = math.sin(t * 13) * 20
			pose(record, right, classic and CFrame.Angles(math.rad(-110 * fade), math.rad(swing * fade), 0) or CFrame.Angles(math.rad(20 * fade), 0, math.rad((125 + swing) * fade)))
			pose(record, record.bodyJoints.RightElbow, CFrame.Angles(math.rad(-25 * fade), 0, 0))
		elseif action == "Cheer" then
			local rise = (145 + math.sin(t * 8) * 12) * fade
			pose(record, right, classic and CFrame.Angles(math.rad(-rise), 0, 0) or CFrame.Angles(math.rad(12 * fade), 0, math.rad(rise)))
			pose(record, left, classic and CFrame.Angles(math.rad(-rise), 0, 0) or CFrame.Angles(math.rad(12 * fade), 0, math.rad(-rise)))
			pose(record, record.bodyJoints.Waist, CFrame.Angles(math.rad(math.sin(t * 8) * 4 * fade), 0, 0))
		end
	end
end)
local removing = Players.PlayerRemoving:Connect(function(player)
	local record = records[player]
	if record then restore(record) records[player] = nil end
end)
script.Destroying:Connect(function()
	stopCatalogEmote("Dance stopped")
	cleanRetiredEmotes(true)
	beforeAnimation:Disconnect()
	frame:Disconnect()
	removing:Disconnect()
	for _, record in pairs(records) do restore(record) end
	for _, record in pairs(botRecords) do restore(record) end
	table.clear(botRecords)
end)



]====]},
{path="StarterGui.PlaygroundPodium.Controller",before=[====[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local function finite(value)
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function animationId(value)
	if typeof(value) == "number" then
		if not finite(value) or value <= 0 or value % 1 ~= 0 then return nil end
		value = string.format("%.0f", value)
	end
	if typeof(value) ~= "string" then return nil end
	local digits = value:match("^rbxassetid://(%d+)$") or value:match("^(%d+)$")
	if not digits or #digits > 18 or tonumber(digits) <= 0 then return nil end
	return "rbxassetid://" .. digits
end

local function readableIsA(object, className)
	local ok, result = pcall(function() return object:IsA(className) end)
	return ok and result
end

local function bodyBounds(model)
	local low, high = math.huge, -math.huge
	for _, part in ipairs(model:GetChildren()) do
		if readableIsA(part, "BasePart") and part.Name ~= "HumanoidRootPart" then
			local half, frame = part.Size * 0.5, part.CFrame
			local extent = math.abs(frame.RightVector.Y) * half.X + math.abs(frame.UpVector.Y) * half.Y + math.abs(frame.LookVector.Y) * half.Z
			low = math.min(low, part.Position.Y - extent)
			high = math.max(high, part.Position.Y + extent)
		end
	end
	return low, high
end

local function prepareModel(model)
	assert(model and model:IsA("Model"), "Avatar model unavailable")
	local humanoid = assert(model:FindFirstChildOfClass("Humanoid"), "Avatar humanoid unavailable")
	local root = assert(model:FindFirstChild("HumanoidRootPart"), "Avatar root unavailable")
	for _, object in ipairs(model:GetDescendants()) do
		if readableIsA(object, "LuaSourceContainer") then
			object:Destroy()
		elseif readableIsA(object, "BasePart") then
			object.Anchored = object == root
			object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
			object.Massless = true
		elseif readableIsA(object, "AnimationConstraint") then
			object.IsKinematic = true
			object.Enabled = true
		end
	end
	humanoid.AutoRotate = false
	humanoid.EvaluateStateMachine = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then animator = Instance.new("Animator") animator.Parent = humanoid end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop(0) end
	local low, high = bodyBounds(model)
	local height = high - low
	assert(finite(height) and height > 0.05 and height < 1000, "Avatar body dimensions unavailable")
	model:ScaleTo(model:GetScale() * 5.5 / height)
	model.PrimaryPart = root
	model:PivotTo(CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, 1)))
	low = bodyBounds(model)
	local result = { model = model, root = root, humanoid = humanoid, animator = animator, floorOffset = -low, joints = {} }
	for _, name in ipairs({ "Right Shoulder", "Left Shoulder", "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "RightWrist", "LeftWrist", "Waist", "Neck" }) do
		local joint = model:FindFirstChild(name, true)
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			result.joints[name] = { joint = joint, original = joint.Transform, rotation = joint.C0.Rotation }
		end
	end
	return result
end

local function poseJoint(avatar, name, x, y, z, fade)
	local entry = avatar.joints[name]
	if not entry or not entry.joint.Parent then return end
	local offset = entry.rotation:Inverse() * CFrame.Angles(math.rad(x), math.rad(y), math.rad(z)) * entry.rotation
	entry.joint.Transform = entry.original:Lerp(entry.original * offset, fade)
end

local function restorePose(avatar)
	for _, entry in pairs(avatar.joints) do if entry.joint.Parent then entry.joint.Transform = entry.original end end
end

local function animateModel(avatar, standingPoint, rank, elapsed, authored)
	local fade = math.clamp(elapsed / 0.35, 0, 1)
	local t = elapsed + rank * 0.7
	local bounce = authored and 0 or (1 - math.cos(elapsed * 3.6)) * 0.065 * fade
	local position = standingPoint.WorldPosition + Vector3.new(0, avatar.floorOffset + bounce, 0)
	avatar.model:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, 1)) * CFrame.Angles(0, math.sin(t * 1.3) * 0.045 * fade, 0))
	if authored then return end
	local wave = math.sin(t * 4.8)
	local right = avatar.joints["Right Shoulder"] and "Right Shoulder" or "RightShoulder"
	local left = avatar.joints["Left Shoulder"] and "Left Shoulder" or "LeftShoulder"
	if rank == 1 then
		poseJoint(avatar, right, 12, 0, 132 + wave * 10, fade)
		poseJoint(avatar, left, 12, 0, -132 + wave * 10, fade)
		poseJoint(avatar, "RightElbow", 35 + wave * 12, 0, 0, fade)
		poseJoint(avatar, "LeftElbow", 35 - wave * 12, 0, 0, fade)
	elseif rank == 2 then
		poseJoint(avatar, right, 10, 0, 140 + wave * 12, fade)
		poseJoint(avatar, left, 0, 0, -12 + math.sin(t * 2) * 5, fade)
		poseJoint(avatar, "RightElbow", 50, wave * 15, 0, fade)
	else
		poseJoint(avatar, right, 18 + wave * 8, 0, 48, fade)
		poseJoint(avatar, left, 18 - wave * 8, 0, -48, fade)
		poseJoint(avatar, "RightElbow", 55 + wave * 15, 0, 0, fade)
		poseJoint(avatar, "LeftElbow", 55 - wave * 15, 0, 0, fade)
	end
	poseJoint(avatar, "Waist", 0, 0, math.sin(t * 2.4) * 4, fade)
	poseJoint(avatar, "Neck", math.sin(t * 2.1) * 3, math.sin(t * 1.4) * 7, 0, fade)
	poseJoint(avatar, "RightWrist", 0, wave * 12, 0, fade)
	poseJoint(avatar, "LeftWrist", 0, -wave * 12, 0, fade)
end

local gui = script.Parent
local playerGui = gui.Parent
local header = gui:WaitForChild("Header")
local slots, connections, selectionConnections = {}, {}, {}
local folder = Instance.new("Folder")
folder.Name = "PlaygroundPodiumAvatars"
folder.Parent = workspace
local alive, activeLoads = true, 0
local selectionGui
local selectedScope, selectedBoard = "global", "MostWins"
local scopes = { global = true, server = true, region = true }
local boardNames = { MostWins = "MOST WINS", HighestLevel = "HIGHEST LEVEL" }
local packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil

local function disconnect(list)
	for _, connection in ipairs(list) do connection:Disconnect() end
	table.clear(list)
end

local function stopTrack(avatar)
	if avatar.track then avatar.track:Stop(0) avatar.track:Destroy() avatar.track = nil end
	if avatar.animation then avatar.animation:Destroy() avatar.animation = nil end
	avatar.animationAsset = nil
	restorePose(avatar)
end

local function clearAvatar(slot)
	if slot.loadToken then slot.loadToken.expired = true slot.loadToken = nil end
	if slot.avatar then stopTrack(slot.avatar) slot.avatar.model:Destroy() slot.avatar = nil end
end

local function setEntry(slot, entry)
	local id = entry and entry.userId
	if slot.userId ~= id then
		clearAvatar(slot)
		slot.userId, slot.attempts, slot.retryAt = id, 0, 0
	end
	slot.entry = entry
	slot.display.NameLabel.Text = entry and entry.name or (packetState == "loading" and "Loading..." or "No winner yet")
	slot.display.ScoreLabel.Text = entry and (selectedBoard == "MostWins" and entry.value .. " WINS" or entry.value) or "—"
	if entry then
		slot.display.StatusLabel.Text = slot.avatar and (packetState == "stale" and "Saved ranking" or "") or (slot.attempts >= 3 and "Avatar unavailable" or "Loading avatar...")
	else
		slot.display.StatusLabel.Text = packetState == "loading" and "Waiting for rankings" or packetState == "unavailable" and "Rankings unavailable" or "Your next win could put you here"
	end
end

local function refreshHeading()
	header.Title.Text = boardNames[selectedBoard] .. " · TOP 3"
	local label = selectedScope == "region" and (packetRegion or "REGION") or selectedScope == "server" and "THIS SERVER" or "GLOBAL"
	header.Subtitle.Text = string.upper(label) .. (packetState == "loading" and " · LOADING" or packetState == "unavailable" and " · UNAVAILABLE" or packetState == "stale" and " · SAVED RANKINGS" or " · WINNERS")
end

local function readPacket()
	local encoded = selectionGui and selectionGui:GetAttribute("PodiumSnapshot")
	if typeof(encoded) ~= "string" or #encoded > 32768 then return end
	local ok, packet = pcall(function() return HttpService:JSONDecode(encoded) end)
	if not ok or typeof(packet) ~= "table" or packet.scope ~= selectedScope or packet.board ~= selectedBoard or typeof(packet.entries) ~= "table" then return end
	packetState = packet.state == "loading" and "loading" or packet.state == "unavailable" and "unavailable" or packet.state == "stale" and "stale" or "ready"
	packetStatus = typeof(packet.status) == "string" and packet.status or ""
	packetRegion = typeof(packet.region) == "string" and packet.region or nil
	local seen = {}
	for index, slot in ipairs(slots) do
		local entry = packet.entries[index]
		if typeof(entry) ~= "table" or not finite(entry.userId) or entry.userId <= 0 or entry.userId % 1 ~= 0 or seen[entry.userId]
			or typeof(entry.name) ~= "string" or typeof(entry.value) ~= "string" then entry = nil end
		if entry then seen[entry.userId] = true end
		setEntry(slot, entry)
	end
	refreshHeading()
end

local function readSelection()
	local scope = selectionGui and selectionGui:GetAttribute("PodiumScope")
	local board = selectionGui and selectionGui:GetAttribute("PodiumBoard")
	scope = scopes[scope] and scope or "global"
	board = boardNames[board] and board or "MostWins"
	if scope ~= selectedScope or board ~= selectedBoard then
		selectedScope, selectedBoard = scope, board
		packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil
		for _, slot in ipairs(slots) do setEntry(slot, nil) end
		refreshHeading()
	end
	readPacket()
end

local function bindSelection()
	local source = playerGui:FindFirstChild("PlaygroundLeaderboards")
	if source == selectionGui then return end
	disconnect(selectionConnections)
	selectionGui = source
	packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil
	for _, slot in ipairs(slots) do setEntry(slot, nil) end
	refreshHeading()
	if source then
		for _, attribute in ipairs({ "PodiumScope", "PodiumBoard", "PodiumSnapshot" }) do
			table.insert(selectionConnections, source:GetAttributeChangedSignal(attribute):Connect(attribute == "PodiumSnapshot" and readPacket or readSelection))
		end
	end
	readSelection()
end

local function bindPedestals()
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local podium = lobby and lobby:FindFirstChild("WinnerPodium")
	local headerFace = podium and podium:FindFirstChild("HeaderFace")
	if headerFace and headerFace:IsA("BasePart") then header.Adornee = headerFace end
	header.Enabled = gui.Enabled and headerFace ~= nil
	for index, slot in ipairs(slots) do
		local pedestal = podium and podium:FindFirstChild("Rank" .. index)
		local point = pedestal and pedestal:FindFirstChild("StandingPoint", true)
		local face = pedestal and pedestal:FindFirstChild("Face")
		slot.point = point and point:IsA("Attachment") and point or nil
		if face and face:IsA("BasePart") then slot.display.Adornee = face end
		slot.display.Enabled = gui.Enabled and slot.point ~= nil and face ~= nil
		if not slot.point and slot.avatar then clearAvatar(slot) end
	end
end

local function beginAvatar(slot)
	local token = { userId = slot.userId, startedAt = os.clock() }
	slot.loadToken = token
	slot.attempts += 1
	activeLoads += 1
	task.spawn(function()
		local ok, model = pcall(function() return Players:CreateHumanoidModelFromUserIdAsync(token.userId) end)
		activeLoads -= 1
		local current = alive and not token.expired and slot.loadToken == token and slot.userId == token.userId and slot.point and slot.point:IsDescendantOf(workspace)
		if slot.loadToken == token then slot.loadToken = nil end
		if not current then if ok and typeof(model) == "Instance" then model:Destroy() end return end
		local prepared, avatar = false, nil
		if ok and typeof(model) == "Instance" then prepared, avatar = pcall(prepareModel, model) end
		if not prepared then
			if ok and typeof(model) == "Instance" then model:Destroy() end
			slot.retryAt = os.clock() + math.min(60, slot.attempts * 15)
			slot.display.StatusLabel.Text = "Avatar unavailable"
			return
		end
		avatar.startedAt = os.clock()
		model.Name = "Rank" .. slot.rank .. "_" .. token.userId
		model:SetAttribute("PodiumUserId", token.userId)
		model.Parent = folder
		slot.avatar = avatar
		animateModel(avatar, slot.point, slot.rank, 0, false)
		slot.display.StatusLabel.Text = packetState == "stale" and "Saved ranking" or ""
	end)
end

local function updateAnimation(avatar)
	local requested = animationId(gui:GetAttribute("PodiumAnimationId"))
	if avatar.animationAsset == requested then return end
	stopTrack(avatar)
	avatar.animationAsset = requested
	if not requested then return end
	local animation = Instance.new("Animation")
	animation.AnimationId = requested
	avatar.animation = animation
	local ok, track = pcall(function() return avatar.animator:LoadAnimation(animation) end)
	if ok then
		avatar.track = track
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.25)
	end
end

for index = 1, 3 do
	slots[index] = { rank = index, display = gui:WaitForChild("Rank" .. index), attempts = 0, retryAt = 0 }
	setEntry(slots[index], nil)
end
refreshHeading()
bindSelection()
readPacket()
bindPedestals()

local function cleanup()
	if not alive then return end
	alive = false
	disconnect(connections)
	disconnect(selectionConnections)
	for _, slot in ipairs(slots) do clearAvatar(slot) slot.display.Enabled = false end
	folder:Destroy()
end

table.insert(connections, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled then folder.Parent = workspace else folder.Parent = nil end
	bindPedestals()
end))
table.insert(connections, gui.Destroying:Connect(cleanup))
table.insert(connections, script.Destroying:Connect(cleanup))
local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	if not alive then return end
	elapsed += dt
	if elapsed < 0.25 then return end
	elapsed = 0
	bindSelection()
	bindPedestals()
	if not gui.Enabled then return end
	local now = os.clock()
	for _, slot in ipairs(slots) do
		if slot.loadToken and now - slot.loadToken.startedAt > 20 then slot.display.StatusLabel.Text = "Avatar is taking longer to load" end
		if slot.userId and slot.point and not slot.avatar and not slot.loadToken and slot.attempts < 3 and now >= slot.retryAt and activeLoads < 2 then beginAvatar(slot) end
	end
end))
table.insert(connections, RunService.PreAnimation:Connect(function()
	if not alive then return end
	for _, slot in ipairs(slots) do if slot.avatar then restorePose(slot.avatar) end end
end))
table.insert(connections, RunService.PreSimulation:Connect(function()
	if not alive or not gui.Enabled then return end
	local now = os.clock()
	for _, slot in ipairs(slots) do
		local avatar = slot.avatar
		if avatar and slot.point and slot.point:IsDescendantOf(workspace) then
			updateAnimation(avatar)
			local authored = avatar.track and avatar.track.IsPlaying and avatar.track.Length > 0
			animateModel(avatar, slot.point, slot.rank, now - avatar.startedAt, authored)
		end
	end
end))


]====],after=[====[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local function finite(value)
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function animationId(value)
	if typeof(value) == "number" then
		if not finite(value) or value <= 0 or value % 1 ~= 0 then return nil end
		value = string.format("%.0f", value)
	end
	if typeof(value) ~= "string" then return nil end
	local digits = value:match("^rbxassetid://(%d+)$") or value:match("^(%d+)$")
	if not digits or #digits > 18 or tonumber(digits) <= 0 then return nil end
	return "rbxassetid://" .. digits
end

local function readableIsA(object, className)
	local ok, result = pcall(function() return object:IsA(className) end)
	return ok and result
end

local function bodyBounds(model)
	local low, high = math.huge, -math.huge
	for _, part in ipairs(model:GetChildren()) do
		if readableIsA(part, "BasePart") and part.Name ~= "HumanoidRootPart" then
			local half, frame = part.Size * 0.5, part.CFrame
			local extent = math.abs(frame.RightVector.Y) * half.X + math.abs(frame.UpVector.Y) * half.Y + math.abs(frame.LookVector.Y) * half.Z
			low = math.min(low, part.Position.Y - extent)
			high = math.max(high, part.Position.Y + extent)
		end
	end
	return low, high
end

local function prepareModel(model)
	assert(model and model:IsA("Model"), "Avatar model unavailable")
	local humanoid = assert(model:FindFirstChildOfClass("Humanoid"), "Avatar humanoid unavailable")
	local root = assert(model:FindFirstChild("HumanoidRootPart"), "Avatar root unavailable")
	for _, object in ipairs(model:GetDescendants()) do
		if readableIsA(object, "LuaSourceContainer") then
			object:Destroy()
		elseif readableIsA(object, "BasePart") then
			object.Anchored = object == root
			object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
			object.Massless = true
		elseif readableIsA(object, "AnimationConstraint") then
			object.IsKinematic = true
			object.Enabled = true
		end
	end
	humanoid.AutoRotate = false
	humanoid.EvaluateStateMachine = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then animator = Instance.new("Animator") animator.Parent = humanoid end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop(0) end
	local low, high = bodyBounds(model)
	local height = high - low
	assert(finite(height) and height > 0.05 and height < 1000, "Avatar body dimensions unavailable")
	model:ScaleTo(model:GetScale() * 5.5 / height)
	model.PrimaryPart = root
	model:PivotTo(CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, 1)))
	low = bodyBounds(model)
	local result = { model = model, root = root, humanoid = humanoid, animator = animator, floorOffset = -low, joints = {} }
	for _, name in ipairs({ "Right Shoulder", "Left Shoulder", "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "RightWrist", "LeftWrist", "Waist", "Neck" }) do
		local joint = model:FindFirstChild(name, true)
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			result.joints[name] = { joint = joint, original = joint.Transform, rotation = joint.C0.Rotation }
		end
	end
	return result
end

local function poseJoint(avatar, name, x, y, z, fade)
	local entry = avatar.joints[name]
	if not entry or not entry.joint.Parent then return end
	local offset = entry.rotation:Inverse() * CFrame.Angles(math.rad(x), math.rad(y), math.rad(z)) * entry.rotation
	entry.joint.Transform = entry.original:Lerp(entry.original * offset, fade)
end

local function restorePose(avatar)
	for _, entry in pairs(avatar.joints) do if entry.joint.Parent then entry.joint.Transform = entry.original end end
end

local function animateModel(avatar, standingPoint, rank, elapsed, authored)
	local fade = math.clamp(elapsed / 0.35, 0, 1)
	local t = elapsed + rank * 0.7
	local bounce = authored and 0 or (1 - math.cos(elapsed * 3.6)) * 0.065 * fade
	local position = standingPoint.WorldPosition + Vector3.new(0, avatar.floorOffset + bounce, 0)
	avatar.model:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, 1)) * CFrame.Angles(0, math.sin(t * 1.3) * 0.045 * fade, 0))
	if authored then return end
	local wave = math.sin(t * 4.8)
	local right = avatar.joints["Right Shoulder"] and "Right Shoulder" or "RightShoulder"
	local left = avatar.joints["Left Shoulder"] and "Left Shoulder" or "LeftShoulder"
	if rank == 1 then
		poseJoint(avatar, right, 12, 0, 132 + wave * 10, fade)
		poseJoint(avatar, left, 12, 0, -132 + wave * 10, fade)
		poseJoint(avatar, "RightElbow", 35 + wave * 12, 0, 0, fade)
		poseJoint(avatar, "LeftElbow", 35 - wave * 12, 0, 0, fade)
	elseif rank == 2 then
		poseJoint(avatar, right, 10, 0, 140 + wave * 12, fade)
		poseJoint(avatar, left, 0, 0, -12 + math.sin(t * 2) * 5, fade)
		poseJoint(avatar, "RightElbow", 50, wave * 15, 0, fade)
	else
		poseJoint(avatar, right, 18 + wave * 8, 0, 48, fade)
		poseJoint(avatar, left, 18 - wave * 8, 0, -48, fade)
		poseJoint(avatar, "RightElbow", 55 + wave * 15, 0, 0, fade)
		poseJoint(avatar, "LeftElbow", 55 - wave * 15, 0, 0, fade)
	end
	poseJoint(avatar, "Waist", 0, 0, math.sin(t * 2.4) * 4, fade)
	poseJoint(avatar, "Neck", math.sin(t * 2.1) * 3, math.sin(t * 1.4) * 7, 0, fade)
	poseJoint(avatar, "RightWrist", 0, wave * 12, 0, fade)
	poseJoint(avatar, "LeftWrist", 0, -wave * 12, 0, fade)
end

local gui = script.Parent
local playerGui = gui.Parent
local header = gui:WaitForChild("Header")
local slots, connections, selectionConnections = {}, {}, {}
local folder = Instance.new("Folder")
folder.Name = "PlaygroundPodiumAvatars"
folder.Parent = workspace
local alive, activeLoads = true, 0
local selectionGui
local selectedScope, selectedBoard = "global", "MostWins"
local scopes = { global = true, server = true, region = true }
local boardNames = { MostWins = "MOST WINS", HighestLevel = "HIGHEST LEVEL" }
local packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil

local function disconnect(list)
	for _, connection in ipairs(list) do connection:Disconnect() end
	table.clear(list)
end

local function stopTrack(avatar)
	local token = avatar.animationToken
	if token then
		token.expired = true
		if token.worker and coroutine.status(token.worker) ~= "dead" and token.worker ~= coroutine.running() then pcall(task.cancel, token.worker) end
		avatar.animationToken = nil
	end
	if avatar.track then avatar.track:Stop(0) avatar.track:Destroy() avatar.track = nil end
	if avatar.animation then avatar.animation:Destroy() avatar.animation = nil end
	avatar.animationAsset = nil
	restorePose(avatar)
end

local function clearAvatar(slot)
	if slot.loadToken then slot.loadToken.expired = true slot.loadToken = nil end
	if slot.avatar then stopTrack(slot.avatar) slot.avatar.model:Destroy() slot.avatar = nil end
end

local function setEntry(slot, entry)
	local id = entry and entry.userId
	if slot.userId ~= id then
		clearAvatar(slot)
		slot.userId, slot.attempts, slot.retryAt = id, 0, 0
	end
	slot.entry = entry
	slot.display.NameLabel.Text = entry and entry.name or (packetState == "loading" and "Loading..." or "No winner yet")
	slot.display.ScoreLabel.Text = entry and (selectedBoard == "MostWins" and entry.value .. " WINS" or entry.value) or "—"
	if entry then
		slot.display.StatusLabel.Text = slot.avatar and (packetState == "stale" and "Saved ranking" or "") or (slot.attempts >= 3 and "Avatar unavailable" or "Loading avatar...")
	else
		slot.display.StatusLabel.Text = packetState == "loading" and "Waiting for rankings" or packetState == "unavailable" and "Rankings unavailable" or "Your next win could put you here"
	end
end

local function refreshHeading()
	header.Title.Text = boardNames[selectedBoard] .. " · TOP 3"
	local label = selectedScope == "region" and (packetRegion or "REGION") or selectedScope == "server" and "THIS SERVER" or "GLOBAL"
	header.Subtitle.Text = string.upper(label) .. (packetState == "loading" and " · LOADING" or packetState == "unavailable" and " · UNAVAILABLE" or packetState == "stale" and " · SAVED RANKINGS" or " · WINNERS")
end

local function readPacket()
	local encoded = selectionGui and selectionGui:GetAttribute("PodiumSnapshot")
	if typeof(encoded) ~= "string" or #encoded > 32768 then return end
	local ok, packet = pcall(function() return HttpService:JSONDecode(encoded) end)
	if not ok or typeof(packet) ~= "table" or packet.scope ~= selectedScope or packet.board ~= selectedBoard or typeof(packet.entries) ~= "table" then return end
	packetState = packet.state == "loading" and "loading" or packet.state == "unavailable" and "unavailable" or packet.state == "stale" and "stale" or "ready"
	packetStatus = typeof(packet.status) == "string" and packet.status or ""
	packetRegion = typeof(packet.region) == "string" and packet.region or nil
	local seen = {}
	for index, slot in ipairs(slots) do
		local entry = packet.entries[index]
		if typeof(entry) ~= "table" or not finite(entry.userId) or entry.userId <= 0 or entry.userId % 1 ~= 0 or seen[entry.userId]
			or typeof(entry.name) ~= "string" or typeof(entry.value) ~= "string" then entry = nil end
		if entry then seen[entry.userId] = true end
		setEntry(slot, entry)
	end
	refreshHeading()
end

local function readSelection()
	local scope = selectionGui and selectionGui:GetAttribute("PodiumScope")
	local board = selectionGui and selectionGui:GetAttribute("PodiumBoard")
	scope = scopes[scope] and scope or "global"
	board = boardNames[board] and board or "MostWins"
	if scope ~= selectedScope or board ~= selectedBoard then
		selectedScope, selectedBoard = scope, board
		packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil
		for _, slot in ipairs(slots) do setEntry(slot, nil) end
		refreshHeading()
	end
	readPacket()
end

local function bindSelection()
	local source = playerGui:FindFirstChild("PlaygroundLeaderboards")
	if source == selectionGui then return end
	disconnect(selectionConnections)
	selectionGui = source
	packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil
	for _, slot in ipairs(slots) do setEntry(slot, nil) end
	refreshHeading()
	if source then
		for _, attribute in ipairs({ "PodiumScope", "PodiumBoard", "PodiumSnapshot" }) do
			table.insert(selectionConnections, source:GetAttributeChangedSignal(attribute):Connect(attribute == "PodiumSnapshot" and readPacket or readSelection))
		end
	end
	readSelection()
end

local function bindPedestals()
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local podium = lobby and lobby:FindFirstChild("WinnerPodium")
	local headerFace = podium and podium:FindFirstChild("HeaderFace")
	if headerFace and headerFace:IsA("BasePart") then header.Adornee = headerFace end
	header.Enabled = gui.Enabled and headerFace ~= nil
	for index, slot in ipairs(slots) do
		local pedestal = podium and podium:FindFirstChild("Rank" .. index)
		local point = pedestal and pedestal:FindFirstChild("StandingPoint", true)
		local face = pedestal and pedestal:FindFirstChild("Face")
		slot.point = point and point:IsA("Attachment") and point or nil
		if face and face:IsA("BasePart") then slot.display.Adornee = face end
		slot.display.Enabled = gui.Enabled and slot.point ~= nil and face ~= nil
		if not slot.point and slot.avatar then clearAvatar(slot) end
	end
end

local function beginAvatar(slot)
	local token = { userId = slot.userId, startedAt = os.clock() }
	slot.loadToken = token
	slot.attempts += 1
	activeLoads += 1
	task.spawn(function()
		local ok, model = pcall(function()
			local description = Players:GetHumanoidDescriptionFromUserIdAsync(token.userId)
			local created, value = pcall(function() return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15) end)
			description:Destroy()
			if not created then error(value) end
			return value
		end)
		activeLoads -= 1
		local current = alive and not token.expired and slot.loadToken == token and slot.userId == token.userId and slot.point and slot.point:IsDescendantOf(workspace)
		if slot.loadToken == token then slot.loadToken = nil end
		if not current then if ok and typeof(model) == "Instance" then model:Destroy() end return end
		local prepared, avatar = false, nil
		if ok and typeof(model) == "Instance" then prepared, avatar = pcall(prepareModel, model) end
		if not prepared then
			if ok and typeof(model) == "Instance" then model:Destroy() end
			slot.retryAt = os.clock() + math.min(60, slot.attempts * 15)
			slot.display.StatusLabel.Text = "Avatar unavailable"
			return
		end
		avatar.startedAt = os.clock()
		model.Name = "Rank" .. slot.rank .. "_" .. token.userId
		model:SetAttribute("PodiumUserId", token.userId)
		model.Parent = folder
		slot.avatar = avatar
		animateModel(avatar, slot.point, slot.rank, 0, false)
		slot.display.StatusLabel.Text = packetState == "stale" and "Saved ranking" or ""
	end)
end

local function requestedAnimation(slot)
	local winner = slot.userId and Players:GetPlayerByUserId(slot.userId)
	local equipped, asset, rig
	if winner and winner:GetAttribute("PCDataReady") == true then
		equipped = winner:GetAttribute("PCEmote")
		asset = winner:GetAttribute("PCEquippedEmoteAnimationId")
		rig = winner:GetAttribute("PCEquippedEmoteRigType")
	else
		local entry = slot.entry
		equipped = entry and entry.emoteId
		asset = entry and entry.emoteAnimationId
		rig = entry and entry.emoteRigType
	end
	if typeof(equipped) == "string" and equipped ~= "" then
		return rig == "R15" and animationId(asset) or nil
	end
	return animationId(gui:GetAttribute("PodiumAnimationId"))
end

local function failedAnimation(slot, avatar)
	stopTrack(avatar)
	avatar.animationRetryAt = os.clock() + 15
	slot.display.StatusLabel.Text = avatar.animationAttempts >= 3 and "Dance unavailable" or "Dance is loading slowly"
end

local function updateAnimation(slot)
	local avatar = slot.avatar
	local requested = requestedAnimation(slot)
	if avatar.requestedAnimation ~= requested then
		stopTrack(avatar)
		avatar.requestedAnimation = requested
		avatar.animationAttempts, avatar.animationRetryAt = 0, 0
	end
	if not requested then return end
	local now = os.clock()
	if avatar.track then
		if avatar.track.Length > 0 and avatar.track.IsPlaying then
			avatar.animationAttempts, avatar.animationRetryAt = 0, 0
			return
		end
		if now - avatar.animationLoadedAt > 8 then failedAnimation(slot, avatar) end
		return
	end
	if avatar.animationToken then
		if now - avatar.animationToken.startedAt > 8 then failedAnimation(slot, avatar) end
		return
	end
	if (avatar.animationAttempts or 0) >= 3 or now < (avatar.animationRetryAt or 0) then return end
	avatar.animationAttempts = (avatar.animationAttempts or 0) + 1
	local token = {startedAt=now}
	avatar.animationToken = token
	local animation = Instance.new("Animation")
	animation.Name = "EquippedPodiumEmote"
	animation.AnimationId = requested
	avatar.animation, avatar.animationAsset = animation, requested
	token.worker = task.spawn(function()
		local ok, track = pcall(function() return avatar.animator:LoadAnimation(animation) end)
		if not alive or token.expired or avatar.animationToken ~= token or slot.avatar ~= avatar or not avatar.model.Parent then
			if ok then track:Destroy() end
			return
		end
		avatar.animationToken = nil
		if not ok then failedAnimation(slot, avatar) return end
		avatar.track, avatar.animationLoadedAt = track, os.clock()
		local played = pcall(function()
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.25)
		end)
		if not played then failedAnimation(slot, avatar)
		else slot.display.StatusLabel.Text = packetState == "stale" and "Saved ranking" or "" end
	end)
end

for index = 1, 3 do
	slots[index] = { rank = index, display = gui:WaitForChild("Rank" .. index), attempts = 0, retryAt = 0 }
	setEntry(slots[index], nil)
end
refreshHeading()
bindSelection()
readPacket()
bindPedestals()

local function cleanup()
	if not alive then return end
	alive = false
	disconnect(connections)
	disconnect(selectionConnections)
	for _, slot in ipairs(slots) do clearAvatar(slot) slot.display.Enabled = false end
	folder:Destroy()
end

table.insert(connections, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled then folder.Parent = workspace else
		for _, slot in ipairs(slots) do if slot.avatar then stopTrack(slot.avatar) end end
		folder.Parent = nil
	end
	bindPedestals()
end))
table.insert(connections, gui.Destroying:Connect(cleanup))
table.insert(connections, script.Destroying:Connect(cleanup))
local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	if not alive then return end
	elapsed += dt
	if elapsed < 0.25 then return end
	elapsed = 0
	bindSelection()
	bindPedestals()
	if not gui.Enabled then return end
	local now = os.clock()
	for _, slot in ipairs(slots) do
		if slot.loadToken and now - slot.loadToken.startedAt > 20 then slot.display.StatusLabel.Text = "Avatar is taking longer to load" end
		if slot.userId and slot.point and not slot.avatar and not slot.loadToken and slot.attempts < 3 and now >= slot.retryAt and activeLoads < 2 then beginAvatar(slot) end
	end
end))
table.insert(connections, RunService.PreAnimation:Connect(function()
	if not alive then return end
	for _, slot in ipairs(slots) do if slot.avatar then restorePose(slot.avatar) end end
end))
table.insert(connections, RunService.PreSimulation:Connect(function()
	if not alive or not gui.Enabled then return end
	local now = os.clock()
	for _, slot in ipairs(slots) do
		local avatar = slot.avatar
		if avatar and slot.point and slot.point:IsDescendantOf(workspace) then
			updateAnimation(slot)
			local authored = avatar.track and avatar.track.IsPlaying and avatar.track.Length > 0
			animateModel(avatar, slot.point, slot.rank, now - avatar.startedAt, authored)
		end
	end
end))


]====]},
{path="StarterGui.PlaygroundShell.Controller",before=[====[
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

local function renderPreview(record, item)
	local id = item and item.id or nil
	if record.previewId == id and (not id or record.model) then return end
	record.previewId = nil
	if record.model then record.model:Destroy() end
	record.model = nil
	previews[record] = nil
	local world = record.card.Preview:FindFirstChild("World")
	if not world then return end
	for _, child in ipairs(world:GetChildren()) do child:Destroy() end
	if not item then return end
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
			local available = item.available ~= false
			local action = not available and "UNAVAILABLE" or not data.ready and "LOADING" or equipped and "UNEQUIP" or owned and "EQUIP" or isCoins and "BUY" or "LOCKED"
			if busy then action = "PLEASE WAIT" end
			setText(card.Action, action)
			card.Action.Visible = true
			card.Action.Active = not busy and data.ready and available and (owned or canBuy)
			card.Action.Selectable = card.Action.Active
			card.Action.BackgroundColor3 = not card.Action.Active and muted or equipped and mint or owned and blue or gold
			setText(card.Try, "INFO")
			card.Try.Visible = true
			card.Try.Active = true
			card.Try.Selectable = true
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
request = function(action, id, quiet)
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
	record.card.Try.Activated:Connect(function()
		local item = record.item
		if not item then return end
		local unlock = data.unlocks[item.id]
		local description = item.description or item.name
		if unlock and not data.owned[item.id] then description ..= " " .. unlock.label .. "." end
		showToast(description, 5)
	end)
	record.card.Preview:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() framePreview(record) end)
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



]====],after=[====[
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



]====]},
{path="StarterGui.MudHUD.Controller",before=[====[
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local HttpService=game:GetService("HttpService")
local player=Players.LocalPlayer
local gui=script.Parent
local main=gui:WaitForChild("Main")
main.Visible=false
local controls=UserInputService.TouchEnabled and main.Controls or (main:FindFirstChild("DesktopControls") or main.Controls)
local state=ReplicatedStorage:WaitForChild("MudState")
local remote=ReplicatedStorage:WaitForChild("MudActionRequest")
local focused=true
local sprintKeys={}
local sprintTouch
local fireTouch
local fireHeld=false
local sprintHeld=false
local binding=false
local lastSprint=0
local lastHeat=0
local lastShot=0
local elapsed=0
local message=""
local messageUntil=0
local palette=gui.ColourPicker
local connections={}
local toolConnections={}
local character
local sending={}
local pending={}

local function connect(signal,callback) table.insert(connections,signal:Connect(callback)) end
local function refreshArtwork(button,value)
 local artwork=button:FindFirstChild("UserArtwork")
 local textless=button:FindFirstChild("TextlessSkin")
 local live=button:FindFirstChild("LiveCaption")
 if artwork and not artwork.IsLoaded then
  artwork.Visible=true
  if textless then textless.Visible=false end
  if live then live.Visible=false end
  return
 end
 local authored=button:GetAttribute("ArtworkText")
 local showLive=not artwork or authored==nil or value~=authored
 if artwork then artwork.Visible=not showLive end
 if textless then textless.Visible=showLive end
 if live then live.Visible=showLive end
end
local function caption(button,value)
 button.Text=value
 local live=button:FindFirstChild("LiveCaption")
 if live then live.Text=value end
 refreshArtwork(button,value)
end
local function playing()
 return player:GetAttribute("MDParticipating")==true and state:GetAttribute("Phase")=="Playing" and player:GetAttribute("MDMuddy")~=true and player:GetAttribute("MDEliminated")~=true
end
local function call(action,value,aim,quiet)
 pending[action]={value=value,aim=aim,quiet=quiet}
 if sending[action] then return end
 sending[action]=true
 task.spawn(function()
  while pending[action] do
   local request=pending[action] pending[action]=nil
   local ok,result=pcall(function() return remote:InvokeServer(action,request.value,request.aim) end)
   if not request.quiet and (not ok or typeof(result)=="table" and result.ok==false) then
    message=ok and tostring(result.message or "Try again.") or "Try again."
    messageUntil=workspace:GetServerTimeNow()+1.4
   end
   if action=="ChooseColor" then palette.Message.Text=ok and result and result.message or "Try again." end
  end
  sending[action]=nil
 end)
end
local function release()
 table.clear(sprintKeys) sprintTouch=nil fireTouch=nil fireHeld=false
 sprintHeld=false
 call("Sprint",false,nil,true)
 call("Heat",false,nil,true)
end
local function sprintChange()
 local held=focused and playing() and not palette.Visible and (next(sprintKeys)~=nil or sprintTouch~=nil)
 if held~=sprintHeld then sprintHeld=held lastSprint=os.clock() call("Sprint",held,nil,true) end
end
local function equip(name)
 if palette.Visible or not player:GetAttribute("MDParticipating") or player:GetAttribute("MDMuddy") or player:GetAttribute("MDEliminated") then return end
 call("Heat",false,nil,true)
 fireHeld=false
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local backpack=player:FindFirstChildOfClass("Backpack")
 local tool=character and character:FindFirstChild(name) or backpack and backpack:FindFirstChild(name)
 if humanoid and tool and tool:IsA("Tool") then humanoid:EquipTool(tool) end
end
local function keys(_,phase,input)
 if not player:GetAttribute("MDParticipating") then return Enum.ContextActionResult.Pass end
 if phase==Enum.UserInputState.End or phase==Enum.UserInputState.Cancel then
  sprintKeys[input.KeyCode]=nil sprintChange()
 elseif phase==Enum.UserInputState.Begin then
  if not focused or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
  sprintKeys[input.KeyCode]=true sprintChange()
 end
 return Enum.ContextActionResult.Sink
end
local function aimDirection()
 local camera=workspace.CurrentCamera
 local character=player.Character
 if not camera or not character then return nil end
 local tool=character:FindFirstChildOfClass("Tool")
 local handle=tool and tool:FindFirstChild("Handle")
 local muzzle=handle and handle:FindFirstChild("MuzzleAttachment")
 local root=character:FindFirstChild("HumanoidRootPart")
 if not muzzle and not root then return nil end
 local ray
 if UserInputService.TouchEnabled then
  ray=camera:ViewportPointToRay(camera.ViewportSize.X/2,camera.ViewportSize.Y/2)
 else
  local pointer=UserInputService:GetMouseLocation()
  ray=camera:ScreenPointToRay(pointer.X,pointer.Y)
 end
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={character}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*500,params)
 local target=hit and hit.Position or ray.Origin+ray.Direction*500
 local origin=muzzle and muzzle.WorldPosition or root.Position+Vector3.new(0,1,0)
 local direction=target-origin
 return direction.Magnitude>0.001 and direction.Unit or nil
end
local function progress(track,fraction)
 fraction=math.clamp(fraction,0,1)
 local gradient=track.Fill.Progress
 if fraction<=0 then gradient.Transparency=NumberSequence.new(1)
 elseif fraction>=1 then gradient.Transparency=NumberSequence.new(0)
 else
  local p=math.clamp(fraction,0.001,0.999)
  gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(p-0.0001,0),NumberSequenceKeypoint.new(p+0.0001,1),NumberSequenceKeypoint.new(1,1)})
 end
end
local function bindTools(newCharacter)
 if newCharacter==character then return end
 release()
 character=newCharacter
 for _,connection in ipairs(toolConnections) do connection:Disconnect() end
 table.clear(toolConnections)
 local hooked={}
 local function bind(tool)
  if not tool:IsA("Tool") or hooked[tool] or (tool.Name~="MudGun" and tool.Name~="HeatGun") then return end
  hooked[tool]=true
  table.insert(toolConnections,tool.Activated:Connect(function()
   if focused and playing() and not palette.Visible then fireHeld=true lastShot=0 end
  end))
  table.insert(toolConnections,tool.Deactivated:Connect(function() fireHeld=false call("Heat",false,nil,true) end))
  table.insert(toolConnections,tool.Unequipped:Connect(function() fireHeld=false call("Heat",false,nil,true) end))
 end
 if character then
  for _,tool in ipairs(character:GetChildren()) do bind(tool) end
  table.insert(toolConnections,character.ChildAdded:Connect(bind))
 end
 local backpack=player:FindFirstChildOfClass("Backpack")
 if backpack then
  for _,tool in ipairs(backpack:GetChildren()) do bind(tool) end
  table.insert(toolConnections,backpack.ChildAdded:Connect(bind))
 end
end
local function refresh()
 local phase=state:GetAttribute("Phase")
 local participating=player:GetAttribute("MDParticipating")==true
 local active=participating and (phase=="Countdown" or phase=="Playing" or phase=="Results")
 local shell=player.PlayerGui:FindFirstChild("PlaygroundShell")
 local compactVote=shell and shell:FindFirstChild("CompactVotePanel")
 local blocked=player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating")
  or shell and (shell.ShopPanel.Visible or shell.VotePanel.Visible or compactVote and compactVote.Visible)
 if palette.Visible and blocked then palette.Visible=false release() end
 main.Visible=active
 gui.ColourToggle.Visible=not participating and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating")
 if participating and not binding then
  ContextActionService:BindActionAtPriority("MudControls",keys,false,3000,Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift)
  binding=true
 elseif not participating and binding then ContextActionService:UnbindAction("MudControls") binding=false release() end
 if not active then return end
 local now=workspace:GetServerTimeNow()
 local remaining=phase=="Countdown" and (state:GetAttribute("RoundDuration") or 300) or math.max(0,(state:GetAttribute("EndsAt") or 0)-now)
 local seconds=math.ceil(remaining)
 main.Top.Timer.Text=string.format("%d:%02d",math.floor(seconds/60),seconds%60)
 main.Top.Visible=phase~="Results"
 main.Countdown.Visible=phase=="Countdown"
 main.Countdown.Text=tostring(state:GetAttribute("CountdownValue") or 3)
 local teamId=player:GetAttribute("MDTeamId") or 0
 local own
 local other
 local ok,teams=pcall(function() return HttpService:JSONDecode(state:GetAttribute("TeamSummaryJSON") or "[]") end)
 if ok and typeof(teams)=="table" then for _,team in ipairs(teams) do if team.teamId==teamId then own=team else other=team end end end
 local color=player:GetAttribute("MDTeamColor") or Color3.fromRGB(42,160,255)
 main.Top.Team.BackgroundColor3=color
 local teamColour=main.Top.Team:FindFirstChild("TeamColour")
 if teamColour then teamColour.BackgroundColor3=color end
 caption(main.Top.Team,string.upper(player:GetAttribute("MDTeamColorName") or "TEAM").."\n"..(own and tostring(own.free).."/"..tostring(own.total).." FREE" or ""))
 main.Top.Other.Text=(state:GetAttribute("TeamCount") or 2)==2 and other and string.upper(other.colorName).."\n"..tostring(other.free).."/"..tostring(other.total).." FREE" or "TEAMS LEFT:\n"..tostring(state:GetAttribute("ActiveTeamCount") or 0)
 local muddy=player:GetAttribute("MDMuddy")==true or player:GetAttribute("MDEliminated")==true
 local showControls=(phase=="Playing" or phase=="Countdown") and not muddy and not palette.Visible
 main.Controls.Visible=controls==main.Controls and showControls
 local desktopControls=main:FindFirstChild("DesktopControls")
 if desktopControls then desktopControls.Visible=controls==desktopControls and showControls end
 controls.Visible=showControls
 controls.Mud.Visible=UserInputService.TouchEnabled
 controls.Heat.Visible=UserInputService.TouchEnabled
 controls.Fire.Visible=UserInputService.TouchEnabled
 main.Frozen.Visible=(phase=="Playing" or phase=="Countdown") and muddy
 main.Crosshair.Visible=playing() and not palette.Visible
 local maximum=math.max(0.1,player:GetAttribute("MDSprintMax") or 10)
 local stamina=math.clamp(player:GetAttribute("MDSprintRemaining") or maximum,0,maximum)
 if player:GetAttribute("MDHeatActive") then
  controls.Meter.Charge.Text=string.format("RESCUING %.1fs / %gs",player:GetAttribute("MDHeatProgress") or 0,state:GetAttribute("RescueSeconds") or 5)
 else controls.Meter.Charge.Text=now<messageUntil and message or string.format("SPRINT %.1fs / %ds",stamina,maximum) end
 progress(controls.Meter.Track,stamina/maximum)
 local sprinting=player:GetAttribute("MDSprinting")
 caption(controls.Sprint,(player:GetAttribute("MDSprintExhausted") and "RECHARGING" or sprinting and "SPRINTING" or "SPRINT").." · "..(UserInputService.TouchEnabled and "HOLD" or "HOLD SHIFT"))
 controls.Sprint.BackgroundColor3=color
 local equipped=player:GetAttribute("MDTool") or ""
 controls.Mud.Outline.Color=equipped=="MudGun" and Color3.fromRGB(255,205,77) or Color3.fromRGB(24,35,62)
 controls.Heat.Outline.Color=equipped=="HeatGun" and Color3.fromRGB(255,205,77) or Color3.fromRGB(24,35,62)
 controls.Mud.Outline.Enabled=equipped=="MudGun"
 controls.Heat.Outline.Enabled=equipped=="HeatGun"
 caption(controls.Fire,equipped=="HeatGun" and "HEAT\nHOLD" or "SPLAT!")
 local rescueSeconds=math.max(0.1,state:GetAttribute("RescueSeconds") or 5)
 local rescue=math.clamp(player:GetAttribute("MDRescueProgress") or 0,0,rescueSeconds)
 main.Frozen.Title.Text=player:GetAttribute("MDEliminated") and "TEAM ELIMINATED" or "STUCK IN THE MUD!"
 main.Frozen.Status.Text=string.format("TEAMMATE HEAT: %.1f / %gs",rescue,rescueSeconds)
 progress(main.Frozen.RescueTrack,rescue/rescueSeconds)
 main.Results.Visible=phase=="Results"
 if phase=="Results" then
  local won=player:GetAttribute("MDResult")=="Won"
  main.Results.Title.Text=won and "YOUR TEAM WINS!" or "ROUND FINISHED!"
  local reason=state:GetAttribute("ResultReason")
  main.Results.Reason.Text=reason=="TimeoutShared" and "BEST SURVIVING TEAMS SHARE THE WIN" or reason=="Timeout" and "MOST OF THE TEAM STAYED FREE" or reason=="NoActiveTeams" and "EVERY TEAM IS STUCK" or "LAST TEAM STILL FREE"
  local practice=state:GetAttribute("LastResultPractice")==true
  main.Results.Rewards.Text=practice and "PRACTICE ROUND" or (won and "+150 COINS" or "+50 COINS").." · +50 XP"
 end
 if not playing() then if sprintHeld or fireHeld then release() end else sprintChange() end
end
connect(controls.Mud.Activated,function() equip("MudGun") end)
connect(controls.Heat.Activated,function() equip("HeatGun") end)
connect(controls.Sprint.InputBegan,function(input)
 if playing() and focused and not palette.Visible and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then sprintTouch=input sprintChange() end
end)
connect(controls.Fire.InputBegan,function(input)
 if playing() and focused and not palette.Visible and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then fireTouch=input fireHeld=true lastShot=0 end
end)
connect(UserInputService.InputEnded,function(input)
 if input==sprintTouch then sprintTouch=nil end
 if input==fireTouch then fireTouch=nil fireHeld=false call("Heat",false,nil,true) end
 if input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift then sprintKeys[input.KeyCode]=nil end
 sprintChange()
end)
connect(UserInputService.InputChanged,function(input)
 if input.UserInputState==Enum.UserInputState.Cancel and (input==sprintTouch or input==fireTouch) then release() end
end)
connect(UserInputService.WindowFocusReleased,function() focused=false release() end)
connect(UserInputService.WindowFocused,function() focused=true end)
connect(UserInputService.TextBoxFocused,release)
connect(gui.ColourToggle.Activated,function() palette.Visible=not palette.Visible release() end)
connect(main.Top.Team.Activated,function() palette.Visible=not palette.Visible release() end)
connect(palette.Close.Activated,function() palette.Visible=false release() end)
connect(palette:GetPropertyChangedSignal("Visible"),function() if palette.Visible then release() end end)
for _,name in ipairs({"Red","Blue","Green","Black"}) do connect(palette[name].Activated,function() call("ChooseColor",name) end) end
connect(player.CharacterAdded,bindTools)
connect(player.CharacterRemoving,function() bindTools(nil) end)
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if player.Character~=character then bindTools(player.Character) end
 if elapsed>=0.05 then elapsed=0 refresh() end
 if sprintHeld and os.clock()-lastSprint>=0.3 then lastSprint=os.clock() call("Sprint",true,nil,true) end
 if fireHeld and playing() and not palette.Visible then
  local direction=aimDirection()
  if direction then
   if player:GetAttribute("MDTool")=="HeatGun" then
    if os.clock()-lastHeat>=0.25 then lastHeat=os.clock() call("Heat",true,direction,true) end
   elseif os.clock()-lastShot>=0.7 then lastShot=os.clock() call("Fire",direction,nil,true) end
  end
 end
end)
connect(script.Destroying,function()
 release()
 if binding then ContextActionService:UnbindAction("MudControls") end
 for _,connection in ipairs(connections) do connection:Disconnect() end
 for _,connection in ipairs(toolConnections) do connection:Disconnect() end
end)
bindTools(player.Character)
refresh()
]====],after=[====[
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local HttpService=game:GetService("HttpService")
local GuiService=game:GetService("GuiService")
local player=Players.LocalPlayer
local gui=script.Parent
local main=gui:WaitForChild("Main")
main.Visible=false
local controls=UserInputService.TouchEnabled and main.Controls or (main:FindFirstChild("DesktopControls") or main.Controls)
local state=ReplicatedStorage:WaitForChild("MudState")
local remote=ReplicatedStorage:WaitForChild("MudActionRequest")
local focused=true
local sprintKeys={}
local sprintTouch
local fireTouch
local fireHeld=false
local sprintHeld=false
local binding=false
local lastSprint=0
local lastHeat=0
local lastShot=0
local elapsed=0
local message=""
local messageUntil=0
local palette=gui.ColourPicker
local connections={}
local toolConnections={}
local character
local sending={}
local pending={}

local function connect(signal,callback) table.insert(connections,signal:Connect(callback)) end
local function refreshArtwork(button,value)
 local artwork=button:FindFirstChild("UserArtwork")
 local textless=button:FindFirstChild("TextlessSkin")
 local live=button:FindFirstChild("LiveCaption")
 if artwork and not artwork.IsLoaded then
  artwork.Visible=true
  if textless then textless.Visible=false end
  if live then live.Visible=false end
  return
 end
 local authored=button:GetAttribute("ArtworkText")
 local showLive=not artwork or authored==nil or value~=authored
 if artwork then artwork.Visible=not showLive end
 if textless then textless.Visible=showLive end
 if live then live.Visible=showLive end
end
local function caption(button,value)
 button.Text=value
 local live=button:FindFirstChild("LiveCaption")
 if live then live.Text=value end
 refreshArtwork(button,value)
end
local function playing()
 return player:GetAttribute("MDParticipating")==true and state:GetAttribute("Phase")=="Playing" and player:GetAttribute("MDMuddy")~=true and player:GetAttribute("MDEliminated")~=true
end
local function call(action,value,aim,quiet)
 pending[action]={value=value,aim=aim,quiet=quiet}
 if sending[action] then return end
 sending[action]=true
 task.spawn(function()
  while pending[action] do
   local request=pending[action] pending[action]=nil
   local ok,result=pcall(function() return remote:InvokeServer(action,request.value,request.aim) end)
   if not request.quiet and (not ok or typeof(result)=="table" and result.ok==false) then
    message=ok and tostring(result.message or "Try again.") or "Try again."
    messageUntil=workspace:GetServerTimeNow()+1.4
   end
   if action=="ChooseColor" then palette.Message.Text=ok and result and result.message or "Try again." end
  end
  sending[action]=nil
 end)
end
local function release()
 table.clear(sprintKeys) sprintTouch=nil fireTouch=nil fireHeld=false
 sprintHeld=false
 call("Sprint",false,nil,true)
 call("Heat",false,nil,true)
end
local function sprintChange()
 local held=focused and playing() and not palette.Visible and (next(sprintKeys)~=nil or sprintTouch~=nil)
 if held~=sprintHeld then sprintHeld=held lastSprint=os.clock() call("Sprint",held,nil,true) end
end
local function equip(name)
 if palette.Visible or not player:GetAttribute("MDParticipating") or player:GetAttribute("MDMuddy") or player:GetAttribute("MDEliminated") then return end
 call("Heat",false,nil,true)
 fireHeld=false
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local backpack=player:FindFirstChildOfClass("Backpack")
 local tool=character and character:FindFirstChild(name) or backpack and backpack:FindFirstChild(name)
 if humanoid and tool and tool:IsA("Tool") then humanoid:EquipTool(tool) end
end
local function keys(_,phase,input)
 if not player:GetAttribute("MDParticipating") then return Enum.ContextActionResult.Pass end
 if phase==Enum.UserInputState.End or phase==Enum.UserInputState.Cancel then
  sprintKeys[input.KeyCode]=nil sprintChange()
 elseif phase==Enum.UserInputState.Begin then
  if not focused or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
  sprintKeys[input.KeyCode]=true sprintChange()
 end
 return Enum.ContextActionResult.Sink
end
local function aimViewportPoint(camera)
 local deviceArea=GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
 local point=camera.ViewportSize*0.5
 if UserInputService.PreferredInput==Enum.PreferredInput.KeyboardAndMouse and UserInputService.MouseBehavior~=Enum.MouseBehavior.LockCenter then
  local fullArea=GuiService:GetInsetArea(Enum.ScreenInsets.None)
  point=UserInputService:GetMouseLocation()-(deviceArea.Min-fullArea.Min)
 end
 point=Vector2.new(math.clamp(point.X,0,camera.ViewportSize.X),math.clamp(point.Y,0,camera.ViewportSize.Y))
 return point,point+deviceArea.Min
end
local function updateCrosshair()
 local camera=workspace.CurrentCamera
 if not camera or not main.Crosshair.Visible then return end
 local _,screenPoint=aimViewportPoint(camera)
 local offset=screenPoint-main.AbsolutePosition
 local size=main.AbsoluteSize
 if size.X>0 and size.Y>0 then main.Crosshair.Position=UDim2.fromScale(offset.X/size.X,offset.Y/size.Y) end
end
local function aimRay()
 local camera=workspace.CurrentCamera
 if not camera then return nil end
 local point=aimViewportPoint(camera)
 local ray=camera:ViewportPointToRay(point.X,point.Y)
 return {cameraOrigin=ray.Origin,cameraDirection=ray.Direction}
end
local function progress(track,fraction)
 fraction=math.clamp(fraction,0,1)
 local gradient=track.Fill.Progress
 if fraction<=0 then gradient.Transparency=NumberSequence.new(1)
 elseif fraction>=1 then gradient.Transparency=NumberSequence.new(0)
 else
  local p=math.clamp(fraction,0.001,0.999)
  gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(p-0.0001,0),NumberSequenceKeypoint.new(p+0.0001,1),NumberSequenceKeypoint.new(1,1)})
 end
end
local function bindTools(newCharacter)
 if newCharacter==character then return end
 release()
 character=newCharacter
 for _,connection in ipairs(toolConnections) do connection:Disconnect() end
 table.clear(toolConnections)
 local hooked={}
 local function bind(tool)
  if not tool:IsA("Tool") or hooked[tool] or (tool.Name~="MudGun" and tool.Name~="HeatGun") then return end
  hooked[tool]=true
  table.insert(toolConnections,tool.Activated:Connect(function()
   if focused and playing() and not palette.Visible then fireHeld=true lastShot=0 end
  end))
  table.insert(toolConnections,tool.Deactivated:Connect(function() fireHeld=false call("Heat",false,nil,true) end))
  table.insert(toolConnections,tool.Unequipped:Connect(function() fireHeld=false call("Heat",false,nil,true) end))
 end
 if character then
  for _,tool in ipairs(character:GetChildren()) do bind(tool) end
  table.insert(toolConnections,character.ChildAdded:Connect(bind))
 end
 local backpack=player:FindFirstChildOfClass("Backpack")
 if backpack then
  for _,tool in ipairs(backpack:GetChildren()) do bind(tool) end
  table.insert(toolConnections,backpack.ChildAdded:Connect(bind))
 end
end
local function refresh()
 local phase=state:GetAttribute("Phase")
 local participating=player:GetAttribute("MDParticipating")==true
 local active=participating and (phase=="Countdown" or phase=="Playing" or phase=="Results")
 local shell=player.PlayerGui:FindFirstChild("PlaygroundShell")
 local compactVote=shell and shell:FindFirstChild("CompactVotePanel")
 local blocked=player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating")
  or shell and (shell.ShopPanel.Visible or shell.VotePanel.Visible or compactVote and compactVote.Visible)
 if palette.Visible and blocked then palette.Visible=false release() end
 main.Visible=active
 gui.ColourToggle.Visible=not participating and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating")
 if participating and not binding then
  ContextActionService:BindActionAtPriority("MudControls",keys,false,3000,Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift)
  binding=true
 elseif not participating and binding then ContextActionService:UnbindAction("MudControls") binding=false release() end
 if not active then return end
 local now=workspace:GetServerTimeNow()
 local remaining=phase=="Countdown" and (state:GetAttribute("RoundDuration") or 300) or math.max(0,(state:GetAttribute("EndsAt") or 0)-now)
 local seconds=math.ceil(remaining)
 main.Top.Timer.Text=string.format("%d:%02d",math.floor(seconds/60),seconds%60)
 main.Top.Visible=phase~="Results"
 main.Countdown.Visible=phase=="Countdown"
 main.Countdown.Text=tostring(state:GetAttribute("CountdownValue") or 3)
 local teamId=player:GetAttribute("MDTeamId") or 0
 local own
 local other
 local ok,teams=pcall(function() return HttpService:JSONDecode(state:GetAttribute("TeamSummaryJSON") or "[]") end)
 if ok and typeof(teams)=="table" then for _,team in ipairs(teams) do if team.teamId==teamId then own=team else other=team end end end
 local color=player:GetAttribute("MDTeamColor") or Color3.fromRGB(42,160,255)
 main.Top.Team.BackgroundColor3=color
 local teamColour=main.Top.Team:FindFirstChild("TeamColour")
 if teamColour then teamColour.BackgroundColor3=color end
 caption(main.Top.Team,string.upper(player:GetAttribute("MDTeamColorName") or "TEAM").."\n"..(own and tostring(own.free).."/"..tostring(own.total).." FREE" or ""))
 main.Top.Other.Text=(state:GetAttribute("TeamCount") or 2)==2 and other and string.upper(other.colorName).."\n"..tostring(other.free).."/"..tostring(other.total).." FREE" or "TEAMS LEFT:\n"..tostring(state:GetAttribute("ActiveTeamCount") or 0)
 local muddy=player:GetAttribute("MDMuddy")==true or player:GetAttribute("MDEliminated")==true
 local showControls=(phase=="Playing" or phase=="Countdown") and not muddy and not palette.Visible
 main.Controls.Visible=controls==main.Controls and showControls
 local desktopControls=main:FindFirstChild("DesktopControls")
 if desktopControls then desktopControls.Visible=controls==desktopControls and showControls end
 controls.Visible=showControls
 controls.Mud.Visible=UserInputService.TouchEnabled
 controls.Heat.Visible=UserInputService.TouchEnabled
 controls.Fire.Visible=UserInputService.TouchEnabled
 main.Frozen.Visible=(phase=="Playing" or phase=="Countdown") and muddy
 main.Crosshair.Visible=focused and playing() and not palette.Visible
 local maximum=math.max(0.1,player:GetAttribute("MDSprintMax") or 10)
 local stamina=math.clamp(player:GetAttribute("MDSprintRemaining") or maximum,0,maximum)
 if player:GetAttribute("MDHeatActive") then
  controls.Meter.Charge.Text=string.format("RESCUING %.1fs / %gs",player:GetAttribute("MDHeatProgress") or 0,state:GetAttribute("RescueSeconds") or 5)
 else controls.Meter.Charge.Text=now<messageUntil and message or string.format("SPRINT %.1fs / %ds",stamina,maximum) end
 progress(controls.Meter.Track,stamina/maximum)
 local sprinting=player:GetAttribute("MDSprinting")
 caption(controls.Sprint,(player:GetAttribute("MDSprintExhausted") and "RECHARGING" or sprinting and "SPRINTING" or "SPRINT").." · "..(UserInputService.TouchEnabled and "HOLD" or "HOLD SHIFT"))
 controls.Sprint.BackgroundColor3=color
 local equipped=player:GetAttribute("MDTool") or ""
 controls.Mud.Outline.Color=equipped=="MudGun" and Color3.fromRGB(255,205,77) or Color3.fromRGB(24,35,62)
 controls.Heat.Outline.Color=equipped=="HeatGun" and Color3.fromRGB(255,205,77) or Color3.fromRGB(24,35,62)
 controls.Mud.Outline.Enabled=equipped=="MudGun"
 controls.Heat.Outline.Enabled=equipped=="HeatGun"
 caption(controls.Fire,equipped=="HeatGun" and "HEAT\nHOLD" or "SPLAT!")
 local rescueSeconds=math.max(0.1,state:GetAttribute("RescueSeconds") or 5)
 local rescue=math.clamp(player:GetAttribute("MDRescueProgress") or 0,0,rescueSeconds)
 main.Frozen.Title.Text=player:GetAttribute("MDEliminated") and "TEAM ELIMINATED" or "STUCK IN THE MUD!"
 main.Frozen.Status.Text=string.format("TEAMMATE HEAT: %.1f / %gs",rescue,rescueSeconds)
 progress(main.Frozen.RescueTrack,rescue/rescueSeconds)
 main.Results.Visible=phase=="Results"
 if phase=="Results" then
  local won=player:GetAttribute("MDResult")=="Won"
  main.Results.Title.Text=won and "YOUR TEAM WINS!" or "ROUND FINISHED!"
  local reason=state:GetAttribute("ResultReason")
  main.Results.Reason.Text=reason=="TimeoutShared" and "BEST SURVIVING TEAMS SHARE THE WIN" or reason=="Timeout" and "MOST OF THE TEAM STAYED FREE" or reason=="NoActiveTeams" and "EVERY TEAM IS STUCK" or "LAST TEAM STILL FREE"
  local practice=state:GetAttribute("LastResultPractice")==true
  main.Results.Rewards.Text=practice and "PRACTICE ROUND" or (won and "+150 COINS" or "+50 COINS").." · +50 XP"
 end
 if not playing() then if sprintHeld or fireHeld then release() end else sprintChange() end
end
connect(controls.Mud.Activated,function() equip("MudGun") end)
connect(controls.Heat.Activated,function() equip("HeatGun") end)
connect(controls.Sprint.InputBegan,function(input)
 if playing() and focused and not palette.Visible and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then sprintTouch=input sprintChange() end
end)
connect(controls.Fire.InputBegan,function(input)
 if playing() and focused and not palette.Visible and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then fireTouch=input fireHeld=true lastShot=0 end
end)
connect(UserInputService.InputEnded,function(input)
 if input==sprintTouch then sprintTouch=nil end
 if input==fireTouch then fireTouch=nil fireHeld=false call("Heat",false,nil,true) end
 if input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift then sprintKeys[input.KeyCode]=nil end
 sprintChange()
end)
connect(UserInputService.InputChanged,function(input)
 if input.UserInputState==Enum.UserInputState.Cancel and (input==sprintTouch or input==fireTouch) then release() end
end)
connect(UserInputService.WindowFocusReleased,function() focused=false release() end)
connect(UserInputService.WindowFocused,function() focused=true end)
connect(UserInputService.TextBoxFocused,release)
connect(gui.ColourToggle.Activated,function() palette.Visible=not palette.Visible release() end)
connect(main.Top.Team.Activated,function() palette.Visible=not palette.Visible release() end)
connect(palette.Close.Activated,function() palette.Visible=false release() end)
connect(palette:GetPropertyChangedSignal("Visible"),function() if palette.Visible then release() end end)
for _,name in ipairs({"Red","Blue","Green","Black"}) do connect(palette[name].Activated,function() call("ChooseColor",name) end) end
connect(player.CharacterAdded,bindTools)
connect(player.CharacterRemoving,function() bindTools(nil) end)
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if player.Character~=character then bindTools(player.Character) end
 if elapsed>=0.05 then elapsed=0 refresh() end
 if sprintHeld and os.clock()-lastSprint>=0.3 then lastSprint=os.clock() call("Sprint",true,nil,true) end
 if fireHeld and playing() and not palette.Visible then
  local direction=aimRay()
  if direction then
   if player:GetAttribute("MDTool")=="HeatGun" then
    if os.clock()-lastHeat>=0.25 then lastHeat=os.clock() call("Heat",true,direction,true) end
   elseif os.clock()-lastShot>=0.7 then lastShot=os.clock() call("Fire",direction,nil,true) end
  end
 end
end)
RunService:BindToRenderStep("MudAimReticle",Enum.RenderPriority.Camera.Value+1,updateCrosshair)
connect(script.Destroying,function()
 release()
 RunService:UnbindFromRenderStep("MudAimReticle")
 if binding then ContextActionService:UnbindAction("MudControls") end
 for _,connection in ipairs(connections) do connection:Disconnect() end
 for _,connection in ipairs(toolConnections) do connection:Disconnect() end
end)
bindTools(player.Character)
refresh()

]====]},
{path="ServerScriptService.StuckInTheMudService",before=[====[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")
local Service = {}
Service.__index = Service
local runningService
local COLORS = { Runner = Color3.fromRGB(66, 174, 255), Tagger = Color3.fromRGB(255, 105, 119) }
local COLOR_NAMES = { "Red", "Blue", "Green", "Black", "Yellow", "Purple", "Orange", "Teal", "Pink", "Lime", "Lavender", "Brown" }
local TEAM_COLORS = { Red = COLORS.Tagger, Blue = COLORS.Runner, Green = Color3.fromRGB(90, 210, 114), Black = Color3.fromRGB(44, 49, 64), Yellow = Color3.fromRGB(255, 201, 72), Purple = Color3.fromRGB(174, 98, 229), Orange = Color3.fromRGB(255, 156, 77), Teal = Color3.fromRGB(85, 220, 202), Pink = Color3.fromRGB(234, 144, 204), Lime = Color3.fromRGB(179, 215, 91), Lavender = Color3.fromRGB(150, 158, 246), Brown = Color3.fromRGB(166, 111, 77) }
local PREFERENCE_COLORS = { Red = true, Blue = true, Green = true, Black = true }

local function attribute(instance, name, value)
	if instance:GetAttribute(name) ~= value then instance:SetAttribute(name, value) end
end
local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end
local function parts(folder)
	local result = {}
	if folder then for _, child in ipairs(folder:GetChildren()) do if child:IsA("BasePart") then table.insert(result, child) end end end
	table.sort(result, function(a, b) return a.Name < b.Name end)
	return result
end
local function alive(record)
	return record and record.ready and record.character and record.character.Parent and record.root and record.root.Parent and record.humanoid and record.humanoid.Health > 0
end
local function direction(value)
	if typeof(value) ~= "Vector3" or value.X ~= value.X or value.Y ~= value.Y or value.Z ~= value.Z
		or math.abs(value.X) == math.huge or math.abs(value.Y) == math.huge or math.abs(value.Z) == math.huge
		or value.Magnitude < 0.01 or value.Magnitude > 10000 then return nil end
	return value.Unit
end
local function connectedPlayer(value)
	return typeof(value) == "Instance" and value:IsA("Player") and value.Parent == Players
end

function Service.new(arena, state)
	local self = setmetatable({}, Service)
	self.arena = arena
	self.gameplay = arena:WaitForChild("Gameplay")
	self.bounds = self.gameplay:WaitForChild("ArenaBounds")
	self.spawnPads = parts(self.gameplay:WaitForChild("StartPads"))
	self.navNodes = parts(self.gameplay:FindFirstChild("NavigationNodes"))
	self.teamSpawns = {}
	local groups = self.gameplay:FindFirstChild("TeamSpawns")
	if groups then
		for _, group in ipairs(groups:GetChildren()) do if group:IsA("Folder") then table.insert(self.teamSpawns, group) end end
		table.sort(self.teamSpawns, function(a, b) return a.Name < b.Name end)
	end
	assert(#self.spawnPads > 0, "Mud needs StartPads")
	self.records, self.connections, self.projectiles, self.eliminatedTeams = {}, {}, {}, {}
	self.teamColors, self.originalTeamSizes, self.roundRoster = {}, {}, {}
	self.random = Random.new()
	self.active, self.running, self.phase, self.mode = false, false, "Waiting", "Waiting"
	self.endsAt, self.roundNumber, self.tickAccumulator, self.teamCount = 0, 0, 0, 2
	self.state = state or ReplicatedStorage:FindFirstChild("MudState")
	if not self.state then self.state = Instance.new("Folder") self.state.Name = "MudState" self.state.Parent = ReplicatedStorage end
	for _, object in ipairs(workspace:GetDescendants()) do
		if object:IsA("SpawnLocation") and not object:IsDescendantOf(arena) then self.lobbySpawn = object break end
	end
	return self
end

function Service:_setting(name, fallback, minimum)
	local value = self.arena:GetAttribute(name)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.max(minimum or 0, value)
end

function Service:_phase(value)
	self.phase = value
	attribute(self.state, "Phase", value)
end

function Service.TeamAssignments(count, requested, maximum)
	if count < 2 then return {}, 0 end
	local teamCount = math.clamp(math.max(math.floor(requested), math.ceil(count / math.max(2, math.floor(maximum)))), 2, math.min(count, #COLOR_NAMES))
	local result = {}
	for index = 1, count do result[index] = (index - 1) % teamCount + 1 end
	return result, teamCount
end

function Service:_chooseTeamColors()
	local used = {}
	self.teamColors = {}
	for team = 1, self.teamCount do
		local counts = {}
		for _, record in pairs(self.records) do
			if record.participating and record.teamId == team then
				local preference = record.player:GetAttribute("MDColorPreference")
				if PREFERENCE_COLORS[preference] then counts[preference] = (counts[preference] or 0) + 1 end
			end
		end
		local choice, votes
		for _, name in ipairs(COLOR_NAMES) do
			if not used[name] and (not votes or (counts[name] or 0) > votes) then choice, votes = name, counts[name] or 0 end
		end
		self.teamColors[team], used[choice] = choice, true
	end
end

function Service:_colorName(team)
	return self.teamColors[team] or COLOR_NAMES[(math.max(team or 1, 1) - 1) % #COLOR_NAMES + 1]
end

function Service.ChooseTimeoutTeams(active, free, original)
	local best, winners = -1, {}
	for _, team in ipairs(active) do
		local amount = free[team] or 0
		if amount > 0 then
			local score = amount / math.max(original[team] or 0, 1)
			if score > best + 0.000001 then best, winners = score, { team }
			elseif math.abs(score - best) <= 0.000001 then table.insert(winners, team) end
		end
	end
	table.sort(winners)
	return winners
end

function Service:_timeoutWinners()
	local active, _, free = self:_teams(true)
	return Service.ChooseTimeoutTeams(active, free, self.originalTeamSizes)
end

function Service:_spawn(index, team)
	team = typeof(team) == "number" and team or 1
	local pads = self.spawnPads
	if #self.teamSpawns > 0 then
		local groupIndex = math.floor((team - 1) * #self.teamSpawns / math.max(self.teamCount, 1)) + 1
		local choices = parts(self.teamSpawns[math.clamp(groupIndex, 1, #self.teamSpawns)])
		if #choices > 0 then pads = choices end
	end
	local position = pads[(index - 1) % #pads + 1].Position
	local target = Vector3.new(self.bounds.Position.X, position.Y, self.bounds.Position.Z)
	if (target - position).Magnitude < 1 then target = position + Vector3.new(0, 0, -1) end
	return CFrame.lookAt(position, target)
end

function Service:_teleport(record, cframe)
	if not record.root or not record.root.Parent or not record.character then return end
	self:_clearHeat(record, true)
	record.character:PivotTo(cframe * record.root.CFrame:Inverse() * record.character:GetPivot())
	record.root.AssemblyLinearVelocity, record.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	if record.frozen then record.lockedCFrame = record.root.CFrame end
end

function Service:_publishRecord(record)
	attribute(record.player, "MDParticipating", record.participating)
	attribute(record.player, "MDTeamId", record.teamId or 0)
	local colorName = record.participating and self:_colorName(record.teamId) or ""
	attribute(record.player, "MDTeamColorName", colorName)
	attribute(record.player, "MDTeamColor", TEAM_COLORS[colorName] or Color3.fromRGB(255, 255, 255))
	attribute(record.player, "MDTeamName", colorName ~= "" and colorName .. " Team" or "")
	attribute(record.player, "MDMuddy", record.muddy == true)
	attribute(record.player, "MDEliminated", record.eliminated == true)
	attribute(record.player, "MDRescueProgress", record.rescueProgress or 0)
	attribute(record.player, "MDSprintMax", record.sprintMax or 0)
	attribute(record.player, "MDSprintRemaining", math.floor((record.sprintRemaining or 0) * 10) / 10)
	attribute(record.player, "MDSprinting", record.sprinting == true)
	attribute(record.player, "MDSprintExhausted", record.sprintExhausted == true)
	attribute(record.player, "MDFireReadyAt", record.fireReadyAt or 0)
	attribute(record.player, "MDHeatActive", record.heatTarget ~= nil)
	attribute(record.player, "MDHeatTargetUserId", record.heatTarget and (record.heatTarget.player.UserId or 0) or 0)
	attribute(record.player, "MDHeatProgress", record.heatProgress or 0)
	local tool = record.participating and record.character and record.character:FindFirstChildOfClass("Tool")
	attribute(record.player, "MDTool", tool and tool:GetAttribute("MDManaged") and tool.Name or "")
end

function Service:_collision(record, part)
	if not record.participating or not part:IsA("BasePart") then return end
	if not record.originalGroups[part] then record.originalGroups[part] = part.CollisionGroup end
	part.CollisionGroup = "MudPlayer"
end

function Service:_mudVisual(record)
	local coating = record.character:FindFirstChild("MDMudCoating")
	if not record.muddy then if coating then coating:Destroy() end return end
	if coating then return end
	coating = Instance.new("Folder") coating.Name = "MDMudCoating" coating.Parent = record.character
	for index, name in ipairs({ "Head", "UpperTorso", "LowerTorso", "Torso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
		local body = record.character:FindFirstChild(name)
		if body and body:IsA("BasePart") then
			local patch = Instance.new("Part") patch.Name = name == "Head" and "MudFaceMask" or "MudPatch"
			patch.Shape = Enum.PartType.Ball
			patch.Size = Vector3.new(math.max(0.3, body.Size.X * (name == "Head" and 0.75 or 0.7)), math.max(0.2, body.Size.Y * (name == "Head" and 0.3 or 0.37)), 0.18)
			patch.CFrame = body.CFrame * CFrame.new(name == "Head" and 0 or body.Size.X * (index % 2 == 0 and 0.1 or -0.1), body.Size.Y * (name == "Head" and -0.22 or -0.08), -body.Size.Z / 2 - 0.015)
			patch.Material = Enum.Material.SmoothPlastic patch.Color = index % 2 == 0 and Color3.fromRGB(114, 73, 43) or Color3.fromRGB(143, 95, 59)
			patch.Anchored, patch.Massless, patch.CanCollide, patch.CanTouch, patch.CanQuery = false, true, false, false, false
			patch.Parent = coating
			local weld = Instance.new("WeldConstraint") weld.Name = "MudWeld" weld.Part0, weld.Part1 = body, patch weld.Parent = patch
		end
	end
end

function Service:_role(record)
	self:_publishRecord(record)
	if not record.character or not record.character.Parent then return end
	for _, part in ipairs(record.character:GetDescendants()) do self:_collision(record, part) end
	if record.participating then
		local outline = record.character:FindFirstChild("MDOutline")
		if not outline then
			outline = Instance.new("Highlight") outline.Name = "MDOutline" outline.Adornee = record.character
			outline.FillTransparency = 1 outline.OutlineTransparency = 0 outline.DepthMode = Enum.HighlightDepthMode.Occluded outline.Parent = record.character
		end
		outline.OutlineColor = TEAM_COLORS[self:_colorName(record.teamId)]
		outline.FillColor = Color3.fromRGB(124, 83, 54)
		outline.FillTransparency = record.muddy and 0.55 or 1
		self:_mudVisual(record)
		local label = record.character:FindFirstChild("MDMuddyLabel")
		local assets = ReplicatedStorage:FindFirstChild("MudAssets")
		local template = assets and assets:FindFirstChild("MuddyTemplate")
		if record.muddy and not label and template then label = template:Clone() label.Name = "MDMuddyLabel" label.Adornee = record.character:FindFirstChild("Head") or record.root label.Enabled = true label.Parent = record.character
		elseif not record.muddy and label then label:Destroy() end
		local torso = record.isBot and record.character:FindFirstChild("Torso")
		if torso then torso.Color = record.muddy and Color3.fromRGB(124, 83, 54) or outline.OutlineColor end
	end
end

function Service:_movement(record)
	if not record.participating or not alive(record) then return end
	local humanoid = record.humanoid
	if not record.originalMovement then record.originalMovement = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight, AutoRotate = humanoid.AutoRotate } end
	local multiplier = not record.frozen and record.sprinting and not record.sprintExhausted and (record.sprintRemaining or 0) > 0 and workspace:GetServerTimeNow() < (record.sprintLeaseEndsAt or 0) and self:_setting("SprintMultiplier", 2.5, 1) or 1
	humanoid.WalkSpeed = record.frozen and 0 or self:_setting("BaseSpeed", 16, 0) * multiplier
	humanoid.JumpPower = record.frozen and 0 or record.originalMovement.JumpPower
	humanoid.JumpHeight = record.frozen and 0 or record.originalMovement.JumpHeight
	humanoid.AutoRotate = not record.frozen and record.originalMovement.AutoRotate
	if record.frozen then
		record.lockedCFrame = record.lockedCFrame or record.root.CFrame
		humanoid.Jump = false
		pcall(function() record.root:SetNetworkOwner(nil) end)
	elseif not record.isBot then pcall(function() record.root:SetNetworkOwnershipAuto() end) end
end

function Service:_freeze(record, frozen)
	record.frozen = frozen
	if frozen then record.sprintHeld = false record.sprinting = false self:_clearHeat(record, true) else record.lockedCFrame = nil end
	self:_movement(record)
end

local function managedGun(tool)
	return tool:IsA("Tool") and (tool.Name == "MudGun" or tool.Name == "HeatGun")
		and (tool:GetAttribute("MDManaged") == true or tool:GetAttribute("ManagedMudTemplate") == true)
end

function Service:_toolsAllowed(record)
	return not record.isBot and self.active and record.participating and alive(record)
		and record.player.Character == record.character
		and not record.player:GetAttribute("BBParticipating") and not record.player:GetAttribute("TGParticipating")
end

function Service:_destroyTools(record)
	if record.isBot then return end
	for _, tool in ipairs(record.managedTools or {}) do if tool.Parent then tool:Destroy() end end
	record.managedTools = {}
	local containers = { record.character, record.player.Character, record.player:FindFirstChild("Backpack"), record.player:FindFirstChild("StarterGear") }
	for _, container in pairs(containers) do
		for _, tool in ipairs(container:GetChildren()) do if managedGun(tool) then tool:Destroy() end end
	end
	attribute(record.player, "MDTool", "")
end

function Service:_watchTools(record, container, connections)
	local function validate(tool)
		if not managedGun(tool) then return end
		task.defer(function()
			if not tool.Parent or tool.Parent ~= container then return end
			if container.Name == "StarterGear" or not self:_toolsAllowed(record)
				or tool:GetAttribute("MDRound") ~= self.roundNumber or tool:GetAttribute("MDOwnerUserId") ~= record.player.UserId then
				tool:Destroy()
				self:_publishRecord(record)
			end
		end)
	end
	table.insert(connections, container.ChildAdded:Connect(validate))
	for _, tool in ipairs(container:GetChildren()) do validate(tool) end
end

function Service:_giveTools(record)
	self:_destroyTools(record)
	if not self:_toolsAllowed(record) then return end
	local backpack = record.player:FindFirstChild("Backpack")
	local assets = ReplicatedStorage:FindFirstChild("MudAssets")
	if not backpack or not assets then return end
	record.humanoid:UnequipTools()
	local first
	for _, name in ipairs({ "MudGun", "HeatGun" }) do
		local template = assets:FindFirstChild(name)
		if template and template:IsA("Tool") then
			local tool = template:Clone()
			tool:SetAttribute("MDManaged", true)
			tool:SetAttribute("MDRound", self.roundNumber)
			tool:SetAttribute("MDOwnerUserId", record.player.UserId)
			tool.CanBeDropped = false
			table.insert(record.managedTools, tool)
			tool.Parent = backpack
			if name == "MudGun" then first = tool end
		end
	end
	if first then record.humanoid:EquipTool(first) end
end

function Service:_restore(record)
	self:_clearHeat(record, true)
	record.sprintHeld, record.sprinting = false, false
	if record.originalMovement and record.humanoid and record.humanoid.Parent then for name, value in pairs(record.originalMovement) do record.humanoid[name] = value end end
	record.originalMovement, record.frozen, record.lockedCFrame = nil, false, nil
	for part, group in pairs(record.originalGroups) do if part.Parent then pcall(function() part.CollisionGroup = group end) end end
	table.clear(record.originalGroups)
	if record.character then for _, name in ipairs({ "MDOutline", "MDMuddyLabel", "MDMudCoating" }) do local object = record.character:FindFirstChild(name) if object then object:Destroy() end end end
	self:_destroyTools(record)
	if record.root and record.root.Parent and not record.isBot then pcall(function() record.root:SetNetworkOwnershipAuto() end) end
end

function Service:_record(player, isBot)
	local record = { player = player, isBot = isBot, role = "Runner", ready = false, participating = false,
		teamId = 0, muddy = false, eliminated = false, originalGroups = {}, connections = {}, characterConnections = {},
		spawnIndex = 1, rescueProgress = 0, sprintMax = 0, sprintRemaining = 0, fireReadyAt = 0, requests = {}, managedTools = {} }
	self.records[player] = record self:_publishRecord(record)
	return record
end

function Service:_setupCharacter(record, character)
	if self.records[record.player] ~= record or record.player.Character ~= character then return end
	record.generation = (record.generation or 0) + 1
	local generation = record.generation
	disconnect(record.characterConnections) self:_restore(record)
	record.character, record.root, record.humanoid, record.ready = character, nil, nil, false
	local humanoid, root = character:WaitForChild("Humanoid", 10), character:WaitForChild("HumanoidRootPart", 10)
	if self.records[record.player] ~= record or record.generation ~= generation or record.player.Character ~= character or not character.Parent or not humanoid or not root then return end
	record.humanoid, record.root, record.ready = humanoid, root, true
	table.insert(record.characterConnections, character.DescendantAdded:Connect(function(part) self:_collision(record, part) end))
	self:_watchTools(record, character, record.characterConnections)
	table.insert(record.characterConnections, humanoid.Died:Connect(function()
		if record.participating then self:_stick(record, nil) end
		record.ready = false
		self:_destroyTools(record)
	end))
	if record.participating then
		self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.teamId))
		self:_freeze(record, record.muddy or record.eliminated or self.phase ~= "Playing") self:_giveTools(record) self:_role(record)
	end
end

function Service:_addPlayer(player)
	if self.records[player] then return end
	local record = self:_record(player, false)
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) task.spawn(function() self:_setupCharacter(record, character) end) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if record.character == character then
			if record.participating then self:_stick(record, nil) end
			record.ready = false
			self:_destroyTools(record)
		end
	end))
	local function watchContainer(container)
		if container:IsA("Backpack") or container.Name == "StarterGear" then self:_watchTools(record, container, record.connections) end
	end
	table.insert(record.connections, player.ChildAdded:Connect(watchContainer))
	for _, container in ipairs(player:GetChildren()) do watchContainer(container) end
	for _, name in ipairs({ "BBParticipating", "TGParticipating" }) do
		table.insert(record.connections, player:GetAttributeChangedSignal(name):Connect(function()
			if player:GetAttribute(name) then self:_destroyTools(record) end
		end))
	end
	self:_destroyTools(record)
	if player.Character then task.spawn(function() self:_setupCharacter(record, player.Character) end) end
end

function Service:_removePlayer(player)
	local record = self.records[player] if not record then return end
	record.participating = false self:_restore(record) disconnect(record.connections) disconnect(record.characterConnections) self.records[player] = nil
	if self.practiceOwner == player then self:StopRound() else self:_teams(true) end
end

function Service:_readyPlayers(selected)
	local result, included = {}, {}
	for _, player in ipairs(selected or Players:GetPlayers()) do
		local record = self.records[player]
		if record and not record.isBot and not included[player] and connectedPlayer(player) and alive(record)
			and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating") then included[player] = true table.insert(result, player) end
	end
	table.sort(result, function(a, b) return a.UserId < b.UserId end)
	return result
end

function Service:_teams(mark)
	local totals, free = {}, {}
	for _, record in pairs(self.records) do
		if record.participating and (record.isBot or record.player.Parent == Players) then totals[record.teamId] = (totals[record.teamId] or 0) + 1 if not record.muddy and not record.eliminated then free[record.teamId] = (free[record.teamId] or 0) + 1 end end
	end
	if mark and self.phase == "Playing" and self.pendingWinners == nil then
		for team = 1, self.teamCount do
			if not free[team] and not self.eliminatedTeams[team] then
				self.eliminatedTeams[team] = true
				for _, record in pairs(self.records) do if record.participating and record.teamId == team then record.eliminated = true self:_freeze(record, true) self:_role(record) end end
			end
		end
	end
	local active = {}
	for team, amount in pairs(free) do if amount > 0 and not self.eliminatedTeams[team] then table.insert(active, team) end end
	table.sort(active)
	if mark and self.active and self.phase == "Playing" and self.pendingWinners == nil and #active <= 1 then
		self.pendingWinners = table.clone(active)
		for _, record in pairs(self.records) do if record.participating then self:_freeze(record, true) self:_publishRecord(record) end end
	end
	attribute(self.state, "ActiveTeamCount", #active)
	attribute(self.state, "TeamCount", self.teamCount)
	local participants, muddy = 0, 0
	local summary = {}
	for team = 1, self.teamCount do
		participants += totals[team] or 0 muddy += (totals[team] or 0) - (free[team] or 0)
		attribute(self.state, "Team" .. team .. "Members", totals[team] or 0) attribute(self.state, "Team" .. team .. "Free", free[team] or 0)
		table.insert(summary, { teamId = team, colorName = self:_colorName(team), free = free[team] or 0, total = totals[team] or 0, originalTotal = self.originalTeamSizes[team] or 0, eliminated = self.eliminatedTeams[team] == true })
	end
	attribute(self.state, "TeamSummaryJSON", HttpService:JSONEncode(summary))
	attribute(self.state, "ParticipantCount", participants) attribute(self.state, "MuddyCount", muddy)
	return active, totals, free
end

function Service:_stick(record, shooter)
	if not self.active or self.phase ~= "Playing" or self.pendingWinners ~= nil or not record.participating or record.eliminated or (shooter and shooter.teamId == record.teamId) then return false end
	for _, saver in pairs(self.records) do if saver.heatTarget == record then self:_clearHeat(saver, false) end end
	record.muddy, record.rescueProgress = true, 0
	self:_freeze(record, true) self:_role(record) self:_teams(true)
	return true
end

function Service:_clearHeat(record, release)
	if record.heatTarget then record.heatTarget.rescueProgress = 0 attribute(record.heatTarget.player, "MDRescueProgress", 0) end
	record.heatTarget, record.heatStartedAt, record.heatProgress = nil, nil, 0
	if record.player then attribute(record.player, "MDHeatProgress", 0) attribute(record.player, "MDHeatActive", false) attribute(record.player, "MDHeatTargetUserId", 0) end
	if record.heatBeam then record.heatBeam:Destroy() record.heatBeam = nil end
	if release then record.heatHeld, record.heatDirection, record.heatLeaseEndsAt = false, nil, 0 end
end

function Service:_canAct(record, now)
	return self.active and self.phase == "Playing" and self.pendingWinners == nil and now < self.endsAt and record.participating
		and not record.muddy and not record.eliminated and not record.frozen and alive(record)
end

function Service:_equipped(record, kind)
	if record.isBot then return true end
	if not self:_toolsAllowed(record) then return nil end
	if not record.character then return nil end
	local name = kind == "Mud" and "MudGun" or "HeatGun"
	for _, tool in ipairs(record.character:GetChildren()) do if tool:IsA("Tool") and tool.Name == name and tool:GetAttribute("MDManaged") == true and tool:GetAttribute("MDRound") == self.roundNumber and tool:GetAttribute("MDOwnerUserId") == record.player.UserId and tool:GetAttribute("GunKind") == kind and tool.Enabled == true then return tool end end
	return nil
end

function Service:_rayParameters(source, ignoreCharacters)
	local ignored = { self.bounds }
	for _, name in ipairs({ "StartPads", "TeamSpawns", "NavigationNodes", "CoverVolumes", "RescueAreas", "PracticeSpawns" }) do local folder = self.gameplay:FindFirstChild(name) if folder then table.insert(ignored, folder) end end
	if self.effects then table.insert(ignored, self.effects) end
	if source and source.character then table.insert(ignored, source.character) end
	if ignoreCharacters or not source then for _, record in pairs(self.records) do if record.character then table.insert(ignored, record.character) end end end
	local params = RaycastParams.new() params.FilterType = Enum.RaycastFilterType.Exclude params.FilterDescendantsInstances = ignored params.RespectCanCollide = ignoreCharacters == true or source == nil
	return params
end

function Service:_origin(record, kind, aim)
	local tool = self:_equipped(record, kind)
	if not tool then return nil end
	local origin = (record.character:FindFirstChild("Head") or record.root).Position + aim * 1.5
	if not record.isBot then
		local handle = tool:FindFirstChild("Handle") local muzzle = handle and handle:FindFirstChild("MuzzleAttachment")
		if not muzzle or not muzzle:IsA("Attachment") or (muzzle.WorldPosition - record.root.Position).Magnitude > 8 then return nil end
		origin = muzzle.WorldPosition
	end
	if workspace:Raycast(record.root.Position, origin - record.root.Position, self:_rayParameters(record, true)) then return nil end
	return origin
end

function Service:_hitRecord(part)
	for _, record in pairs(self.records) do if record.participating and record.character and part:IsDescendantOf(record.character) then return record end end
	return nil
end

function Service:_effects()
	if not self.effects then self.effects = Instance.new("Folder") self.effects.Name = "MudRoundEffects" self.effects.Parent = workspace end
	return self.effects
end

function Service:_fire(record, aim, now)
	if not self:_canAct(record, now) or now < (record.fireReadyAt or 0) then return false end
	local origin = self:_origin(record, "Mud", aim) if not origin then return false end
	local glob = Instance.new("Part") glob.Name = "MudGlob" glob.Shape = Enum.PartType.Ball glob.Size = Vector3.new(1.1, 1.1, 1.1)
	glob.Material = Enum.Material.SmoothPlastic glob.Color = Color3.fromRGB(132, 88, 57) glob.Anchored = true glob.CanCollide = false glob.CanTouch = false glob.CanQuery = false glob.Position = origin glob.Parent = self:_effects()
	table.insert(self.projectiles, { part = glob, position = origin, direction = aim, speed = self:_setting("ProjectileSpeed", 115, 1), remaining = self:_setting("MudRange", 130, 1), source = record, teamId = record.teamId, token = self.currentRound })
	record.fireReadyAt = now + self:_setting("MudCooldownSeconds", 0.65, 0.1) self:_publishRecord(record)
	return true
end

function Service:_tickProjectiles(dt)
	for index = #self.projectiles, 1, -1 do
		local shot = self.projectiles[index]
		local remove = shot.token ~= self.currentRound or self.phase ~= "Playing" or not self.active or self.pendingWinners ~= nil
		if not remove then
			local length = math.min(shot.remaining, shot.speed * dt)
			local vector = shot.direction * length
			local hit = workspace:Raycast(shot.position, vector, self:_rayParameters(shot.source, false))
			if hit then local target = self:_hitRecord(hit.Instance) if target and target.teamId ~= shot.teamId then self:_stick(target, shot.source) end remove = true
			else shot.position += vector shot.remaining -= length shot.part.Position = shot.position remove = shot.remaining <= 0 end
		end
		if remove then shot.part:Destroy() table.remove(self.projectiles, index) end
	end
end

function Service:_heatTarget(record, now)
	if not self:_canAct(record, now) or not record.heatHeld or now >= (record.heatLeaseEndsAt or 0) or not record.heatDirection then return nil end
	local origin = self:_origin(record, "Heat", record.heatDirection) if not origin then return nil end
	local hit = workspace:Raycast(origin, record.heatDirection * self:_setting("HeatRange", 24, 1), self:_rayParameters(record, false))
	local target = hit and self:_hitRecord(hit.Instance)
	if not target or target == record or target.teamId ~= record.teamId or not target.muddy or target.eliminated or not alive(target) then return nil end
	if (target.root.Position - record.root.Position).Magnitude > self:_setting("HeatRange", 24, 1) + 2 then return nil end
	return target, origin, hit.Position
end

function Service:_tickHeat(now)
	for _, record in pairs(self.records) do if record.participating then record.rescueProgress = 0 end end
	local progress = {}
	for _, saver in pairs(self.records) do
		local target, origin, finish = self:_heatTarget(saver, now)
		if not target then self:_clearHeat(saver, false)
		else
			if saver.heatTarget ~= target then self:_clearHeat(saver, false) saver.heatTarget, saver.heatStartedAt = target, now end
			local elapsed = math.max(0, now - saver.heatStartedAt)
			saver.heatProgress = math.min(self:_setting("RescueSeconds", 5, 0.1), elapsed)
			progress[target] = math.max(progress[target] or 0, saver.heatProgress)
			if not saver.heatBeam then local beam = Instance.new("Part") beam.Name = "HeatBeam" beam.Anchored = true beam.CanCollide = false beam.CanTouch = false beam.CanQuery = false beam.Material = Enum.Material.Neon beam.Color = Color3.fromRGB(255, 184, 71) beam.Parent = self:_effects() saver.heatBeam = beam end
			saver.heatBeam.Size = Vector3.new(0.3, 0.3, (finish - origin).Magnitude) saver.heatBeam.CFrame = CFrame.lookAt((origin + finish) / 2, finish)
			if elapsed >= self:_setting("RescueSeconds", 5, 0.1) then target.muddy, target.rescueProgress = false, 0 self:_freeze(target, false) self:_role(target) self:_clearHeat(saver, false) end
		end
	end
	for _, record in pairs(self.records) do if record.participating then record.rescueProgress = record.muddy and (progress[record] or 0) or 0 self:_publishRecord(record) end end
end

function Service:_tickSprint(record, dt, now)
	if not record.participating then return end
	if now >= (record.sprintLeaseEndsAt or 0) or not self:_canAct(record, now) then record.sprintHeld = false end
	local speed = alive(record) and Vector3.new(record.root.AssemblyLinearVelocity.X, 0, record.root.AssemblyLinearVelocity.Z).Magnitude or 0
	record.sprinting = record.sprintHeld and not record.sprintExhausted and record.sprintRemaining > 0 and speed > 1
	if record.sprinting then record.sprintRemaining = math.max(0, record.sprintRemaining - dt) if record.sprintRemaining == 0 then record.sprintExhausted, record.sprinting = true, false end
	else record.sprintRemaining = math.min(record.sprintMax, record.sprintRemaining + record.sprintMax / self:_setting("SprintRefillSeconds", 15, 0.1) * dt) if record.sprintRemaining >= record.sprintMax - 0.0001 then record.sprintRemaining, record.sprintExhausted = record.sprintMax, false end end
	self:_movement(record) self:_publishRecord(record)
end

function Service:_action(record, action, value, aim)
	local player = record.player
	if action == "ChooseColor" then
		if typeof(value) ~= "string" or not PREFERENCE_COLORS[value] then return { ok = false, message = "Choose Red, Blue, Green or Black." } end
		local now = workspace:GetServerTimeNow()
		if now - (record.requests.ChooseColor or -math.huge) < 0.2 then return { ok = false, message = "Slow down." } end
		record.requests.ChooseColor = now
		attribute(player, "MDColorPreference", value)
		if record.participating and self.phase == "Countdown" then
			for team, name in pairs(self.teamColors) do if team ~= record.teamId and name == value then return { ok = true, message = "Saved for the next round; that team color is in use." } end end
			self.teamColors[record.teamId] = value
			for _, teammate in pairs(self.records) do if teammate.participating and teammate.teamId == record.teamId then self:_role(teammate) end end
			self:_teams(false)
		end
		return { ok = true, message = "Color preference saved." }
	end
	if action == "Sprint" and value == false then record.sprintHeld, record.sprinting = false, false if record.participating then self:_movement(record) end self:_publishRecord(record) return { ok = true } end
	if action == "Heat" and value == false then self:_clearHeat(record, true) self:_publishRecord(record) return { ok = true } end
	if typeof(action) ~= "string" or (action ~= "Sprint" and action ~= "Fire" and action ~= "Heat") then return { ok = false, message = "Unknown action." } end
	local now = workspace:GetServerTimeNow()
	if now - (record.requests[action] or -math.huge) < 0.08 then return { ok = false, message = "Slow down." } end
	record.requests[action] = now
	if not self:_canAct(record, now) then return { ok = false, message = "Wait until you can move." } end
	if action == "Sprint" then if value ~= true then return { ok = false, message = "Invalid sprint." } end record.sprintHeld, record.sprintLeaseEndsAt = true, now + 1 self:_movement(record) return { ok = true } end
	local unit = direction(action == "Fire" and value or aim)
	if not unit then return { ok = false, message = "Aim toward the playground." } end
	if action == "Fire" then return { ok = self:_fire(record, unit, now), message = "Mud shot." } end
	if value ~= true or not self:_origin(record, "Heat", unit) then return { ok = false, message = "Equip the Heat Gun." } end
	record.heatHeld, record.heatDirection, record.heatLeaseEndsAt = true, unit, now + 1
	return { ok = true }
end

function Service:Action(player, action, value, aim)
	local record = self.records[player]
	if not connectedPlayer(player) or not record or record.isBot then return { ok = false, message = "Your character is loading." } end
	return self:_action(record, action, value, aim)
end

function Service:_keepLegal(record)
	local point = self.bounds.CFrame:PointToObjectSpace(record.root.Position) local half = self.bounds.Size / 2
	local floor = self:_setting("FloorY", self.spawnPads[1].Position.Y - 3.5, -10000)
	if math.abs(point.X) > half.X - 3 or math.abs(point.Z) > half.Z - 3 or record.root.Position.Y < floor - 7 or math.abs(point.Y) > half.Y then self:_stick(record, nil) self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.teamId))
	elseif record.humanoid.FloorMaterial ~= Enum.Material.Air then record.lastGoodCFrame = record.root.CFrame end
end

function Service:_newBot(index, role)
	if not self.botFolder then
		self.botFolder = Instance.new("Folder")
		self.botFolder.Name = "MudPracticeBots"
		self.botFolder:SetAttribute("MudManaged", true)
		self.botFolder.Parent = workspace
	end
	local attributes = {}
	local player = { DisplayName = role == "Tagger" and "Practice Rival" or "Practice Teammate " .. tostring(index), UserId = -index }
	function player:GetAttribute(name) return attributes[name] end
	function player:SetAttribute(name, value) attributes[name] = value end
	local character = Instance.new("Model")
	character.Name = player.DisplayName
	character:SetAttribute("MDPracticeBot", true)
	local spawn = self:_spawn(index + 1, role == "Tagger" and 2 or 1)
	local function bodyPart(name, size, offset, color, collidable)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = spawn * CFrame.new(offset)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = collidable
		part.CanTouch = false
		part.Parent = character
		return part
	end
	local bodyColor = COLORS[role]
	local skin, navy = Color3.fromRGB(255, 219, 119), Color3.fromRGB(33, 49, 74)
	local root = bodyPart("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero, bodyColor, false)
	root.Transparency = 1
	root.RootPriority = 127
	local torso = bodyPart("Torso", Vector3.new(2, 2, 1), Vector3.zero, bodyColor, true)
	local head = bodyPart("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), skin, false)
	local rightArm = bodyPart("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), skin, false)
	local leftArm = bodyPart("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), skin, false)
	local rightLeg = bodyPart("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), navy, false)
	local leftLeg = bodyPart("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), navy, false)
	local function motor(name, first, second, offset)
		local joint = Instance.new("Motor6D")
		joint.Name = name
		joint.Part0, joint.Part1 = first, second
		joint.C0 = CFrame.new(offset)
		joint.Parent = first
	end
	motor("RootJoint", root, torso, Vector3.zero)
	motor("Neck", torso, head, Vector3.new(0, 1.5, 0))
	motor("Right Shoulder", torso, rightArm, Vector3.new(1.5, 0, 0))
	motor("Left Shoulder", torso, leftArm, Vector3.new(-1.5, 0, 0))
	motor("Right Hip", torso, rightLeg, Vector3.new(0.5, -2, 0))
	motor("Left Hip", torso, leftLeg, Vector3.new(-0.5, -2, 0))
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = player.DisplayName
	humanoid.HipHeight = 0
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = self:_setting("BaseSpeed", 16, 0)
	humanoid.Parent = character
	character.PrimaryPart = root
	player.Character = character
	character.Parent = self.botFolder
	pcall(function() root:SetNetworkOwner(nil) end)
	local record = self:_record(player, true)
	record.character, record.root, record.humanoid, record.ready = character, root, humanoid, true
	record.nextBotMoveAt = 0
	record.nextPathAt = 0
	record.stuckSince = 0
	record.spawnIndex = index + 1
	record.template = character:Clone()
	return player
end

function Service:_respawnBot(record)
	if record.respawning or not record.template or not self.botFolder or not self.active then return end
	record.respawning = true
	self:_restore(record)
	disconnect(record.characterConnections)
	if record.character then record.character:Destroy() end
	local character = record.template:Clone()
	character.Parent = self.botFolder
	record.player.Character = character
	record.character = character
	record.root = character:FindFirstChild("HumanoidRootPart")
	record.humanoid = character:FindFirstChild("Humanoid")
	record.ready = true
	record.route = nil
	record.pathBusy = false
	record.nextPathAt = 0
	record.frozen = record.muddy or record.eliminated or self.phase ~= "Playing"
	self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.teamId))
	pcall(function() record.root:SetNetworkOwner(nil) end)
	self:_freeze(record, record.frozen)
	self:_role(record)
	record.respawning = false
end

function Service:_clearBots()
	local remove = {}
	for player, record in pairs(self.records) do
		if record.isBot then
			disconnect(record.connections)
			disconnect(record.characterConnections)
			if record.template then record.template:Destroy() end
			table.insert(remove, player)
		end
	end
	for _, player in ipairs(remove) do self.records[player] = nil end
	if self.botFolder then self.botFolder:Destroy() self.botFolder = nil end
end

function Service:_fallbackRoute(startPosition, goal)
	local params = self:_rayParameters()
	if not workspace:Raycast(startPosition, goal - startPosition, params) then
		return { { Position = goal, Action = Enum.PathWaypointAction.Walk } }
	end
	local nodes, distances, previous, done = self.navNodes, {}, {}, {}
	local start, finish, startDistance, finishDistance
	for index, node in ipairs(nodes) do
		local first = (node.Position - startPosition).Magnitude
		local second = (node.Position - goal).Magnitude
		if not workspace:Raycast(startPosition, node.Position - startPosition, params) and (not startDistance or first < startDistance) then start, startDistance = index, first end
		if not workspace:Raycast(node.Position, goal - node.Position, params) and (not finishDistance or second < finishDistance) then finish, finishDistance = index, second end
	end
	if not start or not finish then return nil end
	distances[start] = 0
	local byName = {}
	for index, node in ipairs(nodes) do byName[node.Name] = index end
	for _ = 1, #nodes do
		local current, cost
		for index, distance in pairs(distances) do
			if not done[index] and (not cost or distance < cost) then current, cost = index, distance end
		end
		if not current or current == finish then break end
		done[current] = true
		local neighborNames = nodes[current]:GetAttribute("Neighbors") or nodes[current]:GetAttribute("Neighbor") or ""
		for name in string.gmatch(neighborNames, "[^,%s]+") do
			local neighbor = byName[name]
			if neighbor and not done[neighbor] then
				local alternative = cost + (nodes[neighbor].Position - nodes[current].Position).Magnitude
				if not distances[neighbor] or alternative < distances[neighbor] then
					distances[neighbor], previous[neighbor] = alternative, current
				end
			end
		end
	end
	if not distances[finish] then return nil end
	local reversed, current = {}, finish
	while current do
		table.insert(reversed, { Position = nodes[current].Position, Action = Enum.PathWaypointAction.Walk })
		current = previous[current]
	end
	local route = {}
	for index = #reversed, 1, -1 do table.insert(route, reversed[index]) end
	table.insert(route, { Position = goal, Action = Enum.PathWaypointAction.Walk })
	return route
end

function Service:_path(bot, goal, now)
	if bot.pathBusy or now < bot.nextPathAt then return end
	bot.pathBusy = true
	bot.nextPathAt = now + 1.2
	bot.pathGoal = goal
	local token = self.currentRound
	local character = bot.character
	local origin = bot.root.Position
	task.spawn(function()
		local route
		local ok = pcall(function()
			local path = PathfindingService:CreatePath({ AgentRadius = 2.4, AgentHeight = 5.5, AgentCanJump = true, WaypointSpacing = 6 })
			path:ComputeAsync(origin, goal)
			if path.Status == Enum.PathStatus.Success then route = path:GetWaypoints() end
			path:Destroy()
		end)
		if not ok or not route or #route == 0 then route = self:_fallbackRoute(origin, goal) end
		if self.currentRound == token and self.records[bot.player] == bot and bot.character == character then
			bot.route, bot.routeIndex = route, 2
			if route and #route == 1 then bot.routeIndex = 1 end
			bot.pathBusy = false
		end
	end)
end

function Service:_botTarget(bot)
	local teammate, teammateDistance, opponent, opponentDistance
	for _, candidate in pairs(self.records) do
		if candidate ~= bot and candidate.participating and not candidate.eliminated and alive(candidate) then
			local distance = (candidate.root.Position - bot.root.Position).Magnitude
			if candidate.teamId == bot.teamId and candidate.muddy and (not teammateDistance or distance < teammateDistance) then teammate, teammateDistance = candidate, distance
			elseif candidate.teamId ~= bot.teamId and not candidate.muddy and (not opponentDistance or distance < opponentDistance) then opponent, opponentDistance = candidate, distance end
		end
	end
	if teammate then return teammate, true, teammateDistance end
	return opponent, false, opponentDistance
end

function Service:_moveBot(bot, goal, now)
	local direct = not workspace:Raycast(bot.root.Position, goal - bot.root.Position, self:_rayParameters())
	local destination = goal
	if not direct then
		self:_path(bot, goal, now)
		local route, index = bot.route, bot.routeIndex or 1
		while route and route[index] and (route[index].Position - bot.root.Position).Magnitude < 4 do index += 1 end
		bot.routeIndex = index
		local waypoint = route and route[index]
		if waypoint then destination = waypoint.Position if waypoint.Action == Enum.PathWaypointAction.Jump then bot.humanoid.Jump = true end
		else destination = bot.root.Position end
	end
	if bot.previousBotPosition and (bot.root.Position - bot.previousBotPosition).Magnitude < 0.2 and (destination - bot.root.Position).Magnitude > 5 then
		bot.stuckSince += 0.2
		if bot.stuckSince > 0.8 then bot.humanoid.Jump = true bot.nextPathAt = 0 end
	else bot.stuckSince = 0 end
	bot.previousBotPosition = bot.root.Position
	bot.humanoid:MoveTo(destination)
end

function Service:_driveBots(now)
	for _, bot in pairs(self.records) do
		if bot.isBot and self:_canAct(bot, now) and now >= bot.nextBotMoveAt then
			bot.nextBotMoveAt = now + 0.2
			local target, rescue, distance = self:_botTarget(bot)
			if target then
				local goal = target.root.Position
				local head = bot.character:FindFirstChild("Head") or bot.root
				local aim = direction(goal - head.Position)
				local heating = false
				if rescue and aim and distance <= self:_setting("HeatRange", 24, 1) - 2 then
					bot.heatHeld, bot.heatDirection, bot.heatLeaseEndsAt = true, aim, now + 1
					heating = self:_heatTarget(bot, now) == target
				end
				if not heating then self:_clearHeat(bot, true) end
				if heating then bot.humanoid:MoveTo(bot.root.Position)
				else
					local direct = not workspace:Raycast(bot.root.Position, goal - bot.root.Position, self:_rayParameters())
					if not rescue and direct and distance < math.min(self:_setting("MudRange", 130, 1) - 10, 80) then
						bot.humanoid:MoveTo(bot.root.Position)
						local interval = self:_setting("BotShotIntervalSeconds", 7, 0.2)
						bot.nextBotShotAt = bot.nextBotShotAt or now + interval * (0.6 + bot.spawnIndex * 0.3)
						if now >= bot.nextBotShotAt then
							local lead = math.min(distance / self:_setting("ProjectileSpeed", 115, 1), 1)
							local predicted = goal + target.root.AssemblyLinearVelocity * lead
							local shotDirection = direction(predicted - head.Position)
							if shotDirection then self:_fire(bot, shotDirection, now) end
							bot.nextBotShotAt = now + interval
						end
					else self:_moveBot(bot, goal, now) end
				end
			else self:_clearHeat(bot, true) bot.humanoid:MoveTo(bot.root.Position) end
		end
	end
end

function Service:_tick(dt)
	if not self.active then return end
	local now = workspace:GetServerTimeNow()
	for _, record in pairs(self.records) do
		if record.participating and record.isBot and not alive(record) then self:_stick(record, nil) self:_respawnBot(record) end
		if record.participating and alive(record) then
			if record.frozen and record.lockedCFrame then if (record.root.Position - record.lockedCFrame.Position).Magnitude > 0.05 then self:_teleport(record, record.lockedCFrame) end record.root.AssemblyLinearVelocity, record.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero record.humanoid:Move(Vector3.zero)
			else self:_keepLegal(record) end
		end
		self:_tickSprint(record, dt, now)
	end
	if self.phase ~= "Playing" or now >= self.endsAt then return end
	self:_driveBots(now) self:_tickProjectiles(dt) self:_tickHeat(now) self:_teams(true)
end

function Service:_valid(token) return self.running and self.active and self.currentRound == token end

function Service:_results(token, winners, reason)
	local winnerSet, winnerIds, participantIds, names = {}, {}, {}, {}
	for _, id in ipairs(winners) do winnerSet[id] = true end
	for _, entry in ipairs(self.roundRoster) do if not entry.isBot then table.insert(participantIds, entry.userId) if winnerSet[entry.teamId] then table.insert(winnerIds, entry.userId) end end end
	for _, record in pairs(self.records) do if record.participating then self:_freeze(record, true) self:_publishRecord(record) local won = winnerSet[record.teamId] == true attribute(record.player, "MDResult", won and "Won" or "Lost") if won then table.insert(names, record.player.DisplayName) end end end
	for _, shot in ipairs(self.projectiles) do shot.part:Destroy() end table.clear(self.projectiles)
	table.sort(winnerIds) table.sort(participantIds) table.sort(names)
	attribute(self.state, "WinnerTeamIds", table.concat(winners, ",")) attribute(self.state, "WinnerTeams", table.concat(winners, ",")) attribute(self.state, "WinnersText", table.concat(names, ", ")) attribute(self.state, "ResultReason", reason)
	attribute(self.state, "LastResultWinnerIds", table.concat(winnerIds, ",")) attribute(self.state, "LastResultParticipantIds", table.concat(participantIds, ",")) attribute(self.state, "LastResultPractice", self.mode ~= "Round") attribute(self.state, "LastResultRound", self.roundNumber)
	self:_phase("Results")
	local untilTime = workspace:GetServerTimeNow() + self:_setting("ResultsSeconds", 7, 0)
	while self:_valid(token) and workspace:GetServerTimeNow() < untilTime do task.wait(0.1) end
end

function Service:_cleanup(token)
	if token and self.currentRound ~= token then return end
	for _, record in pairs(self.records) do self:_destroyTools(record) end
	for _, record in pairs(self.records) do if record.participating then record.participating = false self:_restore(record) record.teamId, record.muddy, record.eliminated, record.rescueProgress, record.sprintMax, record.sprintRemaining = 0, false, false, 0, 0, 0 record.sprintExhausted, record.sprintLeaseEndsAt, record.fireReadyAt = false, 0, 0 self:_publishRecord(record) if not record.isBot and self.lobbySpawn and self.lobbySpawn.Parent then self:_teleport(record, self.lobbySpawn.CFrame + Vector3.new(0, self.lobbySpawn.Size.Y / 2 + 3, 0)) end end end
	self:_clearBots() table.clear(self.projectiles) if self.effects then self.effects:Destroy() self.effects = nil end
	self.active, self.currentRound, self.practiceOwner, self.mode, self.endsAt = false, nil, nil, "Waiting", 0
	self.pendingWinners = nil
	self.eliminatedTeams, self.originalTeamSizes, self.roundRoster = {}, {}, {}
	attribute(self.state, "Mode", "Waiting") attribute(self.state, "EndsAt", 0) attribute(self.state, "PracticeOwnerUserId", 0) attribute(self.state, "CountdownValue", 0) self:_phase("Waiting") self:_teams(false)
end

function Service:_run(participants, token)
	if not self:_valid(token) then return end
	self.roundNumber += 1 self.eliminatedTeams, self.originalTeamSizes, self.roundRoster, self.pendingWinners = {}, {}, {}, nil
	attribute(self.state, "RoundNumber", self.roundNumber) attribute(self.state, "RoundDuration", self:_setting("RoundDuration", 300, 1)) attribute(self.state, "RescueSeconds", self:_setting("RescueSeconds", 5, 0.1)) attribute(self.state, "WinnersText", "") attribute(self.state, "WinnerTeams", "") attribute(self.state, "WinnerTeamIds", "") attribute(self.state, "ResultReason", "")
	local assignments
	if token.teams then assignments, self.teamCount = token.teams, 2 else assignments, self.teamCount = Service.TeamAssignments(#participants, self:_setting("TeamCount", 2, 2), self:_setting("MaxTeamSize", 2, 2)) end
	local slots = {}
	for index, player in ipairs(participants) do
		local record = self.records[player]
		if record then
			record.participating, record.teamId, record.muddy, record.eliminated = true, assignments[index], false, false slots[record.teamId] = (slots[record.teamId] or 0) + 1 record.spawnIndex = slots[record.teamId]
			self.originalTeamSizes[record.teamId] = (self.originalTeamSizes[record.teamId] or 0) + 1
			table.insert(self.roundRoster, { userId = player.UserId, teamId = record.teamId, isBot = record.isBot })
			record.sprintMax = self:_setting("SprintSeconds", 10, 0.1) record.sprintRemaining = record.sprintMax record.sprintExhausted, record.sprintHeld, record.fireReadyAt = false, false, 0
			record.rescueProgress, record.lastGoodCFrame, record.requests, record.nextBotShotAt = 0, nil, {}, nil attribute(player, "MDResult", "")
			local spawn = self:_spawn(record.spawnIndex, record.teamId)
			local practice = token.teams and parts(self.gameplay:FindFirstChild("PracticeSpawns"))
			if practice and #practice > 0 then spawn = practice[(index - 1) % #practice + 1].CFrame elseif token.teams then spawn = CFrame.new(self.bounds.Position.X + (record.teamId == 1 and -22 or 22), self.spawnPads[1].Position.Y, self.bounds.Position.Z + (record.spawnIndex - 1) * 17) end
			self:_teleport(record, spawn) self:_freeze(record, true) self:_giveTools(record) self:_role(record)
		end
	end
	self:_chooseTeamColors()
	for _, record in pairs(self.records) do if record.participating then self:_role(record) end end
	self:_teams(false) self:_phase("Countdown")
	for number = math.floor(self:_setting("CountdownSeconds", 3, 1)), 1, -1 do if not self:_valid(token) then return end attribute(self.state, "CountdownValue", number) local untilTime = workspace:GetServerTimeNow() + 1 while self:_valid(token) and workspace:GetServerTimeNow() < untilTime do task.wait(0.05) end end
	if not self:_valid(token) then return end
	self.endsAt = workspace:GetServerTimeNow() + self:_setting("RoundDuration", 300, 1) attribute(self.state, "EndsAt", self.endsAt) attribute(self.state, "CountdownValue", 0) self:_phase("Playing")
	for _, record in pairs(self.records) do if record.participating and self.pendingWinners == nil then if not alive(record) or (record.isBot and record.practiceMedic and self.mode == "PracticeMedic") then self:_stick(record, nil) else self:_freeze(record, false) end end end
	local active = self:_teams(true)
	while self:_valid(token) and self.pendingWinners == nil and workspace:GetServerTimeNow() < self.endsAt do task.wait(0.05) active = self:_teams(true) end
	if self:_valid(token) then
		local reason
		if self.pendingWinners then active = self.pendingWinners reason = #active == 0 and "NoActiveTeams" or "LastTeamStanding"
		else active = self:_timeoutWinners() reason = #active > 1 and "TimeoutShared" or #active == 0 and "NoActiveTeams" or "Timeout" end
		self:_results(token, active, reason) self:_cleanup(token)
	end
end

function Service:_begin(participants, mode, teams, owner)
	self.active, self.mode, self.practiceOwner = true, mode, owner
	local token = { teams = teams } self.currentRound = token
	attribute(self.state, "Mode", mode) attribute(self.state, "PracticeOwnerUserId", owner and owner.UserId or 0)
	task.spawn(function() local ok, failure = xpcall(function() self:_run(participants, token) end, debug.traceback) if not ok then warn("Stuck in the Mud round failed: " .. tostring(failure)) self:_cleanup(token) end end)
	return true
end

function Service:_weaponsReady()
	local ok, ready = pcall(function()
		local assets = ReplicatedStorage:FindFirstChild("MudAssets")
		local mud = assets and assets:FindFirstChild("MudGun")
		local heat = assets and assets:FindFirstChild("HeatGun")
		if not mud or not heat or not mud:IsA("Tool") or not heat:IsA("Tool") then return false end
		local mudEnabled, heatEnabled = mud.Enabled, heat.Enabled
		return mudEnabled == true and heatEnabled == true
	end)
	return ok and ready == true
end

function Service:StartRound(selected)
	if not self.running then return false, "Service is not running" end if self.active then return false, "A round is already running" end
	local ready = self:_weaponsReady() attribute(self.state, "GunAccessReady", ready)
	if not ready then return false, "Mud gun access is awaiting approval." end
	local participants = self:_readyPlayers(selected)
	local minimum = math.clamp(math.floor(self:_setting("MinimumPlayers", 4, 2)), 2, 24)
	local maximum = math.clamp(math.floor(self:_setting("MaxPlayers", 4, 2)), 2, 24)
	if #participants < minimum or maximum < minimum then return false, "At least " .. minimum .. " ready players are needed." end
	for index = #participants, 2, -1 do local other = self.random:NextInteger(1, index) participants[index], participants[other] = participants[other], participants[index] end
	while #participants > maximum do table.remove(participants) end
	return self:_begin(participants, "Round")
end

function Service:StartPractice(player, role)
	if not self.running then return false, "Service is not running" end if self.active then return false, "A round is already running" end
	local ready = self:_weaponsReady() attribute(self.state, "GunAccessReady", ready)
	if not ready then return false, "Mud gun access is awaiting approval." end
	if role ~= "Runner" and role ~= "Tagger" and role ~= "Shooter" and role ~= "Medic" then return false, "Choose Shooter or Medic practice" end
	local record = self.records[player] if not connectedPlayer(player) or not record or record.isBot or not alive(record) or player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") then return false, "Your character is not ready" end
	local participants, teams = { player }, { 1 }
	local ok, failure = xpcall(function() for index = 1, 3 do local bot = self:_newBot(index, index == 1 and "Runner" or "Tagger") table.insert(participants, bot) table.insert(teams, index == 1 and 1 or 2) self.records[bot].practiceMedic = index == 1 end end, debug.traceback)
	if not ok then self:_clearBots() warn(tostring(failure)) return false, "Practice bots could not be created" end
	return self:_begin(participants, "Practice" .. role, teams, player)
end

function Service:StopRound()
	if not self.active then return false, "No round is running" end self.currentRound = nil self:_cleanup() return true
end

function Service:Start(player, role)
	if player then if not self.running then self:Start() end return self:StartPractice(player, role or "Shooter") end
	if self.running then return end self.running, runningService = true, self
	local provider = PhysicsService if pcall(function() workspace:IsCollisionGroupRegistered("MudPlayer") end) then provider = workspace end
	if not provider:IsCollisionGroupRegistered("MudPlayer") then provider:RegisterCollisionGroup("MudPlayer") end provider:CollisionGroupSetCollidable("MudPlayer", "MudPlayer", false)
	for name, value in pairs({ Phase = "Waiting", Mode = "Waiting", GunAccessReady = self:_weaponsReady(), EndsAt = 0, CountdownValue = 0, RoundNumber = 0, RoundDuration = 300, RescueSeconds = 5, ActiveTeamCount = 0, ParticipantCount = 0, MuddyCount = 0, TeamCount = 2, TeamSummaryJSON = "[]", WinnersText = "", WinnerTeams = "", WinnerTeamIds = "", ResultReason = "", LastResultWinnerIds = "", LastResultParticipantIds = "", LastResultPractice = true, LastResultRound = 0, PracticeOwnerUserId = 0 }) do attribute(self.state, name, value) end
	table.insert(self.connections, Players.PlayerAdded:Connect(function(value) self:_addPlayer(value) end)) table.insert(self.connections, Players.PlayerRemoving:Connect(function(value) self:_removePlayer(value) end))
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self.tickAccumulator += dt if self.tickAccumulator >= 0.05 then local elapsed = self.tickAccumulator self.tickAccumulator = 0 self:_tick(math.min(elapsed, 0.25)) end end))
	for _, value in ipairs(Players:GetPlayers()) do self:_addPlayer(value) end
	local remote = ReplicatedStorage:FindFirstChild("MudActionRequest") if remote and remote:IsA("RemoteFunction") then self.remote = remote remote.OnServerInvoke = function(value, action, argument, aim) return self:Action(value, action, argument, aim) end end
end

function Service:Stop()
	self.running, self.currentRound = false, nil disconnect(self.connections) self:_cleanup()
	for _, record in pairs(self.records) do disconnect(record.connections) disconnect(record.characterConnections) end table.clear(self.records)
	if self.remote then self.remote.OnServerInvoke = nil end if runningService == self then runningService = nil end
end

function Service.GetRunningService() return runningService end

return Service
]====],after=[====[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")
local Service = {}
Service.__index = Service
local runningService
local COLORS = { Runner = Color3.fromRGB(66, 174, 255), Tagger = Color3.fromRGB(255, 105, 119) }
local COLOR_NAMES = { "Red", "Blue", "Green", "Black", "Yellow", "Purple", "Orange", "Teal", "Pink", "Lime", "Lavender", "Brown" }
local TEAM_COLORS = { Red = COLORS.Tagger, Blue = COLORS.Runner, Green = Color3.fromRGB(90, 210, 114), Black = Color3.fromRGB(44, 49, 64), Yellow = Color3.fromRGB(255, 201, 72), Purple = Color3.fromRGB(174, 98, 229), Orange = Color3.fromRGB(255, 156, 77), Teal = Color3.fromRGB(85, 220, 202), Pink = Color3.fromRGB(234, 144, 204), Lime = Color3.fromRGB(179, 215, 91), Lavender = Color3.fromRGB(150, 158, 246), Brown = Color3.fromRGB(166, 111, 77) }
local PREFERENCE_COLORS = { Red = true, Blue = true, Green = true, Black = true }

local function attribute(instance, name, value)
	if instance:GetAttribute(name) ~= value then instance:SetAttribute(name, value) end
end
local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end
local function parts(folder)
	local result = {}
	if folder then for _, child in ipairs(folder:GetChildren()) do if child:IsA("BasePart") then table.insert(result, child) end end end
	table.sort(result, function(a, b) return a.Name < b.Name end)
	return result
end
local function alive(record)
	return record and record.ready and record.character and record.character.Parent and record.root and record.root.Parent and record.humanoid and record.humanoid.Health > 0
end
local function direction(value)
	if typeof(value) ~= "Vector3" or value.X ~= value.X or value.Y ~= value.Y or value.Z ~= value.Z
		or math.abs(value.X) == math.huge or math.abs(value.Y) == math.huge or math.abs(value.Z) == math.huge
		or value.Magnitude < 0.01 or value.Magnitude > 10000 then return nil end
	return value.Unit
end
local function connectedPlayer(value)
	return typeof(value) == "Instance" and value:IsA("Player") and value.Parent == Players
end

function Service.new(arena, state)
	local self = setmetatable({}, Service)
	self.arena = arena
	self.gameplay = arena:WaitForChild("Gameplay")
	self.bounds = self.gameplay:WaitForChild("ArenaBounds")
	self.spawnPads = parts(self.gameplay:WaitForChild("StartPads"))
	self.navNodes = parts(self.gameplay:FindFirstChild("NavigationNodes"))
	self.teamSpawns = {}
	local groups = self.gameplay:FindFirstChild("TeamSpawns")
	if groups then
		for _, group in ipairs(groups:GetChildren()) do if group:IsA("Folder") then table.insert(self.teamSpawns, group) end end
		table.sort(self.teamSpawns, function(a, b) return a.Name < b.Name end)
	end
	assert(#self.spawnPads > 0, "Mud needs StartPads")
	self.records, self.connections, self.projectiles, self.eliminatedTeams = {}, {}, {}, {}
	self.teamColors, self.originalTeamSizes, self.roundRoster = {}, {}, {}
	self.random = Random.new()
	self.active, self.running, self.phase, self.mode = false, false, "Waiting", "Waiting"
	self.endsAt, self.roundNumber, self.tickAccumulator, self.teamCount = 0, 0, 0, 2
	self.state = state or ReplicatedStorage:FindFirstChild("MudState")
	if not self.state then self.state = Instance.new("Folder") self.state.Name = "MudState" self.state.Parent = ReplicatedStorage end
	for _, object in ipairs(workspace:GetDescendants()) do
		if object:IsA("SpawnLocation") and not object:IsDescendantOf(arena) then self.lobbySpawn = object break end
	end
	return self
end

function Service:_setting(name, fallback, minimum)
	local value = self.arena:GetAttribute(name)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.max(minimum or 0, value)
end

function Service:_phase(value)
	self.phase = value
	attribute(self.state, "Phase", value)
end

function Service.TeamAssignments(count, requested, maximum)
	if count < 2 then return {}, 0 end
	local teamCount = math.clamp(math.max(math.floor(requested), math.ceil(count / math.max(2, math.floor(maximum)))), 2, math.min(count, #COLOR_NAMES))
	local result = {}
	for index = 1, count do result[index] = (index - 1) % teamCount + 1 end
	return result, teamCount
end

function Service:_chooseTeamColors()
	local used = {}
	self.teamColors = {}
	for team = 1, self.teamCount do
		local counts = {}
		for _, record in pairs(self.records) do
			if record.participating and record.teamId == team then
				local preference = record.player:GetAttribute("MDColorPreference")
				if PREFERENCE_COLORS[preference] then counts[preference] = (counts[preference] or 0) + 1 end
			end
		end
		local choice, votes
		for _, name in ipairs(COLOR_NAMES) do
			if not used[name] and (not votes or (counts[name] or 0) > votes) then choice, votes = name, counts[name] or 0 end
		end
		self.teamColors[team], used[choice] = choice, true
	end
end

function Service:_colorName(team)
	return self.teamColors[team] or COLOR_NAMES[(math.max(team or 1, 1) - 1) % #COLOR_NAMES + 1]
end

function Service.ChooseTimeoutTeams(active, free, original)
	local best, winners = -1, {}
	for _, team in ipairs(active) do
		local amount = free[team] or 0
		if amount > 0 then
			local score = amount / math.max(original[team] or 0, 1)
			if score > best + 0.000001 then best, winners = score, { team }
			elseif math.abs(score - best) <= 0.000001 then table.insert(winners, team) end
		end
	end
	table.sort(winners)
	return winners
end

function Service:_timeoutWinners()
	local active, _, free = self:_teams(true)
	return Service.ChooseTimeoutTeams(active, free, self.originalTeamSizes)
end

function Service:_spawn(index, team)
	team = typeof(team) == "number" and team or 1
	local pads = self.spawnPads
	if #self.teamSpawns > 0 then
		local groupIndex = math.floor((team - 1) * #self.teamSpawns / math.max(self.teamCount, 1)) + 1
		local choices = parts(self.teamSpawns[math.clamp(groupIndex, 1, #self.teamSpawns)])
		if #choices > 0 then pads = choices end
	end
	local position = pads[(index - 1) % #pads + 1].Position
	local target = Vector3.new(self.bounds.Position.X, position.Y, self.bounds.Position.Z)
	if (target - position).Magnitude < 1 then target = position + Vector3.new(0, 0, -1) end
	return CFrame.lookAt(position, target)
end

function Service:_teleport(record, cframe)
	if not record.root or not record.root.Parent or not record.character then return end
	self:_clearHeat(record, true)
	record.character:PivotTo(cframe * record.root.CFrame:Inverse() * record.character:GetPivot())
	record.root.AssemblyLinearVelocity, record.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	if record.frozen then record.lockedCFrame = record.root.CFrame end
end

function Service:_publishRecord(record)
	attribute(record.player, "MDParticipating", record.participating)
	attribute(record.player, "MDTeamId", record.teamId or 0)
	local colorName = record.participating and self:_colorName(record.teamId) or ""
	attribute(record.player, "MDTeamColorName", colorName)
	attribute(record.player, "MDTeamColor", TEAM_COLORS[colorName] or Color3.fromRGB(255, 255, 255))
	attribute(record.player, "MDTeamName", colorName ~= "" and colorName .. " Team" or "")
	attribute(record.player, "MDMuddy", record.muddy == true)
	attribute(record.player, "MDEliminated", record.eliminated == true)
	attribute(record.player, "MDRescueProgress", record.rescueProgress or 0)
	attribute(record.player, "MDSprintMax", record.sprintMax or 0)
	attribute(record.player, "MDSprintRemaining", math.floor((record.sprintRemaining or 0) * 10) / 10)
	attribute(record.player, "MDSprinting", record.sprinting == true)
	attribute(record.player, "MDSprintExhausted", record.sprintExhausted == true)
	attribute(record.player, "MDFireReadyAt", record.fireReadyAt or 0)
	attribute(record.player, "MDHeatActive", record.heatTarget ~= nil)
	attribute(record.player, "MDHeatTargetUserId", record.heatTarget and (record.heatTarget.player.UserId or 0) or 0)
	attribute(record.player, "MDHeatProgress", record.heatProgress or 0)
	local tool = record.participating and record.character and record.character:FindFirstChildOfClass("Tool")
	attribute(record.player, "MDTool", tool and tool:GetAttribute("MDManaged") and tool.Name or "")
end

function Service:_collision(record, part)
	if not record.participating or not part:IsA("BasePart") then return end
	if not record.originalGroups[part] then record.originalGroups[part] = part.CollisionGroup end
	part.CollisionGroup = "MudPlayer"
end

function Service:_mudVisual(record)
	local coating = record.character:FindFirstChild("MDMudCoating")
	if not record.muddy then if coating then coating:Destroy() end return end
	if coating then return end
	coating = Instance.new("Folder") coating.Name = "MDMudCoating" coating.Parent = record.character
	for index, name in ipairs({ "Head", "UpperTorso", "LowerTorso", "Torso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
		local body = record.character:FindFirstChild(name)
		if body and body:IsA("BasePart") then
			local patch = Instance.new("Part") patch.Name = name == "Head" and "MudFaceMask" or "MudPatch"
			patch.Shape = Enum.PartType.Ball
			patch.Size = Vector3.new(math.max(0.3, body.Size.X * (name == "Head" and 0.75 or 0.7)), math.max(0.2, body.Size.Y * (name == "Head" and 0.3 or 0.37)), 0.18)
			patch.CFrame = body.CFrame * CFrame.new(name == "Head" and 0 or body.Size.X * (index % 2 == 0 and 0.1 or -0.1), body.Size.Y * (name == "Head" and -0.22 or -0.08), -body.Size.Z / 2 - 0.015)
			patch.Material = Enum.Material.SmoothPlastic patch.Color = index % 2 == 0 and Color3.fromRGB(114, 73, 43) or Color3.fromRGB(143, 95, 59)
			patch.Anchored, patch.Massless, patch.CanCollide, patch.CanTouch, patch.CanQuery = false, true, false, false, false
			patch.Parent = coating
			local weld = Instance.new("WeldConstraint") weld.Name = "MudWeld" weld.Part0, weld.Part1 = body, patch weld.Parent = patch
		end
	end
end

function Service:_role(record)
	self:_publishRecord(record)
	if not record.character or not record.character.Parent then return end
	for _, part in ipairs(record.character:GetDescendants()) do self:_collision(record, part) end
	if record.participating then
		local outline = record.character:FindFirstChild("MDOutline")
		if not outline then
			outline = Instance.new("Highlight") outline.Name = "MDOutline" outline.Adornee = record.character
			outline.FillTransparency = 1 outline.OutlineTransparency = 0 outline.DepthMode = Enum.HighlightDepthMode.Occluded outline.Parent = record.character
		end
		outline.OutlineColor = TEAM_COLORS[self:_colorName(record.teamId)]
		outline.FillColor = Color3.fromRGB(124, 83, 54)
		outline.FillTransparency = record.muddy and 0.55 or 1
		self:_mudVisual(record)
		local label = record.character:FindFirstChild("MDMuddyLabel")
		local assets = ReplicatedStorage:FindFirstChild("MudAssets")
		local template = assets and assets:FindFirstChild("MuddyTemplate")
		if record.muddy and not label and template then label = template:Clone() label.Name = "MDMuddyLabel" label.Adornee = record.character:FindFirstChild("Head") or record.root label.Enabled = true label.Parent = record.character
		elseif not record.muddy and label then label:Destroy() end
		local torso = record.isBot and record.character:FindFirstChild("Torso")
		if torso then torso.Color = record.muddy and Color3.fromRGB(124, 83, 54) or outline.OutlineColor end
	end
end

function Service:_movement(record)
	if not record.participating or not alive(record) then return end
	local humanoid = record.humanoid
	if not record.originalMovement then record.originalMovement = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight, AutoRotate = humanoid.AutoRotate } end
	local multiplier = not record.frozen and record.sprinting and not record.sprintExhausted and (record.sprintRemaining or 0) > 0 and workspace:GetServerTimeNow() < (record.sprintLeaseEndsAt or 0) and self:_setting("SprintMultiplier", 2.5, 1) or 1
	humanoid.WalkSpeed = record.frozen and 0 or self:_setting("BaseSpeed", 16, 0) * multiplier
	humanoid.JumpPower = record.frozen and 0 or record.originalMovement.JumpPower
	humanoid.JumpHeight = record.frozen and 0 or record.originalMovement.JumpHeight
	humanoid.AutoRotate = not record.frozen and record.originalMovement.AutoRotate
	if record.frozen then
		record.lockedCFrame = record.lockedCFrame or record.root.CFrame
		humanoid.Jump = false
		pcall(function() record.root:SetNetworkOwner(nil) end)
	elseif not record.isBot then pcall(function() record.root:SetNetworkOwnershipAuto() end) end
end

function Service:_freeze(record, frozen)
	record.frozen = frozen
	if frozen then record.sprintHeld = false record.sprinting = false self:_clearHeat(record, true) else record.lockedCFrame = nil end
	self:_movement(record)
end

local function managedGun(tool)
	return tool:IsA("Tool") and (tool.Name == "MudGun" or tool.Name == "HeatGun")
		and (tool:GetAttribute("MDManaged") == true or tool:GetAttribute("ManagedMudTemplate") == true)
end

function Service:_toolsAllowed(record)
	return not record.isBot and self.active and record.participating and alive(record)
		and record.player.Character == record.character
		and not record.player:GetAttribute("BBParticipating") and not record.player:GetAttribute("TGParticipating")
end

function Service:_destroyTools(record)
	if record.isBot then return end
	for _, tool in ipairs(record.managedTools or {}) do if tool.Parent then tool:Destroy() end end
	record.managedTools = {}
	local containers = { record.character, record.player.Character, record.player:FindFirstChild("Backpack"), record.player:FindFirstChild("StarterGear") }
	for _, container in pairs(containers) do
		for _, tool in ipairs(container:GetChildren()) do if managedGun(tool) then tool:Destroy() end end
	end
	attribute(record.player, "MDTool", "")
end

function Service:_watchTools(record, container, connections)
	local function validate(tool)
		if not managedGun(tool) then return end
		task.defer(function()
			if not tool.Parent or tool.Parent ~= container then return end
			if container.Name == "StarterGear" or not self:_toolsAllowed(record)
				or tool:GetAttribute("MDRound") ~= self.roundNumber or tool:GetAttribute("MDOwnerUserId") ~= record.player.UserId then
				tool:Destroy()
				self:_publishRecord(record)
			end
		end)
	end
	table.insert(connections, container.ChildAdded:Connect(validate))
	for _, tool in ipairs(container:GetChildren()) do validate(tool) end
end

function Service:_giveTools(record)
	self:_destroyTools(record)
	if not self:_toolsAllowed(record) then return end
	local backpack = record.player:FindFirstChild("Backpack")
	local assets = ReplicatedStorage:FindFirstChild("MudAssets")
	if not backpack or not assets then return end
	record.humanoid:UnequipTools()
	local first
	for _, name in ipairs({ "MudGun", "HeatGun" }) do
		local template = assets:FindFirstChild(name)
		if template and template:IsA("Tool") then
			local tool = template:Clone()
			tool:SetAttribute("MDManaged", true)
			tool:SetAttribute("MDRound", self.roundNumber)
			tool:SetAttribute("MDOwnerUserId", record.player.UserId)
			tool.CanBeDropped = false
			table.insert(record.managedTools, tool)
			tool.Parent = backpack
			if name == "MudGun" then first = tool end
		end
	end
	if first then record.humanoid:EquipTool(first) end
end

function Service:_restore(record)
	self:_clearHeat(record, true)
	record.sprintHeld, record.sprinting = false, false
	if record.originalMovement and record.humanoid and record.humanoid.Parent then for name, value in pairs(record.originalMovement) do record.humanoid[name] = value end end
	record.originalMovement, record.frozen, record.lockedCFrame = nil, false, nil
	for part, group in pairs(record.originalGroups) do if part.Parent then pcall(function() part.CollisionGroup = group end) end end
	table.clear(record.originalGroups)
	if record.character then for _, name in ipairs({ "MDOutline", "MDMuddyLabel", "MDMudCoating" }) do local object = record.character:FindFirstChild(name) if object then object:Destroy() end end end
	self:_destroyTools(record)
	if record.root and record.root.Parent and not record.isBot then pcall(function() record.root:SetNetworkOwnershipAuto() end) end
end

function Service:_record(player, isBot)
	local record = { player = player, isBot = isBot, role = "Runner", ready = false, participating = false,
		teamId = 0, muddy = false, eliminated = false, originalGroups = {}, connections = {}, characterConnections = {},
		spawnIndex = 1, rescueProgress = 0, sprintMax = 0, sprintRemaining = 0, fireReadyAt = 0, requests = {}, managedTools = {} }
	self.records[player] = record self:_publishRecord(record)
	return record
end

function Service:_setupCharacter(record, character)
	if self.records[record.player] ~= record or record.player.Character ~= character then return end
	record.generation = (record.generation or 0) + 1
	local generation = record.generation
	disconnect(record.characterConnections) self:_restore(record)
	record.character, record.root, record.humanoid, record.ready = character, nil, nil, false
	local humanoid, root = character:WaitForChild("Humanoid", 10), character:WaitForChild("HumanoidRootPart", 10)
	if self.records[record.player] ~= record or record.generation ~= generation or record.player.Character ~= character or not character.Parent or not humanoid or not root then return end
	record.humanoid, record.root, record.ready = humanoid, root, true
	table.insert(record.characterConnections, character.DescendantAdded:Connect(function(part) self:_collision(record, part) end))
	self:_watchTools(record, character, record.characterConnections)
	table.insert(record.characterConnections, humanoid.Died:Connect(function()
		if record.participating then self:_stick(record, nil) end
		record.ready = false
		self:_destroyTools(record)
	end))
	if record.participating then
		self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.teamId))
		self:_freeze(record, record.muddy or record.eliminated or self.phase ~= "Playing") self:_giveTools(record) self:_role(record)
	end
end

function Service:_addPlayer(player)
	if self.records[player] then return end
	local record = self:_record(player, false)
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) task.spawn(function() self:_setupCharacter(record, character) end) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if record.character == character then
			if record.participating then self:_stick(record, nil) end
			record.ready = false
			self:_destroyTools(record)
		end
	end))
	local function watchContainer(container)
		if container:IsA("Backpack") or container.Name == "StarterGear" then self:_watchTools(record, container, record.connections) end
	end
	table.insert(record.connections, player.ChildAdded:Connect(watchContainer))
	for _, container in ipairs(player:GetChildren()) do watchContainer(container) end
	for _, name in ipairs({ "BBParticipating", "TGParticipating" }) do
		table.insert(record.connections, player:GetAttributeChangedSignal(name):Connect(function()
			if player:GetAttribute(name) then self:_destroyTools(record) end
		end))
	end
	self:_destroyTools(record)
	if player.Character then task.spawn(function() self:_setupCharacter(record, player.Character) end) end
end

function Service:_removePlayer(player)
	local record = self.records[player] if not record then return end
	record.participating = false self:_restore(record) disconnect(record.connections) disconnect(record.characterConnections) self.records[player] = nil
	if self.practiceOwner == player then self:StopRound() else self:_teams(true) end
end

function Service:_readyPlayers(selected)
	local result, included = {}, {}
	for _, player in ipairs(selected or Players:GetPlayers()) do
		local record = self.records[player]
		if record and not record.isBot and not included[player] and connectedPlayer(player) and alive(record)
			and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating") then included[player] = true table.insert(result, player) end
	end
	table.sort(result, function(a, b) return a.UserId < b.UserId end)
	return result
end

function Service:_teams(mark)
	local totals, free = {}, {}
	for _, record in pairs(self.records) do
		if record.participating and (record.isBot or record.player.Parent == Players) then totals[record.teamId] = (totals[record.teamId] or 0) + 1 if not record.muddy and not record.eliminated then free[record.teamId] = (free[record.teamId] or 0) + 1 end end
	end
	if mark and self.phase == "Playing" and self.pendingWinners == nil then
		for team = 1, self.teamCount do
			if not free[team] and not self.eliminatedTeams[team] then
				self.eliminatedTeams[team] = true
				for _, record in pairs(self.records) do if record.participating and record.teamId == team then record.eliminated = true self:_freeze(record, true) self:_role(record) end end
			end
		end
	end
	local active = {}
	for team, amount in pairs(free) do if amount > 0 and not self.eliminatedTeams[team] then table.insert(active, team) end end
	table.sort(active)
	if mark and self.active and self.phase == "Playing" and self.pendingWinners == nil and #active <= 1 then
		self.pendingWinners = table.clone(active)
		for _, record in pairs(self.records) do if record.participating then self:_freeze(record, true) self:_publishRecord(record) end end
	end
	attribute(self.state, "ActiveTeamCount", #active)
	attribute(self.state, "TeamCount", self.teamCount)
	local participants, muddy = 0, 0
	local summary = {}
	for team = 1, self.teamCount do
		participants += totals[team] or 0 muddy += (totals[team] or 0) - (free[team] or 0)
		attribute(self.state, "Team" .. team .. "Members", totals[team] or 0) attribute(self.state, "Team" .. team .. "Free", free[team] or 0)
		table.insert(summary, { teamId = team, colorName = self:_colorName(team), free = free[team] or 0, total = totals[team] or 0, originalTotal = self.originalTeamSizes[team] or 0, eliminated = self.eliminatedTeams[team] == true })
	end
	attribute(self.state, "TeamSummaryJSON", HttpService:JSONEncode(summary))
	attribute(self.state, "ParticipantCount", participants) attribute(self.state, "MuddyCount", muddy)
	return active, totals, free
end

function Service:_stick(record, shooter)
	if not self.active or self.phase ~= "Playing" or self.pendingWinners ~= nil or not record.participating or record.eliminated or (shooter and shooter.teamId == record.teamId) then return false end
	for _, saver in pairs(self.records) do if saver.heatTarget == record then self:_clearHeat(saver, false) end end
	record.muddy, record.rescueProgress = true, 0
	self:_freeze(record, true) self:_role(record) self:_teams(true)
	return true
end

function Service:_clearHeat(record, release)
	if record.heatTarget then record.heatTarget.rescueProgress = 0 attribute(record.heatTarget.player, "MDRescueProgress", 0) end
	record.heatTarget, record.heatStartedAt, record.heatProgress = nil, nil, 0
	if record.player then attribute(record.player, "MDHeatProgress", 0) attribute(record.player, "MDHeatActive", false) attribute(record.player, "MDHeatTargetUserId", 0) end
	if record.heatBeam then record.heatBeam:Destroy() record.heatBeam = nil end
	if release then record.heatHeld, record.heatDirection, record.heatAim, record.heatLeaseEndsAt = false, nil, nil, 0 end
end

function Service:_canAct(record, now)
	return self.active and self.phase == "Playing" and self.pendingWinners == nil and now < self.endsAt and record.participating
		and not record.muddy and not record.eliminated and not record.frozen and alive(record)
end

function Service:_equipped(record, kind)
	if record.isBot then return true end
	if not self:_toolsAllowed(record) then return nil end
	if not record.character then return nil end
	local name = kind == "Mud" and "MudGun" or "HeatGun"
	for _, tool in ipairs(record.character:GetChildren()) do if tool:IsA("Tool") and tool.Name == name and tool:GetAttribute("MDManaged") == true and tool:GetAttribute("MDRound") == self.roundNumber and tool:GetAttribute("MDOwnerUserId") == record.player.UserId and tool:GetAttribute("GunKind") == kind and tool.Enabled == true then return tool end end
	return nil
end

function Service:_rayParameters(source, ignoreCharacters)
	local ignored = { self.bounds }
	for _, name in ipairs({ "StartPads", "TeamSpawns", "NavigationNodes", "CoverVolumes", "RescueAreas", "PracticeSpawns" }) do local folder = self.gameplay:FindFirstChild(name) if folder then table.insert(ignored, folder) end end
	if self.effects then table.insert(ignored, self.effects) end
	if source and source.character then table.insert(ignored, source.character) end
	if ignoreCharacters or not source then for _, record in pairs(self.records) do if record.character then table.insert(ignored, record.character) end end end
	local params = RaycastParams.new() params.FilterType = Enum.RaycastFilterType.Exclude params.FilterDescendantsInstances = ignored params.RespectCanCollide = ignoreCharacters == true or source == nil
	return params
end

function Service:_origin(record, kind, aim)
	local tool = self:_equipped(record, kind)
	if not tool then return nil end
	local origin = (record.character:FindFirstChild("Head") or record.root).Position + aim * 1.5
	if not record.isBot then
		local handle = tool:FindFirstChild("Handle") local muzzle = handle and handle:FindFirstChild("MuzzleAttachment")
		if not muzzle or not muzzle:IsA("Attachment") or (muzzle.WorldPosition - record.root.Position).Magnitude > 8 then return nil end
		origin = muzzle.WorldPosition
	end
	if workspace:Raycast(record.root.Position, origin - record.root.Position, self:_rayParameters(record, true)) then return nil end
	return origin
end

function Service:_hitRecord(part)
	for _, record in pairs(self.records) do if record.participating and record.character and part:IsDescendantOf(record.character) then return record end end
	return nil
end

function Service:_resolveAim(record, kind, aim)
	if typeof(aim) == "Vector3" then
		local unit = direction(aim)
		if not unit then return nil end
		return unit, self:_origin(record, kind, unit)
	end
	if typeof(aim) ~= "table" then return nil end
	local cameraOrigin, unit = aim.cameraOrigin, direction(aim.cameraDirection)
	if not unit or typeof(cameraOrigin) ~= "Vector3" or cameraOrigin.X ~= cameraOrigin.X or cameraOrigin.Y ~= cameraOrigin.Y
		or cameraOrigin.Z ~= cameraOrigin.Z or math.abs(cameraOrigin.X) == math.huge or math.abs(cameraOrigin.Y) == math.huge
		or math.abs(cameraOrigin.Z) == math.huge then return nil end
	local head = record.character:FindFirstChild("Head") or record.root
	if (cameraOrigin - head.Position).Magnitude > 24 then return nil end
	if workspace:Raycast(head.Position, cameraOrigin - head.Position, self:_rayParameters(record, true)) then return nil end
	local origin = self:_origin(record, kind, unit)
	if not origin then return nil end
	local hit = workspace:Raycast(cameraOrigin, unit * 500, self:_rayParameters(record, false))
	local point = hit and hit.Position or cameraOrigin + unit * 500
	return direction(point - origin), origin
end

function Service:_effects()
	if not self.effects then self.effects = Instance.new("Folder") self.effects.Name = "MudRoundEffects" self.effects.Parent = workspace end
	return self.effects
end

function Service:_fire(record, aim, now)
	if not self:_canAct(record, now) or now < (record.fireReadyAt or 0) then return false end
	local unit, origin = self:_resolveAim(record, "Mud", aim) if not unit or not origin then return false end
	local glob = Instance.new("Part") glob.Name = "MudGlob" glob.Shape = Enum.PartType.Ball glob.Size = Vector3.new(1.1, 1.1, 1.1)
	glob.Material = Enum.Material.SmoothPlastic glob.Color = Color3.fromRGB(132, 88, 57) glob.Anchored = true glob.CanCollide = false glob.CanTouch = false glob.CanQuery = false glob.Position = origin glob.Parent = self:_effects()
	table.insert(self.projectiles, { part = glob, position = origin, direction = unit, speed = self:_setting("ProjectileSpeed", 115, 1), remaining = self:_setting("MudRange", 130, 1), source = record, teamId = record.teamId, token = self.currentRound })
	record.fireReadyAt = now + self:_setting("MudCooldownSeconds", 0.65, 0.1) self:_publishRecord(record)
	return true
end

function Service:_tickProjectiles(dt)
	for index = #self.projectiles, 1, -1 do
		local shot = self.projectiles[index]
		local remove = shot.token ~= self.currentRound or self.phase ~= "Playing" or not self.active or self.pendingWinners ~= nil
		if not remove then
			local length = math.min(shot.remaining, shot.speed * dt)
			local vector = shot.direction * length
			local hit = workspace:Raycast(shot.position, vector, self:_rayParameters(shot.source, false))
			if hit then local target = self:_hitRecord(hit.Instance) if target and target.teamId ~= shot.teamId then self:_stick(target, shot.source) end remove = true
			else shot.position += vector shot.remaining -= length shot.part.Position = shot.position remove = shot.remaining <= 0 end
		end
		if remove then shot.part:Destroy() table.remove(self.projectiles, index) end
	end
end

function Service:_heatTarget(record, now)
	if not self:_canAct(record, now) or not record.heatHeld or now >= (record.heatLeaseEndsAt or 0) or not record.heatDirection then return nil end
	local unit, origin = self:_resolveAim(record, "Heat", record.heatAim or record.heatDirection) if not unit or not origin then return nil end
	local hit = workspace:Raycast(origin, unit * self:_setting("HeatRange", 24, 1), self:_rayParameters(record, false))
	local target = hit and self:_hitRecord(hit.Instance)
	if not target or target == record or target.teamId ~= record.teamId or not target.muddy or target.eliminated or not alive(target) then return nil end
	if (target.root.Position - record.root.Position).Magnitude > self:_setting("HeatRange", 24, 1) + 2 then return nil end
	return target, origin, hit.Position
end

function Service:_tickHeat(now)
	for _, record in pairs(self.records) do if record.participating then record.rescueProgress = 0 end end
	local progress = {}
	for _, saver in pairs(self.records) do
		local target, origin, finish = self:_heatTarget(saver, now)
		if not target then self:_clearHeat(saver, false)
		else
			if saver.heatTarget ~= target then self:_clearHeat(saver, false) saver.heatTarget, saver.heatStartedAt = target, now end
			local elapsed = math.max(0, now - saver.heatStartedAt)
			saver.heatProgress = math.min(self:_setting("RescueSeconds", 5, 0.1), elapsed)
			progress[target] = math.max(progress[target] or 0, saver.heatProgress)
			if not saver.heatBeam then local beam = Instance.new("Part") beam.Name = "HeatBeam" beam.Anchored = true beam.CanCollide = false beam.CanTouch = false beam.CanQuery = false beam.Material = Enum.Material.Neon beam.Color = Color3.fromRGB(255, 184, 71) beam.Parent = self:_effects() saver.heatBeam = beam end
			saver.heatBeam.Size = Vector3.new(0.3, 0.3, (finish - origin).Magnitude) saver.heatBeam.CFrame = CFrame.lookAt((origin + finish) / 2, finish)
			if elapsed >= self:_setting("RescueSeconds", 5, 0.1) then target.muddy, target.rescueProgress = false, 0 self:_freeze(target, false) self:_role(target) self:_clearHeat(saver, false) end
		end
	end
	for _, record in pairs(self.records) do if record.participating then record.rescueProgress = record.muddy and (progress[record] or 0) or 0 self:_publishRecord(record) end end
end

function Service:_tickSprint(record, dt, now)
	if not record.participating then return end
	if now >= (record.sprintLeaseEndsAt or 0) or not self:_canAct(record, now) then record.sprintHeld = false end
	local speed = alive(record) and Vector3.new(record.root.AssemblyLinearVelocity.X, 0, record.root.AssemblyLinearVelocity.Z).Magnitude or 0
	record.sprinting = record.sprintHeld and not record.sprintExhausted and record.sprintRemaining > 0 and speed > 1
	if record.sprinting then record.sprintRemaining = math.max(0, record.sprintRemaining - dt) if record.sprintRemaining == 0 then record.sprintExhausted, record.sprinting = true, false end
	else record.sprintRemaining = math.min(record.sprintMax, record.sprintRemaining + record.sprintMax / self:_setting("SprintRefillSeconds", 15, 0.1) * dt) if record.sprintRemaining >= record.sprintMax - 0.0001 then record.sprintRemaining, record.sprintExhausted = record.sprintMax, false end end
	self:_movement(record) self:_publishRecord(record)
end

function Service:_action(record, action, value, aim)
	local player = record.player
	if action == "ChooseColor" then
		if typeof(value) ~= "string" or not PREFERENCE_COLORS[value] then return { ok = false, message = "Choose Red, Blue, Green or Black." } end
		local now = workspace:GetServerTimeNow()
		if now - (record.requests.ChooseColor or -math.huge) < 0.2 then return { ok = false, message = "Slow down." } end
		record.requests.ChooseColor = now
		attribute(player, "MDColorPreference", value)
		if record.participating and self.phase == "Countdown" then
			for team, name in pairs(self.teamColors) do if team ~= record.teamId and name == value then return { ok = true, message = "Saved for the next round; that team color is in use." } end end
			self.teamColors[record.teamId] = value
			for _, teammate in pairs(self.records) do if teammate.participating and teammate.teamId == record.teamId then self:_role(teammate) end end
			self:_teams(false)
		end
		return { ok = true, message = "Color preference saved." }
	end
	if action == "Sprint" and value == false then record.sprintHeld, record.sprinting = false, false if record.participating then self:_movement(record) end self:_publishRecord(record) return { ok = true } end
	if action == "Heat" and value == false then self:_clearHeat(record, true) self:_publishRecord(record) return { ok = true } end
	if typeof(action) ~= "string" or (action ~= "Sprint" and action ~= "Fire" and action ~= "Heat") then return { ok = false, message = "Unknown action." } end
	local now = workspace:GetServerTimeNow()
	if now - (record.requests[action] or -math.huge) < 0.08 then return { ok = false, message = "Slow down." } end
	record.requests[action] = now
	if not self:_canAct(record, now) then return { ok = false, message = "Wait until you can move." } end
	if action == "Sprint" then if value ~= true then return { ok = false, message = "Invalid sprint." } end record.sprintHeld, record.sprintLeaseEndsAt = true, now + 1 self:_movement(record) return { ok = true } end
	if action == "Fire" then return { ok = self:_fire(record, value, now), message = "Mud shot." } end
	local unit, origin = self:_resolveAim(record, "Heat", aim)
	if value ~= true or not unit or not origin then return { ok = false, message = "Equip the Heat Gun and aim toward the playground." } end
	record.heatHeld, record.heatDirection, record.heatAim, record.heatLeaseEndsAt = true, unit, typeof(aim) == "table" and aim or nil, now + 1
	return { ok = true }
end

function Service:Action(player, action, value, aim)
	local record = self.records[player]
	if not connectedPlayer(player) or not record or record.isBot then return { ok = false, message = "Your character is loading." } end
	return self:_action(record, action, value, aim)
end

function Service:_keepLegal(record)
	local point = self.bounds.CFrame:PointToObjectSpace(record.root.Position) local half = self.bounds.Size / 2
	local floor = self:_setting("FloorY", self.spawnPads[1].Position.Y - 3.5, -10000)
	if math.abs(point.X) > half.X - 3 or math.abs(point.Z) > half.Z - 3 or record.root.Position.Y < floor - 7 or math.abs(point.Y) > half.Y then self:_stick(record, nil) self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.teamId))
	elseif record.humanoid.FloorMaterial ~= Enum.Material.Air then record.lastGoodCFrame = record.root.CFrame end
end

function Service:_newBot(index, role)
	if not self.botFolder then
		self.botFolder = Instance.new("Folder")
		self.botFolder.Name = "MudPracticeBots"
		self.botFolder:SetAttribute("MudManaged", true)
		self.botFolder.Parent = workspace
	end
	local attributes = {}
	local player = { DisplayName = role == "Tagger" and "Practice Rival" or "Practice Teammate " .. tostring(index), UserId = -index }
	function player:GetAttribute(name) return attributes[name] end
	function player:SetAttribute(name, value) attributes[name] = value end
	local character = Instance.new("Model")
	character.Name = player.DisplayName
	character:SetAttribute("MDPracticeBot", true)
	local spawn = self:_spawn(index + 1, role == "Tagger" and 2 or 1)
	local function bodyPart(name, size, offset, color, collidable)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = spawn * CFrame.new(offset)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = collidable
		part.CanTouch = false
		part.Parent = character
		return part
	end
	local bodyColor = COLORS[role]
	local skin, navy = Color3.fromRGB(255, 219, 119), Color3.fromRGB(33, 49, 74)
	local root = bodyPart("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero, bodyColor, false)
	root.Transparency = 1
	root.RootPriority = 127
	local torso = bodyPart("Torso", Vector3.new(2, 2, 1), Vector3.zero, bodyColor, true)
	local head = bodyPart("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), skin, false)
	local rightArm = bodyPart("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), skin, false)
	local leftArm = bodyPart("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), skin, false)
	local rightLeg = bodyPart("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), navy, false)
	local leftLeg = bodyPart("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), navy, false)
	local function motor(name, first, second, offset)
		local joint = Instance.new("Motor6D")
		joint.Name = name
		joint.Part0, joint.Part1 = first, second
		joint.C0 = CFrame.new(offset)
		joint.Parent = first
	end
	motor("RootJoint", root, torso, Vector3.zero)
	motor("Neck", torso, head, Vector3.new(0, 1.5, 0))
	motor("Right Shoulder", torso, rightArm, Vector3.new(1.5, 0, 0))
	motor("Left Shoulder", torso, leftArm, Vector3.new(-1.5, 0, 0))
	motor("Right Hip", torso, rightLeg, Vector3.new(0.5, -2, 0))
	motor("Left Hip", torso, leftLeg, Vector3.new(-0.5, -2, 0))
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = player.DisplayName
	humanoid.HipHeight = 0
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = self:_setting("BaseSpeed", 16, 0)
	humanoid.Parent = character
	character.PrimaryPart = root
	player.Character = character
	character.Parent = self.botFolder
	pcall(function() root:SetNetworkOwner(nil) end)
	local record = self:_record(player, true)
	record.character, record.root, record.humanoid, record.ready = character, root, humanoid, true
	record.nextBotMoveAt = 0
	record.nextPathAt = 0
	record.stuckSince = 0
	record.spawnIndex = index + 1
	record.template = character:Clone()
	return player
end

function Service:_respawnBot(record)
	if record.respawning or not record.template or not self.botFolder or not self.active then return end
	record.respawning = true
	self:_restore(record)
	disconnect(record.characterConnections)
	if record.character then record.character:Destroy() end
	local character = record.template:Clone()
	character.Parent = self.botFolder
	record.player.Character = character
	record.character = character
	record.root = character:FindFirstChild("HumanoidRootPart")
	record.humanoid = character:FindFirstChild("Humanoid")
	record.ready = true
	record.route = nil
	record.pathBusy = false
	record.nextPathAt = 0
	record.frozen = record.muddy or record.eliminated or self.phase ~= "Playing"
	self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.teamId))
	pcall(function() record.root:SetNetworkOwner(nil) end)
	self:_freeze(record, record.frozen)
	self:_role(record)
	record.respawning = false
end

function Service:_clearBots()
	local remove = {}
	for player, record in pairs(self.records) do
		if record.isBot then
			disconnect(record.connections)
			disconnect(record.characterConnections)
			if record.template then record.template:Destroy() end
			table.insert(remove, player)
		end
	end
	for _, player in ipairs(remove) do self.records[player] = nil end
	if self.botFolder then self.botFolder:Destroy() self.botFolder = nil end
end

function Service:_fallbackRoute(startPosition, goal)
	local params = self:_rayParameters()
	if not workspace:Raycast(startPosition, goal - startPosition, params) then
		return { { Position = goal, Action = Enum.PathWaypointAction.Walk } }
	end
	local nodes, distances, previous, done = self.navNodes, {}, {}, {}
	local start, finish, startDistance, finishDistance
	for index, node in ipairs(nodes) do
		local first = (node.Position - startPosition).Magnitude
		local second = (node.Position - goal).Magnitude
		if not workspace:Raycast(startPosition, node.Position - startPosition, params) and (not startDistance or first < startDistance) then start, startDistance = index, first end
		if not workspace:Raycast(node.Position, goal - node.Position, params) and (not finishDistance or second < finishDistance) then finish, finishDistance = index, second end
	end
	if not start or not finish then return nil end
	distances[start] = 0
	local byName = {}
	for index, node in ipairs(nodes) do byName[node.Name] = index end
	for _ = 1, #nodes do
		local current, cost
		for index, distance in pairs(distances) do
			if not done[index] and (not cost or distance < cost) then current, cost = index, distance end
		end
		if not current or current == finish then break end
		done[current] = true
		local neighborNames = nodes[current]:GetAttribute("Neighbors") or nodes[current]:GetAttribute("Neighbor") or ""
		for name in string.gmatch(neighborNames, "[^,%s]+") do
			local neighbor = byName[name]
			if neighbor and not done[neighbor] then
				local alternative = cost + (nodes[neighbor].Position - nodes[current].Position).Magnitude
				if not distances[neighbor] or alternative < distances[neighbor] then
					distances[neighbor], previous[neighbor] = alternative, current
				end
			end
		end
	end
	if not distances[finish] then return nil end
	local reversed, current = {}, finish
	while current do
		table.insert(reversed, { Position = nodes[current].Position, Action = Enum.PathWaypointAction.Walk })
		current = previous[current]
	end
	local route = {}
	for index = #reversed, 1, -1 do table.insert(route, reversed[index]) end
	table.insert(route, { Position = goal, Action = Enum.PathWaypointAction.Walk })
	return route
end

function Service:_path(bot, goal, now)
	if bot.pathBusy or now < bot.nextPathAt then return end
	bot.pathBusy = true
	bot.nextPathAt = now + 1.2
	bot.pathGoal = goal
	local token = self.currentRound
	local character = bot.character
	local origin = bot.root.Position
	task.spawn(function()
		local route
		local ok = pcall(function()
			local path = PathfindingService:CreatePath({ AgentRadius = 2.4, AgentHeight = 5.5, AgentCanJump = true, WaypointSpacing = 6 })
			path:ComputeAsync(origin, goal)
			if path.Status == Enum.PathStatus.Success then route = path:GetWaypoints() end
			path:Destroy()
		end)
		if not ok or not route or #route == 0 then route = self:_fallbackRoute(origin, goal) end
		if self.currentRound == token and self.records[bot.player] == bot and bot.character == character then
			bot.route, bot.routeIndex = route, 2
			if route and #route == 1 then bot.routeIndex = 1 end
			bot.pathBusy = false
		end
	end)
end

function Service:_botTarget(bot)
	local teammate, teammateDistance, opponent, opponentDistance
	for _, candidate in pairs(self.records) do
		if candidate ~= bot and candidate.participating and not candidate.eliminated and alive(candidate) then
			local distance = (candidate.root.Position - bot.root.Position).Magnitude
			if candidate.teamId == bot.teamId and candidate.muddy and (not teammateDistance or distance < teammateDistance) then teammate, teammateDistance = candidate, distance
			elseif candidate.teamId ~= bot.teamId and not candidate.muddy and (not opponentDistance or distance < opponentDistance) then opponent, opponentDistance = candidate, distance end
		end
	end
	if teammate then return teammate, true, teammateDistance end
	return opponent, false, opponentDistance
end

function Service:_moveBot(bot, goal, now)
	local direct = not workspace:Raycast(bot.root.Position, goal - bot.root.Position, self:_rayParameters())
	local destination = goal
	if not direct then
		self:_path(bot, goal, now)
		local route, index = bot.route, bot.routeIndex or 1
		while route and route[index] and (route[index].Position - bot.root.Position).Magnitude < 4 do index += 1 end
		bot.routeIndex = index
		local waypoint = route and route[index]
		if waypoint then destination = waypoint.Position if waypoint.Action == Enum.PathWaypointAction.Jump then bot.humanoid.Jump = true end
		else destination = bot.root.Position end
	end
	if bot.previousBotPosition and (bot.root.Position - bot.previousBotPosition).Magnitude < 0.2 and (destination - bot.root.Position).Magnitude > 5 then
		bot.stuckSince += 0.2
		if bot.stuckSince > 0.8 then bot.humanoid.Jump = true bot.nextPathAt = 0 end
	else bot.stuckSince = 0 end
	bot.previousBotPosition = bot.root.Position
	bot.humanoid:MoveTo(destination)
end

function Service:_driveBots(now)
	for _, bot in pairs(self.records) do
		if bot.isBot and self:_canAct(bot, now) and now >= bot.nextBotMoveAt then
			bot.nextBotMoveAt = now + 0.2
			local target, rescue, distance = self:_botTarget(bot)
			if target then
				local goal = target.root.Position
				local head = bot.character:FindFirstChild("Head") or bot.root
				local aim = direction(goal - head.Position)
				local heating = false
				if rescue and aim and distance <= self:_setting("HeatRange", 24, 1) - 2 then
					bot.heatHeld, bot.heatDirection, bot.heatLeaseEndsAt = true, aim, now + 1
					heating = self:_heatTarget(bot, now) == target
				end
				if not heating then self:_clearHeat(bot, true) end
				if heating then bot.humanoid:MoveTo(bot.root.Position)
				else
					local direct = not workspace:Raycast(bot.root.Position, goal - bot.root.Position, self:_rayParameters())
					if not rescue and direct and distance < math.min(self:_setting("MudRange", 130, 1) - 10, 80) then
						bot.humanoid:MoveTo(bot.root.Position)
						local interval = self:_setting("BotShotIntervalSeconds", 7, 0.2)
						bot.nextBotShotAt = bot.nextBotShotAt or now + interval * (0.6 + bot.spawnIndex * 0.3)
						if now >= bot.nextBotShotAt then
							local lead = math.min(distance / self:_setting("ProjectileSpeed", 115, 1), 1)
							local predicted = goal + target.root.AssemblyLinearVelocity * lead
							local shotDirection = direction(predicted - head.Position)
							if shotDirection then self:_fire(bot, shotDirection, now) end
							bot.nextBotShotAt = now + interval
						end
					else self:_moveBot(bot, goal, now) end
				end
			else self:_clearHeat(bot, true) bot.humanoid:MoveTo(bot.root.Position) end
		end
	end
end

function Service:_tick(dt)
	if not self.active then return end
	local now = workspace:GetServerTimeNow()
	for _, record in pairs(self.records) do
		if record.participating and record.isBot and not alive(record) then self:_stick(record, nil) self:_respawnBot(record) end
		if record.participating and alive(record) then
			if record.frozen and record.lockedCFrame then if (record.root.Position - record.lockedCFrame.Position).Magnitude > 0.05 then self:_teleport(record, record.lockedCFrame) end record.root.AssemblyLinearVelocity, record.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero record.humanoid:Move(Vector3.zero)
			else self:_keepLegal(record) end
		end
		self:_tickSprint(record, dt, now)
	end
	if self.phase ~= "Playing" or now >= self.endsAt then return end
	self:_driveBots(now) self:_tickProjectiles(dt) self:_tickHeat(now) self:_teams(true)
end

function Service:_valid(token) return self.running and self.active and self.currentRound == token end

function Service:_results(token, winners, reason)
	local winnerSet, winnerIds, participantIds, names = {}, {}, {}, {}
	for _, id in ipairs(winners) do winnerSet[id] = true end
	for _, entry in ipairs(self.roundRoster) do if not entry.isBot then table.insert(participantIds, entry.userId) if winnerSet[entry.teamId] then table.insert(winnerIds, entry.userId) end end end
	for _, record in pairs(self.records) do if record.participating then self:_freeze(record, true) self:_publishRecord(record) local won = winnerSet[record.teamId] == true attribute(record.player, "MDResult", won and "Won" or "Lost") if won then table.insert(names, record.player.DisplayName) end end end
	for _, shot in ipairs(self.projectiles) do shot.part:Destroy() end table.clear(self.projectiles)
	table.sort(winnerIds) table.sort(participantIds) table.sort(names)
	attribute(self.state, "WinnerTeamIds", table.concat(winners, ",")) attribute(self.state, "WinnerTeams", table.concat(winners, ",")) attribute(self.state, "WinnersText", table.concat(names, ", ")) attribute(self.state, "ResultReason", reason)
	attribute(self.state, "LastResultWinnerIds", table.concat(winnerIds, ",")) attribute(self.state, "LastResultParticipantIds", table.concat(participantIds, ",")) attribute(self.state, "LastResultPractice", self.mode ~= "Round") attribute(self.state, "LastResultRound", self.roundNumber)
	self:_phase("Results")
	local untilTime = workspace:GetServerTimeNow() + self:_setting("ResultsSeconds", 7, 0)
	while self:_valid(token) and workspace:GetServerTimeNow() < untilTime do task.wait(0.1) end
end

function Service:_cleanup(token)
	if token and self.currentRound ~= token then return end
	for _, record in pairs(self.records) do self:_destroyTools(record) end
	for _, record in pairs(self.records) do if record.participating then record.participating = false self:_restore(record) record.teamId, record.muddy, record.eliminated, record.rescueProgress, record.sprintMax, record.sprintRemaining = 0, false, false, 0, 0, 0 record.sprintExhausted, record.sprintLeaseEndsAt, record.fireReadyAt = false, 0, 0 self:_publishRecord(record) if not record.isBot and self.lobbySpawn and self.lobbySpawn.Parent then self:_teleport(record, self.lobbySpawn.CFrame + Vector3.new(0, self.lobbySpawn.Size.Y / 2 + 3, 0)) end end end
	self:_clearBots() table.clear(self.projectiles) if self.effects then self.effects:Destroy() self.effects = nil end
	self.active, self.currentRound, self.practiceOwner, self.mode, self.endsAt = false, nil, nil, "Waiting", 0
	self.pendingWinners = nil
	self.eliminatedTeams, self.originalTeamSizes, self.roundRoster = {}, {}, {}
	attribute(self.state, "Mode", "Waiting") attribute(self.state, "EndsAt", 0) attribute(self.state, "PracticeOwnerUserId", 0) attribute(self.state, "CountdownValue", 0) self:_phase("Waiting") self:_teams(false)
end

function Service:_run(participants, token)
	if not self:_valid(token) then return end
	self.roundNumber += 1 self.eliminatedTeams, self.originalTeamSizes, self.roundRoster, self.pendingWinners = {}, {}, {}, nil
	attribute(self.state, "RoundNumber", self.roundNumber) attribute(self.state, "RoundDuration", self:_setting("RoundDuration", 300, 1)) attribute(self.state, "RescueSeconds", self:_setting("RescueSeconds", 5, 0.1)) attribute(self.state, "WinnersText", "") attribute(self.state, "WinnerTeams", "") attribute(self.state, "WinnerTeamIds", "") attribute(self.state, "ResultReason", "")
	local assignments
	if token.teams then assignments, self.teamCount = token.teams, 2 else assignments, self.teamCount = Service.TeamAssignments(#participants, self:_setting("TeamCount", 2, 2), self:_setting("MaxTeamSize", 2, 2)) end
	local slots = {}
	for index, player in ipairs(participants) do
		local record = self.records[player]
		if record then
			record.participating, record.teamId, record.muddy, record.eliminated = true, assignments[index], false, false slots[record.teamId] = (slots[record.teamId] or 0) + 1 record.spawnIndex = slots[record.teamId]
			self.originalTeamSizes[record.teamId] = (self.originalTeamSizes[record.teamId] or 0) + 1
			table.insert(self.roundRoster, { userId = player.UserId, teamId = record.teamId, isBot = record.isBot })
			record.sprintMax = self:_setting("SprintSeconds", 10, 0.1) record.sprintRemaining = record.sprintMax record.sprintExhausted, record.sprintHeld, record.fireReadyAt = false, false, 0
			record.rescueProgress, record.lastGoodCFrame, record.requests, record.nextBotShotAt = 0, nil, {}, nil attribute(player, "MDResult", "")
			local spawn = self:_spawn(record.spawnIndex, record.teamId)
			local practice = token.teams and parts(self.gameplay:FindFirstChild("PracticeSpawns"))
			if practice and #practice > 0 then spawn = practice[(index - 1) % #practice + 1].CFrame elseif token.teams then spawn = CFrame.new(self.bounds.Position.X + (record.teamId == 1 and -22 or 22), self.spawnPads[1].Position.Y, self.bounds.Position.Z + (record.spawnIndex - 1) * 17) end
			self:_teleport(record, spawn) self:_freeze(record, true) self:_giveTools(record) self:_role(record)
		end
	end
	self:_chooseTeamColors()
	for _, record in pairs(self.records) do if record.participating then self:_role(record) end end
	self:_teams(false) self:_phase("Countdown")
	for number = math.floor(self:_setting("CountdownSeconds", 3, 1)), 1, -1 do if not self:_valid(token) then return end attribute(self.state, "CountdownValue", number) local untilTime = workspace:GetServerTimeNow() + 1 while self:_valid(token) and workspace:GetServerTimeNow() < untilTime do task.wait(0.05) end end
	if not self:_valid(token) then return end
	self.endsAt = workspace:GetServerTimeNow() + self:_setting("RoundDuration", 300, 1) attribute(self.state, "EndsAt", self.endsAt) attribute(self.state, "CountdownValue", 0) self:_phase("Playing")
	for _, record in pairs(self.records) do if record.participating and self.pendingWinners == nil then if not alive(record) or (record.isBot and record.practiceMedic and self.mode == "PracticeMedic") then self:_stick(record, nil) else self:_freeze(record, false) end end end
	local active = self:_teams(true)
	while self:_valid(token) and self.pendingWinners == nil and workspace:GetServerTimeNow() < self.endsAt do task.wait(0.05) active = self:_teams(true) end
	if self:_valid(token) then
		local reason
		if self.pendingWinners then active = self.pendingWinners reason = #active == 0 and "NoActiveTeams" or "LastTeamStanding"
		else active = self:_timeoutWinners() reason = #active > 1 and "TimeoutShared" or #active == 0 and "NoActiveTeams" or "Timeout" end
		self:_results(token, active, reason) self:_cleanup(token)
	end
end

function Service:_begin(participants, mode, teams, owner)
	self.active, self.mode, self.practiceOwner = true, mode, owner
	local token = { teams = teams } self.currentRound = token
	attribute(self.state, "Mode", mode) attribute(self.state, "PracticeOwnerUserId", owner and owner.UserId or 0)
	task.spawn(function() local ok, failure = xpcall(function() self:_run(participants, token) end, debug.traceback) if not ok then warn("Stuck in the Mud round failed: " .. tostring(failure)) self:_cleanup(token) end end)
	return true
end

function Service:_weaponsReady()
	local ok, ready = pcall(function()
		local assets = ReplicatedStorage:FindFirstChild("MudAssets")
		local mud = assets and assets:FindFirstChild("MudGun")
		local heat = assets and assets:FindFirstChild("HeatGun")
		if not mud or not heat or not mud:IsA("Tool") or not heat:IsA("Tool") then return false end
		local mudEnabled, heatEnabled = mud.Enabled, heat.Enabled
		return mudEnabled == true and heatEnabled == true
	end)
	return ok and ready == true
end

function Service:StartRound(selected)
	if not self.running then return false, "Service is not running" end if self.active then return false, "A round is already running" end
	local ready = self:_weaponsReady() attribute(self.state, "GunAccessReady", ready)
	if not ready then return false, "Mud gun access is awaiting approval." end
	local participants = self:_readyPlayers(selected)
	local minimum = math.clamp(math.floor(self:_setting("MinimumPlayers", 4, 2)), 2, 24)
	local maximum = math.clamp(math.floor(self:_setting("MaxPlayers", 4, 2)), 2, 24)
	if #participants < minimum or maximum < minimum then return false, "At least " .. minimum .. " ready players are needed." end
	for index = #participants, 2, -1 do local other = self.random:NextInteger(1, index) participants[index], participants[other] = participants[other], participants[index] end
	while #participants > maximum do table.remove(participants) end
	return self:_begin(participants, "Round")
end

function Service:StartPractice(player, role)
	if not self.running then return false, "Service is not running" end if self.active then return false, "A round is already running" end
	local ready = self:_weaponsReady() attribute(self.state, "GunAccessReady", ready)
	if not ready then return false, "Mud gun access is awaiting approval." end
	if role ~= "Runner" and role ~= "Tagger" and role ~= "Shooter" and role ~= "Medic" then return false, "Choose Shooter or Medic practice" end
	local record = self.records[player] if not connectedPlayer(player) or not record or record.isBot or not alive(record) or player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") then return false, "Your character is not ready" end
	local participants, teams = { player }, { 1 }
	local ok, failure = xpcall(function() for index = 1, 3 do local bot = self:_newBot(index, index == 1 and "Runner" or "Tagger") table.insert(participants, bot) table.insert(teams, index == 1 and 1 or 2) self.records[bot].practiceMedic = index == 1 end end, debug.traceback)
	if not ok then self:_clearBots() warn(tostring(failure)) return false, "Practice bots could not be created" end
	return self:_begin(participants, "Practice" .. role, teams, player)
end

function Service:StopRound()
	if not self.active then return false, "No round is running" end self.currentRound = nil self:_cleanup() return true
end

function Service:Start(player, role)
	if player then if not self.running then self:Start() end return self:StartPractice(player, role or "Shooter") end
	if self.running then return end self.running, runningService = true, self
	local provider = PhysicsService if pcall(function() workspace:IsCollisionGroupRegistered("MudPlayer") end) then provider = workspace end
	if not provider:IsCollisionGroupRegistered("MudPlayer") then provider:RegisterCollisionGroup("MudPlayer") end provider:CollisionGroupSetCollidable("MudPlayer", "MudPlayer", false)
	for name, value in pairs({ Phase = "Waiting", Mode = "Waiting", GunAccessReady = self:_weaponsReady(), EndsAt = 0, CountdownValue = 0, RoundNumber = 0, RoundDuration = 300, RescueSeconds = 5, ActiveTeamCount = 0, ParticipantCount = 0, MuddyCount = 0, TeamCount = 2, TeamSummaryJSON = "[]", WinnersText = "", WinnerTeams = "", WinnerTeamIds = "", ResultReason = "", LastResultWinnerIds = "", LastResultParticipantIds = "", LastResultPractice = true, LastResultRound = 0, PracticeOwnerUserId = 0 }) do attribute(self.state, name, value) end
	table.insert(self.connections, Players.PlayerAdded:Connect(function(value) self:_addPlayer(value) end)) table.insert(self.connections, Players.PlayerRemoving:Connect(function(value) self:_removePlayer(value) end))
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self.tickAccumulator += dt if self.tickAccumulator >= 0.05 then local elapsed = self.tickAccumulator self.tickAccumulator = 0 self:_tick(math.min(elapsed, 0.25)) end end))
	for _, value in ipairs(Players:GetPlayers()) do self:_addPlayer(value) end
	local remote = ReplicatedStorage:FindFirstChild("MudActionRequest") if remote and remote:IsA("RemoteFunction") then self.remote = remote remote.OnServerInvoke = function(value, action, argument, aim) return self:Action(value, action, argument, aim) end end
end

function Service:Stop()
	self.running, self.currentRound = false, nil disconnect(self.connections) self:_cleanup()
	for _, record in pairs(self.records) do disconnect(record.connections) disconnect(record.characterConnections) end table.clear(self.records)
	if self.remote then self.remote.OnServerInvoke = nil end if runningService == self then runningService = nil end
end

function Service.GetRunningService() return runningService end

return Service

]====]}
}
local function normalize(source) return (source:gsub("\r\n", "\n"):gsub("\n+$", "")) end
for _,entry in ipairs(entries) do
    local node=game
    for name in entry.path:gmatch("[^%.]+") do node=node and node:FindFirstChild(name) end
    assert(node and node:IsA("LuaSourceContainer"), "Missing script: "..entry.path)
    assert(normalize(node.Source)==normalize(entry.before), "Source changed since snapshot: "..entry.path)
    entry.node=node
    entry.capabilities=tostring(node.Capabilities)
    entry.sandboxed=node.Sandboxed
end
local backup=Instance.new("Folder") backup.Name="EmoteCatalogBackup20261005"
for index,entry in ipairs(entries) do
    local copy=entry.node:Clone()
    copy.Name=string.format("%02d_",index)..entry.node.Name
    copy:SetAttribute("OriginalPath",entry.path)
    copy.Parent=backup
end
backup.Parent=storage
local ui=(function()
local function install(shell, backup)
	assert(not game:GetService("RunService"):IsRunning(), "Use Edit mode")
	local shop = shell:WaitForChild("ShopPanel")
	if backup then
		local storage = game:GetService("ServerStorage")
		if not storage:FindFirstChild("EmoteShopUIBackup20261005") then
			local folder = Instance.new("Folder")
			folder.Name = "EmoteShopUIBackup20261005"
			local copy = shop:Clone()
			copy.Parent = folder
			shell.Templates.ItemCard:Clone().Parent = folder
			folder.Parent = storage
		end
	end
	local cards = { shell.Templates.ItemCard }
	for _, card in ipairs(shop.Cards:GetChildren()) do
		if card:IsA("Frame") and card:FindFirstChild("Preview") and card:FindFirstChild("Action") then table.insert(cards, card) end
	end
	for _, card in ipairs(cards) do
		local preview = card.Preview
		local thumbnail = card:FindFirstChild("Thumbnail")
		if not thumbnail then
			thumbnail = Instance.new("ImageLabel")
			thumbnail.Name = "Thumbnail"
			thumbnail.AnchorPoint = preview.AnchorPoint
			thumbnail.Position = preview.Position
			thumbnail.Size = preview.Size
			thumbnail.Rotation = preview.Rotation
			thumbnail.ZIndex = preview.ZIndex
			thumbnail.BackgroundTransparency = 1
			thumbnail.BorderSizePixel = 0
			thumbnail.Image = ""
			thumbnail.ScaleType = Enum.ScaleType.Fit
			thumbnail.Visible = false
			thumbnail:SetAttribute("EmoteThumbnail", true)
			thumbnail.Parent = card
		end
		if not card:FindFirstChild("ThumbnailStatus") then
			local status = card.Category:Clone()
			status.Name = "ThumbnailStatus"
			status.AnchorPoint = preview.AnchorPoint
			status.Position = preview.Position
			status.Size = preview.Size
			status.Rotation = preview.Rotation
			status.ZIndex = preview.ZIndex + 1
			status.BackgroundTransparency = 1
			status.BorderSizePixel = 0
			status.Text = "Loading preview..."
			status.TextColor3 = Color3.fromRGB(255, 255, 248)
			status.TextStrokeTransparency = 1
			status.TextXAlignment = Enum.TextXAlignment.Center
			status.TextYAlignment = Enum.TextYAlignment.Center
			status.TextScaled = true
			status.TextWrapped = true
			status.Visible = false
			local limit = status:FindFirstChildOfClass("UITextSizeConstraint")
			if limit then limit.MinTextSize = 10 limit.MaxTextSize = 16 end
			local stroke = status:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
				stroke.Color = Color3.fromRGB(27, 45, 61)
				stroke.Thickness = 1.5
				stroke.Transparency = 0
			end
			status.Parent = card
		end
	end
	return { cards = #cards, thumbnails = #cards, templateIncluded = true }
end

return install(game:GetService("StarterGui"):WaitForChild("PlaygroundShell"), true)

end)()
local changed={}
local ok,problem=pcall(function()
    for _,entry in ipairs(entries) do
        entry.node.Source=entry.after
        table.insert(changed,entry)
        assert(normalize(entry.node.Source)==normalize(entry.after),"Source did not match: "..entry.path)
        assert(tostring(entry.node.Capabilities)==entry.capabilities and entry.node.Sandboxed==entry.sandboxed,"Permissions changed: "..entry.path)
    end
end)
if not ok then
    for _,entry in ipairs(changed) do entry.node.Source=entry.before end
    error(problem)
end
return game:GetService("HttpService"):JSONEncode({installed=#changed,ui=ui,backup=backup:GetFullName(),playStarted=false,permissionsChanged=false})
