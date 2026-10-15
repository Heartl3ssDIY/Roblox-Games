local Catalog = {}

Catalog.Gamepasses = {
 TripleOpen = 1981952807, -- Add the supplied 3-egg gamepass ID here.
 AutoOpen = 1986410259, -- Add the supplied auto-open gamepass ID here.
}

Catalog.Products = {
 OrbitSingle = 3713207054, -- Add the 249 Robux developer product ID here.
}

Catalog.Images = {
 Velocity = "rbxassetid://110022336090832",
 Gravity = "rbxassetid://86762504154551",
 Orbit = "rbxassetid://75704086419090",
 VelocityOne = "rbxassetid://98308203687023",
 VelocityThree = "rbxassetid://111125144566157",
 GravityOne = "rbxassetid://124922484834219",
 GravityThree = "rbxassetid://94966086406125",
 OrbitOne = "rbxassetid://102413858920436",
 Auto = "rbxassetid://134573582746562",
}

Catalog.Eggs = {
 Gravity = {
  Currency = "Trophies",
  SingleCost = 500,
  TripleCost = 1400,
  Pets = {
   {Id="Ostrich",Chance=50,CashMultiplier=2.8,TrophyMultiplier=1.9},
   {Id="Hummingbird",Chance=35,CashMultiplier=4,TrophyMultiplier=2.5},
   {Id="Bat",Chance=10,CashMultiplier=8.5,TrophyMultiplier=5},
   {Id="Eagle",Chance=4,CashMultiplier=12,TrophyMultiplier=8},
   {Id="Falcon",Chance=1,CashMultiplier=15,TrophyMultiplier=11},
  },
 },
 Velocity = {
  Currency = "Trophies",
  SingleCost = 150,
  TripleCost = 420,
  Pets = {
   {Id="Horse",Chance=50,CashMultiplier=1.2,TrophyMultiplier=1},
   {Id="Bloodhound",Chance=35,CashMultiplier=1.5,TrophyMultiplier=1.2},
   {Id="Hare",Chance=10,CashMultiplier=2.5,TrophyMultiplier=1.5},
   {Id="Lion",Chance=4,CashMultiplier=3.8,TrophyMultiplier=2.5},
   {Id="Cheetah",Chance=1,CashMultiplier=8,TrophyMultiplier=4},
  },
 },
 Orbit = {
  Currency = "Robux",
  RobuxPrice = 249,
  ProductId = 3713207054,
  Pets = {
   {Id="Orca",Chance=85,CashMultiplier=3,TrophyMultiplier=2},
   {Id="Swordfish",Chance=10,CashMultiplier=15,TrophyMultiplier=5},
   {Id="Shark",Chance=4.5,CashMultiplier=25,TrophyMultiplier=12},
   {Id="Alien",Chance=.5,CashMultiplier=45,TrophyMultiplier=20},
  },
 },
}

function Catalog.GetPet(petId)
 for eggName,egg in Catalog.Eggs do
  for _,pet in egg.Pets do
   if pet.Id==petId then return pet,eggName end
  end
 end
end

return Catalog

