local lobby = workspace:FindFirstChild("Playground Lobby")
assert(lobby and not game:GetService("RunService"):IsRunning(), "Build the lobby swing in Edit mode.")
assert(not lobby:FindFirstChild("PlaygroundLobbySwing"), "Swing is already installed; inspect before replacing it.")
local center = Vector3.new(51, 4, 35)
local ink = Color3.fromRGB(18, 28, 48)
local cream = Color3.fromRGB(255, 244, 200)
local teal = Color3.fromRGB(102, 220, 197)
local blue = Color3.fromRGB(94, 184, 232)
local coral = Color3.fromRGB(250, 154, 177)
local yellow = Color3.fromRGB(255, 207, 88)
local model = Instance.new("Model")
model.Name = "PlaygroundLobbySwing"
model:SetAttribute("SwingAngle", 26)
model:SetAttribute("SwingPeriod", 4.5)
model:SetAttribute("LobbyOnly", true)
model:SetAttribute("BuildVersion", "20261007")
model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
local static = Instance.new("Model")
static.Name, static.Parent = "Frame", model
local seats = Instance.new("Folder")
seats.Name, seats.Parent = "Seats", model

local function part(parent, name, size, cf, color, collision, studs, class)
	local p = Instance.new(class or "Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, collision == true, false, collision == true
	p.Material, p.MaterialVariant = Enum.Material.SmoothPlastic, studs and "PlaygroundRetroStuds" or ""
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Locked = true
	p.Parent = parent
	return p
end

local function bar(parent, name, a, b, width, depth, color, collision, studs)
	local cf = CFrame.lookAt((a + b) / 2, b)
	return part(parent, name, Vector3.new(width, depth, (b - a).Magnitude), cf, color, collision, studs)
end

local function edges(p, thickness)
	local half = p.Size / 2
	local e = Instance.new("Folder")
	e.Name, e.Parent = p.Name .. "InkEdges", p.Parent
	for axis = 1, 3 do
		for _, a in ipairs({ -1, 1 }) do
			for _, b in ipairs({ -1, 1 }) do
				local q0, q1
				if axis == 1 then q0, q1 = Vector3.new(-half.X, a * half.Y, b * half.Z), Vector3.new(half.X, a * half.Y, b * half.Z)
				elseif axis == 2 then q0, q1 = Vector3.new(a * half.X, -half.Y, b * half.Z), Vector3.new(a * half.X, half.Y, b * half.Z)
				else q0, q1 = Vector3.new(a * half.X, b * half.Y, -half.Z), Vector3.new(a * half.X, b * half.Y, half.Z) end
				bar(e, "Ink", p.CFrame:PointToWorldSpace(q0), p.CFrame:PointToWorldSpace(q1), thickness, thickness, ink, false, false)
			end
		end
	end
end

local function ball(parent, name, pos, size, color)
	local p = part(parent, name, Vector3.one * size, CFrame.new(pos), color, false, false)
	p.Shape = Enum.PartType.Ball
	return p
end

local function textFace(p, face, title, subtitle)
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face, gui.CanvasSize, gui.Parent = "SwingSign", face, Vector2.new(800, 180), p
	gui.LightInfluence, gui.AlwaysOnTop = 0, false
	local label = Instance.new("TextLabel")
	label.Name, label.BackgroundTransparency = "Title", 1
	label.Position, label.Size = UDim2.fromScale(0.04, 0.05), UDim2.fromScale(0.92, 0.58)
	label.Font, label.Text, label.TextScaled, label.TextColor3 = Enum.Font.FredokaOne, title, true, cream
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Parent = ink, 3, label
	local hint = label:Clone()
	hint.Name, hint.Text = "Hint", subtitle
	hint.Position, hint.Size = UDim2.fromScale(0.04, 0.65), UDim2.fromScale(0.92, 0.3)
	hint.Parent = gui
end

local mat = part(static, "RubberMatInk", Vector3.new(32, 0.28, 24), CFrame.new(center + Vector3.new(0, 0.13, 0)), ink, true, false)
part(static, "PlayMat", Vector3.new(31.5, 0.2, 23.5), CFrame.new(center + Vector3.new(0, 0.32, 0)), teal, true, true)
for _, x in ipairs({ -6.5, 6.5 }) do
	part(static, "SeatLane", Vector3.new(5.2, 0.025, 17), CFrame.new(center + Vector3.new(x, 0.433, 0)), cream, false, false)
end
for _, x in ipairs({ -13, 13 }) do
	for _, z in ipairs({ -5.1, 5.1 }) do
		local foot = center + Vector3.new(x, 0.55, z)
		local top = center + Vector3.new(x, 15.75, 0)
		local leg = bar(static, "AFrameLeg", foot, top, 1.05, 1.05, blue, true, true)
		edges(leg, 0.055)
		local shoe = part(static, "FootShoe", Vector3.new(1.85, 0.75, 2.1), CFrame.new(foot), yellow, true, true)
		edges(shoe, 0.065)
		ball(static, "AnchorBolt", foot + Vector3.new(0, 0.46, 0), 0.24, ink)
	end
	local brace = part(static, "SideBrace", Vector3.new(0.8, 0.65, 6.8), CFrame.new(center + Vector3.new(x, 4.8, 0)), coral, true, true)
	edges(brace, 0.055)
end
local beam = part(static, "TopBeam", Vector3.new(29.5, 1.25, 1.5), CFrame.new(center + Vector3.new(0, 15.9, 0)), teal, true, true)
edges(beam, 0.065)
for _, x in ipairs({ -15.1, 15.1 }) do ball(static, "BeamEndCap", center + Vector3.new(x, 15.9, 0), 1.65, yellow) end
local sign = part(static, "SwingsSign", Vector3.new(11, 2.4, 0.5), CFrame.new(center + Vector3.new(0, 17.7, 0)), coral, false, true)
edges(sign, 0.07)
textFace(sign, Enum.NormalId.Front, "PLAYGROUND SWINGS", "SIT TO SWING  •  JUMP TO HOP OFF")
textFace(sign, Enum.NormalId.Back, "PLAYGROUND SWINGS", "SIT TO SWING  •  JUMP TO HOP OFF")

for index, x in ipairs({ -6.5, 6.5 }) do
	local assembly = Instance.new("Model")
	assembly.Name, assembly.Parent = "Swing" .. index, seats
	local seatPosition = center + Vector3.new(x, 3.65, 0)
	local seat = part(assembly, "Seat", Vector3.new(3.7, 0.48, 2.65), CFrame.new(seatPosition), index == 1 and coral or blue, false, true, "Seat")
	seat.CanQuery = true
	seat.Disabled = false
	seat.RootPriority = 127
	seat.CustomPhysicalProperties = PhysicalProperties.new(1.8, 0.3, 0, 1, 1)
	edges(seat, 0.075)
	local grip = part(assembly, "SeatFrontLip", Vector3.new(3.75, 0.18, 0.24), CFrame.new(seatPosition + Vector3.new(0, 0.23, -1.28)), cream, false, false)
	edges(grip, 0.04)
	for _, ropeX in ipairs({ -1.65, 1.65 }) do
		local a = seatPosition + Vector3.new(ropeX, 0.2, 0)
		local b = center + Vector3.new(x + ropeX, 15.3, 0)
		bar(assembly, "SwingRope", a, b, 0.17, 0.17, cream, false, false)
		for j = 0, 9 do
			part(assembly, "RopeWrap", Vector3.new(0.22, 0.07, 0.22), CFrame.new(a:Lerp(b, (j + 0.4) / 10)), ink, false, false)
		end
		part(assembly, "RopeShoe", Vector3.new(0.4, 0.55, 0.45), CFrame.new(a + Vector3.new(0, 0.1, 0)), yellow, false, false)
		local collar = part(static, "Hanger", Vector3.new(0.6, 1.65, 1.75), CFrame.new(center + Vector3.new(x + ropeX, 15.65, 0)), ink, false, false)
		part(static, "HangerFace", Vector3.new(0.43, 1.42, 0.05), collar.CFrame * CFrame.new(0, 0, -0.901), cream, false, false)
	end
	local pivot = center + Vector3.new(x, 15.3, 0)
	local fixed = Instance.new("Attachment")
	fixed.Name, fixed.Position, fixed.Parent = "SwingPivot" .. index, beam.CFrame:PointToObjectSpace(pivot), beam
	local moving = Instance.new("Attachment")
	moving.Name, moving.Position, moving.Parent = "SuspensionPivot", seat.CFrame:PointToObjectSpace(pivot), seat
	local hinge = Instance.new("HingeConstraint")
	hinge.Name, hinge.Attachment0, hinge.Attachment1 = "SwingHinge", fixed, moving
	hinge.ActuatorType, hinge.LimitsEnabled = Enum.ActuatorType.Servo, true
	hinge.LowerAngle, hinge.UpperAngle, hinge.Restitution = -32, 32, 0
	hinge.AngularSpeed, hinge.AngularResponsiveness, hinge.ServoMaxTorque = 1.3, 8, 160000
	hinge.TargetAngle, hinge.Parent = 0, assembly
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = "SitPrompt", "Sit & swing", "Playground swing"
	prompt.MaxActivationDistance, prompt.HoldDuration, prompt.RequiresLineOfSight = 7, 0, false
	prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
	prompt.Exclusivity, prompt.Parent = Enum.ProximityPromptExclusivity.OnePerButton, seat
	for _, p in ipairs(assembly:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = p ~= seat
			if p ~= seat then
				local weld = Instance.new("WeldConstraint")
				weld.Name, weld.Part0, weld.Part1, weld.Parent = "SeatAssemblyWeld", seat, p, p
			end
		end
	end
	assembly.PrimaryPart = seat
end
model.PrimaryPart = mat
model.Parent = lobby
return model:GetFullName()
