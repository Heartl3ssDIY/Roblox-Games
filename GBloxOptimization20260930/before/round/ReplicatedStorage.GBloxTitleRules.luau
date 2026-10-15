-- Shared title catalogue and pure, server-authoritative unlock rules.
local R={}
-- September 21 is inclusive: September 22, 2026 00:00 Europe/London (BST).
R.BetaCutoff=1790031600
R.List={
 {Id="BetaTester",Name="Beta Tester",Beta=true,Color=Color3.fromRGB(81,242,230)},
 {Id="Rookie",Name="Rookie",Wins=1,Color=Color3.fromRGB(224,236,244)},
 {Id="RisingStar",Name="Rising Star",Wins=5,Color=Color3.fromRGB(175,234,255)},
 {Id="Challenger",Name="Challenger",Wins=10,Color=Color3.fromRGB(114,223,255)},
 {Id="Contender",Name="Contender",Wins=25,Color=Color3.fromRGB(75,218,220)},
 {Id="Speedster",Name="Speedster",Wins=50,Color=Color3.fromRGB(69,245,187)},
 {Id="FrontRunner",Name="Front Runner",Wins=100,Color=Color3.fromRGB(111,246,123)},
 {Id="Champion",Name="Champion",Wins=250,Color=Color3.fromRGB(226,241,98)},
 {Id="Elite",Name="Elite",Wins=500,Color=Color3.fromRGB(255,218,102)},
 {Id="Master",Name="Master",Wins=1000,Color=Color3.fromRGB(255,183,96)},
 {Id="Grandmaster",Name="Grandmaster",Wins=2500,Color=Color3.fromRGB(255,142,109)},
 {Id="Legend",Name="Legend",Wins=5000,Color=Color3.fromRGB(255,117,166)},
 {Id="Mythic",Name="Mythic",Wins=10000,Color=Color3.fromRGB(218,137,255)},
 {Id="Immortal",Name="Immortal",Wins=25000,Color=Color3.fromRGB(182,147,255)},
 {Id="GravitySovereign",Name="Gravity Sovereign",Wins=50000,Color=Color3.fromRGB(135,174,255)},
 {Id="Transcendent",Name="Transcendent",Wins=100000,Color=Color3.fromRGB(137,238,255)},
 {Id="BeyondInfinity",Name="Beyond Infinity",Wins=250000,Color=Color3.fromRGB(255,239,170)},
}
R.ById={}
for _,d in R.List do R.ById[d.Id]=d end
local function integer(n)
 return typeof(n)=="number" and n==n and n>=0 and n<math.huge and math.floor(n) or 0
end
function R.Unlocked(s,id)
 local d=R.ById[id]
 if not d then return false end
 return d.Beta and s.BetaTester==true or not d.Beta and integer(s.HighestWins)>=d.Wins
end
function R.Sanitize(raw,wins)
 raw=typeof(raw)=="table" and raw or {}
 local s={Version=1,BetaTester=raw.BetaTester==true,
  FirstPlayedAt=integer(raw.FirstPlayedAt),HighestWins=math.max(integer(raw.HighestWins),integer(wins)),
  Equipped=typeof(raw.Equipped)=="string" and raw.Equipped or ""}
 if s.Equipped~="" and not R.Unlocked(s,s.Equipped) then s.Equipped="" end
 return s
end
function R.Arrive(raw,wins,joinedAt,createdMs,legacyStarted)
 local s=R.Sanitize(raw,wins)
 local earliest=integer(joinedAt)
 for _,value in {s.FirstPlayedAt,integer(createdMs)/1000,integer(legacyStarted)} do
  if value>0 and value<=joinedAt and (earliest==0 or value<earliest) then earliest=math.floor(value) end
 end
 s.FirstPlayedAt=earliest
 s.BetaTester=s.BetaTester or (earliest>0 and earliest<R.BetaCutoff)
 if typeof(raw)~="table" and s.BetaTester then s.Equipped="BetaTester" end
 return s
end
function R.Select(raw,wins,id)
 local s=R.Sanitize(raw,wins)
 if typeof(id)~="string" or #id>64 or (id~="" and not R.Unlocked(s,id)) then
  return false,"That title is locked.",s
 end
 s.Equipped=id
 return true,id=="" and "Title unequipped." or (R.ById[id].Name.." equipped."),s
end
function R.Sync(player,profile)
 profile.Titles=R.Sanitize(profile.Titles,profile.Wins)
 local s=profile.Titles local d=R.ById[s.Equipped]
 player:SetAttribute("GBloxBetaTester",s.BetaTester)
 player:SetAttribute("GBloxTitleHighestWins",s.HighestWins)
 player:SetAttribute("GBloxEquippedTitle",s.Equipped)
 player:SetAttribute("GBloxTitleName",d and d.Name or "")
 player:SetAttribute("GBloxTitleColor",d and d.Color or Color3.new(1,1,1))
end
return R

