local RunService = game:GetService("RunService")
local AttackAnimator = {}
local states = {}
local connection

local function getState(model)
	if states[model] then return states[model] end
	local state = { joints = {}, walking = false, attackTime = -10, duration = 0.35, clock = 0 }
	for _, joint in ipairs(model:GetDescendants()) do
		if joint:IsA("Motor6D") then
			state.joints[joint] = joint.C0
		end
	end
	states[model] = state
	return state
end

local function poseJoint(joint, rest, state, strength)
	local name = joint.Name:gsub(" ", "")
	local swing = state.walking and math.sin(state.clock * 11) * 0.45 or 0
	local rotation = CFrame.identity
	if name == "RightHip" or name == "LeftShoulder" then rotation = CFrame.Angles(swing, 0, 0) end
	if name == "LeftHip" or name == "RightShoulder" then rotation = CFrame.Angles(-swing, 0, 0) end
	local target = rest * rotation
	local bothArms = state.unitName == "Master Roshu" or state.unitName == "Tein"
	if strength > 0 and (name == "RightShoulder" or (name == "LeftShoulder" and bothArms)) then
		local angle = state.unitName == "Tein" and 135 or 90
		local attack = rest * CFrame.Angles(math.rad(angle), 0, 0)
		if joint.Name:find(" ") then
			attack = CFrame.new(rest.Position) * CFrame.Angles(math.rad(angle), 0, 0)
		end
		target = target:Lerp(attack, strength)
	end
	return target
end

local function update(dt)
	for model, state in pairs(states) do
		if not model.Parent then
			states[model] = nil
		else
			state.clock += dt
			local age = os.clock() - state.attackTime
			local strength = math.clamp(math.min(age / 0.06, (state.duration - age) / 0.12), 0, 1)
			for joint, rest in pairs(state.joints) do
				if joint.Parent then
					joint.C0 = joint.C0:Lerp(poseJoint(joint, rest, state, strength), 1 - math.exp(-25 * dt))
				end
			end
		end
	end
	if not next(states) and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function start()
	if not connection then connection = RunService.RenderStepped:Connect(update) end
end

function AttackAnimator.setWalking(model, walking)
	getState(model).walking = walking
	start()
end

function AttackAnimator.play(model, unitName)
	local state = getState(model)
	state.unitName = unitName
	state.attackTime = os.clock()
	state.duration = unitName == "Master Roshu" and 0.7 or 0.3
	start()
end

function AttackAnimator.stop(model)
	local state = states[model]
	if not state then return end
	for joint, rest in pairs(state.joints) do
		if joint.Parent then joint.C0 = rest end
	end
	states[model] = nil
end

function AttackAnimator.stopAll()
	for model in pairs(states) do AttackAnimator.stop(model) end
	if connection then connection:Disconnect() connection = nil end
end

return AttackAnimator

