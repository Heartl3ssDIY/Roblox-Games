assert(not game:GetService("RunService"):IsRunning(), "Stop Play before integrating Duck Duck Goose.")
assert(game.PlaceId == 95034648955135, "Wrong experience.")
local entries = { {path="ReplicatedStorage.PlaygroundCatalog",expected=1678216908,after=989140918,caps="RunClientScript | RunServerScript | Basic",sandboxed=true,source=[==[local COIN_PRICE_MULTIPLIER = 3
local COIN_PRICE_CAP = 100000

local function item(id, name, category, slot, kind, amount, gameId, description, color, finalCoinPrice)
	if kind == "Coins" and not finalCoinPrice then amount = amount * COIN_PRICE_MULTIPLIER end
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
	item("P20", "Royal Slime", "Pets", "Pet", "Wins", 100, "All", "Win 100 rounds across all games.", {100, 148, 237}),
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
	item("B16", "Fossil Slugger", "Bats", "Bat", "Coins", 36000, nil, "A recognisable long tapered baseball bat with a broad ivory fossil-bone barrel, three chunky tan rib-like rings fused around the upper barrel, dark navy collar and a dark brown wrapped grip.", {232, 213, 163}, true),
	item("B17", "Dragon Scale", "Bats", "Bat", "Level", 100, nil, "A long tapered baseball bat with a glossy emerald barrel clad in four broad overlapping rounded dragon-scale bands, golden end cap and collar, plum-purple grip and gold knob.", {71, 180, 119}),
	item("B18", "Breakfast Bonker", "Bats", "Bat", "Coins", 42000, nil, "A long baseball bat with a golden toasted waffle-patterned barrel, broad shallow 3-by-5 waffle grid following its rounded cylinder, a glossy caramel cap dripping a little onto the top third, cream butter-coloured rim.", {232, 170, 75}, true),
	item("B19", "Cloud Nine", "Bats", "Bat", "Level", 75, nil, "An elegant chunky baseball bat with a pearl-white rounded barrel, sky-blue lower taper, two broad embossed feather panels wrapping along the barrel and a lavender collar.", {225, 226, 255}),
	item("B20", "Bamboo Bruiser", "Bats", "Bat", "Wins", 100, "StuckInTheMud", "A recognisable baseball bat made of glossy jade-green bamboo-like segments, thick broad upper barrel and smoothly narrowing shaft, pale cream node bands, dark navy collar, tan rope-textured handgrip rendered as four simple broad wraps and flat green knob.", {121, 181, 93}),
	item("B21", "Arcade Combo", "Bats", "Bat", "Coins", 55000, nil, "A chunky baseball bat with a dark violet elongated cylindrical barrel with broad cyan edge rails and exactly three large glossy arcade buttons arranged lengthwise, red yellow and mint.", {90, 188, 247}, true),
	item("B22", "Honeycomb Hitter", "Bats", "Bat", "Coins", 70000, nil, "A warm amber baseball bat with a rounded barrel wrapped in five large golden hexagonal honeycomb panels, a few broad opaque golden honey drips moulded against its surface, cream tip cap, navy collar and black-and-yellow striped rubber grip.", {250, 196, 57}, true),
	item("B23", "Clockwork Clobber", "Bats", "Bat", "Coins", 85000, nil, "A copper and cream baseball bat with a long thick tapered barrel, two broad navy collars and one LARGE simple brass gear inset into the barrel side.", {192, 145, 85}, true),
	item("B24", "Patchwork Popper", "Bats", "Bat", "Level", 250, nil, "A long rounded baseball bat with purple and mint-green broad stitched fabric-like panels, simple cream cross stitches and one large round orange button mounted near the upper barrel.", {217, 122, 204}),
	item("B25", "Prism Champion", "Bats", "Bat", "Coins", 100000, nil, "A spectacular long baseball bat with an opaque faceted royal-purple and cyan crystal barrel, six broad flat facets, a blunt chamfered tip and two thick cream-and-gold reinforcing collars.", {119, 193, 243}, true),
	item("M16", "Snowglobe Sip", "Toys", "Gear", "Coins", 18000, nil, "Lobby only. Take a sip and release a cheerful flurry of snow sparkles. Cosmetic effect.", {127, 214, 245}, true),
	item("M17", "Snowball Lobber", "Toys", "Gear", "Coins", 33000, nil, "Lobby only. Fire a playful snowball with a throwing pose. Cosmetic shot; no freeze or damage.", {93, 162, 229}, true),
	item("M18", "Bubble Blower", "Toys", "Gear", "Coins", 22500, nil, "Lobby only. Blow a stream of floating cartoon bubbles. Cosmetic effect.", {246, 142, 196}, true),
	item("M19", "Slippy Banana", "Toys", "Gear", "Coins", 20000, nil, "Lobby only. Place a banana prop that disappears after 5 seconds. Cosmetic prop; no slipping.", {255, 216, 85}, true),
	item("M20", "Spring Glove", "Toys", "Gear", "Coins", 28000, nil, "Lobby only. Swing a spring glove with a sparkling bonk. Cosmetic effect; no damage or knockback.", {241, 112, 96}, true),
	item("M21", "Sticky Honey", "Toys", "Gear", "Coins", 30000, nil, "Lobby only. Toss a honey pot with a golden splat. Cosmetic effect; no slowing players.", {240, 180, 73}, true),
	item("M22", "Whoopee Whump", "Toys", "Gear", "Coins", 24000, nil, "Lobby only. Squeeze and shake a whoopee cushion with a playful puff. Cosmetic effect.", {242, 99, 103}, true),
	item("M23", "Magnet Mover", "Toys", "Gear", "Coins", 45000, nil, "Lobby only. Aim a chunky magnet and create a sparkling arc. Cosmetic effect; no pulling players.", {234, 94, 93}, true),
	item("M24", "Ricochet Flyer", "Toys", "Gear", "Coins", 60000, nil, "Lobby only. Throw a flyer that curves back toward you. Cosmetic effect.", {89, 211, 234}, true),
	item("M25", "Pop-Up Surprise", "Toys", "Gear", "Coins", 75000, nil, "Lobby only. Shake a surprise box to release colourful confetti. Cosmetic effect.", {237, 126, 105}, true),
	item("P21", "Crystal Drake", "Pets", "Pet", "Coins", 100000, nil, "A chubby sapphire-blue baby dragon with an oversized friendly head, two short ivory horns, lavender wing membranes, a pale blue belly, four sturdy little feet and a curled tail.", {89, 170, 239}, true),
	item("P22", "Ember Wyrmling", "Pets", "Pet", "Wins", 150, "StuckInTheMud", "A squat brick-red baby dragon with broad orange folded wings, cream segmented belly, rounded charcoal horns and a short tail with a solid orange flame-shaped fin.", {233, 111, 69}),
	item("P23", "Cloud Pegasus", "Pets", "Pet", "Level", 150, nil, "An adorable pearl-white miniature winged horse, rounded lavender mane and curled tail, sky-blue hooves, two thick feathered white wings attached at the shoulders and a small gold collar.", {223, 210, 248}),
	item("P24", "Suncrest Griffin", "Pets", "Pet", "Wins", 200, "BritishBulldog", "A chubby baby griffin with a cream eagle head, chunky golden beak, small swept-back gold head feathers, caramel lion body, stout golden front talons and rounded lion rear paws.", {237, 186, 85}),
	item("P25", "Halo Cherub", "Pets", "Pet", "Level", 250, nil, "One tiny angel companion pet with a round cream face, two shiny navy eyes, a tiny smiling mouth, a simple pale-blue bell-shaped robe/body, stubby hands and feet, and two attached layered ivory wings.", {254, 225, 157}),
	item("P26", "Pebble Triceratops", "Pets", "Pet", "Coins", 36000, nil, "A chubby turquoise baby triceratops with a huge rounded head frill edged in chunky cream knobs, two short blunt cream brow horns and one smaller nose horn, four squat legs and a short tail.", {184, 206, 126}, true),
	item("P27", "Fern Stegosaurus", "Pets", "Pet", "Coins", 42000, nil, "A cheerful moss-green baby stegosaurus with a plump low body, small round head, four squat cream-toed legs and two rows of five broad orange leaf-shaped dorsal plates attached to its back.", {109, 184, 108}, true),
	item("P28", "Sky Pterodactyl", "Pets", "Pet", "Level", 100, nil, "A cute lavender baby pterosaur standing with two little feet and compact partially open wings, a long rounded peach beak, a small backward swept head crest and shiny navy eyes.", {156, 187, 231}),
	item("P29", "Tundra Mammoth", "Pets", "Pet", "Coins", 75000, nil, "A tiny shaggy cinnamon-brown woolly mammoth with a huge round head, short lifted trunk, two short curved ivory tusks, small caramel ears and four stubby feet.", {187, 150, 118}, true),
	item("P30", "Crowned Pig", "Pets", "Pet", "Coins", 90000, nil, "A lovable plump PINK PIG wearing a prominent GOLD CROWN with three broad points and one red square jewel, a playful Minecraft king-pig homage interpreted as an original rounded cartoon pet.", {247, 173, 191}, true),
	item("P31", "Waffle Tortoise", "Pets", "Pet", "Coins", 48000, nil, "One adorable little golden tortoise whose thick square-rounded shell is a golden waffle with a very clear simple 3-by-3 grid of recessed pockets, a glossy caramel syrup patch and one thick pale-yellow butter square attached on top.", {224, 177, 87}, true),
	item("P32", "Pancake Pal", "Pets", "Pet", "Level", 75, nil, "A cute living stack of THREE thick fluffy golden pancakes as one compact pet, glossy caramel syrup draped over the top edge and a pale-yellow butter cube fixed on top.", {234, 182, 101}),
	item("P33", "Velvet Jumper", "Pets", "Pet", "Coins", 60000, nil, "One cute plush-like jumping spider, a single round plum-purple body and smaller attached head with two oversized glossy navy front eyes plus two tiny eyes above.", {155, 113, 200}, true),
	item("P34", "Patchwork Zombie", "Pets", "Pet", "Wins", 150, "TagYoureIt", "A silly friendly chibi zombie companion with a large square-rounded mint-green head, one button-shaped eye and one shiny navy eye, a big goofy smile with two chunky teeth.", {139, 189, 112}),
	item("P35", "Sunfeather Phoenix", "Pets", "Pet", "Level", 500, nil, "One adorable baby phoenix with a rounded orange body, huge expressive navy eyes, short gold beak and feet, three broad swept orange-and-yellow crest feathers, attached compact red wings, and a dramatic fan of THREE thick layered flame-shaped tail feathers in yellow, orange and red.", {249, 170, 55}),
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

table.insert(items, item("P36", "VIP Royal Dragon", "Pets", "Pet", "VIP", 0, nil,
	"A crowned golden dragon with ruby wings. Flies beside VIP players.", {255, 195, 53}))

local suppliedThumbnails = {
	["B16"] = "rbxassetid://93718576682762",
	["B17"] = "rbxassetid://90690876218946",
	["B18"] = "rbxassetid://136532648735315",
	["B19"] = "rbxassetid://74566241696564",
	["B20"] = "rbxassetid://89577365506241",
	["B21"] = "rbxassetid://87448555104310",
	["B22"] = "rbxassetid://121107988866639",
	["B23"] = "rbxassetid://124353995030650",
	["B24"] = "rbxassetid://122610247795492",
	["B25"] = "rbxassetid://84320288725225",
	["M16"] = "rbxassetid://137233677326237",
	["M17"] = "rbxassetid://100196340349310",
	["M18"] = "rbxassetid://108922005145390",
	["M19"] = "rbxassetid://138594944253005",
	["M20"] = "rbxassetid://113055348827876",
	["M21"] = "rbxassetid://87962378887990",
	["M22"] = "rbxassetid://87262880627267",
	["M23"] = "rbxassetid://72259913966212",
	["M24"] = "rbxassetid://71753510653959",
	["M25"] = "rbxassetid://70446171295062",
	["P21"] = "rbxassetid://102415565658167",
	["P22"] = "rbxassetid://124542948595389",
	["P23"] = "rbxassetid://136302530480282",
	["P24"] = "rbxassetid://83083028780532",
	["P25"] = "rbxassetid://112851232107682",
	["P26"] = "rbxassetid://106054275413428",
	["P27"] = "rbxassetid://98519809843976",
	["P28"] = "rbxassetid://83779715530699",
	["P29"] = "rbxassetid://92025994579959",
	["P30"] = "rbxassetid://134613010096847",
	["P31"] = "rbxassetid://119087155825550",
	["P32"] = "rbxassetid://133184161504265",
	["P33"] = "rbxassetid://77099692424415",
	["P34"] = "rbxassetid://139150635065122",
	["P35"] = "rbxassetid://124088547333228",
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
	assert(entry.price >= 0 and entry.price <= COIN_PRICE_CAP, "Catalog price exceeds the coin cap")
	byId[entry.id] = entry
end

byId.M09.toyActionPending = true
for index = 16, 25 do
	byId[string.format("M%02d", index)].cosmeticOnly = true
end

return {
	Items = items,
	ById = byId,
	Categories = { "All", "Bats", "Pets", "Toys", "Emotes" },
	EmoteAnimations = emoteAnimations,
	StarterBat = "B01",
	MaxCoinPrice = COIN_PRICE_CAP,
	MaxEquipmentCoinPrice = COIN_PRICE_CAP,
	MaxToySlots = 4,
	GameNames = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It", StuckInTheMud = "Stuck in the Mud", HideAndSeek = "Hide and Seek", DuckDuckGoose = "Duck Duck Goose", All = "total" },
}
]==]},
 {path="ServerScriptService.PlaygroundAdminService",expected=1374130468,after=1190708090,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Admin = {}
Admin.__index = Admin
local controls = {
	BBStart = { game = "BritishBulldog" }, BBRunner = { game = "BritishBulldog", role = "Runner" }, BBBulldog = { game = "BritishBulldog", role = "Bulldog" },
	TagStart = { game = "TagYoureIt" }, TagRunner = { game = "TagYoureIt", role = "Runner" }, TagTagger = { game = "TagYoureIt", role = "Tagger" },
	MudStart = { game = "StuckInTheMud" }, MudShooter = { game = "StuckInTheMud", role = "Shooter" }, MudMedic = { game = "StuckInTheMud", role = "Medic" },
}
controls.HSStart = { game = "HideAndSeek" }
controls.DGStart = { game = "DuckDuckGoose" }
local aliases = { StartRound = "BBStart", PracticeRunner = "BBRunner", PracticeBulldog = "BBBulldog" }
local grants = { GrantItem = true, GrantCoins = true, AddLevels = true, GrantVIP = true, GrantBetaTester = true }

function Admin.new(coordinator, config, isStudio, playerSource)
	return setmetatable({ coordinator = coordinator, config = config, isStudio = isStudio, players = playerSource or Players, lastRequest = {}, lastStatus = {}, busy = false, connections = {} }, Admin)
end

function Admin:IsAuthorized(player)
	local userId = player and player.UserId
	if typeof(userId) ~= "number" or userId <= 0 or userId % 1 ~= 0 or userId >= 9007199254740991 then return false end
	if userId == self.config:GetAttribute("AdminUserId") then return true end
	local extraIds = self.config:GetAttribute("ExtraAdminUserIds")
	if typeof(extraIds) ~= "string" then return false end
	for token in extraIds:gmatch("[^,]+") do
		local digits = token:match("^%s*(%d+)%s*$")
		if digits and tonumber(digits) == userId then return true end
	end
	return false
end

function Admin:_target(player, payload)
	if payload ~= nil and typeof(payload) ~= "table" then return nil, "Choose a player in this server." end
	local id = player.UserId
	if payload and payload.targetUserId ~= nil then id = payload.targetUserId end
	if typeof(id) ~= "number" or id ~= id or id % 1 ~= 0 or id == 0 or math.abs(id) > 1000000000000 or (id < 0 and not self.isStudio) then
		return nil, "Choose a player in this server."
	end
	local target = self.players:GetPlayerByUserId(id)
	if not target then return nil, "That player is no longer in this server." end
	return target
end

function Admin:Status(player, ok, message, target)
	local active = self.coordinator:ActiveGame()
	local service = active and self.coordinator.services[active]
	local reply = { ok = ok, message = message or "", game = active or "", phase = service and service.phase or "Waiting", mode = service and service.state:GetAttribute("Mode") or "Waiting", role = active == "DuckDuckGoose" and player:GetAttribute("DGRole") or active == "HideAndSeek" and player:GetAttribute("HSRole") or active == "StuckInTheMud" and (player:GetAttribute("MDMuddy") and "Stuck" or "Free") or active == "TagYoureIt" and player:GetAttribute("TGRole") or player:GetAttribute("BBRole"), automatic = self.coordinator.autoEnabled }
	reply.players = {}
	for _, online in ipairs(self.players:GetPlayers()) do
		table.insert(reply.players, { userId = online.UserId, name = online.Name, displayName = online.DisplayName, ready = online:GetAttribute("PCDataReady") == true })
	end
	table.sort(reply.players, function(a, b)
		if a.name == b.name then return a.userId < b.userId end
		return a.name:lower() < b.name:lower()
	end)
	local economy = self.coordinator.economy
	if economy then
		reply.limits = table.clone(economy.AdminLimits)
		if target == false then target = nil
		else target = target or self.players:GetPlayerByUserId(player.UserId) end
		if target then
			reply.targetUserId = target.UserId
			reply.target = economy:Status(target, true)
			reply.target.userId = target.UserId
			reply.target.name = target.Name
			reply.target.displayName = target.DisplayName
		end
	end
	return reply
end

function Admin:Handle(player, action, payload)
	if not self:IsAuthorized(player) then return { ok = false, message = "Admin access required." } end
	if typeof(action) ~= "string" then return self:Status(player, false, "Unknown control.") end
	action = aliases[action] or action
	if not controls[action] and not grants[action] and action ~= "StopRound" and action ~= "GetStatus" and action ~= "ToggleAutomatic" then return self:Status(player, false, "Unknown control.") end
	local target, targetError
	if grants[action] or action == "GetStatus" then
		if grants[action] and (typeof(payload) ~= "table" or payload.targetUserId == nil) then return self:Status(player, false, "Choose a target player for this action.") end
		target, targetError = self:_target(player, payload)
		if not target then return self:Status(player, false, targetError, false) end
	end
	local now = os.clock()
	local timestamps = action == "GetStatus" and self.lastStatus or self.lastRequest
	if now - (timestamps[player] or -math.huge) < (action == "GetStatus" and 0.1 or 0.5) then return self:Status(player, false, "Please wait a moment.", target) end
	timestamps[player] = now
	if action == "GetStatus" then return self:Status(player, true, "Ready to play.", target) end
	if self.busy then return self:Status(player, false, "Another control is finishing.", target) end
	self.busy = true
	local ok, success, message = pcall(function()
		if grants[action] then
			local economy = self.coordinator.economy
			if not economy then return false, "The player economy is not ready." end
			if typeof(payload) ~= "table" then return false, "Choose an item or grant amount." end
			if action == "GrantItem" then
				return economy:AdminGrantItem(target, payload.itemId, payload.equip)
			end
			if action == "GrantCoins" then return economy:AdminGrantCoins(target, payload.amount) end
			if action == "AddLevels" then return economy:AdminAddLevels(target, payload.amount) end
			if action == "GrantVIP" then return economy:AdminGrantEntitlement(target, "VIP") end
			if action == "GrantBetaTester" then return economy:AdminGrantEntitlement(target, "BetaTester") end
		end
		if action == "StopRound" then return self.coordinator:StopGame() end
		if action == "ToggleAutomatic" then
			self.coordinator:SetAutoEnabled(not self.coordinator.autoEnabled)
			return true, self.coordinator.autoEnabled and "Automatic voting rounds are on." or "Automatic rounds paused."
		end
		local control = controls[action]
		local started, reason = self.coordinator:StartGame(control.game, player, control.role, false)
		if not started and reason == "Not enough ready players" then reason = "Use a solo button to test alone. Normal rounds need two players." end
		return started, started and "Starting your game." or reason
	end)
	self.busy = false
	if not ok then
		warn("Playground admin command failed: " .. tostring(success))
		return self:Status(player, false, "That admin action could not finish. Try again.", target)
	end
	if success and grants[action] then print("Playground admin " .. player.UserId .. " used " .. action .. " for " .. target.UserId) end
	return self:Status(player, success == true, message, target)
end

function Admin.Start(coordinator)
	local config = ServerStorage:WaitForChild("PlaygroundAdminConfig")
	local remote = ReplicatedStorage:WaitForChild("PlaygroundAdminRequest")
	local self = Admin.new(coordinator, config, RunService:IsStudio())
	self.remote = remote
	remote.OnServerInvoke = function(player, action, payload) return self:Handle(player, action, payload) end
	local function bind(player) player:SetAttribute("PlaygroundAdmin", self:IsAuthorized(player)) end
	table.insert(self.connections, Players.PlayerAdded:Connect(bind))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self.lastRequest[player] = nil self.lastStatus[player] = nil end))
	for _, player in ipairs(Players:GetPlayers()) do bind(player) end
	table.insert(self.connections, config.AttributeChanged:Connect(function() for _, player in ipairs(Players:GetPlayers()) do bind(player) end end))
	return self
end

function Admin:Destroy()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
end

return Admin
]==]},
 {path="ServerScriptService.PlaygroundCoordinator",expected=662588760,after=1489884087,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Coordinator = {}
Coordinator.__index = Coordinator
local games = { "BritishBulldog", "TagYoureIt", "StuckInTheMud", "HideAndSeek", "DuckDuckGoose" }
local INTERMISSION_SECONDS = 35
local START_RETRY_SECONDS = 5
local titles = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It", StuckInTheMud = "Stuck in the Mud", HideAndSeek = "Hide and Seek", DuckDuckGoose = "Duck Duck Goose" }

function Coordinator.new(services, lobby, economy)
	local self = setmetatable({}, Coordinator)
	self.services = services
	self.lobby = lobby
	self.economy = economy
	self.zone = lobby.Gameplay.VoteZone
	self.state = ReplicatedStorage:WaitForChild("PlaygroundState")
	self.votes = {}
	self.lastVote = {}
	self.lastSessionRequest = {}
	self.sessionConnections = {}
	self.spectators = {}
	self.lastSpectateStamp = {}
	self.lastSpectateRequest = {}
	self.connections = {}
	self.running = false
	self.autoEnabled = true
	self.votingEndsAt = 0
	self.startRetryAt = 0
	self.random = Random.new()
	self.lastGame = nil
	return self
end

function Coordinator:ActiveGame()
	for _, id in ipairs(games) do if self.services[id] and self.services[id].active then return id end end
	return nil
end

function Coordinator:_participating(player)
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true
end

function Coordinator:_afkRequested(player)
	return player:GetAttribute("PCAFK") == true or player:GetAttribute("PCAFKRequested") == true
end

function Coordinator:_syncAFK(player)
	local requested = player:GetAttribute("PCAFKRequested") == true
	local participating = self:_participating(player)
	player:SetAttribute("PCAFK", requested and not participating)
	player:SetAttribute("PCAFKQueued", requested and participating)
	if participating then self:_clearSpectate(player) end
end

function Coordinator:_clearSpectate(player)
	local entry = self.spectators[player]
	if not entry then return end
	self.spectators[player] = nil
	pcall(player.RemoveReplicationFocus, player, entry.root)
end

function Coordinator:_spectateTarget(player, userId)
	if player.Parent ~= Players or self:_participating(player) then return nil end
	local active = self:ActiveGame()
	local service = active and self.services[active]
	local phase = service and service.state:GetAttribute("Phase")
	if not service or phase == "Waiting" or phase == "Results" or phase == "Intermission" then return nil end
	local target = Players:GetPlayerByUserId(userId)
	local attribute = ({ BritishBulldog = "BBParticipating", TagYoureIt = "TGParticipating", StuckInTheMud = "MDParticipating", HideAndSeek = "HSParticipating", DuckDuckGoose = "DGParticipating" })[active]
	local character = target and target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if target == player or not target or not target:GetAttribute(attribute) or not humanoid or humanoid.Health <= 0 or not root then return nil end
	return target, root
end

function Coordinator:SetSpectate(player, userId, stamp)
	local now = workspace:GetServerTimeNow()
	if player.Parent ~= Players or typeof(stamp) ~= "number" or stamp ~= stamp or math.abs(stamp - now) > 30
		or stamp <= (self.lastSpectateStamp[player] or -math.huge) then return { ok = false, message = "Expired spectate request." } end
	self.lastSpectateStamp[player] = stamp
	if userId == 0 then self:_clearSpectate(player) return { ok = true } end
	if typeof(userId) ~= "number" or userId ~= userId or userId % 1 ~= 0 then return { ok = false, message = "Invalid player." } end
	if now - (self.lastSpectateRequest[player] or -math.huge) < 0.2 then return { ok = false, message = "Please wait a moment." } end
	self.lastSpectateRequest[player] = now
	local target, root = self:_spectateTarget(player, userId)
	if not target then self:_clearSpectate(player) return { ok = false, message = "That player is no longer in the round." } end
	local entry = self.spectators[player]
	if not entry or entry.root ~= root then
		self:_clearSpectate(player)
		local ok = pcall(player.AddReplicationFocus, player, root)
		if not ok then return { ok = false, message = "Could not load that arena. Try again." } end
		entry = { userId = userId, root = root }
		self.spectators[player] = entry
	end
	entry.expiresAt = now + 12
	return { ok = true, position = root.Position }
end

function Coordinator:_updateSpectators()
	local now = workspace:GetServerTimeNow()
	for player, entry in pairs(self.spectators) do
		local target, root = self:_spectateTarget(player, entry.userId)
		local ownHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not target or root ~= entry.root or now >= entry.expiresAt or not ownHumanoid or ownHumanoid.Health <= 0 then self:_clearSpectate(player) end
	end
end

function Coordinator:SetAFK(player, enabled)
	if player.Parent ~= Players or typeof(enabled) ~= "boolean" then
		return { ok = false, message = "Invalid AFK request." }
	end
	local now = os.clock()
	if now - (self.lastSessionRequest[player] or -math.huge) < 0.4 then
		return { ok = false, message = "Please wait a moment." }
	end
	self.lastSessionRequest[player] = now
	player:SetAttribute("PCAFKRequested", enabled)
	self:_syncAFK(player)
	if enabled then
		self.votes[player] = nil
		if self.padChoices then self.padChoices[player] = nil end
		player:SetAttribute("PCVote", "")
		self:_counts()
	end
	return {
		ok = true,
		afk = player:GetAttribute("PCAFK") == true,
		queued = player:GetAttribute("PCAFKQueued") == true,
		requested = enabled,
		message = enabled and (self:_participating(player) and "AFK after this round." or "AFK on. You will stay in the lobby.") or "AFK off. You can join the next round.",
	}
end

function Coordinator:_watchSessionPlayer(player)
	if self.sessionConnections[player] then return end
	player:SetAttribute("PCAFKRequested", false)
	player:SetAttribute("PCAFK", false)
	player:SetAttribute("PCAFKQueued", false)
	local connections = {}
	self.sessionConnections[player] = connections
	for _, name in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating", "DGParticipating" }) do
		table.insert(connections, player:GetAttributeChangedSignal(name):Connect(function()
			self:_syncAFK(player)
		end))
	end
end

function Coordinator:_readyPlayers()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not self:_afkRequested(player) and not self:_participating(player) and player:GetAttribute("PCDataReady") == true then
			table.insert(list, player)
		end
	end
	return list
end

function Coordinator:MinimumPlayers(id)
	local service=self.services[id]
	local minimum=service and service.arena and service.arena:GetAttribute("MinimumPlayers")
	if typeof(minimum)~="number" or minimum~=minimum or math.abs(minimum)==math.huge then minimum=id=="StuckInTheMud" and 4 or 2 end
	return math.max(2,math.floor(minimum))
end

function Coordinator:GameAvailable(id, readyCount)
	local service=self.services[id]
	if not service or service.running == false then return false end
	if id=="StuckInTheMud" and service.state:GetAttribute("GunAccessReady")==false then return false end
	return (readyCount or #self:_readyPlayers())>=self:MinimumPlayers(id)
end

function Coordinator:_availability(readyCount)
	self.state:SetAttribute("ReadyPlayerCount",readyCount)
	for _,id in ipairs(games) do
	 self.state:SetAttribute("Available"..id,self:GameAvailable(id,readyCount))
	 if self.services[id] then self.state:SetAttribute("Minimum"..id,self:MinimumPlayers(id)) end
	end
end

function Coordinator:_insideZone(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local point = self.zone.CFrame:PointToObjectSpace(root.Position)
	local half = self.zone.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Coordinator:_counts()
	local counts = { BritishBulldog = 0, TagYoureIt = 0, StuckInTheMud = 0, HideAndSeek = 0, DuckDuckGoose = 0 }
	for player, id in pairs(self.votes) do
		if player.Parent == Players and not self:_afkRequested(player) and counts[id] then counts[id] += 1 end
	end
	for id, count in pairs(counts) do self.state:SetAttribute("Votes" .. id, count) end
	return counts
end

function Coordinator:_clearVotes()
	for player in pairs(self.votes) do if player.Parent == Players then player:SetAttribute("PCVote", "") end end
	table.clear(self.votes)
	self:_counts()
end

function Coordinator:SetAutoEnabled(enabled)
	self.autoEnabled = enabled == true
	self.votingEndsAt = 0
	self.startRetryAt = 0
	self.state:SetAttribute("LastRoundStartError", "")
	self.state:SetAttribute("IntermissionStatus", self.autoEnabled and "Waiting for ready players" or "Automatic rounds paused by an admin")
	self.state:SetAttribute("AutomaticRounds", self.autoEnabled)
	self.state:SetAttribute("VotingEndsAt", 0)
	if not self:ActiveGame() then
		self.state:SetAttribute("Phase", self.autoEnabled and "Waiting" or "Paused")
		self:_clearVotes()
	end
end

function Coordinator:Vote(player, id)
	if typeof(id) ~= "string" or not self.services[id] then return { ok = false, message = "Choose an available game." } end
	if self.state:GetAttribute("Phase") ~= "Voting" or self:ActiveGame() or not self.autoEnabled then return { ok = false, message = "Voting opens between rounds." } end
	if self:_afkRequested(player) then return { ok = false, message = "Turn AFK off before voting." } end
	if player:GetAttribute("PCDataReady") ~= true then return { ok = false, message = "Your player data is loading." } end
	if not self:GameAvailable(id) then return {ok=false,message="This game is not ready for the next round."} end
	if self:_participating(player) or not self:_insideZone(player) then return { ok = false, message = "Walk into the voting area first." } end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return { ok = false, message = "Your character is loading." } end
	local now = os.clock()
	if now - (self.lastVote[player] or -math.huge) < 0.35 then return { ok = false, message = "Please wait a moment." } end
	self.lastVote[player] = now
	self.votes[player] = id
	player:SetAttribute("PCVote", id)
	self:_counts()
	return { ok = true, message = "Vote saved." }
end

function Coordinator:StartGame(id, player, role, automatic)
	local service = self.services[id]
	if not service then return false, "This game is not available yet." end
	if self:ActiveGame() then return false, "A game is running. Stop it first." end
	if role and (not player or self:_afkRequested(player)) then return false, "Turn AFK off before starting practice." end
	local started, reason
	if role and not service.StartPractice then return false, "This game requires a normal round." end
	if role then started, reason = service:StartPractice(player, role)
	else started, reason = service:StartRound(self:_readyPlayers()) end
	if started then
		self.votingEndsAt = 0
		self.startRetryAt = 0
		self.state:SetAttribute("VotingEndsAt", 0)
		self.state:SetAttribute("LastRoundStartError", "")
		self.state:SetAttribute("IntermissionStatus", "")
		self:_clearVotes()
		self.lastGame = id
		self.state:SetAttribute("ActiveGame", id)
		self.state:SetAttribute("GameTitle", titles[id])
		self.state:SetAttribute("Phase", "Playing")
	end
	return started, reason
end

function Coordinator:StopGame()
	local stopped = false
	for _, id in ipairs(games) do
		if self.services[id] and self.services[id].active then self.services[id]:StopRound() stopped = true end
	end
	self:SetAutoEnabled(false)
	self.state:SetAttribute("ActiveGame", "")
	self.state:SetAttribute("GameTitle", "")
	return true, stopped and "Back in the lobby." or "Ready in the lobby."
end

function Coordinator:_chooseGame()
	local counts = self:_counts()
	local readyCount=#self:_readyPlayers()
	local maximum = 0
	for _, id in ipairs(games) do if self:GameAvailable(id,readyCount) then maximum = math.max(maximum, counts[id]) end end
	local tied = {}
	for _, id in ipairs(games) do if self:GameAvailable(id,readyCount) and counts[id] == maximum then table.insert(tied, id) end end
	if maximum == 0 and self.lastGame then
		for _, id in ipairs(tied) do if id ~= self.lastGame then return id end end
	end
	return #tied>0 and tied[self.random:NextInteger(1, #tied)] or nil
end

function Coordinator:_rewardBulldog()
	local service = self.services.BritishBulldog
	if service.phase ~= "Results" then return end
	local state = service.state
	local team = state:GetAttribute("WinnerTeam")
	if team ~= "Runners" and team ~= "Bulldogs" then return end
	local winnerIds, participantIds = {}, {}
	for player, record in pairs(service.records) do
		if not record.isBot and record.participating and player.Parent == Players then
			table.insert(participantIds, player.UserId)
			if (team == "Runners" and record.role == "Runner") or (team == "Bulldogs" and record.role == "Bulldog") then table.insert(winnerIds, player.UserId) end
		end
	end
	table.sort(winnerIds)
	table.sort(participantIds)
	self.economy:AwardRound("BB:" .. tostring(state:GetAttribute("RoundNumber")), winnerIds, string.find(state:GetAttribute("Mode") or "", "Practice", 1, true) ~= nil, participantIds, { gameId = "BritishBulldog" })
end

function Coordinator:_rewardTag()
	local state = self.services.TagYoureIt.state
	local ids, participants = {}, {}
	for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids, tonumber(value)) end
	for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants, tonumber(value)) end
	self.economy:AwardRound("TAG:" .. tostring(state:GetAttribute("LastResultRound")), ids, state:GetAttribute("LastResultPractice") == true, participants, { gameId = "TagYoureIt" })
end

function Coordinator:_rewardMud()
 local service=self.services.StuckInTheMud
 if not service then return end
 local state=service.state
 local ids,participants={},{}
 for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids,tonumber(value)) end
 for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants,tonumber(value)) end
 self.economy:AwardRound("MUD:"..tostring(state:GetAttribute("LastResultRound")),ids,state:GetAttribute("LastResultPractice")==true,participants,{gameId="StuckInTheMud",winnerXP=50,loserXP=50})
