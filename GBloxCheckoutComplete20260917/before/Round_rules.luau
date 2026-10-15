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
function M.Build(place,count,result,petId,pet)
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
 local cm=pet and pet.CashMultiplier or 1
 local tm=pet and pet.TrophyMultiplier or 1
 local totalCash=math.floor(cash*cm+.5)
 local totalTrophies=math.floor(trophies*tm+.5)
 if pet then
  add(petId.." x"..tostring(cm).." cash",totalCash-cash,0)
  add(petId.." x"..tostring(tm).." trophies",0,totalTrophies-trophies)
 end
 return {place=place,playerCount=count,time=result.time,deaths=result.deaths or (result.died and 1 or 0),
  score=result.score,finishes=result.finishes,rows=rows,cash=totalCash,trophies=totalTrophies,
  baseScale=scale,pet=petId,cashMultiplier=cm,trophyMultiplier=tm}
end
return M

