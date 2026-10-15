assert(not game:GetService("RunService"):IsRunning())
local arena=assert(workspace:FindFirstChild("Hide and Seek"))
local emitter=arena.Gameplay:FindFirstChild("SchoolBellEmitter")
if not emitter then emitter=Instance.new("Part")emitter.Name="SchoolBellEmitter"emitter.Size=Vector3.new(.2,.2,.2)emitter.Position=Vector3.new(11000,55,4585)emitter.Transparency=1 emitter.Anchored=true emitter.CanCollide=false emitter.CanTouch=false emitter.CanQuery=false emitter.Parent=arena.Gameplay end
local bell=emitter:FindFirstChild("SchoolBell")or Instance.new("Sound")
bell.Name="SchoolBell"bell.SoundId="rbxassetid://2783281207"bell.Volume=.35 bell.Looped=false bell.RollOffMode=Enum.RollOffMode.InverseTapered bell.RollOffMinDistance=100 bell.RollOffMaxDistance=350 bell.Parent=emitter
return {sound=bell:GetFullName(),volume=bell.Volume}
