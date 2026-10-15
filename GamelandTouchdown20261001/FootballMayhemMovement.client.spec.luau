local player = game.Players.LocalPlayer
local remote = game.ReplicatedStorage:WaitForChild("FootballMovementTest")
local origin = game.ReplicatedStorage.FootballMayhem.ArenaOrigin.Value
local model = player.Character or player.CharacterAdded:Wait()
local humanoid = model:WaitForChild("Humanoid")
local root = model:WaitForChild("HumanoidRootPart")
local baseline = humanoid.WalkSpeed
local checks = {}
local samples = {}
local function check(value, name)
    assert(value, name)
    table.insert(checks, name)
    script:SetAttribute("Stage", name)
end
local function untilTrue(fn, seconds)
    local start = os.clock()
    repeat if fn() then return true end task.wait(.03) until os.clock() - start > seconds
    return false
end
local function walk(x, z, seconds)
    local target = origin:PointToWorldSpace(Vector3.new(x, 4, z))
    humanoid:MoveTo(target)
    return untilTrue(function()
        local p = origin:PointToObjectSpace(root.Position)
        table.insert(samples, p.Y)
        return (Vector2.new(p.X, p.Z) - Vector2.new(x, z)).Magnitude < 1.6
    end, seconds or 5)
end
local function begin()
    local ok, message = remote:InvokeServer("Begin")
    assert(ok, tostring(message))
    check(untilTrue(function() return player:GetAttribute("FootballMayhemStatus") == "Active" end, 5), "Round starts")
    task.wait(.5)
    check(not root.Anchored, "Walking test uses real unanchored physics")
    check(humanoid.WalkSpeed == baseline * 2, "Running speed remains doubled")
end
local ok, err = xpcall(function()
    begin()
    check(walk(-24, 102), "Walk onto first safe tile")
    check(untilTrue(function() return player:GetAttribute("FootballMayhemRowsCompleted") == 1 end, 2), "First row commits once")
    table.clear(samples)
    check(walk(40, 102), "Walk sideways across all remaining tiles including revealed danger")
    check(player:GetAttribute("FootballMayhemStatus") == "Active", "Crossing a cleared row does not eliminate")
    check(walk(-24, 102), "Walk back sideways without lane restriction")
    humanoid:MoveTo(origin:PointToWorldSpace(Vector3.new(-24, 4, 125)))
    task.wait(1.2)
    local pos = origin:PointToObjectSpace(root.Position)
    check(pos.Z < 112.5 and pos.Z > 108, "Invisible wall physically stops backward movement")
    check(workspace:FindFirstChild("PersonalFootballProgressWall") ~= nil, "Personal wall exists only for this participant")
    humanoid:MoveTo(root.Position)
    local low, high = math.huge, -math.huge
    for _, y in ipairs(samples) do low = math.min(low, y) high = math.max(high, y) end
    script:SetAttribute("StandingHeightRange", high - low)
    check(high - low < 1, "Lateral movement stays level without floor or air snapping")
    for row = 2, 10 do
        check(walk(-24, 102 - (row - 1) * 22), "Walk through row " .. row)
    end
    humanoid:MoveTo(origin:PointToWorldSpace(Vector3.new(-24, 4, -118)))
    check(untilTrue(function() return player:GetAttribute("FootballMayhemStatus") == "Qualified" end, 3), "Ten safe rows qualify")
    local qualifiedAt = os.clock()
    task.wait(2.65)
    check(player:GetAttribute("CurrentMinigame") == "FootballMayhem", "Qualifier stays in the end zone for nearly three seconds")
    check(untilTrue(function() return player:GetAttribute("CurrentMinigame") == nil end, 1), "Qualifier returns after three seconds")
    script:SetAttribute("QualificationHoldSeconds", os.clock() - qualifiedAt)
    check(not workspace:FindFirstChild("PersonalFootballProgressWall"), "Personal wall cleaned after qualification")
    check(humanoid.WalkSpeed == baseline and not root.Anchored, "Qualification restores movement")
    task.wait(2.3)
    begin()
    check(walk(40, 125), "Approach wrong lane from start area")
    humanoid:MoveTo(origin:PointToWorldSpace(Vector3.new(40, 4, 102)))
    check(untilTrue(function() return player:GetAttribute("FootballMayhemStatus") == "Eliminated" end, 3), "Wrong choice tackles player")
    task.wait(.9)
    local bottom = math.huge
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            local cf, half = part.CFrame, part.Size / 2
            local extent = math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z
            bottom = math.min(bottom, part.Position.Y - extent)
        end
    end
    local floor = workspace["Oni's Work"].FootballMayhem.SupportFloor
    local top = floor.Position.Y + floor.Size.Y / 2
    script:SetAttribute("KnockdownFloorClearance", bottom - top)
    check(bottom >= top - .05 and bottom - top < .5, "Knocked out character rests on the solid floor")
    check(math.abs(root.CFrame.UpVector.Y) < .1, "Knocked out character lies flat")
    check(untilTrue(function() return player:GetAttribute("CurrentMinigame") == nil end, 3), "Tackled player returns to lobby")
    check(not root.Anchored and not humanoid.PlatformStand and humanoid.WalkSpeed == baseline, "Tackle restores normal movement")
    task.wait(2.3)
    begin()
    check(walk(-24, 102), "Restart can clear a new row")
    check(remote:InvokeServer("Stop"), "Admin stop works during round")
    task.wait(.3)
    check(not workspace:FindFirstChild("PersonalFootballProgressWall"), "Admin stop removes personal wall")
end, debug.traceback)
humanoid:MoveTo(root.Position)
if not ok then remote:InvokeServer("Return") end
script:SetAttribute("Result", game:GetService("HttpService"):JSONEncode({passed = ok, error = err, checks = checks}))
