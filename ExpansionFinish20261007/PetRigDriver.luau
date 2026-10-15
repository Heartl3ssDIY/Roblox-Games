local petRigStates = {}
local petRigClock = 1
local function updatePetRigs(delta)
	petRigClock += delta
	if petRigClock >= 0.3 then
		petRigClock = 0
		local folder = workspace:FindFirstChild("PlaygroundPetVisuals")
		if folder then
			for _, model in ipairs(folder:GetChildren()) do
				if model:IsA("Model") and model:GetAttribute("PCProceduralPetRig") == true and not petRigStates[model] then
					local userId = tonumber(model:GetAttribute("PetOwnerUserId")) or 0
					local state = {model = model, id = model:GetAttribute("CatalogId"), tracks = {}, movement = 0, phase = (userId % 97) * math.pi * 2 / 97}
					prepareRigMotion(state)
					petRigStates[model] = state
				end
			end
		end
	end
	local reducedMotion = Players.LocalPlayer:GetAttribute("PCReducedMotion") == true
	for model, state in pairs(petRigStates) do
		if not model.Parent then
			petRigStates[model] = nil
		else
			state.movement = math.clamp(tonumber(model:GetAttribute("PCPetMovement")) or 0, 0, 1)
			state.phase += delta * math.pi * 2 * (0.85 + state.movement * 1.75)
			updateRigMotion(state, reducedMotion)
		end
	end
end
