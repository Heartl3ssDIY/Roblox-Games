local SoundService = game:GetService("SoundService")
local MatchSettings = {}
local soundsOn = true
local effectsOn = true
local volumes = setmetatable({}, {__mode = "k"})

local function applySound(sound)
    if not sound:IsA("Sound") then return end
    if volumes[sound] == nil then volumes[sound] = sound.Volume end
    sound.Volume = soundsOn and volumes[sound] or 0
end

function MatchSettings.soundsEnabled() return soundsOn end
function MatchSettings.effectsEnabled() return effectsOn end
function MatchSettings.setSounds(value)
    soundsOn = value == true
    local folder = SoundService:FindFirstChild("PackShopSounds")
    if folder then for _, sound in ipairs(folder:GetChildren()) do applySound(sound) end end
end
function MatchSettings.setEffects(value) effectsOn = value == true end

local folder = SoundService:FindFirstChild("PackShopSounds")
if folder then folder.ChildAdded:Connect(applySound) end
return MatchSettings
