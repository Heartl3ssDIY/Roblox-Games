local ReplicatedStorage = game:GetService("ReplicatedStorage")
local event = ReplicatedStorage:WaitForChild("RunnerEvent")
local FLIP_VELOCITY = 36

event.OnServerEvent:Connect(function(player, action)
	if action ~= "Flip" then return end
	local previousSign = player:GetAttribute("GravitySign")

	task.defer(function()
		local newSign = player:GetAttribute("GravitySign")
		if not newSign or newSign == previousSign then return end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then return end

		if root.Anchored then
			local deadline = os.clock() + 1
			while root.Parent and root.Anchored and os.clock() < deadline do
				task.wait()
			end
		end
		if not root.Parent or root.Anchored then return end
		if player:GetAttribute("GravitySign") ~= newSign then return end

		root.CFrame = CFrame.lookAt(
			root.Position,
			root.Position + Vector3.new(-1, 0, 0),
			Vector3.new(0, newSign, 0)
		)
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(
			velocity.X,
			-newSign * FLIP_VELOCITY,
			0
		)
	end)
end)

