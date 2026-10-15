from pathlib import Path
root = Path(__file__).parent
out = root / "After"
out.mkdir(exist_ok=True)
def replace_once(s, old, new):
    assert s.count(old) == 1, (old[:100], s.count(old))
    return s.replace(old, new)
s = (root / "Before/Emotes.luau").read_text(encoding="utf-8")
motion = (root / "AuthoredMotion.luau").read_text(encoding="utf-8")
s = replace_once(s, "local hoveringPets = { P23", motion + "local hoveringPets = { P23")
s = replace_once(s, "local function prepareRigMotion(state)\n", "local function prepareRigMotion(state)\n\tprepareAuthoredMotion(state)\n")
s = replace_once(s, "local function updateRigMotion(state, reducedMotion)\n\tif not state.tracks.idle", "local function updateRigMotion(state, reducedMotion)\n\tif state.authored then updateAuthoredMotion(state, reducedMotion) return end\n\tif not state.tracks.idle")
s = replace_once(s, 'if model:IsA("Model") and model:GetAttribute("PCProceduralPetRig") == true and not petRigStates[model] then', 'if model:IsA("Model") and (model:GetAttribute("PCProceduralPetRig") == true or type(model:GetAttribute("PCPetClipSet")) == "string") and not petRigStates[model] then')
s = replace_once(s, '\t\tlocal folder = workspace:FindFirstChild("PlaygroundPetVisuals")', '''\t\tlocal display = workspace:FindFirstChild("VIP-Dragon-Rigged-display")
\t\tif display and display:IsA("Model") and display:GetAttribute("PCDisplayPet") == true and not petRigStates[display] then
\t\t\tlocal state = {model = display, id = "P36", tracks = {}, movement = 0, phase = 0}
\t\t\tprepareRigMotion(state)
\t\t\tpetRigStates[display] = state
\t\tend
\t\tlocal folder = workspace:FindFirstChild("PlaygroundPetVisuals")''')
s = replace_once(s, '\t\t\tupdateRigMotion(state, reducedMotion)', '''\t\t\tif state.authored and not reducedMotion then
\t\t\t\tlocal clips = state.authored.clips
\t\t\t\tlocal blend = model:GetAttribute("PCDisplayPet") == true and 0 or state.movement
\t\t\t\tlocal duration = clips.Idle.duration + ((clips.Fly or clips.Idle).duration - clips.Idle.duration) * blend
\t\t\t\tstate.authored.phase = (state.authored.phase + delta / duration) % 1
\t\t\tend
\t\t\tupdateRigMotion(state, reducedMotion)''')
s = replace_once(s, '\t\tif model.Parent then updateRigMotion(state, true) end', '''\t\tif model.Parent then
\t\t\tif state.authored then
\t\t\t\tfor _, entry in state.authored.bones do entry.bone.Transform = entry.rest end
\t\t\telse updateRigMotion(state, true) end
\t\tend''')
(out / "Emotes.luau").write_text(s, encoding="utf-8")
s = (root / "Before/Pets.luau").read_text(encoding="utf-8")
s = replace_once(s, 'local position = Vector3.new(state.position.X, state.ground + 0.12 + bounce, state.position.Z)', '''local flightHeight = math.clamp(tonumber(state.model:GetAttribute("PCPetHoverHeight")) or 0, 0, 5)
\tif flightHeight > 0 then
\t\tbounce = math.sin(state.phase * 0.5) * (reducedMotion and 0.015 or 0.07)
\t\tpitch, roll = 0, 0
\tend
\tlocal position = Vector3.new(state.position.X, state.ground + 0.12 + flightHeight + bounce, state.position.Z)''')
s = replace_once(s, 'if state.model:GetAttribute("PCProceduralPetRig") == true then', 'if state.model:GetAttribute("PCProceduralPetRig") == true or type(state.model:GetAttribute("PCPetClipSet")) == "string" then')
(out / "Pets.luau").write_text(s, encoding="utf-8")
s = (root / "Before/Catalog.luau").read_text(encoding="utf-8")
s = replace_once(s, 'local suppliedThumbnails = {', '''table.insert(items, item("P36", "VIP Royal Dragon", "Pets", "Pet", "VIP", 0, nil,
\t"A crowned golden dragon with ruby wings. Flies beside VIP players.", {255, 195, 53}))

local suppliedThumbnails = {''')
(out / "Catalog.luau").write_text(s, encoding="utf-8")
print("Prepared Catalog, Pets and Emotes with guarded substitutions.")

