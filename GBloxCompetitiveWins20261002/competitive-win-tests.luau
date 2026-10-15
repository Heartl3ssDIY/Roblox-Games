local passed=0
local function check(ok,message) assert(ok,message) passed+=1 end
local Players={}
local workspace={attributes={}}
function workspace:SetAttribute(key,value) self.attributes[key]=value end
local players={}
local courseNumber=1
local matchHumanCount
local matchWinEligible=false
local roundHumanCount=0
local function snapshot(roster,course)
 players=roster courseNumber=course
 local starterIds={}
 for player,data in players do
  if player.Parent==Players and data.ready and data.status~="Spectating" and data.root and data.root.Parent then
   starterIds[player.UserId]=true
  end
 end
 roundHumanCount=0
 for _ in starterIds do roundHumanCount+=1 end
 if courseNumber==1 and matchHumanCount==nil then
  matchHumanCount=roundHumanCount
  matchWinEligible=matchHumanCount>=2
  workspace:SetAttribute("RunnerMatchHumanCount",matchHumanCount)
  workspace:SetAttribute("RunnerMatchCompetitive",matchWinEligible)
 end
 workspace:SetAttribute("RunnerRoundHumanCount",roundHumanCount)

 return matchHumanCount,matchWinEligible,roundHumanCount
end
local function reset()
 matchHumanCount=nil matchWinEligible=false roundHumanCount=0 workspace.attributes={}
end
local function human(id,ready,status,root)
 return {UserId=id,Parent=Players},{ready=ready~=false,status=status or "Waiting",root=root==false and nil or {Parent=workspace}}
end
local a,ad=human(1001)
local b,bd=human(1002)
reset()
local count,eligible,roundCount=snapshot({[a]=ad},1)
check(count==1 and not eligible and roundCount==1,"Solo practice was competitive")
snapshot({[a]=ad,[b]=bd},2)
check(matchHumanCount==1 and not matchWinEligible,"Late join made a solo match competitive")
reset()
snapshot({[a]=ad,[b]=bd},1)
check(matchHumanCount==2 and matchWinEligible,"Two actual starters were not competitive")
b.Parent=nil
snapshot({[a]=ad},2)
check(matchHumanCount==2 and matchWinEligible and roundHumanCount==1,"Disconnect removed competitive eligibility")
b.Parent=Players
bd.status="Out"
check(matchWinEligible,"Elimination removed competitive eligibility")
reset()
local bot={UserId=999,Parent=workspace}
snapshot({[a]=ad,[bot]={ready=true,root={Parent=workspace}}},1)
check(matchHumanCount==1 and not matchWinEligible,"A bot counted as a real entrant")
reset()
local spectator,sd=human(1003,true,"Spectating")
snapshot({[a]=ad,[spectator]=sd},1)
check(matchHumanCount==1 and not matchWinEligible,"A spectator counted as a starter")
reset()
local loading,ld=human(1004,false)
snapshot({[a]=ad,[loading]=ld},1)
check(matchHumanCount==1 and not matchWinEligible,"An unready player counted as a starter")
reset()
local absent,absentData=human(1005)
absentData.root=nil
snapshot({[a]=ad,[absent]=absentData},1)
check(matchHumanCount==1 and not matchWinEligible,"A missing character counted as a starter")
reset()
local duplicate,dd=human(1001)
snapshot({[a]=ad,[duplicate]=dd},1)
check(matchHumanCount==1,"Duplicate user ID counted twice")
reset()
local studioA,studioAD=human(-1)
local studioB,studioBD=human(-2)
snapshot({[studioA]=studioAD,[studioB]=studioBD},1)
check(matchWinEligible,"Two Studio test players were ignored")
check(workspace.attributes.RunnerMatchCompetitive==true and workspace.attributes.RunnerMatchHumanCount==2,"Eligibility metadata not published")

