assert(not game:GetService("RunService"):IsRunning(),"Stop Play before installing the mobile layout.")
assert(game.PlaceId==95034648955135,"This layout is for Playground Classics.")
local StarterGui=game:GetService("StarterGui")
local ServerStorage=game:GetService("ServerStorage")
assert(not ServerStorage:FindFirstChild("RightSprintBackup20261008"),"The right-side sprint layout is already installed.")
local layout=__LAYOUT__
local paths={
 {"BritishBulldogHUD","MobileSprint"},
 {"TagHUD","MobileSprint"},
 {"MudHUD","Main","MobileSprint"},
 {"PlaygroundBatControls","Swing"},
 {"PlaygroundPushControls","MobilePush"},
 {"MudHUD","Main","Controls","Mud"},
 {"MudHUD","Main","Controls","Heat"},
 {"MudHUD","Main","Controls","Fire"},
}
local clonedRoot=Instance.new("Folder")
for _,name in ipairs({"BritishBulldogHUD","TagHUD","MudHUD","PlaygroundBatControls","PlaygroundPushControls"})do
 local clone=StarterGui[name]:Clone()
 clone.Parent=clonedRoot
end
local checked,validation=pcall(layout,clonedRoot,true)
clonedRoot:Destroy()
assert(checked,validation)
local backup=Instance.new("Folder")
backup.Name="RightSprintBackup20261008"
backup.Parent=ServerStorage
for _,path in ipairs(paths)do
 local button=StarterGui
 for _,name in ipairs(path)do button=button[name]end
 local clone=button:Clone()
 clone.Name=table.concat(path,"_")
 clone.Parent=backup
end
local changed=layout(StarterGui,true)
local result={}
for _,entry in ipairs(changed)do table.insert(result,entry.button:GetFullName())end
return {changed=result,backup=backup:GetFullName()}
