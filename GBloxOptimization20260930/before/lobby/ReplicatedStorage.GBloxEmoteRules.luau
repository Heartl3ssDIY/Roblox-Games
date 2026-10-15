local C=require(game.ReplicatedStorage:WaitForChild("GBloxEmoteCatalog"))
local R={}
function R.Sanitize(raw)
 raw=typeof(raw)=="table" and raw or {}
 local s={Owned={},Equipped={}}
 for id,owned in typeof(raw.Owned)=="table" and raw.Owned or {} do
  if typeof(id)=="string" and C.ById[id] and owned==true then s.Owned[id]=true end
 end
 local used={}
 for _,id in typeof(raw.Equipped)=="table" and raw.Equipped or {} do
  if typeof(id)=="string" and s.Owned[id] and not used[id] and #s.Equipped<C.MaxEquipped then
   used[id]=true table.insert(s.Equipped,id)
  end
 end
 return s
end
function R.IsEquipped(s,id) return table.find(s.Equipped,id)~=nil end
function R.Buy(profile,id)
 if typeof(id)~="string" or not C.ById[id] then return false,"Unknown emote." end
 local s=R.Sanitize(profile.Emotes)
 if s.Owned[id] then return true,"You already own this emote.",false end
 if typeof(profile.Trophies)~="number" or profile.Trophies~=profile.Trophies or profile.Trophies<C.Price or profile.Trophies==math.huge then return false,"Not enough trophies." end
 profile.Trophies-=C.Price s.Owned[id]=true
 if #s.Equipped<C.MaxEquipped then table.insert(s.Equipped,id) end
 profile.Emotes=s
 return true,"Emote unlocked in G-Blox!",true
end
function R.Equip(profile,id,equip)
 if typeof(id)~="string" or not C.ById[id] or typeof(equip)~="boolean" then return false,"Unknown emote." end
 local s=R.Sanitize(profile.Emotes)
 if not s.Owned[id] then return false,"You do not own that emote." end
 local index=table.find(s.Equipped,id)
 if equip and not index then
  if #s.Equipped>=C.MaxEquipped then return false,"Eight emotes equipped. Unequip one first." end
  table.insert(s.Equipped,id)
 elseif not equip and index then table.remove(s.Equipped,index) end
 profile.Emotes=s
 return true,equip and "Emote equipped for the podium." or "Emote unequipped."
end
function R.Sync(player,profile)
 profile.Emotes=R.Sanitize(profile.Emotes)
 for _,e in C.List do
  player:SetAttribute("GBloxEmoteOwned_"..e.Id,profile.Emotes.Owned[e.Id]==true)
  player:SetAttribute("GBloxEmoteEquipped_"..e.Id,R.IsEquipped(profile.Emotes,e.Id))
 end
 player:SetAttribute("GBloxEmoteSlotsUsed",#profile.Emotes.Equipped)
 player:SetAttribute("GBloxEmotesRevision",(player:GetAttribute("GBloxEmotesRevision") or 0)+1)
end
return R
