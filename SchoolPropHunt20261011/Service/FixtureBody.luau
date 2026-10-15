local ok, failure = xpcall(function()
	local Service = require(module)(env)
	service = Service.new(arena, state)
	service.schoolBell = fakeBell
	service:Start()
	check("Only suitable tagged props are eligible", #service:_propTemplates() == 2)
	check("Storage displays correct kind", prompt.ObjectText == "Wardrobe")
	local a, ar, atag, aoutline = add(1)
	local b, br = add(2)
	local c, cr = add(3)
	local originals = {}
	for _, record in pairs(service.records) do
		record.character.Head.Transparency = 0.17
		local face = Instance.new("Decal") face.Transparency, face.Parent = 0.23, record.character.Head
		local effect = Instance.new("ParticleEmitter") effect.Enabled, effect.Parent = true, record.character.Head
		local original = {}
		for _, object in ipairs(record.character:GetDescendants()) do
			if object:IsA("BasePart") then original[object] = { Transparency = object.Transparency, CanCollide = object.CanCollide, Size = object.Size, Massless = object.Massless }
			elseif object:IsA("Decal") then original[object] = { Transparency = object.Transparency }
			elseif object:IsA("ParticleEmitter") or object:IsA("Highlight") or object:IsA("BillboardGui") then original[object] = { Enabled = object.Enabled } end
		end
		originals[record] = original
	end
	local function restored(record)
		for object, properties in pairs(originals[record] or {}) do
			if object.Parent then for key, value in pairs(properties) do if object[key] ~= value then return false, object.Name .. "." .. key end end end
		end
		return not record.propMorph and not record.player:GetAttribute("HSPropMorphed")
	end
	local function morphed(record)
		if not record.propMorph or not record.player:GetAttribute("HSPropMorphed") then return false end
		for object in pairs(originals[record] or {}) do
			if object:IsA("BasePart") or object:IsA("Decal") then if object.Transparency ~= 1 then return false end
			elseif object:IsA("ParticleEmitter") or object:IsA("Highlight") or object:IsA("BillboardGui") then if object.Enabled then return false end end
		end
		return true
	end
	local seeker, hiders = seeking({ a, b, c })
	local hider, other = hiders[1], hiders[2]
	check("School sprint capacity is twenty-five seconds", hider.player:GetAttribute("HSMaxStamina") == 25 and seeker.player:GetAttribute("HSMaxStamina") == 25)
	hider.stamina = 25
	check("Hider can begin sprinting", service:SetSprint(hider.player, true))
	now += 1
	service:_tick(1)
	check("One sprint second uses one of twenty-five seconds", math.abs(hider.stamina - 24) < 0.001 and hider.humanoid.WalkSpeed == 26)
	hider.stamina = 0.1
	service:_tick(0.05)
	check("School can sprint from a partially recharged bar", hider.stamina > 0 and hider.stamina < 0.1 and hider.humanoid.WalkSpeed == 26)
	hider.stamina = 0
	service:_movement(hider)
	check("School empty stamina stops sprinting", hider.humanoid.WalkSpeed == 16 and not hider.player:GetAttribute("HSSprinting"))
	service:_tick(0.05)
	check("First positive recharge immediately resumes school sprint", hider.stamina > 0 and hider.stamina < 0.1 and hider.humanoid.WalkSpeed == 26 and hider.player:GetAttribute("HSSprinting"))
	check("School sprint releases without a recharge gate", service:SetSprint(hider.player, false))
	service:_tick(30)
	check("School refill caps at twenty-five", hider.stamina == 25 and hider.humanoid.WalkSpeed == 16)
	check("Only hiders receive random prop morphs", morphed(hider) and morphed(other) and not seeker.propMorph)
	check("Prop identity is replicated on player and character", hider.player:GetAttribute("HSPropId") ~= "" and hider.character:GetAttribute("HSPropId") == hider.player:GetAttribute("HSPropId"))
	check("Bat reach remains ten studs", service:_setting("TagDistance", 10) == 10)
	local model = hider.propMorph.model
	local box, size = model:GetBoundingBox()
	local floor = hider.root.Position.Y - hider.humanoid.HipHeight - hider.root.Size.Y * 0.5 - hider.character["Left Leg"].Size.Y
	check("Prop bottom rests at avatar feet", math.abs(box.Position.Y - size.Y * 0.5 - floor) < 0.001)
	check("Morph retains template scale", size == Vector3.new(3, 4, 3))
	local outline = model:FindFirstChild("SchoolPropOutline")
	check("Morph has black occluded outline", outline and outline.Enabled and outline.OutlineColor == Color3.new(0,0,0) and outline.DepthMode == Enum.HighlightDepthMode.Occluded and outline.FillTransparency == 1)
	for object, values in pairs(originals[hider]) do
		if object:IsA("BasePart") then check("Avatar collider and rig size remain unchanged: " .. object.Name, object.CanCollide == values.CanCollide and object.Size == values.Size and object.Massless == values.Massless) end
	end
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then check("Visible prop is massless welded decoration", not object.Anchored and object.Massless and not object.CanCollide and not object.CanTouch and not object.CanQuery and object.SchoolPropWeld.Part0 == hider.root) end
	end
	local late = Instance.new("Part")
	late.Name, late.Transparency, late.CanCollide = "LateHat", 0.34, false
	late.Parent = hider.character
	local lateSpark = Instance.new("Sparkles") lateSpark.Enabled, lateSpark.Parent = true, late
	task.wait()
	check("Late avatar accessories and sparkles stay concealed", late.Transparency == 1 and not lateSpark.Enabled)
	local locker = service.lockers[lockerModel]
	service:_teleport(hider, CFrame.new(origin + Vector3.new(20,3,-6)))
	now += 1
	check("Morphed hider can enter wardrobe", service:UseLocker(hider.player, locker))
	check("Wardrobe conceals prop and outline", model.PropBody.Transparency == 1 and not outline.Enabled and hider.root.Anchored)
	now += 1
	check("Hider can leave wardrobe", service:ExitLocker(hider.player))
	check("Leaving wardrobe reveals prop only", model.PropBody.Transparency == 0 and outline.Enabled and morphed(hider) and not hider.root.Anchored)
	now += 1
	check("Wardrobe can be occupied again", service:UseLocker(hider.player, locker))
	service:_teleport(seeker, CFrame.new(origin + Vector3.new(20,3,-6)))
	now += 1
	check("Seeker can find and convert wardrobe occupant", service:UseLocker(seeker.player, locker))
	check("Conversion removes prop before ragdoll", hider.role == "Seeker" and not hider.propMorph and model.Parent == nil and not hider.player:GetAttribute("HSPropMorphed"))
	check("Conversion restores avatar face and late accessory", math.abs(hider.character.Head.Transparency - 0.17) < 0.0001 and math.abs(late.Transparency - 0.34) < 0.0001 and lateSpark.Enabled)
	now += 1.36 service:_tick(0.05)
	check("Converted seeker recovers normally", not hider.ragdoll and hider.humanoid.WalkSpeed == 18)
	service:_teleport(seeker, CFrame.lookAt(origin + Vector3.new(0,3,0), origin + Vector3.new(0,3,-10)))
	service:_teleport(other, CFrame.new(origin + Vector3.new(0,3,-9.9)))
	local wall = part(container, "PropBatWall", origin + Vector3.new(0,3,-5), Vector3.new(15,10,0.5), true)
	now += 1
	check("Seeker can swing at a prop", service:TryBatSwing(seeker.player))
	now += 0.15 service:_tick(0.05)
	check("Prop cannot be tagged through walls", other.role == "Hider" and other.propMorph ~= nil)
	wall:Destroy()
	now += 1
	check("Seeker can swing again after cooldown", service:TryBatSwing(seeker.player))
	now += 0.15 service:_tick(0.05)
	check("Prop tags at 9.9 studs convert and reveal avatar", other.role == "Seeker" and not other.propMorph and not other.player:GetAttribute("HSPropMorphed"))
	service:StopRound()
	check("Admin stop restores all originals", restored(ar) and restored(br) and restored(cr))
	check("Admin stop clears hiding flags", not a:GetAttribute("HSParticipating") and not b:GetAttribute("HSParticipating") and not c:GetAttribute("HSParticipating"))
	seeker, hiders = seeking({a,b,c})
	hider = hiders[1]
	local lost = hider.propMorph.model
	lost:Destroy()
	service:_tick(0.05)
	check("Missing morph is repaired instead of invisible hider", hider.propMorph and hider.propMorph.model.Parent == hider.character and morphed(hider))
	local originalCharacter = hider.character
	hider.player.CharacterRemoving:Fire(originalCharacter)
	service:_restoreCharacter(hider)
	hider.ready = false
	service:_role(hider, "Seeker")
	service:_bindCharacter(hider, character(hider.player))
	check("Respawn returns visible seeker with no stale morph", hider.ready and hider.role == "Seeker" and not hider.propMorph and hider.character.Head.Transparency == 0)
	service:StopRound()
	seeker, hiders = seeking({a,b,c})
	hider = hiders[1]
	hider.humanoid.Health = 0
	task.wait()
	service:_tick(0.05)
	check("Death cleans prop and converts hider", not hider.propMorph and hider.role == "Seeker" and not hider.player:GetAttribute("HSPropMorphed"))
	service:StopRound()
	service:_bindCharacter(hider, character(hider.player))
	seeker, hiders = seeking({a,b,c})
	now = service.endsAt
	service:_tick(0.05)
	check("Five minute timeout awards surviving hiders", service.phase == "Results" and state:GetAttribute("WinningRole") == "Hider")
	check("Results reveal avatars and remove all props", not hiders[1].propMorph and not hiders[2].propMorph)
	service:StopRound()
	local entries = templates:GetChildren()
	for _, item in ipairs(entries) do item:SetAttribute("HSPropEligible", false) end
	check("Unavailable props cancel startup rather than invisible play", not service:StartRound({a,b,c}) and not service.active and service.phase == "Waiting")
	check("Failed start restores all participant flags", not a:GetAttribute("HSParticipating") and not b:GetAttribute("HSParticipating") and not c:GetAttribute("HSParticipating"))
	for _, item in ipairs(entries) do if item == usableTemplate then item:SetAttribute("HSPropEligible", true) end end
	usableTemplate.Archivable = false
	check("Clone failure cancels the prepared round safely", not service:StartRound({a,b,c}) and not service.active and service.phase == "Waiting")
	check("Clone failure leaves no hidden avatars", not a:GetAttribute("HSPropMorphed") and not b:GetAttribute("HSPropMorphed") and not c:GetAttribute("HSPropMorphed"))
	usableTemplate.Archivable = true
	seeker, hiders = seeking({a,b,c})
	hider = hiders[1]
	usableTemplate:SetAttribute("HSPropEligible", false)
	hider.propMorph.model:Destroy()
	service:_tick(0.05)
	check("Unrecoverable morph loss cancels rewards", service.phase == "Results" and state:GetAttribute("LastResultPractice") == true and state:GetAttribute("LastResultWinnerIds") == "")
	service:Stop()
	check("Shutdown clears service and no props remain", not service.running and next(service.records) == nil and not container:FindFirstChild("SchoolPropMorph", true))
end, debug.traceback)
if not ok then table.insert(report.errors, failure) end
pcall(function() if service then service:Stop() end end)
container:Destroy()
module:Destroy()
report.passed = ok
report.checkCount = #report.checks
return game:GetService("HttpService"):JSONEncode(report)
