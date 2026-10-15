assert(not game:GetService("RunService"):IsRunning(),"Edit only")
local api=require(game.ServerStorage.PushAnimationProbe20261008)
local checks={}
local function check(name,ok) table.insert(checks,{name=name,passed=ok==true}) assert(ok,name) end
for _,kind in {"R6","R15"} do
	local rig=game.ServerStorage.PushAnimationAuthoring20261008["PushPreview"..kind]:Clone()
	rig.Parent=game.ServerStorage
	local ok,err=xpcall(function()
		local humanoid=rig:FindFirstChildOfClass("Humanoid")
		local attrs={TGParticipating=true}
		local player={GetAttribute=function(_,key)return attrs[key]end}
		local record={character=rig,joints={}}
		rig:SetAttribute("PCPushAt",100)
		check(kind.." starts an accepted shove",api.animate(record,player,rig,humanoid,100))
		check(kind.." neutral frame blends cleanly",next(record.joints)==nil)
		for _,t in {.05,.10,.18,.25,.37,.48,.59} do
			api.restore(record)
			check(kind.." samples time "..t,api.animate(record,player,rig,humanoid,100+t))
			local count=0
			for joint,entry in record.joints do
				count+=1
				for _,v in {entry.applied:GetComponents()} do assert(v==v and math.abs(v)<100,"Invalid transform") end
			end
			check(kind.." has full-body joints at "..t,count>=(kind=="R6" and 6 or 13))
		end
		api.restore(record)
		check(kind.." finishes at 0.6 seconds",not api.animate(record,player,rig,humanoid,100.61))
		attrs.TGRagdolled=true
		check(kind.." cancels when ragdolled",not api.animate(record,player,rig,humanoid,100.18))
		attrs.TGRagdolled=false;attrs.TGParticipating=false
		check(kind.." cannot animate a lobby push",not api.animate(record,player,rig,humanoid,100.18))
		attrs.BBParticipating=true
		check(kind.." works for Bulldog",api.animate(record,player,rig,humanoid,100.18))
		api.restore(record)
		for _,j in rig:GetDescendants()do if j:IsA("Motor6D")or j:IsA("AnimationConstraint")then
			check(kind.." restores "..j.Name,j.Transform==CFrame.identity)
		end end
		local clip=api.clip(kind=="R6")
		check(kind.." native editable clip has seven keys",#clip.frames==7 and math.abs(clip.duration-.6)<.001)
	end,debug.traceback)
	rig:Destroy()
	if not ok then error(err)end
end
return game:GetService("HttpService"):JSONEncode({passed=true,checks=checks})