end

function Coordinator:_rewardHideAndSeek()
 local service = self.services.HideAndSeek
 if not service then return end
 local state = service.state
 local ids, participants = {}, {}
 for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids, tonumber(value)) end
 for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants, tonumber(value)) end
 self.economy:AwardRound("HS:" .. tostring(state:GetAttribute("LastResultRound")), ids, state:GetAttribute("LastResultPractice") == true, participants, { gameId = "HideAndSeek" })
end

function Coordinator:_rewardDuckDuckGoose()
 local service = self.services.DuckDuckGoose
 if not service then return end
 local state = service.state
 local ids, participants = {}, {}
 for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids, tonumber(value)) end
 for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants, tonumber(value)) end
 self.economy:AwardRound("DG:" .. tostring(state:GetAttribute("LastResultRound")), ids, state:GetAttribute("LastResultPractice") == true, participants, { gameId = "DuckDuckGoose" })
end


function Coordinator:_padVoting()
 self.padChoices=self.padChoices or {}
 if self.state:GetAttribute("Phase")~="Voting" then table.clear(self.padChoices) return end
 local choices=self.lobby.Gameplay:FindFirstChild("VoteChoices")
 if not choices then return end
 for _,player in ipairs(Players:GetPlayers()) do
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local choice
  if root and not self:_afkRequested(player) and self:_insideZone(player) then
   for _,pad in ipairs(choices:GetChildren()) do
    if pad:IsA("BasePart") and pad:GetAttribute("Available")~=false then
     local point=pad.CFrame:PointToObjectSpace(root.Position)
     local half=pad.Size/2
     if math.abs(point.X)<=half.X and math.abs(point.Y)<=half.Y and math.abs(point.Z)<=half.Z then choice=pad:GetAttribute("GameId") break end
    end
   end
  end
  if choice and not self:GameAvailable(choice) then choice=nil end
  if choice~=self.padChoices[player] then
   self.padChoices[player]=choice
   if choice then self:Vote(player,choice) end
  end
 end
