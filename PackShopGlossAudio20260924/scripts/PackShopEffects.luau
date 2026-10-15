local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local Effects = {}
local bindings = setmetatable({}, {__mode = "k"})
local playing = setmetatable({}, {__mode = "k"})
local lastSound = {}
local sounds = SoundService:WaitForChild("PackShopSounds")

task.spawn(function()
    pcall(function() ContentProvider:PreloadAsync(sounds:GetChildren()) end)
end)

local function available(button, gui)
    if not gui.Enabled or not button.Interactable then return false end
    local current = button
    while current and current ~= gui do
        if current:IsA("GuiObject") and not current.Visible then return false end
        current = current.Parent
    end
    return current == gui
end

function Effects.play(name)
    local sound = sounds:FindFirstChild(name)
    if not sound or not sound:IsA("Sound") or not sound.IsLoaded then return false end
    local now = os.clock()
    local cooldown = name == "Hover" and .1 or .07
    if now - (lastSound[name] or -math.huge) < cooldown then return false end
    lastSound[name] = now
    sound:Stop()
    sound.TimePosition = 0
    sound:Play()
    return true
end

function Effects.sweep(button, gui)
    if not available(button, gui) then return end
    local layer = button:FindFirstChild("ShopFinish")
    local sweep = layer and layer.Shine:FindFirstChild("Sweep")
    if not sweep or playing[sweep] then return end
    sweep.Offset = Vector2.new(-1.25, 0)
    local tween = TweenService:Create(sweep, TweenInfo.new(.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Offset = Vector2.new(1.25, 0)})
    playing[sweep] = tween
    tween.Completed:Once(function()
        if playing[sweep] == tween then playing[sweep] = nil end
    end)
    tween:Play()
end

function Effects.bind(gui)
    if bindings[gui] then return end
    bindings[gui] = true
    local buttons = {}
    for _, button in ipairs(gui:GetDescendants()) do
        if button:IsA("GuiButton") then
            table.insert(buttons, button)
            local function hover()
                if available(button, gui) then
                    Effects.play("Hover")
                    Effects.sweep(button, gui)
                end
            end
            button.MouseEnter:Connect(hover)
            button.SelectionGained:Connect(hover)
            button.Activated:Connect(function()
                if available(button, gui) then Effects.play("Click") end
            end)
        end
    end
    local version = 0
    local function changed()
        version += 1
        local token = version
        if not gui.Enabled then
            for _, button in ipairs(buttons) do
                local finish = button:FindFirstChild("ShopFinish")
                local sweep = finish and finish.Shine.Sweep
                if sweep then
                    if playing[sweep] then playing[sweep]:Cancel(); playing[sweep] = nil end
                    sweep.Offset = Vector2.new(-1.25, 0)
                end
            end
            return
        end
        task.spawn(function()
            while gui.Parent and gui.Enabled and version == token do
                for index, button in ipairs(buttons) do
                    task.delay((index - 1) * .07, function()
                        if gui.Parent and version == token then Effects.sweep(button, gui) end
                    end)
                end
                task.wait(math.max(3, gui:GetAttribute("GlossInterval") or 7))
            end
        end)
    end
    gui:GetPropertyChangedSignal("Enabled"):Connect(changed)
    if gui.Enabled then changed() end
end

return Effects
