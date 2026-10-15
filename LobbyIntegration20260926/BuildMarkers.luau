
assert(not game:GetService("RunService"):IsRunning(), "Exit Play first")
local root=assert(workspace:FindFirstChild("ACU_Citadel_Staging"),"Staged lobby missing")
assert(not root:FindFirstChild("Markers"),"Markers already exist")
local data=game:GetService("HttpService"):JSONDecode([==[[{"name":"ACCESS_AcademyUpperGallery","role":"walkable_upper_gallery","pos":[-192,1.2000000476837158,-49]},{"name":"ACCESS_PagodaUpperGallery","role":"walkable_upper_gallery","pos":[167.1999969482422,8,-121]},{"name":"ARRIVAL_Arena_Promenade","role":"DistrictArrival:ArenaPortals","pos":[191,1.7000000476837158,81]},{"name":"AcademyFastTravel","role":"TrainingDistrict","pos":[-172,2,-17]},{"name":"ArrivalCameraLook","role":"CameraLook","pos":[0,18,0]},{"name":"CharacterDisplay_Main","role":"ReservedRobloxCharacter","pos":[0,6.5,0]},{"name":"DAILY_REWARDS_Interaction","role":"interact_daily_rewards","pos":[29,1.2000000476837158,37.79999923706055]},{"name":"DAILY_REWARDS_NPC","role":"npc_daily_rewards","pos":[29,1.8200000524520874,33.70000076293945]},{"name":"DISPLAY_SeasonChampion","role":"season_champion","pos":[-58,3.5,-55]},{"name":"DISPLAY_StrongestUnit_A","role":"strongest_unit","pos":[-72.4000015258789,2.4000000953674316,-56]},{"name":"DISPLAY_StrongestUnit_B","role":"strongest_unit","pos":[-43.599998474121094,2.4000000953674316,-56]},{"name":"DISTRICT_Academy","role":"district_training_academy","pos":[-172,1.2000000476837158,-11]},{"name":"DISTRICT_CelestialPagoda","role":"district_celestial_pagoda","pos":[140,8,-111]},{"name":"DISTRICT_MerchantQuarter","role":"district_merchant_quarter","pos":[155,1.2000000476837158,68]},{"name":"DISTRICT_NorthGate","role":"district_outer_world_gate","pos":[0,1.2000000476837158,-213]},{"name":"FOCUS_CentralChampion","role":"landmark_focus","pos":[0,9,8]},{"name":"HOBBY_Fishing","role":"hobby_fishing","pos":[-64,2.1600000858306885,71]},{"name":"HOBBY_OuterGardenFishing","role":"hobby_fishing","pos":[-197,2.9000000953674316,130]},{"name":"HOBBY_ParkourStart","role":"hobby_parkour_start","pos":[66,1.2999999523162842,-65]},{"name":"HOBBY_TeaCeremony","role":"hobby_tea_ceremony","pos":[-166,4.5,114]},{"name":"HOBBY_Training","role":"hobby_training","pos":[-77,1.899999976158142,26]},{"name":"INTERACT_Leaderboards","role":"leaderboards","pos":[-58,1.2000000476837158,-46]},{"name":"INTERACT_LuckyCharms","role":"hobby_luckycharms","pos":[43.08612060546875,1.2000000476837158,66.50830841064453]},{"name":"INTERACT_MoonTea","role":"hobby_moontea","pos":[-44.791324615478516,1.2000000476837158,43.236881256103516]},{"name":"INTERACT_ScrollAtelier","role":"hobby_scrollatelier","pos":[-27.90656852722168,1.2000000476837158,64.46815490722656]},{"name":"INTERACT_Shop","role":"weekly_store","pos":[63,1.2000000476837158,56.5]},{"name":"INTERACT_Summon","role":"summon_packs","pos":[57,1.2000000476837158,-8]},{"name":"MASTERY_Interaction","role":"interact_mastery","pos":[-40,1.2000000476837158,11.800000190734863]},{"name":"MASTERY_NPC","role":"npc_mastery","pos":[-40,1.8200000524520874,7.699999809265137]},{"name":"MarketFastTravel","role":"MarketDistrict","pos":[155,2,112]},{"name":"NPC_CombatMentor","role":"npc_combat_mentor","pos":[-75,1.899999976158142,17]},{"name":"NPC_ForestWarden","role":"npc_forest_warden","pos":[218,1.7000000476837158,-56]},{"name":"NPC_LuckyCharms","role":"npc_merchant_luckycharms","pos":[44.11920166015625,1.2000000476837158,61.41196060180664]},{"name":"NPC_MoonGardener","role":"npc_hobby_guide","pos":[-43,1.2999999523162842,69]},{"name":"NPC_MoonTea","role":"npc_merchant_moontea","pos":[-42.76634979248047,1.2000000476837158,38.447364807128906]},{"name":"NPC_SakuraLore","role":"npc_story_lore","pos":[38,1.4500000476837158,-65]},{"name":"NPC_ScrollAtelier","role":"npc_merchant_scrollatelier","pos":[-29.142621994018555,1.2000000476837158,59.417198181152344]},{"name":"NPC_Shopkeeper","role":"npc_shop","pos":[63,1.2000000476837158,46]},{"name":"NPC_ShrineKeeper","role":"npc_secret_lore","pos":[86,1.350000023841858,-45]},{"name":"NPC_TeaMaster","role":"npc_tea_master","pos":[-162,4.449999809265137,110]},{"name":"NPC_WaterfallWanderer","role":"npc_exploration_guide","pos":[-260,2,-47]},{"name":"NewPlayerArrival","role":"PlayerSpawn","pos":[0,2.799999952316284,260]},{"name":"NorthernSanctumFastTravel","role":"SanctumDistrict","pos":[0,2,-201]},{"name":"OuterGardenFastTravel","role":"GardenDistrict","pos":[-135,2.799999952316284,127]},{"name":"PORTAL_01_Tenkaichi","role":"Teleport:Tenkaichi","pos":[201,2.0399999618530273,81]},{"name":"PORTAL_02_ChuninExamHall","role":"Teleport:ChuninExamHall","pos":[201,2.0399999618530273,93]},{"name":"PORTAL_03_Loguetown","role":"Teleport:Loguetown","pos":[202,2.0399999618530273,105]},{"name":"PORTAL_04_JujutsuHigh","role":"Teleport:JujutsuHigh","pos":[205,2.0399999618530273,117]},{"name":"PORTAL_05_Fujikasane","role":"Teleport:Fujikasane","pos":[216,2.0399999618530273,112]},{"name":"PORTAL_06_HeavensArena","role":"Teleport:HeavensArena","pos":[229,2.0399999618530273,115]},{"name":"PORTAL_07_HyperbolicTimeChamber","role":"Teleport:HyperbolicTimeChamber","pos":[226,2.0399999618530273,101]},{"name":"PORTAL_08_Wano","role":"Teleport:Wano","pos":[230,2.0399999618530273,88]},{"name":"PORTAL_09_Marineford","role":"Teleport:Marineford","pos":[219,2.0399999618530273,80]},{"name":"PORTAL_Ranked","role":"teleport_ranked","pos":[-72,1.2000000476837158,-5]},{"name":"PORTAL_Story","role":"teleport_story","pos":[0,1.2000000476837158,-66]},{"name":"PORTAL_Unranked","role":"teleport_unranked","pos":[-72,1.2000000476837158,-19]},{"name":"PlayerArrival","role":"PlayerSpawn","pos":[0,2.799999952316284,102]},{"name":"QUEST_GUIDE_Interaction","role":"interact_quest_guide","pos":[-24,1.2000000476837158,39.79999923706055]},{"name":"QUEST_GUIDE_NPC","role":"npc_quest_guide","pos":[-24,1.8200000524520874,35.70000076293945]},{"name":"RankedDestination","role":"OpenRanked","pos":[-59,2,-9]},{"name":"SECRET_EasternSpiritShrine","role":"exploration_forest_shrine","pos":[234,2.5999999046325684,-60]},{"name":"SECRET_HiddenShrine","role":"exploration_discovery","pos":[83,2.200000047683716,-47]},{"name":"SECRET_LotusTrail","role":"exploration_lotus_trail","pos":[-165,2.5,133]},{"name":"SECRET_SakuraVistaReward","role":"exploration_reward","pos":[55,14.800000190734863,-94]},{"name":"SECRET_WaterfallVista","role":"exploration_vista","pos":[-219,46,-163]},{"name":"SPAWN_PvP_Return","role":"return_pvp","pos":[-47,1.2000000476837158,-12]},{"name":"SPAWN_Story_Return","role":"return_story","pos":[0,1.2000000476837158,-53]},{"name":"SPAWN_Summon","role":"travel_summon","pos":[49,1.2000000476837158,-8]},{"name":"ShopDestination","role":"OpenShop","pos":[62,2,42]},{"name":"StoryDestination","role":"TeleportStory","pos":[0,2,-85]},{"name":"SummonDestination","role":"OpenSummon","pos":[61,2,-5]},{"name":"TownFastTravel","role":"LobbyWayfinder","pos":[0,2,141]},{"name":"VISTA_PagodaBalcony","role":"exploration_vista","pos":[140,64.80000305175781,-123]},{"name":"Waterfall_RiverBridge_WalkSurface","role":"scenic_bridge","pos":[-272,5.900000095367432,-79]},{"name":"WestMoonLake_EastBridge_WalkSurface","role":"scenic_bridge","pos":[-146,5.724999904632568,120]},{"name":"WestMoonLake_WestBridge_WalkSurface","role":"scenic_bridge","pos":[-191,6.425000190734863,111]}]]==])
local Config=assert(loadstring([==[local Config = {}
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
]==]))()
local markers=Instance.new("Folder");markers.Name="Markers";markers.Parent=root
local interactions=Instance.new("Folder");interactions.Name="Interactions";interactions.Parent=root
local scale=root:GetScale()
local pivot=root:GetPivot()
local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={root.Collision}
local function invisible(name,pos,parent)
 local part=Instance.new("Part")
 part.Name=name;part.Size=Vector3.new(.5,.2,.5);part.Position=pos
 part.Anchored=true;part.Transparency=1;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
 part.Parent=parent
 return part
