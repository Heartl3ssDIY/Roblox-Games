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



