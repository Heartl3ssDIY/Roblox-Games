local TweenService = game:GetService("TweenService")
local ModePickerUI = {}
local gui, panel, content, motion
local transition, fade, serial = nil, nil, 0
local sweeps = {}
local function fit()
    if gui:GetAttribute("AutoFit") == false then return end
    local size = gui.AbsoluteSize
    local margin = 40 + math.max(0, -gui.AbsolutePosition.Y)
    panel.FitToScreen.Scale = math.max(.1, math.min(.82, (size.X - 80) / panel.Size.X.Offset, (size.Y - margin * 2) / panel.Size.Y.Offset))
end
local function stopTransition()
    serial += 1
    if transition then transition:Cancel() end
    if fade then fade:Cancel() end
end
local function shine(button)
    local gradient = button.Finish.Shine.Sweep
    if sweeps[button] then sweeps[button]:Cancel() end
    gradient.Offset = Vector2.new(-1.3, 0)
    local tween = TweenService:Create(gradient, TweenInfo.new(.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Offset = Vector2.new(1.3, 0)})
    sweeps[button] = tween
    tween:Play()
end
function ModePickerUI.close()
    if not gui or not gui.Enabled then return end
    stopTransition()
    local token = serial
    transition = TweenService:Create(motion, TweenInfo.new(.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = .96})
    fade = TweenService:Create(content, TweenInfo.new(.16), {GroupTransparency = 1})
    transition:Play()
    fade:Play()
    task.delay(.17, function()
        if token == serial then gui.Enabled = false end
    end)
end
function ModePickerUI.open()
    if not gui then return end
    stopTransition()
    fit()
    motion.Scale = .96
    content.GroupTransparency = 1
    gui.Enabled = true
    transition = TweenService:Create(motion, TweenInfo.new(.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
    fade = TweenService:Create(content, TweenInfo.new(.2), {GroupTransparency = 0})
    transition:Play()
    fade:Play()
    shine(content.Main)
    shine(content.UnderConstruction)
end
function ModePickerUI.build(playerGui)
    if gui then return gui end
    gui = playerGui:WaitForChild("ModePickerGui")
    panel = gui.Panel
    content = panel.Content
    motion = content.Motion
    content.Close.Activated:Connect(ModePickerUI.close)
    content.UnderConstruction.Activated:Connect(function()
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {Title="Modes", Text="This mode is still being built.", Duration=4})
        end)
    end)
    for _, button in {content.Main, content.UnderConstruction} do
        local scale = button.HoverScale
        local hovered = false
        local tween
        local function setScale(value)
            if tween then tween:Cancel() end
            tween = TweenService:Create(scale, TweenInfo.new(.14, Enum.EasingStyle.Quad), {Scale = value})
            tween:Play()
        end
        local function enter()
            hovered = true
            setScale(button:GetAttribute("Locked") and 1.012 or 1.025)
            shine(button)
        end
        local function leave()
            hovered = false
            setScale(1)
        end
        button.MouseEnter:Connect(enter)
        button.MouseLeave:Connect(leave)
        button.SelectionGained:Connect(enter)
        button.SelectionLost:Connect(leave)
        button.MouseButton1Down:Connect(function() setScale(.985) end)
        button.MouseButton1Up:Connect(function() setScale(hovered and 1.025 or 1) end)
        gui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if not gui.Enabled then
                hovered = false
                if tween then tween:Cancel() end
                scale.Scale = 1
            end
        end)
    end
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(fit)
    fit()
    task.spawn(function()
        while gui.Parent do
            task.wait(5)
            if gui.Enabled then
                shine(content.Main)
                shine(content.UnderConstruction)
            end
        end
    end)
    return gui
end
return ModePickerUI