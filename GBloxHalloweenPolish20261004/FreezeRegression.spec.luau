local Effects = require("./ServerScriptService.GBloxAbilityEffects.after")
local zero = {X=0, Y=0, Z=0}
getfenv(Effects.new).Vector3 = {zero=zero}

local assertions = 0
local scenarios = 0
local function equal(actual, expected, label)
    assertions += 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function root()
    local part = {Parent=true, Anchored=false, AssemblyLinearVelocity="moving", AssemblyAngularVelocity="turning", owners=0}
    function part:SetNetworkOwner(player) self.owner=player self.owners+=1 end
    return part
end
local function fixture()
    local attrs = {}
    local player = {Parent=true}
    function player:SetAttribute(name,value) attrs[name]=value end
    local data = {root=root(),status="Running",humanoid={Health=100},velocity={LineVelocity=18},recovering=false}
    data.runTrack = {}
    function data.runTrack:AdjustSpeed(speed) self.speed=speed end
    local now, phase, round = 100, "Running", 1
    local runners = {[player]=data}
    local context = {
        Runners=runners, Now=function() return now end, Phase=function() return phase end,
        RoundKey=function() return round end, BoostMultiplier=2,
        SetSpeed=function(target,speed) target.mockSpeed=speed end,
    }
    return {
        player=player,data=data,attrs=attrs,runners=runners,effects=Effects.new(context),
        time=function(value) now=value end,phase=function(value) phase=value end,round=function(value) round=value end,
    }
end
local function scenario(name,callback)
    scenarios += 1
    callback(fixture())
    print("PASS " .. name)
end

scenario("Seasonal freeze releases at exactly five seconds",function(f)
    local untilTime=f.effects.FreezeSeasonal(f.player,5)
    equal(untilTime,105,"reported seasonal deadline")
    equal(f.data.freezeUntil,105,"server movement freeze deadline")
    equal(f.attrs.GBloxFrozenUntil,105,"client combined deadline")
    equal(f.attrs.GBloxHalloweenHeldUntil,105,"client seasonal deadline")
    equal(f.data.root.Anchored,true,"initial immobilization")
    equal(f.data.root.AssemblyLinearVelocity,zero,"linear velocity cleared")
    equal(f.data.root.AssemblyAngularVelocity,zero,"angular velocity cleared")
    equal(f.data.velocity.LineVelocity,0,"runner velocity cleared")
    equal(f.data.runTrack.speed,0,"run animation paused")
    f.time(104.999) f.effects.Step()
    equal(f.data.root.Anchored,true,"not released early")
    f.time(105) f.effects.Step()
    equal(f.data.root.Anchored,false,"released at deadline")
    equal(f.data.freezeUntil,nil,"server freeze cleared")
    equal(f.attrs.GBloxFrozenUntil,nil,"combined client deadline cleared")
    equal(f.attrs.GBloxHalloweenHeldUntil,nil,"seasonal client deadline cleared")
    equal(f.data.root.owner,f.player,"client physics ownership restored")
    equal(f.data.root.owners,1,"ownership restored once")
    f.time(106) f.effects.Step()
    equal(f.data.root.owners,1,"empty state does not repeat release")
end)

scenario("Cancelling seasonal hold preserves longer paid Freeze",function(f)
    f.effects.Freeze(f.player,10)
    f.effects.FreezeSeasonal(f.player,5)
    f.time(102) f.effects.ClearSeasonalFreeze(f.player)
    equal(f.data.root.Anchored,true,"paid Freeze still anchors")
    equal(f.data.freezeUntil,110,"paid deadline preserved")
    equal(f.attrs.GBloxFrozenUntil,110,"paid client deadline preserved")
    equal(f.attrs.GBloxHalloweenHeldUntil,nil,"seasonal deadline removed")
    equal(f.data.root.owners,0,"not released during overlap")
    f.time(110) f.effects.Step()
    equal(f.data.root.Anchored,false,"released when paid Freeze expires")
    equal(f.attrs.GBloxFrozenUntil,nil,"paid expiry cleared")
end)

scenario("Paid expiry cannot release an active seasonal hold",function(f)
    f.effects.Freeze(f.player,2)
    f.effects.FreezeSeasonal(f.player,5)
    f.time(102) f.effects.Step()
    equal(f.data.root.Anchored,true,"seasonal freeze survives paid expiry")
    equal(f.data.freezeUntil,105,"seasonal deadline preserved")
    equal(f.attrs.GBloxHalloweenHeldUntil,105,"seasonal client hold preserved")
    equal(f.data.root.owners,0,"paid expiry does not restore physics")
    f.time(105) f.effects.Step()
    equal(f.data.root.Anchored,false,"released at seasonal deadline")
end)

scenario("Seasonal expiry cannot release a still-active paid Freeze",function(f)
    f.effects.Freeze(f.player,10)
    f.effects.FreezeSeasonal(f.player,5)
    f.time(105) f.effects.Step()
    equal(f.data.root.Anchored,true,"paid Freeze survives seasonal expiry")
    equal(f.data.freezeUntil,110,"longer paid deadline remains")
    equal(f.attrs.GBloxHalloweenHeldUntil,nil,"expired seasonal flag removed")
    f.time(110) f.effects.Step()
    equal(f.data.root.Anchored,false,"eventual paid expiry releases")
end)