end
local groundResults={}
for _,entry in ipairs(data) do
 local pos=pivot:PointToWorldSpace(Vector3.new(-entry.pos[1],entry.pos[2],-entry.pos[3])*scale)
 local preserve=entry.name:match("^NPC_") or entry.name:match("_NPC$") or entry.name:match("^DISPLAY_") or entry.name=="FOCUS_CentralChampion" or entry.name=="ArrivalCameraLook" or entry.name=="CharacterDisplay_Main"
 if not preserve then
  local hit=workspace:Raycast(pos+Vector3.new(0,3,0),Vector3.new(0,-12,0),params)
  if hit then
   pos=Vector3.new(pos.X,hit.Position.Y,pos.Z)
   table.insert(groundResults,{name=entry.name,y=pos.Y,part=hit.Instance.Name})
  else table.insert(groundResults,{name=entry.name,missingGround=true}) end
 end
 local p=invisible(entry.name,pos,markers)
 p:SetAttribute("Role",entry.role);p:SetAttribute("Configured",true);p:SetAttribute("FeatureStatus","Reserved")
 if Vector3.new(pos.X,0,pos.Z).Magnitude>.1 then p.CFrame=CFrame.lookAt(pos,Vector3.new(0,pos.Y,0)) end
end
local function marker(name) return assert(markers:FindFirstChild(name),name) end
invisible("MainModeSpawn",marker("PORTAL_Story").Position,root)
local ring=invisible("RingOuter",marker("PORTAL_Story").Position,root);ring:SetAttribute("ActivationRadius",Config.StoryAutoOpenRadius)
local packZone=Instance.new("Model");packZone.Name="Lobby_PackShopZone";packZone.Parent=root
local pack=invisible("PackShopTrigger",marker("INTERACT_Summon").Position,packZone);pack:SetAttribute("ActivationRadius",Config.PacksAutoOpenRadius)
local destinations=Instance.new("Folder");destinations.Name="Destinations";destinations.Parent=root
for _,key in ipairs({"Ranked","PvP","Clans"}) do invisible(key,marker(Config.Destinations[key].marker).Position,destinations) end
local spawn=Instance.new("SpawnLocation")
spawn.Name="SpawnLocation";spawn.Size=Vector3.new(6,.5,6)
local pos=marker("PlayerArrival").Position+Vector3.new(0,.25,0)
spawn.CFrame=CFrame.lookAt(pos,Vector3.new(0,pos.Y,0))
spawn.Anchored=true;spawn.CanCollide=false;spawn.CanTouch=false;spawn.CanQuery=false;spawn.Transparency=1;spawn.CastShadow=false
spawn.Enabled=false;spawn.Neutral=true;spawn.Duration=0;spawn.Parent=root
local promptCount=0
local function promptAt(markerName,action,label,verb,attrs)
 local p=marker(markerName)
 local attach=Instance.new("Attachment");attach.Name="Interaction";attach.Position=Vector3.new(0,2.4,0);attach.Parent=p
 local prompt=Instance.new("ProximityPrompt");prompt.Name="Interact";prompt.ActionText=verb or "Open";prompt.ObjectText=label
 prompt.RequiresLineOfSight=false;prompt.MaxActivationDistance=Config.PromptDistance;prompt.HoldDuration=0
 prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
 prompt:SetAttribute("LobbyAction",action)
 for k,v in pairs(attrs or {}) do prompt:SetAttribute(k,v) end
 prompt.Parent=attach;p:SetAttribute("FeatureStatus",action=="Notice" and "Information" or "Connected")
 promptCount+=1
