local assets = game.ReplicatedStorage.FootballMayhem
local sounds = assets:FindFirstChild("Sounds") or Instance.new("Folder")
sounds.Name = "Sounds" sounds.Parent = assets
for _, spec in ipairs({{"TackleGrunt", "4596892095", 0.65, 1}, {"RevealPop", "72264591133889", 0.22, 1.15}, {"RoundStartWhistle", "9118113825", 0.35, 1}}) do
    local sound = sounds:FindFirstChild(spec[1]) or Instance.new("Sound")
    sound.Name = spec[1] sound.SoundId = "rbxassetid://" .. spec[2]
    sound.Volume = spec[3] sound.PlaybackSpeed = spec[4]
    sound.RollOffMaxDistance = 65 sound.RollOffMinDistance = 7 sound.Parent = sounds
end
local visuals = assets:FindFirstChild("Visuals") or Instance.new("Folder")
visuals.Name = "Visuals" visuals.Parent = assets
if not visuals:FindFirstChild("Quarterback") then
    game.ServerStorage.FootballMayhemAssets.Quarterback:Clone().Parent = visuals
end
if not assets:FindFirstChild("Effects") then
    local event = Instance.new("RemoteEvent") event.Name = "Effects" event.Parent = assets
end
workspace["Oni's Work"].FootballMayhem:SetAttribute("Rules", "Choose once per row; personal danger reveal; no backtracking; double-speed runs")