scenario("Loading cleanup never unanchors a spawn root",function(f)
    f.effects.FreezeSeasonal(f.player,5)
    f.data.status="Loading"
    f.effects.ClearSeasonalFreeze(f.player)
    equal(f.data.root.Anchored,true,"direct seasonal cancellation respects loading")
    f.effects.Step()
    equal(f.data.root.Anchored,true,"loading cleanup keeps spawn anchored")
    equal(f.data.root.owners,0,"loading root never assigned ownership")
    equal(f.data.freezeUntil,nil,"loading freeze state cleared")
    equal(f.attrs.GBloxFrozenUntil,nil,"loading combined attribute cleared")
    equal(f.attrs.GBloxHalloweenHeldUntil,nil,"loading seasonal attribute cleared")
end)

scenario("Recovery cleanup never releases the recovery anchor",function(f)
    f.effects.Freeze(f.player,10)
    f.effects.FreezeSeasonal(f.player,5)
    f.data.recovering=true
    f.effects.Step()
    equal(f.data.root.Anchored,true,"recovery anchor retained")
    equal(f.data.root.owners,0,"recovery ownership untouched")
    equal(f.data.freezeUntil,nil,"recovery stale deadline cleared")
    equal(f.attrs.GBloxFrozenUntil,nil,"recovery client deadline cleared")
    equal(f.attrs.GBloxHalloweenHeldUntil,nil,"recovery seasonal flag cleared")
    f.data.recovering=false
    f.time(111) f.effects.Step()
    equal(f.data.root.Anchored,true,"discarded old state cannot later release recovery")
end)

scenario("Intermission cancellation never unanchors a result root",function(f)
    f.effects.FreezeSeasonal(f.player,5)
    f.phase("Intermission")
    f.effects.ClearSeasonalFreeze(f.player)
    equal(f.data.root.Anchored,true,"intermission cancellation retains anchor")
    f.effects.Step()
    equal(f.data.root.Anchored,true,"intermission step retains anchor")
    equal(f.attrs.GBloxFrozenUntil,nil,"intermission deadline cleared")
    equal(f.data.root.owners,0,"intermission ownership untouched")
end)

scenario("Expired stale-character state cannot unanchor its replacement",function(f)
    local oldRoot=f.data.root
    f.effects.FreezeSeasonal(f.player,5)
    local newRoot=root() newRoot.Anchored=true
    f.data.root=newRoot
    f.time(105) f.effects.ClearSeasonalFreeze(f.player)
    equal(newRoot.Anchored,true,"direct stale cancellation cannot release replacement")
    equal(newRoot.owners,0,"replacement owner untouched")
    f.effects.Step()
    equal(newRoot.Anchored,true,"stale-character step cannot release replacement")
    equal(oldRoot.Anchored,true,"old state no longer owns old root release")
    equal(f.data.freezeUntil,nil,"stale-character deadline cleared")
    f.time(110) f.effects.Step()
    equal(newRoot.Anchored,true,"discarded state cannot release replacement later")
end)

scenario("Expired stale-round state cannot unanchor next-course root",function(f)
    f.effects.FreezeSeasonal(f.player,5)
    f.round(2)
    f.time(105) f.effects.ClearSeasonalFreeze(f.player)
    equal(f.data.root.Anchored,true,"round identity prevents direct release")
    f.effects.Step()
    equal(f.data.root.Anchored,true,"round cleanup preserves next-course anchor")
    equal(f.data.root.owners,0,"next-course ownership not assigned")
    equal(f.attrs.GBloxFrozenUntil,nil,"stale-round deadline cleared")
end)

scenario("Replacing the entire runner data cannot mutate the replacement",function(f)
    f.effects.FreezeSeasonal(f.player,5)
    local replacement={root=root(),status="Running",humanoid={Health=100},freezeUntil=500}
    replacement.root.Anchored=true
    f.runners[f.player]=replacement
    f.time(105) f.effects.Step()
    equal(replacement.root.Anchored,true,"replacement data root not released")
    equal(replacement.freezeUntil,500,"replacement data fields untouched")
    equal(replacement.root.owners,0,"replacement data physics untouched")
end)

scenario("Explicit removal preserves loading and recovery anchors",function(f)
    f.effects.FreezeSeasonal(f.player,5)
    f.data.status="Loading" f.data.recovering=true
    f.effects.Remove(f.player)
    equal(f.data.root.Anchored,true,"Remove never overrides lifecycle anchoring")
    equal(f.attrs.GBloxFrozenUntil,nil,"Remove clears combined attribute")
    equal(f.attrs.GBloxHalloweenHeldUntil,nil,"Remove clears seasonal attribute")
    equal(f.data.freezeUntil,nil,"Remove clears server freeze field")
    f.time(110) f.effects.Step()
    equal(f.data.root.Anchored,true,"removed state cannot fire later")
end)

scenario("Dead roots and absent seasonal states are not released",function(f)
    f.effects.ClearSeasonalFreeze(f.player)
    equal(f.data.root.Anchored,false,"empty cancellation leaves root alone")
    f.effects.FreezeSeasonal(f.player,5)
    f.data.humanoid.Health=0
    f.time(105) f.effects.Step()
    equal(f.data.root.Anchored,true,"dead root keeps lifecycle anchor")
    equal(f.data.root.owners,0,"dead root ownership not restored")
    equal(f.attrs.GBloxHalloweenHeldUntil,nil,"dead hold attribute cleared")
end)

print(string.format("PASS %d freeze assertions across %d isolated scenarios",assertions,scenarios))