local profiles={}
local PlayerData={}
local saves,syncs=0,0
local saveResult=true
function PlayerData.Save(_) saves+=1 return saveResult end
local function sync(_) syncs+=1 end
local function number(n) return math.max(0,math.floor(tonumber(n) or 0)) end
function PlayerData.AwardMatch(player,matchId,place,cash,trophies,competitive)
 local p=profiles[player]
 if not p or (not p.CanSave and not p.StudioTemporary) then return false,false end
 if p.MatchReceipts[matchId] then
  return p.StudioTemporary or PlayerData.Save(player),true
 end
 p.MatchReceipts[matchId]=os.time()
 for id,time in p.MatchReceipts do if time<os.time()-604800 then p.MatchReceipts[id]=nil end end
 if place==1 and competitive==true then p.Wins+=1 end
 p.Cash+=number(cash) p.TotalCashEarned+=number(cash) p.Trophies+=number(trophies)
 sync(player)
 return p.StudioTemporary or PlayerData.Save(player),true
end

local function profile()
 return {CanSave=true,Wins=9,Cash=100,TotalCashEarned=200,Trophies=3,MatchReceipts={}}
end
profiles[a]=profile()
local saved,recorded=PlayerData.AwardMatch(a,"solo",1,700,5,false)
check(saved and recorded and profiles[a].Wins==9,"Solo race added a win")
check(profiles[a].Cash==800 and profiles[a].TotalCashEarned==900 and profiles[a].Trophies==8,"Practice cash/trophies changed")
PlayerData.AwardMatch(a,"solo",1,700,5,true)
check(profiles[a].Wins==9 and profiles[a].Cash==800,"A retry changed an existing practice receipt")
profiles[a]=profile()
PlayerData.AwardMatch(a,"competitive",1,700,5,true)
check(profiles[a].Wins==10,"Competitive winner did not reach ten wins")
PlayerData.AwardMatch(a,"competitive",1,700,5,true)
check(profiles[a].Wins==10 and profiles[a].Cash==800,"Duplicate match was counted twice")
profiles[b]=profile()
PlayerData.AwardMatch(b,"competitive",2,400,2,true)
check(profiles[b].Wins==9,"Second place added a win")
PlayerData.AwardMatch(b,"missing-eligibility",1,400,2)
check(profiles[b].Wins==9,"Missing eligibility granted a win")
PlayerData.AwardMatch(b,"numeric-eligibility",1,400,2,2)
check(profiles[b].Wins==9,"Truthy non-boolean granted a win")
local notLoaded={}
saved,recorded=PlayerData.AwardMatch(notLoaded,"missing",1,1,1,true)
check(not saved and not recorded,"Missing profile was awarded")
profiles[a]=profile()
saveResult=false
saved,recorded=PlayerData.AwardMatch(a,"save-retry",1,100,1,true)
check(not saved and recorded and profiles[a].Wins==10,"Save-pending winner was not recorded")
saveResult=true
PlayerData.AwardMatch(a,"save-retry",1,100,1,true)
check(profiles[a].Wins==10 and profiles[a].Cash==200,"Save retry duplicated rewards")
profiles[a]=profile()
profiles[a].CanSave=false profiles[a].StudioTemporary=true
PlayerData.AwardMatch(a,"studio",1,100,1,true)
check(profiles[a].Wins==10,"Studio temporary profile failed normal competitive rules")

local function practiceLabels(breakdown,competitive)
 matchWinEligible=competitive
  if not matchWinEligible then
   for _,row in breakdown.rows do
    if row.label=="Won without abilities" then row.label="Completed without abilities"
    elseif row.label=="Podium bonus" then row.label="Completion bonus"
    elseif row.label:sub(1,8)=="Placing " then row.label="Practice completion" end
   end
  end

end
local breakdown={rows={{label="Placing 1st",cash=0,trophies=0},{label="Podium bonus",cash=1000,trophies=0},{label="Won without abilities",cash=1500,trophies=0}},cash=2500,trophies=0}
practiceLabels(breakdown,false)
check(breakdown.rows[1].label=="Practice completion" and breakdown.rows[2].label=="Completion bonus" and breakdown.rows[3].label=="Completed without abilities","Practice claims a win/place")
check(breakdown.cash==2500 and breakdown.rows[2].cash==1000 and breakdown.rows[3].cash==1500,"Practice wording changed reward amounts")
local competitiveBreakdown={rows={{label="Won without abilities",cash=1500,trophies=0}}}
practiceLabels(competitiveBreakdown,true)
check(competitiveBreakdown.rows[1].label=="Won without abilities","Competitive wording changed")
print("Competitive win assertions passed:",passed)

