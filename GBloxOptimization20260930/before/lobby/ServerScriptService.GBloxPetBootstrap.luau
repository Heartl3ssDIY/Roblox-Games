local PetService=require(script.Parent:WaitForChild("GBloxPetService"))
-- Keeps newly imported pet models available without adding a Script to each pet.
local pets=workspace:WaitForChild("Pets")
pets.DescendantAdded:Connect(function(instance)
 if instance:IsA("Model") then task.defer(PetService.RefreshTemplates) end
end)

