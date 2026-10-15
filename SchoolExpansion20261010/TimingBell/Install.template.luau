assert(not game:GetService("RunService"):IsRunning(), "Stop Play before applying school timing")
assert(game.PlaceId == 95034648955135 and game.GameId == 10769034155, "Wrong experience")
local module = game.ServerScriptService:WaitForChild("HideAndSeekService")
local original = module.Source
local digest = 5381
for index = 1, #original do digest = (digest * 33 + string.byte(original, index)) % 4294967296 end
assert(#original == __BEFORE_LENGTH__ and digest == __BEFORE_DIGEST__, "School service changed; inspect before applying")
local arena = workspace:WaitForChild("Hide and Seek")
assert(arena:GetAttribute("HideSeconds") == 20, "Hiding duration changed")
local bell = arena:FindFirstChild("SchoolBell", true)
assert(bell and bell:IsA("Sound"), "Create the school bell Sound before installing its release trigger")
local gui = game.StarterGui:WaitForChild("HideAndSeekHUD")
local countdown = gui.SeekerBlindfold.WaitingCard.Countdown
local state = game.ReplicatedStorage:WaitForChild("HideAndSeekState")
local storage = game:GetService("ServerStorage")
assert(not storage:FindFirstChild("SchoolTimingBellBackup20261010"), "Timing backup already exists; inspect before reinstalling")
local backup = Instance.new("Folder")
backup.Name = "SchoolTimingBellBackup20261010"
backup:SetAttribute("PreviousHideSeconds", arena:GetAttribute("HideSeconds"))
backup:SetAttribute("PreviousStateHideSeconds", state:GetAttribute("HideSeconds"))
backup:SetAttribute("PreviousPreviewCountdown", countdown.Text)
local saved = module:Clone()
saved.Name, saved.Parent = "HideAndSeekServiceBefore", backup
backup.Parent = storage
module.Source = [======[__SOURCE__]======]
arena:SetAttribute("HideSeconds", 30)
state:SetAttribute("HideSeconds", 30)
countdown.Text = "0:30"
return { hidingSeconds = 30, searchingSeconds = arena:GetAttribute("RoundDuration"), bell = bell:GetFullName(), sourceLength = #module.Source }