end
local catalog=require(game.ReplicatedStorage.ArenaCatalog)
for _,arena in ipairs(catalog.ordered) do
 promptAt(string.format("PORTAL_%02d_%s",arena.number,arena.key),"Arena",string.format("%d · %s",arena.number,arena.displayName),"Select Arena",{ArenaKey=arena.key,FreePlay=true})
end
promptAt("PORTAL_Story","Story","Story Gate","Choose Mode")
promptAt("INTERACT_Summon","Summon","Summon Hall","Open Packs")
promptAt("INTERACT_Shop","Shop","Unit Shop","Browse")
promptAt("MASTERY_Interaction","Units","Unit Mastery","View Units")
promptAt("DAILY_REWARDS_Interaction","Arena","Daily Wins","View Rewards",{ArenaKey="Tenkaichi",FreePlay=false})
promptAt("QUEST_GUIDE_Interaction","Story","Story Guide","Choose Arena")
promptAt("PORTAL_Ranked","Notice","Ranked Hall","Information",{NoticeTitle="Ranked Hall",NoticeText="This hall is reserved for ranked battles. Ranked matchmaking and season rewards are still being configured."})
promptAt("PORTAL_Unranked","Notice","Duel Court","Information",{NoticeTitle="Duel Court",NoticeText="This court is reserved for unranked PvP. Player matchmaking will be added here."})
promptAt("INTERACT_Leaderboards","Notice","Champions Court","Information",{NoticeTitle="Champions Court",NoticeText="Champion and strongest-unit display positions are ready. Season leaderboards will be connected once the ranking rules are set."})
promptAt("NPC_CombatMentor","Units","Combat Mentor","View Team")
for _,name in ipairs({"TownFastTravel","AcademyFastTravel","MarketFastTravel","OuterGardenFastTravel","NorthernSanctumFastTravel","ARRIVAL_Arena_Promenade","SPAWN_Story_Return","SPAWN_Summon"}) do
 promptAt(name,"TravelMenu","Citadel Wayfinder","Fast Travel")
