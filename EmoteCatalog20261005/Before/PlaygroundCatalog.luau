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