end

function Coordinator:_step(now)
	self:_updateSpectators()
	local active = self:ActiveGame()
	local readyCount = #self:_readyPlayers()
	self:_availability(readyCount)
	local minimum, available = math.huge, false
	for _, id in ipairs(games) do
		local service = self.services[id]
		if service and service.running ~= false and not (id == "StuckInTheMud" and service.state:GetAttribute("GunAccessReady") == false) then
			minimum = math.min(minimum, self:MinimumPlayers(id))
			available = available or self:GameAvailable(id, readyCount)
		end
	end
	if minimum == math.huge then minimum = 2 end
	self.state:SetAttribute("MinimumReadyPlayers", minimum)
	if active then
		self.votingEndsAt, self.startRetryAt = 0, 0
		self.state:SetAttribute("Phase", "Playing")
		self.state:SetAttribute("ActiveGame", active)
		self.state:SetAttribute("GameTitle", titles[active])
		self.state:SetAttribute("VotingEndsAt", 0)
		self.state:SetAttribute("IntermissionStatus", "")
	elseif not self.autoEnabled then
		self.state:SetAttribute("Phase", "Paused")
		self.state:SetAttribute("ActiveGame", "")
		self.state:SetAttribute("GameTitle", "")
		self.state:SetAttribute("IntermissionStatus", "Automatic rounds paused by an admin")
	elseif not available then
		self.votingEndsAt, self.startRetryAt = 0, 0
		self.state:SetAttribute("Phase", "Waiting")
		self.state:SetAttribute("ActiveGame", "")
		self.state:SetAttribute("GameTitle", "")
		self.state:SetAttribute("VotingEndsAt", 0)
		self.state:SetAttribute("IntermissionStatus", readyCount < minimum
			and string.format("Waiting for ready players (%d/%d)", readyCount, minimum)
			or "Waiting for an available game")
		self:_clearVotes()
	elseif self.votingEndsAt == 0 then
		self:_clearVotes()
		self.votingEndsAt = now + INTERMISSION_SECONDS
		self.state:SetAttribute("Phase", "Voting")
		self.state:SetAttribute("ActiveGame", "")
		self.state:SetAttribute("GameTitle", "")
		self.state:SetAttribute("VotingEndsAt", self.votingEndsAt)
		self.state:SetAttribute("IntermissionStatus", "Next round starts in")
		self.state:SetAttribute("LastRoundStartError", "")
	elseif now >= self.votingEndsAt and now >= self.startRetryAt then
		local selected = self:_chooseGame()
		local ok, started, reason = pcall(self.StartGame, self, selected, nil, nil, true)
		if not ok or not started then
			local failure = tostring(ok and reason or started)
			self.startRetryAt = now + START_RETRY_SECONDS
			self.state:SetAttribute("IntermissionStatus", "Preparing the next round - retrying")
			self.state:SetAttribute("LastRoundStartError", failure)
			warn("Automatic round could not start: " .. failure)
		end
	end
	self:_padVoting()
