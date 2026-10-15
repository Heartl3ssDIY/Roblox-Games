from pathlib import Path
r=Path(__file__).parent
a=r/'After'
s=(a/'PlaygroundPets.luau').read_text(encoding='utf-8')
helper=(r/'PetRigMotion.luau').read_text(encoding='utf-8')
assert helper in s
s=s.replace(helper+'\n','').replace('\tprepareRigMotion(state)\n','')
s=s.replace('\tupdateRigMotion(state, reducedMotion)\n','\tif state.model:GetAttribute("PCProceduralPetRig") == true then\n\t\tstate.model:SetAttribute("PCPetMovement", state.movement)\n\tend\n')
(a/'PlaygroundPets.luau').write_text(s,encoding='utf-8')
s=(a/'PlaygroundEmotes.luau').read_text(encoding='utf-8')
driver=(r/'PetRigDriver.luau').read_text(encoding='utf-8')
s=s.replace('local beforeAnimation = RunService.PreAnimation:Connect(function()', 'local hoveringPets = { P23 = true, P25 = true, P28 = true, P35 = true }\n'+helper+'\n'+driver+'\nlocal beforeAnimation = RunService.PreAnimation:Connect(function()')
s=s.replace('local frame = RunService.PreSimulation:Connect(function()\n', 'local frame = RunService.PreSimulation:Connect(function(delta)\n\tupdatePetRigs(math.min(delta, 0.1))\n')
s=s.replace('\ttable.clear(botRecords)\nend)', '\ttable.clear(botRecords)\n\tfor model, state in pairs(petRigStates) do\n\t\tif model.Parent then updateRigMotion(state, true) end\n\tend\n\ttable.clear(petRigStates)\nend)')
(a/'PlaygroundEmotes.luau').write_text(s,encoding='utf-8')
print('Moved procedural bone animation into already-authorized PlaygroundEmotes')
