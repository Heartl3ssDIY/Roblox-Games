-- ArenaCameraController
-- Locks the camera to a fixed top-down PORTRAIT view of an arena.
-- The arena's long axis (red end -> blue end) maps to the vertical screen axis,
-- with the local player's RED side at the BOTTOM and the opponent's BLUE side at the TOP.
-- Slight zoom allowed via scroll wheel / pinch.
--
-- This script does NOTHING on its own. To activate, set the player attribute
-- "ActiveArena" to the arena Model's name (a child of workspace), e.g.:
--     game.Players.LocalPlayer:SetAttribute("ActiveArena", "Arena_WestCity")
-- Clear it (set to nil/"") to release the camera back to normal.

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UserInput     = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Zoom config (camera height above the field). Lower = closer.
local BASE_HEIGHT = 95      -- default height to frame the whole portrait field
local MIN_HEIGHT  = 80      -- closest (slight zoom in)
local MAX_HEIGHT  = 110     -- farthest (slight zoom out)
local ZOOM_STEP   = 5
local height = BASE_HEIGHT

local active = false
local arena = nil
local renderName = "ArenaCameraLock"

local function getFocus(a)
    local f = a:FindFirstChild("CameraFocus")
    if f then return f.Position end
    -- fallback: bounding box center
    local cf = a:GetBoundingBox()
    return cf.Position
end

local function startLock(a)
    arena = a
    active = true
    camera.CameraType = Enum.CameraType.Scriptable

    RunService:UnbindFromRenderStep(renderName)
    RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function()
        if not active or not arena or not arena.Parent then return end
        local focus = getFocus(arena)
        -- Near-top-down, pulled back over the RED end (-Z) and tilted slightly so the
        -- orientation locks: the local player's RED side sits at the BOTTOM of the
        -- screen, opponent's BLUE side at the TOP. (Pure straight-down is ambiguous.)
        local pullback = height * 0.6
        local camPos = focus + Vector3.new(0, height, -pullback)
        camera.CFrame = CFrame.lookAt(camPos, focus + Vector3.new(0, 0, 4))
    end)
end

local function stopLock()
    active = false
    arena = nil
    RunService:UnbindFromRenderStep(renderName)
    camera.CameraType = Enum.CameraType.Custom
end

local function onAttrChanged()
    local name = player:GetAttribute("ActiveArena")
    if name and name ~= "" then
        local a = workspace:FindFirstChild(name)
        if a then
            height = BASE_HEIGHT
            startLock(a)
        end
    else
        stopLock()
    end
end

player:GetAttributeChangedSignal("ActiveArena"):Connect(onAttrChanged)
onAttrChanged() -- apply if already set

-- Slight zoom control
UserInput.InputChanged:Connect(function(input)
    if not active then return end
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        height = math.clamp(height - input.Position.Z * ZOOM_STEP, MIN_HEIGHT, MAX_HEIGHT)
    end
end)

-- Pinch zoom (touch)
UserInput.TouchPinch:Connect(function(_, scale, _, state)
    if not active then return end
    if state == Enum.UserInputState.Change then
        height = math.clamp(height / scale, MIN_HEIGHT, MAX_HEIGHT)
    end
end)