end
local arrival=marker("PlayerArrival")
invisible("ArrivalWayfinder",arrival.Position+pivot:VectorToWorldSpace(Vector3.new(7,0,4)*scale),markers)
promptAt("ArrivalWayfinder","TravelMenu","Welcome to ACU","Fast Travel")
promptAt("DISTRICT_CelestialPagoda","TravelMenu","Celestial Pagoda","Fast Travel")
root:SetAttribute("PromptCount",promptCount)
root:SetAttribute("MarkerCount",#markers:GetChildren())
root:SetAttribute("SetupState","MarkersReady")

local backup=game.ServerStorage:FindFirstChild(root:GetAttribute("BackupFolder"))
assert(backup,"Backup folder missing")
local gui=Instance.new("ScreenGui")
gui.Name="LobbyTravelGui";gui.Enabled=false;gui.ResetOnSpawn=false;gui.DisplayOrder=60;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
local shade=Instance.new("Frame");shade.Name="Dim";shade.Size=UDim2.fromScale(1,1);shade.BackgroundColor3=Color3.fromRGB(8,5,19);shade.BackgroundTransparency=.25;shade.BorderSizePixel=0;shade.Active=true;shade.Parent=gui
local panel=Instance.new("Frame");panel.Name="Panel";panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.Size=UDim2.fromScale(.9,.85);panel.BackgroundColor3=Color3.fromRGB(24,14,44);panel.BorderSizePixel=0;panel.Parent=gui
local max=Instance.new("UISizeConstraint");max.MaxSize=Vector2.new(620,560);max.Parent=panel
local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,16);corner.Parent=panel
local stroke=Instance.new("UIStroke");stroke.Thickness=2;stroke.Color=Color3.fromRGB(240,187,65);stroke.Parent=panel
local function text(name,value,size,pos,parent)
 local t=Instance.new("TextLabel");t.Name=name;t.Text=value;t.Size=size;t.Position=pos;t.BackgroundTransparency=1;t.Font=Enum.Font.PermanentMarker;t.TextColor3=Color3.fromRGB(255,241,198);t.TextStrokeColor3=Color3.fromRGB(30,7,61);t.TextStrokeTransparency=0;t.TextScaled=true;t.Parent=parent
 local limit=Instance.new("UITextSizeConstraint");limit.MaxTextSize=28;limit.MinTextSize=12;limit.Parent=t
 return t
