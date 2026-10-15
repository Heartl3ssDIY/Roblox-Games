-- Installed into StarterPlayerScripts. A touch button appears only while carrying.
local CAS = game:GetService("ContextActionService")
local remote = game:GetService("ReplicatedStorage"):WaitForChild("SchoolPropDrop")
local action = "DropSchoolProp"
remote.OnClientEvent:Connect(function(carrying)
    CAS:UnbindAction(action)
    if carrying then
        CAS:BindAction(action, function(_, state)
            if state == Enum.UserInputState.Begin then remote:FireServer() end
            return Enum.ContextActionResult.Sink
        end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
        CAS:SetTitle(action, "Drop")
        CAS:SetPosition(action, UDim2.new(1, -160, 1, -190))
    end
end)
