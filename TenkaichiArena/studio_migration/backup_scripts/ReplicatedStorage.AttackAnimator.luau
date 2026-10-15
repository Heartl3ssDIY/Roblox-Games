--!strict
-- AttackAnimator: procedural per-unit attack animations for deployed combat
-- rigs. Units are ANCHORED, so we animate Motor6D joint C0s (limb poses) and,
-- for hops (Roshi), the whole model's pivot up & back to the same spot.
-- Handles both R6 and R15 rigs. Restores rest pose after each attack.

local TweenService = game:GetService("TweenService")

local AttackAnimator = {}

-- ── Joint helpers ──────────────────────────────────────────────────────────
local function isR6(model)
	return model:FindFirstChild("Torso") ~= nil and model:FindFirstChild("Right Arm") ~= nil
end

-- Find a Motor6D by name anywhere in the model.
local function findJoint(model, name)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name == name then return d end
	end
	return nil
end

-- Tween a joint's C0 to a target offset (relative to its rest C0).
-- We cache the rest C0 on the joint via an attribute-like table.
local restCache = setmetatable({}, { __mode = "k" })
local function restC0(joint)
	if restCache[joint] == nil then restCache[joint] = joint.C0 end
	return restCache[joint]
end
local function tweenJoint(joint, offsetCFrame, time, style, dir)
	if not joint then return end
	local rest = restC0(joint)
	local tw = TweenService:Create(joint,
		TweenInfo.new(time or 0.12, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		{ C0 = rest * offsetCFrame })
	tw:Play()
	return tw
end
-- Tween a joint's C0 to an ABSOLUTE target (not relative to rest).
local function tweenJointAbsolute(joint, targetC0, time, style, dir)
	if not joint then return end
	restC0(joint)  -- cache rest so resetJoint works
	TweenService:Create(joint,
		TweenInfo.new(time or 0.12, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		{ C0 = targetC0 }):Play()
end
local function resetJoint(joint, time)
	if not joint then return end
	local rest = restCache[joint]
	if not rest then return end
	TweenService:Create(joint,
		TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ C0 = rest }):Play()
end

-- Arm joint names differ by rig. Returns the primary "firing/punching" arm joint.
local function rightArmJoint(model)
	if isR6(model) then
		return findJoint(model, "Right Shoulder")
	else
		return findJoint(model, "RightShoulder")   -- R15
	end
end
local function leftArmJoint(model)
	if isR6(model) then
		return findJoint(model, "Left Shoulder")
	else
		return findJoint(model, "LeftShoulder")
	end
end

-- R15-only joint accessors (return nil on R6).
local function rightElbow(model) return findJoint(model, "RightElbow") end
local function leftElbow(model)  return findJoint(model, "LeftElbow") end
local function rightHipJ(model)  return findJoint(model, isR6(model) and "Right Hip" or "RightHip") end
local function leftHipJ(model)   return findJoint(model, isR6(model) and "Left Hip" or "LeftHip") end
local function rightKnee(model)  return findJoint(model, "RightKnee") end
local function leftKnee(model)   return findJoint(model, "LeftKnee") end
local function waistJ(model)     return findJoint(model, "Waist") end
local function neckJ(model)      return findJoint(model, "Neck") end

-- ── Per-unit attack poses ─────────────────────────────────────────────────
-- Each returns a function(model, side) that plays the pose. side affects facing
-- for the firing direction but joints are local so it's largely symmetric.
-- We raise the firing arm toward the enemy (forward = the rig's look direction).
-- R15 arms point forward with a +90° X rotation of the shoulder (verified).

-- Goku: raise right hand FORWARD (toward the enemy) and fire an energy blast.
local function goku(model)
	local arm = rightArmJoint(model)
	if not arm then return end
	if isR6(model) then
		-- absolute C0: shoulder at rest offset (1, 0.5, 0), arm rotated to point
		-- forward (-Z local = toward the enemy the rig faces).
		tweenJointAbsolute(arm, CFrame.new(1, 0.5, 0) * CFrame.Angles(math.rad(90), 0, 0), 0.1)
	else
		-- R15: raise the upper arm forward (+90° X).
		tweenJoint(arm, CFrame.Angles(math.rad(90), 0, 0), 0.1)
	end
	task.delay(0.24, function() resetJoint(arm, 0.18) end)
end

-- Bluma (R15): raises her gun hand forward to fire (a sharp arm-raise, holds
-- briefly as the shot goes off, then lowers).
local function bluma(model)
	local arm = rightArmJoint(model)
	if not arm then return end
	local el = rightElbow(model)
	-- raise arm forward + level (gun pointing at the enemy)
	tweenJoint(arm, CFrame.Angles(math.rad(88), 0, 0), 0.07, Enum.EasingStyle.Back)
	if el then tweenJoint(el, CFrame.Angles(math.rad(-5), 0, 0), 0.07) end
	task.delay(0.3, function()
		resetJoint(arm, 0.16)
		if el then resetJoint(el, 0.16) end
	end)
end

-- Tein (R15): squats down (bends hips/knees + leans), then fires his beam from
-- his forehead — a hand rises to the forehead during the squat. Returns to stand.
local function tein(model)
	local rHip, lHip = rightHipJ(model), leftHipJ(model)
	local rKnee, lKnee = rightKnee(model), leftKnee(model)
	local waist = waistJ(model)
	local arm = rightArmJoint(model)
	local el = rightElbow(model)
	local startPivot = model:GetPivot()
	local down = startPivot + Vector3.new(0, -1.6, 0)   -- dip the whole body down
	task.spawn(function()
		-- squat: lower the body (HRP is anchored, so dip the pivot) + bend knees/hips
		if rKnee then tweenJoint(rKnee, CFrame.Angles(math.rad(-50), 0, 0), 0.16) end
		if lKnee then tweenJoint(lKnee, CFrame.Angles(math.rad(-50), 0, 0), 0.16) end
		if rHip then tweenJoint(rHip, CFrame.Angles(math.rad(45), 0, 0), 0.16) end
		if lHip then tweenJoint(lHip, CFrame.Angles(math.rad(45), 0, 0), 0.16) end
		if waist then tweenJoint(waist, CFrame.Angles(math.rad(-15), 0, 0), 0.16) end
		if arm then tweenJoint(arm, CFrame.Angles(math.rad(150), 0, math.rad(20)), 0.16) end
		if el then tweenJoint(el, CFrame.Angles(math.rad(-120), 0, 0), 0.16) end
		-- dip the body down over ~0.16s
		local t0 = os.clock()
		while os.clock() - t0 < 0.16 do
			model:PivotTo(startPivot:Lerp(down, (os.clock()-t0)/0.16))
			task.wait()
		end
		model:PivotTo(down)
		task.wait(0.28)
		-- fire: hand snaps forward from forehead (beam from third eye)
		if arm then tweenJoint(arm, CFrame.Angles(math.rad(90), 0, 0), 0.08, Enum.EasingStyle.Back) end
		if el then tweenJoint(el, CFrame.Angles(0, 0, 0), 0.08) end
		task.wait(0.28)
		-- stand back up: raise body + reset joints
		local t1 = os.clock()
		while os.clock() - t1 < 0.16 do
			model:PivotTo(down:Lerp(startPivot, (os.clock()-t1)/0.16))
			task.wait()
		end
		model:PivotTo(startPivot)
		resetJoint(rKnee, 0.16); resetJoint(lKnee, 0.16)
		resetJoint(rHip, 0.16); resetJoint(lHip, 0.16)
		resetJoint(waist, 0.16)
		resetJoint(arm, 0.16); resetJoint(el, 0.16)
	end)
end

-- Pikkolo (R15): touches two fingers to his forehead (charging), then thrusts
-- the arm forward to fire his beam (Special Beam Cannon).
local function pikkolo(model)
	local arm = rightArmJoint(model)
	local el = rightElbow(model)
	if not arm then return end
	task.spawn(function()
		-- raise hand and bend elbow so the fingers reach the forehead
		tweenJoint(arm, CFrame.Angles(math.rad(150), 0, math.rad(15)), 0.12)
		if el then tweenJoint(el, CFrame.Angles(math.rad(-125), 0, 0), 0.12) end
		task.wait(0.32)
		-- thrust forward: straighten arm out toward the enemy (beam fires)
		tweenJoint(arm, CFrame.Angles(math.rad(90), 0, 0), 0.07, Enum.EasingStyle.Back)
		if el then tweenJoint(el, CFrame.Angles(0, 0, 0), 0.07, Enum.EasingStyle.Back) end
		task.wait(0.3)
		resetJoint(arm, 0.16)
		if el then resetJoint(el, 0.16) end
	end)
end

-- Punch: jab the right arm straight forward fast, then retract.
local function punch(model)
	local arm = rightArmJoint(model)
	if not arm then return end
	if isR6(model) then
		-- snap forward to the extended punch pose, then pull back
		tweenJointAbsolute(arm, CFrame.new(1, 0.5, 0) * CFrame.Angles(math.rad(90), 0, 0), 0.05, Enum.EasingStyle.Back)
	else
		-- R15: swing the upper arm forward (+90° X = forward, verified). Straighten
		-- the elbow on the jab for a fuller extension.
		tweenJoint(arm, CFrame.Angles(math.rad(90), 0, 0), 0.05, Enum.EasingStyle.Back)
		local el = rightElbow(model)
		if el then tweenJoint(el, CFrame.Angles(math.rad(-10), 0, 0), 0.05) end
		task.delay(0.13, function() resetJoint(el, 0.1) end)
	end
	task.delay(0.13, function() resetJoint(arm, 0.1) end)
end

-- ── Walking animation ────────────────────────────────────────────────────────
-- A simple looping leg-swing (+ subtle arm sway) played while a unit advances.
-- Per-model state so we can start/stop independently.
local walkState = setmetatable({}, { __mode = "k" })

local function legJoints(model)
	if isR6(model) then
		return findJoint(model, "Right Hip"), findJoint(model, "Left Hip")
	else
		return findJoint(model, "RightHip"), findJoint(model, "LeftHip")
	end
end

-- Start the walk loop for a model (no-op if already walking).
local function startWalk(model)
	if walkState[model] and walkState[model].running then return end
	local rLeg, lLeg = legJoints(model)
	local rArm, lArm = rightArmJoint(model), leftArmJoint(model)
	if not rLeg or not lLeg then return end
	restC0(rLeg); restC0(lLeg)
	if rArm then restC0(rArm) end
	if lArm then restC0(lArm) end
	local st = { running = true }
	walkState[model] = st
	task.spawn(function()
		local t = 0
		while st.running and model.Parent do
			t += 0.06
			local legAxisR6 = isR6(model)
			-- R15 needs a bigger swing to read (only the upper leg rotates).
			local amp = legAxisR6 and math.rad(32) or math.rad(45)
			local swing = math.sin(t * 9) * amp   -- gait speed + amplitude
			if legAxisR6 then
				rLeg.C0 = restC0(rLeg) * CFrame.Angles(0, 0, swing)
				lLeg.C0 = restC0(lLeg) * CFrame.Angles(0, 0, -swing)
			else
				rLeg.C0 = restC0(rLeg) * CFrame.Angles(swing, 0, 0)
				lLeg.C0 = restC0(lLeg) * CFrame.Angles(-swing, 0, 0)
			end
			-- subtle opposite arm sway (only if arms aren't mid-attack)
			if rArm then
				if legAxisR6 then rArm.C0 = restC0(rArm) * CFrame.Angles(0, 0, swing*0.5)
				else rArm.C0 = restC0(rArm) * CFrame.Angles(-swing*0.5, 0, 0) end
			end
			if lArm then
				if legAxisR6 then lArm.C0 = restC0(lArm) * CFrame.Angles(0, 0, -swing*0.5)
				else lArm.C0 = restC0(lArm) * CFrame.Angles(swing*0.5, 0, 0) end
			end
			task.wait(0.06)
		end
	end)
end

-- Stop the walk loop and ease limbs back to rest.
local function stopWalk(model)
	local st = walkState[model]
	if not st then return end
	st.running = false
	local rLeg, lLeg = legJoints(model)
	local rArm, lArm = rightArmJoint(model), leftArmJoint(model)
	resetJoint(rLeg, 0.15); resetJoint(lLeg, 0.15)
	-- don't reset arms here if an attack pose might be using them; ease gently
	if rArm then resetJoint(rArm, 0.15) end
	if lArm then resetJoint(lArm, 0.15) end
end

-- Public: set whether a unit is currently walking.
function AttackAnimator.setWalking(model, isMoving)
	if isMoving then startWalk(model) else stopWalk(model) end
end

-- Master Roshu: jump up, pull arms back to charge, then thrust forward firing
-- the beam, and land back in the same spot. He's anchored; the hop animates the
-- whole model's pivot up and back to where it started.
local function roshi(model)
	local rs = rightArmJoint(model)
	local ls = leftArmJoint(model)
	if not rs or not ls then return end
	restC0(rs); restC0(ls)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local startPivot = model:GetPivot()
	local up = startPivot + Vector3.new(0, 4, 0)

	task.spawn(function()
		-- 1) tiny crouch (dip down) then 2) hop up
		model:PivotTo(startPivot + Vector3.new(0, -0.6, 0))
		task.wait(0.08)
		-- hop up over ~0.18s
		local t0 = os.clock()
		while os.clock() - t0 < 0.18 do
			local a = (os.clock() - t0) / 0.18
			model:PivotTo(startPivot:Lerp(up, a))
			task.wait()
		end
		model:PivotTo(up)
		-- 3) pull both arms back (charge cup pose)
		tweenJointAbsolute(rs, CFrame.new(1, 0.5, 0) * CFrame.Angles(math.rad(70), 0, math.rad(-40)), 0.12)
		tweenJointAbsolute(ls, CFrame.new(-1, 0.5, 0) * CFrame.Angles(math.rad(70), 0, math.rad(40)), 0.12)
		task.wait(0.22)
		-- 4) thrust both arms forward (beam fires around now)
		tweenJointAbsolute(rs, CFrame.new(1, 0.5, 0) * CFrame.Angles(math.rad(90), 0, 0), 0.08, Enum.EasingStyle.Back)
		tweenJointAbsolute(ls, CFrame.new(-1, 0.5, 0) * CFrame.Angles(math.rad(90), 0, 0), 0.08, Enum.EasingStyle.Back)
		task.wait(0.25)
		-- 5) land back to the original spot + reset arms
		local t1 = os.clock()
		while os.clock() - t1 < 0.16 do
			local a = (os.clock() - t1) / 0.16
			model:PivotTo(up:Lerp(startPivot, a))
			task.wait()
		end
		model:PivotTo(startPivot)
		resetJoint(rs, 0.15); resetJoint(ls, 0.15)
	end)
end

-- Registry of unit -> pose function. Units not listed get no pose (yet).
local POSES = {
	Goku = goku,
	Yumcha = punch,
	Krillen = punch,
	["Master Roshu"] = roshi,
	Tein = tein,
	Bluma = bluma,
	Pikkolo = pikkolo,
}

-- Public: play a unit's attack animation. Safe no-op if no pose defined.
function AttackAnimator.play(model, unitName, side)
	local pose = POSES[unitName]
	if pose then
		local ok = pcall(pose, model, side)
		-- swallow errors so combat never breaks from an animation glitch
	end
end

return AttackAnimator