end

function Coordinator:_loop()
	while self.running do
		self:_step(workspace:GetServerTimeNow())
		task.wait(0.25)
	end
end

function Coordinator:Start()
	if self.running then return end
	self.running = true
	self.state:SetAttribute("AutomaticRounds", self.autoEnabled)
	self.state:SetAttribute("IntermissionSeconds", INTERMISSION_SECONDS)
	self.state:SetAttribute("MinimumReadyPlayers", 2)
	self.state:SetAttribute("IntermissionStatus", "Waiting for ready players")
	self.state:SetAttribute("LastRoundStartError", "")
	self.state:SetAttribute("Phase", "Waiting")
	self.state:SetAttribute("ActiveGame", "")
	self.state:SetAttribute("VotingEndsAt", 0)
	self:_counts()
	local remote = ReplicatedStorage:WaitForChild("PlaygroundVoteRequest")
	remote.OnServerInvoke = function(player, id) return self:Vote(player, id) end
	self.remote = remote
	local sessionRemote = ReplicatedStorage:WaitForChild("PlaygroundSessionRequest")
	sessionRemote.OnServerInvoke = function(player, action, value, stamp)
		if action == "SetSpectate" then return self:SetSpectate(player, value, stamp) end
		if action ~= "SetAFK" then return { ok = false, message = "Invalid session request." } end
		return self:SetAFK(player, value)
	end
	self.sessionRemote = sessionRemote
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_watchSessionPlayer(player) end))
	for _, player in ipairs(Players:GetPlayers()) do self:_watchSessionPlayer(player) end
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		self.votes[player] = nil
		self.lastVote[player] = nil
		self.lastSessionRequest[player] = nil
		self:_clearSpectate(player)
		self.lastSpectateStamp[player] = nil
		self.lastSpectateRequest[player] = nil
		for _, connection in ipairs(self.sessionConnections[player] or {}) do connection:Disconnect() end
		self.sessionConnections[player] = nil
		self:_counts()
	end))
	table.insert(self.connections, self.services.BritishBulldog.state:GetAttributeChangedSignal("Phase"):Connect(function() self:_rewardBulldog() end))
	table.insert(self.connections, self.services.TagYoureIt.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardTag() end))
	if self.services.StuckInTheMud then table.insert(self.connections,self.services.StuckInTheMud.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardMud() end)) end
	if self.services.HideAndSeek then table.insert(self.connections, self.services.HideAndSeek.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardHideAndSeek() end)) end
	if self.services.DuckDuckGoose then table.insert(self.connections, self.services.DuckDuckGoose.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardDuckDuckGoose() end)) end
	task.spawn(function() self:_loop() end)
