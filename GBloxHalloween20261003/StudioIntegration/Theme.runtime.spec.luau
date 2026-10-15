local settings = game.ReplicatedStorage:WaitForChild("GBloxCourseTheme")
local Theme = require(game.ServerScriptService.GBloxCourseTheme.Theme)
local checks={}
local function check(value,name) assert(value,name) table.insert(checks,name) end
local ok,err=xpcall(function()
 task.wait(1)
 local course=workspace[" Course -  round 1"]
 local wheel
 for _,v in ipairs(course:GetDescendants()) do if v:IsA("Model") and v.Name=="Red_Spiked_Wheel" then wheel=v break end end
 assert(wheel)
 local teeth=wheel:FindFirstChild("RedWheel_Teeth")
 local cf=teeth.CFrame
 task.wait(.6)
 check(teeth.CFrame~=cf,"Existing wheel rotation runs with Halloween active")
 local halloween=teeth.Color
 local canQuery,canCollide=teeth.CanQuery,teeth.CanCollide
 settings:SetAttribute("ActiveTheme","Normal")
 task.wait(.3)
 check(teeth.Color==teeth:GetAttribute("GBloxNormalColor"),"Normal switch updates live wheel")
 local normalCF=teeth.CFrame
 settings:SetAttribute("ActiveTheme","Halloween")
 task.wait(.3)
 check(teeth.Color==halloween,"Halloween switch updates live wheel")
 check(teeth.CFrame~=normalCF,"Theme switching does not interrupt rotation")
 check(teeth.CanQuery==canQuery and teeth.CanCollide==canCollide,"Wheel contact flags unchanged")
 local source=course:FindFirstChild("Flat_Platform_Cyan",true)
 assert(source)
 local temporary=source:Clone()
 temporary.Color=temporary:GetAttribute("GBloxNormalColor")
 temporary.Name="Flat_Platform_Cyan"
 temporary.Parent=source.Parent
 task.wait(.3)
 check(temporary.Color==source.Color,"Newly added course mesh inherits active theme")
 temporary:Destroy()
 check(settings:GetAttribute("AppliedParts")==6020,"Runtime applies all expected parts")
end,debug.traceback)
settings:SetAttribute("ActiveTheme","Halloween")
script:SetAttribute("Result",game:GetService("HttpService"):JSONEncode({passed=ok,error=err,checks=checks}))
