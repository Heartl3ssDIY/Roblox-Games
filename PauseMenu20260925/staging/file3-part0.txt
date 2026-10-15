local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Feedback = require(ReplicatedStorage:WaitForChild("PackShopEffects"))
local Settings = require(ReplicatedStorage:WaitForChild("MatchSettings"))
local PauseMenu = {}
local hud, overlay, panel, callbacks
local quitting = false
local selectedBefore

local function page(name)
    for _, id in ipairs({"Main", "Settings", "Confirm"}) do panel[id].Visible = id == name end
    panel.Title.Text = name == "Settings" and "Settings" or name == "Confirm" and "Quit Match?" or "Paused"
    panel.Error.Visible = false
    if UserInputService.GamepadEnabled then
        GuiService.SelectedObject = name == "Main" and panel.Main.Resume or name == "Settings" and panel.Settings.Sounds or panel.Confirm.Cancel
    end
end

function PauseMenu.settings()
    if not overlay.Visible or quitting then return end
    panel.Settings.Sounds.Label.Text = "UI Sounds: " .. (Settings.soundsEnabled() and "ON" or "OFF")
    panel.Settings.Effects.Label.Text = "Battle Effects: " .. (Settings.effectsEnabled() and "ON" or "OFF")
    page("Settings")
end

function PauseMenu.resume()
    if quitting or not overlay.Visible then return end
    callbacks.pause(false)
    PauseMenu.hide()
end

function PauseMenu.hide()
    if not overlay then return end
    overlay.Visible = false
    quitting = false
    if selectedBefore and selectedBefore.Parent then GuiService.SelectedObject = selectedBefore
    else GuiService.SelectedObject = nil end
    selectedBefore = nil
end

function PauseMenu.open()
    if quitting or not hud.Enabled or not callbacks.canPause() then return false end
    if overlay.Visible then return true end
    callbacks.pause(true)
    selectedBefore = GuiService.SelectedObject
    panel.Subtitle.Text = game.Players.LocalPlayer:GetAttribute("QuickRound") and "Practice · AI Match" or "Tenkaichi · AI Match"
    panel.Confirm.Warning.Text = game.Players.LocalPlayer:GetAttribute("QuickRound")
        and "Leave this practice match?\nArena progress is unchanged."
        or "Forfeit this match?\nYou lose 1 arena win of progress.\nEarned rewards stay yours."
    panel.Confirm.Confirm.Interactable = true
    panel.Confirm.Cancel.Interactable = true
    overlay.Visible = true
    page("Main")
    return true
end

function PauseMenu.requestQuit()
    if overlay.Visible and not quitting then page("Confirm") end
end

function PauseMenu.confirmQuit()
    if not overlay.Visible or not panel.Confirm.Visible or quitting then return false end
    quitting = true
    panel.Confirm.Confirm.Interactable = false
    panel.Confirm.Cancel.Interactable = false
    local success, message = callbacks.quit()
    if success then
        PauseMenu.hide()
        return true
    end
    quitting = false
    panel.Confirm.Confirm.Interactable = true
    panel.Confirm.Cancel.Interactable = true
    panel.Error.Text = message or "Could not return to the lobby. Try again."
    panel.Error.Visible = true
    return false
end

function PauseMenu.build(arenaHud, actions)
    if hud then return end
    hud, callbacks = arenaHud, actions
    overlay = hud:WaitForChild("PauseOverlay")
    panel = overlay.Panel
    local function fit()
        panel.FitToScreen.Scale = math.max(.1, math.min(1, (hud.AbsoluteSize.X - 32) / panel.Size.X.Offset, (hud.AbsoluteSize.Y - 32) / panel.Size.Y.Offset))
    end
    hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    fit()
    hud.Pause.Activated:Connect(PauseMenu.open)
    panel.Main.Resume.Activated:Connect(PauseMenu.resume)
    panel.Main.Settings.Activated:Connect(PauseMenu.settings)
    panel.Main.Quit.Activated:Connect(PauseMenu.requestQuit)
    panel.Settings.Back.Activated:Connect(function() if not quitting then page("Main") end end)
    panel.Confirm.Cancel.Activated:Connect(function() if not quitting then page("Main") end end)
    panel.Confirm.Confirm.Activated:Connect(PauseMenu.confirmQuit)
    panel.Settings.Sounds.Activated:Connect(function()
        Settings.setSounds(not Settings.soundsEnabled())
        PauseMenu.settings()
    end)
    panel.Settings.Effects.Activated:Connect(function()
        Settings.setEffects(not Settings.effectsEnabled())
        PauseMenu.settings()
    end)
    for _, button in ipairs(overlay:GetDescendants()) do
        if button:IsA("GuiButton") then
            button.MouseEnter:Connect(function() if overlay.Visible and button.Interactable then Feedback.play("Hover") end end)
            button.SelectionGained:Connect(function() if overlay.Visible then Feedback.play("Hover") end end)
            button.Activated:Connect(function() Feedback.play("Click") end)
        end
    end
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.P or input.KeyCode == Enum.KeyCode.ButtonStart then
            if overlay.Visible then PauseMenu.resume() else PauseMenu.open() end
        end
    end)
end

return PauseMenu
