-- Preserve the existing match economy. Only the breakdown/display is new.
local M={}
function M.Rank(entries)
 table.sort(entries,function(a,b)
  if math.abs(a.result.score-b.result.score)>.00001 then return a.result.score>b.result.score end
  if a.result.time~=b.result.time then return a.result.time<b.result.time end
  return a.player.UserId<b.player.UserId
 end)
 return entries
end
function M.Build(place,count,result,petId,pet,petList,cashPass,trophyPass)
 local rows={}
 local scale=math.clamp((count-1)*.2,0,1)
 local cash=math.floor(math.max(0,3000-place*500)*scale+.000001)
 local trophies=math.floor((({10,5,3})[place] or 0)*scale+.000001)
 local function add(label,c,t)
  table.insert(rows,{label=label,cash=c,trophies=t}) 
 end
 add("Placing "..(({"1st","2nd","3rd","4th","5th","6th"})[place] or tostring(place)),cash,trophies)
 if place<=3 then cash+=1000 add("Podium bonus",1000,0) end
 if result.score>=49.999 then cash+=10000 trophies+=5 add("Perfect score",10000,5) end
 if place==1 and not result.usedAbility then cash+=1500 add("Won without abilities",1500,0) end
 if not result.died then cash+=5000 add("No deaths",5000,0) end
 local cm,tm=1,1
 local totalCash,totalTrophies=cash,trophies
 petList=petList or (pet and {{Id=petId,CashMultiplier=pet.CashMultiplier,TrophyMultiplier=pet.TrophyMultiplier}} or {})
 for _,entry in petList do
  cm+=entry.CashMultiplier-1 tm+=entry.TrophyMultiplier-1
  local nextCash=math.floor(cash*cm+.5)
  local nextTrophies=math.floor(trophies*tm+.5)
  add(entry.Id.." x"..entry.CashMultiplier.." cash",nextCash-totalCash,0)
  add(entry.Id.." x"..entry.TrophyMultiplier.." trophies",0,nextTrophies-totalTrophies)
  totalCash,totalTrophies=nextCash,nextTrophies
 end
 cashPass=cashPass or 1 trophyPass=trophyPass or 1
 if cashPass>1 then
  local boosted=math.floor(totalCash*cashPass+.5) add("Cash pass x"..cashPass,boosted-totalCash,0) totalCash=boosted
 end
 if trophyPass>1 then
  local boosted=math.floor(totalTrophies*trophyPass+.5) add("Trophy pass x"..trophyPass,0,boosted-totalTrophies) totalTrophies=boosted
 end
 return {place=place,playerCount=count,time=result.time,deaths=result.deaths or (result.died and 1 or 0),
  score=result.score,finishes=result.finishes,rows=rows,cash=totalCash,trophies=totalTrophies,
  baseScale=scale,pet=petId,cashMultiplier=cm,trophyMultiplier=tm}
end
return M

