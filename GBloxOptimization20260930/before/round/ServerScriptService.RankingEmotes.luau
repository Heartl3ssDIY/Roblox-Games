-- Only defaults and emotes returned by Roblox for this player's avatar are allowed.
-- Clients send a selection key, never an animation ID.
local Players=game:GetService("Players")
local InsertService=game:GetService("InsertService")
local Emotes={}
local profiles={}
local ShopCatalog=require(game.ReplicatedStorage:WaitForChild("GBloxEmoteCatalog"))
local ShopRules=require(game.ReplicatedStorage:WaitForChild("GBloxEmoteRules"))
local Data=require(game.ServerScriptService:WaitForChild("PlayerData"))
local function shopEntry(player,key)
 if typeof(key)~="string" or key:sub(1,5)~="shop:" then return nil end
 local p=Data.Get(player) if not p then return nil end
 local id=key:sub(6) local state=ShopRules.Sanitize(p.Emotes)
 return state.Owned[id] and ShopRules.IsEquipped(state,id) and ShopCatalog.ById[id] or nil
end
local cache={}
local function resolve(assetIds)
 for _,assetId in assetIds or {} do
  if cache[assetId] then return cache[assetId] end
  local loaded,container=pcall(function() return InsertService:LoadAsset(assetId) end)
  if loaded and container then
   local animation=container:FindFirstChildWhichIsA("Animation",true)
   local id=animation and animation.AnimationId
   container:Destroy() -- Never parent or run code from an emote asset.
   if id and id~="" then cache[assetId]=id return id end
  end
 end
end
function Emotes.Register(player)
 local profile={options={{key="idle",name="Idle"},{key="wave",name="Wave"},{key="cheer",name="Cheer"},{key="dance",name="Dance"}},
  allowed={idle=true,wave=true,cheer=true,dance=true},animations={},catalog={},selected="idle",revision=0}
 profiles[player]=profile
 player:SetAttribute("RankingEmote","idle")
 player:SetAttribute("RankingEmotesLoaded",false)
 task.spawn(function()
  local description
  for attempt=1,3 do
   if profiles[player]~=profile or not player.Parent then return end
   local ok,value=pcall(function() return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId) end)
   if ok then description=value break end
   if attempt<3 then task.wait(1) end
  end
  if not description then
   if profiles[player]==profile and player.Parent then player:SetAttribute("RankingEmotesLoaded",true) end
   return
  end
  if profiles[player]~=profile then description:Destroy() return end
  local nativeEmotes=description:GetEmotes()
  description:Destroy()
  local names={}
  for name in nativeEmotes do table.insert(names,name) end
  table.sort(names)
  for _,name in names do
   local key="avatar:"..name
   profile.allowed[key]=true profile.catalog[key]=nativeEmotes[name]
   table.insert(profile.options,{key=key,name=name})
  end
  player:SetAttribute("RankingEmotesLoaded",true)
  -- Resolve in the background; one slow asset does not hide the whole list.
  for _,option in profile.options do
   if profile.catalog[option.key] then
    task.spawn(function()
     local id=resolve(profile.catalog[option.key])
     if profiles[player]~=profile then return end
     profile.animations[option.key]=id
     option.animationId=id -- Existing inter-round viewport previews use this.
    end)
   end
  end
 end)
end
function Emotes.Options(player)
 local options={} for _,v in profiles[player] and profiles[player].options or {} do table.insert(options,v) end
 local p=Data.Get(player)
 if p then
  for _,id in ShopRules.Sanitize(p.Emotes).Equipped do
   local e=ShopCatalog.ById[id]
   table.insert(options,{key="shop:"..id,name=e.Name,animationId=e.AnimationId})
  end
 end
 return options
end
function Emotes.Select(player,key)
 local profile=profiles[player]
 if not profile or typeof(key)~="string" or #key>150 or (not profile.allowed[key] and not shopEntry(player,key)) then return false end
 if os.clock()-(profile.lastChange or -math.huge)<.2 then return false end
 profile.lastChange=os.clock() profile.selected=key
 player:SetAttribute("RankingEmote",key)
 return true
end
function Emotes.Selected(player)
 return profiles[player] and profiles[player].selected or "idle"
end
function Emotes.AnimationId(player,key)
 local e=shopEntry(player,key)
 if typeof(key)=="string" and key:sub(1,5)=="shop:" then return e and e.AnimationId end
 return profiles[player] and profiles[player].animations[key]
end
function Emotes.PlayPodium(player,key)
 local profile=profiles[player]
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local shop=shopEntry(player,key)
 if not profile or (not profile.allowed[key] and not shop) or profile.selected~=key
  or not player:GetAttribute("GBloxPodiumActive") or not humanoid
  or humanoid.RigType~=Enum.HumanoidRigType.R15 then return false end
 profile.revision+=1
 local revision=profile.revision
 local function current()
  return profiles[player]==profile and profile.revision==revision and profile.selected==key
   and player.Parent and player.Character==character and humanoid.Parent
   and player:GetAttribute("GBloxPodiumActive")
 end
 if profile.track then profile.track:Stop(.12) profile.track:Destroy() profile.track=nil end
 player:SetAttribute("GBloxPodiumEmoteError",nil)
 -- The four free poses are rendered for everyone by GBloxPodiumVisuals.
 if not profile.catalog[key] and not shop then return true end
 local id=shop and shop.AnimationId or profile.animations[key] or resolve(profile.catalog[key])
 if not current() then return false end
 if not id then
  player:SetAttribute("GBloxPodiumEmoteError","That emote couldn't load. Please try another.")
  return false
 end
 profile.animations[key]=id
 local animator=humanoid:FindFirstChildOfClass("Animator")
 if not animator then animator=Instance.new("Animator",humanoid) end
 local animation=Instance.new("Animation") animation.AnimationId=id
 local ok,track=pcall(function() return animator:LoadAnimation(animation) end)
 animation:Destroy()
 if not ok or not track then
  if current() then player:SetAttribute("GBloxPodiumEmoteError","That emote couldn't play. Please try another.") end
  return false
 end
 if not current() then track:Destroy() return false end
 profile.track=track
 track.Priority=Enum.AnimationPriority.Action
 track.Looped=true
 track:Play(.15)
 -- LoadAnimation may return a track even when asset loading is denied.
 local deadline=os.clock()+5
 while current() and track.Length==0 and os.clock()<deadline do task.wait(.1) end
 if not current() then
  if profile.track==track then profile.track=nil track:Stop(0) track:Destroy() end
  return false
 end
 if track.Length==0 then
  profile.track=nil track:Stop(0) track:Destroy()
  player:SetAttribute("GBloxPodiumEmoteError","That emote isn't available here. Please try another.")
  return false
 end
 return true
end
function Emotes.Remove(player)
 local profile=profiles[player]
 profiles[player]=nil
 if profile and profile.track then profile.track:Stop(0) profile.track:Destroy() end
end
return Emotes