end
text("Title","LOBBY TRAVEL",UDim2.new(1,-88,0,44),UDim2.fromOffset(22,14),panel).TextXAlignment=Enum.TextXAlignment.Left
local sub=text("Subtitle","CHOOSE A DISTRICT",UDim2.new(1,-44,0,24),UDim2.fromOffset(22,59),panel);sub.TextXAlignment=Enum.TextXAlignment.Left;sub.TextColor3=Color3.fromRGB(189,155,236)
local close=Instance.new("TextButton");close.Name="Close";close.Text="X";close.Font=Enum.Font.PermanentMarker;close.TextSize=23;close.TextColor3=Color3.new(1,1,1);close.BackgroundColor3=Color3.fromRGB(145,35,65);close.Size=UDim2.fromOffset(42,42);close.Position=UDim2.new(1,-58,0,16);close.BorderSizePixel=0;close.Parent=panel
local cc=Instance.new("UICorner");cc.CornerRadius=UDim.new(0,10);cc.Parent=close
local list=Instance.new("ScrollingFrame");list.Name="Destinations";list.BackgroundTransparency=1;list.BorderSizePixel=0;list.Position=UDim2.fromOffset(18,100);list.Size=UDim2.new(1,-36,1,-143);list.ScrollBarThickness=5;list.ScrollBarImageColor3=Color3.fromRGB(236,193,69);list.CanvasSize=UDim2.fromOffset(0,0);list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.Parent=panel
local grid=Instance.new("UIGridLayout");grid.CellSize=UDim2.new(.5,-7,0,46);grid.CellPadding=UDim2.fromOffset(10,10);grid.SortOrder=Enum.SortOrder.LayoutOrder;grid.Parent=list
for i,key in ipairs(Config.TravelOrder) do
 local b=Instance.new("TextButton");b.Name=key;b:SetAttribute("Destination",key);b.Text=Config.Destinations[key].label;b.Font=Enum.Font.PermanentMarker;b.TextColor3=Color3.fromRGB(255,243,213);b.TextStrokeColor3=Color3.fromRGB(29,10,58);b.TextStrokeTransparency=0;b.TextSize=18;b.TextScaled=true;b.BackgroundColor3=Color3.fromRGB(59,30,91);b.BorderSizePixel=0;b.LayoutOrder=i;b.Parent=list
 local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,8);c.Parent=b
 local st=Instance.new("UIStroke");st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;st.Color=Color3.fromRGB(132,80,187);st.Parent=b
 local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,9);pad.PaddingRight=UDim.new(0,9);pad.Parent=b
 local lim=Instance.new("UITextSizeConstraint");lim.MaxTextSize=18;lim.MinTextSize=10;lim.Parent=b
end
text("Footer","ANIME COMBAT UNITS",UDim2.new(1,-36,0,23),UDim2.new(0,18,1,-32),panel).TextColor3=Color3.fromRGB(225,183,70)
gui.Parent=backup
return game:GetService("HttpService"):JSONEncode({markers=#markers:GetChildren(),prompts=promptCount,ground=groundResults,travelButtons=#Config.TravelOrder,guiStaged=true})