end

function Coordinator:Stop()
	self.running = false
	self:StopGame()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
	if self.sessionRemote then self.sessionRemote.OnServerInvoke = nil end
	for player in pairs(self.spectators) do self:_clearSpectate(player) end
	table.clear(self.lastSpectateStamp)
	table.clear(self.lastSpectateRequest)
	for player, connections in pairs(self.sessionConnections) do
		for _, connection in ipairs(connections) do connection:Disconnect() end
		if player.Parent == Players then
			player:SetAttribute("PCAFKRequested", false)
			player:SetAttribute("PCAFK", false)
			player:SetAttribute("PCAFKQueued", false)
		end
	end
	table.clear(self.sessionConnections)
	table.clear(self.lastSessionRequest)
end

return Coordinator]==]}}
local function fingerprint(source)
 source = string.gsub(source,"\r\n","\n")
 local value=0
 for index=1,#source do value=(value*31+string.byte(source,index))%2147483647 end
 return value
end
local objects={}
for _,entry in entries do
 local object=game
 for name in string.gmatch(entry.path,"[^.]+") do object=object:FindFirstChild(name) assert(object,"Missing "..entry.path) end
 local hash=fingerprint(object.Source)
 assert(hash==entry.expected or hash==entry.after,"Source changed: "..entry.path)
 assert(tostring(object.Capabilities)==entry.caps and object.Sandboxed==entry.sandboxed,"Permissions changed: "..entry.path)
 objects[entry.path]=object
end
local storage=game:GetService("ServerStorage")
local backup=storage:FindFirstChild("DuckDuckGooseIntegrationBackup20261010")
if not backup then backup=Instance.new("Folder") backup.Name,backup.Parent="DuckDuckGooseIntegrationBackup20261010",storage end
local changed=0
for _,entry in entries do
 local object=objects[entry.path]
 if fingerprint(object.Source)~=entry.after then
  local snapshot=object:Clone()
  snapshot.Name=entry.path
  if snapshot:IsA("BaseScript") then snapshot.Enabled=false end
  snapshot.Parent=backup
  object.Source=entry.source
  object:SetAttribute("DuckDuckGooseIntegrated20261010",true)
  changed+=1
 end
end
return {patched=changed,capabilitiesPreserved=true,backup=backup:GetFullName()}
