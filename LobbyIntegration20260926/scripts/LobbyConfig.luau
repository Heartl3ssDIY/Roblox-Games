local Config = {}
Config.RootName = "Lobby_MainModeZone"
Config.RequestCooldown = 0.4
Config.PromptCooldown = 0.4
Config.PromptDistance = 10
Config.RootClearance = 3.5
Config.SafeLandingOffset = 0.12
Config.StoryAutoOpenRadius = 6
Config.PacksAutoOpenRadius = 6
Config.Destinations = {
 Arrival = { marker = "PlayerArrival", label = "Arrival Plaza", lookAt = "FOCUS_CentralChampion" },
 MainMode = { marker = "PORTAL_Story", label = "Story Gate", lookAt = "StoryDestination" },
 Packs = { marker = "INTERACT_Summon", label = "Summon Hall", lookAt = "SummonDestination" },
 Shop = { marker = "INTERACT_Shop", label = "Unit Shop", lookAt = "NPC_Shopkeeper" },
 Ranked = { marker = "PORTAL_Ranked", label = "Ranked Hall", lookAt = "RankedDestination" },
 PvP = { marker = "PORTAL_Unranked", label = "Duel Court", lookAt = "RankedDestination" },
 Clans = { marker = "DISTRICT_NorthGate", label = "Guild Gate", lookAt = "NorthernSanctumFastTravel" },
 Leaderboards = { marker = "INTERACT_Leaderboards", label = "Champions Court", lookAt = "DISPLAY_SeasonChampion" },
 Promenade = { marker = "ARRIVAL_Arena_Promenade", label = "Arena Portals", lookAt = "PORTAL_01_Tenkaichi" },
 Academy = { marker = "AcademyFastTravel", label = "Training Academy", lookAt = "DISTRICT_Academy" },
 Market = { marker = "MarketFastTravel", label = "Merchant Quarter", lookAt = "DISTRICT_MerchantQuarter" },
 Gardens = { marker = "OuterGardenFastTravel", label = "Moon Gardens", lookAt = "HOBBY_TeaCeremony" },
 Pagoda = { marker = "DISTRICT_CelestialPagoda", label = "Celestial Pagoda", lookAt = "ACCESS_PagodaUpperGallery" },
 Sanctum = { marker = "NorthernSanctumFastTravel", label = "Northern Sanctum", lookAt = "DISTRICT_NorthGate" },
}
Config.TravelOrder = {"Arrival","MainMode","Packs","Shop","Promenade","Ranked","PvP","Leaderboards","Academy","Market","Gardens","Pagoda","Sanctum","Clans"}
return Config
